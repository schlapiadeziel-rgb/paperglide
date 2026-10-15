extends Node2D
## Static background set dressing, per stage sheet (decor / decor_canyon /
## decor_fortress). Rows: [sheet, frame, x, y(bottom), scale, flip].
## Stage 2/3 sheets are streamed: missing textures are skipped and the game
## calls queue_redraw() when a segment arrives.

var items: Array = []


func build(list: Array) -> void:
	items = list
	z_index = -3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	for d in items:
		var sheet: String = d[0]
		var frame: String = d[1]
		var pos := Vector2(float(d[2]), float(d[3]))
		var sc: float = float(d[4])
		if SpriteLib.tex(sheet, frame) == null:
			continue
		var w: float = SpriteLib.size(sheet, frame, sc).x
		draw_set_transform(pos + Vector2(0, -4), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, w * 0.42, Color(0.1, 0.05, 0.02, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		SpriteLib.draw(self, sheet, frame, pos, bool(d[5]), sc, Color(0.93, 0.9, 0.88))
