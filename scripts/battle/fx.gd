# 短命なエフェクト（ヒットスパーク・回復・ブレイクなど）
class_name Fx
extends Node2D

var kind := "spark"
var color := Color.WHITE
var t := 0.0
var life := 0.3
var rnd: Array = []
var scale_k := 1.0


func setup(k: String, pos: Vector2, c: Color, s: float = 1.0) -> void:
	kind = k
	position = pos
	color = c
	scale_k = s
	match k:
		"spark":
			life = 0.22
		"crit":
			life = 0.35
		"heal":
			life = 0.9
		"break":
			life = 0.6
		"ring":
			life = 0.5
		"guard":
			life = 0.25
		"dust":
			life = 0.4
		"buff":
			life = 0.9
	for i in range(12):
		rnd.append(Vector2(randf(), randf()))


func tick(dt: float) -> void:
	t += dt
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k = t / life
	var a = 1.0 - k
	var c = Color(color.r, color.g, color.b, a)
	match kind:
		"spark", "crit":
			var n = 8 if kind == "spark" else 12
			var r = (20.0 + k * 40.0) * scale_k
			for i in range(n):
				var ang = TAU * i / n + rnd[i].x
				var l: float = r * (0.6 + rnd[i].y * 0.6)
				draw_line(Vector2(cos(ang), sin(ang)) * l * 0.3, Vector2(cos(ang), sin(ang)) * l, c, 3.0 * scale_k)
			draw_circle(Vector2.ZERO, 14 * (1.0 - k) * scale_k, Color(1, 1, 1, a))
			if kind == "crit":
				draw_arc(Vector2.ZERO, r * 1.2, 0, TAU, 24, c, 4.0)
		"heal":
			for i in range(10):
				var p = Vector2((rnd[i].x - 0.5) * 60, -k * 90 * (0.5 + rnd[i].y))
				draw_circle(p, 4 + rnd[i].y * 3, c)
			draw_arc(Vector2(0, 10), 30 + k * 20, 0, TAU, 24, Color(c.r, c.g, c.b, a * 0.6), 3.0)
		"buff":
			for i in range(8):
				var p2 = Vector2((rnd[i].x - 0.5) * 50, 20 - k * 100 * (0.5 + rnd[i].y))
				draw_line(p2, p2 + Vector2(0, -12), c, 3.0)
		"break":
			var r2 = 30 + k * 120
			draw_arc(Vector2.ZERO, r2, 0, TAU, 32, c, 8.0 * a)
			for i in range(10):
				var ang2 = TAU * i / 10.0
				draw_rect(Rect2(Vector2(cos(ang2), sin(ang2)) * r2 * 0.8 - Vector2(4, 4), Vector2(8, 8)), c)
		"ring":
			draw_arc(Vector2.ZERO, (20 + k * 80) * scale_k, 0, TAU, 32, c, 5.0 * a)
		"guard":
			draw_arc(Vector2.ZERO, 30 + k * 20, -1.0, 1.0, 12, c, 6.0)
		"dust":
			for i in range(6):
				draw_circle(Vector2((rnd[i].x - 0.5) * 60 * (0.5 + k), -k * 20 * rnd[i].y), 6 * a, Color(0.8, 0.75, 0.7, a * 0.5))
