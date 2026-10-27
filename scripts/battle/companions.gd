# 戦闘に参加しない仲間：後方で応援するナインと、レンに付き従うポッツ
extends Node2D

var battle: Node
var nine_visible := true
var pots_visible := true
var t := 0.0
var cheer_t := 0.0
var pots_p := Vector2(300, 420)
var nine_x := 70.0


func _ready() -> void:
	nine_visible = not Game.flags.get("nine_absent", false)
	pots_visible = not Game.flags.get("pots_absent", false)


func tick(dt: float) -> void:
	t += dt
	cheer_t = max(0.0, cheer_t - dt)
	if battle.player:
		var target: Vector2 = battle.player.head() + Vector2(-battle.player.facing * 50, -40 + sin(t * 3.0) * 8)
		pots_p = pots_p.lerp(target, min(1.0, dt * 3.0))
	# 戦闘から離れた後ろに隠れる
	var leftmost = 1e9
	for p in battle.party:
		leftmost = min(leftmost, p.x)
	nine_x = lerp(nine_x, clamp(leftmost - 120.0, 50.0, 200.0), min(1.0, dt * 1.5))
	queue_redraw()


func cheer() -> void:
	cheer_t = 1.0
	Sfx.play("chat", 1.5, -8)


func nine_pos() -> Vector2:
	return Vector2(nine_x, battle.GROUND_Y)


func pots_pos() -> Vector2:
	return pots_p


func _draw() -> void:
	if nine_visible:
		_draw_nine()
	if pots_visible:
		_draw_pots()


func _draw_nine() -> void:
	var base = nine_pos()
	var jump = 0.0
	if cheer_t > 0.0:
		jump = abs(sin(cheer_t * 12.0)) * 22.0
	var p = base + Vector2(0, -jump)
	var skin = Color(1.0, 0.86, 0.74)
	var hair = Color(0.95, 0.85, 0.6)
	draw_circle(base + Vector2(0, 2), 16, Color(0, 0, 0, 0.25))
	draw_line(p + Vector2(-4, -26), p + Vector2(-5, 0), Color(0.3, 0.25, 0.25), 6)
	draw_line(p + Vector2(4, -26), p + Vector2(5, 0), Color(0.3, 0.25, 0.25), 6)
	UI.poly(self, PackedVector2Array([p + Vector2(-14, -24), p + Vector2(-9, -52), p + Vector2(9, -52), p + Vector2(14, -24)]), Color(1.0, 0.62, 0.3))
	var hc = p + Vector2(0, -64)
	draw_circle(hc + Vector2(-14, 4), 8, hair)
	draw_circle(hc + Vector2(14, 4), 8, hair)
	draw_circle(hc, 13, skin)
	draw_circle(hc + Vector2(0, -5), 12, hair)
	draw_circle(hc + Vector2(2, 2), 9, skin)
	draw_arc(hc + Vector2(-3, 3), 3, PI * 1.1, PI * 1.9, 6, Color(0.2, 0.1, 0.1), 2)
	draw_arc(hc + Vector2(6, 3), 3, PI * 1.1, PI * 1.9, 6, Color(0.2, 0.1, 0.1), 2)
	draw_circle(hc + Vector2(-10, -12), 3.5, Color(1, 0.35, 0.3))
	draw_circle(hc + Vector2(10, -12), 3.5, Color(1, 0.35, 0.3))
	var wave = sin(t * (14.0 if cheer_t > 0 else 4.0)) * 0.6
	var sh = p + Vector2(8, -48)
	draw_line(sh, sh + Vector2(cos(-1.2 + wave), sin(-1.2 + wave)) * 20, skin, 5)
	draw_line(p + Vector2(-8, -48), p + Vector2(-18, -36), skin, 5)
	if cheer_t > 0.0:
		for i in range(5):
			var a = t * 4.0 + TAU * i / 5.0
			draw_string(UI.FONT_BOLD, hc + Vector2(cos(a), sin(a)) * 34 - Vector2(6, -6), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.3, cheer_t))


func _draw_pots() -> void:
	var c = pots_p
	draw_circle(c, 15, Color(0.35, 0.5, 0.6))
	draw_circle(c, 13, Color(0.55, 0.75, 0.85))
	draw_rect(Rect2(c + Vector2(-10, -4), Vector2(20, 8)), Color(0.1, 0.12, 0.16))
	var blink = fmod(t, 3.0) < 0.1
	if not blink:
		draw_rect(Rect2(c + Vector2(-7, -2), Vector2(5, 4)), Color(0.3, 1.0, 0.9))
		draw_rect(Rect2(c + Vector2(2, -2), Vector2(5, 4)), Color(0.3, 1.0, 0.9))
	draw_line(c + Vector2(0, -15), c + Vector2(0, -22), Color(0.35, 0.5, 0.6), 2)
	draw_circle(c + Vector2(0, -23), 2.5, Color(0.3, 1.0, 0.9))
	draw_circle(c + Vector2(0, 20), 5 + sin(t * 8.0), Color(0.3, 1.0, 0.9, 0.3))
