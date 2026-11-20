# 探索マップの描画（素材を使わず図形で描く「シンプルなイラスト」版）。
# assets/pixel/ にドット絵があれば、そちらを優先して描く（PixelArt）。
class_name FieldArt
extends RefCounted

const TS := 64.0  # 1マスの大きさ（ドット絵では16ドット×4倍）

# タイルの文字 → ドット絵タイルシート（8列×2行、16×16ドット）の番号
const ATLAS := {".": 0, "P": 0, "G": 0, "E": 0, "L": 0, "C": 0, "M": 0, "N": 0, "F": 0, "?": 0, "B": 0,
	",": 2, "\"": 3, ":": 4, "=": 5, "^": 6, "+": 7, "#": 8, "~": 10, "o": 12, " ": 13, "T": 15}
const ATLAS_FLOOR_B := 1
const ATLAS_WALL_FACE := 9
const ATLAS_WATER_B := 11
const ATLAS_TALL_TOP := 14

const THEMES := {
	"grass": {"floor": Color(0.45, 0.68, 0.32), "floor2": Color(0.41, 0.63, 0.3), "path": Color(0.76, 0.64, 0.42),
		"wall": Color(0.16, 0.38, 0.2), "wall2": Color(0.22, 0.47, 0.24), "face": Color(0.3, 0.21, 0.14),
		"water": Color(0.28, 0.58, 0.88), "tall": "tree", "rock": Color(0.6, 0.6, 0.62), "deco": "flower", "grass": Color(0.3, 0.55, 0.25),
		"void": Color(0.1, 0.2, 0.1)},
	"town": {"floor": Color(0.56, 0.52, 0.5), "floor2": Color(0.52, 0.48, 0.47), "path": Color(0.66, 0.6, 0.52),
		"wall": Color(0.48, 0.24, 0.3), "wall2": Color(0.56, 0.3, 0.34), "face": Color(0.74, 0.66, 0.56),
		"water": Color(0.3, 0.55, 0.75), "tall": "lamp", "rock": Color(0.55, 0.4, 0.28), "deco": "crack", "grass": Color(0.4, 0.55, 0.35),
		"void": Color(0.12, 0.1, 0.14)},
	"bamboo": {"floor": Color(0.15, 0.24, 0.19), "floor2": Color(0.13, 0.21, 0.17), "path": Color(0.32, 0.34, 0.33),
		"wall": Color(0.1, 0.2, 0.14), "wall2": Color(0.2, 0.42, 0.26), "face": Color(0.26, 0.5, 0.3),
		"water": Color(0.12, 0.18, 0.32), "tall": "bamboo", "rock": Color(0.5, 0.5, 0.48), "deco": "leaf", "grass": Color(0.2, 0.36, 0.24),
		"void": Color(0.03, 0.05, 0.08)},
	"colosseum": {"floor": Color(0.8, 0.68, 0.48), "floor2": Color(0.76, 0.64, 0.45), "path": Color(0.64, 0.57, 0.48),
		"wall": Color(0.62, 0.48, 0.34), "wall2": Color(0.7, 0.56, 0.4), "face": Color(0.52, 0.4, 0.29),
		"water": Color(0.12, 0.1, 0.08), "tall": "column", "rock": Color(0.68, 0.6, 0.5), "deco": "crack", "grass": Color(0.55, 0.55, 0.3),
		"void": Color(0.1, 0.08, 0.06)},
	"library": {"floor": Color(0.38, 0.26, 0.2), "floor2": Color(0.35, 0.24, 0.18), "path": Color(0.5, 0.16, 0.22),
		"wall": Color(0.22, 0.14, 0.12), "wall2": Color(0.3, 0.2, 0.16), "face": Color(0.32, 0.2, 0.15),
		"water": Color(0.06, 0.05, 0.16), "tall": "globe", "rock": Color(0.7, 0.62, 0.5), "deco": "page", "grass": Color(0.42, 0.2, 0.32),
		"void": Color(0.04, 0.03, 0.1)},
	"factory": {"floor": Color(0.38, 0.36, 0.34), "floor2": Color(0.35, 0.33, 0.31), "path": Color(0.46, 0.42, 0.36),
		"wall": Color(0.2, 0.18, 0.17), "wall2": Color(0.3, 0.27, 0.24), "face": Color(0.45, 0.36, 0.26),
		"water": Color(0.35, 0.12, 0.04), "tall": "chimney", "rock": Color(0.55, 0.42, 0.25), "deco": "oil", "grass": Color(0.3, 0.3, 0.3),
		"void": Color(0.08, 0.06, 0.05)},
	"summit": {"floor": Color(0.9, 0.9, 0.94), "floor2": Color(0.86, 0.86, 0.91), "path": Color(0.78, 0.68, 0.42),
		"wall": Color(0.62, 0.74, 0.95), "wall2": Color(0.95, 0.97, 1.0), "face": Color(0.75, 0.75, 0.82),
		"water": Color(0.5, 0.65, 0.95), "tall": "pillar", "rock": Color(0.8, 0.8, 0.85), "deco": "petal", "grass": Color(0.85, 0.75, 0.85),
		"void": Color(0.55, 0.7, 0.95)},
}


static func hash2(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(abs(h) % 1000) / 1000.0


static func is_wallish(c: String) -> bool:
	return c == "#" or c == " "


# ------------------------------------------------------------ 地面（下の層）
static func draw_ground(ci: CanvasItem, theme: String, c: String, tx: int, ty: int, below: String, above: String, t: float) -> void:
	var r = Rect2(tx * TS, ty * TS, TS, TS)
	var sheet: Texture2D = PixelArt.tex("tiles/%s.png" % theme)
	if sheet:
		_ground_pixel(ci, sheet, c, tx, ty, below, t, r)
		return
	var P: Dictionary = THEMES[theme]
	var h = hash2(tx, ty)
	var base: Color = P["floor"].lerp(P["floor2"], h * 0.6)
	match c:
		"#", " ":
			_wall(ci, theme, P, r, tx, ty, below, c)
			return
		"~":
			_water(ci, theme, P, r, tx, ty, t, above)
			return
		":":
			ci.draw_rect(r, P["path"])
			_path_detail(ci, theme, P, r, h)
		"=":
			_water(ci, theme, P, r, tx, ty, t, above)
			ci.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(TS, TS - 12)), Color(0.55, 0.38, 0.22))
			for i in range(4):
				ci.draw_line(r.position + Vector2(i * 16 + 2, 6), r.position + Vector2(i * 16 + 2, TS - 6), Color(0.38, 0.25, 0.14), 2.0)
			ci.draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(TS, 4)), Color(0.4, 0.27, 0.15))
			ci.draw_rect(Rect2(r.position + Vector2(0, TS - 8), Vector2(TS, 4)), Color(0.4, 0.27, 0.15))
		"^":
			ci.draw_rect(r, P["path"].darkened(0.1))
			for i in range(4):
				ci.draw_rect(Rect2(r.position + Vector2(4, i * 16 + 2), Vector2(TS - 8, 10)), P["path"].lightened(0.15))
		"+":
			ci.draw_rect(r, base)
		_:
			ci.draw_rect(r, base)
			_floor_detail(ci, theme, P, r, h, c)
	# 壁の下に落ちる影
	if is_wallish(above) or above == "T":
		ci.draw_rect(Rect2(r.position, Vector2(TS, 10)), Color(0, 0, 0, 0.18))


