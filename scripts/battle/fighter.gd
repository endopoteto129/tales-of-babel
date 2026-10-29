# 戦闘キャラクター（味方・敵共通）。移動・攻撃・被弾・AIを扱う。
class_name Fighter
extends Node2D

const GRAVITY := 1800.0
const ArtScript := preload("res://scripts/battle/fighter_art.gd")

var battle: Node
var team := 0                 # 0=味方 1=敵
var cid := ""                 # キャラ or 敵ID
var data: Dictionary = {}
var is_player := false
var role := "melee"
var display_name := ""

var max_hp := 100.0
var hp := 100.0
var max_tp := 0.0
var tp := 0.0
var atk := 10.0
var def := 10.0
var matk := 10.0
var mdef := 10.0
var agi := 10.0

var x := 0.0
var h := 0.0                  # 地面からの高さ
var vx := 0.0
var vy := 0.0
var facing := 1
var body := Vector2(48, 96)
var speed := 260.0
var fly_h := 0.0

var state := "idle"
var state_t := 0.0
var act: Dictionary = {}
var act_t := 0.0
var act_level := 0
var act_name := ""
var act_hits: Dictionary = {}
var act_hit_any := false
var act_spawned := 0
var combo_idx := 0
var chain_count := 0
var buffered := ""
var buffer_t := 0.0
var cast_id := ""
var cast_t := 0.0
var cast_time := 0.0
var cast_target: Fighter
var hitstun := 0.0
var invul := 0.0
var armor := 0.0
var armor_max := 0.0
var armor_regen_t := 0.0
var held := false       # HP1で踏みとどまり、とどめ演出を待っているボス
var break_t := 0.0       # ブレイク中の残り時間。終わると装甲が全快する
var resist_t := 0.0      # のけぞらない時間（ブレイク明け・連続被弾の後）
var stun_chain := 0.0    # 敵がのけぞり続けている時間
var stun_free_t := 0.0
const STUN_LIMIT := 3.5
const BREAK_TIME := 3.5
var flash_t := 0.0
var guard_t := 0.0
var guard_pressed_at := -10.0
var down_t := 0.0
var dead := false
var fade := 1.0
var buffs: Dictionary = {}    # stat -> [mult, time]
var target: Fighter
var ai_t := 0.0
var ai_cd := 0.0
var cooldowns: Dictionary = {}
var phase := 0
var warned := false
var arte_slots: Array = []
var combo: Array = []
var skills: Dictionary = {}
var weak: Array = []
var resist: Array = []
var guard_rate := 0.0
var anim_t := 0.0
var landed_t := 0.0
var phoenix_used := false
var air_actions := 0
var shortcut_req := ""
var hurt_this_battle := false
var stun_mult := 1.0
var enemy_speed_mult := 1.0
var dodged_at := -10.0


func setup_party(b: Node, member: Dictionary, player: bool) -> void:
	battle = b
	team = 0
	cid = member["id"]
	data = DB.chara(cid)
	is_player = player
	role = data["role"]
	display_name = data["name"]
	max_hp = Game.max_hp(cid)
	hp = clamp(member["hp"], 0, max_hp)
	max_tp = Game.max_tp(cid)
	tp = clamp(member["tp"], 0, max_tp)
	atk = Game.stat(cid, "atk") * Game.bmod("atk_mult")
	def = Game.stat(cid, "def")
	matk = Game.stat(cid, "matk")
	mdef = Game.stat(cid, "mdef")
	agi = Game.stat(cid, "agi")
	body = Vector2(44, 96) if cid != "john" else Vector2(54, 104)
	speed = 270.0 + agi * 1.5
	combo = data["combo"].duplicate(true)
	for k in ["combo_plus", "perfect_guard", "crit_up", "chain_plus", "fast_cast", "iron_cast", "tp_regen"]:
		if Game.has_skill(cid, k):
			skills[k] = true
	if skills.has("combo_plus"):
		var extra: Dictionary = combo[combo.size() - 2].duplicate(true)
		combo.insert(combo.size() - 1, extra)
	arte_slots = member["slots"].duplicate()
	if hp <= 0:
		hp = 0
		dead = true
		state = "down"


