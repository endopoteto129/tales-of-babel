# バランス確認：各層をデバッグジャンプと同じ想定状態にして、雑魚・強敵・ボスをAI同士で戦わせる
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	var main: Main = get_parent()
	Engine.time_scale = 4.0
	var floors: Array = [1, 2, 3, 4, 5, 6, 7]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--floors="):
			floors = Array(a.substr(9).split(",")).map(func(x) -> int: return int(x))
	for f in floors:
		var fd: Dictionary = DB.floor_data(f)
		var fights: Array = []
		for g in fd["groups"]:
			fights.append([g, "battle", false])
		fights.append([fd["elites"][0], "elite", false])
		fights.append([fd["boss"], "boss", true])
		for fi in fights:
			Game.debug_setup(f, fi[2])
			if not fi[2]:
				Game._debug_apply_story(DB.Story.FLOORS[f]["intro"])
				for m in Game.party:
					m["level"] = Game.EXPECTED_LV_START[f - 1]
				Game.full_heal_party()
				for b in Game.random_buffs(1):
					Game.add_floor_buff(b)
			main.busy = false
			main.goto("battle", {"enemies": fi[0], "kind": fi[1]})
			await get_tree().create_timer(1.0).timeout
			var b: Node = main.screen
			if b.get("player"):
				b.player.is_player = false
			var t := 0.0
			var limit = 180.0 if fi[1] == "boss" else 60.0
			while t < limit:
				await get_tree().create_timer(1.0).timeout
				t += 1.0
				if not is_instance_valid(b) or b.get("ended"):
					break
			if is_instance_valid(b) and b.get("party"):
				var alive_e: int = b.enemies.filter(func(e) -> bool: return e.alive()).size()
				var alive_p: int = b.party.filter(func(p) -> bool: return p.alive()).size()
				var hp_sum := 0.0
				for p in b.party:
					hp_sum += p.hp_ratio() if p.alive() else 0.0
				var res = "WIN" if alive_e == 0 else ("LOSE" if alive_p == 0 else "TIMEOUT")
				print("[balance] F%d %-6s %-40s %s t=%d party=%d/%d hp=%.2f lv=%d" % [f, fi[1], str(fi[0]), res, t, alive_p, b.party.size(), hp_sum / b.party.size(), Game.party[0]["level"]])
	print("[balance] done")
	get_tree().quit()
