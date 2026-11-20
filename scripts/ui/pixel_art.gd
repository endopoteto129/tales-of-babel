# ドット絵素材の差し替え口。res://assets/pixel/ に画像があればそれを使い、なければ図形で描く。
# 画像はすべて「1ドット＝画面の4ピクセル」（320×180 相当）で描かれている前提。
class_name PixelArt
extends RefCounted

const SCALE := 4.0
const ROOT := "res://assets/pixel/"

static var _cache := {}


# 相対パス（例 "field/chara_ren.png"）の画像。なければ null
static func tex(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var t: Texture2D = null
	var p := ROOT + rel
	if ResourceLoader.exists(p):
		t = load(p)
	_cache[rel] = t
	return t


static func has(rel: String) -> bool:
	return tex(rel) != null


# シート（cols×rows の等分割）の1コマを描く。anchor は「コマの下端中央」が来る位置
static func draw_cell(ci: CanvasItem, t: Texture2D, cols: int, rows: int, col: int, row: int, anchor: Vector2,
		flip: bool = false, mod: Color = Color.WHITE, k: float = SCALE) -> void:
	var cw: float = t.get_width() / float(cols)
	var ch: float = t.get_height() / float(rows)
	var src = Rect2(cw * (col % cols), ch * (row % rows), cw, ch)
	var size = Vector2(cw, ch) * k
	var dst = Rect2(anchor - Vector2(size.x / 2.0, size.y), size)
	if flip:
		ci.draw_set_transform(Vector2(anchor.x * 2.0, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(t, dst, src, mod)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(t, dst, src, mod)


# 正方形のコマを横に並べたシート（コマ数は 高さ から自動）の1コマ。中心に描く
static func draw_strip(ci: CanvasItem, t: Texture2D, frame: int, center: Vector2, mod: Color = Color.WHITE, k: float = SCALE, flip: bool = false) -> void:
	var n: int = max(1, int(t.get_width() / t.get_height()))
	var s: float = t.get_height()
	var src = Rect2(s * (frame % n), 0, s, s)
	var size = Vector2(s, s) * k
	var dst = Rect2(center - size / 2.0, size)
	if flip:
		ci.draw_set_transform(Vector2(center.x * 2.0, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(t, dst, src, mod)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(t, dst, src, mod)


static func strip_frames(t: Texture2D) -> int:
	return max(1, int(t.get_width() / t.get_height()))
