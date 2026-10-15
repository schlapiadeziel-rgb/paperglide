extends "res://scripts/enemy_base.gd"
## Mortar bunker: stationary emplacement lobbing telegraphed shells at the
## commando's predicted position. Heavy: grapple zips in for a strike.

const P := preload("res://scripts/projectiles.gd")
var cooldown := 1.5
var recoil := 0.0


func _init() -> void:
	super()
	sheet = "mortar"
	kind_name = "mortar"
	body_size = Vector2(150, 110)
	max_hp = 18.0
	score_value = 500


func grapple_kind() -> String:
	return "heavy"


func grapple_kick(dmg: float, dir: Vector2) -> void:
	take_hit(dmg, dir, "kick")
	cooldown = maxf(cooldown, 1.6)


func _ai(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = maxf(0.0, recoil - delta * 4.0)
	velocity.x = 0.0
	face_player()
	var p := player()
	if p != null and player_alive() and cooldown <= 0.0 and on_screen(120.0) and absf(to_player().x) < 1150.0:
		_fire(p)
		cooldown = randf_range(2.4, 3.0) / rate_scale
	_gravity_move(delta)


func _fire(p: Node) -> void:
	var game := GS.game
	var from := global_position + Vector2(facing * 36.0, -104.0)
	var tx: float = p.global_position.x + p.velocity.x * 0.7
	var ty: float = game.ground_top(tx)
	if ty > GS.KILL_Y:
		tx = p.global_position.x
		ty = p.global_position.y
	var t := 1.35
	var g := 900.0
	var d := Vector2(tx, ty) - from
	var v := Vector2(d.x / t, (d.y - 0.5 * g * t * t) / t)
	game.proj.fire(P.K.MORTAR, from, v, P.TEAM_ENEMY, 20.0, {"radius": 80.0, "gravity": g})
	game.proj.add_marker(Vector2(tx, ty), t, 80.0)
	game.fx.muzzle(from, -PI * 0.5 + facing * 0.4, 0.9)
	game.fx.smoke(from, 5, 16.0)
	recoil = 1.0
	game.shake(2.5, 0.1)
	GS.sfx(&"rocket")


func _on_die(_how: String) -> void:
	var game := GS.game
	game.explode(center(), 120.0, 0.0, -2, 1.5)
	game.fx.chunks(center(), 16, Color("#6b5a48"))
	velocity = Vector2.ZERO


func _dead_physics(delta: float) -> void:
	dead_t += delta
	if int(dead_t * 20.0) % 4 == 0:
		GS.game.fx.smoke(center() + Vector2(randf_range(-50, 50), -20), 1, 20.0, Color(0.15, 0.13, 0.12, 0.6))
	alpha = clampf(1.0 - (dead_t - 1.6) / 0.8, 0.0, 1.0)
	if dead_t > 2.4:
		remove()


func _draw() -> void:
	var mod := Color(1, 1, 1, alpha)
	if dead:
		mod = Color(0.35, 0.3, 0.28, alpha)
	var squash := 1.0 - recoil * 0.05
	var base := Transform2D(0.0, Vector2(1.0 + recoil * 0.03, squash), 0.0, Vector2.ZERO)
	# Source art faces left.
	SpriteLib.draw(self, sheet, "bunker", Vector2.ZERO, facing > 0.0, 1.0, mod, 0.0, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
