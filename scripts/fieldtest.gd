# 探索マップの確認用。--fieldtest --shots: 各層の画面写真 / --fieldtest --play: 自動テストプレイ
extends Node

var main: Main


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join("../shots"))
	var args := OS.get_cmdline_user_args()
	var floors: Array = [1, 2, 3, 4, 5, 6, 7]
	for a in args:
		if a.begins_with("--floors="):
			floors = Array(a.substr(9).split(",")).map(func(x) -> int: return int(x))
	if "--flow" in args:
		await _flow()
	elif "--play" in args:
		await load("res://scripts/fieldbot.gd").new().run(self, main, floors)
	else:
		await _shots(floors)
	get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("../shots/%s.png" % name))
	print("[shot] ", name)


func _seen_all_tutorials() -> void:
	for id in DB.Tutorials.ORDER:
		Game.flags["tut_" + id] = true


func _shots(floors: Array) -> void:
	for f in floors:
		Game.debug_setup(f, false)
		_seen_all_tutorials()
		Game.flags["floor_started_%d" % f] = true
		main.busy = false
		main.goto("map", {})
		await get_tree().create_timer(1.2).timeout
		await shot("f%d_a_start" % f)
		var s: Node = main.screen
		# 中盤（ストーリー地点）とボスの手前を撮る
		for o in s.objs:
			if o["ch"] == "B":
				s.ppos = o["pos"] + Vector2(0, 64 * 3)
		s.locked = true
		s._update_cam(true)
		await get_tree().create_timer(0.4).timeout
		await shot("f%d_c_boss" % f)
		for y in range(s.H):
			var x: int = s.rows[y].find("G")
			if x >= 0:
				s.ppos = s._tile_center(x, y) + Vector2(0, 80)
				break
		s._update_cam(true)
		await get_tree().create_timer(0.4).timeout
		await shot("f%d_b_mid" % f)


# 実際の画面遷移を通して確認：遭遇→戦闘→勝利→地図へ戻る／逃走／宝箱／焚火
func _flow() -> void:
	Engine.time_scale = 3.0
	Game.debug_setup(1, false)
	_seen_all_tutorials()
	Game.flags["floor_started_1"] = true
	main.busy = false
	main.goto("map", {})
	await get_tree().create_timer(1.0).timeout
	var s: Node = main.screen
	while s.locked:
		await get_tree().process_frame
	var e: Dictionary = {}
	for o in s.objs:
		if o["ch"] == "E":
			e = o
			break
	print("[flow] enemy ", e["id"], " group ", e["props"]["g"])
	s.ppos = e["pos"] + Vector2(0, 40)
	await get_tree().create_timer(1.5).timeout
	var b: Node = main.screen
	print("[flow] screen after contact: ", main.screen_name)
	b.player.is_player = false
	await get_tree().create_timer(2.5).timeout
	await shot("flow_battle")
	var t := 0.0
	while not b.ended and t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	await get_tree().create_timer(2.0).timeout
	b.finish_victory()
	await get_tree().create_timer(1.5).timeout
	s = main.screen
	while s.locked:
		await get_tree().process_frame
	print("[flow] back on ", main.screen_name, " done=", Game.map["done"].has(e["id"]), " engage='", Game.map["engage"], "' enemies left=", s.objs.filter(func(o) -> bool: return o["ch"] in "EL").size(), " lv=", Game.party[0]["level"])
	await shot("flow_after_battle")
	# 逃走
	for o in s.objs:
		if o["ch"] == "E":
			e = o
			break
	s.ppos = e["pos"] + Vector2(0, 40)
	var wait_t := 0.0
	while main.screen_name != "battle" and wait_t < 8.0:
		if is_instance_valid(s) and main.screen == s and not s.locked:
			s.ppos = e["pos"] + Vector2(0, 40)
		await get_tree().process_frame
		wait_t += get_process_delta_time()
	await get_tree().create_timer(2.0).timeout
	b = main.screen
	b.escape()
	await get_tree().create_timer(1.5).timeout
	s = main.screen
	while s.locked:
		await get_tree().process_frame
	var still: bool = s.objs.any(func(o) -> bool: return o["id"] == e["id"])
	print("[flow] after escape: enemy still there=", still, " stun=", s.objs.filter(func(o) -> bool: return o["id"] == e["id"])[0]["stun"] if still else -1)
	# 宝箱
	for o in s.objs:
		if o["ch"] == "C":
			s.ppos = o["pos"] + Vector2(0, 56)
			s.pdir = 3
			break
	await get_tree().create_timer(0.3).timeout
	print("[flow] near=", s.near.get("ch", ""), " gald/items before ", Game.gald, " ", Game.items)
	s.interact()
	print("[flow] after chest ", Game.gald, " ", Game.items)
	await shot("flow_chest")
	# 焚火
	for o in s.objs:
		if o["ch"] == "F":
			s.ppos = o["pos"] + Vector2(0, 56)
			s.pdir = 3
	await get_tree().create_timer(0.3).timeout
	s.interact()
	await get_tree().create_timer(1.5).timeout
	print("[flow] camp screen: ", main.screen_name)
	main.busy = false
	main.goto("map", {"after": "camp"})
	await get_tree().create_timer(1.5).timeout
	s = main.screen
	print("[flow] back: ", main.screen_name, " camp used=", s.objs.filter(func(o) -> bool: return o["ch"] == "F")[0]["done"], " pos=", s.ppos)
	await shot("flow_back_from_camp")
	# セーブとロード
	Game.save_game()
	var before: Dictionary = Game.map.duplicate(true)
	Game.load_game()
	print("[flow] save/load keeps map: ", Game.map["done"].size() == before["done"].size(), " pos ", Game.map["pos"])
