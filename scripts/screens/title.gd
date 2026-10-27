# タイトル画面
extends Control

var t := 0.0
var menu: VBoxContainer
var stars: Array = []
var help: Control


func _ready() -> void:
	UI.full(self)
	for i in range(120):
		stars.append(Vector3(randf() * 1280, randf() * 720, randf()))
	var title = UI.outlined(UI.label("テイルズ オブ バベル", 64, Color(1.0, 0.95, 0.85), true), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 120)
	title.size = Vector2(1280, 90)
	add_child(title)
	var sub = UI.outlined(UI.label("TALES  OF  BABEL", 28, Color(1.0, 0.75, 0.4)), 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 208)
	sub.size = Vector2(1280, 40)
	add_child(sub)
	var tag = UI.outlined(UI.label("― 絶対なんてない。それでも、君と昇る ―", 20, Color(0.85, 0.85, 0.95)), 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 256)
	tag.size = Vector2(1280, 30)
	add_child(tag)
	menu = VBoxContainer.new()
	menu.position = Vector2(540, 400)
	menu.custom_minimum_size = Vector2(200, 0)
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	menu.add_child(UI.button("はじめから", _new_game, 24))
	var cont = UI.button("つづきから", _continue, 24)
	cont.disabled = not Game.has_save()
	menu.add_child(cont)
	menu.add_child(UI.button("操作説明", _show_help, 24))
	# エディタから実行したとき（デバッグビルド）だけ表示
	if OS.is_debug_build():
		menu.add_child(UI.button("デバッグ：章を選ぶ", _show_debug, 20))
	if not OS.has_feature("web"):
		menu.add_child(UI.button("終了", func() -> void: get_tree().quit(), 24))
	UI.focus_first(menu)
	var ver = UI.label("社内コンペ用 試作版", 14, UI.C_DIM)
	ver.position = Vector2(1100, 690)
	add_child(ver)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	for i in range(24):
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(0.03, 0.03, 0.09).lerp(Color(0.2, 0.12, 0.25), i / 23.0))
	for s in stars:
		var a: float = 0.4 + sin(t * 2.0 + s.z * 10.0) * 0.4
		draw_circle(Vector2(s.x, s.y), 1.0 + s.z * 1.5, Color(1, 1, 0.95, a))
	# 塔
	var base = Vector2(640, 720)
	for i in range(14):
		var w = 360.0 - i * 22.0
		var y = 720.0 - i * 52.0
		var c = Color(0.12, 0.1, 0.16).lerp(Color(0.32, 0.26, 0.36), i / 13.0)
		draw_rect(Rect2(base.x - w / 2, y - 52, w, 52), c)
		draw_rect(Rect2(base.x - w / 2, y - 52, w, 4), Color(0.6, 0.5, 0.4, 0.4))
		for j in range(int(w / 40)):
			var lit = 0.3 + 0.3 * sin(t * 1.5 + i * 3 + j)
			draw_rect(Rect2(base.x - w / 2 + 14 + j * 40, y - 36, 10, 16), Color(1.0, 0.8, 0.45, lit))
	var tip = Vector2(640, 720 - 14 * 52)
	draw_circle(tip, 26 + sin(t * 2.0) * 4, Color(1.0, 0.95, 0.7, 0.35))
	draw_circle(tip, 10, Color(1.0, 0.95, 0.8))
	draw_line(tip, tip + Vector2(0, -200), Color(1.0, 0.95, 0.7, 0.15), 6.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.25))


func _new_game() -> void:
	Game.new_game()
	Game.flags["nine_absent"] = true
	Game.flags["pots_absent"] = true
	menu.visible = false
	var done = [false]
	Main.inst.play_story("p1_sisters", func() -> void: done[0] = true)
	while not done[0]:
		await get_tree().process_frame
	done[0] = false
	Main.inst.play_story("p2_balfour", func() -> void: done[0] = true)
	while not done[0]:
		await get_tree().process_frame
	Main.inst.goto("battle", {"enemies": ["soldier", "soldier"], "kind": "prologue", "scale": 0.55, "no_escape": true, "past": true})


func _continue() -> void:
	if Game.load_game():
		Main.inst.goto("map", {})


func _show_help() -> void:
	if help:
		help.queue_free()
	help = UI.panel()
	help.position = Vector2(240, 120)
	help.custom_minimum_size = Vector2(800, 0)
	add_child(help)
	var v = VBoxContainer.new()
	help.add_child(v)
	v.add_child(UI.label("操作説明", 28, UI.C_GOLD, true))
	v.add_child(UI.rich("[b]バトル[/b]（ゲームパッド対応）\n移動：A/D・←→　通常攻撃：J　術技：K（＋↑/↓/←→で4種）\nジャンプ：Space　ガード：L（ガード中←→でステップ）\nターゲット切替：Tab　共鳴秘技：U（絆ゲージ満タン時）　メニュー：Esc\n仲間に術技を指示：1/2/3\n[b]ゲームパッド[/b]　移動：左スティック/十字キー　攻撃：X(□)　術技：B(○)　ジャンプ：A(×)\nガード：LB/LT　ターゲット：RB　共鳴秘技：Y/RT　仲間に指示：右スティック←↑→　メニュー：START　スキット：BACK\n\n[b]マップ[/b]\n←→でルート選択、決定で進む。スキット：T　メニュー：M\n\n[b]テイルズ流のコツ[/b]\n通常攻撃 → 特技 → 奥義 の順にキャンセルして繋げよう。\n仲間と同じ敵を叩くと「連携」で絆ゲージが一気にたまる。", 18))
	v.add_child(UI.button("閉じる", func() -> void:
		help.queue_free()
		help = null
		UI.focus_first(menu)))
	UI.focus_first(v)


func _show_debug() -> void:
	if help:
		help.queue_free()
	help = UI.panel(Color(0.05, 0.05, 0.1, 0.98), UI.C_GOLD)
	help.position = Vector2(200, 60)
	help.custom_minimum_size = Vector2(880, 0)
	add_child(help)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	help.add_child(v)
	v.add_child(UI.label("デバッグ：章を選ぶ", 28, UI.C_GOLD, true))
	v.add_child(UI.label("レベル・スキル・所持品・仲間は、通常プレイでその時点に想定される状態にそろえます。", 16, UI.C_DIM))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for f in range(1, 8):
		var fname: String = DB.floor_data(f)["name"]
		for boss in [false, true]:
			var ff: int = f
			var bb: bool = boss
			var lv: int = (Game.EXPECTED_LV_BOSS if boss else Game.EXPECTED_LV_START)[f - 1]
			var label = "%s　%s（Lv%d）" % [fname, "ボス直前" if boss else "開始", lv]
			var b = UI.button(label, func() -> void: _debug_jump(ff, bb), 17)
			b.custom_minimum_size = Vector2(430, 0)
			grid.add_child(b)
	v.add_child(UI.button("閉じる", func() -> void:
		help.queue_free()
		help = null
		UI.focus_first(menu)))
	UI.focus_first(grid)


func _debug_jump(f: int, at_boss: bool) -> void:
	Game.debug_setup(f, at_boss)
	Main.inst.goto("map", {})
