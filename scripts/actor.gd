extends CharacterBody2D
## Shared base for anything the commando can grapple, carry and throw
## (enemies and props). Origin = feet / bottom-centre.

signal removed

var hp := 1.0
var max_hp := 1.0
var body_size := Vector2(40, 90)
var is_enemy := false
var dead := false
## "" (free), "reeled", "carried", "thrown"
var carry_state := ""
var holder: Node = null
var thrown_by: Node = null
var thrown_t := 0.0
var flash_t := 0.0
var gravity_force := 2100.0
var mat: ShaderMaterial
var _hit_list: Array = []


func _init() -> void:
	collision_layer = GS.L_ENEMY
	collision_mask = GS.L_WORLD | GS.L_PLATFORM
	floor_snap_length = 8.0
	safe_margin = 0.5


func _ready() -> void:
	mat = SpriteLib.flash_material()
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(16.0, body_size.x - 8.0), body_size.y)
	shape.shape = rect
	shape.position = Vector2(0, -body_size.y * 0.5)
	add_child(shape)


func hurt_rect() -> Rect2:
	return Rect2(global_position - Vector2(body_size.x * 0.5, body_size.y), body_size)


func center() -> Vector2:
	return global_position - Vector2(0, body_size.y * 0.5)


func is_targetable() -> bool:
	return not dead and carry_state == ""


func grapple_kind() -> String:
	return "light"


func flash(amount: float = 1.0) -> void:
	flash_t = 0.1 * amount


func _tick_flash(delta: float) -> void:
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta)
		mat.set_shader_parameter("flash", clampf(flash_t / 0.1, 0.0, 1.0) * 0.85)
	elif mat != null:
		mat.set_shader_parameter("flash", 0.0)


# ---- grapple / carry lifecycle -------------------------------------------

func on_grappled(by: Node) -> void:
	carry_state = "reeled"
	holder = by
	collision_mask = 0
	collision_layer = 0
	velocity = Vector2.ZERO


## Pull toward the holder's hand; returns true on arrival.
func reel_to(target: Vector2, delta: float) -> bool:
	global_position = global_position.move_toward(target, 1700.0 * delta)
	return global_position.distance_to(target) < 26.0


func set_carried(by: Node) -> void:
	carry_state = "carried"
	holder = by
	z_index = 12


func carry_update(pos: Vector2, _facing: float) -> void:
	global_position = pos


## Released without throwing (holder died/was hit).
func release_drop() -> void:
	carry_state = ""
	holder = null
	z_index = 0
	collision_layer = GS.L_ENEMY if is_enemy else GS.L_PROPS
	collision_mask = GS.L_WORLD | GS.L_PLATFORM
	velocity = Vector2(0, -120)


func thrown(vel: Vector2, by: Node) -> void:
	carry_state = "thrown"
	thrown_by = by
	thrown_t = 0.0
	holder = null
	z_index = 12
	velocity = vel
	collision_layer = 0
	collision_mask = GS.L_WORLD
	_hit_list.clear()


func _thrown_physics(delta: float) -> void:
	thrown_t += delta
	velocity.y += 1700.0 * delta
	var game := GS.game
	var my := hurt_rect().grow(6.0)
	if game != null:
		for t in game.targets():
			if t == self or t in _hit_list or not is_instance_valid(t):
				continue
			if my.intersects(t.hurt_rect()):
				_hit_list.append(t)
				if impact(t):
					return
	var motion := velocity * delta
	var col := move_and_collide(motion)
	if col != null:
		impact(null)
		return
	if thrown_t > 3.0 or global_position.y > GS.KILL_Y:
		impact(null)


## Thrown object struck `target` (or terrain when null). Return true if this
## object is consumed and should stop simulating this frame.
func impact(_target: Node) -> bool:
	return true


func take_hit(_dmg: float, _dir: Vector2, _kind: String) -> String:
	return "none"


func hostage_hit(_dmg: float) -> void:
	pass


func remove() -> void:
	removed.emit()
	queue_free()
