# 立ち絵（バストアップ）を図形で描くコントロール。
# 素材なしでもキャラが識別できるよう、髪型・小物・表情をキャラごとに描き分ける。
class_name Portrait
extends Control

var cid := ""
var expr := ""
var flip := false
var dim := false
var bob := 0.0
var _t := 0.0
static var _tex_cache: Dictionary = {}


func setup(id: String, expression: String = "", flipped: bool = false) -> void:
	cid = id
	expr = expression
	flip = flipped
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if cid == "" or not DB.Characters.DATA.has(cid):
		return
	var tex := _image()
	if tex:
		# 立ち絵画像があれば、それを足元合わせで描く（無ければ下の図形で描く）
		var k: float = min(size.x / tex.get_width(), size.y / tex.get_height())
		var sz: Vector2 = tex.get_size() * k
		var pos := Vector2((size.x - sz.x) / 2.0, size.y - sz.y + sin(_t * 2.0) * 1.5 + bob)
		if flip:
			# 幅をマイナスにすると左右反転で描ける
			pos.x += sz.x
			sz.x = -sz.x
		draw_texture_rect(tex, Rect2(pos, sz), false)
		return
	var c: Dictionary = DB.chara(cid)
	var s: float = min(size.x / 220.0, size.y / 260.0)
	var breathe = sin(_t * 2.0) * 1.5 + bob
	draw_set_transform(Vector2(size.x / 2.0, size.y + breathe), 0.0, Vector2(-s if flip else s, s))
	var col: Color = c["color"]
	var acc: Color = c["accent"]
	var hair: Color = c["hair"]
	var skin = Color(1.0, 0.86, 0.74)
	if cid == "pots":
		_draw_pots(col, acc)
	else:
		_draw_back_hair(hair)
		_draw_body(col, acc, skin)
		_draw_head(hair, skin)
		_draw_face(skin)
		_draw_extras(col, acc, hair)
	_draw_expr_marks()
	draw_set_transform(Vector2.ZERO)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.0))


# assets/portraits/<キャラID>/<表情>.png。表情の画像が無ければ normal.png を使う
func _image() -> Texture2D:
	var key := cid + "/" + expr
	if not _tex_cache.has(key):
		var tex: Texture2D = null
		for e in [expr if expr != "" else "normal", "normal"]:
			var path := "res://assets/portraits/%s/%s.png" % [cid, e]
			if ResourceLoader.exists(path):
				tex = load(path)
				break
		_tex_cache[key] = tex
	return _tex_cache[key]


func _darker(c: Color, f: float = 0.7) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


