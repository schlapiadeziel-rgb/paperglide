extends "res://scripts/actor.gd"
## Common enemy behaviour: facing, animation clock, damage, death fling,
## thrown-body impacts, ledge checks and player queries.

var sheet := "grunt"
var frame := "walk0"
var facing := -1.0
var state := "idle"
var state_t := 0.0
var anim_t := 0.0
var score_value := 100
var kind_name := "grunt"
var draw_scale := 1.0
var dead_t := 0.0
var alpha := 1.0
var home_x := 0.0
var patrol_range := 90.0
var stun_t := 0.0
var contact_damage := 0.0
var contact_cd := 0.0
var wave_tag := ""
var dmg_scale := 1.0
var rate_scale := 1.0
var panic_t := 0.0
var panic_x := 0.0
var spin := 0.0
var spin_angle := 0.0
var spot_t := -1.0       # >= 0 while the "!" spot bubble shows
var spotted := false
var launched_by_blast := false


func _init() -> void:
	super()
	is_enemy = true


func setup(pos: Vector2, data: Dictionary) -> void:
	global_position = pos
	home_x = pos.x
	facing = float(data.get("facing", -1.0))
	wave_tag = str(data.get("wave", ""))


func _ready() -> void:
	super()
	var hs := GS.tuning("enemy_health_scale", 1.0)
	max_hp *= hs
	hp = max_hp
	dmg_scale = 1.0
	rate_scale = GS.tuning("enemy_fire_rate", 1.0)


func player() -> Node:
	return GS.game.player if GS.game != null else null


func to_player() -> Vector2:
	var p := player()
	if p == null:
		return Vector2(9999, 0)
	return p.center() - center()


func player_alive() -> bool:
	var p := player()
	return p != null and p.is_hittable()


func face_player() -> void:
	var d := to_player()
	if absf(d.x) > 8.0:
		facing = signf(d.x)


func on_screen(margin: float = 0.0) -> bool:
	return GS.game != null and GS.game.view_rect().grow(margin).has_point(center())


## True if there is floor ahead in `dir` (so walkers don't step off ledges).
func floor_ahead(dir: float, dist: float = 26.0) -> bool:
	var from := global_position + Vector2(dir * (body_size.x * 0.5 + dist), -10)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 60), GS.L_WORLD | GS.L_PLATFORM)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func wall_ahead(dir: float) -> bool:
	var from := global_position + Vector2(0, -body_size.y * 0.5)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (body_size.x * 0.5 + 14.0), 0), GS.L_WORLD)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	_tick_flash(delta)
	anim_t += delta
	contact_cd = maxf(0.0, contact_cd - delta)
	match carry_state:
		"reeled", "carried":
			queue_redraw()
			return
		"thrown":
			_thrown_physics(delta)
			queue_redraw()
			return
	if dead:
		_dead_physics(delta)
		queue_redraw()
		return
	state_t += delta
	stun_t = maxf(0.0, stun_t - delta)
	panic_t = maxf(0.0, panic_t - delta)
	if spot_t >= 0.0:
		spot_t += delta
		if spot_t > 0.7:
			spot_t = -1.0
	_ai(delta)
	if contact_damage > 0.0 and contact_cd <= 0.0 and player_alive():
		var p := player()
		if hurt_rect().grow(-6.0).intersects(p.hurt_rect()):
			p.take_damage(contact_damage, Vector2(signf(p.global_position.x - global_position.x), -0.3))
			contact_cd = 0.8
	queue_redraw()


func _ai(_delta: float) -> void:
	pass


func _gravity_move(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity_force * delta, 1400.0)
	move_and_slide()


func take_hit(dmg: float, dir: Vector2, kind: String) -> String:
	if dead or carry_state != "":
		return "none"
	hp -= dmg
	flash()
	GS.sfx(&"hit")
	if hp <= 0.0:
		die(dir, kind)
	else:
		_on_hurt(dir, kind)
	return "hit"


func _on_hurt(_dir: Vector2, _kind: String) -> void:
	pass


## Called by the game when a lit grenade / burning barrel lands nearby.
func scare(from_x: float, time: float) -> void:
	if dead or carry_state != "" or not can_panic():
		return
	if panic_t <= 0.0:
		GS.sfx(&"panic")
	panic_t = maxf(panic_t, time)
	panic_x = from_x


func can_panic() -> bool:
	return false


## First time this enemy sees the player: "!" pop and alert the squad.
func on_spotted() -> void:
	if spotted:
		return
	spotted = true
	spot_t = 0.0
	if GS.game != null:
		GS.game.alert_squad(self)


func alerted() -> void:
	spotted = true


func die(dir: Vector2, how: String) -> void:
	if dead:
		return
	dead = true
	state = "dead"
	dead_t = 0.0
	collision_layer = 0
	collision_mask = GS.L_WORLD | GS.L_PLATFORM
	carry_state = ""
	var side := signf(dir.x) if absf(dir.x) > 0.1 else -facing
	velocity = Vector2(side * 240.0, -420.0)
	if how in ["explosion", "thrown", "kick", "fury"]:
		# ragdoll fling: big arc + spin
		launched_by_blast = true
		velocity = Vector2(side * randf_range(360.0, 520.0), randf_range(-760.0, -560.0))
		spin = side * randf_range(8.0, 13.0)
	GS.sfx(&"enemy_die")
	if GS.game != null:
		GS.game.on_enemy_killed(self, how)
		GS.game.fx.death_burst(center(), how, facing)
	_on_die(how)


func _on_die(_how: String) -> void:
	pass


