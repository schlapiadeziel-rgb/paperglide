class_name UIKit
extends RefCounted
## Fonts and small drawing/style helpers shared by HUD, menus and title.

const DISPLAY := preload("res://assets/template/game/fonts/BlackOpsOne-Regular.ttf")
const BOLD := preload("res://assets/template/game/fonts/ChakraPetch-Bold.ttf")
const SEMI := preload("res://assets/template/game/fonts/ChakraPetch-SemiBold.ttf")

const INK := Color("#1a0f0a")
const ORANGE := Color("#ff8a1f")
const YELLOW := Color("#ffd23f")
const RED := Color("#e63b2e")
const CYAN := Color("#46e0ff")
const CREAM := Color("#fff2d6")
const PANEL := Color(0.09, 0.07, 0.06, 0.86)


static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, outline: int = 6, outline_color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, size, outline, outline_color)
	ci.draw_string(font, pos, s, align, width, size, color)


static func text_w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func centered(ci: CanvasItem, font: Font, center_x: float, y: float, s: String, size: int, color: Color, outline: int = 6) -> void:
	var w := text_w(font, s, size)
	text(ci, font, Vector2(center_x - w * 0.5, y), s, size, color, outline)


## Slanted arcade panel.
static func panel(ci: CanvasItem, r: Rect2, fill: Color = PANEL, border: Color = ORANGE, slant: float = 10.0) -> void:
	var pts := PackedVector2Array([r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - slant, r.end.y), Vector2(r.position.x, r.end.y)])
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, border, 2.5)


## Keycap glyph, e.g. key(ci, pos, "J") -> returns width used.
static func key(ci: CanvasItem, pos: Vector2, label: String, size: int = 18) -> float:
	var w := maxf(size * 1.5, text_w(BOLD, label, size) + size * 0.8)
	var h := size * 1.45
	var r := Rect2(pos + Vector2(0, -h * 0.78), Vector2(w, h))
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.5))
	ci.draw_rect(r, CREAM)
	ci.draw_rect(r, INK, false, 2.0)
	text(ci, BOLD, Vector2(r.position.x + (w - text_w(BOLD, label, size)) * 0.5, pos.y), label, size, INK, 0)
	return w


## Draw a tip string where [X] segments become keycaps.
static func rich_tip(ci: CanvasItem, center_x: float, y: float, s: String, size: int = 20) -> void:
	var parts := _split_tip(s)
	var total := 0.0
	for p in parts:
		total += (maxf(size * 1.5, text_w(BOLD, p[1], size) + size * 0.8) + 6.0) if p[0] else text_w(BOLD, p[1], size)
	var x := center_x - total * 0.5
	for p in parts:
		if p[0]:
			if p[1].begins_with("RED"):
				text(ci, BOLD, Vector2(x, y), p[1], size, RED, 5)
				x += text_w(BOLD, p[1], size)
			else:
				x += key(ci, Vector2(x, y), p[1], size) + 6.0
		else:
			text(ci, BOLD, Vector2(x, y), p[1], size, CREAM, 5)
			x += text_w(BOLD, p[1], size)


static func _split_tip(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		var a := s.find("[", i)
		if a < 0:
			out.append([false, s.substr(i)])
			break
		if a > i:
			out.append([false, s.substr(i, a - i)])
		var b := s.find("]", a)
		if b < 0:
			out.append([false, s.substr(a)])
			break
		out.append([true, s.substr(a + 1, b - a - 1)])
		i = b + 1
	return out


static func style_button(b: Button, size: int = 26) -> void:
	b.add_theme_font_override("font", DISPLAY)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 4)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.09, 0.07, 0.92)
	normal.border_color = ORANGE
	normal.set_border_width_all(3)
	normal.skew = Vector2(0.18, 0)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = YELLOW
	hot.border_color = CREAM
	var pressed := hot.duplicate() as StyleBoxFlat
	pressed.bg_color = ORANGE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", pressed)
	b.focus_mode = Control.FOCUS_ALL
