# 第五層ボス戦の途中で起きるOVL解放イベントの確認（画面ありで実行）
# 1) 第二層の戦闘では絆・OVLゲージが出ない　2) 第五層ボスのHPを減らすと会話が流れ、OVLが解放されて発動する
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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := "user://ovltest"
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")
	print("[ovltest] shot ", ProjectSettings.globalize_path(dir + "/" + name + ".png"))


func _ready() -> void:
	var main: Main = get_parent()
	await get_tree().create_timer(0.5).timeout
	# 1) 解放前
	Game.debug_setup(2, false)
	Game.flags["tut_battle"] = true
	Game.flags["tut_depth_attack"] = true
	main.busy = false
	main.goto("battle", {"enemies": DB.floor_data(2)["groups"][0], "kind": "battle"})
	await get_tree().create_timer(2.5).timeout
	var b: Node = main.screen
	print("[ovltest] f2 link_unlocked=", b.link_unlocked(), " ovl_unlocked=", b.ovl_unlocked())
	await _shot("1_f2_locked")
	# 2) 第五層ボス
	Game.debug_setup(5, true)
	for k in ["battle", "depth_attack", "boss_jump", "boss_guard", "break", "link"]:
		Game.flags["tut_" + k] = true
	print("[ovltest] f5 before: link=", Game.flags.get("link_unlocked", false), " ovl=", Game.flags.get("ovl_unlocked", false))
	main.busy = false
	main.goto("battle", {"enemies": DB.floor_data(5)["boss"], "kind": "boss"})
	await get_tree().create_timer(2.5).timeout
	b = main.screen
	for e in b.enemies:
		if e.data.get("boss", false):
			e.hp = e.max_hp * 0.55
	await get_tree().create_timer(1.0).timeout
	var dlg: Array = main.overlay.get_children().filter(func(c) -> bool: return c.has_method("setup"))
	print("[ovltest] event dialogue shown=", not dlg.is_empty(), " paused=", b.paused)
	await _shot("2_event")
	for i in range(60):
		await _press("ui_accept")
		await get_tree().create_timer(0.15).timeout
		if main.overlay.get_children().filter(func(c) -> bool: return c.has_method("setup")).is_empty() and not b.paused:
			break
		if i == 25:
			await _shot("3_event_mid")
	await get_tree().create_timer(0.8).timeout
	await _shot("4_tutorial")
	for i in range(10):
		await _press("ui_accept")
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.0).timeout
	print("[ovltest] after: ovl_unlocked=", b.ovl_unlocked(), " ovl_t=%.1f" % b.ovl_t, " paused=", b.paused)
	await _shot("5_ovl_active")
	# 長い台詞が会話ウィンドウに収まるか（第三層ボス後のアンジー）
	main.busy = false
	main.goto("title")
	await get_tree().create_timer(1.0).timeout
	var lines: Array = DB.Story.DATA["f3_boss_post"]["lines"]
	var longest: Array = lines[0]
	for ln in lines:
		if str(ln[0]) == "angie" and str(ln[1]).length() > str(longest[1]).length():
			longest = ln
	main.play_dialogue({"mode": "story", "bg": "camp", "lines": [longest]})
	await get_tree().create_timer(3.0).timeout
	await _shot("6_long_line")
	print("[ovltest] done")
	get_tree().quit()