static func _ground_pixel(ci: CanvasItem, sheet: Texture2D, c: String, tx: int, ty: int, below: String, t: float, r: Rect2) -> void:
	var idx: int = ATLAS.get(c, 0)
	if c == "#" and not is_wallish(below):
		idx = ATLAS_WALL_FACE
	elif c == "~" and fmod(t, 1.0) > 0.5:
		idx = ATLAS_WATER_B
	elif idx == 0 and hash2(tx, ty) > 0.7:
		idx = ATLAS_FLOOR_B
	elif c == "T" or c == "o" or c == "+":
		# 背の高いものの足元は床
		ci.draw_texture_rect_region(sheet, r, _atlas_src(sheet, 0))
		return
	ci.draw_texture_rect_region(sheet, r, _atlas_src(sheet, idx))


static func _atlas_src(sheet: Texture2D, idx: int) -> Rect2:
	var cw: float = sheet.get_width() / 8.0
	return Rect2((idx % 8) * cw, int(idx / 8) * cw, cw, cw)


static func _floor_detail(ci: CanvasItem, theme: String, P: Dictionary, r: Rect2, h: float, c: String) -> void:
	var o = r.position
	match theme:
		"grass":
			if h > 0.6:
				ci.draw_line(o + Vector2(12 + h * 20, 40), o + Vector2(15 + h * 20, 30), P["grass"], 2.0)
				ci.draw_line(o + Vector2(18 + h * 20, 42), o + Vector2(19 + h * 20, 33), P["grass"], 2.0)
		"town":
			ci.draw_line(o + Vector2(0, 32), o + Vector2(TS, 32), Color(0, 0, 0, 0.12), 1.5)
			ci.draw_line(o + Vector2(32 if int(r.position.y / TS) % 2 == 0 else 0, 0), o + Vector2(32 if int(r.position.y / TS) % 2 == 0 else 0, 32), Color(0, 0, 0, 0.12), 1.5)
			ci.draw_line(o + Vector2(16, 32), o + Vector2(16, TS), Color(0, 0, 0, 0.12), 1.5)
			ci.draw_line(o + Vector2(48, 32), o + Vector2(48, TS), Color(0, 0, 0, 0.12), 1.5)
		"bamboo":
			if h > 0.7:
				ci.draw_circle(o + Vector2(h * 50 + 6, 20 + h * 30), 2.0, Color(0.5, 0.7, 0.5, 0.4))
		"colosseum":
			if h > 0.75:
				ci.draw_line(o + Vector2(10, 20 + h * 20), o + Vector2(40, 30 + h * 10), Color(0, 0, 0, 0.1), 1.5)
		"library":
			for i in range(4):
				ci.draw_line(o + Vector2(0, i * 16), o + Vector2(TS, i * 16), Color(0, 0, 0, 0.18), 1.5)
			ci.draw_line(o + Vector2(h * 60, 0), o + Vector2(h * 60, 16), Color(0, 0, 0, 0.18), 1.5)
		"factory":
			ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(TS - 2, TS - 2)), Color(0, 0, 0, 0.18), false, 2.0)
			for p in [Vector2(6, 6), Vector2(58, 6), Vector2(6, 58), Vector2(58, 58)]:
				ci.draw_circle(o + p, 2.0, Color(0.55, 0.53, 0.5))
		"summit":
			ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(TS - 2, TS - 2)), Color(0.75, 0.75, 0.82, 0.6), false, 1.5)
	match c:
		",":
			_small_deco(ci, theme, P, o, h)
		"\"":
			_tall_grass(ci, theme, P, o, h)


static func _small_deco(ci: CanvasItem, theme: String, P: Dictionary, o: Vector2, h: float) -> void:
	match P["deco"]:
		"flower":
			var cols = [Color(1.0, 0.6, 0.75), Color(1.0, 0.95, 0.5), Color(1, 1, 1)]
			for i in range(3):
				var p = o + Vector2(14 + i * 15 + h * 6, 18 + fmod(h * 97.0 * (i + 1), 30.0))
				ci.draw_circle(p, 4.0, cols[(i + int(h * 10)) % 3])
				ci.draw_circle(p, 1.6, Color(1.0, 0.8, 0.3))
		"crack":
			ci.draw_polyline(PackedVector2Array([o + Vector2(10, 14), o + Vector2(26, 28), o + Vector2(22, 42), o + Vector2(40, 52)]), Color(0, 0, 0, 0.25), 2.0)
		"leaf":
			for i in range(3):
				var p2 = o + Vector2(12 + i * 18, 20 + fmod(h * 71.0 * (i + 1), 28.0))
				ci.draw_line(p2, p2 + Vector2(8, 3), Color(0.55, 0.5, 0.25, 0.8), 3.0)
		"page":
			ci.draw_rect(Rect2(o + Vector2(14 + h * 20, 20), Vector2(14, 18)), Color(0.9, 0.86, 0.75, 0.9))
			ci.draw_rect(Rect2(o + Vector2(30, 34 + h * 10), Vector2(12, 15)), Color(0.85, 0.8, 0.7, 0.8))
		"oil":
			ci.draw_circle(o + Vector2(30 + h * 10, 34), 14.0, Color(0.1, 0.1, 0.12, 0.35))
		"petal":
			for i in range(4):
				ci.draw_circle(o + Vector2(10 + i * 14, 16 + fmod(h * 53.0 * (i + 1), 34.0)), 3.0, Color(1.0, 0.75, 0.85))


