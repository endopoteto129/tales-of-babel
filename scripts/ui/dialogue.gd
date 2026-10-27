# 会話プレイヤー（ストーリー記録・スキット・焚火会話で共通）
# lines の書式: [話者id, 本文, 表情] / 話者 "" はナレーション / "@命令" は演出コマンド
extends Control

signal finished

var data: Dictionary
var lines: Array = []
var idx := -1
var mode := "story"
var bg := "black"
var title_text := ""

var portraits: Dictionary = {}   # cid -> Portrait
var order: Array = []            # 表示中の話者の並び
var text_label: RichTextLabel
var name_panel: PanelContainer
var name_label: Label
var box: PanelContainer
var narr_label: Label
var title_label: Label
var hint_label: Label
var caption: Label
var typing := false
var shown_chars := 0.0
var speed := 45.0
var t := 0.0
var shake := 0.0
var flash := 0.0
var flash_color := Color.WHITE
var _done := false
var _input_lock := 0.25


func setup(d: Dictionary) -> void:
	data = d
	lines = d.get("lines", [])
	mode = d.get("mode", "story")
	bg = d.get("bg", "black" if mode == "story" else "none")
	title_text = d.get("title", "")


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var stage = Control.new()
	stage.name = "Stage"
	UI.full(stage)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	box = UI.panel(Color(0.04, 0.05, 0.1, 0.98), Color(0.8, 0.68, 0.45))
	var bsb: StyleBoxFlat = box.get_theme_stylebox("panel")
	bsb.content_margin_top = 30
	bsb.content_margin_left = 30
	box.position = Vector2(110, 520)
	box.size = Vector2(1060, 170)
	box.custom_minimum_size = Vector2(1060, 170)
	add_child(box)
	# 立ち絵（話者は z_index=1）より常に文字を手前に出す
	box.z_index = 5
	text_label = UI.rich("", 24)
	text_label.custom_minimum_size = Vector2(1020, 130)
	text_label.fit_content = false
	box.add_child(text_label)

	name_panel = UI.panel(Color(0.15, 0.1, 0.1, 0.96), UI.C_GOLD)
	name_panel.position = Vector2(130, 486)
	add_child(name_panel)
	name_panel.z_index = 5
	name_label = UI.label("", 22, UI.C_GOLD, true)
	name_panel.add_child(name_label)

	narr_label = UI.outlined(UI.label("", 26, UI.C_TEXT), 4)
	narr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narr_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narr_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narr_label.position = Vector2(140, 180)
	narr_label.size = Vector2(1000, 300)
	add_child(narr_label)
	narr_label.z_index = 5

	title_label = UI.outlined(UI.label(title_text, 22, Color(0.9, 0.95, 1.0)), 4)
	title_label.position = Vector2(30, 24)
	add_child(title_label)
	title_label.z_index = 5
	if mode == "skit":
		title_label.text = "SKIT  ―  " + title_text
		title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.9))
	elif mode == "camp":
		title_label.text = "焚火  ―  " + title_text
		title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	if title_label.text != "":
		# 下の画面の文字と重ならないよう、見出しに帯を敷く
		var tb = ColorRect.new()
		tb.color = Color(0.03, 0.03, 0.08, 0.92)
		tb.position = Vector2(0, 18)
		tb.size = Vector2(title_label.get_minimum_size().x + 80, 44)
		add_child(tb)
		tb.z_index = 4
		move_child(tb, title_label.get_index())

	caption = UI.outlined(UI.label("", 40, Color(1, 1, 1), true), 8)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 300)
	caption.size = Vector2(1280, 80)
	caption.modulate.a = 0.0
	add_child(caption)
	caption.z_index = 6

	hint_label = UI.outlined(UI.label("", 16, UI.C_DIM), 3)
	UI.live_text(hint_label, func() -> String: return "%s: 進む　%s: スキップ" % [Game.key("accept"), Game.key("pause")])
	hint_label.position = Vector2(1000, 694)
	add_child(hint_label)
	hint_label.z_index = 5
	_next()


