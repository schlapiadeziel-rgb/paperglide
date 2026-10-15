extends CanvasLayer
## Drives post.gdshader: shockwaves, aberration kicks, hurt/low-HP vignette,
## screen flashes and the FURY grade. Sits above the world, below the HUD.

const SHADER := preload("res://assets/template/game/post.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var waves: Array = []           # [uv, age, strength]
var aberr := 0.0
var hurt_v := 0.0
var low_hp := 0.0
var flash_v := 0.0
var flash_col := Color.WHITE
var fury := 0.0
var fury_target := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)


func _enabled() -> bool:
	return GS.tuning("post_fx", 1.0) > 0.5


func shockwave(world_pos: Vector2, strength: float = 1.0) -> void:
	if GS.reduced_motion() or not _enabled():
		return
	var vp := get_viewport()
	var sp: Vector2 = vp.get_canvas_transform() * world_pos
	var uv := sp / vp.get_visible_rect().size
	if uv.x < -0.3 or uv.x > 1.3 or uv.y < -0.3 or uv.y > 1.3:
		return
	if waves.size() >= 4:
		waves.remove_at(0)
	waves.append([uv, 0.0, clampf(strength, 0.2, 1.6)])
	aberr = maxf(aberr, 0.004 * strength)


func kick(amount: float) -> void:
	aberr = maxf(aberr, amount)


func hurt(amount: float = 1.0) -> void:
	hurt_v = maxf(hurt_v, 0.55 * amount)
	aberr = maxf(aberr, 0.006 * amount)


func flash(color: Color, amount: float) -> void:
	if GS.reduced_motion():
		amount *= 0.4
	flash_col = color
	flash_v = maxf(flash_v, amount)


func _process(delta: float) -> void:
	_t += delta
	var real := delta / maxf(Engine.time_scale, 0.05)
	for w in waves:
		w[1] += real / 0.55
	waves = waves.filter(func(w): return w[1] < 1.0)
	aberr = move_toward(aberr, 0.0, real * 0.03)
	hurt_v = move_toward(hurt_v, 0.0, real * 1.6)
	flash_v = move_toward(flash_v, 0.0, real * 3.2)
	fury = move_toward(fury, fury_target, real * 2.5)
	rect.visible = _enabled()
	if not rect.visible:
		return
	var arr: Array = []
	for i in 4:
		if i < waves.size():
			var w: Array = waves[i]
			arr.append(Vector4(w[0].x, w[0].y, w[1], w[2]))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	var sz := get_viewport().get_visible_rect().size
	mat.set_shader_parameter("waves", arr)
	mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	mat.set_shader_parameter("aberration", aberr)
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	mat.set_shader_parameter("vignette", maxf(hurt_v, low_hp * (0.22 + 0.18 * pulse)))
	mat.set_shader_parameter("flash", flash_v)
	mat.set_shader_parameter("flash_color", flash_col)
	mat.set_shader_parameter("fury", fury)
	mat.set_shader_parameter("time_s", _t)
