# スマホ・タブレット用のタッチ操作ボタン。
# 画面に触れると表示され、キーボードやゲームパッドを触ると消える（Game.touch_mode）。
# 押したボタンは、キーボードと同じ入力アクション（attack / jump など）として送るので、
# ゲーム側はタッチ操作を特別扱いしなくてよい。
#  ・左半分：どこに指を置いてもそこがスティックの中心になる（フローティングスティック）
#  ・右下：場面ごとのボタン（マップ／戦闘）
class_name TouchControls
extends CanvasLayer

const STICK_R := 90.0        # スティックの可動半径
const DEAD := 0.28           # これより小さい倒し方は無視
const BTN_ALPHA := 0.42

var mode := ""               # "" / "map" / "battle" / "dialogue"
var buttons: Array = []      # {action, label, pos, r, held_by}
var stick_touch := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var held_dirs := {}          # action -> strength
var canvas: Node2D


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Node2D.new()
	canvas.draw.connect(_draw_controls)
	add_child(canvas)


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size


func _current_mode() -> String:
	if not Game.touch_mode:
		return ""
	var main := Main.inst
	if main == null or main.busy or main.screen == null:
		return ""
	# 会話・チュートリアルの間は、会話を飛ばすボタンだけ（会話は画面のタップで進む）
	for c in main.overlay.get_children():
		if c == main.toast_box:
			continue
		if c.has_method("setup"):
			return "dialogue"
		return ""
	if main.screen_name == "map":
		if main.screen.get("locked"):
			return ""
		return "map"
	if main.screen_name == "battle":
		var b = main.screen
		if not b.started or b.ended or b.paused or get_tree().paused:
			return ""
		if b.hud and is_instance_valid(b.hud.pause_menu):
			return ""
		return "battle"
	return ""


var layout_sig := ""


func _unlock_sig() -> String:
	return "%s%s" % [Game.flags.get("link_unlocked", false), Game.flags.get("ovl_unlocked", false)]


func _layout(m: String) -> void:
	layout_sig = _unlock_sig()
	var v := _view()
	var R := v.x
	var B := v.y
	buttons.clear()
	match m:
		"map":
			buttons.append(_btn("ui_accept", "調べる", Vector2(R - 110, B - 110), 66))
			buttons.append(_btn("guard", "ダッシュ", Vector2(R - 250, B - 80), 50))
			buttons.append(_btn("menu", "メニュー", Vector2(R - 60, 210), 40))
		"battle":
			buttons.append(_btn("attack", "攻撃", Vector2(R - 105, B - 105), 64))
			buttons.append(_btn("arte", "術技", Vector2(R - 245, B - 75), 52))
			buttons.append(_btn("jump", "跳ぶ", Vector2(R - 110, B - 260), 50))
			buttons.append(_btn("guard", "ガード", Vector2(R - 250, B - 210), 50))
			buttons.append(_btn("dodge", "回避", Vector2(R - 375, B - 70), 42))
			buttons.append(_btn("target", "狙う", Vector2(R - 60, B - 380), 36))
			if Game.flags.get("link_unlocked", false):
				buttons.append(_btn("link", "秘技", Vector2(R - 150, B - 400), 36))
			if Game.flags.get("ovl_unlocked", false):
				buttons.append(_btn("overlimit", "OVL", Vector2(R - 240, B - 380), 36))
			buttons.append(_btn("pause", "Ⅱ", Vector2(R - 300, 46), 32))
		"dialogue":
			buttons.append(_btn("pause", "スキップ", Vector2(R - 70, 50), 38))


func _btn(action: String, label: String, pos: Vector2, r: float) -> Dictionary:
	return {"action": action, "label": label, "pos": pos, "r": r, "held_by": -1}


func _process(_delta: float) -> void:
	var m := _current_mode()
	if m != mode:
		_release_all()
		mode = m
		_layout(mode)
	elif mode != "" and buttons.size() > 0 and buttons[0]["pos"].x > _view().x:
		_layout(mode)  # 画面の向きや大きさが変わった
	elif mode == "battle" and _unlock_sig() != layout_sig:
		_release_all()
		_layout(mode)  # 戦闘中に絆技やOVLが解放された
	canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if mode == "":
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for b in buttons:
				if b["held_by"] == -1 and p.distance_to(b["pos"]) <= b["r"] * 1.15:
					b["held_by"] = event.index
					_send(b["action"], true)
					get_viewport().set_input_as_handled()
					return
			# 左の6割：スティック（会話中は使わない）
			if mode != "dialogue" and stick_touch == -1 and p.x < _view().x * 0.6:
				stick_touch = event.index
				stick_origin = p
				stick_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			for b in buttons:
				if b["held_by"] == event.index:
					b["held_by"] = -1
					_send(b["action"], false)
			if event.index == stick_touch:
				stick_touch = -1
				stick_vec = Vector2.ZERO
				_apply_stick()
	elif event is InputEventScreenDrag and event.index == stick_touch:
		var d: Vector2 = event.position - stick_origin
		if d.length() > STICK_R:
			# 指が大きく動いたら、中心も一緒に引っ張る（いつまでも同じ所に戻らなくてよい）
			stick_origin = event.position - d.limit_length(STICK_R)
			d = d.limit_length(STICK_R)
		stick_vec = d / STICK_R
		_apply_stick()
		get_viewport().set_input_as_handled()


func _apply_stick() -> void:
	var v := stick_vec
	var want := {
		"move_left": maxf(0.0, -v.x), "move_right": maxf(0.0, v.x),
		"move_up": maxf(0.0, -v.y), "move_down": maxf(0.0, v.y),
	}
	for a in want:
		var s: float = want[a]
		if s < DEAD:
			s = 0.0
		var was: float = held_dirs.get(a, 0.0)
		if s > 0.0 and was == 0.0:
			_send(a, true, s)
		elif s == 0.0 and was > 0.0:
			_send(a, false)
		elif s > 0.0:
			Input.action_press(a, s)
		held_dirs[a] = s


func _send(action: String, pressed: bool, strength: float = 1.0) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength if pressed else 0.0
	Input.parse_input_event(e)


func _release_all() -> void:
	for b in buttons:
		if b["held_by"] != -1:
			b["held_by"] = -1
			_send(b["action"], false)
	stick_touch = -1
	stick_vec = Vector2.ZERO
	_apply_stick()


func _draw_controls() -> void:
	if mode == "":
		return
	var font := UI.FONT_BOLD
	if mode != "dialogue":
		# スティック：触っていないときは置き場所の目安だけ薄く出す
		var c := stick_origin if stick_touch != -1 else Vector2(170, _view().y - 210)
		var a := 0.5 if stick_touch != -1 else 0.22
		canvas.draw_circle(c, STICK_R + 14, Color(0, 0, 0, a * 0.6))
		canvas.draw_arc(c, STICK_R + 14, 0, TAU, 48, Color(1, 1, 1, a), 3.0)
		canvas.draw_circle(c + stick_vec * STICK_R, 40, Color(1, 1, 1, a + 0.15))
	for b in buttons:
		var held: bool = b["held_by"] != -1
		var pos: Vector2 = b["pos"]
		var r: float = b["r"]
		canvas.draw_circle(pos, r, Color(0.05, 0.05, 0.1, BTN_ALPHA + (0.25 if held else 0.0)))
		canvas.draw_arc(pos, r, 0, TAU, 40, Color(1, 0.9, 0.6, 0.8 if held else 0.55), 3.0)
		var fs := 22 if r >= 50 else 17
		var sz := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		canvas.draw_string(font, pos + Vector2(-sz.x / 2.0, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