func _draw_body(col: Color, acc: Color, skin: Color) -> void:
	var w = 92.0
	if cid == "john":
		w = 118.0
	elif cid == "nine" or cid == "sister":
		w = 70.0
	var top = -96.0 if cid != "nine" and cid != "sister" else -84.0
	# 首
	draw_rect(Rect2(-12, top - 18, 24, 22), _darker(skin, 0.9))
	# 胴体
	var pts = PackedVector2Array([Vector2(-w, 0), Vector2(-w + 14, top + 6), Vector2(-28, top - 4), Vector2(28, top - 4), Vector2(w - 14, top + 6), Vector2(w, 0)])
	var body_col = col
	if cid == "maria":
		body_col = Color(0.95, 0.95, 0.97)
	UI.poly(self, pts, body_col)
	draw_polyline(pts, _darker(body_col, 0.55), 3.0)
	# 襟・服の差し色
	match cid:
		"ren":
			UI.poly(self, PackedVector2Array([Vector2(-30, top - 4), Vector2(0, top + 30), Vector2(30, top - 4), Vector2(20, top - 14), Vector2(0, top + 12), Vector2(-20, top - 14)]), Color(0.75, 0.1, 0.12))
			draw_line(Vector2(-w + 20, top + 30), Vector2(w - 30, -10), Color(0.35, 0.25, 0.2), 8.0)
			draw_circle(Vector2(-50, top + 30), 7, Color(0.9, 0.8, 0.3))
		"nine":
			UI.poly(self, PackedVector2Array([Vector2(-26, top - 2), Vector2(0, top + 18), Vector2(26, top - 2)]), acc)
			draw_circle(Vector2(0, top + 18), 6, Color(1.0, 0.35, 0.3))
		"angie":
			UI.poly(self, PackedVector2Array([Vector2(-34, top - 2), Vector2(0, top + 44), Vector2(34, top - 2)]), _darker(col, 0.6))
			draw_circle(Vector2(0, top + 22), 6, Color(1.0, 0.85, 0.3))
		"sona":
			draw_rect(Rect2(-w + 18, top + 20, 2 * w - 36, 10), Color(0.25, 0.2, 0.15))
			draw_rect(Rect2(20, top + 30, 26, 22), Color(0.3, 0.25, 0.2))
		"jin":
			UI.poly(self, PackedVector2Array([Vector2(-30, top - 4), Vector2(12, top + 70), Vector2(22, top + 60), Vector2(-12, top - 4)]), acc)
			UI.poly(self, PackedVector2Array([Vector2(30, top - 4), Vector2(-4, top + 50), Vector2(6, top + 58), Vector2(40, top)]), Color(0.9, 0.9, 0.9))
		"john":
			UI.poly(self, PackedVector2Array([Vector2(-w, 0), Vector2(-w + 14, top + 6), Vector2(-50, top), Vector2(-40, 0)]), skin)
			draw_line(Vector2(-60, top + 10), Vector2(40, -10), Color(0.4, 0.28, 0.16), 10.0)
		"maria":
			UI.poly(self, PackedVector2Array([Vector2(-28, top - 4), Vector2(0, top + 40), Vector2(28, top - 4)]), Color(0.35, 0.45, 0.7))
			draw_line(Vector2(0, top + 40), Vector2(0, 0), Color(0.7, 0.7, 0.75), 3.0)
		"shasta":
			UI.poly(self, PackedVector2Array([Vector2(-w, 0), Vector2(-w + 10, top + 10), Vector2(-20, top + 20), Vector2(-30, 0)]), acc)
			UI.poly(self, PackedVector2Array([Vector2(w, 0), Vector2(w - 10, top + 10), Vector2(20, top + 20), Vector2(30, 0)]), acc)
			draw_circle(Vector2(0, top + 24), 8, Color(0.9, 0.2, 0.3))
		"zone":
			UI.poly(self, PackedVector2Array([Vector2(-34, top - 6), Vector2(-6, top + 60), Vector2(6, top + 60), Vector2(34, top - 6), Vector2(0, top + 10)]), Color(0.15, 0.15, 0.15))
		"val":
			UI.poly(self, PackedVector2Array([Vector2(-w + 10, 0), Vector2(-40, top - 10), Vector2(40, top - 10), Vector2(w - 10, 0)]), _darker(col, 0.8))
		"nene":
			UI.poly(self, PackedVector2Array([Vector2(-26, top - 2), Vector2(0, top + 26), Vector2(26, top - 2)]), Color(0.2, 0.1, 0.15))
		"kaguya":
			# 十二単風の重ね襟
			for k in range(3):
				var cc = [Color(1.0, 0.85, 0.4), Color(0.95, 0.95, 0.9), Color(0.5, 0.15, 0.3)][k]
				UI.poly(self, PackedVector2Array([Vector2(-34 + k * 6, top - 2), Vector2(0, top + 50 - k * 10), Vector2(34 - k * 6, top - 2)]), cc)
		"soldier":
			draw_rect(Rect2(-w + 14, top + 6, 2 * w - 28, 24), Color(0.6, 0.62, 0.7))


func _head_r() -> float:
	if cid == "nine" or cid == "sister":
		return 46.0
	if cid == "john":
		return 50.0
	return 48.0