func setup_enemy(b: Node, eid: String, scale: float) -> void:
	battle = b
	team = 1
	cid = eid
	data = DB.enemy(eid)
	role = data["ai"]
	display_name = data["name"]
	var st: Dictionary = data["stats"]
	var hp_scale = scale * (1.0 + (scale - 1.0) * 0.35) * DB.Floors.ENEMY_HP_MULT
	var pow_scale = scale * DB.Floors.ENEMY_POWER_MULT
	if data.get("boss", false):
		hp_scale *= DB.floor_data(Game.floor_num).get("boss_hp", 1.0)
		pow_scale *= DB.Floors.BOSS_POWER_MULT
	var tm: Array = DB.Floors.TURN_BOSS_HP_MULT if data.get("boss", false) else DB.Floors.TURN_HP_MULT
	hp_scale *= lerpf(tm[0], tm[1], clampf((b.party.size() - 1) / 3.0, 0.0, 1.0))
	pow_scale *= DB.Floors.TURN_POWER_MULT
	if Game.flags.get("allies_captured", false):
		# 頂上の一本道はレンひとり。ナインの「ヒーローは負けない」という認識が敵を弱らせている
		hp_scale *= DB.Floors.SOLO_HP_MULT
		pow_scale *= DB.Floors.SOLO_POWER_MULT
	max_hp = st["hp"] * hp_scale
	hp = max_hp
	atk = st["atk"] * pow_scale
	def = st["def"] * scale
	matk = st["matk"] * pow_scale
	mdef = st["mdef"] * scale
	agi = st["agi"]
	body = data["size"]
	speed = data["speed"]
	fly_h = data.get("fly", 0.0)
	h = fly_h
	armor_max = data.get("armor", 0.0) * scale
	armor = armor_max
	weak = data.get("weak", [])
	resist = data.get("resist", [])
	guard_rate = data.get("guard", 0.0)
	facing = -1
	enemy_speed_mult = Game.bmod("enemy_speed_mult")


# ------------------------------------------------------------ 基本
func ground_y() -> float:
	return battle.GROUND_Y


func on_ground() -> bool:
	return h <= 0.5 and fly_h <= 0.0


func body_rect() -> Rect2:
	return Rect2(x - body.x / 2.0, ground_y() - h - body.y, body.x, body.y)


func center() -> Vector2:
	return Vector2(x, ground_y() - h - body.y / 2.0)


func head() -> Vector2:
	return Vector2(x, ground_y() - h - body.y - 10)


func alive() -> bool:
	return not dead


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0 else 0.0


func stat_mult(stat: String) -> float:
	if buffs.has(stat):
		return buffs[stat][0]
	return 1.0


func is_busy() -> bool:
	return state in ["act", "cast", "hit", "down", "dead", "win", "link"]


func can_act() -> bool:
	return not dead and state in ["idle", "move", "jump", "guard"] and battle.started


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


# ------------------------------------------------------------ 毎フレーム
func tick(dt: float) -> void:
	anim_t += dt
	state_t += dt
	flash_t = max(0.0, flash_t - dt)
	invul = max(0.0, invul - dt)
	buffer_t = max(0.0, buffer_t - dt)
	if buffer_t <= 0.0:
		buffered = ""
	for k in cooldowns.keys():
		cooldowns[k] = max(0.0, cooldowns[k] - dt)
	for k in buffs.keys():
		buffs[k][1] -= dt
		if buffs[k][1] <= 0:
			buffs.erase(k)
	if break_t > 0.0:
		break_t -= dt
		if break_t <= 0.0 and not dead:
			_recover_from_break()
	elif armor_max > 0.0 and armor < armor_max:
		armor_regen_t -= dt
		if armor_regen_t <= 0.0:
			armor = min(armor_max, armor + armor_max * dt * 0.5)
	resist_t = max(0.0, resist_t - dt)
	if team == 1:
		if state == "hit" and break_t <= 0.0:
			stun_chain += dt
			stun_free_t = 0.0
		else:
			stun_free_t += dt
			if stun_free_t > 1.2:
				stun_chain = 0.0
	if team == 0 and not dead:
		var regen = 0.6
		if skills.has("tp_regen"):
			regen += 2.0
		tp = min(max_tp, tp + regen * dt)

	if dead:
		if team == 1:
			fade = max(0.0, fade - dt * 1.2)
		_physics(dt)
		queue_redraw()
		return

	match state:
		"hit":
			hitstun -= dt
			if hitstun <= 0.0 and on_ground_or_flyer():
				set_state("idle")
		"down":
			down_t -= dt
			if down_t <= 0.0:
				set_state("idle")
				invul = 0.5
		"act":
			_tick_act(dt)
		"cast":
			_tick_cast(dt)
		"guard":
			guard_t += dt
		"win", "link":
			pass

	if state in ["idle", "move", "jump", "guard"] and battle.started and not battle.frozen:
		if is_player:
			_player_control(dt)
		elif team == 0:
			_ally_ai(dt)
		else:
			if battle.first_strike_t <= 0.0:
				_enemy_ai(dt)
	_physics(dt)
	queue_redraw()


