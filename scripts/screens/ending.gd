# エンディング（スタッフロール）。物語はジンが記した『Tales of Babel』として締めくくられる。
extends Control

var t := 0.0
var roll: VBoxContainer
var speed := 38.0
var done := false


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
		if is_inside_tree():
			Main.inst.goto("title")
	queue_redraw()


func _draw() -> void:
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(0.25, 0.35, 0.65).lerp(Color(0.95, 0.8, 0.75), i / 23.0))
	for i in range(8):
		var cx = fmod(i * 210.0 + t * (8 + i), 1500.0) - 100
		draw_circle(Vector2(cx, 500 + (i % 3) * 60), 60, Color(1, 1, 1, 0.5))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.35))