# 顔の中心（このコントロール内の座標）。吹き出しの顔アイコンの切り抜きに使う
func face_point() -> Vector2:
	var tex := _image()
	if tex:
		var k: float = min(size.x / tex.get_width(), size.y / tex.get_height())
		return Vector2(size.x / 2.0, size.y - tex.get_height() * k * 0.78)
	var s: float = min(size.x / 220.0, size.y / 260.0)
	var hc := _head_c() if cid != "pots" else Vector2(0, -130)
	return Vector2(size.x / 2.0, size.y) + hc * s


func _head_c() -> Vector2:
	if cid == "nine" or cid == "sister":
		return Vector2(0, -136)
	return Vector2(0, -150)


func _draw_head(hair: Color, skin: Color) -> void:
	var hc = _head_c()
	var r = _head_r()
	# 後ろ髪（胴より手前に見える部分）
	match cid:
		"nine":
			draw_circle(hc + Vector2(-52, 6), 24, hair)
			draw_circle(hc + Vector2(52, 6), 24, hair)
			UI.poly(self, PackedVector2Array([hc + Vector2(-60, 10), hc + Vector2(-70, 70), hc + Vector2(-44, 60)]), hair)
			UI.poly(self, PackedVector2Array([hc + Vector2(60, 10), hc + Vector2(70, 70), hc + Vector2(44, 60)]), hair)
		"maria":
			# 頭の後ろでまとめたお団子
			draw_circle(hc + Vector2(0, -r - 4), 22, _darker(hair, 0.85))
			draw_arc(hc + Vector2(0, -r - 4), 22, PI * 0.9, PI * 2.1, 12, _darker(hair, 0.65), 2.5)
			draw_line(hc + Vector2(-30, -r - 14), hc + Vector2(28, -r + 4), Color(0.75, 0.55, 0.3), 4.0)
	# 顔
	draw_circle(hc, r, skin)
	# 前髪
	var fringe = PackedVector2Array()
	for i in range(13):
		var a = PI + PI * i / 12.0
		fringe.append(hc + Vector2(cos(a), sin(a)) * (r + 4))
	match cid:
		"ren":
			fringe.append(hc + Vector2(r, -6))
			fringe.append(hc + Vector2(30, -18))
			fringe.append(hc + Vector2(18, -4))
			fringe.append(hc + Vector2(4, -20))
			fringe.append(hc + Vector2(-14, -2))
			fringe.append(hc + Vector2(-26, -20))
			fringe.append(hc + Vector2(-r, 0))
		"jin":
			fringe.append(hc + Vector2(r, -14))
			fringe.append(hc + Vector2(-10, -24))
			fringe.append(hc + Vector2(-r, 10))
		"john":
			fringe.append(hc + Vector2(r, -20))
			fringe.append(hc + Vector2(-r, -20))
		"pots":
			pass
		"angie":
			# 右から左へ流した前髪
			fringe.append(hc + Vector2(r + 2, 2))
			fringe.append(hc + Vector2(r - 10, -14))
			fringe.append(hc + Vector2(16, -20))
			fringe.append(hc + Vector2(-6, -12))
			fringe.append(hc + Vector2(-24, -22))
			fringe.append(hc + Vector2(-r + 2, -8))
			fringe.append(hc + Vector2(-r - 2, 10))
		"maria":
			# 左右に分けた前髪
			fringe.append(hc + Vector2(r + 2, 8))
			fringe.append(hc + Vector2(r - 12, -20))
			fringe.append(hc + Vector2(6, -32))
			fringe.append(hc + Vector2(0, -26))
			fringe.append(hc + Vector2(-6, -32))
			fringe.append(hc + Vector2(-r + 12, -20))
			fringe.append(hc + Vector2(-r - 2, 8))
		_:
			fringe.append(hc + Vector2(r, -4))
			fringe.append(hc + Vector2(20, -22))
			fringe.append(hc + Vector2(0, -14))
			fringe.append(hc + Vector2(-20, -22))
			fringe.append(hc + Vector2(-r, -4))
	UI.poly(self, fringe, hair)
	# 髪型の特徴
	match cid:
		"angie":
			# 肩にかかる、ゆるく波打つ横髪
			for side in [-1, 1]:
				_lock(hc, side, r, 124.0, 22.0, 7.0, hair)
		"maria":
			# 顔の横に垂らした細い後れ毛
			for side in [-1, 1]:
				_lock(hc, side, r, 62.0, 9.0, 3.0, hair)
		"nene", "sister", "kaguya":
			for side in [-1, 1]:
				_lock(hc, side, r, 100.0, 14.0, 3.0, hair)
		"jin":
			draw_circle(hc + Vector2(0, -r - 10), 14, hair)
			draw_rect(Rect2(hc + Vector2(-8, -r - 2), Vector2(16, 6)), Color(0.8, 0.2, 0.2))
		"ren":
			UI.poly(self, PackedVector2Array([hc + Vector2(-r - 2, -6), hc + Vector2(-r - 14, 20), hc + Vector2(-r + 6, 8)]), hair)
		"nine":
			draw_circle(hc + Vector2(-34, -38), 9, Color(1.0, 0.35, 0.3))
			draw_circle(hc + Vector2(34, -38), 9, Color(1.0, 0.35, 0.3))