static func _tall_grass(ci: CanvasItem, theme: String, P: Dictionary, o: Vector2, h: float) -> void:
	if theme in ["library", "summit", "town"]:
		# 敷物・花壇
		ci.draw_rect(Rect2(o + Vector2(4, 4), Vector2(TS - 8, TS - 8)), P["grass"])
		ci.draw_rect(Rect2(o + Vector2(8, 8), Vector2(TS - 16, TS - 16)), P["grass"].lightened(0.15), false, 2.0)
		return
	var gc: Color = P["grass"].darkened(0.15)
	for i in range(6):
		var x = 6 + i * 10 + h * 4
		ci.draw_line(o + Vector2(x, TS - 6), o + Vector2(x - 4, 14 + fmod(h * 31.0 * (i + 1), 12.0)), gc, 3.0)
		ci.draw_line(o + Vector2(x + 3, TS - 6), o + Vector2(x + 7, 18 + fmod(h * 17.0 * (i + 1), 12.0)), gc.lightened(0.15), 2.5)


static func _path_detail(ci: CanvasItem, theme: String, P: Dictionary, r: Rect2, h: float) -> void:
	var o = r.position
	match theme:
		"grass", "bamboo":
			for i in range(3):
				ci.draw_circle(o + Vector2(10 + fmod(h * 113.0 * (i + 1), 44.0), 12 + i * 18), 3.0, P["path"].darkened(0.12))
		"town", "colosseum", "summit":
			ci.draw_rect(Rect2(o + Vector2(2, 2), Vector2(28, 28)), P["path"].lightened(0.05), false, 1.5)
			ci.draw_rect(Rect2(o + Vector2(34, 34), Vector2(28, 28)), P["path"].lightened(0.05), false, 1.5)
		"library":
			ci.draw_line(o + Vector2(0, 6), o + Vector2(TS, 6), Color(0.9, 0.7, 0.3, 0.6), 2.0)
			ci.draw_line(o + Vector2(0, TS - 6), o + Vector2(TS, TS - 6), Color(0.9, 0.7, 0.3, 0.6), 2.0)
		"factory":
			for i in range(4):
				ci.draw_line(o + Vector2(i * 16, 0), o + Vector2(i * 16 + 8, 8), Color(0.9, 0.75, 0.2, 0.8), 3.0)
				ci.draw_line(o + Vector2(i * 16, TS - 8), o + Vector2(i * 16 + 8, TS), Color(0.9, 0.75, 0.2, 0.8), 3.0)


static func _water(ci: CanvasItem, theme: String, P: Dictionary, r: Rect2, tx: int, ty: int, t: float, above: String) -> void:
	var o = r.position
	var wc: Color = P["water"]
	ci.draw_rect(r, wc)
	match theme:
		"library":
			for i in range(3):
				var s = hash2(tx * 3 + i, ty)
				var tw = 0.5 + 0.5 * sin(t * 2.0 + s * 20.0)
				ci.draw_circle(o + Vector2(s * TS, fmod(s * 977.0, TS)), 1.5 + tw, Color(1, 1, 0.9, 0.4 + tw * 0.5))
		"factory":
			var k = 0.5 + 0.5 * sin(t * 2.0 + tx + ty)
			ci.draw_rect(Rect2(o + Vector2(6, 6), Vector2(TS - 12, TS - 12)), Color(1.0, 0.5, 0.1, 0.25 + k * 0.2))
		"colosseum":
			ci.draw_rect(Rect2(o, Vector2(TS, 8)), Color(0, 0, 0, 0.4))
		"summit":
			ci.draw_circle(o + Vector2(20 + sin(t + tx) * 6, 30), 10.0, Color(1, 1, 1, 0.5))
			ci.draw_circle(o + Vector2(36 + sin(t + tx) * 6, 34), 12.0, Color(1, 1, 1, 0.5))
		_:
			for i in range(2):
				var yy = 16 + i * 26 + sin(t * 2.0 + tx * 0.7 + i) * 3.0
				var xx = 8 + fmod((tx * 37 + i * 23) + t * 10.0, 30.0)
				ci.draw_line(o + Vector2(xx, yy), o + Vector2(xx + 18, yy), Color(1, 1, 1, 0.35), 2.0)
	if above != "~" and above != "=" and not is_wallish(above):
		ci.draw_rect(Rect2(o, Vector2(TS, 6)), wc.darkened(0.3))


