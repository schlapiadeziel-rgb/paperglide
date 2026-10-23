extends Node2D
## Reuses the notebook illustration and overlays a selectable page pattern.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/world/notebook_background.png")
const GRID_SPACING := 36
const DOT_SPACING := 26


func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var page_size := get_viewport_rect().size
	if page_size.x <= 0.0 or page_size.y <= 0.0:
		return
	var page_rect := Rect2(Vector2.ZERO, page_size)
	draw_texture_rect(BACKGROUND_TEXTURE, page_rect, false)
	var theme_index := FlightPreferences.get_page_theme_index()
	if theme_index == 0:
		return
	# A light wash softens the printed ruling beneath the alternate page patterns.
	draw_rect(page_rect, Color(0.99, 0.975, 0.93, 0.34), true)
	if theme_index == 1:
		_draw_grid(page_size)
	elif theme_index == 2:
		_draw_dots(page_size)


func _draw_grid(page_size: Vector2) -> void:
	var ink := Color("#7299b2")
	ink.a = 0.24
	for x in range(0, int(page_size.x) + 1, GRID_SPACING):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), page_size.y), ink, 1.2, true)
	for y in range(0, int(page_size.y) + 1, GRID_SPACING):
		draw_line(Vector2(0.0, float(y)), Vector2(page_size.x, float(y)), ink, 1.2, true)


func _draw_dots(page_size: Vector2) -> void:
	var ink := Color("#7196aa")
	ink.a = 0.31
	for x in range(DOT_SPACING, int(page_size.x), DOT_SPACING):
		for y in range(DOT_SPACING, int(page_size.y), DOT_SPACING):
			draw_circle(Vector2(float(x), float(y)), 1.35, ink)
