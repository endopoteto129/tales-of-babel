# タッチ操作テスト：画面タッチだけでマップを歩き、行商人を調べ、戦闘で攻撃できるか確かめる
extends Node

var main: Main
var shots := false


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	Input.parse_input_event(e)


func _tap(pos: Vector2) -> void:
	_touch(0, pos, true)
	await get_tree().create_timer(0.1).timeout
	_touch(0, pos, false)
	await get_tree().create_timer(0.2).timeout


func _shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("../shots/%s.png" % name))


func _btn_pos(action: String) -> Vector2:
	var tc: TouchControls = null
	for c in main.get_children():
		if c is TouchControls:
			tc = c
	for b in tc.buttons:
		if b["action"] == action:
			return b["pos"]
	return Vector2(-1, -1)


func _ready() -> void:
	main = get_parent()
	shots = DisplayServer.get_name() != "headless"
	await get_tree().create_timer(0.5).timeout
	Game.debug_setup(2, false)
	Game.flags["floor_started_2"] = true
	for k in DB.Tutorials.ORDER:
		Game.flags["tut_" + k] = true
	main.busy = false
	main.goto("map", {})
	await get_tree().create_timer(1.5).timeout
	# 最初のタッチでタッチモードになる
	await _tap(Vector2(640, 300))
	print("[touch] touch_mode=", Game.touch_mode)
	await get_tree().create_timer(0.3).timeout
	await _shot("touch_map")
	var s = main.screen
	var p0: Vector2 = s.ppos
	_touch(1, Vector2(200, 500), true)
	for i in range(10):
		_drag(1, Vector2(200 + i * 10, 500))
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_touch(1, Vector2(290, 500), false)
	print("[touch] stick moved right: ", s.ppos.x - p0.x > 20, " dx=", int(s.ppos.x - p0.x))
	# 行商人の前で「調べる」
	var m: Dictionary = {}
	for o in s.objs:
		if o["ch"] == "M":
			m = o
	s.ppos = m["pos"] + Vector2(0, 60)
	s.pdir = 3
	await get_tree().create_timer(0.4).timeout
	await _tap(_btn_pos("ui_accept"))
	await get_tree().create_timer(1.2).timeout
	print("[touch] after 調べる screen=", main.screen_name)
	await _shot("touch_shop")
	main.goto("map", {})
	await get_tree().create_timer(1.2).timeout
	main.goto("battle", {"enemies": ["slime", "wolf"], "kind": "battle"})
	await get_tree().create_timer(3.5).timeout
	print("[touch] battle mode buttons=", _btn_pos("attack") != Vector2(-1, -1))
	var b = main.screen
	var before := 0
	for e in b.enemies if "enemies" in b else []:
		before += e.hp
	for i in range(6):
		await _tap(_btn_pos("attack"))
	await _shot("touch_battle")
	print("[touch] player state after attacks: ", b.player.state if "player" in b else "?")
	await _tap(_btn_pos("pause"))
	await get_tree().create_timer(0.5).timeout
	print("[touch] paused=", b.paused or get_tree().paused)
	print("[touch] done")
	get_tree().quit()
