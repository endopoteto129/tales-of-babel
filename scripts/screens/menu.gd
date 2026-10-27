# キャンプメニュー（ステータス・術技・スキルツリー・称号・アイテム・隊列・システム）
extends Control

const TABS := ["ステータス", "術技", "スキルツリー", "称号", "アイテム", "隊列", "システム"]

var params: Dictionary
var tab := 0
var cidx := 0
var tabs_box: VBoxContainer
var content: Control
var char_bar: HBoxContainer
var slot_sel := -1


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	UI.full(self)
	var bgc = ColorRect.new()
	bgc.color = Color(0.05, 0.06, 0.11)
	UI.full(bgc)
	add_child(bgc)
	var head = UI.outlined(UI.label("メニュー", 30, UI.C_GOLD, true), 5)
	head.position = Vector2(30, 18)
	add_child(head)
	tabs_box = VBoxContainer.new()
	tabs_box.position = Vector2(24, 80)
	tabs_box.custom_minimum_size = Vector2(190, 0)
	tabs_box.add_theme_constant_override("separation", 8)
	add_child(tabs_box)
	for i in range(TABS.size()):
		var idx = i
		tabs_box.add_child(UI.button(TABS[i], func() -> void:
			tab = idx
			_rebuild(), 20))
	tabs_box.add_child(UI.button("閉じる [Esc]", _close, 20))
	char_bar = HBoxContainer.new()
	char_bar.position = Vector2(240, 24)
	char_bar.add_theme_constant_override("separation", 8)
	add_child(char_bar)
	content = Control.new()
	content.position = Vector2(240, 80)
	content.size = Vector2(1020, 620)
	add_child(content)
	_rebuild()
	UI.focus_first(tabs_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Sfx.play("cancel")
	Main.inst.goto(params.get("back", "map"), {})


func _cid() -> String:
	return Game.party[clampi(cidx, 0, Game.party.size() - 1)]["id"]


func _rebuild() -> void:
	for c in content.get_children():
		c.queue_free()
	for c in char_bar.get_children():
		c.queue_free()
	if tab in [0, 1, 2, 3]:
		for i in range(Game.party.size()):
			var m: Dictionary = Game.party[i]
			var idx = i
			var b = UI.button(DB.cname(m["id"]) + (" ●" if m["sp"] > 0 and tab == 2 else ""), func() -> void:
				cidx = idx
				slot_sel = -1
				_rebuild(), 18)
			if i == cidx:
				b.add_theme_color_override("font_color", UI.C_GOLD)
			char_bar.add_child(b)
	match tab:
		0:
			_status()
		1:
			_artes()
		2:
			_tree()
		3:
			_titles()
		4:
			_items()
		5:
			_formation()
		6:
			_system()


func _status() -> void:
	var cid = _cid()
	var m = Game.member(cid)
	var c: Dictionary = DB.chara(cid)
	var por = Portrait.new()
	por.size = Vector2(320, 380)
	por.position = Vector2(0, 40)
	por.setup(cid, "")
	content.add_child(por)
	var v = VBoxContainer.new()
	v.position = Vector2(360, 0)
	v.custom_minimum_size = Vector2(640, 0)
	v.add_theme_constant_override("separation", 6)
	content.add_child(v)
	v.add_child(UI.label(c["full_name"], 30, DB.ccolor(cid).lightened(0.35), true))
	var tt: String = DB.title(m["title"])["name"] if m["title"] != "" else "なし"
	v.add_child(UI.label("称号：" + tt, 18, UI.C_GOLD))
	v.add_child(UI.label("Lv %d　　EXP %d / %d　　SP %d" % [m["level"], m["exp"], Game.exp_to_next(m["level"]), m["sp"]], 20))
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 30)
	v.add_child(g)
	var names = {"hp": "最大HP", "tp": "最大TP", "atk": "攻撃力", "def": "防御力", "matk": "魔攻", "mdef": "魔防", "agi": "素早さ"}
	for k in ["hp", "tp", "atk", "def", "matk", "mdef", "agi"]:
		g.add_child(UI.label(names[k], 18, UI.C_DIM))
		g.add_child(UI.label(str(int(Game.stat(cid, k))), 20, UI.C_TEXT, true))
	v.add_child(UI.label("HP %d / %d　　TP %d / %d" % [m["hp"], Game.max_hp(cid), m["tp"], Game.max_tp(cid)], 18))
	v.add_child(HSeparator.new())
	var prof = UI.label(c["profile"], 18)
	prof.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prof.custom_minimum_size = Vector2(640, 0)
	v.add_child(prof)
	v.add_child(HSeparator.new())
	var bonds: Array = []
	for o in Game.party:
		if o["id"] != cid:
			bonds.append("%s %d" % [DB.cname(o["id"]), Game.get_bond(cid, o["id"])])
	if not bonds.is_empty():
		v.add_child(UI.label("絆：" + "　".join(bonds), 17, Color(1, 0.75, 0.9)))


