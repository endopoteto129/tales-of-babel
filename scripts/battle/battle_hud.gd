# 戦闘HUD（パーティ状態・敵HP・コンボ・絆ゲージ・リザルト・ポーズメニュー）
extends Control

var battle: Node
var banner: Label
var arte_label: Label
var arte_t := 0.0
var warn_label: Label
var warn_t := 0.0
var combo_label: Label
var combo_sub: Label
var results: Control
var pause_menu: Control
var t := 0.0
var link_full_t := 0.0


static func officer_of(eid: String) -> String:
	match eid:
		"boss_nene":
			return "nene"
		"boss_val":
			return "val"
		"boss_zone":
			return "zone"
		"boss_shasta":
			return "shasta"
	return ""


func build() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = UI.outlined(UI.label("", 54, Color.WHITE, true), 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, 250)
	banner.size = Vector2(1280, 80)
	banner.modulate.a = 0.0
	add_child(banner)
	arte_label = UI.outlined(UI.label("", 30, Color(1, 0.95, 0.8), true), 8)
	arte_label.position = Vector2(0, 92)
	arte_label.size = Vector2(1280, 50)
	arte_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(arte_label)
	warn_label = UI.outlined(UI.label("", 30, Color(1, 0.4, 0.35), true), 8)
	warn_label.position = Vector2(0, 150)
	warn_label.size = Vector2(1280, 50)
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(warn_label)
	combo_label = UI.outlined(UI.label("", 44, Color(1, 0.85, 0.3), true), 8)
	combo_label.position = Vector2(1000, 180)
	combo_label.size = Vector2(260, 60)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(combo_label)
	combo_sub = UI.outlined(UI.label("", 18, Color(1, 1, 1), false), 5)
	combo_sub.position = Vector2(1000, 236)
	combo_sub.size = Vector2(260, 30)
	combo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(combo_sub)


func _process(delta: float) -> void:
	t += delta
	if arte_t > 0.0:
		arte_t -= delta
		if arte_t <= 0.0:
			create_tween().tween_property(arte_label, "modulate:a", 0.0, 0.25)
	if warn_t > 0.0:
		warn_t -= delta
		warn_label.modulate.a = 0.6 + sin(t * 14.0) * 0.4
		if warn_t <= 0.0:
			warn_label.modulate.a = 0.0
	if battle.combo_hits >= 2:
		combo_label.text = "%d HITS" % battle.combo_hits
		combo_sub.text = "%d DAMAGE" % battle.combo_dmg
		combo_label.modulate.a = 1.0
		combo_sub.modulate.a = 1.0
		combo_label.scale = Vector2.ONE
	elif combo_label.modulate.a > 0.0 and battle.combo_hits == 0:
		combo_label.modulate.a = max(0.0, combo_label.modulate.a - delta * 1.5)
		combo_sub.modulate.a = combo_label.modulate.a
	if battle.link >= 100.0:
		link_full_t += delta


func _draw() -> void:
	# 画面フラッシュ
	if battle.flash_col.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), battle.flash_col)
	_draw_party()
	_draw_enemies()
	_draw_link()
	_draw_buffs()
	if battle.started and not battle.ended:
		var hint = "J:攻撃  K(+↑↓→):術技  Space:ジャンプ  L:ガード  Tab:ターゲット  U:共鳴秘技  Esc:メニュー"
		if Input.get_connected_joypads().size() > 0:
			hint = "X(□):攻撃  B(○)+方向:術技  A(×):ジャンプ  LB/LT:ガード  RB:ターゲット  Y/RT:共鳴秘技  右スティック:仲間に指示  START:メニュー"
		draw_string(UI.FONT, Vector2(12, 612), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))


