# 塔の各層の探索マップ（見下ろし型）。歩いて探索し、敵シンボルに触れると戦闘。
# 宝箱・行商人・焚火・イベント・住人・中盤ストーリー・ボスを配置する。マップは data/fieldmaps.gd
extends Control

const TS := 64.0
const SPEED := 270.0
const DASH_MULT := 1.55
const SOLID_TILES := "#To~ "
const OBJ_SOLID := "CMNF?B"
const VIEW := Vector2(1280, 720)
# 第一層の出発地点から最初の宝箱までの描画プレビュー。
const GRASS_DETAIL_AREA := Rect2i(0, 26, 19, 10)
const DETAIL_CELL := 32
# 敵シンボルの動き
const WANDER_SPEED := 70.0
const CHASE_SPEED := 190.0
const SIGHT := 4.5 * 64.0
const LEASH := 7.0 * 64.0
const CONTACT := 46.0

var params: Dictionary = {}
var t := 0.0
var fm: Dictionary = {}
var rows: Array = []
var W := 0
var H := 0
var ftheme := "grass"
var field_backdrop: Texture2D
var backdrop_mask: PackedByteArray
var grass_detail: Texture2D
var view: Node2D
var hud: Control
var ppos := Vector2.ZERO
var pdir := 0  # 0 下 1 左 2 右 3 上
var walk_t := 0.0
var moving := false
var objs: Array = []
var cam := Vector2.ZERO
var locked := true
var invul := 0.0
var near: Dictionary = {}
var fog: PackedByteArray
var skit_btn: Button
var flash := 0.0
var boss_obj: Dictionary = {}
var bot_input := Vector2.ZERO  # 自動テストプレイ用の入力（0 なら人の入力）
var bot_mode := false
var hint_cd := 0.0
var bot_log: Array = []


class View extends Node2D:
	var s
	func _draw() -> void:
		s._draw_world(self)


class Hud extends Control:
	var s
	func _draw() -> void:
		s._draw_hud(self)


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	UI.full(self)
	_load_floor()
	_load_field_backdrop()
	if Game.floor_num == 1 and ftheme == "grass":
		var detail_path := "res://assets/field_detail/grass.png"
		if ResourceLoader.exists(detail_path):
			var atlas := load(detail_path) as Texture2D
			if atlas != null and atlas.get_size() == Vector2(8, 8) * DETAIL_CELL:
				grass_detail = atlas
	view = View.new()
	view.s = self
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)
	hud = Hud.new()
	hud.s = self
	UI.full(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_update_cam(true)
	Game.skit_available.connect(_on_skit_available)
	_arrive()


func _exit_tree() -> void:
	if Game.skit_available.is_connected(_on_skit_available):
		Game.skit_available.disconnect(_on_skit_available)


# ------------------------------------------------------------ マップの読み込み
func _load_floor() -> void:
	if int(Game.map.get("floor", -1)) != Game.floor_num or not Game.map.has("done"):
		Game.init_field()
	fm = DB.FieldMaps.MAPS.get(Game.floor_num, DB.FieldMaps.MAPS[1])
	ftheme = fm["theme"]
	rows = fm["rows"]
	H = rows.size()
	W = rows[0].length()
	objs.clear()
	var done: Dictionary = Game.map["done"]
	for y in range(H):
		var r: String = rows[y]
		for x in range(W):
			var c := r[x]
			if c == "P" and (Game.map.get("pos", []) as Array).is_empty():
				ppos = _tile_center(x, y) + Vector2(0, 20)
			if c in "ELCMNF?B":
				var id := "%d,%d" % [x, y]
				var props: Dictionary = fm["objects"].get(id, {})
				var o := {"id": id, "ch": c, "tile": Vector2i(x, y), "pos": _tile_center(x, y) + Vector2(0, 20), "props": props,
					"done": done.has(id), "home": _tile_center(x, y) + Vector2(0, 20), "state": "idle", "wait": randf_range(0.5, 2.0),
					"target": Vector2.ZERO, "face": 1.0, "alert": 0.0, "stun": 0.0, "walk": randf() * 3.0}
				if c in "EL" and done.has(id):
					continue
				objs.append(o)
				if c == "B":
					boss_obj = o
	var pos: Array = Game.map.get("pos", [])
	if pos.size() == 2:
		ppos = Vector2(float(pos[0]), float(pos[1]))
	pdir = int(Game.map.get("dir", 3))
	var f: String = Game.map.get("fog", "")
	fog = PackedByteArray()
	fog.resize(W * H)
	if f.length() == W * H:
		for i in range(W * H):
			fog[i] = 1 if f[i] == "1" else 0
	_reveal()


func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * TS + TS / 2.0, y * TS + TS / 2.0)


func tile_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.y / TS)))


func ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "#"
	return rows[y][x]


func gate_open() -> bool:
	var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	return not fs.has("mid") or Game.flags.get("story_" + fs["mid"], false)


func solid(x: int, y: int, for_enemy: bool = false) -> bool:
	var c := ch(x, y)
	if c in SOLID_TILES:
		return true
	if c == "+":
		return for_enemy or not gate_open()
	if for_enemy and c in "G=":
		return c == "G"
	if c in OBJ_SOLID:
		# 置物は、使い終わっても置いたまま（焚火・宝箱）。イベントは使うと消える
		var o = _obj_at(x, y)
		if o.is_empty():
			return false
		if c == "?" and o["done"]:
			return false
		return true
	return false