func _artes() -> void:
	var cid = _cid()
	var m = Game.member(cid)
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(1000, 0)
	v.add_theme_constant_override("separation", 6)
	content.add_child(v)
	v.add_child(UI.label("術技セット（バトル中：K / ↑+K / ↓+K / ←→+K）", 20, UI.C_GOLD, true))
	if cid != "ren":
		v.add_child(UI.label("※仲間は自動で術技を使う。セットした順に優先され、1/2/3キーで1番目を指示できる。", 15, UI.C_DIM))
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var slot_names = ["K", "↑+K", "↓+K", "←→+K"]
	for i in range(4):
		var aid: String = m["slots"][i]
		var nm: String = DB.arte(aid)["name"] if aid != "" else "（なし）"
		var idx = i
		var b = UI.button("%s\n%s" % [slot_names[i], nm], func() -> void:
			slot_sel = idx
			_rebuild(), 17)
		b.custom_minimum_size = Vector2(240, 64)
		if slot_sel == i:
			b.add_theme_color_override("font_color", UI.C_GOLD)
		hb.add_child(b)
	v.add_child(UI.label("習得済みの術技" + ("（セットする術技を選んでください）" if slot_sel >= 0 else "（先に上のスロットを選択）"), 17, UI.C_DIM))
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1000, 420)
	v.add_child(sc)
	var lv = VBoxContainer.new()
	sc.add_child(lv)
	for aid in m["artes"]:
		var a: Dictionary = DB.arte(aid)
		var id: String = aid
		var b2 = UI.button("【%s】%s　TP%d　―　%s" % [DB.Artes.KIND_NAME[a["kind"]], a["name"], a["tp"], a["desc"]], func() -> void:
			if slot_sel >= 0:
				for j in range(4):
					if m["slots"][j] == id:
						m["slots"][j] = ""
				m["slots"][slot_sel] = id
				slot_sel = -1
				_rebuild(), 17)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lv.add_child(b2)


func _tree() -> void:
	var cid = _cid()
	var m = Game.member(cid)
	var nodes: Array = DB.tree(cid)
	content.add_child(UI.label("%s のスキルツリー　　SP：%d" % [DB.cname(cid), m["sp"]], 22, UI.C_GOLD, true))
	var desc = UI.rich("ノードを選んで習得（SPはレベルアップと層の踏破で増える）", 17)
	desc.position = Vector2(620, 60)
	desc.custom_minimum_size = Vector2(390, 200)
	content.add_child(desc)
	var canvas = TreeCanvas.new()
	canvas.position = Vector2(0, 50)
	canvas.size = Vector2(600, 560)
	canvas.nodes = nodes
	canvas.learned = m["nodes"]
	content.add_child(canvas)
	for n in nodes:
		var nd: Dictionary = n
		var learned: bool = nd["id"] in m["nodes"]
		var avail = not learned
		for r in nd["req"]:
			if not r in m["nodes"]:
				avail = false
		var b = Button.new()
		b.text = nd["name"] + ("" if learned else "\nSP%d" % nd["cost"])
		b.add_theme_font_size_override("font_size", 15)
		b.position = canvas.pos_of(nd) - Vector2(80, 30) + Vector2(0, 50)
		b.custom_minimum_size = Vector2(160, 60)
		if learned:
			b.add_theme_color_override("font_color", UI.C_GOLD)
			b.add_theme_stylebox_override("normal", UI.box(Color(0.3, 0.24, 0.1, 0.95), UI.C_GOLD, 2, 8))
		elif avail:
			b.add_theme_stylebox_override("normal", UI.box(Color(0.1, 0.16, 0.26, 0.95), UI.C_BLUE, 2, 8))
		else:
			b.modulate = Color(0.75, 0.75, 0.78)
		b.focus_entered.connect(func() -> void:
			Sfx.play("select")
			desc.text = "[b]%s[/b]\n%s\n\n必要SP：%d\n%s" % [nd["name"], nd["desc"], nd["cost"], "習得済み" if learned else ("習得できる" if avail and m["sp"] >= nd["cost"] else "前提の習得かSPが必要")])
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(func() -> void:
			if Game.learn_node(cid, nd["id"]):
				Sfx.play("levelup")
				Main.inst.toast("%s：%s を習得！" % [DB.cname(cid), nd["name"]], "info")
				_rebuild()
			else:
				Sfx.play("cancel"))
		content.add_child(b)


class TreeCanvas extends Control:
	var nodes: Array = []
	var learned: Array = []

	func pos_of(n: Dictionary) -> Vector2:
		var p: Vector2 = n["pos"]
		return Vector2(110 + p.x * 190, 40 + p.y * 110)

	func _draw() -> void:
		for n in nodes:
			for r in n["req"]:
				for o in nodes:
					if o["id"] == r:
						var lit: bool = r in learned
						draw_line(pos_of(o), pos_of(n), Color(1, 0.85, 0.4, 0.9) if lit else Color(1, 1, 1, 0.25), 4.0 if lit else 2.0)


