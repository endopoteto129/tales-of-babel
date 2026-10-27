# スクリーンショット撮影用（xvfb で実行）
extends Node

var out_dir := "res://../shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join("../shots"))
	Game.new_game()
	for cid in ["angie", "sona", "jin"]:
		Game.join(cid)
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("../shots/%s.png" % name))
	print("[shot] ", name)


func _run() -> void:
	var main: Main = get_parent()
	main.busy = false
	main.goto("title")
	await get_tree().create_timer(1.0).timeout
	await shot("01_title")
	main.screen._show_debug()
	await get_tree().create_timer(0.5).timeout
	await shot("13_debug")
	main.screen.help.queue_free()
	main.busy = false
	Game.flags["floor_started_1"] = true
	main.goto("map", {})
	await get_tree().create_timer(1.0).timeout
	await shot("02_map")
	main.busy = false
	main.goto("battle", {"enemies": ["slime", "wolf", "bat"], "kind": "battle"})
	await get_tree().create_timer(3.5).timeout
	await shot("03_battle")
	main.screen.player.is_player = false
	await get_tree().create_timer(2.5).timeout
	await shot("04_battle2")
	main.screen.link = 100
	main.screen.try_link()
	await get_tree().create_timer(1.6).timeout
	await shot("05_link")
	main.busy = false
	Game.floor_num = 4
	main.goto("battle", {"enemies": ["boss_nene"], "kind": "boss"})
	await get_tree().create_timer(4.0).timeout
	await shot("06_boss")
	main.busy = false
	for fl in DB.Story.FLOORS:
		Game.flags["story_" + DB.Story.FLOORS[fl]["camp"]] = true
	main.goto("camp", {})
	await get_tree().create_timer(1.5).timeout
	await shot("07_camp")
	main.busy = false
	main.goto("menu", {})
	await get_tree().create_timer(1.0).timeout
	main.screen.tab = 2
	main.screen._rebuild()
	await get_tree().create_timer(0.5).timeout
	await shot("08_tree")
	var sk: Dictionary = DB.Skits.DATA["s_jin_honest"].duplicate()
	sk["mode"] = "skit"
	var dlg = main.play_dialogue(sk)
	await get_tree().create_timer(3.5).timeout
	await shot("09_skit")
	dlg.queue_free()
	main.busy = false
	main.goto("shop", {})
	await get_tree().create_timer(2.0).timeout
	await shot("10_shop")
	main.busy = false
	main.goto("event", {})
	await get_tree().create_timer(1.5).timeout
	await shot("11_event")
	main.busy = false
	Game.floor_num = 7
	Game.join("john")
	Game.flags["red_cape"] = true
	Game.flags["nine_absent"] = true
	main.goto("battle", {"enemies": ["soldier", "gunner"], "kind": "battle"})
	await get_tree().create_timer(2.0).timeout
	main.screen.link = 100
	main.screen.try_link()
	await get_tree().create_timer(2.2).timeout
	await shot("12_zettai")
	await get_tree().create_timer(3.0).timeout
	# オーバーリミッツと3人の合体秘奥義
	var b = main.screen
	b.ovl = 100.0
	Game.flags["mystic_gauge"] = 300.0
	b.start_ovl()
	await get_tree().create_timer(0.8).timeout
	await shot("14_ovl")
	b.fire_mystic()
	await get_tree().create_timer(1.2).timeout
	await shot("15_mystic_cutin")
	await get_tree().create_timer(1.8).timeout
	await shot("16_mystic_name")
	await get_tree().create_timer(1.6).timeout
	await shot("17_mystic_hit")
	# マップのスキット呼び出し
	main.busy = false
	Game.floor_num = 1
	Game.flags["floor_started_1"] = true
	Game.flags["red_cape"] = false
	Game.flags["nine_absent"] = false
	Game.gen_map()
	Game.pending_skits = ["s_first_step"]
	main.goto("map", {})
	await get_tree().create_timer(1.2).timeout
	await shot("18_map_skit")
	# ラスボスのとどめ演出
	main.busy = false
	Game.floor_num = 7
	Game.flags["red_cape"] = true
	Game.flags["nine_absent"] = true
	main.goto("battle", {"enemies": ["boss_shasta"], "kind": "boss"})
	await get_tree().create_timer(4.0).timeout
	var bt = main.screen
	var boss: Fighter = bt.enemies[0]
	boss.hp = 5.0
	boss.take_hit(100, 10, 0, 1, 1.0, false)
	await get_tree().create_timer(1.5).timeout
	await shot("19_finish_prompt")
	bt.fire_finisher()
	await get_tree().create_timer(2.8).timeout
	await shot("20_finish_cutin")
	await get_tree().create_timer(0.95).timeout
	await shot("21_finish_shout")
	await get_tree().create_timer(2.6).timeout
	await shot("22_finish_name")
	await get_tree().create_timer(2.0).timeout
	await shot("23_finish_end")
	# エンドロール後の場面
	main.busy = false
	var d2 = DB.Story.AFTER_CREDITS.duplicate()
	d2["mode"] = "story"
	main.play_dialogue(d2)
	await get_tree().create_timer(3.0).timeout
	await shot("24_after_credits")
	get_tree().quit()
