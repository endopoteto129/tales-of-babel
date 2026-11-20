# 探索マップの自動テストプレイ。各層を実際に歩き、到達性・戦闘数・所要時間を測る。
# mode=full: 宝箱・敵・施設をすべて回る / mode=rush: 中盤の地点とボスへまっすぐ向かう（ぶつかった敵とは戦う）
extends RefCounted

var tree: SceneTree
var s: Node


func run(host: Node, main: Main, floors: Array) -> void:
	tree = host.get_tree()
	Engine.time_scale = 4.0
	for mode in ["full", "rush"]:
		for f in floors:
			Game.debug_setup(f, false)
			for id in DB.Tutorials.ORDER:
				Game.flags["tut_" + id] = true
			Game.flags["floor_started_%d" % f] = true
			main.busy = false
			main.goto("map", {})
			await tree.create_timer(1.0).timeout
			s = main.screen
			while s.locked:
				await tree.process_frame
			s.bot_mode = true
			await _play(f, mode)
	print("[fieldbot] done")


func _play(f: int, mode: String) -> void:
	var t0 := Time.get_ticks_msec()
	var game_t := 0.0
	var stuck := 0
	var visited := 0
	var chests := 0
	var unreachable: Array = []
	var skip: Dictionary = {}
	var last_pos: Vector2 = s.ppos
	var still := 0.0
	var path: Array = []
	var repath := 0.0
	var goal: Dictionary = {}
	var was_open: bool = s.gate_open()
	while game_t < 900.0:
		if s.gate_open() != was_open:
			was_open = true
			skip.clear()
			unreachable.clear()
		var dt := tree.root.get_process_delta_time() if false else 1.0 / 60.0 * Engine.time_scale
		game_t += dt
		if s.bot_log.size() > 0 and s.bot_log[-1][0] == "boss":
			break
		repath -= dt
		if goal.is_empty() or repath <= 0.0 or _goal_done(goal):
			goal = _pick_goal(mode, skip)
			if goal.is_empty():
				break
			path = _path_to(goal)
			repath = 0.6
			if path.is_empty():
				skip[goal["id"]] = true
				unreachable.append("%s%s" % [goal["ch"], goal["id"]])
				goal = {}
				continue
		# 近くの物は調べる
		if not s.near.is_empty() and s.near["ch"] in "CMF?N" and not s.near["done"]:
			if s.near["ch"] == "C":
				chests += 1
			s.interact()
		# 経路をたどる
		while path.size() > 1 and s.ppos.distance_to(path[0]) < 14.0:
			path.pop_front()
		var tgt: Vector2 = path[0] if path.size() > 0 else goal["pos"]
		var v: Vector2 = tgt - s.ppos
		s.bot_input = v.normalized() if v.length() > 4.0 else Vector2.ZERO
		await tree.process_frame
		if s.ppos.distance_to(last_pos) < 1.0 and s.bot_input != Vector2.ZERO:
			still += dt
			if still > 2.0:
				stuck += 1
				print("[fieldbot]   STUCK F%d at tile %s heading %s" % [f, str(s.tile_at(s.ppos)), str(s.tile_at(tgt))])
				s.ppos = tgt
				still = 0.0
		else:
			still = 0.0
		last_pos = s.ppos
	var battles := 0
	var elites := 0
	for e in s.bot_log:
		if e[0] == "battle":
			battles += 1
			if e[2] == "L":
				elites += 1
	var reached_boss: bool = s.bot_log.size() > 0 and s.bot_log[-1][0] == "boss"
	print("[fieldbot] F%d %-4s boss=%s walk=%.0fs battles=%d(elite %d) chests=%d stuck=%d unreachable=%s" % [
		f, mode, "OK" if reached_boss else "NG", game_t, battles, elites, chests, stuck, str(unreachable)])
	s.bot_mode = false


func _goal_done(g: Dictionary) -> bool:
	if g.get("kind", "") == "tile":
		return s.tile_at(s.ppos) == g["tile"] or s.gate_open()
	return g.get("done", false) or not g in s.objs


func _pick_goal(mode: String, skip: Dictionary) -> Dictionary:
	# 中盤ストーリーがまだなら、そこを優先（rush）／最後に（full）
	var cands: Array = []
	if mode == "full":
		for o in s.objs:
			if o["done"] or skip.has(o["id"]) or o["ch"] == "B":
				continue
			cands.append(o)
	if cands.is_empty() and not s.gate_open():
		for y in range(s.H):
			var x: int = s.rows[y].find("G")
			if x >= 0:
				var g := {"kind": "tile", "id": "G", "ch": "G", "tile": Vector2i(x, y), "pos": s._tile_center(x, y)}
				if not skip.has("G"):
					return g
	if cands.is_empty():
		return s.boss_obj
	# 歩いて一番近いもの
	var dist: Dictionary = _bfs(s.tile_at(s.ppos))
	var best: Dictionary = {}
	var bd := 1e9
	for o in cands:
		var d := _obj_dist(o, dist)
		if d < bd:
			bd = d
			best = o
	if best.is_empty():
		for o in cands:
			skip[o["id"]] = true
		return _pick_goal(mode, skip)
	return best


func _obj_dist(o: Dictionary, dist: Dictionary) -> float:
	var tp: Vector2i = s.tile_at(o["pos"])
	var best := 1e9
	for d in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if dist.has(tp + d):
			best = min(best, float(dist[tp + d]))
	return best


func _passable(x: int, y: int) -> bool:
	return not s.solid(x, y)


func _bfs(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var q: Array = [start]
	var i := 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if dist.has(n) or not _passable(n.x, n.y):
				continue
			dist[n] = dist[c] + 1
			q.append(n)
	return dist


func _path_to(g: Dictionary) -> Array:
	var start: Vector2i = s.tile_at(s.ppos)
	var goal_t: Vector2i = s.tile_at(g["pos"]) if g.get("kind", "") != "tile" else g["tile"]
	var prev := {start: start}
	var q: Array = [start]
	var i := 0
	var found := Vector2i(-1, -1)
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		if c == goal_t or (c - goal_t).length_squared() == 1 and not _passable(goal_t.x, goal_t.y):
			found = c
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or not _passable(n.x, n.y):
				continue
			prev[n] = c
			q.append(n)
	if found.x < 0:
		return []
	var out: Array = []
	var c2: Vector2i = found
	while c2 != start:
		out.push_front(s._tile_center(c2.x, c2.y) + Vector2(0, 8))
		c2 = prev[c2]
	out.append(g["pos"] if g.get("kind", "") != "tile" else s._tile_center(goal_t.x, goal_t.y))
	return out