func _obj_at(x: int, y: int) -> Dictionary:
	for o in objs:
		if o["tile"] == Vector2i(x, y):
			return o
	return {}


# 足元の四角（幅32×高さ20）が壁に重なるか
func blocked(p: Vector2, for_enemy: bool = false) -> bool:
	for off in [Vector2(-16, -10), Vector2(16, -10), Vector2(-16, 8), Vector2(16, 8)]:
		var tp := tile_at(p + off)
		if solid(tp.x, tp.y, for_enemy):
			return true
	return false


func move_body(p: Vector2, v: Vector2, for_enemy: bool = false) -> Vector2:
	var steps: int = int(ceil(v.length() / 8.0)) + 1
	var d := v / steps
	for i in range(steps):
		var nx := p + Vector2(d.x, 0)
		if not blocked(nx, for_enemy):
			p = nx
		var ny := p + Vector2(0, d.y)
		if not blocked(ny, for_enemy):
			p = ny
	return p


# ------------------------------------------------------------ 毎フレーム
func _process(delta: float) -> void:
	t += delta
	flash = max(0.0, flash - delta * 2.0)
	if invul > 0.0:
		invul -= delta
	hint_cd -= delta
	var can_move: bool = not locked and not Main.inst.busy and is_inside_tree()
	if can_move:
		_move_player(delta)
	else:
		moving = false
	_update_enemies(delta, can_move)
	if can_move:
		_check_triggers()
	_update_near()
	_update_cam(false)
	view.position = -cam
	view.queue_redraw()
	hud.queue_redraw()


func _move_player(delta: float) -> void:
	var v := bot_input if bot_mode else Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.25)
	moving = v.length() > 0.1
	if not moving:
		return
	if abs(v.x) > abs(v.y) * 1.1:
		pdir = 1 if v.x < 0 else 2
	elif abs(v.y) > 0.0:
		pdir = 3 if v.y < 0 else 0
	var sp := SPEED * (DASH_MULT if Input.is_action_pressed("guard") or bot_mode else 1.0)
	ppos = move_body(ppos, v.limit_length(1.0) * sp * delta)
	walk_t += delta * (1.4 if sp > SPEED else 1.0)
	_reveal()


func _reveal() -> void:
	if fog.size() != W * H:
		return
	var tp := tile_at(ppos)
	for y in range(tp.y - 5, tp.y + 6):
		for x in range(tp.x - 6, tp.x + 7):
			if x >= 0 and y >= 0 and x < W and y < H:
				fog[y * W + x] = 1


func _update_cam(snap: bool) -> void:
	var want := ppos - VIEW / 2.0 + Vector2(0, -20)
	var mw := W * TS
	var mh := H * TS
	want.x = clamp(want.x, 0.0, max(0.0, mw - VIEW.x)) if mw > VIEW.x else (mw - VIEW.x) / 2.0
	want.y = clamp(want.y, 0.0, max(0.0, mh - VIEW.y)) if mh > VIEW.y else (mh - VIEW.y) / 2.0
	cam = want if snap else cam.lerp(want, 0.18)
	cam = cam.round()


# ------------------------------------------------------------ 敵シンボル
func _update_enemies(delta: float, active: bool) -> void:
	for o in objs:
		if not o["ch"] in "EL" or o["done"]:
			continue
		o["walk"] += delta
		if o["stun"] > 0.0:
			o["stun"] -= delta
			o["alert"] = 0.0
			continue
		if not active:
			continue
		var guard: bool = o["ch"] == "L" or o["props"].get("move", "wander") == "guard"
		var to_p: Vector2 = ppos - o["pos"]
		var dist := to_p.length()
		var sight: float = SIGHT * (0.45 if guard else 1.0)
		var leash: float = LEASH * (0.35 if guard else 1.0)
		var sees: bool = dist < sight and invul <= 0.0 and _line_clear(o["pos"], ppos)
		var home_d: float = (o["pos"] - o["home"]).length()
		if sees and home_d < leash:
			if o["state"] != "chase":
				o["alert"] = 1.0
			o["state"] = "chase"
		elif o["state"] == "chase":
			o["state"] = "return"
		o["alert"] = max(0.0, o["alert"] - delta * 0.6)
		var v := Vector2.ZERO
		match o["state"]:
			"chase":
				# 番の敵は、すぐそばを通ろうとすると飛びかかってくる
				var lunge: bool = guard and dist < TS * 1.8
				v = to_p.normalized() * (310.0 if lunge else CHASE_SPEED * (0.75 if guard else 1.0))
			"return":
				var back: Vector2 = o["home"] - o["pos"]
				if back.length() < 8.0:
					o["state"] = "idle"
				else:
					v = back.normalized() * WANDER_SPEED * 1.5
			"walk":
				var dv: Vector2 = o["target"] - o["pos"]
				o["wait"] -= delta
				if dv.length() < 6.0 or o["wait"] <= 0.0:
					o["state"] = "idle"
					o["wait"] = randf_range(0.8, 2.4)
				else:
					v = dv.normalized() * WANDER_SPEED
			_:
				o["wait"] -= delta
				if o["wait"] <= 0.0 and not guard:
					var ang := randf() * TAU
					o["target"] = o["home"] + Vector2(cos(ang), sin(ang)) * randf_range(0.5, 2.6) * TS
					o["state"] = "walk"
					o["wait"] = 3.0
		if v != Vector2.ZERO:
			o["face"] = sign(v.x) if abs(v.x) > 1.0 else o["face"]
			o["pos"] = move_body(o["pos"], v * delta, true)
		elif guard:
			o["face"] = sign(to_p.x) if abs(to_p.x) > 4.0 else o["face"]
		# 接触
		if dist < CONTACT * (1.3 if guard else 1.0) and invul <= 0.0 and active:
			_encounter(o)
			return


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var n: int = int(a.distance_to(b) / 24.0) + 1
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n) + Vector2(0, -8)
		var tp := tile_at(p)
		var c := ch(tp.x, tp.y)
		if c in "#T ":
			return false
	return true


