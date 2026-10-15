extends "res://scripts/enemy_base.gd"
## Iron Jackal rifle grunt: patrols, telegraphs, fires 3-round bursts,
## lobs grenades and repositions. Light: can be grappled and thrown.

const P := preload("res://scripts/projectiles.gd")
var shots_left := 0
var shot_cd := 0.0
var cooldown := 0.0
var patrol_dir := -1.0
var enter_x := 0.0
var walk_speed := 62.0


func _init() -> void:
	super()
	sheet = "grunt"
	kind_name = "grunt"
	body_size = Vector2(38, 90)
	max_hp = 3.0
	score_value = 100


func setup(pos: Vector2, data: Dictionary) -> void:
	super(pos, data)
	if data.get("enter", false):
		state = "enter"
		enter_x = pos.x
		var view: Rect2 = GS.game.view_rect()
		global_position.x = view.end.x + 60.0
		facing = -1.0
	elif data.get("drop", false):
		state = "drop"
		global_position.y = GS.game.view_rect().position.y - 60.0
	cooldown = randf_range(0.3, 1.2)


func _ai(delta: float) -> void:
	var d := to_player()
	var dist := absf(d.x)
	shot_cd = maxf(0.0, shot_cd - delta)
	cooldown = maxf(0.0, cooldown - delta)
	if stun_t > 0.0:
		frame = "hurt"
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		_gravity_move(delta)
		return
	if panic_t > 0.0 and state not in ["enter", "drop"]:
		# flee the lit explosive, arms flailing
		var away := signf(global_position.x - panic_x)
		if away == 0.0:
			away = -facing
		facing = away
		if floor_ahead(away) and not wall_ahead(away):
			velocity.x = away * walk_speed * 3.0
			frame = _walk_frame(18.0)
		else:
			velocity.x = 0.0
			frame = "hurt"
		state = "idle"
		cooldown = maxf(cooldown, 0.5)
		_gravity_move(delta)
		return
	match state:
		"enter":
			velocity.x = -220.0
			facing = -1.0
			frame = _walk_frame(14.0)
			if is_on_wall() and is_on_floor():
				velocity.y = -620.0
			if global_position.x <= enter_x or state_t > 5.0:
				state = "idle"
				state_t = 0.0
		"drop":
			frame = "hurt"
			velocity.x = 0.0
			if is_on_floor() and state_t > 0.1:
				state = "idle"
				GS.game.fx.dust(global_position, 6)
		"idle", "stagger":
			frame = _walk_frame(7.0)
			if not floor_ahead(patrol_dir) or wall_ahead(patrol_dir) or absf(global_position.x + patrol_dir * 4.0 - home_x) > patrol_range:
				patrol_dir = -patrol_dir
			if wave_tag != "" and not on_screen(-60.0):
				var vr: Rect2 = GS.game.view_rect()
				patrol_dir = signf(vr.get_center().x - global_position.x)
				home_x = global_position.x + patrol_dir * 200.0
			velocity.x = patrol_dir * walk_speed
			facing = patrol_dir
			if player_alive() and on_screen(-30.0) and dist < 820.0 and absf(d.y) < 320.0 and cooldown <= 0.0:
				state = "aim"
				state_t = 0.0
				velocity.x = 0.0
				face_player()
				on_spotted()
		"aim":
			velocity.x = 0.0
			face_player()
			frame = "fire"
			if state_t > 0.5 / rate_scale:
				if dist > 170.0 and dist < 520.0 and randf() < 0.3 and absf(d.y) < 200.0:
					state = "grenade"
				else:
					state = "fire"
					shots_left = 3
					shot_cd = 0.0
				state_t = 0.0
		"fire":
			velocity.x = 0.0
			frame = "fire"
			if shots_left > 0 and shot_cd <= 0.0:
				_shoot()
				shots_left -= 1
				shot_cd = 0.15
			elif shots_left <= 0 and state_t > 0.3:
				_after_attack()
		"grenade":
			velocity.x = 0.0
			frame = "hurt" if state_t < 0.25 else "walk0"
			if state_t > 0.3 and state_t - delta <= 0.3:
				_lob()
			if state_t > 0.55:
				_after_attack()
		"reposition":
			var want := 380.0
			var dir := 0.0
			if dist < want - 120.0:
				dir = -signf(d.x)
			elif dist > want + 160.0:
				dir = signf(d.x)
			if dir != 0.0 and (not floor_ahead(dir) or wall_ahead(dir)):
				dir = 0.0
			velocity.x = dir * walk_speed * 1.2
			face_player()
			frame = _walk_frame(8.0) if dir != 0.0 else "walk0"
			if state_t > 1.1:
				state = "aim" if player_alive() and on_screen(-30.0) else "idle"
				state_t = 0.0
	_gravity_move(delta)


func _after_attack() -> void:
	state = "reposition"
	state_t = 0.0
	cooldown = randf_range(1.0, 1.8) / rate_scale


func can_panic() -> bool:
	return true


func alerted() -> void:
	super()
	cooldown = minf(cooldown, randf_range(0.05, 0.35))


func _walk_frame(fps: float) -> String:
	return "walk%d" % (int(anim_t * fps) % 4)


func muzzle() -> Vector2:
	return global_position + Vector2(facing * 46.0, -60.0)


func _shoot() -> void:
	var from := muzzle()
	var p := player()
	var target: Vector2 = p.center() if p != null else from + Vector2(facing * 100, 0)
	var dir := (target - from).normalized()
	var ang := clampf(dir.angle_to(Vector2(facing, 0)), -0.4, 0.4)
	dir = Vector2(facing, 0).rotated(-ang)
	GS.game.proj.fire(P.K.EBULLET, from, dir * 430.0, P.TEAM_ENEMY, 8.0)
	GS.game.fx.muzzle(from, dir.angle(), 0.6, Color(1, 0.6, 0.3))
	GS.sfx(&"pistol")


func _lob() -> void:
	var p := player()
	if p == null:
		return
	var from := global_position + Vector2(facing * 10.0, -86.0)
	var t := 0.85
	var d: Vector2 = p.global_position - from + Vector2(p.velocity.x * 0.3, -10.0)
	var g := 1100.0
	var v := Vector2(d.x / t, (d.y - 0.5 * g * t * t) / t)
	GS.game.proj.fire(P.K.BOMB, from, v, P.TEAM_ENEMY, 16.0, {"radius": 72.0, "gravity": g})
	GS.sfx(&"throw")


func current_frame() -> String:
	if carry_state in ["reeled", "carried"]:
		return "grabbed"
	if carry_state == "thrown":
		return "grabbed"
	if dead:
		return "dead" if is_on_floor() else "hurt"
	return frame


func _draw_extra() -> void:
	if not dead and carry_state == "" and state == "aim":
		draw_alert(state_t)
