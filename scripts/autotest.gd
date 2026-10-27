# ヘッドレス自動テスト：各画面を順に生成し、戦闘をAI同士でしばらく回す
extends Node

var step := 0
var t := 0.0
var log_lines: Array = []


func _ready() -> void:
	print("[autotest] start")
	Game.new_game()
	for cid in ["angie", "sona", "jin", "john"]:
		Game.join(cid)
	preload("res://scripts/validate.gd").run()
	for cook in ["ren", "angie", "sona", "jin", "john"]:
		for rid in DB.Items.RECIPES:
			DB.Skits.cook_lines(cook, rid, DB.Items.RECIPES[rid]["best"] == cook)
	DB.Skits.rest_lines()
	DB.Skits.shop_greeting()
	DB.Skits.shop_comment()
	if "--validate-only" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	_run()


func _run() -> void:
	var main: Main = get_parent()
	for scr in ["title", "map", "camp", "shop", "event", "menu", "gameover", "ending"]:
		print("[autotest] screen ", scr)
		main.busy = false
		main.goto(scr, {})
		await get_tree().create_timer(1.2).timeout
	var floors: Array = [1, 2, 3, 4, 5, 6, 7]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floors="):
			floors = Array(a.substr(9).split(",")).map(func(x) -> int: return int(x))
	for f in floors:
		Game.floor_num = f
		Game.flags["red_cape"] = f == 7
		Game.flags["nine_absent"] = f == 7
		Game.gen_map()
		# 想定レベルに合わせる（バランス確認用）
		for m in Game.party:
			m["level"] = [2, 5, 7, 10, 12, 15, 17][f - 1]
		var fd: Dictionary = DB.floor_data(f)
		for grp in [fd["groups"][0], fd["elites"][0], fd["boss"]]:
			print("[autotest] battle floor ", f, " ", grp)
			main.busy = false
			Game.full_heal_party()
			main.goto("battle", {"enemies": grp, "kind": "boss" if grp == fd["boss"] else "battle"})
			await get_tree().create_timer(1.5).timeout
			var b: Node = main.screen
			# プレイヤーもAI化
			if b.get("player"):
				b.player.is_player = false
			var wait_t := 0.0
			while wait_t < (40.0 if grp == fd["boss"] else 20.0):
				await get_tree().create_timer(1.0).timeout
				wait_t += 1.0
				if not is_instance_valid(b) or b.get("ended"):
					break
			if b and is_instance_valid(b) and b.get("party"):
				var alive_e: int = b.enemies.filter(func(e) -> bool: return e.alive()).size()
				var alive_p: int = b.party.filter(func(p) -> bool: return p.alive()).size()
				var hp_sum := 0.0
				for p in b.party:
					hp_sum += p.hp_ratio() if p.alive() else 0.0
				print("[autotest]   t=", wait_t, " enemies alive=", alive_e, " party alive=", alive_p, " party hp=", snappedf(hp_sum / b.party.size(), 0.01), " combo max=", b.max_combo, " link=", int(b.link))
	print("[autotest] done")
	get_tree().quit()
