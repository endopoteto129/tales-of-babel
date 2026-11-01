# 飛び道具（魔神剣・銃弾・魔弾など）
class_name Projectile
extends Node2D

var battle: Node
var owner_f: Fighter
var spec: Dictionary
var ps: Dictionary
var power := 1.0
var vel := Vector2.ZERO
var life := 1.0
var t := 0.0
var hits: Dictionary = {}
var pierce := false
var multi := 1
var color := Color.WHITE
var shape := "orb"
var size := Vector2(20, 20)
var homing: Fighter
var done := false
var team := 0


func setup(b: Node, f: Fighter, s: Dictionary, pw: float) -> void:
	battle = b
	owner_f = f
	spec = s
	ps = s["projectile"]
	power = pw
	team = f.team
	shape = ps.get("shape", "orb")
	size = Vector2(ps.get("w", 20), ps.get("h", 20))
	life = ps.get("life", 1.0)
	pierce = ps.get("pierce", false)
	multi = ps.get("multi", 1)
	color = s.get("color", Color(1, 0.9, 0.6) if f.team == 0 else Color(1, 0.4, 0.5))
	if f.team == 1 and not s.has("color"):
		color = Color(0.9, 0.4, 1.0) if s.get("magic", false) else Color(1.0, 0.6, 0.3)
	var spd: float = ps.get("speed", 500)
	var start = f.center() + Vector2(f.facing * (f.body.x / 2.0 + 10), 0)
	if shape == "wave":
		start.y = f.ground_y() - size.y / 2.0 - f.h
		if f.h > 20:
			start.y = f.center().y
	position = start
	vel = Vector2(f.facing * spd, 0)
	var tgt: Fighter = battle.player_target if (f.is_player and battle.player_target) else (battle.nearest_enemy(f) if f.team == 0 else f.target)
	if tgt and tgt.alive():
		var to = tgt.center() - start
		if abs(to.x) > 10 and sign(to.x) == f.facing and shape != "wave":
			vel = to.normalized() * spd
			if abs(vel.y) > abs(vel.x) * 0.6:
				vel = Vector2(f.facing * spd * 0.85, sign(to.y) * spd * 0.5)
	if ps.get("homing", false):
		homing = tgt


func tick(dt: float) -> void:
	if done:
		return
	t += dt
	if homing and homing.alive():
		var to = (homing.center() - position).normalized() * vel.length()
		vel = vel.lerp(to, min(1.0, dt * 2.5))
	position += vel * dt
	if t >= life or position.x < battle.LEFT - 60 or position.x > battle.RIGHT + 60:
		done = true
		queue_free()
		return
	var r = Rect2(position - size / 2.0, size)
	for f in battle.opponents_of_team(team):
		if not f.alive() or f.invul > 0.0:
			continue
		if not r.intersects(f.body_rect()):
			continue
		var rec: Array = hits.get(f, [0, -10.0])
		if rec[0] >= multi or t - rec[1] < 0.09:
			continue
		rec[0] += 1
		rec[1] = t
		hits[f] = rec
		battle.apply_hit(owner_f, f, spec, power, true, int(sign(vel.x)))
		if not pierce:
			battle.spawn_fx("spark", position, color)
			done = true
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var c = color
	var dir = 1.0 if vel.x >= 0 else -1.0
	match shape:
		"wave":
			var pts = PackedVector2Array()
			for i in range(9):
				var a = -PI / 2 + PI * i / 8.0
				pts.append(Vector2(cos(a) * size.x * 0.5 * dir, sin(a) * size.y * 0.5))
			for i in range(9):
				var a2 = PI / 2 - PI * i / 8.0
				pts.append(Vector2(cos(a2) * size.x * 0.2 * dir - size.x * 0.15 * dir, sin(a2) * size.y * 0.45))
			UI.poly(self, pts, Color(c.r, c.g, c.b, 0.85))
			draw_line(Vector2(-size.x * 1.2 * dir, size.y * 0.4), Vector2(0, size.y * 0.4), Color(c.r, c.g, c.b, 0.4), 4.0)
		"orb":
			draw_circle(Vector2.ZERO, size.x * 0.75, Color(c.r, c.g, c.b, 0.25))
			draw_circle(Vector2.ZERO, size.x * 0.5, c)
			draw_circle(Vector2.ZERO, size.x * 0.25, Color(1, 1, 1, 0.9))
			draw_line(Vector2.ZERO, -vel.normalized() * size.x * 1.4, Color(c.r, c.g, c.b, 0.4), size.x * 0.5)
		"bullet":
			draw_line(-vel.normalized() * size.x * 1.6, Vector2.ZERO, Color(c.r, c.g, c.b, 0.5), size.y * 0.5)
			draw_line(-vel.normalized() * size.x * 0.5, Vector2.ZERO, Color(1, 1, 0.85), size.y * 0.6)
		"lance":
			var n = vel.normalized()
			draw_line(-n * size.x / 2, n * size.x / 2, Color(c.r, c.g, c.b, 0.5), size.y)
			draw_line(-n * size.x / 2, n * size.x / 2, Color(1, 1, 1, 0.9), size.y * 0.35)
		"rock":
			draw_set_transform(Vector2.ZERO, t * 8.0)
			draw_rect(Rect2(-size / 2, size), Color(0.5, 0.42, 0.35))
			draw_rect(Rect2(-size / 4, size / 2), Color(0.62, 0.55, 0.45))
			draw_set_transform(Vector2.ZERO)
		"gear":
			draw_set_transform(Vector2.ZERO, t * 10.0)
			for i in range(6):
				var a3 = TAU * i / 6.0
				draw_rect(Rect2(Vector2(cos(a3), sin(a3)) * size.x * 0.45 - Vector2(5, 5), Vector2(10, 10)), Color(0.7, 0.6, 0.3))
			draw_circle(Vector2.ZERO, size.x * 0.4, Color(0.8, 0.7, 0.4))
			draw_circle(Vector2.ZERO, size.x * 0.15, Color(0.3, 0.25, 0.2))
			draw_set_transform(Vector2.ZERO)
		_:
			draw_circle(Vector2.ZERO, size.x / 2, c)
