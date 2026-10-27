# 全滅画面
extends Control

var t := 0.0


func _ready() -> void:
	UI.full(self)
	var l = UI.outlined(UI.label("GAME OVER", 64, Color(0.9, 0.3, 0.3), true), 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 180)
	l.size = Vector2(1280, 90)
	add_child(l)
	var s = UI.label(_line(), 22, Color(0.9, 0.85, 0.85))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, 290)
	s.size = Vector2(1280, 40)
	add_child(s)
	var v = VBoxContainer.new()
	v.position = Vector2(490, 400)
	v.custom_minimum_size = Vector2(300, 0)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var retry = UI.button("この層の最初からやり直す", func() -> void:
		if Game.restore_floor_snapshot():
			Game.full_heal_party()
			Main.inst.goto("map", {})
		else:
			Main.inst.goto("title"), 22)
	retry.disabled = Game.floor_snapshot.is_empty()
	v.add_child(retry)
	v.add_child(UI.button("タイトルへ戻る", func() -> void: Main.inst.goto("title"), 22))
	UI.focus_first(v)


func _line() -> String:
	if Game.flags.get("nine_absent", false) and Game.floor_num == 1:
		return "「……隊長……」"
	return "ナイン「レン……起きて……レッドマンは、負けないんだよ……」"


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.02, 0.03))
	for i in range(40):
		var p = Vector2(fmod(i * 131.0, 1280.0), fmod(i * 71.0 + t * 30.0, 720.0))
		draw_circle(p, 2, Color(0.8, 0.3, 0.3, 0.2))