func on_ground_or_flyer() -> bool:
	return on_ground() or fly_h > 0.0


func _physics(dt: float) -> void:
	var grav = GRAVITY
	if state == "act" and act.get("float", false):
		grav *= 0.25
	if fly_h > 0.0 and not dead:
		# 飛行する敵は目標高度へ戻る
		if not (state == "act" and act.get("dive", false)):
			# こちらのターンは低く降りてきて、攻撃が届く高さに身構える
			var want_h: float = fly_h if team == 0 or battle.is_enemy_turn() else min(fly_h, 30.0)
			h = lerp(h, want_h, min(1.0, dt * 3.0))
			vy = 0.0
	else:
		if h > 0.0 or vy > 0.0:
			vy -= grav * dt
			h += vy * dt
			if h <= 0.0:
				h = 0.0
				if vy < -300.0:
					landed_t = 0.15
				vy = 0.0
				air_actions = 0
				if state == "jump":
					set_state("idle")
				elif state == "hit" and hitstun <= 0.0:
					set_state("idle")
	landed_t = max(0.0, landed_t - dt)
	x += vx * dt
	var fr = 600.0 if on_ground() else 120.0
	if state in ["move", "act"] and act.get("dash_now", false):
		fr = 0.0
	if state != "move":
		vx = move_toward(vx, 0.0, fr * dt * 3.0)
	x = clamp(x, battle.LEFT + body.x / 2.0, battle.RIGHT - body.x / 2.0)
	position = Vector2(x, ground_y() - h)


# ------------------------------------------------------------ プレイヤー操作
func _player_control(dt: float) -> void:
	var dir = Input.get_axis("move_left", "move_right")
	var guarding = Input.is_action_pressed("guard") and on_ground()
	if Input.is_action_just_pressed("guard"):
		guard_pressed_at = battle.time
	if guarding:
		if state != "guard":
			set_state("guard")
			guard_t = 0.0
		vx = 0.0
		# ガード＋方向でステップ
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
			var sd = -1 if Input.is_action_just_pressed("move_left") else 1
			vx = sd * 620.0
			invul = 0.22
			set_state("move")
			Sfx.play("jump", 0.7)
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("arte"):
			pass
		else:
			return
	elif state == "guard":
		set_state("idle")

	if Input.is_action_just_pressed("jump") and on_ground():
		vy = 720.0
		h = 1.0
		set_state("jump")
		Sfx.play("jump")
	if battle.is_enemy_turn() and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("arte")):
		# 敵のターン：攻撃はパリィ直後のカウンターだけ
		if Input.is_action_just_pressed("attack"):
			battle.try_counter()
		return
	if Input.is_action_just_pressed("attack"):
		_auto_face()
		start_normal()
		return
	if Input.is_action_just_pressed("arte"):
		_auto_face()
		var slot = _dir_slot()
		use_slot(slot)
		return
	if abs(dir) > 0.2:
		facing = 1 if dir > 0 else -1
		vx = dir * speed * (0.85 if not on_ground() else 1.0)
		if on_ground() and state != "move":
			set_state("move")
	else:
		if on_ground():
			vx = move_toward(vx, 0.0, 3000 * dt)
			if state == "move":
				set_state("idle")


func _dir_slot() -> int:
	if Input.is_action_pressed("move_up"):
		return 1
	if Input.is_action_pressed("move_down"):
		return 2
	if abs(Input.get_axis("move_left", "move_right")) > 0.3:
		return 3
	return 0