func _process(delta: float) -> void:
	t += delta
	_input_lock -= delta
	shake = max(0.0, shake - delta * 2.0)
	flash = max(0.0, flash - delta * 2.5)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0
	if typing:
		shown_chars += delta * speed
		var total = text_label.get_total_character_count()
		text_label.visible_characters = int(shown_chars)
		if int(shown_chars) % 3 == 0 and int(shown_chars) != int(shown_chars - delta * speed):
			Sfx.play("text", 1.0, -8)
		if shown_chars >= total:
			typing = false
			text_label.visible_characters = -1
	queue_redraw()


func _draw() -> void:
	var r = Rect2(Vector2(-20, -20), size + Vector2(40, 40))
	match bg:
		"black":
			draw_rect(r, Color(0.02, 0.02, 0.04, 1.0))
			for i in range(30):
				var p = Vector2(fmod(i * 197.0 + t * (8 + i % 5), 1300.0), fmod(i * 83.0 - t * (5 + i % 3) * 3.0, 740.0))
				if p.y < 0:
					p.y += 740
				draw_circle(p, 1.5 + (i % 3), Color(0.8, 0.85, 1.0, 0.15))
		"rec":
			draw_rect(r, Color(0.03, 0.05, 0.06, 1.0))
			for y in range(0, 720, 4):
				draw_line(Vector2(0, y), Vector2(1280, y), Color(0.3, 0.6, 0.6, 0.06), 1.0)
			draw_rect(Rect2(20, 14, 1240, 692), Color(0.5, 0.9, 0.9, 0.35), false, 2.0)
			if fmod(t, 1.2) < 0.7:
				draw_circle(Vector2(1180, 40), 9, Color(1.0, 0.2, 0.2))
			draw_string(UI.FONT_BOLD, Vector2(1196, 48), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.3, 0.3))
			draw_string(UI.FONT, Vector2(1050, 76), "P-02 LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.9, 0.8))
		"red":
			draw_rect(r, Color(0.25, 0.02, 0.03, 1.0))
		"white":
			draw_rect(r, Color(0.92, 0.92, 0.95, 1.0))
		"camp":
			draw_rect(r, Color(0.03, 0.03, 0.08, 0.96))
			var glow = 0.25 + sin(t * 7.0) * 0.03 + sin(t * 13.0) * 0.02
			for i in range(8):
				draw_circle(Vector2(640, 470), 420 - i * 45, Color(1.0, 0.5, 0.15, glow * 0.12))
		"floor":
			var fd: Dictionary = DB.floor_data(Game.floor_num)
			var top: Color = fd["bg_top"]
			var bot: Color = fd["bg_bottom"]
			for i in range(24):
				var y = i * 31.0
				draw_rect(Rect2(-20, y - 20, 1320, 32), top.lerp(bot, i / 23.0))
			draw_rect(r, Color(0, 0, 0, 0.35))
		"none":
			draw_rect(r, Color(0, 0, 0, 0.55))
	if flash > 0.0:
		draw_rect(r, Color(flash_color.r, flash_color.g, flash_color.b, flash))


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_skip_all()
		return
	var adv = event.is_action_pressed("ui_accept") or event.is_action_pressed("attack") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if adv:
		get_viewport().set_input_as_handled()
		if _input_lock > 0.0:
			return
		if typing:
			typing = false
			text_label.visible_characters = -1
		else:
			_next()


func _skip_all() -> void:
	# 演出コマンド（加入・称号など）は飛ばさずに実行する
	while idx < lines.size() - 1:
		idx += 1
		var line: Array = lines[idx]
		if str(line[0]).begins_with("@"):
			_command(line, true)
	_finish()


func _next() -> void:
	while true:
		idx += 1
		if idx >= lines.size():
			_finish()
			return
		var line: Array = lines[idx]
		var sp = str(line[0])
		if sp.begins_with("@"):
			var wait = _command(line, false)
			if wait:
				return
			continue
		_show_line(sp, str(line[1]), str(line[2]) if line.size() > 2 else "")
		return


func _command(line: Array, skipping: bool) -> bool:
	var cmd = str(line[0])
	match cmd:
		"@join":
			Game.join(line[1])
		"@title":
			Game.award_title(line[1], line[2] if line.size() > 2 else "")
		"@flag":
			Game.flags[line[1]] = true
		"@unflag":
			Game.flags.erase(line[1])
		"@buff":
			Game.add_floor_buff(line[1])
		"@item":
			Game.add_item(line[1], line[2] if line.size() > 2 else 1)
		"@recipe":
			if not line[1] in Game.known_recipes:
				Game.known_recipes.append(line[1])
				Game.notified.emit("レシピ『%s』を覚えた！" % DB.Items.RECIPES[line[1]]["name"], "info")
		"@bg":
			bg = line[1]
		"@shake":
			if not skipping:
				shake = 1.0
				Sfx.play("hit_heavy")
		"@flash":
			if not skipping:
				flash = 1.0
				flash_color = Color.html(line[1]) if line.size() > 1 else Color.WHITE
		"@sfx":
			if not skipping:
				Sfx.play(line[1])
		"@leave":
			_remove_portrait(line[1])
		"@clear":
			for k in portraits.keys():
				_remove_portrait(k)
		"@caption":
			if not skipping:
				_show_caption(line[1])
				return true
		"@title_card":
			if not skipping:
				_show_caption(line[1], 2.2)
				return true
	return false


func _show_caption(text: String, dur: float = 1.6) -> void:
	caption.text = text
	box.visible = false
	name_panel.visible = false
	narr_label.text = ""
	var tw = create_tween()
	tw.tween_property(caption, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(caption, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next)


func _show_line(sp: String, text: String, expr: String) -> void:
	text = text.replace("{leader}", DB.cname("ren"))
	if sp == "":
		box.visible = false
		name_panel.visible = false
		narr_label.text = text
		narr_label.modulate.a = 0.0
		create_tween().tween_property(narr_label, "modulate:a", 1.0, 0.4)
		typing = false
		for k in portraits:
			portraits[k].modulate = Color(0.45, 0.45, 0.5)
		return
	narr_label.text = ""
	box.visible = true
	var known = DB.Characters.DATA.has(sp)
	name_panel.visible = true
	name_label.text = DB.cname(sp) if known else sp
	if known:
		name_label.add_theme_color_override("font_color", DB.ccolor(sp).lightened(0.35))
		_ensure_portrait(sp, expr)
	else:
		name_label.add_theme_color_override("font_color", UI.C_GOLD)
	text_label.text = text
	text_label.visible_characters = 0
	shown_chars = 0.0
	typing = true
	for k in portraits:
		var p: Portrait = portraits[k]
		var active: bool = k == sp
		p.modulate = Color(1, 1, 1) if active else Color(0.5, 0.5, 0.58)
		p.z_index = 1 if active else 0


func _ensure_portrait(cid: String, expr: String) -> void:
	var stage: Control = get_node("Stage")
	if not portraits.has(cid):
		if order.size() >= 4:
			_remove_portrait(order[0])
		var p = Portrait.new()
		p.size = Vector2(300, 360)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(p)
		portraits[cid] = p
		order.append(cid)
		p.modulate.a = 0.0
		_layout()
		p.position.y += 40
		var tw = p.create_tween().set_parallel()
		tw.tween_property(p, "modulate:a", 1.0, 0.25)
		tw.tween_property(p, "position:y", p.position.y - 40, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var por: Portrait = portraits[cid]
	var changed = por.expr != expr
	por.setup(cid, expr, por.flip)
	if changed and expr in ["surprise", "angry", "laugh"]:
		var y0 = 170.0
		var tw2 = por.create_tween()
		tw2.tween_property(por, "position:y", y0 - 24, 0.08)
		tw2.tween_property(por, "position:y", y0, 0.12)


func _layout() -> void:
	var n = order.size()
	var slots = {1: [490.0], 2: [200.0, 780.0], 3: [80.0, 490.0, 900.0], 4: [20.0, 330.0, 640.0, 950.0]}
	var xs: Array = slots[max(1, n)]
	for i in range(n):
		var p: Portrait = portraits[order[i]]
		var x: float = xs[i]
		p.flip = x > 500.0
		var target = Vector2(x, 170)
		if p.modulate.a < 0.5:
			p.position = target
		else:
			p.create_tween().tween_property(p, "position", target, 0.2)


func _remove_portrait(cid: String) -> void:
	if not portraits.has(cid):
		return
	var p: Portrait = portraits[cid]
	portraits.erase(cid)
	order.erase(cid)
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	tw.tween_callback(p.queue_free)
	_layout()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
