extends Node2D
## Item pickup: medkit, grenades, shield, hmg, spread, rocket, medal, gold.

const LABELS := {
	"medkit": "MEDKIT", "grenades": "GRENADES +5", "shield": "BARRIER CELL",
	"hmg": "HEAVY MG!", "spread": "SPREAD GUN!", "rocket": "ROCKETS!",
	"medal": "+500", "gold": "+1000",
}

var kind := "medkit"
var vel := Vector2.ZERO
var falling := false
var ground_y := 0.0
var t := 0.0
var life := -1.0
var magnet: Node = null
var collected := false


func setup(k: String, pos: Vector2, pop: bool) -> void:
	kind = k
	global_position = pos
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if pop:
		vel = Vector2(randf_range(-70, 70), -420)
		falling = true
		life = 14.0
	_find_ground()


func _find_ground() -> void:
	var space := get_world_2d().direct_space_state if is_inside_tree() else null
	ground_y = GS.KILL_Y + 100.0
	if space == null:
		return
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -20), global_position + Vector2(0, 1400), GS.L_WORLD | GS.L_PLATFORM)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		ground_y = hit.position.y - 4.0
		if not falling and global_position.y < ground_y - 4.0:
			falling = true


func _ready() -> void:
	_find_ground()


func radius() -> float:
	return 30.0


func _physics_process(delta: float) -> void:
	t += delta
	var p = GS.game.player if GS.game != null else null
	if magnet != null and is_instance_valid(magnet):
		global_position = global_position.move_toward(magnet.center(), 1500.0 * delta)
	elif falling:
		vel.y += 1600.0 * delta
		global_position += vel * delta
		if global_position.y >= ground_y and vel.y > 0.0:
			global_position.y = ground_y
			if absf(vel.y) > 250.0:
				vel = Vector2(vel.x * 0.5, -vel.y * 0.35)
			else:
				falling = false
				vel = Vector2.ZERO
		if global_position.y > GS.KILL_Y:
			queue_free()
			return
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	if p != null and p.is_hittable() and not collected:
		if p.hurt_rect().grow(18.0).has_point(global_position + Vector2(0, -20)):
			collected = true
			p.collect(kind)
			GS.game.fx.popup(global_position + Vector2(0, -50), LABELS.get(kind, kind.to_upper()), GS.C_YELLOW if kind in ["medal", "gold"] else GS.C_CYAN, 22)
			GS.game.fx.ring(global_position + Vector2(0, -20), 50.0, Color(1, 0.95, 0.5, 0.9), 0.25)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if life > 0.0 and life < 3.0 and int(t * 10.0) % 2 == 0:
		return
	var bob := 0.0 if falling else sin(t * 4.0) * 4.0 - 4.0
	var glow := 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(Vector2(0, -22 + bob), 30.0, Color(1.0, 0.9, 0.4, 0.12 + 0.1 * glow))
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	SpriteLib.draw(self, "items", kind, Vector2(0, -22 + bob), false, 0.8)