func _auto_face() -> void:
	var t = battle.player_target
	if t and t.alive():
		var d: float = t.x - x
		if abs(d) > 4 and not (abs(Input.get_axis("move_left", "move_right")) > 0.2):
			facing = 1 if d > 0 else -1


func handle_buffered_input() -> void:
	# 行動中に押されたボタンを次の行動へ繋ぐ（先行入力）
	if not is_player:
		return
	if Input.is_action_just_pressed("attack"):
		buffered = "attack"
		buffer_t = 0.3
	elif Input.is_action_just_pressed("arte"):
		buffered = "arte%d" % _dir_slot()
		buffer_t = 0.3


# ------------------------------------------------------------ 行動
func start_normal() -> bool:
	if combo.is_empty():
		return false
	var idx = 0
	if state == "act" and act_level == 0:
		idx = combo_idx + 1
		if idx >= combo.size():
			return false
	var spec: Dictionary = combo[idx].duplicate()
	spec["normal"] = true
	if not on_ground():
		spec["float"] = true
	combo_idx = idx
	chain_count = 0
	_begin_act(spec, 0, "")
	return true


func use_slot(slot: int) -> bool:
	var aid: String = arte_slots[slot] if slot < arte_slots.size() else ""
	if aid == "":
		aid = arte_slots[0] if arte_slots.size() > 0 else ""
	if aid == "":
		return false
	return use_arte(aid)


func arte_cost(aid: String) -> float:
	if is_player and battle.ovl_t > 0.0:
		return 0.0  # オーバーリミッツ中はTPを消費しない
	var a: Dictionary = DB.arte(aid)
	return ceil(a["tp"] * Game.bmod("tp_cost_mult"))


func arte_level(a: Dictionary) -> int:
	match a["kind"]:
		"tech":
			return 1
		"arcane":
			return 2
		"mystic":
			return 3
	return 1


func can_chain_to(level: int) -> bool:
	if state != "act":
		return true
	var phase_ok = act_t >= act.get("startup", 0.0)
	if not phase_ok:
		return false
	if level > act_level:
		return true
	if act_level == 2 and level == 1 and (skills.has("chain_plus") or Game.bmod("endless_chain") > 0.0) and chain_count < 6:
		return true
	return false


func use_arte(aid: String) -> bool:
	var a: Dictionary = DB.arte(aid)
	var cost = arte_cost(aid)
	if tp < cost:
		if is_player:
			battle.popup_text(head() + Vector2(0, -20), "TPが足りない", Color(0.7, 0.8, 1.0), 18)
		return false
	var kind: String = a["kind"]
	if kind in ["spell", "heal", "support"]:
		if not on_ground():
			return false
		if state == "act" and not can_chain_to(1):
			return false
		var tgt = _pick_cast_target(a)
		if tgt == null:
			return false
		tp -= cost
		cast_id = aid
		cast_t = 0.0
		var ct: float = a["cast"] * Game.bmod("cast_mult")
		if skills.has("fast_cast"):
			ct *= 0.8
		cast_time = ct
		cast_target = tgt
		act = {}
		set_state("cast")
		vx = 0.0
		Sfx.play("cast")
		return true
	var lvl = arte_level(a)
	if state == "act" and not can_chain_to(lvl):
		return false
	if state == "act" and lvl <= act_level:
		chain_count += 1
	tp -= cost
	var spec: Dictionary = a.duplicate()
	spec["arte_id"] = aid
	if not on_ground():
		spec["float"] = true
	_begin_act(spec, lvl, a["name"])
	return true


func _pick_cast_target(a: Dictionary) -> Fighter:
	if a["kind"] == "heal":
		if a.get("revive", false):
			return battle.weakest_ally(self, true)
		return battle.weakest_ally(self, false)
	if a["kind"] == "support":
		return self
	if team == 0 and is_player and battle.player_target and battle.player_target.alive():
		return battle.player_target
	return battle.nearest_enemy(self)


func _begin_act(spec: Dictionary, level: int, name: String) -> void:
	act = spec
	act_t = 0.0
	act_level = level
	act_name = name
	act_hits = {}
	act_hit_any = false
	act_spawned = 0
	set_state("act")
	if spec.has("jump"):
		vy = spec["jump"]
		h = max(h, 1.0)
	if not on_ground() and not spec.has("jump"):
		vy = max(vy, 60.0)
	if name != "":
		battle.on_arte_used(self, name, level)
		Sfx.play("slash", 0.8)
	elif spec.has("projectile"):
		pass
	else:
		Sfx.play("slash", 1.1 + combo_idx * 0.08, -6)