# 胴より奥に描く後ろ髪。頭の上の丸みから肩の後ろへ流れる形
func _draw_back_hair(hair: Color) -> void:
	var hc = _head_c()
	var r = _head_r()
	var length := 0.0
	var spread := 14.0
	match cid:
		"angie":
			length = 120.0
			spread = 22.0
		"nene", "sister", "kaguya":
			length = 104.0
		"shasta":
			length = 72.0
			spread = 8.0
		"sona":
			length = 56.0
			spread = 6.0
		"maria":
			length = 40.0
			spread = 4.0
		_:
			return
	var col = _darker(hair, 0.82)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = PI * 0.92 + PI * 1.16 * i / 16.0
		pts.append(hc + Vector2(cos(a), sin(a)) * (r + 8))
	# 右側を下りて毛先、左側を上る
	pts.append(hc + Vector2(r + spread, length * 0.35))
	pts.append(hc + Vector2(r + spread + 4, length * 0.7))
	var tips := 5
	for i in range(tips * 2 + 1):
		var x = lerp(r + spread, -r - spread, float(i) / (tips * 2))
		var y = length + (10.0 if i % 2 == 0 else -6.0)
		pts.append(hc + Vector2(x, y))
	pts.append(hc + Vector2(-r - spread - 4, length * 0.7))
	pts.append(hc + Vector2(-r - spread, length * 0.35))
	UI.poly(self, pts, col)


# 顔の横から肩の前へ垂れる髪の束。wave で毛先の揺れ幅を決める
func _lock(hc: Vector2, side: int, r: float, length: float, width: float, wave: float, hair: Color) -> void:
	var outer = PackedVector2Array()
	var inner = PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var k = float(i) / steps
		var y = -14.0 + length * k
		var x = side * (r - 4.0 + sin(k * PI * 2.2) * wave + k * 6.0)
		var w = width * (1.0 - k * 0.85)
		outer.append(hc + Vector2(x + side * w * 0.5, y))
		inner.append(hc + Vector2(x - side * w * 0.5, y))
	inner.reverse()
	var pts = outer
	pts.append_array(inner)
	UI.poly(self, pts, hair)
	draw_polyline(outer, _darker(hair, 0.7), 1.5)


