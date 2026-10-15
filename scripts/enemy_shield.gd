extends "res://scripts/enemy_base.gd"
## Shield trooper: advances behind a riot shield that blocks frontal bullets.
## Grapple rips the shield away; unshielded, he lunges at the commando.

const P := preload("res://scripts/projectiles.gd")
var has_shield := true
var shield_hp := 12.0
var cooldown := 1.0


func _init() -> void:
	super()
	sheet = "shield"
	kind_name = "shield"
	body_size = Vector2(46, 96)
	max_hp = 4.0
	score_value = 250


func setup(pos: Vector2, data: Dictionary) -> void:
	super(pos, data)
	if data.get("enter", false):
		state = "enter"
		global_position.x = GS.game.view_rect().end.x + 60.0


func grapple_kind() -> String:
	return "shield" if has_shield else "light"


func take_hit(dmg: float, dir: Vector2, kind: String) -> String:
	if dead or carry_state != "":
		return "none"
	if has_shield:
		var frontal := dir.x * facing < 0.0
		if kind == "explosion":
			shield_hp -= dmg * 1.5
			if shield_hp <= 0.0:
				_lose_shield(dir, "SHIELD BUSTED!")
			return super(dmg * 0.4, dir, kind)
		if kind == "thrown" and frontal:
			_lose_shield(dir, "SHIELD BUSTED!")
			return super(dmg * 0.5, dir, kind)
		if frontal and dir.y < 0.7:
			flash(0.4)
			return "block"
	return super(dmg, dir, kind)


func rip_shield(by: Node) -> void:
	_lose_shield(Vector2(signf(by.global_position.x - global_position.x), 0), "SHIELD RIPPED!")
	GS.game.add_score(50, center() + Vector2(0, -60), "")


func _lose_shield(dir: Vector2, text: String) -> void:
	if not has_shield:
		return
	has_shield = false
	stun_t = 1.0
	state = "stagger"
	state_t = 0.0
	var game := GS.game
	game.fx.chunks(center() + Vector2(facing * 20, 0), 10, Color("#6d7380"))
	game.fx.sparks(center() + Vector2(facing * 24, 0), Vector2(signf(dir.x), -0.5), 12, Color(1, 1, 0.85), 520.0)
	game.fx.popup(center() + Vector2(0, -70), text, GS.C_CYAN, 24)
	game.shake(5.0, 0.15)
	GS.sfx(&"ricochet")


func _ai(delta: float) -> void:
	var d := to_player()
	var dist := absf(d.x)
	cooldown = maxf(0.0, cooldown - delta)
	if stun_t > 0.0:
		frame = "stagger"
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		_gravity_move(delta)
		return
	if state == "enter":
		velocity.x = -120.0
		facing = -1.0
		frame = "walk%d" % (int(anim_t * 7.0) % 4)
		if is_on_wall() and is_on_floor():
			velocity.y = -560.0
		if on_screen(-140.0) or state_t > 6.0:
			state = "idle"
		_gravity_move(delta)
		return
	if has_shield:
		if player_alive() and on_screen(40.0):
			face_player()
		match state:
			"fire":
				velocity.x = 0.0
				frame = "fire"
				if state_t > 0.45 / rate_scale and state_t - delta <= 0.45 / rate_scale:
					_shoot()
				if state_t > 0.8:
					state = "idle"
					state_t = 0.0
					cooldown = randf_range(1.3, 2.0) / rate_scale
			_:
				var dir := signf(d.x) if dist > 260.0 else 0.0
				if dir != 0.0 and (not floor_ahead(dir) or wall_ahead(dir)):
					dir = 0.0
				velocity.x = dir * 46.0 if player_alive() and on_screen(40.0) else 0.0
				frame = "walk%d" % (int(anim_t * 5.0) % 4) if velocity.x != 0.0 else "walk0"
				if cooldown <= 0.0 and player_alive() and on_screen(-40.0) and dist < 760.0:
					state = "fire"
					state_t = 0.0
	else:
		# Unshielded: frantic lunge with contact damage.
		contact_damage = 12.0
		face_player()
		var dir2 := signf(d.x)
		if not floor_ahead(dir2) or wall_ahead(dir2):
			dir2 = 0.0
		velocity.x = move_toward(velocity.x, dir2 * 165.0, 900.0 * delta) if player_alive() else 0.0
		frame = "stagger"
	_gravity_move(delta)


func _shoot() -> void:
	var from := global_position + Vector2(facing * 40.0, -84.0)
	var p := player()
	var target: Vector2 = p.center() if p != null else from + Vector2(facing * 100, 0)
	var dir := (target - from).normalized()
	var ang := clampf(dir.angle_to(Vector2(facing, 0)), -0.35, 0.35)
	dir = Vector2(facing, 0).rotated(-ang)
	GS.game.proj.fire(P.K.EBULLET, from, dir * 440.0, P.TEAM_ENEMY, 9.0)
	GS.game.fx.muzzle(from, dir.angle(), 0.55, Color(1, 0.6, 0.3))
	GS.sfx(&"pistol")


func current_frame() -> String:
	if carry_state != "":
		return "grabbed"
	if dead:
		return "dead" if is_on_floor() else "stagger"
	if not has_shield and frame != "stagger":
		return "stagger"
	return frame


func _draw_extra() -> void:
	if not dead and carry_state == "" and state == "fire" and state_t < 0.45 / rate_scale:
		draw_alert(state_t)
