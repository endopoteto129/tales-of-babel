# 戦闘画面。LMBS（リニアモーションバトル）風のリアルタイム横一列バトル。
extends Node2D

const LEFT := 40.0
const RIGHT := 1240.0
const GROUND_Y := 600.0

const HudScript := preload("res://scripts/battle/battle_hud.gd")
const BgScript := preload("res://scripts/battle/battle_bg.gd")
const CompanionScript := preload("res://scripts/battle/companions.gd")

var params: Dictionary = {}
var kind := "battle"
var world: Node2D
var layer_fighters: Node2D
var layer_fx: Node2D
var hud: Control
var bg: Node2D
var companions: Node2D

var fighters: Array = []
var party: Array = []
var enemies: Array = []
var projectiles: Array = []
var aoes: Array = []
var fxs: Array = []
var pending: Array = []        # 遅延発射 [time, fighter, spec, power]
var player: Fighter
var player_target: Fighter

var time := 0.0
var started := false
var frozen := false
var paused := false
var ended := false
var hitstop := 0.0
var slowmo := 1.0
var slowmo_t := 0.0
var shake_amt := 0.0
var flash_col := Color(1, 1, 1, 0)
var first_strike_t := 0.0

var combo_hits := 0
var combo_dmg := 0
var combo_t := 0.0
var max_combo := 0
var link := 0.0
var ovl := 0.0           # オーバーリミッツゲージ（0〜100）
var ovl_t := 0.0         # オーバーリミッツの残り時間
const OVL_TIME := 10.0
# ゲージのたまりやすさ（1ヒットあたり）。OVLはボス戦で1回、絆はそれより少し多く満タンになる目安
const LINK_PER_HIT := 0.18
const LINK_PER_CHAIN := 0.45
const LINK_PER_CHEER := 5.0
const OVL_PER_HIT := 0.6      # レン自身の攻撃と被弾でだけたまる
const OVL_PER_DAMAGE := 2.5
const MYSTIC_PER_HIT := 2.5   # オーバーリミッツ中だけたまる
var finish_target: Fighter     # とどめ待ちのボス
var finishing := false
var finish_auto_t := 0.0
var gauge_probe := false      # バランス確認用：満タンになった回数を数えて0に戻す
var link_fills := 0
var ovl_fills := 0
var last_hitter: Dictionary = {}  # enemy -> [fighter, time]
var phoenix_used := false
var analyzed: Dictionary = {}

var chat_queue: Array = []
var chat_bubble: Control
var chat_speaker := ""
var chat_t := 0.0
var chat_cd := 0.0
var chat_used: Dictionary = {}
var cheer_t := 14.0
var banter_t := 9.0
var events_fired: Dictionary = {}

# ターン制：こちらのターンは全員で自由に攻め、敵のターンは一体ずつの攻撃を回避・ガード・パリィでしのぐ
const PARTY_TURN_TIME := 7.0
const PARTY_TURN_GRACE := 2.0    # 時間切れでも、レンの連携が終わるまでは待つ
const ENEMY_TURN_LIMIT := 16.0
const PARRY_WINDOW := 0.25       # 攻撃が当たる直前にガードを押すとパリィ
const COUNTER_WINDOW := 0.9      # パリィのあと、攻撃ボタンでカウンター
const PERFECT_BONUS := 2.0       # 無傷でしのぐと次のターンが延びる
const TELEGRAPH_MULT := 1.5      # 敵のターンの攻撃は予備動作を長めに見せる
var turn := "party"
var turn_no := 1
var turn_t := PARTY_TURN_TIME
var enemy_turn_t := 0.0
var enemy_queue: Array = []      # [敵, 残りの攻撃回数]
var turn_actor: Fighter
var actor_attacked := false
var actor_wait := 0.0
var counter_t := 0.0
var counter_target: Fighter
var ren_hurt_this_turn := false
var enemy_attacks_this_turn := 0
var callout_bubble: Control
var callout_t := 0.0
var callout_speaker := ""
var rewards: Dictionary = {}


func setup(p: Dictionary) -> void:
	params = p
	kind = p.get("kind", "battle")


func _ready() -> void:
	bg = BgScript.new()
	bg.deco = DB.floor_data(Game.floor_num)["deco"]
	bg.boss = kind == "boss"
	add_child(bg)
	world = Node2D.new()
	add_child(world)
	companions = CompanionScript.new()
	companions.battle = self
	world.add_child(companions)
	layer_fighters = Node2D.new()
	world.add_child(layer_fighters)
	layer_fx = Node2D.new()
	world.add_child(layer_fx)
	var hl = CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = HudScript.new()
	hud.battle = self
	hl.add_child(hud)

	# 味方
	var members: Array = Game.active_party()
	var px = 330.0
	for i in range(members.size()):
		var m: Dictionary = members[i]
		var f = Fighter.new()
		f.setup_party(self, m, i == 0)
		f.x = px - i * 80.0
		f.facing = 1
		_add_fighter(f)
		party.append(f)
		if i == 0:
			player = f
	# 敵
	var ids: Array = params.get("enemies", ["slime"])
	var scale: float = DB.floor_data(Game.floor_num)["scale"]
	if kind == "elite":
		scale *= 1.05
	scale *= params.get("scale", 1.0)
	for i in range(ids.size()):
		var e = Fighter.new()
		e.setup_enemy(self, ids[i], scale)
		e.x = 900.0 + i * 110.0 if not e.data.get("boss", false) else 960.0
		if ids.size() > 1 and e.data.get("boss", false):
			e.x = 1000.0
		_add_fighter(e)
		enemies.append(e)
	player_target = enemies[0]
	first_strike_t = Game.bmod("first_strike")
	turn_t = PARTY_TURN_TIME + first_strike_t
	link = Game.bmod("link_start")
	hud.build()
	_intro()


func _add_fighter(f: Fighter) -> void:
	fighters.append(f)
	layer_fighters.add_child(f)
	f.position = Vector2(f.x, GROUND_Y - f.h)


func _intro() -> void:
	var title = "BOSS BATTLE" if kind == "boss" else ("STRONG ENEMY" if kind == "elite" else "ENCOUNTER")
	hud.show_banner(title, Color(1, 0.4, 0.3) if kind != "battle" else Color(1, 0.9, 0.6))
	Sfx.play("warn" if kind == "boss" else "confirm")
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	started = true
	if first_strike_t > 0.0:
		popup_text(Vector2(900, 380), "先制！", Color(0.6, 0.9, 1.0), 34)
	chat("start_boss" if kind == "boss" else "start", {})
	if Game.flags.get("debug_full_gauges", false):
		ovl = 100.0
		Game.flags["mystic_gauge"] = 300.0
	_check_analysis()
	_tutorial("battle")


# 新しい要素のチュートリアル。表示中は戦闘を止める
func _tutorial(id: String) -> void:
	if ended or not Game.should_tutorial(id):
		return
	paused = true
	await Main.inst.show_tutorial(id)
	if is_inside_tree():
		paused = false


func _check_tutorials() -> void:
	if link >= 100.0 and not Game.flags.get("tut_link", false):
		_tutorial("link")
	elif ovl >= 100.0 and not Game.flags.get("tut_ovl", false):
		_tutorial("ovl")
	elif ovl_t > 0.0 and mystic_gauge() >= 100.0 and not Game.flags.get("tut_mystic", false):
		_tutorial("mystic")


