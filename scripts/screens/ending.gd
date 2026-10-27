# エンディング（スタッフロール）。物語はジンが記した『バベルの塔の物語』として締めくくられ、
# 最後にレンとナインの場面、玉座のポッツの天気予報、雲の上の塔と太陽を映して暗転する。
extends Control

var t := 0.0
var roll: VBoxContainer
var speed := 38.0
var done := false
var final_t := -1.0  # 0以上なら、最後の「塔と太陽」の画面


func _ready() -> void:
	UI.full(self)
	roll = VBoxContainer.new()
	roll.position = Vector2(0, 740)
	roll.custom_minimum_size = Vector2(1280, 0)
	roll.add_theme_constant_override("separation", 18)
	add_child(roll)
	var lines: Array = DB.Story.CREDITS
	for ln in lines:
		var size = 22
		var col = UI.C_TEXT
		var bold = false
		var text: String = ln
		if text.begins_with("# "):
			size = 44
			col = UI.C_GOLD
			bold = true
			text = text.substr(2)
		elif text.begins_with("## "):
			size = 28
			col = Color(1.0, 0.75, 0.5)
			bold = true
			text = text.substr(3)
		var l = UI.outlined(UI.label(text, size, col, bold), 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1280, 0)
		roll.add_child(l)
	Game.flags["cleared"] = true
	Game.save_game()


func _process(delta: float) -> void:
	t += delta
	var sp = speed * (4.0 if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("attack") else 1.0)
	roll.position.y -= sp * delta
	if roll.position.y + roll.size.y < 300 and not done:
		done = true
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree():
			return
		var data: Dictionary = DB.Story.AFTER_CREDITS.duplicate()
		data["mode"] = "story"
		Main.inst.play_dialogue(data, func() -> void:
			if is_inside_tree():
				_final_shot())
	if final_t >= 0.0:
		final_t += delta
	queue_redraw()


# そびえたつ塔と、雲の上で煌めく太陽。ゆっくり映したあと暗転して終わり。
func _final_shot() -> void:
	roll.visible = false
	final_t = 0.0
	await get_tree().create_timer(7.0).timeout
	if is_inside_tree():
		Main.inst.goto("title")


func _draw() -> void:
	if final_t >= 0.0:
		_draw_final()
		return
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(0.25, 0.35, 0.65).lerp(Color(0.95, 0.8, 0.75), i / 23.0))
	for i in range(8):
		var cx = fmod(i * 210.0 + t * (8 + i), 1500.0) - 100
		draw_circle(Vector2(cx, 500 + (i % 3) * 60), 60, Color(1, 1, 1, 0.5))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.35))


func _draw_final() -> void:
	var ft := final_t
	# 空（上は濃い青、地平は金色）
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(0.12, 0.28, 0.62).lerp(Color(1.0, 0.86, 0.6), i / 23.0))
	# 太陽：雲の上で煌めく
	var sun := Vector2(880, 190)
	for k in range(12):
		var a: float = k * TAU / 12.0 + ft * 0.15
		var len := 150.0 + sin(ft * 2.2 + k) * 22.0
		draw_line(sun + Vector2(cos(a), sin(a)) * 64, sun + Vector2(cos(a), sin(a)) * len, Color(1.0, 0.95, 0.7, 0.35), 6.0)
	draw_circle(sun, 96, Color(1.0, 0.95, 0.75, 0.25))
	draw_circle(sun, 62, Color(1.0, 0.97, 0.85))
	var tw := 0.5 + 0.5 * sin(ft * 5.0)
	draw_line(sun + Vector2(-110, 0), sun + Vector2(110, 0), Color(1, 1, 1, 0.5 * tw), 3.0)
	draw_line(sun + Vector2(0, -110), sun + Vector2(0, 110), Color(1, 1, 1, 0.5 * tw), 3.0)
	# 塔：画面下から雲を突き抜けてそびえる
	var cx := 430.0
	var top := 120.0
	var pts := PackedVector2Array([Vector2(cx - 120, 720), Vector2(cx - 34, top + 40), Vector2(cx, top), Vector2(cx + 34, top + 40), Vector2(cx + 120, 720)])
	UI.poly(self, pts, Color(0.32, 0.3, 0.42))
	UI.poly(self, PackedVector2Array([Vector2(cx, top), Vector2(cx + 34, top + 40), Vector2(cx + 120, 720), Vector2(cx + 20, 720)]), Color(0.95, 0.75, 0.5, 0.35))
	for j in range(1, 14):
		var y := top + 40 + j * 44.0
		var w := 34.0 + (y - top - 40) / (720.0 - top - 40) * 86.0
		draw_line(Vector2(cx - w, y), Vector2(cx + w, y), Color(0.2, 0.18, 0.28), 2.0)
	# 頂上の玉座の小さな光（ポッツ）
	draw_circle(Vector2(cx, top - 6), 7 + sin(ft * 3.0) * 2.0, Color(0.5, 1.0, 0.95, 0.9))
	# 雲海
	for i in range(14):
		var x := fmod(i * 120.0 + ft * (10 + i % 3 * 4), 1480.0) - 100
		draw_circle(Vector2(x, 560 + (i % 3) * 26), 80, Color(1, 1, 1, 0.85))
	draw_rect(Rect2(0, 600, 1280, 120), Color(1, 1, 1, 0.9))
	# 暗転
	var fade := clampf((ft - 4.5) / 2.0, 0.0, 1.0)
	if ft < 1.0:
		fade = 1.0 - ft
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, fade))