func _draw_party() -> void:
	var n: int = battle.party.size()
	for i in range(n):
		var f: Fighter = battle.party[i]
		var r = Rect2(10 + i * 316, 622, 306, 92)
		var col: Color = f.data["color"]
		draw_rect(r, Color(0.04, 0.05, 0.1, 0.85))
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), col)
		if f.is_player:
			draw_rect(r, Color(1, 0.85, 0.4, 0.9), false, 2.0)
		draw_string(UI.FONT_BOLD, r.position + Vector2(16, 26), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE if f.alive() else Color(0.6, 0.6, 0.6))
		var lv: int = Game.member(f.cid).get("level", 1)
		draw_string(UI.FONT, r.position + Vector2(120, 25), "Lv%d" % lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.8, 0.85))
		var hp_r: float = f.hp_ratio()
		var hpc = Color(0.4, 0.9, 0.5) if hp_r > 0.5 else (Color(1.0, 0.8, 0.3) if hp_r > 0.25 else Color(1.0, 0.35, 0.3))
		draw_string(UI.FONT, r.position + Vector2(16, 52), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))
		draw_string(UI.FONT_BOLD, r.position + Vector2(174, 50), "%d/%d" % [int(f.hp), int(f.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, 120, 17, hpc)
		UI.bar(self, Rect2(r.position + Vector2(44, 56), Vector2(250, 7)), hp_r, hpc)
		draw_string(UI.FONT, r.position + Vector2(16, 84), "TP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))
		draw_string(UI.FONT, r.position + Vector2(174, 86), "%d/%d" % [int(f.tp), int(f.max_tp)], HORIZONTAL_ALIGNMENT_RIGHT, 120, 14, Color(0.6, 0.8, 1.0))
		UI.bar(self, Rect2(r.position + Vector2(44, 68), Vector2(250, 5)), f.tp / max(1.0, f.max_tp), Color(0.45, 0.7, 1.0))
		if not f.alive():
			draw_string(UI.FONT_BOLD, r.position + Vector2(200, 28), "戦闘不能", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.4, 0.4))
		elif f.state == "cast":
			draw_string(UI.FONT, r.position + Vector2(200, 26), "詠唱中", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.9, 1.0))
		if f.buffs.size() > 0:
			draw_string(UI.FONT, r.position + Vector2(250, 26), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.9, 1.0))


func _draw_enemies() -> void:
	var boss: Fighter = null
	for e in battle.enemies:
		if e.data.get("boss", false) and e.alive():
			boss = e
		# 頭上の小さなHPバー
		if e.alive() and not e.data.get("boss", false):
			var p: Vector2 = e.head() + battle.world.position + Vector2(-30, -6)
			draw_rect(Rect2(p, Vector2(60, 6)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(p, Vector2(60 * e.hp_ratio(), 6)), Color(1.0, 0.35, 0.3))
			if e.armor_max > 0:
				draw_rect(Rect2(p + Vector2(0, 7), Vector2(60 * e.armor / e.armor_max, 3)), Color(0.9, 0.9, 0.6))
	if boss:
		var r = Rect2(240, 40, 800, 22)
		draw_string(UI.FONT_BOLD, Vector2(240, 32), boss.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.85))
		draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(r.position, Vector2(r.size.x * boss.hp_ratio(), r.size.y)), Color(0.85, 0.15, 0.2))
		draw_rect(Rect2(r.position, Vector2(r.size.x * boss.hp_ratio(), 6)), Color(1, 0.5, 0.5, 0.6))
		if boss.armor_max > 0:
			draw_rect(Rect2(r.position + Vector2(0, 26), Vector2(r.size.x * boss.armor / boss.armor_max, 5)), Color(1.0, 0.9, 0.5))
			draw_string(UI.FONT, Vector2(1046, 72), "装甲", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.5))
	# ターゲット表示
	var tg: Fighter = battle.player_target
	if tg and tg.alive():
		var hp2: Vector2 = tg.head() + battle.world.position + Vector2(0, -22)
		var bobv = sin(t * 6.0) * 4.0
		UI.poly(self, PackedVector2Array([hp2 + Vector2(-9, -14 + bobv), hp2 + Vector2(9, -14 + bobv), hp2 + Vector2(0, -2 + bobv)]), Color(1, 0.85, 0.3))
		if not tg.data.get("boss", false):
			draw_string(UI.FONT_BOLD, Vector2(16, 34), tg.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.85))
			UI.bar(self, Rect2(16, 42, 200, 8), tg.hp_ratio(), Color(1.0, 0.35, 0.3))