func _encounter(o: Dictionary) -> void:
	if locked:
		return
	if bot_mode:
		bot_log.append(["battle", o["id"], o["ch"]])
		o["done"] = true
		Game.map["done"][o["id"]] = true
		objs.erase(o)
		invul = 1.0
		return
	locked = true
	moving = false
	Game.map["engage"] = o["id"]
	_save_pos()
	Sfx.play("warn", 1.2, -4)
	flash = 1.0
	var kind := "elite" if o["ch"] == "L" else "battle"
	var g: Array = o["props"].get("g", DB.floor_data(Game.floor_num)["groups"][0])
	await get_tree().create_timer(0.35).timeout
	Main.inst.goto("battle", {"enemies": g, "kind": kind})


# ------------------------------------------------------------ 触れる・調べる
func _check_triggers() -> void:
	var tp := tile_at(ppos)
	if ch(tp.x, tp.y) == "G" and not gate_open():
		_mid_story()
		return
	# 閉じた門に触れたとき
	if not gate_open() and hint_cd <= 0.0:
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var gp: Vector2i = tp + d
			if ch(gp.x, gp.y) == "+" and ppos.distance_to(_tile_center(gp.x, gp.y)) < 62.0:
				if fm.has("gate_hint"):
					Main.inst.toast(fm["gate_hint"], "info")
					hint_cd = 4.0
				else:
					_mid_story()
				return
	if not boss_obj.is_empty() and ppos.distance_to(boss_obj["pos"]) < TS * 1.7:
		_start_boss()


func _update_near() -> void:
	near = {}
	if locked:
		return
	var best := 9999.0
	var face_v: Vector2 = [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)][pdir]
	for o in objs:
		if not o["ch"] in "CMNF?":
			continue
		if o["done"] and o["ch"] in "C?":
			continue
		var d: Vector2 = o["pos"] - ppos
		var dist := d.length()
		if dist > TS * 1.25:
			continue
		if dist > TS * 0.8 and d.normalized().dot(face_v) < 0.3:
			continue
		if dist < best:
			best = dist
			near = o


func interact() -> void:
	if near.is_empty() or locked:
		return
	var o := near
	if bot_mode and o["ch"] in "MF?N":
		o["done"] = true
		Game.map["done"][o["id"]] = true
		bot_log.append(["visit", o["id"], o["ch"]])
		return
	match o["ch"]:
		"C":
			_open_chest(o)
		"M":
			locked = true
			_save_pos()
			Sfx.play("confirm")
			Main.inst.goto("shop", {})
		"F":
			if o["done"]:
				Main.inst.toast("焚火のあとが残っている。（焚火は1つの層で1回だけ）", "info")
				return
			locked = true
			o["done"] = true
			Game.map["done"][o["id"]] = true
			_save_pos()
			Sfx.play("confirm")
			Main.inst.goto("camp", {})
		"?":
			locked = true
			o["done"] = true
			Game.map["done"][o["id"]] = true
			Game.map["engage"] = ""
			_save_pos()
			Sfx.play("confirm")
			Main.inst.goto("event", {})
		"N":
			_talk(o)


func _open_chest(o: Dictionary) -> void:
	o["done"] = true
	Game.map["done"][o["id"]] = true
	var p: Dictionary = o["props"]
	var text := ""
	if p.has("gald"):
		Game.add_gald(int(p["gald"]))
		text = "%d ガルドを手に入れた！" % int(p["gald"])
	elif p.has("item"):
		var n: int = int(p.get("n", 1))
		Game.add_item(p["item"], n)
		text = "%s ×%d を手に入れた！" % [DB.item(p["item"])["name"], n]
	elif p.has("recipe"):
		if not p["recipe"] in Game.known_recipes:
			Game.known_recipes.append(p["recipe"])
		text = "レシピ「%s」を覚えた！" % DB.Items.RECIPES[p["recipe"]]["name"]
	else:
		Game.add_item("apple_gel", 1)
		text = "アップルグミ ×1 を手に入れた！"
	Sfx.play("heal", 1.1, -2)
	Main.inst.toast("宝箱：" + text, "info")
	Game.count("chests")
	Game.save_game()