func _tick_act(dt: float) -> void:
	act_t += dt
	handle_buffered_input()
	var su: float = act.get("startup", 0.1)
	var ac: float = act.get("active", 0.1)
	var rc: float = act.get("recovery", 0.2)
	if act_t >= su and act_t < su + ac:
		act["dash_now"] = act.has("dash")
		if act.has("dash"):
			vx = facing * act["dash"]
		if act.get("dive", false):
			h = move_toward(h, 0.0, 900.0 * dt)
		if act.has("projectile"):
			_spawn_projectiles()
		elif act.has("aoe") and act_spawned == 0:
			act_spawned = 1
			var tx = x + facing * act["aoe"].get("range", 260)
			var tgt = battle.nearest_enemy(self) if team == 0 else target
			if tgt and abs(tgt.x - x) < act["aoe"].get("range", 260) + 200:
				tx = tgt.x
			battle.spawn_aoe(self, act, tx, act.get("power", 1.0))
		if act.has("reach") or (not act.has("projectile") and not act.has("aoe")):
			_melee_hits()
	else:
		act["dash_now"] = false
	if act_t >= su + ac:
		# 硬直中はキャンセル受付
		if team == 0 and buffered != "":
			var b = buffered
			buffered = ""
			if b == "attack" and act_level == 0:
				if start_normal():
					return
			elif b.begins_with("arte"):
				if use_slot(int(b.substr(4))):
					return
		if not is_player and team == 0 and _ai_follow_up():
			return
	if act_t >= su + ac + rc:
		act = {}
		act_level = 0
		combo_idx = 0
		chain_count = 0
		set_state("idle" if on_ground() else "jump")


func _spawn_projectiles() -> void:
	var p: Dictionary = act["projectile"]
	var count: int = p.get("count", 1)
	var interval: float = p.get("interval", 0.1)
	var su: float = act.get("startup", 0.1)
	while act_spawned < count and act_t >= su + act_spawned * interval:
		battle.spawn_projectile(self, act, act.get("power", 1.0))
		act_spawned += 1
		if act.get("normal", false) or p.get("shape", "") == "bullet":
			Sfx.play("shot", 1.0 + randf() * 0.1, -4)
		else:
			Sfx.play("magic", 1.3, -8)
	# active 時間内に撃ち切れない分を延長
	if act_spawned < count:
		act["active"] = max(act.get("active", 0.1), act_t - su + interval)


func _melee_hits() -> void:
	var reach: float = act.get("reach", 70)
	var height: float = act.get("height", body.y)
	var off: float = act.get("offset", 0.0)
	var cx = x + facing * (body.x / 2.0 + reach / 2.0 + off)
	if off < 0:
		cx = x + facing * (body.x / 2.0 + reach / 2.0) + off * facing
		if act.get("fx", "") in ["quake", "mystic"]:
			cx = x
	var top = ground_y() - h - body.y / 2.0 - height / 2.0
	var r = Rect2(cx - reach / 2.0, top, reach, height)
	var hits: int = act.get("hits", 1)
	var interval: float = act.get("hit_interval", 0.1)
	for f in battle.opponents(self):
		if f.alive() and f.invul > 0.0 and f.team == 0 and team == 1 and battle.is_enemy_turn() and r.intersects(f.body_rect()):
			battle.on_dodge(f)
		if not f.alive() or f.invul > 0.0:
			continue
		if not r.intersects(f.body_rect()):
			continue
		var rec: Array = act_hits.get(f, [0, -10.0])
		if rec[0] >= hits or act_t - rec[1] < interval:
			continue
		rec[0] += 1
		rec[1] = act_t
		act_hits[f] = rec
		act_hit_any = true
		var power: float = act.get("power", 1.0)
		battle.apply_hit(self, f, act, power, false)