static func _wall(ci: CanvasItem, theme: String, P: Dictionary, r: Rect2, tx: int, ty: int, below: String, c: String) -> void:
	var o = r.position
	if c == " ":
		ci.draw_rect(r, P["void"])
		return
	var face: bool = not is_wallish(below)
	var top_h: float = TS * (0.45 if face else 1.0)
	var h = hash2(tx, ty)
	ci.draw_rect(Rect2(o, Vector2(TS, top_h)), P["wall"])
	match theme:
		"grass":
			# 森：木々のかたまり
			for i in range(3):
				var p = o + Vector2(10 + fmod(h * 131.0 * (i + 1), 44.0), 8 + fmod(h * 71.0 * (i + 2), top_h - 4))
				ci.draw_circle(p, 13.0, P["wall2"])
				ci.draw_circle(p + Vector2(-3, -3), 6.0, P["wall2"].lightened(0.12))
		"bamboo":
			for i in range(4):
				var x = 6 + i * 16 + h * 6
				ci.draw_line(o + Vector2(x, 0), o + Vector2(x, top_h), P["wall2"], 5.0)
				ci.draw_line(o + Vector2(x - 3, fmod(h * 50.0 + i * 13.0, top_h)), o + Vector2(x + 3, fmod(h * 50.0 + i * 13.0, top_h)), P["wall2"].lightened(0.2), 2.0)
		"town":
			# 屋根瓦
			for i in range(int(top_h / 12) + 1):
				ci.draw_line(o + Vector2(0, i * 12 + 6), o + Vector2(TS, i * 12 + 6), P["wall2"], 3.0)
		"colosseum":
			ci.draw_rect(Rect2(o + Vector2(2, 2), Vector2(TS - 4, top_h - 4)), P["wall2"], false, 2.0)
		"library":
			ci.draw_rect(Rect2(o + Vector2(4, 4), Vector2(TS - 8, top_h - 8)), P["wall2"])
		"factory":
			ci.draw_circle(o + Vector2(32, top_h / 2.0), min(18.0, top_h / 2.5), P["wall2"])
			ci.draw_line(o + Vector2(0, top_h / 2.0), o + Vector2(TS, top_h / 2.0), P["wall2"].lightened(0.1), 6.0)
		"summit":
			ci.draw_rect(Rect2(o, Vector2(TS, top_h)), P["wall"].lerp(P["wall2"], 0.15 + h * 0.2))
			ci.draw_circle(o + Vector2(20 + h * 20, top_h * 0.5), 14.0, Color(1, 1, 1, 0.55))
			ci.draw_circle(o + Vector2(40 + h * 10, top_h * 0.6), 11.0, Color(1, 1, 1, 0.5))
	if not face:
		return
	var fr = Rect2(o + Vector2(0, top_h), Vector2(TS, TS - top_h))
	ci.draw_rect(fr, P["face"])
	match theme:
		"grass":
			for i in range(3):
				var x2 = 10 + i * 20 + h * 6
				ci.draw_rect(Rect2(o + Vector2(x2, top_h), Vector2(7, TS - top_h)), P["face"].darkened(0.25))
			ci.draw_rect(Rect2(o + Vector2(0, top_h), Vector2(TS, 6)), P["wall"].darkened(0.2))
		"town":
			ci.draw_rect(Rect2(o + Vector2(14, top_h + 8), Vector2(14, 16)), Color(0.3, 0.35, 0.45))
			ci.draw_rect(Rect2(o + Vector2(38, top_h + 8), Vector2(14, 16)), Color(0.95, 0.8, 0.4) if h > 0.5 else Color(0.3, 0.35, 0.45))
		"bamboo":
			for i in range(4):
				var x3 = 6 + i * 16 + h * 6
				ci.draw_line(o + Vector2(x3, top_h), o + Vector2(x3, TS), P["face"].darkened(0.1), 6.0)
		"colosseum":
			ci.draw_line(o + Vector2(0, top_h + 12), o + Vector2(TS, top_h + 12), P["face"].darkened(0.2), 2.0)
			ci.draw_line(o + Vector2(32, top_h), o + Vector2(32, top_h + 12), P["face"].darkened(0.2), 2.0)
			ci.draw_line(o + Vector2(16, top_h + 12), o + Vector2(16, TS), P["face"].darkened(0.2), 2.0)
			ci.draw_line(o + Vector2(48, top_h + 12), o + Vector2(48, TS), P["face"].darkened(0.2), 2.0)
		"library":
			var spines = [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.6), Color(0.3, 0.5, 0.3), Color(0.7, 0.55, 0.25), Color(0.45, 0.25, 0.5)]
			for i in range(8):
				var col: Color = spines[(i + int(h * 10)) % 5]
				ci.draw_rect(Rect2(o + Vector2(2 + i * 7.5, top_h + 4 + fmod(h * 13.0 * (i + 1), 6.0)), Vector2(6, TS - top_h - 8)), col)
		"factory":
			ci.draw_circle(o + Vector2(20, top_h + 16), 8.0, Color(0.85, 0.8, 0.7))
			ci.draw_line(o + Vector2(20, top_h + 16), o + Vector2(20 + cos(h * 6.0) * 6, top_h + 16 + sin(h * 6.0) * 6), Color(0.8, 0.2, 0.1), 2.0)
			ci.draw_rect(Rect2(o + Vector2(36, top_h + 6), Vector2(20, 22)), Color(0.3, 0.26, 0.22))
		"summit":
			ci.draw_rect(fr, Color(0.8, 0.85, 1.0, 0.5))


