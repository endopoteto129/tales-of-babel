# 塔の層マップ（スレイ・ザ・スパイア風のルート選択）と、進行の司令塔
extends Control

const ICON := {"battle": "戦", "elite": "強", "shop": "店", "event": "？", "camp": "焚", "story": "話", "boss": "王"}
const TYPE_NAME := {"battle": "戦闘", "elite": "強敵", "shop": "ショップ", "event": "イベント", "camp": "焚火", "story": "ストーリー", "boss": "ボス"}
const TYPE_COLOR := {"battle": Color(0.85, 0.85, 0.9), "elite": Color(1.0, 0.45, 0.35), "shop": Color(1.0, 0.85, 0.35), "event": Color(0.6, 0.85, 1.0),
	"camp": Color(1.0, 0.6, 0.25), "story": Color(1.0, 0.7, 0.9), "boss": Color(1.0, 0.25, 0.3)}

var params: Dictionary = {}
var t := 0.0
var sel_idx := 0
var selectable: Array = []
var hover_id := -1
var side: VBoxContainer
var info_label: RichTextLabel
var skit_btn: Button
var locked := true
var node_pos: Dictionary = {}


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	UI.full(self)
	_compute_positions()
	_build_side()
	Game.skit_available.connect(_on_skit_available)
	_arrive()


func _exit_tree() -> void:
	if Game.skit_available.is_connected(_on_skit_available):
		Game.skit_available.disconnect(_on_skit_available)


func _compute_positions() -> void:
	node_pos.clear()
	for id in Game.map["nodes"]:
		var n: Dictionary = Game.map["nodes"][id]
		var col: float = float(n["col"])
		var x = 150.0 + col * 200.0 + float(n.get("jx", 0.0))
		var y = 650.0 - n["row"] * 70.0 + float(n.get("jy", 0.0))
		node_pos[int(id)] = Vector2(x, y)


# ------------------------------------------------------------ 到着時の処理（進行の分岐）
func _arrive() -> void:
	locked = true
	var after: String = params.get("after_battle", "")
	if after != "":
		if params.get("won", false) or params.get("escaped", false):
			Game.complete_node()
		if after == "prologue":
			await _prologue_after_battle()
			return
		if after == "boss" and params.get("won", false):
			await _after_boss()
			return
		if after == "elite" and params.get("won", false):
			await _buff_choice("強敵を倒した！ 加護をひとつ選ぼう", 3)
			Game.check_skits("after_elite")
		elif params.get("won", false):
			Game.check_skits("after_battle")
	elif params.get("after", "") != "":
		Game.complete_node()
		Game.check_skits("after_" + params["after"])
	elif params.get("new_floor", false) or Game.map["current"] < 0 and not Game.flags.get("floor_started_%d" % Game.floor_num, false):
		await _floor_start()
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
func _build_side() -> void:
	var p = UI.panel(Color(0.04, 0.05, 0.1, 0.88))
	p.position = Vector2(900, 16)
	p.custom_minimum_size = Vector2(366, 688)
	add_child(p)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	p.add_child(side)


