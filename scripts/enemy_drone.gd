extends "res://scripts/enemy_base.gd"
## Bomber drone: hovers above the commando and drops bombs. Can be grappled,
## carried and thrown — it explodes on impact.

const P := preload("res://scripts/projectiles.gd")
var cooldown := 1.2
var side := 1.0
var bob := 0.0
var drone_spin := 0.0


func _init() -> void:
	super()
	sheet = "drone"
	frame = "hover0"
	kind_name = "drone"
	body_size = Vector2(80, 52)
	max_hp = 3.0
	score_value = 150


func _ready() -> void:
	super()
	collision_mask = 0
	collision_layer = 0
	bob = randf() * TAU
	side = 1.0 if randf() < 0.5 else -1.0


func setup(pos: Vector2, data: Dictionary) -> void:
	super(pos, data)
	if data.get("enter", false):
		global_position = Vector2(GS.game.view_rect().end.x + 80.0, pos.y)


func _ai(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var p := player()
	var target := global_position
	if p != null and player_alive():
		target = p.center() + Vector2(side * 150.0, -250.0)
		var view: Rect2 = GS.game.view_rect()
		target.x = clampf(target.x, view.position.x + 60.0, view.end.x - 60.0)
		# stay in a readable band: below the HUD, above head height
		target.y = clampf(target.y, view.position.y + 175.0, GS.GROUND_Y - 300.0)
		if state_t > 3.2:
			side = -side
			state_t = 0.0
	target.y += sin(anim_t * 3.0 + bob) * 16.0
	var desired := (target - global_position).limit_length(1.0) * 260.0
	if (target - global_position).length() < 40.0:
		desired *= (target - global_position).length() / 40.0
	velocity = velocity.move_toward(desired, 700.0 * delta)
	global_position += velocity * delta
	facing = -1.0 if velocity.x < -10.0 else (1.0 if velocity.x > 10.0 else facing)
	frame = "hover%d" % (int(anim_t * 14.0) % 2)
	if p != null and player_alive() and cooldown <= 0.0 and on_screen(-20.0) and absf(p.global_position.x - global_position.x) < 70.0:
		cooldown = randf_range(1.5, 2.1) / rate_scale
		state = "drop"
		GS.game.proj.fire(P.K.BOMB, global_position + Vector2(0, 6), Vector2(velocity.x * 0.3, 80.0), P.TEAM_ENEMY, 14.0, {"radius": 66.0})
	if state == "drop":
		frame = "drop"
		if cooldown < 1.2:
			state = "hover"


func thrown_explodes() -> bool:
	return true


func thrown_damage() -> float:
	return 14.0


func _on_die(_how: String) -> void:
	drone_spin = randf_range(-6.0, 6.0)


func _dead_physics(delta: float) -> void:
	dead_t += delta
	velocity.y = minf(velocity.y + 1500.0 * delta, 1200.0)
	global_position += velocity * delta
	if int(dead_t * 30.0) % 3 == 0:
		GS.game.fx.smoke(center(), 1, 10.0)
	var gy: float = GS.game.ground_top(global_position.x)
	if global_position.y >= gy or dead_t > 3.0:
		if global_position.y < GS.KILL_Y:
			GS.game.explode(center(), 70.0, 4.0, 0, 0.7)
		remove()


func current_frame() -> String:
	if dead:
		return "wreck"
	if carry_state != "":
		return "hover%d" % (int(anim_t * 20.0) % 2)
	return frame


func _draw() -> void:
	var f := current_frame()
	var rot := 0.0
	if dead:
		rot = dead_t * drone_spin
	elif carry_state == "thrown":
		rot = thrown_t * 12.0
	else:
		rot = clampf(velocity.x / 260.0, -1.0, 1.0) * 0.18
	var off := Vector2(0, -body_size.y * 0.5)
	var base := Transform2D(rot, off) * Transform2D(0.0, -off)
	SpriteLib.draw(self, sheet, f, Vector2.ZERO, facing < 0.0, 0.9, Color.WHITE, 0.0, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