# ------------------------------------------------------------ 背の高いもの（手前・奥の順に描く層）
static func draw_tall(ci: CanvasItem, theme: String, c: String, tx: int, ty: int, t: float) -> void:
	var base = Vector2(tx * TS + TS / 2.0, ty * TS + TS - 6)
	var sheet: Texture2D = PixelArt.tex("tiles/%s.png" % theme)
	if sheet:
		if c == "T":
			ci.draw_texture_rect_region(sheet, Rect2(tx * TS, (ty - 1) * TS, TS, TS), _atlas_src(sheet, ATLAS_TALL_TOP))
			ci.draw_texture_rect_region(sheet, Rect2(tx * TS, ty * TS, TS, TS), _atlas_src(sheet, ATLAS["T"]))
		elif c == "o":
			ci.draw_texture_rect_region(sheet, Rect2(tx * TS, ty * TS, TS, TS), _atlas_src(sheet, ATLAS["o"]))
		elif c == "+":
			ci.draw_texture_rect_region(sheet, Rect2(tx * TS, ty * TS, TS, TS), _atlas_src(sheet, ATLAS["+"]))
		return
	var P: Dictionary = THEMES[theme]
	var h = hash2(tx, ty)
	if c == "o":
		_shadow(ci, base, 24, 7)
		match theme:
			"town", "factory":
				ci.draw_rect(Rect2(base + Vector2(-22, -40), Vector2(44, 40)), P["rock"])
				ci.draw_rect(Rect2(base + Vector2(-22, -40), Vector2(44, 40)), P["rock"].darkened(0.3), false, 3.0)
				ci.draw_line(base + Vector2(-22, -20), base + Vector2(22, -20), P["rock"].darkened(0.3), 3.0)
			"library":
				for i in range(4):
					ci.draw_rect(Rect2(base + Vector2(-20 + i * 2, -10 - i * 10), Vector2(40 - i * 4, 9)), [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.6), Color(0.7, 0.55, 0.25), Color(0.3, 0.5, 0.3)][i])
			"bamboo":
				# 石灯籠
				ci.draw_rect(Rect2(base + Vector2(-8, -30), Vector2(16, 30)), P["rock"])
				ci.draw_rect(Rect2(base + Vector2(-18, -44), Vector2(36, 14)), P["rock"].lightened(0.1))
				ci.draw_rect(Rect2(base + Vector2(-6, -40), Vector2(12, 8)), Color(1.0, 0.85, 0.5, 0.7 + sin(t * 3.0 + h * 9.0) * 0.2))
			_:
				var pts = PackedVector2Array([base + Vector2(-24, 0), base + Vector2(-20, -22), base + Vector2(-4, -32), base + Vector2(16, -26), base + Vector2(24, 0)])
				UI.poly(ci, pts, P["rock"])
				ci.draw_line(base + Vector2(-8, -24), base + Vector2(4, -12), P["rock"].darkened(0.25), 2.0)
		return
	if c == "+":
		# 中盤のストーリーまで閉じている門
		var top = Vector2(tx * TS, ty * TS)
		ci.draw_rect(Rect2(top + Vector2(0, -20), Vector2(TS, TS + 14)), Color(0.25, 0.2, 0.22, 0.9))
		for i in range(5):
			ci.draw_line(top + Vector2(6 + i * 13, -18), top + Vector2(6 + i * 13, TS - 6), Color(0.55, 0.5, 0.45), 4.0)
		ci.draw_line(top + Vector2(0, 10), top + Vector2(TS, 10), Color(0.55, 0.5, 0.45), 4.0)
		ci.draw_circle(top + Vector2(32, 26), 6.0, Color(0.9, 0.7, 0.3, 0.6 + sin(t * 3.0) * 0.3))
		return
	_shadow(ci, base, 26, 8)
	match P["tall"]:
		"tree":
			ci.draw_rect(Rect2(base + Vector2(-7, -34), Vector2(14, 34)), Color(0.42, 0.28, 0.16))
			var cc = Color(0.2, 0.5, 0.24).lerp(Color(0.3, 0.58, 0.26), h)
			ci.draw_circle(base + Vector2(0, -62), 30.0, cc.darkened(0.15))
			ci.draw_circle(base + Vector2(-14, -52), 20.0, cc)
			ci.draw_circle(base + Vector2(14, -54), 20.0, cc)
			ci.draw_circle(base + Vector2(-4, -74), 18.0, cc.lightened(0.12))
		"lamp":
			ci.draw_line(base, base + Vector2(0, -90), Color(0.2, 0.2, 0.22), 5.0)
			ci.draw_rect(Rect2(base + Vector2(-10, -104), Vector2(20, 18)), Color(0.25, 0.25, 0.28))
			ci.draw_rect(Rect2(base + Vector2(-7, -101), Vector2(14, 12)), Color(1.0, 0.85, 0.45))
			ci.draw_circle(base + Vector2(0, -95), 24.0, Color(1.0, 0.85, 0.45, 0.12))
		"bamboo":
			for i in range(3):
				var x = -14 + i * 14
				var ht = 110 + h * 30 - i * 10
				ci.draw_line(base + Vector2(x, 0), base + Vector2(x + 2, -ht), Color(0.3, 0.56, 0.32), 7.0)
				for k in range(4):
					ci.draw_line(base + Vector2(x - 4, -k * 28 - 12), base + Vector2(x + 5, -k * 28 - 12), Color(0.42, 0.68, 0.4), 2.0)
				ci.draw_line(base + Vector2(x + 2, -ht), base + Vector2(x + 18, -ht + 10), Color(0.35, 0.6, 0.35), 4.0)
		"column":
			ci.draw_rect(Rect2(base + Vector2(-16, -100), Vector2(32, 100)), P["face"].lightened(0.2))
			for i in range(3):
				ci.draw_line(base + Vector2(-8 + i * 8, -96), base + Vector2(-8 + i * 8, -4), P["face"], 2.0)
			ci.draw_rect(Rect2(base + Vector2(-22, -108), Vector2(44, 10)), P["wall2"])
			ci.draw_rect(Rect2(base + Vector2(-22, -6), Vector2(44, 6)), P["wall2"])
		"globe":
			ci.draw_line(base, base + Vector2(0, -50), Color(0.55, 0.42, 0.2), 6.0)
			ci.draw_circle(base + Vector2(0, -72), 22.0, Color(0.25, 0.35, 0.7))
			ci.draw_arc(base + Vector2(0, -72), 22.0, 0, TAU, 24, Color(0.9, 0.75, 0.35), 3.0)
			ci.draw_circle(base + Vector2(-6, -78), 5.0, Color(1, 1, 0.8, 0.6))
		"chimney":
			ci.draw_rect(Rect2(base + Vector2(-16, -96), Vector2(32, 96)), Color(0.4, 0.3, 0.25))
			ci.draw_rect(Rect2(base + Vector2(-20, -104), Vector2(40, 10)), Color(0.3, 0.24, 0.2))
			for i in range(3):
				var ph = fmod(t * 0.6 + i * 0.33 + h, 1.0)
				ci.draw_circle(base + Vector2(sin(ph * 6.0) * 6, -110 - ph * 50), 8 + ph * 10, Color(0.6, 0.6, 0.6, 0.35 * (1.0 - ph)))
		"pillar":
			ci.draw_rect(Rect2(base + Vector2(-14, -110), Vector2(28, 110)), Color(0.96, 0.96, 1.0))
			ci.draw_line(base + Vector2(-6, -106), base + Vector2(-6, -4), Color(0.8, 0.8, 0.88), 2.0)
			ci.draw_line(base + Vector2(6, -106), base + Vector2(6, -4), Color(0.8, 0.8, 0.88), 2.0)
			ci.draw_rect(Rect2(base + Vector2(-20, -118), Vector2(40, 10)), Color(0.9, 0.82, 0.55))


static func _shadow(ci: CanvasItem, p: Vector2, rx: float, ry: float, a: float = 0.28) -> void:
	var pts = PackedVector2Array()
	for i in range(16):
		var ang = TAU * i / 16.0
		pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
	UI.poly(ci, pts, Color(0, 0, 0, a))


