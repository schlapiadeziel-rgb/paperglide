extends Node2D
## Screen-space parallax per stage theme (town / canyon / fortress).
## Far sky + mid silhouettes; tiles alternate mirrored copies so
## non-tileable art loops without seams. Stage 2/3 art is streamed through
## Segments: a theme whose textures have not arrived yet keeps showing the
## previous one, then crossfades in when refresh() is called.

const THEMES := {
	"town": {"far": "res://assets/template/game/env/bg_far.webp", "mid": "res://assets/template/game/env/bg_mid.webp", "haze": Color(1.0, 0.75, 0.45, 0.07), "sky": Color("#f0a860")},
	"canyon": {"far": "res://assets/template/game/stage2/bg_far.webp", "mid": "res://assets/template/game/stage2/bg_mid.webp", "haze": Color(1.0, 0.55, 0.3, 0.09), "sky": Color("#e07848")},
	"fortress": {"far": "res://assets/template/game/stage3/bg_far.webp", "mid": "res://assets/template/game/stage3/bg_mid.webp", "haze": Color(0.9, 0.45, 0.35, 0.1), "sky": Color("#8a4a3a")},
}

var cam := Vector2(640, 360)
var tint := Color.WHITE
var theme := "town"
var prev_theme := ""
var fade := 1.0
var _wanted := "town"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_theme(t: String, instant: bool) -> void:
	_wanted = t
	if instant:
		theme = t
		prev_theme = ""
		fade = 1.0
	else:
		_try_switch()


func refresh() -> void:
	_try_switch()


func _try_switch() -> void:
	if _wanted == theme:
		return
	if _tex(_wanted, "far") == null or _tex(_wanted, "mid") == null:
		return
	prev_theme = theme
	theme = _wanted
	fade = 0.0


func _tex(t: String, layer: String) -> Texture2D:
	var d: Dictionary = THEMES.get(t, THEMES.town)
	var path: String = d[layer]
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex := SpriteLib.res(path) as Texture2D
	if tex == null:
		return null
	# Wide lossy-imported backdrops can upload blank on some GL drivers;
	# re-upload them once from their decoded image.
	if tex is CompressedTexture2D:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


var _tex_cache: Dictionary = {}


func _process(delta: float) -> void:
	if GS.game != null:
		cam = GS.game.cam_pos()
	if fade < 1.0:
		fade = minf(1.0, fade + delta / 1.4)
		if fade >= 1.0:
			prev_theme = ""
	queue_redraw()


func _layer(tex: Texture2D, scale: float, factor: float, y: float, col: Color) -> void:
	var w := tex.get_width() * scale
	var h := tex.get_height() * scale
	var scroll := cam.x * factor
	var idx := int(floor(scroll / w))
	var x := -(scroll - idx * w)
	while x < GS.VIEW_W:
		var mirrored := posmod(idx, 2) == 1
		if mirrored:
			draw_set_transform(Vector2(x + w, y), 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, Rect2(0, 0, w, h), false, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, Rect2(x, y, w, h), false, col)
		x += w
		idx += 1


func _draw_theme(t: String, alpha: float) -> void:
	var far := _tex(t, "far")
	var mid := _tex(t, "mid")
	var d: Dictionary = THEMES.get(t, THEMES.town)
	var dy := cam.y - 360.0
	var col := Color(tint, alpha)
	if far != null:
		_layer(far, 0.86, 0.06, -40.0 - dy * 0.05, col)
	else:
		draw_rect(Rect2(0, 0, GS.VIEW_W, GS.VIEW_H), Color(d.sky, alpha))
	var hz: Color = d.haze
	draw_rect(Rect2(0, 380, GS.VIEW_W, 200), Color(hz, hz.a * alpha))
	if mid != null:
		var mid_s := 0.78
		var mh := mid.get_height() * mid_s
		var ground_screen := GS.GROUND_Y - dy
		_layer(mid, mid_s, 0.28, ground_screen + 30.0 - mh + dy * 0.25, col)


func _draw() -> void:
	if prev_theme != "" and fade < 1.0:
		_draw_theme(prev_theme, 1.0)
		_draw_theme(theme, ease(fade, 0.6))
	else:
		_draw_theme(theme, 1.0)
