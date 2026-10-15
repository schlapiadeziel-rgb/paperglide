extends Node2D
## Builds terrain collision (ground, one-way platforms, crate stacks) from
## level data and draws it in a single static canvas pass.

const GROUND_TEX := preload("res://assets/template/game/env/ground.webp")
const PLATFORM_TEX := preload("res://assets/template/game/env/platform.webp")
const GROUND_BY_THEME := {
	"town": "res://assets/template/game/env/ground.webp",
	"canyon": "res://assets/template/game/stage2/ground.webp",
	"fortress": "res://assets/template/game/stage3/ground.webp",
}
const LIP_BY_THEME := {
	"town": [Color("#e8b872"), Color("#fbe0a8")],
	"canyon": [Color("#c9683a"), Color("#f0a070")],
	"fortress": [Color("#8a8580"), Color("#c8c2b8")],
}
var grounds: Array = []
var platforms: Array = []
var blocks: Array = []
var _rocks: Array = []
var _stages: Array = [{"x0": -99999.0, "x1": 99999.0, "theme": "town"}]


func build(level: Dictionary) -> void:
	grounds = level.grounds
	platforms = level.platforms
	blocks = level.blocks
	if level.has("stages"):
		_stages = level.stages
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = -2
	for g in grounds:
		_solid(Rect2(g[0], g[2], g[1] - g[0], 900.0), false)
	for p in platforms:
		_solid(Rect2(p[0], p[1], p[2], 24.0), true)
	for b in blocks:
		_solid(Rect2(b[0], GS.GROUND_Y - b[2], b[1], b[2]), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for g in grounds:
		var x: float = g[0] + 20.0
		while x < g[1] - 20.0:
			_rocks.append([Vector2(x, g[2] + rng.randf_range(14, 60)), rng.randf_range(3, 9), rng.randf_range(0.0, 0.25)])
			x += rng.randf_range(30, 110)
	queue_redraw()


func _solid(r: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = GS.L_PLATFORM if one_way else GS.L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 12.0
	body.add_child(shape)
	if one_way:
		body.add_to_group("platform")
	add_child(body)


## Top of solid ground (not platforms) at x; large value over chasms.
func ground_top(x: float) -> float:
	for b in blocks:
		if x >= b[0] and x <= b[0] + b[1]:
			return GS.GROUND_Y - b[2]
	for g in grounds:
		if x >= g[0] and x <= g[1]:
			return g[2]
	return 99999.0


func _draw() -> void:
	var ink := GS.C_INK
	# chasm pits between consecutive ground segments
	for i in range(grounds.size() - 1):
		var x0: float = grounds[i][1]
		var x1: float = grounds[i + 1][0]
		if x1 - x0 < 4.0:
			continue
		var top: float = grounds[i][2] + 10.0
		for k in 10:
			draw_rect(Rect2(x0, top + k * 22.0, x1 - x0, 22.0), Color(0.22, 0.09, 0.05, 0.25 + k * 0.08))
		draw_rect(Rect2(x0, top + 220.0, x1 - x0, 600.0), Color(0.08, 0.03, 0.02))
		# jagged far cliff faces
		var pts_l := PackedVector2Array([Vector2(x0, top - 10), Vector2(x0 + 34, top + 60), Vector2(x0 + 18, top + 150), Vector2(x0 + 46, top + 260), Vector2(x0, top + 400)])
		var pts_r := PackedVector2Array([Vector2(x1, top - 10), Vector2(x1 - 30, top + 80), Vector2(x1 - 14, top + 170), Vector2(x1 - 42, top + 280), Vector2(x1, top + 400)])
		draw_colored_polygon(pts_l, Color(0.3, 0.13, 0.07, 0.9))
		draw_colored_polygon(pts_r, Color(0.3, 0.13, 0.07, 0.9))
	for g in grounds:
		var r := Rect2(g[0], g[2], g[1] - g[0], 500.0)
		# split the segment by stage so each stretch uses its own ground art
		for st in _stages:
			var sx0: float = maxf(r.position.x, float(st.x0))
			var sx1: float = minf(r.end.x, float(st.x1))
			if sx1 <= sx0:
				continue
			var theme := str(st.theme)
			var tex: Texture2D = SpriteLib.res(GROUND_BY_THEME.get(theme, "")) as Texture2D
			if tex == null:
				tex = GROUND_TEX
			var sub := Rect2(sx0, r.position.y, sx1 - sx0, r.size.y)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
			draw_texture_rect(tex, Rect2(sub.position * 2.0, sub.size * 2.0), true, Color(0.95, 0.9, 0.86))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var lip: Array = LIP_BY_THEME.get(theme, LIP_BY_THEME["town"])
			draw_rect(Rect2(sub.position.x, sub.position.y - 4.0, sub.size.x, 12.0), lip[0])
			draw_rect(Rect2(sub.position.x, sub.position.y - 4.0, sub.size.x, 3.0), lip[1])
		# depth shading toward the bottom
		for i in 6:
			draw_rect(Rect2(r.position.x, r.position.y + 90.0 + i * 50.0, r.size.x, 50.0), Color(0.12, 0.06, 0.03, 0.08 + i * 0.07))
		draw_rect(Rect2(r.position.x, r.position.y + 8.0, r.size.x, 4.0), Color(0.35, 0.2, 0.1, 0.55))
		# cliff edges
		draw_rect(Rect2(r.position.x, r.position.y - 4.0, 6.0, 500.0), Color(0.15, 0.08, 0.04, 0.6))
		draw_rect(Rect2(r.end.x - 6.0, r.position.y - 4.0, 6.0, 500.0), Color(0.15, 0.08, 0.04, 0.6))
	for rk in _rocks:
		draw_circle(rk[0], rk[1], Color(0.3, 0.18, 0.1, 0.35 + rk[2]))
		draw_circle(rk[0] + Vector2(-1, -1), rk[1] * 0.6, Color(0.95, 0.75, 0.5, 0.25))
	for p in platforms:
		var w: float = p[2]
		var pos := Vector2(p[0], p[1] - 6.0)
		draw_rect(Rect2(pos + Vector2(6, 34), Vector2(w - 12, 10)), Color(0, 0, 0, 0.25))
		# support struts
		for sx in [pos.x + 22.0, pos.x + w - 22.0]:
			draw_line(Vector2(sx, pos.y + 30), Vector2(sx, GS.GROUND_Y), Color(0.2, 0.15, 0.12, 0.75), 6.0)
			draw_line(Vector2(sx, pos.y + 30), Vector2(sx, GS.GROUND_Y), Color(0.45, 0.33, 0.25, 0.6), 2.0)
		draw_set_transform(pos, 0.0, Vector2(0.5, 0.5))
		draw_texture_rect(PLATFORM_TEX, Rect2(Vector2.ZERO, Vector2(w * 2.0, 80.0)), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in blocks:
		var x: float = b[0]
		var w2: float = b[1]
		var h: float = b[2]
		var rows := maxi(1, int(h / 48.0))
		var cell_h := h / rows
		var cols := maxi(1, int(round(w2 / 64.0)))
		var cell_w := w2 / cols
		for ry in rows:
			for cx in cols:
				var cell := Rect2(x + cx * cell_w, GS.GROUND_Y - (ry + 1) * cell_h, cell_w, cell_h)
				var base := Transform2D(0.0, Vector2(cell_w / 67.0, cell_h / 64.0), 0.0, Vector2(cell.get_center().x, cell.end.y))
				SpriteLib.draw(self, "props", "crate", Vector2.ZERO, (cx + ry) % 2 == 1, 1.0, Color(0.92, 0.9, 0.88), 0.0, base)
				draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(x, GS.GROUND_Y - h, w2, h), ink, false, 2.0)
