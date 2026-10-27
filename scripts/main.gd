# ルートノード。画面遷移・フェード・通知・会話オーバーレイを管理する。
class_name Main
extends Node

const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"map": "res://scripts/screens/map.gd",
	"battle": "res://scripts/battle/battle.gd",
	"camp": "res://scripts/screens/camp.gd",
	"shop": "res://scripts/screens/shop.gd",
	"event": "res://scripts/screens/event.gd",
	"menu": "res://scripts/screens/menu.gd",
	"gameover": "res://scripts/screens/gameover.gd",
	"ending": "res://scripts/screens/ending.gd",
}

static var inst: Main

var screen: Node
var screen_name := ""
var overlay: CanvasLayer
var fade: ColorRect
var toast_box: VBoxContainer
var busy := false


func _ready() -> void:
	inst = self
	get_tree().root.theme = UI.theme()
	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(400, 14)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(toast_box)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(fade)
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_layer.add_child(fade)
	Game.notified.connect(_on_notified)
	var args = OS.get_cmdline_user_args()
	if "--shots" in args:
		add_child(load("res://scripts/shots.gd").new())
		return
	if "--balance" in args:
		add_child(load("res://scripts/balance.gd").new())
		return
	if "--repro" in args:
		add_child(load("res://scripts/repro.gd").new())
		return
	if "--autotest" in args:
		var t: Node = load("res://scripts/autotest.gd").new()
		add_child(t)
		return
	goto("title")


func goto(name: String, params: Dictionary = {}) -> void:
	if busy:
		return
	busy = true
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	await tw.finished
	if is_instance_valid(screen):
		screen.queue_free()
		await get_tree().process_frame
	clear_toasts_if_needed()
	screen = load(SCREENS[name]).new()
	screen_name = name
	if screen.has_method("setup"):
		screen.setup(params)
	add_child(screen)
	move_child(screen, 0)
	var tw2 = create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.3)
	await tw2.finished
	busy = false


func clear_toasts_if_needed() -> void:
	pass


# 会話（ストーリー・スキット・焚火会話）を再生する。終わると on_done を呼ぶ。
func play_dialogue(data: Dictionary, on_done: Callable = Callable()) -> Node:
	# 会話中は画面のボタンにフォーカスを残さない（決定キーが二重に効くのを防ぐ）
	get_viewport().gui_release_focus()
	var d: Node = load("res://scripts/ui/dialogue.gd").new()
	d.setup(data)
	overlay.add_child(d)
	if on_done.is_valid():
		d.finished.connect(on_done)
	return d


func play_story(id: String, on_done: Callable = Callable()) -> void:
	if not DB.Story.DATA.has(id):
		if on_done.is_valid():
			on_done.call()
		return
	Game.flags["story_" + id] = true
	var data: Dictionary = DB.Story.DATA[id].duplicate()
	data["mode"] = "story"
	play_dialogue(data, on_done)


func _on_notified(text: String, kind: String) -> void:
	if Game.quiet:
		return
	toast(text, kind)


func toast(text: String, kind: String = "info") -> void:
	var col = UI.C_TEXT
	match kind:
		"title":
			col = UI.C_GOLD
			Sfx.play("levelup", 1.2, -4)
		"buff":
			col = UI.C_BLUE
		"join":
			col = UI.C_GREEN
			Sfx.play("levelup")
		"skit":
			col = Color(1.0, 0.75, 0.9)
	var p = UI.panel(Color(0.05, 0.05, 0.1, 0.9), col)
	var l = UI.label(text, 18, col)
	p.add_child(l)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