func _draw_link() -> void:
	var p = Vector2(1080, 560)
	var r = 34.0
	var k: float = battle.link / 100.0
	draw_circle(p, r + 6, Color(0, 0, 0, 0.6))
	draw_arc(p, r, -PI / 2, -PI / 2 + TAU * k, 48, Color(1.0, 0.55, 0.75), 8.0)
	if k >= 1.0:
		var pulse = 0.6 + sin(t * 8.0) * 0.4
		draw_circle(p, r - 6, Color(1.0, 0.6, 0.8, 0.35 * pulse))
		draw_string(UI.FONT_BOLD, p + Vector2(-80, -48), "共鳴秘技 [U]", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color(1, 0.75, 0.9, pulse))
	draw_string(UI.FONT_BOLD, p + Vector2(-20, 6), "絆", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color.WHITE)
	draw_string(UI.FONT, p + Vector2(-30, 52), "%d%%" % int(battle.link), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(1, 0.85, 0.9))


func _draw_buffs() -> void:
	var y = 70.0 if not battle.enemies.any(func(e) -> bool: return e.data.get("boss", false)) else 86.0
	var x = 16.0
	var names: Array = []
	for b in Game.floor_buffs:
		names.append(DB.buff(b)["name"].replace("の加護", ""))
	if not Game.meal.is_empty():
		names.append("料理:" + DB.Items.RECIPES[Game.meal["id"]]["name"])
	for nm in names:
		var w: float = nm.length() * 14 + 16
		draw_rect(Rect2(x, y, w, 22), Color(0.1, 0.2, 0.35, 0.75))
		draw_string(UI.FONT, Vector2(x + 8, y + 17), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.9, 1.0))
		x += w + 6
		if x > 900:
			break


# ------------------------------------------------------------ 演出
func show_banner(text: String, col: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.0, 1.0)
	var tw = create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)


func show_arte_name(name: String, level: int) -> void:
	arte_label.text = ("【秘奥義】" if level == 3 else "") + name
	var col = Color(1, 0.95, 0.8)
	if level == 2:
		col = Color(1.0, 0.75, 0.4)
	elif level == 3:
		col = Color(1.0, 0.4, 0.4)
	arte_label.add_theme_color_override("font_color", col)
	arte_label.modulate.a = 1.0
	arte_t = 1.0


func show_warning(text: String) -> void:
	warn_label.text = "！ " + text + " ！"
	warn_t = 2.0


func show_combo_end(hits: int, dmg: int) -> void:
	var l = UI.outlined(UI.label("%d HITS!" % hits, 34, Color(1.0, 0.7, 0.3), true), 8)
	l.position = Vector2(1020, 270)
	add_child(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:x", 1000.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func make_bubble(sp: String, text: String) -> Control:
	var p = UI.panel(Color(1, 1, 1, 0.95), DB.ccolor(sp) if DB.Characters.DATA.has(sp) else UI.C_GOLD)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var name = UI.label(DB.cname(sp), 13, DB.ccolor(sp).darkened(0.25), true)
	v.add_child(name)
	var l = UI.label(text, 17, Color(0.1, 0.1, 0.15))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min(360, 30 + text.length() * 17), 0)
	v.add_child(l)
	p.z_index = 30
	add_child(p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.12)
	return p