func _draw_face(skin: Color) -> void:
	var hc = _head_c()
	var eye_y = hc.y + 4
	var ex = 18.0
	var eye_col = Color(0.15, 0.12, 0.18)
	if cid == "ren":
		eye_col = Color(0.5, 0.15, 0.15)
	elif cid == "nine":
		eye_col = Color(0.9, 0.45, 0.1)
	elif cid == "angie":
		eye_col = Color(0.6, 0.2, 0.6)
	elif cid == "val":
		eye_col = Color(0.3, 0.8, 0.5)
	var blink = fmod(_t + float(cid.hash() % 7), 4.0) < 0.12
	for side in [-1, 1]:
		var p = Vector2(side * ex, eye_y)
		if cid == "jin" and expr != "surprise" and expr != "serious":
			# 糸目
			draw_arc(p + Vector2(0, 4), 9, PI * 1.1, PI * 1.9, 8, eye_col, 3.0)
		elif blink or expr == "smile" or expr == "laugh":
			draw_arc(p + Vector2(0, 6), 9, PI * 1.1, PI * 1.9, 8, eye_col, 3.0)
		elif expr == "angry":
			draw_circle(p, 7, eye_col)
			draw_line(p + Vector2(-side * 12, -16), p + Vector2(side * 10, -9), Color(0.2, 0.15, 0.15), 4.0)
		elif expr == "sad" or expr == "cry":
			draw_circle(p, 7, eye_col)
			draw_line(p + Vector2(-side * 10, -10), p + Vector2(side * 10, -16), Color(0.2, 0.15, 0.15), 3.0)
		elif expr == "surprise":
			draw_circle(p, 9, Color.WHITE)
			draw_circle(p, 5, eye_col)
		elif expr == "blank":
			# 心が薄れた、光のない目
			draw_circle(p, 8, eye_col.lerp(Color(0.45, 0.45, 0.5), 0.6).darkened(0.3))
		elif expr == "serious" or expr == "cold":
			draw_rect(Rect2(p + Vector2(-9, -3), Vector2(18, 7)), eye_col)
			draw_line(p + Vector2(-10, -12), p + Vector2(10, -11), Color(0.2, 0.15, 0.15), 3.0)
		else:
			draw_circle(p, 8, eye_col)
			draw_circle(p + Vector2(-2, -3), 2.5, Color(1, 1, 1, 0.9))
	# 口
	var m = Vector2(0, hc.y + 26)
	if cid == "nene" or cid == "zone":
		pass
	elif expr == "smile" or expr == "laugh":
		draw_arc(m + Vector2(0, -6), 10, 0.2, PI - 0.2, 10, Color(0.6, 0.25, 0.25), 3.0)
		if expr == "laugh":
			UI.poly(self, PackedVector2Array([m + Vector2(-9, -2), m + Vector2(9, -2), m + Vector2(0, 8)]), Color(0.7, 0.3, 0.3))
	elif expr == "surprise":
		draw_circle(m, 6, Color(0.55, 0.2, 0.2))
	elif expr == "sad" or expr == "cry" or expr == "angry":
		draw_arc(m + Vector2(0, 6), 9, PI + 0.4, TAU - 0.4, 10, Color(0.6, 0.25, 0.25), 3.0)
	else:
		draw_line(m + Vector2(-7, 0), m + Vector2(7, 0), Color(0.6, 0.3, 0.3), 3.0)
	# 頬
	if cid == "nine" or expr == "blush" or cid == "sister":
		draw_circle(Vector2(-28, hc.y + 18), 7, Color(1.0, 0.5, 0.5, 0.45))
		draw_circle(Vector2(28, hc.y + 18), 7, Color(1.0, 0.5, 0.5, 0.45))