func _titles() -> void:
	var cid = _cid()
	var m = Game.member(cid)
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(1000, 0)
	content.add_child(v)
	v.add_child(UI.label("称号（装備すると能力が上がる）　所持 %d" % m["titles"].size(), 20, UI.C_GOLD, true))
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1000, 560)
	v.add_child(sc)
	var lv = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	sc.add_child(lv)
	for tid in m["titles"]:
		var td: Dictionary = DB.title(tid)
		var bonus: Array = []
		var names = {"hp": "HP", "tp": "TP", "atk": "攻", "def": "防", "matk": "魔攻", "mdef": "魔防", "agi": "速"}
		for k in td["bonus"]:
			bonus.append("%s+%d" % [names[k], td["bonus"][k]])
		var id: String = tid
		var b = UI.button("%s%s　[%s]\n　%s" % ["★ " if m["title"] == tid else "", td["name"], " ".join(bonus), td["desc"]], func() -> void:
			m["title"] = id
			_rebuild(), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lv.add_child(b)


func _items() -> void:
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(1000, 0)
	v.add_theme_constant_override("separation", 6)
	content.add_child(v)
	v.add_child(UI.label("アイテム　　所持金 %d ガルド" % Game.gald, 20, UI.C_GOLD, true))
	var any = false
	for id in DB.Items.DATA.keys():
		var n = Game.use_item_count(id)
		if n <= 0:
			continue
		any = true
		var it: Dictionary = DB.item(id)
		var iid: String = id
		var row = HBoxContainer.new()
		row.add_child(UI.label("%s ×%d　%s" % [it["name"], n, it["desc"]], 18))
		v.add_child(row)
		if it.has("hp") or it.has("tp"):
			var hb = HBoxContainer.new()
			for m in Game.party:
				var mm: Dictionary = m
				hb.add_child(UI.button("%s(%d/%d)" % [DB.cname(mm["id"]), mm["hp"], Game.max_hp(mm["id"])], func() -> void:
					if Game.use_item_count(iid) <= 0:
						return
					if it.has("hp"):
						mm["hp"] = min(Game.max_hp(mm["id"]), mm["hp"] + int(Game.max_hp(mm["id"]) * it["hp"]))
					if it.has("tp"):
						mm["tp"] = min(Game.max_tp(mm["id"]), mm["tp"] + int(Game.max_tp(mm["id"]) * it["tp"]))
					Game.remove_item(iid)
					Sfx.play("heal")
					_rebuild(), 15))
			v.add_child(hb)
	if not any:
		v.add_child(UI.label("アイテムを持っていない", 18, UI.C_DIM))
	v.add_child(HSeparator.new())
	v.add_child(UI.label("覚えたレシピ：" + "、".join(Game.known_recipes.map(func(r) -> String: return DB.Items.RECIPES[r]["name"])), 17))


func _formation() -> void:
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(1000, 0)
	v.add_theme_constant_override("separation", 8)
	content.add_child(v)
	v.add_child(UI.label("隊列（戦闘に出るのは4人まで。レンは固定）", 20, UI.C_GOLD, true))
	for i in range(Game.party.size()):
		var m: Dictionary = Game.party[i]
		var mm = m
		var active: bool = m.get("active", true)
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		v.add_child(hb)
		var nl = UI.label("%d. %s" % [i + 1, DB.cname(m["id"])], 22, DB.ccolor(m["id"]).lightened(0.3), true)
		nl.custom_minimum_size = Vector2(200, 0)
		hb.add_child(nl)
		if m["id"] == "ren":
			hb.add_child(UI.label("リーダー（操作キャラ）", 18, UI.C_DIM))
			continue
		hb.add_child(UI.button("出撃中" if active else "控え", func() -> void:
			if active:
				mm["active"] = false
			else:
				var cnt = 0
				for o in Game.party:
					if o.get("active", true):
						cnt += 1
				if cnt >= 4:
					Main.inst.toast("出撃できるのは4人までです", "info")
					return
				mm["active"] = true
			_rebuild(), 18))
		var idx = i
		if i > 1:
			hb.add_child(UI.button("↑", func() -> void:
				var tmp: Dictionary = Game.party[idx - 1]
				Game.party[idx - 1] = Game.party[idx]
				Game.party[idx] = tmp
				_rebuild(), 18))


func _system() -> void:
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(400, 0)
	v.add_theme_constant_override("separation", 10)
	content.add_child(v)
	v.add_child(UI.label("システム", 22, UI.C_GOLD, true))
	var mins = int(Game.play_time / 60.0)
	v.add_child(UI.label("プレイ時間 %d:%02d　　戦闘回数 %d" % [mins / 60, mins % 60, Game.counters.get("battles", 0)], 18))
	v.add_child(UI.button("セーブする", func() -> void:
		Game.save_game()
		Main.inst.toast("セーブしました", "info"), 20))
	v.add_child(UI.button("タイトルへ戻る", func() -> void: Main.inst.goto("title"), 20))