func _talk(o: Dictionary) -> void:
	var lines: Array = o["props"].get("lines", [])
	if lines.is_empty():
		return
	locked = true
	Sfx.play("select")
	Main.inst.play_dialogue({"lines": lines, "mode": "talk", "bg": "none"}, func() -> void:
		locked = false)


func _mid_story() -> void:
	var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	if bot_mode:
		Game._debug_apply_story(fs.get("mid", ""))
		bot_log.append(["mid", "", "G"])
		return
	locked = true
	moving = false
	if fs.has("mid"):
		await _story(fs["mid"])
	Game.check_skits("story_mid")
	for m in Game.party:
		m["hp"] = max(m["hp"], int(Game.max_hp(m["id"]) * 0.5))
	_save_pos()
	Game.save_game()
	if fm.get("gate", false):
		Main.inst.toast("道が開いた！", "info")
	locked = false


func _start_boss() -> void:
	if locked:
		return
	if bot_mode:
		if bot_log.is_empty() or bot_log[-1][0] != "boss":
			bot_log.append(["boss", boss_obj["id"], "B"])
		return
	locked = true
	moving = false
	_save_pos()
	var fs2: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	if fs2.has("boss_pre"):
		await _story(fs2["boss_pre"])
	Game.map["engage"] = boss_obj["id"]
	Main.inst.goto("battle", {"enemies": DB.floor_data(Game.floor_num)["boss"], "kind": "boss"})


func _save_pos() -> void:
	Game.map["pos"] = [ppos.x, ppos.y]
	Game.map["dir"] = pdir
	var s := ""
	for i in range(fog.size()):
		s += "1" if fog[i] == 1 else "0"
	Game.map["fog"] = s


# ------------------------------------------------------------ 到着時の処理（進行の分岐）
func _arrive() -> void:
	locked = true
	var after: String = params.get("after_battle", "")
	var won: bool = params.get("won", false)
	if after != "":
		if after == "prologue":
			await _prologue_after_battle()
			return
		if after == "boss" and won:
			await _after_boss()
			return
		var eng: String = Game.map.get("engage", "")
		if eng != "":
			for o in objs:
				if o["id"] == eng:
					if won:
						o["done"] = true
						Game.map["done"][eng] = true
					else:
						o["stun"] = 3.0
						# 逃げたら少し離れた場所に戻る
						o["pos"] = o["home"]
			if won:
				objs = objs.filter(func(o) -> bool: return not (o["ch"] in "EL" and o["done"]))
		Game.map["engage"] = ""
		invul = 2.0
		if after == "elite" and won:
			await _buff_choice("強敵を倒した！ 加護をひとつ選ぼう", 3)
			Game.check_skits("after_elite")
		elif won:
			Game.check_skits("after_battle")
	elif params.get("after", "") != "":
		invul = 1.0
		Game.check_skits("after_" + params["after"])
	elif params.get("new_floor", false) or not Game.flags.get("floor_started_%d" % Game.floor_num, false):
		await _floor_start()
	_save_pos()
	Game.save_game()
	_refresh()
	await _map_tutorials()
	locked = false


func _map_tutorials() -> void:
	if Game.should_tutorial("map"):
		await Main.inst.show_tutorial("map")
	if Game.party.any(func(m) -> bool: return m["sp"] > 0) and Game.should_tutorial("menu"):
		await Main.inst.show_tutorial("menu")
	if Game.party.size() >= 5 and Game.should_tutorial("formation"):
		await Main.inst.show_tutorial("formation")
	if not Game.pending_skits.is_empty() and Game.should_tutorial("skit"):
		await Main.inst.show_tutorial("skit")


func _floor_start() -> void:
	Game.flags["floor_started_%d" % Game.floor_num] = true
	var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	if fs.has("intro") and not Game.flags.get("story_" + fs["intro"], false):
		await _story(fs["intro"])
	_show_floor_title()
	await get_tree().create_timer(1.6).timeout
	await _buff_choice("%s ― 層の加護をひとつ選ぼう" % DB.floor_data(Game.floor_num)["name"], 3)
	Game.take_floor_snapshot()
	Game.check_skits("floor_start")


func _show_floor_title() -> void:
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	var box = VBoxContainer.new()
	box.position = Vector2(0, 260)
	box.size = Vector2(1280, 160)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var l1 = UI.outlined(UI.label(fd["name"], 52, Color.WHITE, true), 10)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l1)
	var l2 = UI.outlined(UI.label(fd["sub"], 24, fd["accent"]), 6)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l2)
	box.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)
	Sfx.play("link", 0.8, -6)


func _story(id: String) -> void:
	var done = [false]
	Main.inst.play_story(id, func() -> void: done[0] = true)
	while not done[0]:
		await get_tree().process_frame


func _after_boss() -> void:
	var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	if fs.has("boss_post"):
		await _story(fs["boss_post"])
	if DB.floor_data(Game.floor_num).get("final", false):
		Main.inst.goto("ending", {})
		return
	var ftitle = "floor%d" % Game.floor_num
	if DB.Titles.DATA.has(ftitle):
		Game.award_title(ftitle, "")
	Game.check_skits("after_boss")
	# 層クリア：エレベーターで次の層へ
	for m in Game.party:
		m["sp"] += 2
	Game.notified.emit("層を踏破！ 全員のSPが2増えた", "info")
	Game.next_floor()
	Game.save_game()
	Main.inst.goto("map", {"new_floor": true})


