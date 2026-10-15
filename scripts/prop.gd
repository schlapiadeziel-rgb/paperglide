extends "res://scripts/actor.gd"
## Carryable, throwable, shootable props: crate, barrel and fuel tank
## (explosive, chain-react), ammo crate. Damaged explosives catch fire,
## scare nearby grunts and cook off after a short fuse.

const EXPLOSIVE := {"barrel": true, "fuel_tank": true}

var kind := "crate"
var content := ""
var bob_t := 0.0
var spin := 0.0
var burning := false
var fuse := 0.0
var chain_n := 0
var ignite_t := -1.0
var _scare_t := 0.0


func setup(pos: Vector2, data: Dictionary) -> void:
	global_position = pos
	kind = str(data.get("kind", "crate"))
	content = str(data.get("content", ""))
	match kind:
		"barrel":
			body_size = Vector2(44, 72)
			max_hp = 4.0
		"fuel_tank":
			body_size = Vector2(48, 82)
			max_hp = 6.0
		"ammo_crate":
			body_size = Vector2(64, 52)
			max_hp = 7.0
			if content.is_empty():
				content = "grenades"
		_:
			body_size = Vector2(62, 60)
			max_hp = 3.0
	hp = max_hp


func _init() -> void:
	super()
	is_enemy = false
	collision_layer = GS.L_PROPS


func _ready() -> void:
	super()
	collision_layer = GS.L_PROPS


func is_explosive() -> bool:
	return EXPLOSIVE.has(kind)


func _physics_process(delta: float) -> void:
	_tick_flash(delta)
	bob_t += delta
	if ignite_t >= 0.0:
		ignite_t -= delta
		if ignite_t < 0.0:
			_destroy(Vector2.UP)
			return
	if burning and not dead:
		fuse -= delta
		_scare_t -= delta
		if _scare_t <= 0.0:
			_scare_t = 0.35
			if GS.game != null:
				GS.game.panic_near(center(), 300.0, 1.2)
				GS.game.fx.flame_lick(global_position + Vector2(randf_range(-10, 10), -body_size.y + 4.0))
		if fuse <= 0.0:
			_destroy(Vector2.UP)
			return
	match carry_state:
		"reeled", "carried":
			queue_redraw()
			return
		"thrown":
			_thrown_physics(delta)
			queue_redraw()
			return
	velocity.y = minf(velocity.y + gravity_force * delta, 1400.0)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	move_and_slide()
	if global_position.y > GS.KILL_Y:
		remove()
	queue_redraw()


func take_hit(dmg: float, dir: Vector2, kind_hit: String) -> String:
	if dead or carry_state != "":
		return "none"
	hp -= dmg
	flash()
	var game := GS.game
	if kind_hit == "bullet" and game != null:
		game.fx.debris(center(), 2, _debris_color(), 220.0, 5.0)
		if kind == "fuel_tank" or kind == "barrel":
			game.fx.impact_spark(center() + Vector2(-dir.x * body_size.x * 0.4, randf_range(-12, 12)), -dir)
			GS.sfx_var(&"metal", 3)
	if hp <= 0.0:
		_destroy(dir)
	elif is_explosive() and not burning and hp < max_hp * 0.75:
		_catch_fire()
	return "hit"


func _catch_fire() -> void:
	burning = true
	fuse = 2.2 if kind == "barrel" else 2.8
	if GS.game != null:
		GS.game.panic_near(center(), 320.0, 1.6)


## Chain reaction entry: a nearby blast lights this explosive after a beat.
func ignite(n: int, delay: float) -> void:
	if dead or ignite_t >= 0.0:
		return
	chain_n = n
	ignite_t = delay
	burning = true
	fuse = maxf(fuse, delay + 0.05)
	flash()


func _debris_color() -> Color:
	match kind:
		"barrel":
			return Color("#b03a22")
		"fuel_tank":
			return Color("#c9a13a")
		"ammo_crate":
			return Color("#5f6b34")
	return Color("#a0703a")


func _destroy(_dir: Vector2) -> void:
	if dead:
		return
	dead = true
	var game := GS.game
	if kind == "barrel":
		game.explode(center(), 140.0, 14.0, -1, 1.3, chain_n)
		game.fx.scorch(global_position)
		game.fx.fire_patch(global_position, 1.6)
	elif kind == "fuel_tank":
		game.explode(center() + Vector2(0, -10), 200.0, 20.0, -1, 1.8, chain_n)
		game.fx.scorch(global_position, 1.5)
		game.fx.fire_patch(global_position, 3.2)
		game.fx.mushroom(center())
	else:
		game.fx.debris(center(), 14, _debris_color(), 420.0, 9.0)
		game.fx.splinters(center(), 1.0)
		game.fx.dust(global_position, 6)
		GS.sfx_var(&"crash", 2)
		if not content.is_empty():
			game.spawn_pickup(content, center() + Vector2(0, -10), true)
		game.add_score(50, center(), "")
	remove()


func impact(target: Node) -> bool:
	var game := GS.game
	var dir := velocity.normalized()
	if is_explosive():
		_destroy(dir)
		return true
	if target != null:
		target.take_hit(9.0 if kind == "crate" else 12.0, dir, "thrown")
		game.shake(5.0, 0.15)
		game.hitstop(0.05)
		game.fx.popup(center() + Vector2(0, -30), "CRUNCH!", GS.C_ORANGE, 24)
		GS.sfx_var(&"punch", 3)
	_destroy(dir)
	return true


func current_frame() -> String:
	return kind


func _draw() -> void:
	var rot := 0.0
	if carry_state == "thrown":
		rot = thrown_t * 10.0 * signf(velocity.x)
	var off := Vector2(0, -body_size.y * 0.5)
	var base := Transform2D(rot, off) * Transform2D(0.0, -off)
	var sheet := "props2" if kind == "fuel_tank" else "props"
	var mod := Color.WHITE
	if burning:
		var k := 0.5 + 0.5 * sin(bob_t * (26.0 if ignite_t >= 0.0 else 14.0))
		mod = Color(1.0, 0.8 + 0.2 * k, 0.7 + 0.3 * k)
	SpriteLib.draw(self, sheet, kind, Vector2.ZERO, false, 1.0, mod, 0.0, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if burning and carry_state == "" and not dead:
		# flickering flame tongue + fuse ring
		var fl := 0.85 + 0.25 * sin(bob_t * 31.0)
		SpriteLib.draw(self, "vfx_b", "flame", Vector2(0, -body_size.y + 6.0), false, 0.42 * fl, Color(1, 1, 1, 0.95))
		var frac := clampf(fuse / 2.8, 0.0, 1.0)
		draw_arc(Vector2(0, -body_size.y - 26.0), 9.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, Color(1, 0.35, 0.1, 0.9), 3.0)
	elif is_explosive() and carry_state == "" and not dead:
		# idle glint so explosives read as "shoot me"
		var g := fmod(bob_t * 0.45 + global_position.x * 0.001, 1.0)
		if g < 0.12:
			SpriteLib.draw(self, "vfx_a", "glint", Vector2(-8, -body_size.y * 0.7), false, 0.3 * (1.0 - absf(g - 0.06) / 0.06), Color(1, 1, 1, 0.9))
