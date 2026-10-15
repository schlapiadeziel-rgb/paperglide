class_name SpriteLib
extends RefCounted
## Texture cache + pivot-aware drawing for the generated sprite frames.
## Frames are stored at 2x; SOURCE_SCALE maps them to world pixels.

const DB := preload("res://scripts/sprite_db.gd")

static var _cache: Dictionary = {}
static var _seg: Node = null

## Streamed textures (Stage 2/3) come from the Segments autoload; they are
## null until downloaded, and are never cached as null.
static func res(path: String) -> Resource:
	if _seg == null or not is_instance_valid(_seg):
		var tree := Engine.get_main_loop() as SceneTree
		_seg = tree.root.get_node_or_null("Segments") if tree != null else null
	if _seg != null and _seg.is_streamed(path):
		return _seg.get_res(path)
	return load(path)

static func tex(sheet: String, frame: String) -> Texture2D:
	var key := sheet + "/" + frame
	if _cache.has(key):
		return _cache[key]
	var entry: Array = DB.FRAMES[sheet][frame]
	var t := res(entry[0]) as Texture2D
	if t != null:
		_cache[key] = t
	return t

static func pivot(sheet: String, frame: String) -> Vector2:
	return DB.FRAMES[sheet][frame][1]

static func size(sheet: String, frame: String, scale: float = 1.0) -> Vector2:
	var t := tex(sheet, frame)
	return t.get_size() * DB.SOURCE_SCALE * scale if t != null else Vector2.ZERO

static func has(sheet: String, frame: String) -> bool:
	return DB.FRAMES.has(sheet) and DB.FRAMES[sheet].has(frame)

## Draw a frame so its pivot lands on `pos` (local coords of `ci`).
static func draw(ci: CanvasItem, sheet: String, frame: String, pos: Vector2, flip: bool = false, scale: float = 1.0, modulate: Color = Color.WHITE, rotation: float = 0.0, base: Transform2D = Transform2D.IDENTITY) -> void:
	if not has(sheet, frame):
		push_warning("SpriteLib: missing frame %s/%s" % [sheet, frame])
		return
	var t := tex(sheet, frame)
	if t == null:
		return
	var s := DB.SOURCE_SCALE * scale
	var p: Vector2 = DB.FRAMES[sheet][frame][1]
	ci.draw_set_transform_matrix(base * Transform2D(rotation, Vector2(-s if flip else s, s), 0.0, pos))
	ci.draw_texture(t, -p, modulate)
	ci.draw_set_transform_matrix(base)

const FLASH_SHADER := preload("res://assets/template/game/flash.gdshader")

## Give an entity its own hit-flash material (drive with set_shader_parameter("flash", v)).
static func flash_material(color: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("flash_color", color)
	return m

static func preload_all() -> void:
	for sheet in DB.FRAMES:
		for frame in DB.FRAMES[sheet]:
			tex(sheet, frame)

## Warm only the frames of the given sheets (boot-pack sheets at mission start).
static func warm(sheets: Array) -> void:
	for sheet in sheets:
		if DB.FRAMES.has(sheet):
			for frame in DB.FRAMES[sheet]:
				tex(sheet, frame)