func _refresh() -> void:
	for c in side.get_children():
		c.queue_free()
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	side.add_child(UI.label(fd["name"], 22, fd["accent"], true))
	side.add_child(UI.label(fd["sub"], 15, UI.C_DIM))
	side.add_child(HSeparator.new())
	for m in Game.present_party():
		var hb = HBoxContainer.new()
		var nm = UI.label("%s Lv%d" % [DB.cname(m["id"]), m["level"]], 17, DB.ccolor(m["id"]).lightened(0.3), true)
		nm.custom_minimum_size = Vector2(130, 0)
		hb.add_child(nm)
		var active: bool = m in Game.active_party()
		hb.add_child(UI.label("HP %d/%d" % [m["hp"], Game.max_hp(m["id"])], 16, UI.C_TEXT if active else UI.C_DIM))
		if m["sp"] > 0:
			hb.add_child(UI.label(" SP%d" % m["sp"], 14, UI.C_GOLD))
		side.add_child(hb)
	side.add_child(UI.label("所持金  %d ガルド" % Game.gald, 17, UI.C_GOLD))
	side.add_child(HSeparator.new())
	side.add_child(UI.label("層の加護", 17, UI.C_BLUE, true))
	if Game.floor_buffs.is_empty():
		side.add_child(UI.label("なし", 15, UI.C_DIM))
	for b in Game.floor_buffs:
		var l = UI.label("・" + DB.buff(b)["name"], 15, UI.C_TEXT)
		l.tooltip_text = DB.buff(b)["desc"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		side.add_child(l)
	if not Game.meal.is_empty():
		side.add_child(UI.label("料理：%s（あと%d戦）" % [DB.Items.RECIPES[Game.meal["id"]]["name"], Game.meal["left"]], 15, Color(1, 0.75, 0.5)))
	side.add_child(HSeparator.new())
	info_label = UI.rich("", 16)
	info_label.custom_minimum_size = Vector2(340, 70)
	side.add_child(info_label)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_update_skit_btn()
	var menu_btn = UI.button("", _open_menu, 18)
	UI.live_text(menu_btn, func() -> String: return "メニュー " + Game.btn("menu"))
	side.add_child(menu_btn)
	var help = UI.label("", 14, UI.C_DIM)
	UI.live_text(help, func() -> String: return "%sで選択／%sで進む" % [Game.key("move"), Game.key("accept")])
	side.add_child(help)
	selectable = Game.selectable_nodes()
	selectable.sort_custom(func(a, b) -> bool: return node_pos[a].x < node_pos[b].x)
	sel_idx = clamp(sel_idx, 0, max(0, selectable.size() - 1))
	_update_info()


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
	b.position = Vector2(908, 492)
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
	Main.inst.goto("menu", {"back": "map"})


func _update_info() -> void:
	if selectable.is_empty() or not is_instance_valid(info_label):
		return
	var id: int = selectable[sel_idx]
	var n: Dictionary = Game.node(id)
	var desc = ""
	match n["type"]:
		"battle":
			desc = "塔の魔物との戦闘。"
		"elite":
			desc = "手強い敵が待ち構えている。勝てば加護を得られる。"
		"shop":
			desc = "行商の異形が店を開いている。"
		"event":
			desc = "何かが起こりそうだ。"
		"camp":
			desc = "焚火を囲んで休息できる。"
		"story":
			desc = "物語が動く。（必ず通る）"
		"boss":
			desc = "この層の主が待つ。エレベーターはその先だ。"
	info_label.text = "[b][color=#%s]%s[/color][/b]\n%s" % [TYPE_COLOR[n["type"]].to_html(false), TYPE_NAME[n["type"]], desc]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


var stick_dir := 0


func _unhandled_input(event: InputEvent) -> void:
	if locked or Main.inst.busy:
		return
	if event.is_action_pressed("skit"):
		_play_next_skit()
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("pause"):
		_open_menu()
		return
	if selectable.is_empty():
		return
	if event is InputEventJoypadMotion:
		# スティックは倒した瞬間だけ1マス動かす
		if event.axis != JOY_AXIS_LEFT_X:
			return
		var d = 0 if abs(event.axis_value) < 0.5 else int(sign(event.axis_value))
		if d == stick_dir:
			return
		stick_dir = d
		if d != 0:
			sel_idx = (sel_idx + d + selectable.size()) % selectable.size()
			Sfx.play("select")
			_update_info()
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		sel_idx = (sel_idx - 1 + selectable.size()) % selectable.size()
		Sfx.play("select")
		_update_info()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		sel_idx = (sel_idx + 1) % selectable.size()
		Sfx.play("select")
		_update_info()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		_enter(selectable[sel_idx])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(selectable.size()):
			if node_pos[selectable[i]].distance_to(event.position) < 30:
				sel_idx = i
				_enter(selectable[i])
				return
	elif event is InputEventMouseMotion:
		for i in range(selectable.size()):
			if node_pos[selectable[i]].distance_to(event.position) < 30 and sel_idx != i:
				sel_idx = i
				Sfx.play("select")
				_update_info()


func _enter(id: int) -> void:
	if locked:
		return
	locked = true
	Sfx.play("confirm")
	Game.enter_node(id)
	var n: Dictionary = Game.node(id)
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	match n["type"]:
		"battle":
			var g: Array = fd["groups"][Game.rng.randi() % fd["groups"].size()]
			Main.inst.goto("battle", {"enemies": g, "kind": "battle"})
		"elite":
			var e: Array = fd["elites"][Game.rng.randi() % fd["elites"].size()]
			Main.inst.goto("battle", {"enemies": e, "kind": "elite"})
		"shop":
			Main.inst.goto("shop", {})
		"event":
			Main.inst.goto("event", {})
		"camp":
			Main.inst.goto("camp", {})
		"story":
			var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
			if fs.has("mid"):
				await _story(fs["mid"])
			Game.complete_node()
			Game.check_skits("story_mid")
			for m in Game.party:
				m["hp"] = max(m["hp"], int(Game.max_hp(m["id"]) * 0.5))
			Game.save_game()
			_refresh()
			locked = false
		"boss":
			var fs2: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
			if fs2.has("boss_pre"):
				await _story(fs2["boss_pre"])
			Main.inst.goto("battle", {"enemies": fd["boss"], "kind": "boss"})


func _draw() -> void:
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	var top: Color = fd["bg_top"]
	var bot: Color = fd["bg_bottom"]
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), top.lerp(bot, i / 23.0).darkened(0.35))
	# 塔の外壁
	draw_rect(Rect2(40, 20, 820, 680), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(40, 20, 820, 680), Color(fd["accent"].r, fd["accent"].g, fd["accent"].b, 0.25), false, 2.0)
	for i in range(12):
		draw_line(Vector2(40, 20 + i * 57), Vector2(860, 20 + i * 57), Color(1, 1, 1, 0.03), 1.0)
	var nodes: Dictionary = Game.map["nodes"]
	var cur: int = Game.map["current"]
	# 層の切り替え直後（新しいマップに描き直す前）は描かない
	for id in nodes:
		if not node_pos.has(int(id)):
			return
	# 道
	for id in nodes:
		var n: Dictionary = nodes[id]
		for nx in n["next"]:
			var a: Vector2 = node_pos[int(id)]
			var b: Vector2 = node_pos[int(nx)]
			var walked: bool = n["done"] and (nodes[nx]["done"] or nx == cur)
			var col = Color(1, 0.9, 0.6, 0.9) if walked else Color(1, 1, 1, 0.22)
			var seg = 10
			for s in range(seg):
				if s % 2 == 0:
					draw_line(a.lerp(b, float(s) / seg), a.lerp(b, float(s + 1) / seg), col, 3.0 if walked else 2.0)
	# マス
	for id in nodes:
		var n: Dictionary = nodes[id]
		var p: Vector2 = node_pos[int(id)]
		var tc: Color = TYPE_COLOR[n["type"]]
		var r = 24.0 if n["type"] != "boss" else 34.0
		var is_sel: bool = not selectable.is_empty() and selectable[sel_idx] == int(id) and not locked
		var can: bool = int(id) in selectable
		if can:
			var pulse = 4.0 + sin(t * 5.0) * 3.0
			draw_circle(p, r + pulse + (6 if is_sel else 0), Color(tc.r, tc.g, tc.b, 0.25))
		var fill = Color(0.08, 0.08, 0.12, 0.95)
		if n["done"]:
			fill = Color(0.25, 0.22, 0.18, 0.95)
		draw_circle(p, r, fill)
		draw_arc(p, r, 0, TAU, 32, tc if (can or n["done"] or int(id) == cur) else Color(tc.r, tc.g, tc.b, 0.45), 3.0 if not is_sel else 5.0)
		var icon: String = ICON[n["type"]]
		var fs = 24 if n["type"] != "boss" else 32
		draw_string(UI.FONT_BOLD, p + Vector2(-fs / 2.0, fs / 2.6), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc if not n["done"] else Color(0.6, 0.6, 0.6))
		if int(id) == cur:
			_draw_party_marker(p)
	if cur < 0:
		_draw_party_marker(Vector2(450, 700))
	draw_string(UI.FONT_BOLD, Vector2(60, 56), "%dF" % Game.floor_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.5))


func _draw_party_marker(p: Vector2) -> void:
	var y = sin(t * 4.0) * 4.0
	draw_circle(p + Vector2(0, -42 + y), 10, Color(0.85, 0.22, 0.24))
	draw_circle(p + Vector2(14, -38 + y), 7, Color(1.0, 0.62, 0.3))
	UI.poly(self, PackedVector2Array([p + Vector2(-6, -30 + y), p + Vector2(6, -30 + y), p + Vector2(0, -22 + y)]), Color(0.85, 0.22, 0.24))