# ------------------------------------------------------------ メインループ
func _process(delta: float) -> void:
	if paused:
		return
	_poll_commands()
	var dt = delta
	if hitstop > 0.0:
		hitstop -= delta
		dt = delta * 0.04
	if slowmo_t > 0.0:
		slowmo_t -= delta
		dt *= slowmo
	if frozen:
		dt = 0.0
	time += dt
	first_strike_t = max(0.0, first_strike_t - dt)
	if ovl_t > 0.0:
		ovl_t -= dt
		if ovl_t <= 0.0:
			ovl_t = 0.0
			popup_text(player.head() + Vector2(0, -30), "オーバーリミッツ終了", Color(1.0, 0.85, 0.5), 18)
	for f in fighters.duplicate():
		f.tick(dt)
	for p in projectiles.duplicate():
		if is_instance_valid(p):
			p.tick(dt)
	projectiles = projectiles.filter(func(p) -> bool: return is_instance_valid(p) and not p.done)
	for a in aoes.duplicate():
		if is_instance_valid(a):
			a.tick(dt)
	aoes = aoes.filter(func(a) -> bool: return is_instance_valid(a) and not a.done)
	for fx in fxs.duplicate():
		if is_instance_valid(fx):
			fx.tick(dt)
	fxs = fxs.filter(func(fx) -> bool: return is_instance_valid(fx))
	for i in range(pending.size() - 1, -1, -1):
		var pd: Array = pending[i]
		pd[0] -= dt
		if pd[0] <= 0.0:
			pending.remove_at(i)
			if is_instance_valid(pd[1]) and pd[1].alive():
				spawn_projectile(pd[1], pd[2], pd[3])
	companions.tick(dt)
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			_end_combo()
	shake_amt = max(0.0, shake_amt - delta * 3.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt * 10.0
	flash_col.a = max(0.0, flash_col.a - delta * 2.0)
	if player_target == null or not player_target.alive():
		player_target = nearest_enemy(player) if player else null
	_tick_chat(delta)
	if finish_target and not frozen and player and not player.is_player:
		# AI任せ（バランス確認・自動テスト）のときは自動でとどめ
		finish_auto_t += delta
		if finish_auto_t > 1.5:
			fire_finisher()
	_tick_callout(delta)
	if started and not ended:
		_check_tutorials()
		_tick_turn(dt)
		_tick_cheer(dt)
		_tick_banter(dt)
		_check_events()
		_check_end()
	hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not started or ended:
		return
	if event.is_action_pressed("pause"):
		if not frozen:
			hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		debug_enemies_to_10()
		get_viewport().set_input_as_handled()


# デバッグ：生きている敵全員のHPを一気に残り10にする（F9、またはメニューから）
func debug_enemies_to_10() -> void:
	for e in enemies:
		if e.alive() and not e.held:
			e.hp = min(e.hp, 10.0)
			popup_text(e.head() + Vector2(0, -30), "DEBUG HP→10", Color(1.0, 0.5, 1.0), 18)
	Sfx.play("confirm")


# ターゲット切替・共鳴秘技・仲間への指示。スティックやトリガーも1回押しとして扱うため毎フレーム確認する
func _poll_commands() -> void:
	if not started or ended or paused or frozen:
		return
	if Input.is_action_just_pressed("target"):
		_cycle_target()
	elif Input.is_action_just_pressed("link"):
		if not is_enemy_turn():
			try_link()
	elif Input.is_action_just_pressed("overlimit"):
		if finish_target and is_instance_valid(finish_target):
			fire_finisher()
		elif not is_enemy_turn():
			_press_overlimit()
	else:
		for i in range(3):
			if Input.is_action_just_pressed("ally%d" % (i + 1)):
				_shortcut(i + 1)


func _cycle_target() -> void:
	var alive = enemies.filter(func(e) -> bool: return e.alive())
	if alive.is_empty():
		return
	var idx = alive.find(player_target)
	player_target = alive[(idx + 1) % alive.size()]
	Sfx.play("select")


func _shortcut(i: int) -> void:
	if i >= party.size():
		return
	var f: Fighter = party[i]
	if not f.alive():
		return
	for aid in f.arte_slots:
		if aid != "":
			f.shortcut_req = aid
			popup_text(f.head() + Vector2(0, -30), "指示：" + DB.arte(aid)["name"], Color(0.7, 0.9, 1.0), 16)
			return


# ------------------------------------------------------------ 検索
func opponents(f: Fighter) -> Array:
	return opponents_of_team(f.team)


func opponents_of_team(team: int) -> Array:
	return enemies if team == 0 else party


func allies_of(f: Fighter) -> Array:
	return party if f.team == 0 else enemies


func nearest_enemy(f: Fighter) -> Fighter:
	if f == null:
		return null
	var best: Fighter = null
	var bd = 1e9
	for e in opponents(f):
		if not e.alive():
			continue
		var d: float = abs(e.x - f.x)
		if d < bd:
			bd = d
			best = e
	return best


func nearest_enemy_dist(f: Fighter) -> float:
	var e = nearest_enemy(f)
	return abs(e.x - f.x) if e else 1e9


func weakest_ally(f: Fighter, dead_only: bool) -> Fighter:
	var best: Fighter = null
	var br = 2.0
	for a in allies_of(f):
		if dead_only:
			if not a.alive():
				return a
			continue
		if a.alive() and a.hp_ratio() < br:
			br = a.hp_ratio()
			best = a
	if dead_only:
		return null
	return best


func party_avg_hp() -> float:
	var s = 0.0
	var n = 0
	for p in party:
		if p.alive():
			s += p.hp_ratio()
			n += 1
	return s / n if n > 0 else 0.0


func enemy_pick_target(e: Fighter) -> Fighter:
	var alive = party.filter(func(p) -> bool: return p.alive())
	if alive.is_empty():
		return null
	if player.alive() and randf() < 0.45:
		return player
	alive.sort_custom(func(a, b) -> bool: return abs(a.x - e.x) < abs(b.x - e.x))
	return alive[0] if randf() < 0.7 else alive[randi() % alive.size()]


# ------------------------------------------------------------ 攻撃の解決
func apply_hit(att: Fighter, tgt: Fighter, spec: Dictionary, power: float, ranged: bool, dir_override: int = 0) -> void:
	if ended and tgt.team == 0:
		return
	if tgt.held:
		return
	var magic: bool = spec.get("kind", "") == "spell" or spec.get("magic_attack", false) or spec.get("magic", false)
	var A: float = (att.matk if magic else att.atk) * att.stat_mult("matk" if magic else "atk")
	var D: float = (tgt.mdef if magic else tgt.def) * tgt.stat_mult("mdef" if magic else "def")
	var dmg: float = max(A * 2.0 - D, A * 0.35) * power
	var dir = dir_override if dir_override != 0 else int(sign(tgt.x - att.x))
	if dir == 0:
		dir = att.facing
	var label_extra = ""
	var crit = false
	if att.team == 0:
		dmg *= Game.bmod("damage_mult")
		if att.h > 20.0:
			dmg *= Game.bmod("air_power_mult")
		if att.hp_ratio() < 0.3:
			dmg *= 1.0 + Game.bmod("low_hp_power")
		var dead_n = party.filter(func(p) -> bool: return not p.alive()).size()
		if dead_n > 0:
			dmg *= 1.0 + Game.bmod("vengeance")
		var cr = 0.05 + att.agi * 0.002 + Game.bmod("crit") + (0.1 if att.skills.has("crit_up") else 0.0)
		if randf() < cr:
			crit = true
			dmg *= 1.5
		if spec.get("link", false):
			dmg = max(dmg, A * power * 1.2)
		if spec.has("pct"):
			# 秘奥義は最大HPの一定割合を保証する（雑魚には3倍）
			dmg = max(dmg, tgt.max_hp * spec["pct"] * (1.0 if tgt.data.get("boss", false) else 3.0))
	else:
		dmg *= Game.bmod("taken_mult")
		if Game.flags.get("red_cape", false) and tgt.cid == "ren":
			dmg *= 0.45
	var el: String = spec.get("element", "")
	if el != "":
		if el in tgt.weak:
			dmg *= 1.5 + Game.bmod("weak_bonus")
			label_extra = "WEAK"
			if not events_fired.has("weak") and att.team == 0:
				events_fired["weak"] = true
				chat("weak", {"who": att.cid})
		elif el in tgt.resist:
			dmg *= 0.5
			label_extra = "RESIST"
	dmg *= randf_range(0.92, 1.08)
	var idmg = int(max(1.0, round(dmg)))

	# ガード判定
	var guarding = tgt.state == "guard" and (tgt.facing == -dir or spec.get("guardable", false))
	if tgt.team == 1 and tgt.guard_rate > 0.0 and tgt.state in ["idle", "move"] and tgt.facing == -dir and randf() < tgt.guard_rate * 0.5:
		guarding = true
	if guarding and not spec.get("link", false):
		# 当たる直前に構えたらパリィ（スキル「ジャストガード」で受付が広がる）
		var parry_w: float = PARRY_WINDOW * (1.6 if tgt.skills.has("perfect_guard") else 1.0)
		var just: bool = tgt.team == 0 and att.team == 1 and time - tgt.guard_pressed_at < parry_w
		if just:
			idmg = 0
			on_parry(tgt, att)
		else:
			var gm = 0.2 * Game.bmod("guard_mult") if tgt.team == 0 else 0.3
			if spec.get("guardable", false) and tgt.team == 0:
				gm = 0.15 * Game.bmod("guard_mult")
			idmg = int(max(1, idmg * gm))
			if tgt.team == 0:
				tgt.tp = min(tgt.max_tp, tgt.tp + Game.bmod("guard_tp"))
			Sfx.play("guard")
			popup_text(tgt.head(), "GUARD", Color(0.6, 0.85, 1.0), 18)
		spawn_fx("guard", tgt.center() + Vector2(-dir * 20, 0), Color(0.6, 0.85, 1.0))
		tgt.vx = dir * 120.0
		if idmg > 0:
			if tgt.holds_at_one() and tgt.hp - idmg < 1.0:
				tgt.hp = 1.0
				on_boss_held(tgt)
				return
			tgt.hp = max(1.0 if tgt.team == 0 and tgt.hp > 1 else 0.0, tgt.hp - idmg)
			_dmg_number(tgt, idmg, false, "", tgt.team == 0)
			if tgt.hp <= 0.0:
				tgt.die(dir)
		return

	var knock: float = spec.get("knock", 60.0)
	var launch: float = spec.get("launch", 0.0)
	var heavy: bool = power >= 2.0 or knock >= 250.0 or crit
	if tgt.team == 1 and tgt.data.get("boss", false):
		launch *= 0.4
		knock *= 0.5
	if tgt == player and att.team == 1:
		ren_hurt_this_turn = true
	tgt.take_hit(idmg, knock, launch, dir, spec.get("stun", 1.0), heavy)
	_dmg_number(tgt, idmg, crit, label_extra, tgt.team == 0)
	var sc = Color(1, 0.95, 0.7) if att.team == 0 else Color(1, 0.5, 0.4)
	spawn_fx("crit" if crit else "spark", tgt.center() + Vector2(-dir * 10, randf_range(-12, 12)), spec.get("color", sc), 1.3 if heavy else 1.0)
	Sfx.play("hit_heavy" if heavy else "hit", 1.0 + randf() * 0.15, -2 if heavy else -5)
	hitstop = max(hitstop, 0.08 if heavy else 0.035)
	if heavy:
		shake(0.4)

	if att.team == 0:
		combo_hits += 1
		combo_dmg += idmg
		combo_t = 1.6
		max_combo = max(max_combo, combo_hits)
		var gain = LINK_PER_HIT * Game.bmod("link_gain_mult")
		var lh: Array = last_hitter.get(tgt, [])
		if not lh.is_empty() and lh[0] != att and time - lh[1] < 1.2:
			gain += LINK_PER_CHAIN * Game.bmod("link_gain_mult")
			if randf() < 0.12:
				popup_text(tgt.head() + Vector2(0, -40), "連携！", Color(1.0, 0.75, 0.9), 22)
		last_hitter[tgt] = [att, time]
		var before = link
		link = min(100.0, link + gain)
		if before < 100.0 and link >= 100.0:
			Sfx.play("link", 1.5, -6)
			chat("link_ready", {})
			if gauge_probe:
				link_fills += 1
				link = 0.0
		if not spec.get("link", false):
			if att == player:
				add_ovl(OVL_PER_HIT)
			if ovl_t > 0.0:
				add_mystic(MYSTIC_PER_HIT)
		if spec.get("normal", false):
			att.tp = min(att.max_tp, att.tp + 1.0 + Game.bmod("tp_on_hit"))
		if combo_hits == 20:
			Game.award_title("combo20", "")
		if combo_hits == 50:
			Game.award_title("combo50", "")
		if combo_hits in [15, 30]:
			chat("big_combo", {"who": att.cid})
	else:
		if tgt == player:
			add_ovl(OVL_PER_DAMAGE)
		if tgt.alive() and tgt.hp_ratio() < 0.3 and not events_fired.has("low_" + tgt.cid):
			events_fired["low_" + tgt.cid] = true
			chat("low_hp", {"who": tgt.cid})


func _dmg_number(tgt: Fighter, n: int, crit: bool, extra: String, ally: bool) -> void:
	var col = Color(1.0, 1.0, 1.0)
	if ally:
		col = Color(1.0, 0.45, 0.4)
	elif crit:
		col = Color(1.0, 0.85, 0.3)
	var p = tgt.head() + Vector2(randf_range(-20, 20), randf_range(-10, 4))
	popup_text(p, str(n), col, 30 if crit else 24, true)
	if crit:
		popup_text(p + Vector2(0, -28), "CRITICAL", Color(1, 0.8, 0.3), 16)
	if extra != "":
		popup_text(p + Vector2(0, -28), extra, Color(0.6, 1.0, 0.6) if extra == "WEAK" else Color(0.7, 0.7, 0.8), 18)


func resolve_spell(caster: Fighter, aid: String, tgt: Fighter) -> void:
	var a: Dictionary = DB.arte(aid).duplicate()
	a["arte_id"] = aid
	match a["kind"]:
		"spell":
			if a.has("aoe"):
				var tx: float = tgt.x if tgt else caster.x + caster.facing * 300
				spawn_aoe(caster, a, tx, a.get("power", 1.0))
			elif a.has("projectile"):
				var p: Dictionary = a["projectile"]
				for i in range(p.get("count", 1)):
					pending.append([i * p.get("interval", 0.1), caster, a, a.get("power", 1.0)])
			Sfx.play("magic")
		"heal":
			var amt: float = caster.matk * a["heal"] * 2.6 * Game.bmod("heal_mult")
			var targets: Array = []
			if a.get("all", false):
				targets = party.filter(func(p) -> bool: return p.alive())
			else:
				targets = [tgt]
			for t in targets:
				if t == null:
					continue
				if a.get("revive", false) and not t.alive():
					t.revive(a["heal"])
					popup_text(t.head(), "復活！", Color(1.0, 1.0, 0.6), 26)
					chat("revive", {"who": t.cid, "by": caster.cid})
				else:
					t.heal(amt)
					popup_text(t.head(), "+%d" % int(amt), Color(0.5, 1.0, 0.6), 24, true)
					if t != caster and randf() < 0.35:
						chat("healed", {"who": t.cid, "by": caster.cid})
				spawn_fx("heal", t.center() + Vector2(0, 20), a.get("color", Color(0.5, 1, 0.6)))
			Sfx.play("heal")
			if caster.cid == "sona":
				Game.count("heals_sona")
		"support":
			var b: Dictionary = a["buff"]
			for t2 in party:
				if t2.alive():
					t2.add_buff(b["stat"], b["mult"], b["time"])
					spawn_fx("buff", t2.center(), a.get("color", Color(0.6, 0.8, 1)))
			Sfx.play("heal", 0.8)


func spawn_projectile(f: Fighter, spec: Dictionary, power: float) -> void:
	var p = Projectile.new()
	p.setup(self, f, spec, power)
	layer_fx.add_child(p)
	projectiles.append(p)


func spawn_aoe(f: Fighter, spec: Dictionary, x: float, power: float) -> void:
	var a = AoE.new()
	a.setup(self, f, spec, x, power)
	layer_fx.add_child(a)
	aoes.append(a)


func spawn_fx(k: String, pos: Vector2, c: Color, s: float = 1.0) -> void:
	var fx = Fx.new()
	fx.setup(k, pos, c, s)
	layer_fx.add_child(fx)
	fxs.append(fx)


func popup_text(pos: Vector2, text: String, col: Color, size: int = 22, bounce: bool = false) -> void:
	var l = UI.outlined(UI.label(text, size, col, true), 5)
	l.position = pos - Vector2(text.length() * size * 0.3, size)
	l.z_index = 20
	layer_fx.add_child(l)
	var tw = l.create_tween()
	if bounce:
		tw.tween_property(l, "position:y", l.position.y - 26, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", l.position.y - 16, 0.12).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.35)
	else:
		tw.tween_property(l, "position:y", l.position.y - 30, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func shake(a: float) -> void:
	shake_amt = max(shake_amt, a)


func flash(c: Color) -> void:
	flash_col = c


# ------------------------------------------------------------ 通知
func on_arte_used(f: Fighter, name: String, level: int) -> void:
	if f == player:
		hud.show_arte_name(name, level)
	else:
		var col = Color(0.8, 0.9, 1.0) if f.team == 0 else Color(1.0, 0.6, 0.55)
		var lbl = UI.outlined(UI.label(name, 18, col, true), 5)
		lbl.position = f.head() + Vector2(-name.length() * 9, -60)
		lbl.z_index = 15
		layer_fx.add_child(lbl)
		var tw = lbl.create_tween()
		tw.tween_interval(0.7)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
		tw.tween_callback(lbl.queue_free)


func on_break(f: Fighter) -> void:
	_tutorial("break")
	spawn_fx("break", f.center(), Color(1.0, 0.85, 0.4), 1.0)
	popup_text(f.head() + Vector2(0, -40), "BREAK!", Color(1.0, 0.85, 0.3), 34, true)
	Sfx.play("explode", 1.4)
	hitstop = 0.15
	shake(0.6)
	if f.data.get("boss", false):
		chat("break", {})


func on_boss_phase(f: Fighter) -> void:
	popup_text(f.head() + Vector2(0, -60), "本気モード", Color(1.0, 0.3, 0.3), 30, true)
	flash(Color(1, 0.2, 0.2, 0.35))
	Sfx.play("warn")
	chat("boss_phase", {"boss": f.cid})


func boss_warning(f: Fighter, text: String) -> void:
	# 予告は画面の文字ではなく、仲間の声で伝える
	Sfx.play("warn")
	callout("jump" if ("跳" in text or "飛" in text) else "guard", f)


func on_death(f: Fighter) -> void:
	if f.team == 1:
		Sfx.play("down", 0.8)
		spawn_fx("ring", f.center(), Color(1, 1, 1), 1.5)
		var kh = Game.bmod("kill_heal")
		if kh > 0.0:
			for p in party:
				if p.alive():
					p.heal(p.max_hp * kh)
					spawn_fx("heal", p.center(), Color(1.0, 0.6, 0.6))
		if enemies.filter(func(e) -> bool: return e.alive()).size() > 0 and randf() < 0.3:
			chat("kill", {})
		if player_target == f:
			player_target = nearest_enemy(player)
		hitstop = 0.12
	else:
		Sfx.play("down")
		popup_text(f.head(), "戦闘不能", Color(1, 0.4, 0.4), 22)
		chat("ally_ko", {"who": f.cid})
		if Game.bmod("phoenix") > 0.0 and not phoenix_used:
			phoenix_used = true
			await get_tree().create_timer(1.2).timeout
			if is_instance_valid(f) and not f.alive() and not ended:
				f.revive(0.5)
				spawn_fx("heal", f.center(), Color(1.0, 0.6, 0.2))
				popup_text(f.head(), "不死鳥の加護！", Color(1.0, 0.7, 0.3), 24, true)
				Sfx.play("heal")


func _end_combo() -> void:
	if combo_hits >= 10:
		hud.show_combo_end(combo_hits, combo_dmg)
	combo_hits = 0
	combo_dmg = 0


# ------------------------------------------------------------ 共鳴秘技
# 共鳴秘技の相手は、戦える仲間からランダムに選ぶ
func link_partner() -> String:
	var cands: Array = []
	for p in party:
		if p != player and p.alive():
			cands.append(p.cid)
	if cands.is_empty():
		return "nine" if companions.nine_visible else ""
	return cands[randi() % cands.size()]


func try_link() -> void:
	if link < 100.0 or frozen or not player.alive() or ended:
		return
	var partner = link_partner()
	if partner == "":
		return
	var key = DB.pair_key("ren", partner)
	var ld: Dictionary = DB.Links.DATA.get(key, {})
	if ld.is_empty():
		return
	frozen = true
	link = 0.0
	if is_instance_valid(chat_bubble):
		chat_bubble.queue_free()
	chat_t = 0.0
	for p in party:
		p.invul = max(p.invul, 3.0)
	Sfx.play("link")
	await hud.play_link_cutin("ren", partner, ld)
	if not is_inside_tree():
		return
	frozen = false
	var spec = {"aoe": {"w": 1400, "h": 700, "delay": 0.05, "hits": ld.get("hits", 8), "interval": 0.08, "shape": ld.get("shape", "burst"), "at_self": true},
		"power": ld.get("power", 6.0) / ld.get("hits", 8), "color": ld.get("color", Color(1, 0.8, 0.4)), "link": true, "knock": 40, "launch": 200,
		"element": ld.get("element", "")}
	spawn_aoe(player, spec, 640, spec["power"])
	flash(Color(1, 1, 1, 0.8))
	shake(1.0)
	Game.award_title("link_first", "")
	if partner != "nine":
		Game.add_bond("ren", partner, 2)
	Game.count("links")
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and not ended:
		chat("link_used", {"who": partner})


# ------------------------------------------------------------ オーバーリミッツと秘奥義
func mystic_gauge() -> float:
	return float(Game.flags.get("mystic_gauge", 0.0))


func add_mystic(v: float) -> void:
	var before = mystic_gauge()
	var after = min(300.0, before + v)
	Game.flags["mystic_gauge"] = after
	if int(before / 100.0) < int(after / 100.0):
		popup_text(player.head() + Vector2(0, -50), "秘奥義ゲージ %d%%" % (int(after / 100.0) * 100), Color(1.0, 0.5, 0.45), 20, true)
		Sfx.play("link", 1.8, -8)


func add_ovl(v: float) -> void:
	if ovl_t > 0.0 or ended:
		return
	var before = ovl
	ovl = min(100.0, ovl + v * Game.bmod("link_gain_mult"))
	if before < 100.0 and ovl >= 100.0:
		Sfx.play("link", 1.3, -6)
		chat("ovl_ready", {})
		if gauge_probe:
			ovl_fills += 1
			ovl = 0.0


func _press_overlimit() -> void:
	if player == null or not player.alive():
		return
	if ovl_t > 0.0:
		if mystic_gauge() >= 100.0:
			fire_mystic()
		else:
			popup_text(player.head() + Vector2(0, -30), "秘奥義ゲージが足りない", Color(1.0, 0.6, 0.6), 18)
	elif ovl >= 100.0:
		start_ovl()
	else:
		popup_text(player.head() + Vector2(0, -30), "OVLゲージが足りない", Color(0.8, 0.8, 0.9), 16)


func start_ovl() -> void:
	ovl = 0.0
	ovl_t = OVL_TIME
	if player.state == "hit":
		player.hitstun = 0.0
		player.set_state("idle" if player.on_ground() else "jump")
	player.invul = max(player.invul, 0.4)
	hitstop = 0.25
	flash(Color(1.0, 0.85, 0.4, 0.7))
	shake(0.5)
	Sfx.play("link", 0.8)
	spawn_fx("break", player.center(), Color(1.0, 0.85, 0.4), 1.4)
	hud.show_banner("OVER LIMIT!", Color(1.0, 0.85, 0.35))
	chat("ovl", {})


func fire_mystic() -> void:
	if frozen or ended:
		return
	var level: int = min(3, int(mystic_gauge() / 100.0))
	var cands: Array = []
	for p in party:
		if p != player and p.alive():
			cands.append(p.cid)
	cands.shuffle()
	var allies: Array = cands.slice(0, level - 1)
	level = 1 + allies.size()
	Game.flags["mystic_gauge"] = mystic_gauge() - level * 100.0
	ovl_t = 0.0
	var md: Dictionary = DB.Mystics.pick(level, allies)
	var total_pct: float = [0.0, 0.16, 0.26, 0.40][level]
	frozen = true
	if is_instance_valid(chat_bubble):
		chat_bubble.queue_free()
	chat_t = 0.0
	for p in party:
		p.invul = max(p.invul, 6.0)
	Sfx.play("link", 0.6)
	await hud.play_mystic_cutin(md)
	if not is_inside_tree():
		return
	frozen = false
	# 参加した仲間が順に一撃ずつ入れ、最後に全員の大技
	var members: Array = md["members"]
	var waves = members.size() + 1
	var total_hits: int = md.get("hits", 14)
	var shapes = ["burst", "spikes", "storm"]
	for i in range(members.size()):
		var cid: String = members[i]
		var col: Color = DB.ccolor(cid).lightened(0.25)
		var h_i: int = max(3, total_hits / waves)
		var spec = {"aoe": {"w": 1400, "h": 700, "delay": 0.02, "hits": h_i, "interval": 0.05, "shape": shapes[i % shapes.size()], "at_self": true},
			"power": md["power"] / waves / h_i, "color": col, "link": true, "knock": 30, "launch": 160, "element": md.get("element", ""),
			"pct": total_pct / waves / h_i}
		spawn_aoe(player, spec, 640, spec["power"])
		popup_text(speaker_pos(cid) + Vector2(0, -40), DB.cname(cid), col, 22, true)
		flash(Color(col.r, col.g, col.b, 0.55))
		shake(0.7)
		Sfx.play("explode", 1.0 + i * 0.15)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree() or ended:
			return
	var hf: int = max(6, total_hits - (total_hits / waves) * members.size())
	var fin = {"aoe": {"w": 1400, "h": 700, "delay": 0.05, "hits": hf, "interval": 0.06, "shape": md.get("shape", "pillar"), "at_self": true},
		"power": md["power"] / waves / hf, "color": md.get("color", Color(1, 0.4, 0.3)), "link": true, "knock": 50, "launch": 260,
		"element": md.get("element", ""), "pct": total_pct / waves / hf}
	spawn_aoe(player, fin, 640, fin["power"])
	flash(Color(1, 1, 1, 0.9))
	shake(1.4)
	slowmo = 0.35
	slowmo_t = 0.7
	Sfx.play("explode", 0.7)
	Game.award_title("mystic_first", "")
	Game.count("mystics")
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree() and not ended:
		chat("mystic_used", {"who": allies[0] if not allies.is_empty() else "ren"})


# ------------------------------------------------------------ ボスのとどめ
func on_boss_held(f: Fighter) -> void:
	if f.held:
		return
	f.held = true
	f.act = {}
	f.cast_id = ""
	f.break_t = 0.0
	f.vx = 0.0
	f.set_state("down")
	f.down_t = 9999.0
	f.invul = 9999.0
	finish_target = f
	finish_auto_t = 0.0
	hitstop = 0.3
	slowmo = 0.4
	slowmo_t = 0.8
	flash(Color(1, 1, 1, 0.6))
	shake(0.8)
	Sfx.play("explode", 0.9)
	popup_text(f.head() + Vector2(0, -50), "FINISH CHANCE!", Color(1.0, 0.85, 0.3), 30, true)
	_tutorial("finisher")


func fire_finisher() -> void:
	var f: Fighter = finish_target
	if f == null or not is_instance_valid(f) or frozen or ended:
		return
	finish_target = null
	finishing = true
	var fd: Dictionary = DB.Finishers.DATA[f.cid].duplicate()
	fd["header"] = "FINISH"
	frozen = true
	if is_instance_valid(chat_bubble):
		chat_bubble.queue_free()
	chat_t = 0.0
	chat_queue.clear()
	for p in party:
		p.invul = max(p.invul, 4.0)
	Sfx.play("link", 0.6)
	await hud.play_mystic_cutin(fd)
	if not is_inside_tree():
		return
	frozen = false
	# 大きな斬撃でとどめ
	var col: Color = fd.get("color", Color(1, 0.4, 0.3))
	for i in range(5):
		spawn_fx("crit", f.center() + Vector2(randf_range(-40, 40), randf_range(-50, 30)), col, 2.2)
		spawn_fx("break", f.center(), col.lightened(0.3), 1.6)
		flash(Color(col.r, col.g, col.b, 0.5))
		shake(0.9)
		Sfx.play("hit_heavy", 0.8 + i * 0.1)
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
	flash(Color(1, 1, 1, 0.95))
	slowmo = 0.3
	slowmo_t = 1.0
	Sfx.play("explode", 0.6)
	f.held = false
	f.invul = 0.0
	f.hp = 0.0
	_dmg_number(f, int(f.max_hp * 0.1) + 999, true, "FINISH", false)
	f.die(-player.facing if player else 1)
	finishing = false


# ------------------------------------------------------------ ショートチャット
func chat(event: String, ctx: Dictionary) -> void:
	if not DB.Chats.DATA.has(event):
		return
	if chat_cd > 0.0 and event not in ["start", "start_boss", "victory", "boss_phase", "ally_ko", "analysis", "link_used", "ovl", "mystic_used"]:
		return
	var cands: Array = []
	var list: Array = DB.Chats.DATA[event]
	for i in range(list.size()):
		var c: Dictionary = list[i]
		var cid_key = "%s_%d" % [event, i]
		if chat_used.has(cid_key):
			continue
		if not _chat_ok(c, ctx):
			continue
		cands.append([cid_key, c])
	if cands.is_empty():
		return
	# 最近使った会話は避ける
	var recent: Array = Game.flags.get("_chat_recent", [])
	var fresh = cands.filter(func(x) -> bool: return not x[0] in recent)
	if not fresh.is_empty():
		cands = fresh
	# 層やフラグ条件つきの会話（物語に沿ったもの）を優先
	var special = cands.filter(func(x) -> bool: return x[1].has("floor") or x[1].has("flags") or x[1].has("who"))
	if not special.is_empty() and randf() < 0.75:
		cands = special
	var pick: Array = cands[randi() % cands.size()]
	chat_used[pick[0]] = true
	recent.append(pick[0])
	if recent.size() > 40:
		recent.pop_front()
	Game.flags["_chat_recent"] = recent
	for line in pick[1]["lines"]:
		chat_queue.append(line)
	chat_cd = 5.0


func _chat_ok(c: Dictionary, ctx: Dictionary) -> bool:
	for sp in c.get("req", []):
		if not _speaker_present(sp):
			return false
	for line in c["lines"]:
		if not _speaker_present(line[0]):
			return false
	if c.has("who") and c["who"] != ctx.get("who", ""):
		return false
	if c.has("by") and c["by"] != ctx.get("by", ""):
		return false
	if c.has("boss") and c["boss"] != ctx.get("boss", ""):
		return false
	if c.has("floor") and c["floor"] != Game.floor_num:
		return false
	if c.has("floor_min") and Game.floor_num < c["floor_min"]:
		return false
	if c.has("floor_max") and Game.floor_num > c["floor_max"]:
		return false
	for f in c.get("flags", []):
		if not Game.flags.get(f, false):
			return false
	for f in c.get("not_flags", []):
		if Game.flags.get(f, false):
			return false
	return true


func _speaker_present(sp: String) -> bool:
	if sp == "nine":
		return companions.nine_visible
	if sp == "pots":
		return companions.pots_visible
	for p in party:
		if p.cid == sp:
			return p.alive() or ended
	for e in enemies:
		if DB.Characters.DATA.has(sp) and HudScript.officer_of(e.cid) == sp:
			return true
	return false


func _tick_chat(delta: float) -> void:
	if frozen:
		return
	chat_cd = max(0.0, chat_cd - delta)
	if chat_t > 0.0:
		chat_t -= delta
		if is_instance_valid(chat_bubble):
			var anchor = speaker_pos(chat_speaker)
			chat_bubble.position = anchor - Vector2(chat_bubble.size.x / 2.0, chat_bubble.size.y + 8) + world.position
			chat_bubble.position.x = clamp(chat_bubble.position.x, 8, 1272 - chat_bubble.size.x)
			chat_bubble.position.y = max(chat_bubble.position.y, 120)
		if chat_t <= 0.0 and is_instance_valid(chat_bubble):
			chat_bubble.queue_free()
		return
	if chat_queue.is_empty():
		return
	var line: Array = chat_queue.pop_front()
	chat_speaker = line[0]
	var text: String = line[1]
	if not _speaker_present(chat_speaker) and not ended:
		return
	chat_bubble = hud.make_bubble(chat_speaker, text)
	chat_t = clamp(1.3 + text.length() * 0.07, 1.8, 4.0)
	Sfx.play("chat", 1.0 if chat_speaker != "nine" else 1.3, -6)


func speaker_pos(sp: String) -> Vector2:
	if sp == "nine":
		return companions.nine_pos() + Vector2(0, -70)
	if sp == "pots":
		return companions.pots_pos() + Vector2(0, -30)
	for p in party:
		if p.cid == sp:
			return p.head() + Vector2(0, -16)
	for e in enemies:
		if HudScript.officer_of(e.cid) == sp:
			return e.head() + Vector2(0, -16)
	return Vector2(640, 200)


# 戦闘中、手が空いたときの仲間どうしのかけあい
func _tick_banter(dt: float) -> void:
	banter_t -= dt
	if banter_t <= 0.0:
		banter_t = randf_range(11.0, 17.0)
		if chat_t <= 0.0 and chat_queue.is_empty():
			chat("banter", {})


func _tick_cheer(dt: float) -> void:
	if not companions.nine_visible:
		return
	cheer_t -= dt
	if cheer_t <= 0.0:
		cheer_t = randf_range(13.0, 20.0)
		link = min(100.0, link + LINK_PER_CHEER * Game.bmod("link_gain_mult"))
		companions.cheer()
		popup_text(companions.nine_pos() + Vector2(0, -100), "応援！ 絆+", Color(1.0, 0.7, 0.4), 16)
		if chat_t <= 0.0 and chat_queue.is_empty():
			chat("cheer", {})


func _check_analysis() -> void:
	# ポッツの敵解析：初めて見る敵の弱点を教えてくれる
	if not companions.pots_visible:
		return
	for e in enemies:
		var key = "analyzed_" + e.cid
		if Game.flags.get(key, false):
			continue
		Game.flags[key] = true
		var w: Array = e.weak
		var txt = "解析完了。%s" % e.display_name
		if w.size() > 0:
			var names: Array = []
			for el in w:
				names.append(DB.ELEMENT_NAME.get(el, el))
			txt += "の弱点は「%s」属性です。" % "・".join(names)
		else:
			txt += "に明確な弱点はありません。"
		chat_queue.append(["pots", txt])
		return


func _check_events() -> void:
	if not events_fired.has("pinch") and player.alive() and player.hp_ratio() < 0.25:
		events_fired["pinch"] = true
		chat("pinch", {})


# ------------------------------------------------------------ 決着
func _check_end() -> void:
	var foes_alive = enemies.filter(func(e) -> bool: return e.alive()).size()
	var allies_alive = party.filter(func(p) -> bool: return p.alive()).size()
	if foes_alive == 0:
		_victory()
	elif allies_alive == 0:
		_defeat()


func _victory() -> void:
	ended = true
	slowmo = 0.25
	slowmo_t = 0.9
	Sfx.play("explode", 0.7)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	for p in party:
		if p.alive():
			p.set_state("win")
			p.act = {}
	projectiles.map(func(p) -> void: p.queue_free())
	projectiles.clear()
	# 報酬
	var exp = 0
	var gald = 0
	var drops: Array = []
	for e in enemies:
		exp += int(e.data.get("exp", 10) * DB.floor_data(Game.floor_num)["scale"])
		gald += int(e.data.get("gald", 10) * DB.floor_data(Game.floor_num)["scale"])
		if randf() < (0.35 if not e.data.get("boss", false) else 1.0):
			drops.append(["apple_gel", "orange_gel", "apple_gel", "lemon_gel", "mixed_gel", "life_bottle"][randi() % (4 if Game.floor_num < 3 else 6)])
	if kind == "elite":
		exp = int(exp * 1.4)
		gald = int(gald * 1.5)
	gald = int(gald * Game.bmod("gald_mult"))
	# HP/TP を書き戻す
	var meal_heal = Game.bmod("meal_heal")
	var no_damage = true
	for p in party:
		if p.hurt_this_battle:
			no_damage = false
		var m = Game.member(p.cid)
		if not p.alive():
			m["hp"] = 1
		else:
			m["hp"] = int(min(p.max_hp, p.hp + p.max_hp * meal_heal))
		m["tp"] = int(p.tp)
	Game.add_gald(gald)
	for d in drops:
		Game.add_item(d)
	var ups = Game.gain_exp(exp)
	Game.consume_meal()
	Game.count("battles")
	Game.award_title("first_victory", "")
	if no_damage and enemies.size() >= 2:
		Game.award_title("no_damage", "")
	rewards = {"exp": exp, "gald": gald, "drops": drops, "ups": ups, "combo": max_combo, "time": time}
	chat_queue.clear()
	chat_t = 0.0
	if is_instance_valid(chat_bubble):
		chat_bubble.queue_free()
	hud.show_results(rewards)
	chat("victory_boss" if kind == "boss" else "victory", {})
	if ups.size() > 0:
		Sfx.play("levelup")


func finish_victory() -> void:
	Main.inst.goto("map", {"after_battle": kind, "won": true})


func _defeat() -> void:
	ended = true
	slowmo = 0.3
	slowmo_t = 1.2
	hud.show_banner("全滅……", Color(0.8, 0.3, 0.3))
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		Main.inst.goto("gameover", {})


func escape() -> void:
	ended = true
	for p in party:
		var m = Game.member(p.cid)
		m["hp"] = int(p.hp) if p.alive() else 1
		m["tp"] = int(p.tp)
	Main.inst.goto("map", {"after_battle": kind, "won": false, "escaped": true})


func use_item(item_id: String, tgt: Fighter) -> bool:
	var it: Dictionary = DB.item(item_id)
	if Game.use_item_count(item_id) <= 0:
		return false
	if it.has("revive"):
		if tgt.alive():
			return false
		tgt.revive(it["revive"])
	else:
		if not tgt.alive():
			return false
		if it.has("hp"):
			tgt.heal(tgt.max_hp * it["hp"])
		if it.has("tp"):
			tgt.tp = min(tgt.max_tp, tgt.tp + tgt.max_tp * it["tp"])
	Game.remove_item(item_id)
	spawn_fx("heal", tgt.center(), Color(0.9, 0.6, 0.6))
	popup_text(tgt.head(), it["name"], Color(1.0, 0.9, 0.7), 20)
	Sfx.play("heal")
	if chat_t <= 0.0 and chat_queue.is_empty():
		chat("item", {"who": tgt.cid})
	return true


# ------------------------------------------------------------ ターン制
func _tick_turn(dt: float) -> void:
	if frozen:
		return
	counter_t = max(0.0, counter_t - dt)
	if finish_target:
		# とどめ待ちのあいだはこちらのターンのまま止める
		if turn != "party":
			_start_party_turn()
		return
	if turn == "party":
		turn_t -= dt
		if turn_t <= 0.0:
			var busy: bool = player and player.alive() and player.state in ["act", "cast", "link"]
			if busy and turn_t > -PARTY_TURN_GRACE:
				return
			_start_enemy_turn()
		return
	enemy_turn_t += dt
	if enemy_turn_t > ENEMY_TURN_LIMIT:
		_start_party_turn()
		return
	if turn_actor == null or not is_instance_valid(turn_actor) or not turn_actor.alive() or turn_actor.break_t > 0.0:
		_next_actor()
		return
	if turn_actor.state == "act":
		actor_attacked = true
		actor_wait = 0.0
	elif actor_attacked and turn_actor.state != "hit":
		actor_wait += dt
		if actor_wait > 0.45:
			enemy_queue[0][1] -= 1
			actor_attacked = false
			actor_wait = 0.0
			if enemy_queue[0][1] <= 0:
				_next_actor()
			else:
				turn_actor.ai_t = 0.2
	elif actor_attacked and turn_actor.state == "hit":
		# カウンターで崩された敵は、そこで攻撃をやめる
		actor_wait += dt
		if actor_wait > 1.2:
			_next_actor()


func _start_enemy_turn() -> void:
	turn = "enemy"
	enemy_turn_t = 0.0
	enemy_queue.clear()
	ren_hurt_this_turn = false
	enemy_attacks_this_turn = 0
	var alive: Array = enemies.filter(func(e) -> bool: return e.alive() and not e.held)
	alive.sort_custom(func(a, b) -> bool: return a.x < b.x)
	for e in alive:
		var n := 1
		if e.data.get("boss", false):
			n = 2 + (1 if e.phase_level() >= 2 else 0)
		elif kind == "elite" and alive.size() == 1:
			n = 2
		enemy_queue.append([e, n])
	hud.show_banner("ENEMY TURN", Color(1.0, 0.45, 0.4))
	_tutorial("enemy_turn")
	Sfx.play("warn", 1.3, -8)
	turn_actor = null
	_next_actor(true)


func _next_actor(first: bool = false) -> void:
	if not first and not enemy_queue.is_empty():
		enemy_queue.pop_front()
	while not enemy_queue.is_empty():
		var e: Fighter = enemy_queue[0][0]
		if is_instance_valid(e) and e.alive() and e.break_t <= 0.0 and not e.held:
			break
		enemy_queue.pop_front()
	if enemy_queue.is_empty():
		_start_party_turn()
		return
	turn_actor = enemy_queue[0][0]
	turn_actor.target = enemy_pick_target(turn_actor)
	turn_actor.ai_t = 0.5 if first else 0.25
	actor_attacked = false
	actor_wait = 0.0


func _start_party_turn() -> void:
	var was_enemy := turn == "enemy"
	turn = "party"
	turn_actor = null
	enemy_queue.clear()
	if not was_enemy:
		return
	turn_no += 1
	turn_t = PARTY_TURN_TIME
	if enemy_attacks_this_turn > 0 and not ren_hurt_this_turn and player and player.alive():
		turn_t += PERFECT_BONUS
		popup_text(player.head() + Vector2(0, -50), "PERFECT DEFENSE!  ターン+%d秒" % int(PERFECT_BONUS), Color(0.6, 1.0, 1.0), 24, true)
		callout("perfect", null)
	hud.show_banner("YOUR TURN", Color(0.6, 0.9, 1.0))
	Sfx.play("confirm", 1.2, -6)


func is_enemy_turn() -> bool:
	return turn == "enemy" and started and not ended


# 敵のターンに攻撃してよい敵か
func may_attack(e: Fighter) -> bool:
	return is_enemy_turn() and e == turn_actor and not actor_attacked


# 敵のターンにステップの無敵で攻撃をかわした
func on_dodge(f: Fighter) -> void:
	if time - f.dodged_at < 0.6:
		return
	f.dodged_at = time
	popup_text(f.head(), "回避！", Color(0.7, 1.0, 0.8), 22, true)
	f.tp = min(f.max_tp, f.tp + 4)
	link = min(100.0, link + 2.0 * Game.bmod("link_gain_mult"))
	if f.is_player:
		slowmo = 0.5
		slowmo_t = 0.25


# 敵が攻撃を始めた瞬間：仲間が声をかけ、敵の頭上に予兆を出す
func on_enemy_telegraph(e: Fighter, at: Dictionary) -> void:
	enemy_attacks_this_turn += 1
	popup_text(e.head() + Vector2(0, -24), "！", Color(1.0, 0.85, 0.3), 40, true)
	if at.has("warn"):
		return  # 大技は boss_warning から声がかかる
	if randf() < 0.75:
		callout(DB.Callouts.kind_of(at), e)


# パリィ成功。レンならカウンターの受付、仲間なら自動で反撃する
func on_parry(tgt: Fighter, att: Fighter) -> void:
	popup_text(tgt.head(), "PARRY!", Color(0.6, 1.0, 1.0), 30, true)
	Sfx.play("guard", 1.6)
	spawn_fx("guard", tgt.center(), Color(0.7, 1.0, 1.0), 1.6)
	hitstop = 0.12
	link = min(100.0, link + 4.0 * Game.bmod("link_gain_mult"))
	tgt.tp = min(tgt.max_tp, tgt.tp + 6)
	if tgt.is_player:
		counter_t = COUNTER_WINDOW
		counter_target = att
		slowmo = 0.35
		slowmo_t = 0.45
		callout("parry", null)
	elif tgt.team == 0 and att.alive():
		callout_from(tgt.cid, "ally_parry")
		_ally_counter(tgt, att, 0.25)


func try_counter() -> bool:
	if counter_t <= 0.0 or counter_target == null or not is_instance_valid(counter_target) or not counter_target.alive():
		return false
	counter_t = 0.0
	var e: Fighter = counter_target
	# 敵の目の前へ踏み込み、渾身の一撃
	var side: int = -1 if player.x < e.x else 1
	player.x = clamp(e.x + side * (e.body.x / 2.0 + 46.0), LEFT + 30, RIGHT - 30)
	player.facing = -side
	player.invul = max(player.invul, 0.6)
	var spec: Dictionary = player.combo[player.combo.size() - 1].duplicate()
	spec["power"] = spec.get("power", 1.0) * 3.0
	spec["stun"] = 2.0
	spec["knock"] = 260
	player._begin_act(spec, 1, "カウンター")
	popup_text(e.head() + Vector2(0, -40), "COUNTER!", Color(1.0, 0.85, 0.3), 34, true)
	flash(Color(1, 0.95, 0.7, 0.35))
	shake(0.4)
	add_ovl(8.0)
	# 近くの仲間が追撃に加わる（連携カウンター）
	var helpers: Array = party.filter(func(p) -> bool: return p != player and p.alive())
	if not helpers.is_empty():
		var h: Fighter = helpers[randi() % helpers.size()]
		callout_from(h.cid, "counter")
		_ally_counter(h, e, 0.35)
	return true


func _ally_counter(h: Fighter, e: Fighter, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(h) or not is_instance_valid(e) or not h.alive() or not e.alive() or ended:
		return
	var ranged := h.role in ["caster", "gunner"]
	if not ranged:
		var side: int = -1 if h.x < e.x else 1
		h.x = clamp(e.x + side * (e.body.x / 2.0 + 50.0), LEFT + 30, RIGHT - 30)
		h.facing = -side
	else:
		h.facing = 1 if e.x > h.x else -1
	spawn_fx("crit" if not ranged else "spark", e.center(), h.data["color"], 1.4)
	apply_hit(h, e, {"power": 1.0, "knock": 180, "stun": 1.4, "counter": true}, 1.6, ranged, h.facing)
	popup_text(e.head() + Vector2(0, -70), "%sの追撃！" % h.display_name, h.data["color"].lightened(0.4), 20)


# ------------------------------------------------------------ 仲間の声（予告・反応）
func callout(kind_key: String, attacker: Fighter) -> void:
	var lines: Dictionary = DB.Callouts.LINES.get(kind_key, {})
	var cands: Array = []
	for p in party:
		if p != player and p.alive() and lines.has(p.cid) and (attacker == null or attacker.target != p):
			cands.append(p.cid)
	if cands.is_empty():
		for p in party:
			if p != player and p.alive() and lines.has(p.cid):
				cands.append(p.cid)
	if cands.is_empty():
		if companions.pots_visible and lines.has("pots"):
			cands.append("pots")
		elif companions.nine_visible and lines.has("nine"):
			cands.append("nine")
	if cands.is_empty():
		return
	callout_from(cands[randi() % cands.size()], kind_key)


func callout_from(sp: String, kind_key: String) -> void:
	var lines: Dictionary = DB.Callouts.LINES.get(kind_key, {})
	if not lines.has(sp) or not _speaker_present(sp):
		return
	var opts: Array = lines[sp]
	var text: String = opts[randi() % opts.size()]
	if is_instance_valid(callout_bubble):
		callout_bubble.queue_free()
	callout_speaker = sp
	callout_bubble = hud.make_bubble(sp, text, true)
	callout_t = 1.6
	Sfx.play("chat", 1.15, -3)


func _tick_callout(delta: float) -> void:
	if callout_t <= 0.0:
		return
	callout_t -= delta
	if is_instance_valid(callout_bubble):
		var anchor = speaker_pos(callout_speaker)
		callout_bubble.position = anchor - Vector2(callout_bubble.size.x / 2.0, callout_bubble.size.y + 8) + world.position
		callout_bubble.position.x = clamp(callout_bubble.position.x, 8, 1272 - callout_bubble.size.x)
		callout_bubble.position.y = max(callout_bubble.position.y, 110)
		if callout_t <= 0.0:
			callout_bubble.queue_free()