# ------------------------------------------------------------ キャラ（歩きの4方向）
# dir: 0 下 1 左 2 右 3 上
static func draw_walker(ci: CanvasItem, sheet_name: String, cid: String, feet: Vector2, dir: int, walk: float, moving: bool, mod: Color = Color.WHITE) -> void:
	var sheet: Texture2D = null
	if cid == "ren" and Game.flags.get("red_cape", false):
		sheet = PixelArt.tex("field/%s_cape.png" % sheet_name)
	if sheet == null:
		sheet = PixelArt.tex("field/%s.png" % sheet_name)
	var frame := 1
	if moving:
		frame = [0, 1, 2, 1][int(walk * 8.0) % 4]
	_shadow(ci, feet, 20, 7)
	if sheet:
		PixelArt.draw_cell(ci, sheet, 3, 4, frame, dir, feet + Vector2(0, 4), false, mod)
		return
	var d: Dictionary = DB.Characters.DATA.get(cid, {})
	var col: Color = d.get("color", Color(0.5, 0.5, 0.6))
	var hair: Color = d.get("hair", Color(0.3, 0.25, 0.2))
	var acc: Color = d.get("accent", col.lightened(0.3))
	var skin = Color(1.0, 0.86, 0.74)
	var bob = -abs(sin(walk * 12.0)) * 4.0 if moving else 0.0
	var step = sin(walk * 12.0) * 6.0 if moving else 0.0
	var f = feet + Vector2(0, bob)
	col *= mod
	hair *= mod
	# 脚
	var leg = Color(0.22, 0.2, 0.25) * mod
	if dir == 1 or dir == 2:
		ci.draw_line(f + Vector2(-3, -20), f + Vector2(-3 + step, -2), leg, 7.0)
		ci.draw_line(f + Vector2(3, -20), f + Vector2(3 - step, -2), leg, 7.0)
	else:
		ci.draw_line(f + Vector2(-7, -20), f + Vector2(-7, -2 - max(0.0, step)), leg, 7.0)
		ci.draw_line(f + Vector2(7, -20), f + Vector2(7, -2 - max(0.0, -step)), leg, 7.0)
	# 体
	ci.draw_rect(Rect2(f + Vector2(-14, -50), Vector2(28, 32)), col)
	ci.draw_rect(Rect2(f + Vector2(-14, -26), Vector2(28, 6)), acc * mod)
	# マント（レン）
	if cid == "ren" and Game.flags.get("red_cape", false):
		if dir == 3:
			ci.draw_rect(Rect2(f + Vector2(-16, -52), Vector2(32, 36)), Color(0.85, 0.15, 0.18) * mod)
	# 頭
	var head = f + Vector2(0, -66)
	ci.draw_circle(head, 17.0, skin * mod)
	match dir:
		0:
			ci.draw_rect(Rect2(head + Vector2(-18, -18), Vector2(36, 12)), hair)
			ci.draw_rect(Rect2(head + Vector2(-18, -10), Vector2(6, 16)), hair)
			ci.draw_rect(Rect2(head + Vector2(12, -10), Vector2(6, 16)), hair)
			ci.draw_rect(Rect2(head + Vector2(-8, -2), Vector2(4, 7)), Color(0.15, 0.12, 0.15))
			ci.draw_rect(Rect2(head + Vector2(4, -2), Vector2(4, 7)), Color(0.15, 0.12, 0.15))
		3:
			ci.draw_circle(head, 18.0, hair)
		1, 2:
			var s = -1.0 if dir == 1 else 1.0
			ci.draw_rect(Rect2(head + Vector2(-18, -18), Vector2(36, 12)), hair)
			ci.draw_rect(Rect2(head + Vector2(-18.0 if s > 0 else 4.0, -10), Vector2(14, 18)), hair)
			ci.draw_rect(Rect2(head + Vector2(s * 6 - 2, -2), Vector2(4, 7)), Color(0.15, 0.12, 0.15))
	# 腕
	if dir == 1 or dir == 2:
		var s2 = -1.0 if dir == 1 else 1.0
		ci.draw_line(f + Vector2(0, -46), f + Vector2(s2 * 4 - step * 0.8, -26), col.darkened(0.2), 7.0)
	else:
		ci.draw_line(f + Vector2(-15, -46), f + Vector2(-17, -28 + step * 0.5), col.darkened(0.2), 7.0)
		ci.draw_line(f + Vector2(15, -46), f + Vector2(17, -28 - step * 0.5), col.darkened(0.2), 7.0)