# ------------------------------------------------------------ 詠唱
func _tick_cast(dt: float) -> void:
	cast_t += dt
	if cast_target == null or (not cast_target.alive() and not DB.arte(cast_id).get("revive", false)):
		cast_target = _pick_cast_target(DB.arte(cast_id))
		if cast_target == null:
			set_state("idle")
			return
	if cast_t >= cast_time:
		var a: Dictionary = DB.arte(cast_id)
		battle.on_arte_used(self, a["name"], 1)
		battle.resolve_spell(self, cast_id, cast_target)
		set_state("act")
		act = {"startup": 0.0, "active": 0.0, "recovery": 0.35}
		act_t = 0.0
		act_level = 1


# ------------------------------------------------------------ 被弾
func take_hit(dmg: int, knock: float, launch: float, from_dir: int, stun: float, heavy: bool) -> void:
	if held:
		return
	if holds_at_one() and hp - dmg < 1.0:
		hp = 1.0
		battle.on_boss_held(self)
		return
	hp = max(0.0, hp - dmg)
	flash_t = 0.12
	if team == 0:
		hurt_this_battle = true
	if hp <= 0.0:
		die(from_dir)
		return
	if is_player and battle.ovl_t > 0.0:
		return  # オーバーリミッツ中はのけぞらない
	if armor_max > 0.0 and break_t <= 0.0:
		armor -= dmg * 0.6 + 6
		armor_regen_t = 3.5
		if resist_t > 0.0:
			# ブレイク明けの立て直し中は割れない
			armor = max(armor, 1.0)
		if armor <= 0.0:
			armor = 0.0
			break_t = BREAK_TIME
			stun_chain = 0.0
			battle.on_break(self)
			_stagger(1.6, from_dir, 200)
		return
	if team == 1 and break_t <= 0.0:
		if resist_t > 0.0:
			return
		if stun_chain > STUN_LIMIT:
			# のけぞり続けた敵は踏ん張って抜け出す（無限コンボ防止）
			stun_chain = 0.0
			resist_t = 1.6
			hitstun = 0.0
			battle.popup_text(head(), "踏ん張り！", Color(1.0, 0.75, 0.4), 18)
			if on_ground_or_flyer() and state == "hit":
				set_state("idle")
			return
	if state == "cast" and skills.has("iron_cast"):
		return
	if state == "cast":
		battle.popup_text(head(), "詠唱中断！", Color(1, 0.6, 0.6), 18)
	act = {}
	act_level = 0
	combo_idx = 0
	vx = from_dir * knock
	if launch > 0.0:
		vy = launch
		h = max(h, 2.0)
	elif not on_ground() and fly_h <= 0.0:
		vy = max(vy, 120.0)
	hitstun = (0.28 + knock / 900.0) * stun
	set_state("hit")


# とどめ演出のあるボスは、HP1で踏みとどまる
func holds_at_one() -> bool:
	return team == 1 and data.get("boss", false) and DB.Finishers.DATA.has(cid) and not battle.finishing


func _recover_from_break() -> void:
	armor = armor_max
	resist_t = 3.0
	stun_chain = 0.0
	hitstun = 0.0
	if state == "hit" and on_ground_or_flyer():
		set_state("idle")
	battle.popup_text(head() + Vector2(0, -30), "装甲回復", Color(0.9, 0.9, 0.6), 22)
	ai_t = 0.0


func _stagger(t: float, from_dir: int, knock: float) -> void:
	act = {}
	act_level = 0
	vx = from_dir * knock
	hitstun = t
	set_state("hit")


func die(from_dir: int) -> void:
	dead = true
	act = {}
	cast_id = ""
	vx = from_dir * 220.0
	vy = 320.0
	h = max(h, 2.0)
	if fly_h > 0.0:
		fly_h = 0.0
	set_state("dead")
	battle.on_death(self)


func revive(ratio: float) -> void:
	dead = false
	hp = max(1.0, max_hp * ratio)
	set_state("idle")
	invul = 1.0
	fade = 1.0


func heal(amount: float) -> void:
	if dead:
		return
	hp = min(max_hp, hp + amount)


func add_buff(stat: String, mult: float, time: float) -> void:
	buffs[stat] = [mult, time]


