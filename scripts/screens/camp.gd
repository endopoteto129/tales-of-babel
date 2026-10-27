# 焚火（キャンプ）。休む／料理する／語らう から一つを選ぶ。
extends Control

var t := 0.0
var menu: VBoxContainer
var sparks: Array = []
var locked := false


func _ready() -> void:
	UI.full(self)
	var head = UI.outlined(UI.label("焚火", 36, Color(1.0, 0.75, 0.45), true), 6)
	head.position = Vector2(40, 30)
	add_child(head)
	var sub = UI.label("揺れる炎を囲んで、ひと休み。", 18, UI.C_DIM)
	sub.position = Vector2(42, 84)
	add_child(sub)
	menu = VBoxContainer.new()
	menu.position = Vector2(860, 300)
	menu.custom_minimum_size = Vector2(360, 0)
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	# 層ごとの「キャンプ記録」（ストーリー）を最初に再生
	var fs: Dictionary = DB.Story.FLOORS.get(Game.floor_num, {})
	if fs.has("camp") and not Game.flags.get("story_" + fs["camp"], false):
		locked = true
		Main.inst.play_story(fs["camp"], func() -> void:
			locked = false
			_build_menu())
	else:
		_build_menu()


func _build_menu() -> void:
	for c in menu.get_children():
		c.queue_free()
	menu.add_child(UI.label("どうする？（ひとつだけ選べる）", 20, UI.C_TEXT, true))
	menu.add_child(UI.button("休む　―　HPとTPが全回復", _rest, 20))
	menu.add_child(UI.button("料理する　―　HP30%回復＋3戦の間効果", _cook_menu, 20))
	var talk = UI.button("語らう　―　HP30%回復＋仲間との会話", _talk, 20)
	talk.disabled = _pick_talk() == ""
	if talk.disabled:
		talk.text = "語らう　―　（今は話すことがない）"
	menu.add_child(talk)
	UI.focus_first(menu)


