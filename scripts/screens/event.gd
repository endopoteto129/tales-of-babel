# イベントマス。選択肢によって結果が変わる。
extends Control

var ev_id := ""
var ev: Dictionary
var box: VBoxContainer
var t := 0.0


func setup(params: Dictionary) -> void:
	ev_id = params.get("id", "")


func _ready() -> void:
	UI.full(self)
	if ev_id == "" or not DB.Events.DATA.has(ev_id):
		ev_id = _pick()
	ev = DB.Events.DATA[ev_id]
	Game.flags["event_seen_" + ev_id] = true
	var p = UI.panel()
	p.position = Vector2(190, 90)
	p.custom_minimum_size = Vector2(900, 0)
	add_child(p)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	box.add_child(UI.label(ev["title"], 30, UI.C_GOLD, true))
	var txt = UI.rich(ev["text"], 20)
	txt.custom_minimum_size = Vector2(860, 0)
	box.add_child(txt)
	for ch in ev["choices"]:
		var c: Dictionary = ch
		if not _choice_ok(c):
			continue
		box.add_child(UI.button(c["text"], func() -> void: _choose(c), 20))
	UI.focus_first(box)


func _pick() -> String:
	var cands: Array = []
	for id in DB.Events.DATA.keys():
		var e: Dictionary = DB.Events.DATA[id]
		if Game.flags.get("event_seen_" + id, false) and not e.get("repeat", false):
			continue
		if e.get("floor_min", 1) > Game.floor_num or e.get("floor_max", 99) < Game.floor_num:
			continue
		var ok = true
		for r in e.get("req", []):
			if not Game.is_joined(r):
				ok = false
		if ok:
			cands.append(id)
	if cands.is_empty():
		for id in DB.Events.DATA.keys():
			if DB.Events.DATA[id].get("repeat", false):
				cands.append(id)
	return cands[Game.rng.randi() % cands.size()]


func _choice_ok(c: Dictionary) -> bool:
	if c.has("cost") and Game.gald < c["cost"]:
		return true
	for r in c.get("req", []):
		if not Game.is_joined(r):
			return false
	return true


func _choose(c: Dictionary) -> void:
	for ch in box.get_children():
		if ch is Button:
			ch.disabled = true
	var res: Dictionary = c.get("result", {})
	if c.has("cost"):
		if Game.gald < c["cost"]:
			_show_result("ガルドが足りない……。", {})
			return
		Game.gald -= c["cost"]
	if res.has("chance"):
		if Game.rng.randf() < res["chance"]:
			res = res["success"]
		else:
			res = res["fail"]
	_apply(res)


func _apply(res: Dictionary) -> void:
	var msgs: Array = []
	if res.has("gald"):
		Game.add_gald(res["gald"])
		msgs.append("%dガルドを手に入れた。" % res["gald"] if res["gald"] > 0 else "%dガルドを失った。" % -res["gald"])
		Sfx.play("coin")
	if res.has("item"):
		Game.add_item(res["item"], res.get("count", 1))
		msgs.append("%sを%d個手に入れた。" % [DB.item(res["item"])["name"], res.get("count", 1)])
	if res.has("hp"):
		for m in Game.party:
			var mx = Game.max_hp(m["id"])
			m["hp"] = clampi(m["hp"] + int(mx * res["hp"]), 1, mx)
		msgs.append("全員のHPが回復した。" if res["hp"] > 0 else "全員がダメージを受けた。")
	if res.has("tp"):
		for m in Game.party:
			m["tp"] = min(Game.max_tp(m["id"]), m["tp"] + int(Game.max_tp(m["id"]) * res["tp"]))
	if res.has("buff"):
		var b: String = res["buff"]
		if b == "random":
			var r = Game.random_buffs(1)
			if r.size() > 0:
				Game.add_floor_buff(r[0])
		else:
			Game.add_floor_buff(b)
	if res.has("exp"):
		var ups = Game.gain_exp(res["exp"])
		msgs.append("全員が%dの経験値を得た。" % res["exp"])
		for u in ups:
			msgs.append("%sはLv%dになった！" % [DB.cname(u["id"]), u["level"]])
	if res.has("recipe") and not res["recipe"] in Game.known_recipes:
		Game.known_recipes.append(res["recipe"])
		msgs.append("レシピ『%s』を覚えた！" % DB.Items.RECIPES[res["recipe"]]["name"])
	if res.has("title"):
		Game.award_title(res["title"][0], res["title"][1])
	if res.has("bond"):
		Game.add_bond(res["bond"][0], res["bond"][1], res["bond"][2])
	if res.has("sp"):
		for m in Game.party:
			m["sp"] += res["sp"]
		msgs.append("全員のSPが%d増えた。" % res["sp"])
	var text: String = res.get("msg", "")
	if msgs.size() > 0:
		text += "\n[color=#a0ffb0]" + "\n".join(msgs) + "[/color]"
	_show_result(text, res)


func _show_result(text: String, res: Dictionary) -> void:
	box.add_child(HSeparator.new())
	var r = UI.rich(text, 20)
	r.custom_minimum_size = Vector2(860, 0)
	box.add_child(r)
	var next = func() -> void:
		if res.has("battle"):
			Main.inst.goto("battle", {"enemies": res["battle"], "kind": "battle"})
		else:
			Main.inst.goto("map", {"after": "event"})
	if res.has("lines"):
		# 決定キーがボタンにも届いて会話が何度も始まらないよう、一度だけ反応させる
		var once = [false]
		box.add_child(UI.button("次へ", func() -> void:
			if once[0]:
				return
			once[0] = true
			Main.inst.play_dialogue({"title": ev["title"], "mode": "skit", "bg": "none", "lines": res["lines"]}, next), 20))
	else:
		var once2 = [false]
		box.add_child(UI.button("次へ", func() -> void:
			if once2[0]:
				return
			once2[0] = true
			next.call(), 20))
	UI.focus_first(box)
	await get_tree().process_frame
	for c in box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(fd["bg_top"]).lerp(fd["bg_bottom"], i / 23.0).darkened(0.5))
	for i in range(20):
		var p = Vector2(fmod(i * 173.0 + t * 10.0, 1280.0), fmod(i * 91.0, 720.0))
		draw_circle(p, 2, Color(1, 1, 1, 0.15))
