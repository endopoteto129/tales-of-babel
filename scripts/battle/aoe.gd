# 範囲攻撃（術・敵の大技）。発動までの間は予告範囲を表示する。
class_name AoE
extends Node2D

var battle: Node
var owner_f: Fighter
var spec: Dictionary
var asp: Dictionary
var power := 1.0
var cx := 0.0
var w := 100.0
var hgt := 100.0
var delay := 0.3
var hits := 1
var interval := 0.1
var shape := "burst"
var color := Color.WHITE
var t := 0.0
var pulses := 0
var team := 0
var done := false
var rnd: Array = []
var heal_mode := false


func setup(b: Node, f: Fighter, s: Dictionary, x: float, pw: float) -> void:
	battle = b
	owner_f = f
	spec = s
	asp = s["aoe"]
	power = pw
	team = f.team
	w = asp.get("w", 100)
	hgt = asp.get("h", 100)
	delay = asp.get("delay", 0.3)
	hits = asp.get("hits", 1)
	interval = asp.get("interval", 0.1)
	shape = asp.get("shape", "burst")
	color = s.get("color", Color(1, 0.5, 0.4) if team == 1 else Color(1, 0.9, 0.6))
	if team == 1 and not s.has("color"):
		color = Color(0.85, 0.35, 1.0) if s.get("magic_attack", false) else Color(1.0, 0.45, 0.25)
	cx = x
	if asp.get("at_self", false):
		cx = (battle.LEFT + battle.RIGHT) / 2.0
		w = battle.RIGHT - battle.LEFT + 100
	position = Vector2(cx, battle.GROUND_Y)
	for i in range(16):
		rnd.append(Vector2(randf(), randf()))
	if hits > 1 or shape in ["burst", "pillar", "meteor"]:
		pass


func tick(dt: float) -> void:
	if done:
		return
	t += dt
	while pulses < hits and t >= delay + pulses * interval:
		_pulse()
		pulses += 1
	if t >= delay + hits * interval + 0.45:
		done = true
		queue_free()
		return
	queue_redraw()


func _pulse() -> void:
	if pulses == 0:
		match shape:
			"burst", "meteor":
				Sfx.play("explode", 1.0, -2)
				battle.shake(0.35 if team == 0 else 0.5)
			"quake":
				Sfx.play("hit_heavy", 0.6)
				battle.shake(0.9)
			"wave":
				Sfx.play("explode", 0.6)
				battle.shake(0.8)
				battle.flash(Color(1, 1, 1, 0.5))
			_:
				Sfx.play("magic", 1.0, -4)
	elif shape in ["pillar", "storm", "spikes"]:
		Sfx.play("hit", 1.3, -10)
	var r = Rect2(cx - w / 2.0, battle.GROUND_Y - hgt, w, hgt)
	for f in battle.opponents_of_team(team):
		if not f.alive() or f.invul > 0.0:
			continue
		if shape == "quake" and f.h > 12.0:
			continue
		if r.intersects(f.body_rect()):
			var d = int(sign(f.x - cx))
			if d == 0:
				d = 1
			battle.apply_hit(owner_f, f, spec, power, true, d)


func _draw() -> void:
	var k = 0.0
	if t < delay:
		# 予告
		var p = t / max(0.01, delay)
		var wc = Color(1, 0.15, 0.1, 0.18 + 0.12 * sin(t * 30.0)) if team == 1 else Color(color.r, color.g, color.b, 0.15)
		if shape == "quake":
			draw_rect(Rect2(-w / 2, -14, w, 14), wc)
		elif shape != "wave" and shape != "meteor":
			draw_rect(Rect2(-w / 2, -hgt, w, hgt), Color(wc.r, wc.g, wc.b, wc.a * 0.6))
			draw_rect(Rect2(-w / 2, -8, w * p, 8), Color(wc.r, wc.g, wc.b, 0.6))
		return
	k = (t - delay) / max(0.01, hits * interval + 0.45)
	var a: float = clamp(1.0 - k, 0.0, 1.0)
	var c = Color(color.r, color.g, color.b, a)
	match shape:
		"pillar":
			for i in range(5):
				var xx: float = -w / 2 + w * rnd[i].x
				var ww: float = 14 + rnd[i].y * 22
				draw_rect(Rect2(xx - ww / 2, -hgt, ww, hgt), Color(c.r, c.g, c.b, a * 0.5))
				draw_line(Vector2(xx, -hgt), Vector2(xx, 0), Color(1, 1, 1, a), 3.0)
			draw_circle(Vector2(0, -6), w * 0.4, Color(c.r, c.g, c.b, a * 0.25))
		"burst":
			var r: float = min(w, hgt) * (0.4 + k * 0.8)
			draw_circle(Vector2(0, -hgt * 0.4), r, Color(c.r, c.g, c.b, a * 0.55))
			draw_circle(Vector2(0, -hgt * 0.4), r * 0.6, Color(1, 1, 0.9, a * 0.7))
			for i in range(10):
				var ang = TAU * i / 10.0 + rnd[i].x
				draw_line(Vector2(0, -hgt * 0.4), Vector2(0, -hgt * 0.4) + Vector2(cos(ang), sin(ang)) * r * 1.4, Color(c.r, c.g, c.b, a), 3.0)
		"spikes":
			for i in range(7):
				var xx2: float = -w / 2 + w * (i + 0.5) / 7.0
				var hh: float = hgt * (0.5 + rnd[i].x * 0.5) * min(1.0, k * 6.0)
				UI.poly(self, PackedVector2Array([Vector2(xx2 - 12, 0), Vector2(xx2 + 12, 0), Vector2(xx2 + rnd[i].y * 6, -hh)]), c)
				draw_line(Vector2(xx2, 0), Vector2(xx2 + rnd[i].y * 6, -hh), Color(1, 1, 1, a * 0.8), 2.0)
		"storm":
			for i in range(8):
				var ang2 = t * 12.0 + TAU * i / 8.0
				var cc = Vector2(0, -hgt * 0.5)
				var rr: float = w * 0.4 * (0.5 + rnd[i].x * 0.5)
				draw_line(cc + Vector2(cos(ang2), sin(ang2) * 0.8) * rr, cc + Vector2(cos(ang2 + 0.8), sin(ang2 + 0.8) * 0.8) * rr, c, 4.0)
		"quake":
			draw_rect(Rect2(-w / 2, -10, w, 10), Color(c.r, c.g, c.b, a * 0.7))
			for i in range(16):
				var xx3: float = -w / 2 + w * rnd[i].x
				draw_line(Vector2(xx3, 0), Vector2(xx3 + 6, -30 - rnd[i].y * 50 * a), Color(c.r, c.g, c.b, a), 4.0)
		"wave":
			var rr2: float = 80 + k * 1400.0
			draw_arc(Vector2(0, -hgt * 0.5), rr2, 0, TAU, 64, c, 18.0 * a + 2)
			draw_arc(Vector2(0, -hgt * 0.5), rr2 * 0.8, 0, TAU, 64, Color(1, 1, 1, a * 0.6), 6.0)
		"meteor":
			for i in range(10):
				var fall: float = clamp(k * 3.0 - rnd[i].y, 0.0, 1.0)
				var xx4: float = -w / 2 + w * rnd[i].x
				var p2 = Vector2(xx4 - 200 + fall * 200, -700 + fall * 700)
				draw_circle(p2, 18, c)
				draw_line(p2, p2 + Vector2(-60, -120), Color(c.r, c.g, c.b, a * 0.4), 10.0)
		_:
			draw_circle(Vector2(0, -hgt / 2), w / 2, c)
