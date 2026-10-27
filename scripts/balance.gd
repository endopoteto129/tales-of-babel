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
	if "--mystic" in OS.get_cmdline_user_args():
		await _mystic_test(main, floors)
		get_tree().quit()
		return
	for f in floors:
		var fd: Dictionary = DB.floor_data(f)
		var fights: Array = []
		for g in fd["groups"]:
			fights.append([g, "battle", false])
		fights.append([fd["elites"][0], "elite", false])
		fights.append([fd["boss"], "boss", true])
		if "--boss-only" in OS.get_cmdline_user_args():
			fights = [fights[-1]]
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
				if alive_e > 0:
					res += "(敵HP%.0f%%)" % (b.enemies.filter(func(e) -> bool: return e.alive())[0].hp_ratio() * 100.0)
				print("[balance] F%d %-6s %-40s %s t=%d party=%d/%d hp=%.2f lv=%d" % [f, fi[1], str(fi[0]), res, t, alive_p, b.party.size(), hp_sum / b.party.size(), Game.party[0]["level"]])
	print("[balance] done")
	get_tree().quit()


# 各層のボスに秘奥義（単独・2人・3人）を撃ち、削れたHPの割合を表示する
func _mystic_test(main: Main, floors: Array) -> void:
	for f in floors:
		for level in [1, 2, 3]:
			Game.debug_setup(f, true)
			main.busy = false
			main.goto("battle", {"enemies": [DB.floor_data(f)["boss"][0]], "kind": "boss"})
			await get_tree().create_timer(1.5).timeout
			var b: Node = main.screen
			var boss: Fighter = b.enemies[0]
			for p in b.party:
				if p == b.player:
					continue
				p.atk *= 0.0001  # 仲間の通常攻撃を除外して秘奥義の分だけ測る
				p.matk *= 0.0001
			var before: float = boss.hp
			Game.flags["mystic_gauge"] = level * 100.0
			b.ovl = 100.0
			b.start_ovl()
			b.fire_mystic()
			await get_tree().create_timer(12.0).timeout
			print("[mystic] F%d level=%d boss=%s dealt=%.1f%% of max hp" % [f, level, boss.cid, (before - boss.hp) / boss.max_hp * 100.0])