func play_link_cutin(a: String, b: String, ld: Dictionary) -> void:
	var root = Control.new()
	UI.full(root)
	add_child(root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	UI.full(dim)
	root.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.65, 0.2)
	var bands: Array = []
	var lines: Array = ld.get("lines", [])
	for i in range(2):
		var cid = a if i == 0 else b
		var band = ColorRect.new()
		band.color = DB.ccolor(cid).darkened(0.3)
		band.color.a = 0.9
		band.size = Vector2(1400, 170)
		band.position = Vector2(-1400 if i == 0 else 1400, 120 + i * 220)
		band.rotation = -0.06
		root.add_child(band)
		var por = Portrait.new()
		por.size = Vector2(240, 280)
		por.position = Vector2(80 if i == 0 else 960, -110)
		por.setup(cid, "serious" if cid != "nine" else "smile", i == 1)
		band.add_child(por)
		var txt = ""
		for ln in lines:
			if ln[0] == cid:
				txt = ln[1]
				break
		var l = UI.outlined(UI.label(txt, 30, Color.WHITE, true), 6)
		l.position = Vector2(360 if i == 0 else 300, 60)
		band.add_child(l)
		bands.append(band)
		var tw = create_tween()
		tw.tween_property(band, "position:x", -60.0, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		Sfx.play("slash", 0.7)
		await get_tree().create_timer(0.75).timeout
	# 必殺技名
	var title = UI.outlined(UI.label(ld.get("name", ""), 64, Color(1.0, 0.9, 0.5), true), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 100)
	title.position = Vector2(0, 515)
	title.pivot_offset = Vector2(640, 50)
	title.scale = Vector2(2.0, 2.0)
	title.modulate.a = 0.0
	root.add_child(title)
	var tw2 = create_tween().set_parallel()
	tw2.tween_property(title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(title, "modulate:a", 1.0, 0.15)
	Sfx.play("explode", 0.8)
	await get_tree().create_timer(1.0).timeout
	var tw3 = create_tween()
	tw3.tween_property(root, "modulate:a", 0.0, 0.25)
	tw3.tween_callback(root.queue_free)
	await get_tree().create_timer(0.1).timeout


# ------------------------------------------------------------ リザルト
func show_results(r: Dictionary) -> void:
	results = UI.panel(Color(0.04, 0.05, 0.1, 0.92), UI.C_GOLD)
	results.position = Vector2(690, 70)
	results.custom_minimum_size = Vector2(560, 0)
	add_child(results)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	results.add_child(v)
	var ttl = UI.label("VICTORY", 40, UI.C_GOLD, true)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ttl)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	v.add_child(grid)
	for row in [["獲得経験値", "%d EXP" % r["exp"]], ["獲得ガルド", "%d ガルド" % r["gald"]], ["最大コンボ", "%d HITS" % r["combo"]], ["戦闘時間", "%.1f 秒" % r["time"]]]:
		grid.add_child(UI.label(row[0], 20, UI.C_DIM))
		grid.add_child(UI.label(row[1], 22, UI.C_TEXT, true))
	if r["drops"].size() > 0:
		var names: Array = []
		for d in r["drops"]:
			names.append(DB.item(d)["name"])
		v.add_child(UI.label("入手： " + "、".join(names), 18, UI.C_GREEN))
	for u in r["ups"]:
		var l = UI.label("%s は Lv%d になった！ (SP+1)" % [DB.cname(u["id"]), u["level"]], 20, UI.C_GOLD, true)
		v.add_child(l)
	var hint = UI.label("決定キーで進む", 16, UI.C_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	results.modulate.a = 0.0
	create_tween().tween_property(results, "modulate:a", 1.0, 0.3)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if results and is_instance_valid(results) and results.modulate.a >= 0.99:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
			get_viewport().set_input_as_handled()
			Sfx.play("confirm")
			results.modulate.a = 0.5
			battle.finish_victory()


# ------------------------------------------------------------ ポーズメニュー
func toggle_pause() -> void:
	if pause_menu and is_instance_valid(pause_menu):
		_close_pause()
		return
	battle.paused = true
	Sfx.play("confirm")
	pause_menu = Control.new()
	UI.full(pause_menu)
	add_child(pause_menu)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	UI.full(dim)
	pause_menu.add_child(dim)
	_pause_main()


func _close_pause() -> void:
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	battle.paused = false
	Sfx.play("cancel")


func _pause_panel(title: String) -> VBoxContainer:
	for c in pause_menu.get_children():
		if c is PanelContainer:
			c.queue_free()
	var p = UI.panel()
	p.position = Vector2(440, 150)
	p.custom_minimum_size = Vector2(400, 0)
	pause_menu.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UI.label(title, 26, UI.C_GOLD, true))
	return v


func _pause_main() -> void:
	var v = _pause_panel("メニュー")
	v.add_child(UI.button("アイテム", _pause_items))
	v.add_child(UI.button("操作説明", _pause_controls))
	var esc = UI.button("逃げる", func() -> void:
		_close_pause()
		battle.escape())
	esc.disabled = battle.kind == "boss" or battle.params.get("no_escape", false)
	v.add_child(esc)
	v.add_child(UI.button("戦闘に戻る", _close_pause))
	UI.focus_first(v)


func _pause_items() -> void:
	var v = _pause_panel("アイテム")
	var any = false
	for id in DB.Items.DATA.keys():
		var n = Game.use_item_count(id)
		if n <= 0:
			continue
		any = true
		var it: Dictionary = DB.item(id)
		var iid: String = id
		v.add_child(UI.button("%s ×%d　%s" % [it["name"], n, it["desc"]], func() -> void: _pause_item_target(iid), 17))
	if not any:
		v.add_child(UI.label("アイテムを持っていない", 18, UI.C_DIM))
	v.add_child(UI.button("戻る", _pause_main))
	UI.focus_first(v)


func _pause_item_target(iid: String) -> void:
	var v = _pause_panel(DB.item(iid)["name"] + " を誰に使う？")
	for f in battle.party:
		var ff: Fighter = f
		var b = UI.button("%s  HP %d/%d" % [ff.display_name, int(ff.hp), int(ff.max_hp)], func() -> void:
			if battle.use_item(iid, ff):
				_close_pause()
			else:
				Sfx.play("cancel"))
		v.add_child(b)
	v.add_child(UI.button("戻る", _pause_items))
	UI.focus_first(v)


func _pause_controls() -> void:
	var v = _pause_panel("操作説明")
	var txt = "[b]移動[/b]　A/D または ←/→\n[b]通常攻撃[/b]　J（Z）　…3〜4段コンボ\n[b]術技[/b]　K（X）＋方向なし/↑/↓/←→ で4種類\n　通常攻撃 → 特技 → 奥義 と繋がる\n[b]ジャンプ[/b]　Space（C）　空中でも攻撃できる\n[b]ガード[/b]　L（Shift）　ガード中に←→でステップ回避\n[b]ターゲット切替[/b]　Tab（Q）\n[b]共鳴秘技[/b]　U（V）　絆ゲージ満タンで仲間との合体技\n[b]仲間への指示[/b]　1/2/3 で仲間が術技を使う\n\n仲間同士で同じ敵を攻撃すると「連携」で絆ゲージが大きく上がる。\nナインの応援でも絆がたまる。"
	txt += "\n\n[b]ゲームパッド[/b]　移動:左スティック/十字キー　攻撃:X(□)　術技:B(○)　ジャンプ:A(×)\nガード:LB/LT(L1/L2)　ターゲット:RB(R1)　共鳴秘技:Y(△)/RT(R2)　仲間に指示:右スティック←↑→　メニュー:START"
	v.add_child(UI.rich(txt, 16))
	v.add_child(UI.button("戻る", _pause_main))
	UI.focus_first(v)