func _draw_extras(col: Color, acc: Color, hair: Color) -> void:
	var hc = _head_c()
	var r = _head_r()
	match cid:
		"angie":
			# 魔女帽子
			UI.poly(self, PackedVector2Array([hc + Vector2(-r - 30, -r + 18), hc + Vector2(r + 30, -r + 18), hc + Vector2(r + 10, -r + 4), hc + Vector2(-r - 10, -r + 4)]), _darker(col, 0.6))
			UI.poly(self, PackedVector2Array([hc + Vector2(-r + 4, -r + 6), hc + Vector2(r - 4, -r + 6), hc + Vector2(30, -r - 70), hc + Vector2(60, -r - 80)]), _darker(col, 0.6))
			draw_rect(Rect2(hc + Vector2(-r + 6, -r - 4), Vector2(2 * r - 12, 10)), Color(1.0, 0.8, 0.3))
		"sona":
			# ゴーグル
			draw_rect(Rect2(hc + Vector2(-r - 2, -34), Vector2(2 * r + 4, 10)), Color(0.25, 0.2, 0.18))
			draw_circle(hc + Vector2(-16, -30), 12, Color(0.4, 0.8, 0.85))
			draw_circle(hc + Vector2(16, -30), 12, Color(0.4, 0.8, 0.85))
		"john":
			draw_line(hc + Vector2(14, -10), hc + Vector2(30, 16), Color(0.7, 0.4, 0.35), 3.0)
			UI.poly(self, PackedVector2Array([hc + Vector2(-r + 6, 20), hc + Vector2(-20, r), hc + Vector2(20, r), hc + Vector2(r - 6, 20), hc + Vector2(0, 32)]), _darker(hair, 0.8))
		"maria":
			# 丸眼鏡
			draw_arc(hc + Vector2(-18, 4), 13, 0, TAU, 20, Color(0.3, 0.3, 0.35), 2.5)
			draw_arc(hc + Vector2(18, 4), 13, 0, TAU, 20, Color(0.3, 0.3, 0.35), 2.5)
			draw_line(hc + Vector2(-5, 4), hc + Vector2(5, 4), Color(0.3, 0.3, 0.35), 2.5)
		"shasta", "sister":
			if cid == "shasta":
				var crown = PackedVector2Array([hc + Vector2(-30, -r + 4), hc + Vector2(-34, -r - 26), hc + Vector2(-16, -r - 10), hc + Vector2(0, -r - 32), hc + Vector2(16, -r - 10), hc + Vector2(34, -r - 26), hc + Vector2(30, -r + 4)])
				UI.poly(self, crown, Color(1.0, 0.85, 0.2))
				draw_circle(hc + Vector2(0, -r - 8), 5, Color(0.9, 0.2, 0.3))
			else:
				draw_rect(Rect2(hc + Vector2(-r, -6), Vector2(2 * r, 14)), Color(0.85, 0.85, 0.95))
		"kaguya":
			# 金のかんざし
			draw_line(hc + Vector2(18, -r + 4), hc + Vector2(44, -r - 18), Color(1.0, 0.85, 0.35), 4.0)
			draw_circle(hc + Vector2(44, -r - 18), 7, Color(1.0, 0.4, 0.5))
		"nene":
			# 大きなマスク
			UI.poly(self, PackedVector2Array([hc + Vector2(-r + 2, 10), hc + Vector2(r - 2, 10), hc + Vector2(r - 10, 40), hc + Vector2(0, r + 4), hc + Vector2(-r + 10, 40)]), Color(0.95, 0.95, 0.97))
			draw_line(hc + Vector2(-r + 6, 24), hc + Vector2(r - 6, 24), Color(0.8, 0.8, 0.85), 2.0)
		"zone":
			draw_arc(hc + Vector2(18, 4), 12, 0, TAU, 20, Color(0.85, 0.7, 0.3), 2.5)
			draw_line(hc + Vector2(-8, 26), hc + Vector2(8, 26), Color(0.4, 0.3, 0.3), 2.0)
		"val":
			UI.poly(self, PackedVector2Array([hc + Vector2(-r - 10, 30), hc + Vector2(-r - 6, -20), hc + Vector2(0, -r - 18), hc + Vector2(r + 6, -20), hc + Vector2(r + 10, 30), hc + Vector2(r - 4, -10), hc + Vector2(0, -r - 2), hc + Vector2(-r + 4, -10)]), _darker(col, 0.7))
		"soldier":
			UI.poly(self, PackedVector2Array([hc + Vector2(-r - 4, 0), hc + Vector2(-r, -r + 4), hc + Vector2(0, -r - 10), hc + Vector2(r, -r + 4), hc + Vector2(r + 4, 0)]), Color(0.6, 0.62, 0.7))