# ------------------------------------------------------------ 味方AI
func _ally_ai(dt: float) -> void:
	ai_t -= dt
	if battle.is_enemy_turn():
		_ally_defend(dt)
		return
	if shortcut_req != "":
		var aid = shortcut_req
		shortcut_req = ""
		if use_arte(aid):
			return
	var enemy = battle.nearest_enemy(self)
	if enemy == null:
		vx = 0.0
		if state == "move":
			set_state("idle")
		return
	target = enemy
	var d = enemy.x - x
	var dist: float = abs(d)
	if _try_heal():
		return
	# 敵の大技にはガードで備える
	if enemy.state == "act" and enemy.act.get("guardable", false) and on_ground():
		if state != "guard":
			set_state("guard")
		vx = 0.0
		return
	if state == "guard" and state_t > 0.6:
		set_state("idle")
	match role:
		"melee":
			var want: float = 50.0 + body.x / 2.0 + enemy.body.x / 2.0
			if dist > want:
				_walk(sign(d))
			else:
				facing = 1 if d > 0 else -1
				vx = 0.0
				if ai_t <= 0.0:
					if enemy.state == "act" and enemy.act_t < enemy.act.get("startup", 0.3) and randf() < 0.25 and on_ground():
						set_state("guard")
						ai_t = 0.5
						return
					ai_t = randf_range(0.05, 0.35)
					start_normal()
		"caster", "gunner":
			var near = battle.nearest_enemy_dist(self)
			var lo = 220.0 if role == "caster" else 200.0
			var hi = 480.0 if role == "caster" else 420.0
			if near < lo and x > battle.LEFT + 80 and x < battle.RIGHT - 80:
				_walk(-sign(d))
			elif dist > hi:
				_walk(sign(d))
			else:
				facing = 1 if d > 0 else -1
				vx = 0.0
				if ai_t <= 0.0:
					ai_t = randf_range(0.3, 0.8)
					var cands: Array = []
					for aid in arte_slots:
						if aid == "":
							continue
						var a: Dictionary = DB.arte(aid)
						if a["kind"] in ["spell", "tech", "arcane"] and tp >= arte_cost(aid):
							cands.append(aid)
						elif a["kind"] == "support" and tp >= arte_cost(aid) and not buffs.has(a["buff"]["stat"]) and randf() < 0.3:
							cands.append(aid)
					if role == "gunner" and (cands.is_empty() or randf() < 0.45):
						start_normal()
					elif not cands.is_empty():
						use_arte(cands[randi() % cands.size()])
					else:
						start_normal()


# 回復の優先（回復役のみ）
func _try_heal() -> bool:
	if role in ["caster", "gunner"] and ai_t <= 0.0:
		var heal_th = 0.55 if role == "gunner" else 0.38
		for aid in arte_slots:
			if aid == "":
				continue
			var a: Dictionary = DB.arte(aid)
			if a["kind"] == "heal" and tp >= arte_cost(aid):
				var w = battle.weakest_ally(self, a.get("revive", false))
				if w and (a.get("revive", false) or w.hp_ratio() < heal_th or (a.get("all", false) and battle.party_avg_hp() < 0.6)):
					if use_arte(aid):
						ai_t = 0.6
						return true
	return false


# 敵のターン：攻撃せず、来る攻撃を見てガード（うまくいけばパリィ）。回復役は回復を続ける
var defend_lead := 0.3


func _ally_defend(dt: float) -> void:
	if _try_heal():
		return
	var foe: Fighter = battle.turn_actor
	if foe == null or not is_instance_valid(foe) or not foe.alive():
		if state == "guard" and state_t > 0.3:
			set_state("idle")
		vx = 0.0
		if state == "move":
			set_state("idle")
		return
	facing = 1 if foe.x > x else -1
	var aimed: bool = foe.target == self or foe.act.has("aoe") or abs(foe.x - x) < 220.0
	if foe.state == "act" and aimed and on_ground():
		var su: float = foe.act.get("startup", 0.3)
		if state != "guard" and foe.act_t >= su - defend_lead:
			set_state("guard")
			guard_pressed_at = battle.time
			vx = 0.0
		return
	defend_lead = randf_range(0.05, 0.7) * (0.6 if skills.has("perfect_guard") else 1.0)
	if state == "guard" and state_t > 0.3:
		set_state("idle")
	# 後衛は間合いを取る
	if role in ["caster", "gunner"] and abs(foe.x - x) < 200.0 and x > battle.LEFT + 80 and x < battle.RIGHT - 80:
		_walk(-sign(foe.x - x))
	else:
		vx = 0.0
		if state == "move":
			set_state("idle")