# ------------------------------------------------------------ 敵シンボル
static func draw_symbol(ci: CanvasItem, eid: String, p: Vector2, t: float, facing: float, elite: bool, alert: float, mod: Color = Color.WHITE) -> void:
	var d: Dictionary = DB.Enemies.DATA.get(eid, {})
	var col: Color = d.get("color", Color(0.6, 0.6, 0.6)) * mod
	var sc: float = 1.35 if elite else 1.0
	if elite:
		for i in range(3):
			ci.draw_circle(p + Vector2(0, -26), 34.0 + i * 7 + sin(t * 4.0 + i) * 3.0, Color(1.0, 0.25, 0.2, 0.09))
	_shadow(ci, p, 22 * sc, 7 * sc)
	var sheet: Texture2D = PixelArt.tex("field/sym_%s.png" % eid)
	if sheet:
		PixelArt.draw_strip(ci, sheet, int(t * 4.0), p + Vector2(0, -sheet.get_height() * PixelArt.SCALE * sc / 2.0 + 4), mod, PixelArt.SCALE * sc, facing < 0)
		_alert_mark(ci, p + Vector2(0, -sheet.get_height() * PixelArt.SCALE * sc - 10), alert)
		return
	var bob = sin(t * 5.0) * 3.0
	var dark = col.darkened(0.45)
	var s = facing
	var shape: String = d.get("shape", "slime")
	var top: float = -50.0 * sc
	match shape:
		"slime":
			var sq = 1.0 + sin(t * 6.0) * 0.08
			var pts = PackedVector2Array()
			for i in range(16):
				var ang = PI + PI * i / 15.0
				pts.append(p + Vector2(cos(ang) * 22 * sc / sq, sin(ang) * 30 * sc * sq))
			UI.poly(ci, pts, col)
			ci.draw_circle(p + Vector2(s * 7, -18 * sc), 4.5, Color.WHITE)
			ci.draw_circle(p + Vector2(s * 8, -18 * sc), 2.2, Color(0.1, 0.1, 0.1))
			top = -34 * sc
		"bat", "drone", "book", "wisp":
			var c2 = p + Vector2(0, -44 * sc + bob)
			if shape == "bat":
				var fl = sin(t * 16.0) * 10.0
				UI.poly(ci, PackedVector2Array([c2, c2 + Vector2(-26, -8 - fl), c2 + Vector2(-14, 8)]), dark)
				UI.poly(ci, PackedVector2Array([c2, c2 + Vector2(26, -8 - fl), c2 + Vector2(14, 8)]), dark)
				ci.draw_circle(c2, 11.0 * sc, col)
			elif shape == "wisp":
				ci.draw_circle(c2, 18.0 * sc, Color(col.r, col.g, col.b, 0.3))
				ci.draw_circle(c2, 11.0 * sc, col)
				ci.draw_circle(c2, 5.0 * sc, Color(1, 1, 1, 0.9))
			elif shape == "book":
				var fl2 = sin(t * 8.0) * 6.0
				UI.poly(ci, PackedVector2Array([c2 + Vector2(0, 8), c2 + Vector2(-22, -4 - fl2), c2 + Vector2(-20, 12)]), col)
				UI.poly(ci, PackedVector2Array([c2 + Vector2(0, 8), c2 + Vector2(22, -4 - fl2), c2 + Vector2(20, 12)]), col.lightened(0.2))
			else:
				ci.draw_rect(Rect2(c2 + Vector2(-20, -6), Vector2(40, 12)), col)
				ci.draw_line(c2 + Vector2(-26, -10), c2 + Vector2(26, -10), dark, 3.0)
				ci.draw_circle(c2 + Vector2(s * 8, 0), 4.0, Color(1.0, 0.3, 0.2))
			ci.draw_circle(c2 + Vector2(s * 5, -2), 3.0, Color(1.0, 0.95, 0.4))
			top = -66 * sc
		"wolf", "beast":
			var body = p + Vector2(0, -24 * sc + bob * 0.3)
			ci.draw_rect(Rect2(body + Vector2(-22 * sc, -10 * sc), Vector2(44 * sc, 20 * sc)), col)
			ci.draw_circle(body + Vector2(s * 24 * sc, -12 * sc), 12.0 * sc, col)
			UI.poly(ci, PackedVector2Array([body + Vector2(s * 20 * sc, -22 * sc), body + Vector2(s * 26 * sc, -34 * sc), body + Vector2(s * 30 * sc, -20 * sc)]), dark)
			for lx in [-16, -6, 10, 18]:
				ci.draw_line(body + Vector2(lx * sc, 8 * sc), body + Vector2(lx * sc + sin(t * 10.0 + lx) * 3.0, 22 * sc), dark, 5.0)
			ci.draw_line(body + Vector2(-s * 22 * sc, -6 * sc), body + Vector2(-s * 34 * sc, -14 * sc), dark, 5.0)
			ci.draw_circle(body + Vector2(s * 30 * sc, -14 * sc), 2.5, Color(1.0, 0.95, 0.4))
			top = -62 * sc
		"golem", "gearbot":
			ci.draw_rect(Rect2(p + Vector2(-20 * sc, -56 * sc), Vector2(40 * sc, 50 * sc)), col)
			ci.draw_rect(Rect2(p + Vector2(-26 * sc, -50 * sc), Vector2(8 * sc, 30 * sc)), dark)
			ci.draw_rect(Rect2(p + Vector2(18 * sc, -50 * sc), Vector2(8 * sc, 30 * sc)), dark)
			ci.draw_rect(Rect2(p + Vector2(-14 * sc, -8 * sc), Vector2(10 * sc, 8 * sc)), dark)
			ci.draw_rect(Rect2(p + Vector2(4 * sc, -8 * sc), Vector2(10 * sc, 8 * sc)), dark)
			ci.draw_circle(p + Vector2(s * 6 * sc, -42 * sc), 4.0, Color(1.0, 0.9, 0.4))
			if shape == "gearbot":
				ci.draw_arc(p + Vector2(0, -32 * sc), 14.0 * sc, t * 3.0, t * 3.0 + TAU * 0.8, 12, dark, 4.0)
			top = -64 * sc
		"siren":
			ci.draw_circle(p + Vector2(0, -56), 12.0, col.lightened(0.3))
			UI.poly(ci, PackedVector2Array([p + Vector2(-16, -44), p + Vector2(16, -44), p + Vector2(22, 0), p + Vector2(-22, 0)]), col)
			top = -76
		_:
			# 人型（異形・小鬼・兵士など）
			var ht = 1.0 if shape != "oni" else 0.95
			ci.draw_line(p + Vector2(-6, -22), p + Vector2(-6 + sin(t * 8.0) * 3.0, -2), dark, 7.0)
			ci.draw_line(p + Vector2(6, -22), p + Vector2(6 - sin(t * 8.0) * 3.0, -2), dark, 7.0)
			ci.draw_rect(Rect2(p + Vector2(-14, -52 * ht), Vector2(28, 32)), col)
			ci.draw_circle(p + Vector2(0, -64 * ht + bob * 0.3), 14.0, col.lightened(0.15) if shape != "humanoid" else Color(1.0, 0.86, 0.74) * mod)
			if shape == "oni":
				UI.poly(ci, PackedVector2Array([p + Vector2(-10, -74), p + Vector2(-6, -88), p + Vector2(-2, -74)]), Color(0.95, 0.9, 0.7))
				UI.poly(ci, PackedVector2Array([p + Vector2(10, -74), p + Vector2(6, -88), p + Vector2(2, -74)]), Color(0.95, 0.9, 0.7))
			elif shape == "humanoid":
				ci.draw_rect(Rect2(p + Vector2(-15, -80), Vector2(30, 12)), dark)
			elif shape == "ikei":
				ci.draw_line(p + Vector2(-14, -48), p + Vector2(-26, -34 + bob), col, 5.0)
				ci.draw_line(p + Vector2(14, -48), p + Vector2(26, -34 - bob), col, 5.0)
			ci.draw_circle(p + Vector2(s * 6, -66 * ht), 2.8, Color(1.0, 0.3, 0.2) if shape != "humanoid" else Color(0.1, 0.1, 0.1))
			top = -82
	_alert_mark(ci, p + Vector2(0, top - 14), alert)


static func _alert_mark(ci: CanvasItem, p: Vector2, alert: float) -> void:
	if alert <= 0.0:
		return
	var a = clamp(alert, 0.0, 1.0)
	ci.draw_string(UI.FONT_BOLD, p + Vector2(-8, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.85, 0.2, a))


