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
var events_fired: Dictionary = {}
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
		scale *= 1.15
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
	_check_analysis()


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
	if started and not ended:
		_tick_cheer(dt)
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


# ターゲット切替・共鳴秘技・仲間への指示。スティックやトリガーも1回押しとして扱うため毎フレーム確認する
func _poll_commands() -> void:
	if not started or ended or paused or frozen:
		return
	if Input.is_action_just_pressed("target"):
		_cycle_target()
	elif Input.is_action_just_pressed("link"):
		try_link()
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
		var just = tgt.skills.has("perfect_guard") and time - tgt.guard_pressed_at < 0.22
		if just:
			idmg = 0
			tgt.tp = min(tgt.max_tp, tgt.tp + 6)
			popup_text(tgt.head(), "JUST GUARD!", Color(0.6, 1.0, 1.0), 24)
			Sfx.play("guard", 1.4)
			hitstop = 0.08
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
		var gain = 0.28 * Game.bmod("link_gain_mult")
		var lh: Array = last_hitter.get(tgt, [])
		if not lh.is_empty() and lh[0] != att and time - lh[1] < 1.2:
			gain += 0.7 * Game.bmod("link_gain_mult")
			if randf() < 0.12:
				popup_text(tgt.head() + Vector2(0, -40), "連携！", Color(1.0, 0.75, 0.9), 22)
		last_hitter[tgt] = [att, time]
		var before = link
		link = min(100.0, link + gain)
		if before < 100.0 and link >= 100.0:
			Sfx.play("link", 1.5, -6)
			chat("link_ready", {})
		if spec.get("normal", false):
			att.tp = min(att.max_tp, att.tp + 1.0 + Game.bmod("tp_on_hit"))
		if combo_hits == 20:
			Game.award_title("combo20", "")
		if combo_hits == 50:
			Game.award_title("combo50", "")
		if combo_hits in [15, 30]:
			chat("big_combo", {"who": att.cid})
	else:
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
	hud.show_warning(text)
	Sfx.play("warn")


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
func link_partner() -> String:
	if Game.flags.get("red_cape", false):
		return "nine"
	var best = ""
	var bb = -1
	for p in party:
		if p == player or not p.alive():
			continue
		var b = Game.get_bond("ren", p.cid) + randi() % 3
		if b > bb:
			bb = b
			best = p.cid
	if best == "":
		best = "nine" if companions.nine_visible else ""
	return best


func try_link() -> void:
	if link < 100.0 or frozen or not player.alive() or ended:
		return
	var partner = link_partner()
	if partner == "":
		return
	var key = DB.pair_key("ren", partner)
	var ld: Dictionary = DB.Links.DATA.get(key, {})
	if Game.flags.get("red_cape", false):
		ld = DB.Links.DATA.get("zettai_red", {})
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


# ------------------------------------------------------------ ショートチャット
func chat(event: String, ctx: Dictionary) -> void:
	if not DB.Chats.DATA.has(event):
		return
	if chat_cd > 0.0 and event not in ["start", "start_boss", "victory", "boss_phase", "ally_ko", "analysis", "link_used"]:
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


func _tick_cheer(dt: float) -> void:
	if not companions.nine_visible:
		return
	cheer_t -= dt
	if cheer_t <= 0.0:
		cheer_t = randf_range(13.0, 20.0)
		link = min(100.0, link + 8.0 * Game.bmod("link_gain_mult"))
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
	return true