func _ai_follow_up() -> bool:
	# 味方AIのコンボ継続：通常攻撃 → 特技 → 奥義
	if act_t < act.get("startup", 0.1) + act.get("active", 0.1):
		return false
	if randf() < 0.35:
		return false
	if act_level == 0 and combo_idx < combo.size() - 1:
		return start_normal()
	var want = act_level + 1
	var opts: Array = []
	for aid in arte_slots:
		if aid == "":
			continue
		var a: Dictionary = DB.arte(aid)
		if a["kind"] in ["tech", "arcane"] and arte_level(a) == want and tp >= arte_cost(aid):
			opts.append(aid)
	if opts.is_empty():
		return false
	return use_arte(opts[randi() % opts.size()])


func _walk(dir: float) -> void:
	if dir == 0:
		return
	facing = 1 if dir > 0 else -1
	vx = dir * speed * 0.9
	if state != "move" and on_ground():
		set_state("move")


# ------------------------------------------------------------ 敵AI
func _enemy_ai(dt: float) -> void:
	ai_t -= dt * enemy_speed_mult
	if target == null or not target.alive() or randf() < dt * 0.15:
		target = battle.enemy_pick_target(self)
	if target == null:
		vx = 0.0
		return
	var d = target.x - x
	var dist: float = abs(d) - body.x / 2.0 - target.body.x / 2.0
	facing = 1 if d > 0 else -1
	if role == "boss" and not warned and phase == 0 and hp_ratio() < 0.5:
		phase = 1
		battle.on_boss_phase(self)
	if battle.turn_actor != self or not battle.is_enemy_turn():
		# 自分の番ではない：身構えて待つ
		vx = 0.0
		if state == "move":
			set_state("idle")
		return
	var attacks: Array = data["attacks"]
	if ai_t <= 0.0 and battle.may_attack(self):
		var usable: Array = []
		for i in range(attacks.size()):
			var at: Dictionary = attacks[i]
			if cooldowns.get(i, 0.0) > 0.0 and attacks.size() > 1:
				continue
			if at.get("phase", 0) > phase_level():
				continue
			if dist <= at["range"]:
				usable.append(i)
		if not usable.is_empty():
			# 大技を優先
			var pick: int = usable[randi() % usable.size()]
			for i in usable:
				if attacks[i].has("warn"):
					pick = i
			_enemy_attack(pick)
			return
	var spd = speed * enemy_speed_mult
	match role:
		"ranged":
			var pref: float = attacks[0]["range"] * 0.6
			if dist < pref * 0.6:
				vx = -sign(d) * spd
			elif dist > pref:
				vx = sign(d) * spd
			else:
				vx = 0.0
		"charger":
			var pref2: float = attacks[attacks.size() - 1]["range"] * 0.7
			if dist > pref2:
				vx = sign(d) * spd
			elif dist < 60:
				vx = -sign(d) * spd * 0.6
			else:
				vx = 0.0
		_:
			if dist > 20:
				vx = sign(d) * spd
			else:
				vx = 0.0
	if state != "move" and abs(vx) > 1:
		set_state("move")
	elif state == "move" and abs(vx) <= 1:
		set_state("idle")


func phase_level() -> int:
	if role != "boss":
		return 0
	return 2 if hp_ratio() < 0.5 else (1 if hp_ratio() < 0.85 else 0)


func _enemy_attack(i: int) -> void:
	var at: Dictionary = data["attacks"][i].duplicate(true)
	cooldowns[i] = at.get("cooldown", 2.0)
	ai_t = at.get("recovery", 0.6) + randf_range(0.2, 0.8) * (0.6 if role == "boss" else 1.0)
	at["startup"] = at["windup"] / enemy_speed_mult * battle.TELEGRAPH_MULT
	battle.on_enemy_telegraph(self, at)
	at["hit_interval"] = at.get("active", 0.2) / max(1, at.get("hits", 1))
	if at.get("magic", false):
		at["magic_attack"] = true
	_begin_act(at, 1, at["name"] if (role == "boss" or at.has("warn")) else "")
	if at.has("warn"):
		battle.boss_warning(self, at["warn"])
	if at.has("aoe") and at["aoe"].get("at_self", false):
		pass
	vx = 0.0


# ------------------------------------------------------------ 描画
func _draw() -> void:
	ArtScript.draw_fighter(self)
