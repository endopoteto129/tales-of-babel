# 再現テスト：イベント「花畑」で決定キーを連打し、会話が終わってマップに戻るか確認する
extends Node


func _press(action: String) -> void:
	var e = InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r = InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _ready() -> void:
	var main: Main = get_parent()
	await get_tree().create_timer(0.5).timeout
	Game.debug_setup(1, false)
	Game.flags["floor_started_1"] = true
	main.busy = false
	main.goto("event", {"id": "e_flower_field"})
	await get_tree().create_timer(1.0).timeout
	var max_dlg := 0
	for i in range(80):
		await _press("ui_accept")
		await get_tree().create_timer(0.2).timeout
		var n = main.overlay.get_children().filter(func(c) -> bool: return c.has_method("setup")).size()
		max_dlg = max(max_dlg, n)
	print("[repro] screen=", main.screen_name, " max_dialogues_at_once=", max_dlg)
	get_tree().quit()