func _dead_physics(delta: float) -> void:
	dead_t += delta
	velocity.y = minf(velocity.y + gravity_force * delta, 1400.0)
	var was_air := not is_on_floor()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	elif spin != 0.0:
		spin_angle += spin * delta
	move_and_slide()
	if was_air and is_on_floor() and launched_by_blast and dead_t > 0.15:
		launched_by_blast = false
		spin_angle = snappedf(spin_angle, PI)
		spin = 0.0
		if GS.game != null:
			GS.game.fx.dust(global_position, 10, 1.6)
			GS.sfx_var(&"thud", 2)
	if dead_t > 1.5:
		alpha = maxf(0.0, 1.0 - (dead_t - 1.5) / 0.6)
		if alpha <= 0.0 or global_position.y > GS.KILL_Y:
			remove()


# ---- carry / hostage ------------------------------------------------------

func hostage_hit(dmg: float) -> void:
	hp -= dmg
	flash()
	GS.sfx(&"hit")
	if hp <= 0.0 and holder != null:
		var h := holder
		h.drop_carried()
		die(Vector2(-h.facing, 0), "shield")


func release_drop() -> void:
	super()
	state = "stagger"
	state_t = 0.0
	stun_t = 0.8


func impact(target: Node) -> bool:
	var game := GS.game
	var dir := velocity.normalized()
	if target != null:
		target.take_hit(thrown_damage(), dir, "thrown")
		if game != null:
			game.shake(7.0, 0.2)
			game.hitstop(0.06)
			game.fx.chunks(center(), 6, Color("#5a5f6a"))
			game.fx.sparks(center(), -dir, 10, GS.C_YELLOW, 520.0)
			game.fx.popup(center() + Vector2(0, -40), "SMASH!", GS.C_ORANGE, 26)
		GS.sfx(&"explosion" if thrown_explodes() else &"hit")
	elif game != null:
		game.shake(4.0, 0.15)
		game.fx.dust(global_position, 8, 1.5)
	if thrown_explodes() and game != null:
		game.explode(center(), 110.0, 8.0, 0, 1.0)
	carry_state = ""
	collision_layer = 0
	die(dir if target == null else -dir, "thrown")
	velocity = Vector2(-dir.x * 180.0, -300.0) if target != null else Vector2(velocity.x * 0.3, -260.0)
	return true


func thrown_damage() -> float:
	return 10.0


func thrown_explodes() -> bool:
	return false


# ---- drawing --------------------------------------------------------------

func current_frame() -> String:
	return frame


func _draw() -> void:
	var f := current_frame()
	var mod := Color(1, 1, 1, alpha)
	var rot := 0.0
	if carry_state == "thrown":
		rot = thrown_t * 14.0 * signf(velocity.x)
	elif dead and spin_angle != 0.0:
		rot = spin_angle
	if rot != 0.0:
		var off := Vector2(0, -body_size.y * 0.5)
		var base := Transform2D(rot, off) * Transform2D(0.0, -off)
		SpriteLib.draw(self, sheet, f, Vector2.ZERO, facing < 0.0, draw_scale, mod, 0.0, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		SpriteLib.draw(self, sheet, f, Vector2.ZERO, facing < 0.0, draw_scale, mod)
	_draw_extra()
	draw_status()


func _draw_extra() -> void:
	pass


## Common overlays: spot "!" pop and panic "!!" + sweat drops.
func draw_status() -> void:
	if dead or carry_state != "":
		return
	var top := -body_size.y - 30.0
	if spot_t >= 0.0:
		var k := clampf(spot_t / 0.12, 0.0, 1.0)
		var s := lerpf(1.8, 1.0, k) * (1.0 - clampf((spot_t - 0.5) / 0.2, 0.0, 1.0))
		if s > 0.01:
			draw_set_transform(Vector2(0, top - 6.0), 0.0, Vector2(s, s))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -16), Vector2(14, -16), Vector2(14, 8), Vector2(4, 8), Vector2(-2, 18), Vector2(-4, 8), Vector2(-14, 8)]), GS.C_INK)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -13), Vector2(11, -13), Vector2(11, 5), Vector2(-11, 5)]), Color.WHITE)
			draw_rect(Rect2(-2, -11, 4, 10), GS.C_RED)
			draw_rect(Rect2(-2, 1, 4, 3), GS.C_RED)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if panic_t > 0.0:
		var wob := sin(anim_t * 40.0) * 3.0
		for i in 2:
			var x := -9.0 + i * 16.0 + wob
			draw_rect(Rect2(x - 1, top - 16, 6, 14), GS.C_INK)
			draw_rect(Rect2(x, top - 15, 4, 11), GS.C_YELLOW)
			draw_rect(Rect2(x - 1, top + 1, 6, 5), GS.C_INK)
			draw_rect(Rect2(x, top + 2, 4, 3), GS.C_YELLOW)
		# sweat drops
		for j in 3:
			var ph := fmod(anim_t * 2.2 + j * 0.33, 1.0)
			var p := Vector2((-1.0 if j % 2 == 0 else 1.0) * (16.0 + ph * 14.0), -body_size.y + 10.0 + ph * 22.0)
			draw_circle(p, 3.5 * (1.0 - ph * 0.5), Color(0.55, 0.85, 1.0, 1.0 - ph))


func draw_alert(t: float) -> void:
	# Pulsing "!" telegraph above the head
	var y := -body_size.y - 26.0
	var s := 1.0 + 0.2 * sin(t * 30.0)
	draw_circle(Vector2(0, y), 13.0 * s, GS.C_INK)
	draw_circle(Vector2(0, y), 10.0 * s, GS.C_YELLOW)
	draw_rect(Rect2(-2, y - 7, 4, 9), GS.C_INK)
	draw_rect(Rect2(-2, y + 4, 4, 3), GS.C_INK)
