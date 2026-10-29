# ショップ（異形の行商人）
extends Control

var list: VBoxContainer
var gald_label: Label
var talk_label: RichTextLabel
var stock: Array = []
var t := 0.0


func _ready() -> void:
	UI.full(self)
	var head = UI.outlined(UI.label("異形の行商人", 34, UI.C_GOLD, true), 6)
	head.position = Vector2(40, 26)
	add_child(head)
	gald_label = UI.label("", 22, UI.C_GOLD, true)
	gald_label.position = Vector2(40, 80)
	add_child(gald_label)
	var p = UI.panel()
	p.position = Vector2(40, 130)
	p.custom_minimum_size = Vector2(700, 520)
	add_child(p)
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(680, 500)
	p.add_child(sc)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	var tp = UI.panel(Color(0.05, 0.05, 0.1, 0.9))
	tp.position = Vector2(780, 470)
	tp.custom_minimum_size = Vector2(460, 180)
	add_child(tp)
	talk_label = UI.rich("", 19)
	talk_label.custom_minimum_size = Vector2(440, 160)
	tp.add_child(talk_label)
	_make_stock()
	_refresh()
	if Game.should_tutorial("shop"):
		await Main.inst.show_tutorial("shop")
		_refresh()
	_say("towner", DB.Skits.shop_greeting())
	var comment: Array = DB.Skits.shop_comment()
	if comment.size() > 0:
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			_say(comment[0], comment[1])


func _make_stock() -> void:
	stock = ["apple_gel", "orange_gel", "lemon_gel", "life_bottle"]
	if Game.floor_num >= 2:
		stock.append("mixed_gel")
	var bs = Game.random_buffs(2)
	for b in bs:
		stock.append("buff:" + b)
	for rid in DB.Items.RECIPES.keys():
		if not rid in Game.known_recipes:
			stock.append("recipe:" + rid)
			break


func _price(id: String) -> int:
	if id.begins_with("buff:"):
		return 260 + Game.floor_num * 40
	if id.begins_with("recipe:"):
		return 150
	return DB.item(id)["price"]


func _refresh() -> void:
	gald_label.text = "所持金  %d ガルド" % Game.gald
	for c in list.get_children():
		c.queue_free()
	list.add_child(UI.label("― 道具 ―", 18, UI.C_DIM))
	for id in stock:
		if id.begins_with("buff:") and list.get_child_count() > 0 and not _has_header("― 加護の護符 ―"):
			list.add_child(UI.label("― 加護の護符（この層だけ有効）―", 18, UI.C_DIM))
		var name = ""
		var desc = ""
		if id.begins_with("buff:"):
			var b: Dictionary = DB.buff(id.substr(5))
			name = b["name"] + "の護符"
			desc = b["desc"]
		elif id.begins_with("recipe:"):
			var r: Dictionary = DB.Items.RECIPES[id.substr(7)]
			name = "レシピ：" + r["name"]
			desc = r["desc"]
		else:
			var it: Dictionary = DB.item(id)
			name = "%s（所持 %d）" % [it["name"], Game.use_item_count(id)]
			desc = it["desc"]
		var iid: String = id
		var b2 = UI.button("%s　%dG\n　%s" % [name, _price(id), desc], func() -> void: _buy(iid), 17)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.disabled = Game.gald < _price(id)
		list.add_child(b2)
	list.add_child(UI.button("店を出る", _leave, 20))
	UI.focus_first(list)


func _has_header(_s: String) -> bool:
	for c in list.get_children():
		if c is Label and c.text.begins_with("― 加護"):
			return true
	return false


func _buy(id: String) -> void:
	var price = _price(id)
	if Game.gald < price:
		Sfx.play("cancel")
		return
	Game.gald -= price
	Sfx.play("coin")
	if id.begins_with("buff:"):
		Game.add_floor_buff(id.substr(5))
		stock.erase(id)
	elif id.begins_with("recipe:"):
		var rid = id.substr(7)
		Game.known_recipes.append(rid)
		Main.inst.toast("レシピ『%s』を覚えた！" % DB.Items.RECIPES[rid]["name"], "info")
		stock.erase(id)
	else:
		Game.add_item(id)
	Game.count("shop_buys")
	if Game.is_joined("sona") and Game.count("sona_purse_check") == 3:
		_say("sona", "……ねえ、買いすぎじゃない？　財布はわたしが預かるわ。")
		Game.award_title("sona_purse", "sona")
	else:
		_say("towner", ["マイドアリ。", "ヒヒ、イイ買イ物ダ。", "マタ来ナ、上ヘ昇ル人。"][randi() % 3])
	_refresh()


func _say(sp: String, text: String) -> void:
	talk_label.text = "[b][color=#%s]%s[/color][/b]\n%s" % [DB.ccolor(sp).lightened(0.3).to_html(false), DB.cname(sp), text]
	Sfx.play("chat", 0.9, -8)


func _leave() -> void:
	Main.inst.goto("map", {"after": "shop"})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.08, 0.12))
	for i in range(8):
		draw_circle(Vector2(100 + i * 160, 20), 14 + sin(t * 3 + i) * 2, Color(1.0, 0.7, 0.35, 0.6))
	# 店主（異形）
	var c = Vector2(1010, 330)
	var bob = sin(t * 2.0) * 6.0
	draw_circle(c + Vector2(0, bob), 90, Color(0.4, 0.6, 0.5))
	for i in range(5):
		var a = PI * 0.2 + i * 0.25
		draw_line(c + Vector2(cos(a) * 80, sin(a) * 80 + bob), c + Vector2(cos(a) * 140, sin(a) * 140 + sin(t * 3 + i) * 10 + bob), Color(0.35, 0.55, 0.45), 10)
	draw_circle(c + Vector2(-26, -20 + bob), 18, Color.WHITE)
	draw_circle(c + Vector2(30, -14 + bob), 12, Color.WHITE)
	draw_circle(c + Vector2(-22, -20 + bob), 8, Color(0.1, 0.1, 0.1))
	draw_circle(c + Vector2(33, -14 + bob), 5, Color(0.1, 0.1, 0.1))
	draw_arc(c + Vector2(0, 26 + bob), 30, 0.3, PI - 0.3, 12, Color(0.2, 0.3, 0.25), 4)
	draw_rect(Rect2(820, 420, 380, 30), Color(0.35, 0.22, 0.12))