func _draw_pots(col: Color, acc: Color) -> void:
	var hover = sin(_t * 3.0) * 6.0
	var c = Vector2(0, -130 + hover)
	# 浮遊ユニット
	draw_circle(c, 62, _darker(col, 0.6))
	draw_circle(c, 56, col)
	draw_rect(Rect2(c + Vector2(-44, -18), Vector2(88, 36)), Color(0.1, 0.12, 0.16))
	var eye_col = acc
	if expr == "angry":
		eye_col = Color(1.0, 0.4, 0.3)
	elif expr == "sad":
		eye_col = Color(0.5, 0.6, 1.0)
	if expr == "smile" or expr == "laugh":
		draw_arc(c + Vector2(-18, 6), 9, PI * 1.1, PI * 1.9, 8, eye_col, 4.0)
		draw_arc(c + Vector2(18, 6), 9, PI * 1.1, PI * 1.9, 8, eye_col, 4.0)
	elif expr == "surprise":
		draw_circle(c + Vector2(-18, 0), 9, eye_col)
		draw_circle(c + Vector2(18, 0), 9, eye_col)
	else:
		draw_rect(Rect2(c + Vector2(-26, -5), Vector2(16, 10)), eye_col)
		draw_rect(Rect2(c + Vector2(10, -5), Vector2(16, 10)), eye_col)
	draw_line(c + Vector2(0, -56), c + Vector2(0, -80), _darker(col, 0.6), 4.0)
	draw_circle(c + Vector2(0, -84), 7, acc)
	# プロペラ風の羽
	var a = _t * 18.0
	draw_line(c + Vector2(-62, 0), c + Vector2(-90, cos(a) * 14), _darker(col, 0.5), 5.0)
	draw_line(c + Vector2(62, 0), c + Vector2(90, cos(a) * 14), _darker(col, 0.5), 5.0)
	draw_circle(c + Vector2(0, 74), 14 + sin(_t * 6.0) * 3.0, Color(acc.r, acc.g, acc.b, 0.35))


func _draw_expr_marks() -> void:
	var hc = _head_c()
	var r = _head_r()
	match expr:
		"angry":
			var p = hc + Vector2(r + 6, -r + 4)
			for i in range(4):
				var a = PI / 4 + i * PI / 2
				draw_line(p + Vector2(cos(a), sin(a)) * 4, p + Vector2(cos(a), sin(a)) * 14, Color(0.95, 0.2, 0.2), 4.0)
		"sweat":
			var p2 = hc + Vector2(r + 2, -18)
			UI.poly(self, PackedVector2Array([p2 + Vector2(0, -12), p2 + Vector2(-7, 4), p2 + Vector2(7, 4)]), Color(0.6, 0.85, 1.0))
			draw_circle(p2 + Vector2(0, 4), 7, Color(0.6, 0.85, 1.0))
		"surprise":
			draw_line(hc + Vector2(r + 10, -r - 6), hc + Vector2(r + 16, -r + 16), Color(1.0, 0.9, 0.3), 5.0)
			draw_circle(hc + Vector2(r + 18, -r + 28), 3.5, Color(1.0, 0.9, 0.3))
		"cry":
			draw_line(hc + Vector2(-18, 14), hc + Vector2(-20, 34), Color(0.6, 0.85, 1.0), 4.0)
			draw_line(hc + Vector2(18, 14), hc + Vector2(20, 34), Color(0.6, 0.85, 1.0), 4.0)
		"think":
			draw_circle(hc + Vector2(r + 16, -r + 6), 5, Color(1, 1, 1, 0.8))
			draw_circle(hc + Vector2(r + 28, -r - 10), 8, Color(1, 1, 1, 0.8))
		"laugh":
			draw_string(ThemeDB.fallback_font, hc + Vector2(r + 4, -r + 10), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.8, 0.3))