func _prologue_after_battle() -> void:
	await _story("p3_tragedy")
	await _story("p4_prince")
	await _story("p5_lab")
	await _story("p6_entry")
	Game.flags.erase("nine_absent")
	Game.flags.erase("pots_absent")
	Game.full_heal_party()
	Game.gen_map()
	Main.inst.goto("map", {"new_floor": true})


# ------------------------------------------------------------ 加護の選択
func _buff_choice(title: String, n: int) -> void:
	var opts: Array = Game.random_buffs(n)
	if opts.is_empty():
		return
	if Game.should_tutorial("buff"):
		await Main.inst.show_tutorial("buff")
	var picked = [""]
	var layer = Control.new()
	UI.full(layer)
	add_child(layer)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	UI.full(dim)
	layer.add_child(dim)
	var head = UI.outlined(UI.label(title, 30, UI.C_GOLD, true), 6)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 110)
	head.size = Vector2(1280, 50)
	layer.add_child(head)
	var sub = UI.label("この層をクリアするまで有効。層ごとに戦い方が変わる！", 18, UI.C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 160)
	sub.size = Vector2(1280, 30)
	layer.add_child(sub)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	hb.position = Vector2(110, 230)
	layer.add_child(hb)
	for id in opts:
		var b: Dictionary = DB.buff(id)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(330, 280)
		btn.text = ""
		var v = VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = Vector2(20, 20)
		v.size = Vector2(290, 240)
		btn.add_child(v)
		var rare: bool = b["rarity"] >= 2
		var nl = UI.label(b["name"], 26, Color(1.0, 0.6, 0.9) if rare else UI.C_BLUE, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		if rare:
			var rl = UI.label("― 希少 ―", 16, Color(1.0, 0.6, 0.9))
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(rl)
		var dl = UI.label(b["desc"], 20)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(290, 0)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(dl)
		var bid: String = id
		btn.pressed.connect(func() -> void:
			Sfx.play("confirm")
			picked[0] = bid)
		btn.focus_entered.connect(func() -> void: Sfx.play("select"))
		btn.mouse_entered.connect(btn.grab_focus)
		hb.add_child(btn)
	UI.focus_first(hb)
	while picked[0] == "":
		await get_tree().process_frame
	Game.add_floor_buff(picked[0])
	layer.queue_free()


# ------------------------------------------------------------ 画面
func _refresh() -> void:
	_update_skit_btn()


func _on_skit_available(_sid: String) -> void:
	Main.inst.toast("スキットが発生しました！ " + Game.btn("skit"), "skit")
	_update_skit_btn()


func _play_next_skit() -> void:
	if Game.pending_skits.is_empty() or locked:
		return
	var sid: String = Game.pending_skits[0]
	var data: Dictionary = DB.Skits.DATA[sid].duplicate()
	data["mode"] = "skit"
	locked = true
	Main.inst.play_dialogue(data, func() -> void:
		Game.mark_skit_seen(sid)
		_refresh()
		locked = false)


func _open_menu() -> void:
	if locked:
		return
	locked = true
	_save_pos()
	Main.inst.goto("menu", {"back": "map"})


func _unhandled_input(event: InputEvent) -> void:
	if locked or Main.inst.busy:
		return
	if event.is_action_pressed("skit"):
		_play_next_skit()
	elif event.is_action_pressed("menu") or event.is_action_pressed("pause"):
		_open_menu()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		interact()


# ------------------------------------------------------------ 描画（マップ）
func _load_field_backdrop() -> void:
	var path := "res://assets/field_bg/%s.png" % ftheme
	if not ResourceLoader.exists(path):
		return
	field_backdrop = load(path) as Texture2D
	if field_backdrop == null:
		return
	# 歩ける場所を囲む壁は一列以上残し、奥の壁とマップ外から遠景を見せる。
	# このマスクは描画専用。地形データや当たり判定には使わない。
	backdrop_mask.resize(W * H)
	for y in range(H):
		for x in range(W):
			var tile := ch(x, y)
			if tile == " " or (tile == "#" and _is_deep_wall(x, y)):
				backdrop_mask[y * W + x] = 1


func _is_deep_wall(x: int, y: int) -> bool:
	for yy in range(maxi(0, y - 1), mini(H, y + 2)):
		for xx in range(maxi(0, x - 1), mini(W, x + 2)):
			if not FieldArt.is_wallish(ch(xx, yy)):
				return false
	return true


func _draw_field_backdrop(ci: CanvasItem) -> void:
	var travel := (Vector2(W, H) * TS - VIEW).max(Vector2.ONE)
	var progress := (cam / travel).clamp(Vector2.ZERO, Vector2.ONE)
	var overscan := Vector2(160.0, 90.0)
	var area := VIEW + overscan
	# アスペクト比を保って画面を覆い、地形よりゆっくり動かす。
	var source := field_backdrop.get_size()
	var scale_factor := maxf(area.x / source.x, area.y / source.y)
	var size := source * scale_factor
	var pan := overscan * progress * Vector2(1.0, 0.6)
	var offset := ((size - VIEW - overscan) / 2.0 + pan).round()
	ci.draw_texture_rect(field_backdrop, Rect2(cam - offset, size), false, Color(0.90, 0.94, 0.93))


func _shows_backdrop(x: int, y: int) -> bool:
	return x < 0 or x >= W or y < 0 or y >= H or backdrop_mask[y * W + x] == 1


func _draw_backdrop_ledge(ci: CanvasItem, x: int, y: int) -> void:
	# 森の縁に岩肌を重ね、手前の地形が遠景より高いことを示す。
	var edge := Vector2(x * TS, (y + 1) * TS)
	var left := 8.0 if _shows_backdrop(x - 1, y) else 0.0
	var right := 8.0 if _shows_backdrop(x + 1, y) else 0.0
	var depth_px := 32.0 + 4.0 * ((x * 7 + y * 3) % 3)
	UI.poly(ci, PackedVector2Array([
		edge, edge + Vector2(TS, 0), edge + Vector2(TS - right, depth_px - right),
		edge + Vector2(TS - right * 2.0, depth_px), edge + Vector2(left * 2.0, depth_px),
		edge + Vector2(left, depth_px - left)
	]), Color("#37494a"))
	ci.draw_rect(Rect2(edge, Vector2(TS, 8)), Color("#586753"))
	for i in range(3):
		var dx := float(12 + i * 16 + (x + y + i) % 2 * 4)
		ci.draw_rect(Rect2(edge + Vector2(dx, 8), Vector2(8, depth_px - 12 - i * 4)), Color("#495a52"))
		ci.draw_rect(Rect2(edge + Vector2(dx, 8), Vector2(4, 12)), Color("#68715a"))


func _has_grass_detail(x: int, y: int) -> bool:
	return grass_detail != null and GRASS_DETAIL_AREA.has_point(Vector2i(x, y))


func _draw_detail_ground(ci: CanvasItem, c: String, x: int, y: int) -> bool:
	if not _has_grass_detail(x, y) or c not in ".,:\"TPECLMNF?BG":
		return false
	var cell: Vector2i
	var mark := absi(x * 37 + y * 19 + x * y * 11)
	if c == ":":
		var road := 0
		if ch(x, y - 1) == ":":
			road |= 1
		if ch(x + 1, y) == ":":
			road |= 2
		if ch(x, y + 1) == ":":
			road |= 4
		if ch(x - 1, y) == ":":
			road |= 8
		if (road & 2) != 0 and not _has_grass_detail(x + 1, y):
			# 見本区間の東端で、従来の道の幅へつなぐ。
			cell = Vector2i((road & 1) | ((road & 12) >> 1), 7)
		else:
			var variant := mark % 2
			cell = Vector2i(road % 8, 1 + (road >> 3) + variant * 2)
	else:
		var variant := 6 + mark % 2 if c == "," else mark % 6
		cell = Vector2i(variant, 0)
	var tile_size := Vector2(TS, TS)
	var src_size := Vector2(DETAIL_CELL, DETAIL_CELL)
	var dst := Rect2(Vector2(x, y) * TS, tile_size)
	ci.draw_texture_rect_region(grass_detail, dst, Rect2(Vector2(cell) * src_size, src_size))
	return true


func _draw_detail_tree(ci: CanvasItem, x: int, y: int) -> void:
	var variant := absi(x * 17 + y * 11 + x * y * 3) % 4
	var src := Rect2(variant * DETAIL_CELL, 5 * DETAIL_CELL, DETAIL_CELL, DETAIL_CELL * 2)
	var dst := Rect2(x * TS, (y - 1) * TS, TS, TS * 2)
	ci.draw_texture_rect_region(grass_detail, dst, src)


func _draw_world(ci: CanvasItem) -> void:
	if field_backdrop != null:
		_draw_field_backdrop(ci)
	var x0: int = max(0, int(cam.x / TS) - 1)
	var y0: int = max(0, int(cam.y / TS) - 1)
	var x1: int = min(W - 1, int((cam.x + VIEW.x) / TS) + 1)
	var y1: int = min(H - 1, int((cam.y + VIEW.y) / TS) + 2)
	if field_backdrop != null:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if ch(x, y) == "#" and not _shows_backdrop(x, y) and _shows_backdrop(x, y + 1):
					_draw_backdrop_ledge(ci, x, y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if field_backdrop != null and _shows_backdrop(x, y):
				continue
			var c := ch(x, y)
			if not _draw_detail_ground(ci, c, x, y):
				FieldArt.draw_ground(ci, ftheme, c, x, y, ch(x, y + 1), ch(x, y - 1), t)
	# 中盤ストーリーの地点
	if not gate_open():
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if ch(x, y) == "G":
					var cc := _tile_center(x, y)
					ci.draw_circle(cc, 20.0 + sin(t * 4.0) * 4.0, Color(1.0, 0.75, 0.9, 0.22))
					ci.draw_arc(cc, 26.0 + sin(t * 4.0) * 4.0, 0, TAU, 24, Color(1.0, 0.8, 0.95, 0.5), 2.0)
	# 奥から手前の順に、背の高いもの・置物・キャラを描く
	var items: Array = []
	for y in range(y0, min(H - 1, y1 + 2) + 1):
		for x in range(x0, x1 + 1):
			var c2 := ch(x, y)
			if c2 == "T" or c2 == "o" or (c2 == "+" and not gate_open()):
				items.append([y * TS + TS - 6, 0, Vector2i(x, y), c2])
	for o in objs:
		var p: Vector2 = o["pos"]
		if p.x < cam.x - 200 or p.x > cam.x + VIEW.x + 200 or p.y < cam.y - 100 or p.y > cam.y + VIEW.y + 260:
			continue
		if o["ch"] == "?" and o["done"]:
			continue
		items.append([p.y, 1, o])
	items.append([ppos.y, 2])
	items.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for it in items:
		match it[1]:
			0:
				var pos: Vector2i = it[2]
				if it[3] == "T" and _has_grass_detail(pos.x, pos.y):
					_draw_detail_tree(ci, pos.x, pos.y)
				else:
					FieldArt.draw_tall(ci, ftheme, it[3], pos.x, pos.y, t)
			1:
				_draw_obj(ci, it[2])
			2:
				var blink: bool = invul > 0.0 and fmod(t, 0.2) < 0.1
				FieldArt.draw_walker(ci, "chara_" + Game.leader_id(), Game.leader_id(), ppos, pdir, walk_t, moving, Color(1, 1, 1, 0.45) if blink else Color.WHITE)
	# 調べられる物の吹き出し
	if not near.is_empty():
		var label := _near_label(near)
		var bp: Vector2 = near["pos"] + Vector2(0, -96 - sin(t * 5.0) * 3.0)
		var txt := "%s %s" % [Game.btn("accept"), label]
		var w := UI.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24
		ci.draw_rect(Rect2(bp - Vector2(w / 2.0, 18), Vector2(w, 32)), Color(0.05, 0.06, 0.12, 0.9))
		ci.draw_rect(Rect2(bp - Vector2(w / 2.0, 18), Vector2(w, 32)), UI.C_GOLD, false, 2.0)
		ci.draw_string(UI.FONT_BOLD, bp + Vector2(-w / 2.0 + 12, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _near_label(o: Dictionary) -> String:
	match o["ch"]:
		"C":
			return "開ける"
		"M":
			return "買い物"
		"F":
			return "休む" if not o["done"] else "調べる"
		"N":
			return "話す"
		"?":
			return "調べる"
	return "調べる"


func _draw_obj(ci: CanvasItem, o: Dictionary) -> void:
	var p: Vector2 = o["pos"]
	match o["ch"]:
		"E", "L":
			var g: Array = o["props"].get("g", ["slime"])
			var mod := Color(1, 1, 1, 0.5) if o["stun"] > 0.0 and fmod(t, 0.25) < 0.12 else Color.WHITE
			FieldArt.draw_symbol(ci, g[0], p, o["walk"], o["face"], o["ch"] == "L", o["alert"], mod)
			if g.size() > 1 and o["ch"] == "E":
				# 群れの数（小さな点）
				for i in range(g.size()):
					ci.draw_circle(p + Vector2(-8 * (g.size() - 1) + i * 16, 14), 4.0, Color(1.0, 0.85, 0.3, 0.85))
		"C":
			FieldArt.draw_chest(ci, p, o["done"], t)
		"F":
			FieldArt.draw_campfire(ci, p, o["done"], t)
		"?":
			FieldArt.draw_event_spot(ci, p, t)
		"M":
			FieldArt.draw_walker(ci, "npc_merchant", "towner", p, 0, t, false)
			ci.draw_rect(Rect2(p + Vector2(-34, -8), Vector2(68, 14)), Color(0.5, 0.3, 0.15))
			ci.draw_string(UI.FONT_BOLD, p + Vector2(-14, -96), "店", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.C_GOLD)
		"N":
			var cid: String = o["props"].get("cid", "towner")
			FieldArt.draw_walker(ci, "npc_" + o["props"].get("sprite", cid), cid, p, 0, t, false)
		"B":
			FieldArt.draw_boss(ci, DB.floor_data(Game.floor_num)["boss"][0], p, t)


# ------------------------------------------------------------ 描画（情報表示）
func _draw_hud(ci: Control) -> void:
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	# 層の名前
	ci.draw_rect(Rect2(12, 12, 360, 64), Color(0.03, 0.04, 0.09, 0.78))
	ci.draw_string(UI.FONT_BOLD, Vector2(26, 42), fd["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, fd["accent"])
	var info := "%d ガルド" % Game.gald
	if not Game.floor_buffs.is_empty():
		info += "　加護 %d" % Game.floor_buffs.size()
	if not Game.meal.is_empty():
		info += "　料理 あと%d戦" % Game.meal["left"]
	ci.draw_string(UI.FONT, Vector2(26, 66), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.C_GOLD)
	# パーティ
	var mem: Array = Game.present_party()
	var y := 720.0 - 14 - mem.size() * 26
	ci.draw_rect(Rect2(12, y - 8, 250, mem.size() * 26 + 12), Color(0.03, 0.04, 0.09, 0.72))
	for i in range(mem.size()):
		var m: Dictionary = mem[i]
		var yy := y + i * 26
		ci.draw_string(UI.FONT_BOLD, Vector2(22, yy + 15), "%s" % DB.cname(m["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DB.ccolor(m["id"]).lightened(0.35))
		ci.draw_string(UI.FONT, Vector2(88, yy + 15), "Lv%d" % m["level"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.C_DIM)
		var r: float = float(m["hp"]) / max(1, Game.max_hp(m["id"]))
		ci.draw_rect(Rect2(130, yy + 6, 120, 9), Color(0, 0, 0, 0.6))
		ci.draw_rect(Rect2(130, yy + 6, 120 * r, 9), UI.C_GREEN if r > 0.5 else (UI.C_GOLD if r > 0.25 else UI.C_RED))
	# 小さな地図（通った所だけ見える）
	var mk := 4.0
	var mw := W * mk
	var mh := H * mk
	var mo := Vector2(1280 - mw - 16, 14)
	ci.draw_rect(Rect2(mo - Vector2(6, 6), Vector2(mw + 12, mh + 12)), Color(0.03, 0.04, 0.09, 0.72))
	var P: Dictionary = FieldArt.THEMES[ftheme]
	for yy2 in range(H):
		for xx in range(W):
			if fog[yy2 * W + xx] == 0:
				continue
			var c := ch(xx, yy2)
			var col: Color
			if c in "#T ":
				continue
			elif c == "~":
				col = P["water"]
			elif c == "+" and not gate_open():
				col = Color(0.8, 0.5, 0.3)
			else:
				col = Color(0.85, 0.85, 0.8, 0.85)
			ci.draw_rect(Rect2(mo + Vector2(xx, yy2) * mk, Vector2(mk, mk)), col)
	for o in objs:
		var tp: Vector2i = o["tile"]
		if fog[tp.y * W + tp.x] == 0:
			continue
		var oc := Color.TRANSPARENT
		match o["ch"]:
			"C":
				oc = Color(1.0, 0.8, 0.3) if not o["done"] else Color.TRANSPARENT
			"M":
				oc = Color(0.5, 0.9, 1.0)
			"F":
				oc = Color(1.0, 0.5, 0.2) if not o["done"] else Color.TRANSPARENT
			"B":
				oc = Color(1.0, 0.2, 0.2)
			"?":
				oc = Color(0.7, 0.8, 1.0) if not o["done"] else Color.TRANSPARENT
			"N":
				oc = Color(0.6, 1.0, 0.6)
		if oc.a > 0.0:
			ci.draw_rect(Rect2(mo + Vector2(tp.x, tp.y) * mk - Vector2(1, 1), Vector2(mk + 2, mk + 2)), oc)
	var pp := mo + ppos / TS * mk
	ci.draw_circle(pp, 3.5 + sin(t * 6.0), Color(1.0, 0.3, 0.3))
	# 操作
	var help := "%s 移動　%s 調べる　%s ダッシュ　%s メニュー" % [Game.key("dir") if not Game.pad_mode else Game.key("move"), Game.key("accept"), Game.key("guard"), Game.key("menu")]
	ci.draw_string(UI.FONT, Vector2(1280 - 16 - UI.FONT.get_string_size(help, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 708), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	if flash > 0.0:
		ci.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, flash * 0.8))
# スキットが見られるときは、右パネルの空いた所に目立つ呼び出しを出す
func _update_skit_btn() -> void:
	if is_instance_valid(skit_btn):
		skit_btn.queue_free()
	skit_btn = null
	var n = Game.pending_skits.size()
	if n == 0:
		return
	var sd: Dictionary = DB.Skits.DATA.get(Game.pending_skits[0], {})
	var b = Button.new()
	var normal = UI.box(Color(0.32, 0.1, 0.24, 0.96), Color(1.0, 0.6, 0.85), 4, 14)
	var hover = UI.box(Color(0.45, 0.14, 0.32, 0.98), UI.C_GOLD, 4, 14)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.position = Vector2(916, 576)
	b.custom_minimum_size = Vector2(350, 112)
	b.pressed.connect(func() -> void:
		Sfx.play("confirm")
		_play_next_skit())
	add_child(b)
	skit_btn = b
	var hb = HBoxContainer.new()
	hb.position = Vector2(14, 8)
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	# 登場する仲間の顔
	var who: Array = []
	for ln in sd.get("lines", []):
		if ln[0] != "" and DB.Characters.DATA.has(ln[0]) and not ln[0] in who:
			who.append(ln[0])
		if who.size() >= 3:
			break
	for cid in who:
		var por = Portrait.new()
		por.custom_minimum_size = Vector2(50, 92)
		por.mouse_filter = Control.MOUSE_FILTER_IGNORE
		por.setup(cid, "smile")
		hb.add_child(por)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var head = UI.outlined(UI.label("スキット発生！", 25, UI.C_GOLD, true), 5)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var ttl = UI.label("「%s」" % sd.get("title", "") + ("" if n == 1 else " ほか%d件" % (n - 1)), 16, Color(1.0, 0.85, 0.95))
	ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ttl)
	var how = UI.label("", 18, Color.WHITE, true)
	how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.live_text(how, func() -> String: return Game.btn("skit") + " で見る")
	v.add_child(how)
	# 脈打つように光らせて目を引く
	b.pivot_offset = Vector2(175, 56)
	b.scale = Vector2(0.6, 0.6)
	var pop = b.create_tween()
	pop.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow = b.create_tween().set_loops()
	glow.tween_property(b, "modulate", Color(1.25, 1.15, 1.25), 0.6).set_trans(Tween.TRANS_SINE)
	glow.tween_property(b, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