func _process(delta: float) -> void:
	t += delta
	if randf() < delta * 30.0:
		sparks.append([Vector2(440 + randf_range(-30, 30), 470), Vector2(randf_range(-20, 20), randf_range(-90, -40)), 0.0, randf_range(0.8, 1.6)])
	for s in sparks:
		s[0] += s[1] * delta
		s[2] += delta
	sparks = sparks.filter(func(s) -> bool: return s[2] < s[3])
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.06))
	for i in range(60):
		var p = Vector2(fmod(i * 211.0, 1280.0), fmod(i * 97.0, 300.0))
		draw_circle(p, 1.2, Color(1, 1, 0.9, 0.3 + 0.3 * sin(t + i)))
	var glow = 0.9 + sin(t * 9.0) * 0.06 + sin(t * 23.0) * 0.04
	for i in range(10):
		draw_circle(Vector2(440, 470), (380 - i * 34) * glow, Color(1.0, 0.45, 0.12, 0.05))
	draw_rect(Rect2(0, 520, 1280, 200), Color(0.08, 0.06, 0.05))
	# 薪
	draw_line(Vector2(390, 505), Vector2(490, 480), Color(0.35, 0.22, 0.12), 14)
	draw_line(Vector2(390, 480), Vector2(490, 505), Color(0.3, 0.2, 0.1), 14)
	# 炎
	for k in range(3):
		var s = 1.0 - k * 0.28
		var col = [Color(1.0, 0.35, 0.1), Color(1.0, 0.65, 0.15), Color(1.0, 0.95, 0.6)][k]
		var pts = PackedVector2Array()
		for i in range(17):
			var a = PI + PI * i / 16.0
			var r = 50.0 * s
			var flick = sin(t * 12.0 + i * 1.7) * 6.0 * s
			var up: float = (1.0 - abs(i - 8) / 8.0) * 90.0 * s * glow
			pts.append(Vector2(440 + cos(a) * r, 490 + sin(a) * (r * 0.5 + up) + flick))
		UI.poly(self, pts, col)
	for s2 in sparks:
		var a2: float = 1.0 - s2[2] / s2[3]
		draw_circle(s2[0], 2.0, Color(1.0, 0.7, 0.3, a2))
	# 焚火を囲む仲間（シルエット）
	var members: Array = Game.present_party().map(func(m) -> String: return m["id"])
	if not Game.flags.get("nine_absent", false):
		members.append("nine")
	var n = members.size()
	var left_n = int(ceil(n / 2.0))
	for i in range(n):
		var p2 = Vector2.ZERO
		if i < left_n:
			p2 = Vector2(170 + 190.0 * i / max(1, left_n - 1) if left_n > 1 else 270, 510 - (i % 2) * 14)
		else:
			var j = i - left_n
			var rn = n - left_n
			p2 = Vector2(530 + 180.0 * j / max(1, rn - 1) if rn > 1 else 600, 510 - (j % 2) * 14)
		var c: Color = DB.ccolor(members[i]).darkened(0.35)
		var lit = Color(1.0, 0.6, 0.3, 0.35)
		var hgt = 60.0 if members[i] != "nine" else 44.0
		draw_rect(Rect2(p2 + Vector2(-16, -hgt), Vector2(32, hgt)), c)
		draw_circle(p2 + Vector2(0, -hgt - 14), 15, c.lightened(0.1))
		draw_rect(Rect2(p2 + Vector2(-16, -hgt), Vector2(6, hgt)), lit)
		draw_string(UI.FONT, p2 + Vector2(-30, 26), DB.cname(members[i]), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(1, 0.85, 0.7, 0.8))
	if not Game.flags.get("pots_absent", false):
		var pp = Vector2(440, 330 + sin(t * 2.0) * 6)
		draw_circle(pp, 12, Color(0.5, 0.7, 0.8))
		draw_rect(Rect2(pp + Vector2(-8, -3), Vector2(16, 6)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(pp + Vector2(-6, -1), Vector2(4, 3)), Color(0.3, 1.0, 0.9))
		draw_rect(Rect2(pp + Vector2(2, -1), Vector2(4, 3)), Color(0.3, 1.0, 0.9))


func _heal(ratio: float, tp: bool) -> void:
	for m in Game.party:
		m["hp"] = min(Game.max_hp(m["id"]), m["hp"] + int(Game.max_hp(m["id"]) * ratio))
		if tp:
			m["tp"] = min(Game.max_tp(m["id"]), m["tp"] + int(Game.max_tp(m["id"]) * ratio))


func _rest() -> void:
	if locked:
		return
	locked = true
	Game.full_heal_party()
	Sfx.play("heal")
	Main.inst.toast("ぐっすり眠った。HPとTPが全回復！", "info")
	_finish_with_line()


func _cook_menu() -> void:
	if locked:
		return
	for c in menu.get_children():
		c.queue_free()
	menu.add_child(UI.label("何を作る？", 20, UI.C_TEXT, true))
	for rid in Game.known_recipes:
		var r: Dictionary = DB.Items.RECIPES[rid]
		var id: String = rid
		menu.add_child(UI.button("%s　―　%s" % [r["name"], r["desc"]], func() -> void: _cook(id), 17))
	menu.add_child(UI.button("戻る", _build_menu, 18))
	UI.focus_first(menu)


func _cook(rid: String) -> void:
	locked = true
	var r: Dictionary = DB.Items.RECIPES[rid]
	# 料理担当はランダム。得意なキャラが作ると4戦持つ。
	var cooks: Array = Game.present_party().map(func(m) -> String: return m["id"])
	var cook: String = cooks[Game.rng.randi() % cooks.size()]
	var best: bool = r["best"] == cook
	Game.meal = {"id": rid, "left": 4 if best else 3}
	_heal(0.3, true)
	Game.count("cooked_" + cook)
	var lines: Array = DB.Skits.cook_lines(cook, rid, best)
	Main.inst.play_dialogue({"title": "料理：" + r["name"], "mode": "camp", "bg": "camp", "lines": lines}, func() -> void:
		if cook == "john" and Game.counters.get("cooked_john", 0) >= 2:
			Game.award_title("john_bigbro", "")
		Main.inst.goto("map", {"after": "camp"}))


func _pick_talk() -> String:
	for id in DB.Skits.CAMP_ORDER:
		if Game.seen_skits.has(id):
			continue
		var s: Dictionary = DB.Skits.CAMP[id]
		if s.get("min_floor", 1) > Game.floor_num or s.get("max_floor", 99) < Game.floor_num:
			continue
		var blocked = false
		for f in s.get("not_flags", []):
			if Game.flags.get(f, false):
				blocked = true
		if blocked:
			continue
		var ok = true
		for r in s.get("req", []):
			if not Game.is_joined(r):
				ok = false
		for f in s.get("flags", []):
			if not Game.flags.get(f, false):
				ok = false
		if ok and Game.lines_available(s["lines"]):
			return id
	return ""


func _talk() -> void:
	if locked:
		return
	var id = _pick_talk()
	if id == "":
		return
	locked = true
	_heal(0.3, true)
	var s: Dictionary = DB.Skits.CAMP[id].duplicate()
	s["mode"] = "camp"
	s["bg"] = "camp"
	Main.inst.play_dialogue(s, func() -> void:
		Game.seen_skits[id] = true
		var speakers: Array = []
		for line in s["lines"]:
			if DB.Characters.DATA.has(line[0]) and not line[0] in speakers:
				speakers.append(line[0])
		for i in range(speakers.size()):
			for j in range(i + 1, speakers.size()):
				Game.add_bond(speakers[i], speakers[j], 2)
		if Game.count("camp_talks") >= 5:
			Game.award_title("campfire5", "")
		Main.inst.goto("map", {"after": "camp"}))


func _finish_with_line() -> void:
	var lines: Array = DB.Skits.rest_lines()
	Main.inst.play_dialogue({"title": "休息", "mode": "camp", "bg": "camp", "lines": lines}, func() -> void:
		Main.inst.goto("map", {"after": "camp"}))