# ボス（大きな影）
static func draw_boss(ci: CanvasItem, eid: String, p: Vector2, t: float) -> void:
	var d: Dictionary = DB.Enemies.DATA.get(eid, {})
	var col: Color = d.get("color", Color(0.5, 0.3, 0.5))
	for i in range(4):
		ci.draw_circle(p + Vector2(0, -50), 60.0 + i * 10 + sin(t * 2.0 + i) * 4.0, Color(0.3, 0.0, 0.1, 0.08))
	_shadow(ci, p, 48, 12, 0.4)
	var sheet: Texture2D = PixelArt.tex("field/boss_%s.png" % eid.trim_prefix("boss_"))
	if sheet:
		PixelArt.draw_strip(ci, sheet, int(t * 3.0), p + Vector2(0, -sheet.get_height() * PixelArt.SCALE / 2.0 + 6))
		return
	var bob = sin(t * 2.0) * 4.0
	var c = col.darkened(0.35)
	UI.poly(ci, PackedVector2Array([p + Vector2(-44, 0), p + Vector2(-50, -60 + bob), p + Vector2(-26, -104 + bob), p + Vector2(0, -116 + bob),
		p + Vector2(26, -104 + bob), p + Vector2(50, -60 + bob), p + Vector2(44, 0)]), c)
	UI.poly(ci, PackedVector2Array([p + Vector2(-30, -10), p + Vector2(-34, -60 + bob), p + Vector2(0, -96 + bob), p + Vector2(34, -60 + bob), p + Vector2(30, -10)]), col)
	var glow = 0.7 + sin(t * 4.0) * 0.3
	ci.draw_circle(p + Vector2(-12, -80 + bob), 5.0, Color(1.0, 0.3, 0.2, glow))
	ci.draw_circle(p + Vector2(12, -80 + bob), 5.0, Color(1.0, 0.3, 0.2, glow))


# ------------------------------------------------------------ 置物
static func draw_chest(ci: CanvasItem, p: Vector2, opened: bool, t: float) -> void:
	var sheet: Texture2D = PixelArt.tex("field/obj_chest.png")
	_shadow(ci, p, 24, 6)
	if sheet:
		PixelArt.draw_strip(ci, sheet, 1 if opened else 0, p + Vector2(0, -sheet.get_height() * PixelArt.SCALE / 2.0 + 2))
		return
	var body = Rect2(p + Vector2(-22, -30), Vector2(44, 28))
	ci.draw_rect(body, Color(0.62, 0.36, 0.16))
	ci.draw_rect(body, Color(0.35, 0.2, 0.1), false, 3.0)
	if opened:
		ci.draw_rect(Rect2(p + Vector2(-22, -44), Vector2(44, 12)), Color(0.45, 0.26, 0.12))
		ci.draw_rect(Rect2(p + Vector2(-18, -32), Vector2(36, 6)), Color(0.1, 0.06, 0.04))
	else:
		ci.draw_rect(Rect2(p + Vector2(-23, -42), Vector2(46, 14)), Color(0.7, 0.42, 0.2))
		ci.draw_rect(Rect2(p + Vector2(-23, -42), Vector2(46, 14)), Color(0.35, 0.2, 0.1), false, 3.0)
		ci.draw_rect(Rect2(p + Vector2(-4, -34), Vector2(8, 10)), Color(1.0, 0.82, 0.3))
		var sp = fmod(t, 2.4)
		if sp < 0.4:
			var a = 1.0 - sp / 0.4
			ci.draw_line(p + Vector2(14, -50), p + Vector2(14, -38), Color(1, 1, 0.8, a), 2.0)
			ci.draw_line(p + Vector2(8, -44), p + Vector2(20, -44), Color(1, 1, 0.8, a), 2.0)


static func draw_campfire(ci: CanvasItem, p: Vector2, used: bool, t: float) -> void:
	var sheet: Texture2D = PixelArt.tex("field/obj_campfire.png")
	if not used:
		ci.draw_circle(p + Vector2(0, -16), 46.0 + sin(t * 9.0) * 3.0, Color(1.0, 0.6, 0.2, 0.12))
	if sheet:
		PixelArt.draw_strip(ci, sheet, int(t * 8.0) if not used else 0, p + Vector2(0, -sheet.get_height() * PixelArt.SCALE / 2.0 + 2), Color.WHITE if not used else Color(0.45, 0.45, 0.5))
		return
	for i in range(5):
		var a = TAU * i / 5.0
		ci.draw_circle(p + Vector2(cos(a) * 18, sin(a) * 6 - 4), 6.0, Color(0.5, 0.5, 0.52))
	ci.draw_line(p + Vector2(-14, -4), p + Vector2(14, -10), Color(0.4, 0.25, 0.12), 6.0)
	ci.draw_line(p + Vector2(-14, -10), p + Vector2(14, -4), Color(0.45, 0.28, 0.14), 6.0)
	if used:
		ci.draw_circle(p + Vector2(0, -8), 6.0, Color(0.25, 0.22, 0.2))
		return
	for i in range(3):
		var fl = sin(t * 12.0 + i * 2.0) * 4.0
		var hh = 30.0 - i * 6.0 + fl
		UI.poly(ci, PackedVector2Array([p + Vector2(-12 + i * 4, -8), p + Vector2(0, -8 - hh - 10), p + Vector2(12 - i * 4, -8)]),
			[Color(1.0, 0.45, 0.1), Color(1.0, 0.7, 0.2), Color(1.0, 0.95, 0.6)][i])


static func draw_event_spot(ci: CanvasItem, p: Vector2, t: float) -> void:
	var sheet: Texture2D = PixelArt.tex("field/obj_event.png")
	if sheet:
		PixelArt.draw_strip(ci, sheet, int(t * 6.0), p + Vector2(0, -32))
		return
	var c = p + Vector2(0, -34 + sin(t * 3.0) * 5.0)
	ci.draw_circle(c, 22.0 + sin(t * 4.0) * 3.0, Color(0.7, 0.85, 1.0, 0.18))
	for i in range(4):
		var a = t * 1.5 + TAU * i / 4.0
		var q = c + Vector2(cos(a) * 18, sin(a) * 18)
		ci.draw_line(q - Vector2(0, 5), q + Vector2(0, 5), Color(1, 1, 1, 0.8), 2.0)
		ci.draw_line(q - Vector2(5, 0), q + Vector2(5, 0), Color(1, 1, 1, 0.8), 2.0)
	ci.draw_string(UI.FONT_BOLD, c + Vector2(-9, 11), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.85, 0.95, 1.0))
