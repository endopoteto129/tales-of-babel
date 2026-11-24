# UI操作テスト：ゲームパッドの入力だけで行商人の店を開き、カーソル移動と購入ができるか確かめる
extends Node

var main: Main


func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	e.device = 0
	Input.parse_input_event(e)
	await get_tree().create_timer(0.08).timeout
	var r := InputEventJoypadButton.new()
	r.button_index = button
	r.pressed = false
	r.device = 0
	Input.parse_input_event(r)
	await get_tree().create_timer(0.15).timeout


func _focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return "<none>"
	if f is Button:
		return "Button(" + f.text.split("\n")[0] + ")"
	return f.get_class()


func _ready() -> void:
	main = get_parent()
	await get_tree().create_timer(0.5).timeout
	Game.debug_setup(2, false)
	Game.flags["floor_started_2"] = true
	for k in DB.Tutorials.ORDER:
		Game.flags["tut_" + k] = true
	main.busy = false
	main.goto("map", {})
	await get_tree().create_timer(1.5).timeout
	var s = main.screen
	var m: Dictionary = {}
	for o in s.objs:
		if o["ch"] == "M":
			m = o
			break
	s.ppos = m["pos"] + Vector2(0, 60)
	s.pdir = 3
	await get_tree().create_timer(0.4).timeout
	print("[uitest] near=", s.near.get("ch", ""))
	await _pad(JOY_BUTTON_A)
	await get_tree().create_timer(1.5).timeout
	print("[uitest] screen=", main.screen_name, " focus=", _focus())
	for i in range(3):
		await _pad(JOY_BUTTON_DPAD_DOWN)
		print("[uitest] down -> ", _focus())
	var g0 := Game.gald
	Game.gald = 5000
	g0 = Game.gald
	await _pad(JOY_BUTTON_A)
	await get_tree().create_timer(0.3).timeout
	print("[uitest] bought=", Game.gald < g0, " focus after buy=", _focus())
	await _pad(JOY_BUTTON_DPAD_DOWN)
	print("[uitest] down after buy -> ", _focus())
	await _pad(JOY_BUTTON_B)
	await get_tree().create_timer(1.0).timeout
	print("[uitest] after B screen=", main.screen_name)
	print("[uitest] done")
	get_tree().quit()
