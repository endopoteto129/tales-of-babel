# 戦闘背景。層ごとに描き分ける。遠景には常に「次層へのエレベーター」を置く。
extends Node2D

var deco := "grass"
var boss := false
var t := 0.0
var rnd: Array = []


func _ready() -> void:
	var r = RandomNumberGenerator.new()
	r.seed = hash(deco) + Game.floor_num
	for i in range(64):
		rnd.append(Vector3(r.randf(), r.randf(), r.randf()))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var fd: Dictionary = DB.floor_data(Game.floor_num)
	var top: Color = fd["bg_top"]
	var bot: Color = fd["bg_bottom"]
	var gr: Color = fd["ground"]
	if boss:
		top = top.lerp(Color(0.25, 0.05, 0.08), 0.35)
	for i in range(30):
		draw_rect(Rect2(-40, i * 21 - 20, 1360, 22), top.lerp(bot, i / 29.0))
	_elevator(fd["accent"])
	match deco:
		"grass":
			for i in range(6):
				var cx = fmod(rnd[i].x * 1400.0 + t * (6 + i * 2), 1500.0) - 100
				_cloud(Vector2(cx, 60 + rnd[i].y * 160), 40 + rnd[i].z * 50, Color(1, 1, 1, 0.75))
			_hills(Color(0.42, 0.62, 0.38), 470, 60, 0.004)
			_hills(Color(0.35, 0.55, 0.32), 520, 40, 0.007)
		"town":
			for i in range(9):
				var x = i * 150 + rnd[i].x * 40
				var hh = 140 + rnd[i].y * 160
				draw_rect(Rect2(x, 600 - hh, 110, hh), Color(0.3, 0.22, 0.3))
				UI.poly(self, PackedVector2Array([Vector2(x - 10, 600 - hh), Vector2(x + 55, 600 - hh - 50), Vector2(x + 120, 600 - hh)]), Color(0.45, 0.25, 0.3))
				for j in range(3):
					var lit = 0.6 + sin(t * 2 + i + j) * 0.2
					draw_rect(Rect2(x + 15 + j * 30, 620 - hh + 30, 16, 22), Color(1.0, 0.8, 0.4, lit))
			draw_rect(Rect2(-40, 300, 1360, 30), Color(0.2, 0.16, 0.2))
			for i in range(14):
				draw_rect(Rect2(i * 100, 280, 50, 24), Color(0.2, 0.16, 0.2))
			for i in range(5):
				var lx = 100 + i * 260
				draw_line(Vector2(lx, 600), Vector2(lx, 470), Color(0.15, 0.1, 0.12), 4)
				draw_circle(Vector2(lx, 466), 10 + sin(t * 4 + i) * 1.5, Color(1.0, 0.7, 0.3, 0.9))
		"bamboo":
			draw_circle(Vector2(980, 150), 70, Color(1.0, 0.97, 0.85))
			draw_circle(Vector2(980, 150), 95, Color(1.0, 0.97, 0.85, 0.12))
			for i in range(26):
				var x2 = rnd[i].x * 1300
				var col = Color(0.15, 0.3 + rnd[i].y * 0.2, 0.2, 0.9) if i % 2 == 0 else Color(0.1, 0.22, 0.15)
				var sway = sin(t * 0.8 + i) * 3.0
				draw_line(Vector2(x2, 610), Vector2(x2 + sway, -20), col, 10 + rnd[i].z * 10)
				for j in range(6):
					draw_line(Vector2(x2 - 8, 600 - j * 110), Vector2(x2 + 8, 600 - j * 110), col.darkened(0.3), 3)
			for i in range(14):
				var ph = fmod(t * 0.3 + rnd[i].z, 1.0)
				draw_circle(Vector2(rnd[i].x * 1280 + sin(t + i) * 30, ph * 600), 2, Color(0.8, 1.0, 0.6, 0.5 * (1 - ph)))
		"colosseum":
			for row in range(3):
				var y = 260 + row * 70
				draw_rect(Rect2(-40, y, 1360, 60), Color(0.62, 0.48, 0.34).darkened(row * 0.1))
				for i in range(16):
					var ax = i * 90 + (row % 2) * 45
					draw_rect(Rect2(ax, y + 10, 50, 50), Color(0.35, 0.25, 0.18))
					draw_circle(Vector2(ax + 25, y + 12), 25, Color(0.35, 0.25, 0.18))
			for i in range(30):
				draw_circle(Vector2(rnd[i].x * 1280, 250 - rnd[i].y * 40), 6, Color(0.2, 0.15, 0.12, 0.5))
			draw_rect(Rect2(-40, 470, 1360, 12), Color(0.5, 0.36, 0.24))
		"library":
			for i in range(8):
				var bx = i * 170
				draw_rect(Rect2(bx, 120, 150, 480), Color(0.25, 0.15, 0.12))
				for sy in range(6):
					for bk in range(8):
						var c = Color.from_hsv(rnd[(i * 8 + bk) % 64].x, 0.5, 0.5)
						draw_rect(Rect2(bx + 8 + bk * 17, 140 + sy * 75, 14, 60 - (bk % 3) * 8), c)
			for i in range(40):
				var tw = 0.5 + sin(t * 3 + i) * 0.5
				draw_circle(Vector2(rnd[i].x * 1280, rnd[i].y * 120), 1.5 + rnd[i].z, Color(1, 1, 0.9, tw))
			for i in range(5):
				var p = Vector2(fmod(rnd[i].x * 1280 + t * 20 * (i + 1), 1300), 200 + rnd[i].y * 200 + sin(t + i) * 20)
				draw_rect(Rect2(p, Vector2(30, 20)), Color(0.8, 0.75, 0.6, 0.6))
		"factory":
			for i in range(5):
				var gc = Vector2(150 + i * 260, 250 + rnd[i].y * 150)
				var rr = 60 + rnd[i].x * 60
				var rot = t * (0.5 if i % 2 == 0 else -0.5)
				for k in range(10):
					var a = rot + TAU * k / 10
					draw_rect(Rect2(gc + Vector2(cos(a), sin(a)) * rr - Vector2(10, 10), Vector2(20, 20)), Color(0.35, 0.26, 0.15))
				draw_circle(gc, rr, Color(0.4, 0.3, 0.17))
				draw_circle(gc, rr * 0.3, Color(0.25, 0.18, 0.1))
			for i in range(4):
				draw_rect(Rect2(-40, 120 + i * 110, 1360, 14), Color(0.3, 0.22, 0.14))
			for i in range(8):
				var ph2 = fmod(t * 0.5 + rnd[i].z, 1.0)
				draw_circle(Vector2(rnd[i].x * 1280, 600 - ph2 * 500), 20 * ph2 + 5, Color(0.8, 0.8, 0.8, 0.15 * (1 - ph2)))
		"summit":
			for i in range(8):
				var cx2 = fmod(rnd[i].x * 1400.0 + t * (10 + i * 3), 1500.0) - 100
				_cloud(Vector2(cx2, 380 + rnd[i].y * 160), 60 + rnd[i].z * 60, Color(1, 1, 1, 0.8))
			# 神の座
			var th = Vector2(640, 300)
			draw_rect(Rect2(th + Vector2(-60, -10), Vector2(120, 160)), Color(0.95, 0.92, 0.85, 0.7))
			draw_rect(Rect2(th + Vector2(-80, -120), Vector2(160, 120)), Color(0.95, 0.92, 0.85, 0.5))
			draw_circle(th + Vector2(0, -130), 50 + sin(t * 2) * 4, Color(1.0, 0.95, 0.6, 0.25))
	# 地面
	draw_rect(Rect2(-40, 600, 1360, 160), gr)
	draw_rect(Rect2(-40, 600, 1360, 6), gr.lightened(0.25))
	for i in range(20):
		var gx = rnd[i].x * 1300
		draw_line(Vector2(gx, 612 + rnd[i].y * 20), Vector2(gx + 30, 612 + rnd[i].y * 20), gr.darkened(0.2), 2)


func _elevator(acc: Color) -> void:
	# 遠くに見える上層へのエレベーター
	var x = 1120.0
	draw_rect(Rect2(x - 18, -20, 36, 520), Color(acc.r, acc.g, acc.b, 0.12))
	draw_rect(Rect2(x - 4, -20, 8, 520), Color(acc.r, acc.g, acc.b, 0.25))
	var y = fmod(t * 40.0, 520.0)
	draw_rect(Rect2(x - 14, 480 - y, 28, 20), Color(acc.r, acc.g, acc.b, 0.5))


func _cloud(p: Vector2, s: float, c: Color) -> void:
	draw_circle(p, s * 0.5, c)
	draw_circle(p + Vector2(s * 0.45, 6), s * 0.38, c)
	draw_circle(p + Vector2(-s * 0.45, 8), s * 0.35, c)


func _hills(c: Color, base: float, amp: float, freq: float) -> void:
	var pts = PackedVector2Array()
	pts.append(Vector2(-40, 620))
	for i in range(0, 1361, 40):
		pts.append(Vector2(i - 40, base - sin(i * freq * 3.0 + base) * amp - amp))
	pts.append(Vector2(1320, 620))
	UI.poly(self, pts, c)
