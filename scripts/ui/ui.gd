# UI 共通ヘルパー（テーマ・ラベル・ボタン・パネル）
class_name UI
extends RefCounted

const FONT := preload("res://assets/fonts/NotoSansJP-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/NotoSansJP-Bold.ttf")

const C_PANEL := Color(0.07, 0.08, 0.14, 0.92)
const C_BORDER := Color(0.85, 0.7, 0.4)
const C_TEXT := Color(0.96, 0.94, 0.9)
const C_DIM := Color(0.65, 0.65, 0.7)
const C_GOLD := Color(1.0, 0.85, 0.4)
const C_RED := Color(1.0, 0.4, 0.35)
const C_GREEN := Color(0.5, 1.0, 0.6)
const C_BLUE := Color(0.5, 0.75, 1.0)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t = Theme.new()
	t.default_font = FONT
	t.default_font_size = 20
	var normal = box(Color(0.12, 0.13, 0.2, 0.95), Color(0.5, 0.45, 0.35), 2, 6)
	var hover = box(Color(0.22, 0.2, 0.28, 0.98), C_BORDER, 2, 6)
	var pressed = box(Color(0.3, 0.25, 0.2, 1.0), C_GOLD, 2, 6)
	var disabled = box(Color(0.1, 0.1, 0.12, 0.8), Color(0.3, 0.3, 0.3), 2, 6)
	for st in [normal, hover, pressed, disabled]:
		st.content_margin_left = 16
		st.content_margin_right = 16
		st.content_margin_top = 8
		st.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_GOLD)
	t.set_color("font_focus_color", "Button", C_GOLD)
	t.set_color("font_pressed_color", "Button", C_GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	t.set_stylebox("panel", "Panel", box(C_PANEL, C_BORDER, 2, 10))
	t.set_stylebox("panel", "PanelContainer", box(C_PANEL, C_BORDER, 2, 10))
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_font("normal_font", "RichTextLabel", FONT)
	t.set_font("bold_font", "RichTextLabel", FONT_BOLD)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.3, 0.35, 0.5)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab = StyleBoxFlat.new()
	grab.bg_color = C_BORDER
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = t
	return t


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size: int = 20, color: Color = C_TEXT, bold: bool = false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", FONT_BOLD)
	return l


static func outlined(l: Label, outline: int = 6, oc: Color = Color(0, 0, 0, 0.85)) -> Label:
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", oc)
	return l


static func button(text: String, cb: Callable, size: int = 20) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void:
		Sfx.play("confirm")
		cb.call())
	b.focus_entered.connect(func() -> void: Sfx.play("select"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


static func panel(bg: Color = C_PANEL, border: Color = C_BORDER) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 2, 10))
	return p


static func rich(text: String, size: int = 20) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	return r


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func bar(parent: Control, rect: Rect2, ratio: float, fg: Color, bg: Color = Color(0, 0, 0, 0.6)) -> void:
	parent.draw_rect(rect, bg)
	parent.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(ratio, 0.0, 1.0), rect.size.y)), fg)


static func focus_first(container: Node) -> void:
	for c in container.get_children():
		if c is Button and not c.disabled:
			c.grab_focus.call_deferred()
			return
		if c is Container:
			for cc in c.get_children():
				if cc is Button and not cc.disabled:
					cc.grab_focus.call_deferred()
					return


# 自己交差などで三角形分割できない多角形は描かない（エラー防止）
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() >= 4:
			ci.draw_colored_polygon(hull, col)
		return
	ci.draw_colored_polygon(pts, col)


# 操作ボタンの表示を含む文字列を、入力方法が切り替わるたびに作り直す
static func live_text(node: Control, make: Callable) -> void:
	node.text = make.call()
	var cb = func() -> void:
		if is_instance_valid(node):
			node.text = make.call()
	Game.input_mode_changed.connect(cb)
	node.tree_exiting.connect(func() -> void:
		if Game.input_mode_changed.is_connected(cb):
			Game.input_mode_changed.disconnect(cb))
