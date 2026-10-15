extends "res://scripts/enemy_base.gd"
## "Rhino Crawler" hover-tank boss. Patterns: cannon volley, ground ram
## (dodge on the arena platforms or the swing ring), missile rain and drone
## deployment in phase two. Heavy: grapple kicks, thrown objects hurt it.

const P := preload("res://scripts/projectiles.gd")
const HULL_SCALE := 0.85
const TURRET_SCALE := 0.8

var arena_left := 0.0
var arena_right := 0.0
var home := Vector2.ZERO
var hover_y := 0.0
var turret_angle := PI
var turret_glow := 0.0
var pattern_i := 0
var shots_left := 0
var shot_cd := 0.0
var phase := 1
var dying_t := 0.0
var boom_cd := 0.0
var missile_marks: Array = []
var intro_done := false
var hurt_shake := 0.0
var laser_angle := PI
var laser_hit_cd := 0.0


func _init() -> void:
	super()
	sheet = "boss"
	kind_name = "boss"
	body_size = Vector2(360, 150)
	max_hp = 240.0
	score_value = 10000
	gravity_force = 0.0


func _ready() -> void:
	super()
	collision_layer = 0
	collision_mask = 0
	z_index = 5


func setup(pos: Vector2, data: Dictionary) -> void:
	super(pos, data)
	arena_left = float(data.get("arena_left", pos.x - 1000.0))
	arena_right = float(data.get("arena_right", pos.x + 280.0))
	home = pos
	hover_y = pos.y
	global_position = Vector2(arena_right + 420.0, pos.y - 60.0)
	state = "enter"
	facing = -1.0


func grapple_kind() -> String:
	return "heavy" if not dead else "none"


func grapple_kick(dmg: float, dir: Vector2) -> void:
	take_hit(dmg, dir, "kick")


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x * 0.5, -body_size.y - 10.0), body_size)


func is_targetable() -> bool:
	return not dead and state != "enter"


func take_hit(dmg: float, dir: Vector2, kind: String) -> String:
	if dead or state == "enter":
		return "none"
	hp -= dmg
	flash(0.6)
	hurt_shake = 0.12
	if kind != "bullet" or randf() < 0.3:
		GS.sfx(&"hit")
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		var g := GS.game
		g.fx.callout(center() + Vector2(0, -150), "IT'S ENRAGED!", GS.C_RED, 38)
		g.fx.explosion(center() + Vector2(-60, -30), 1.2)
		g.fx.sparks(center(), Vector2.UP, 30, GS.C_YELLOW, 800.0)
		GS.sfx(&"alarm")
		GS.sfx(&"vo_warning")
		g.shake(12.0, 0.5)
		g.hitstop(0.12)
		g.zoom_punch(0.06)
		if g.post != null:
			g.post.shockwave(center(), 1.4)
			g.post.flash(Color(1, 0.3, 0.1), 0.35)
		g.hud.banner("ENRAGED!", "Phase two - watch for the laser", 1.6, "alert")
	if hp <= 0.0:
		hp = 0.0
		_start_dying()
	return "hit"


func _start_dying() -> void:
	dead = true
	state = "dying"
	dying_t = 0.0
	GS.game.on_boss_dying(self)


func center() -> Vector2:
	return global_position + Vector2(0, -85)


func _physics_process(delta: float) -> void:
	_tick_flash(delta)
	anim_t += delta
	state_t += delta
	shot_cd = maxf(0.0, shot_cd - delta)
	turret_glow = maxf(0.0, turret_glow - delta * 2.0)
	hurt_shake = maxf(0.0, hurt_shake - delta)
	var game := GS.game
	if state == "dying":
		_dying(delta)
		queue_redraw()
		return
	_aim_turret(delta)
	match state:
		"enter":
			global_position = global_position.move_toward(home, 260.0 * delta)
			if global_position.distance_to(home) < 4.0:
				state = "idle"
				state_t = 0.0
				game.on_boss_ready(self)
		"idle":
			_hover(delta)
			if state_t > (1.1 if phase == 1 else 0.7) / rate_scale:
				_next_pattern()
		"volley":
			_hover(delta)
			turret_glow = 1.0 if state_t < 0.55 else turret_glow
			if state_t > 0.55 and shots_left > 0 and shot_cd <= 0.0:
				_fire_shell()
				shots_left -= 1
				shot_cd = 0.32 if phase == 1 else 0.22
			if shots_left <= 0 and state_t > 0.8:
				_to_idle()
		"ram_prep":
			global_position.y = move_toward(global_position.y, GS.GROUND_Y + 8.0, 300.0 * delta)
			global_position.x = move_toward(global_position.x, arena_right - 200.0, 200.0 * delta)
			if int(state_t * 20.0) % 2 == 0:
				game.fx.dust(global_position + Vector2(randf_range(-150, 150), 0), 2, 1.5)
			if state_t > 1.0:
				state = "ram"
				state_t = 0.0
				GS.sfx(&"grab")
				game.shake(6.0, 0.3)
		"ram":
			global_position.x -= (900.0 if phase == 1 else 1100.0) * delta
			game.fx.dust(global_position + Vector2(160, 0), 2, 2.0)
			game.fx.sparks(global_position + Vector2(-120, -4), Vector2(1, -0.5), 1, GS.C_YELLOW, 400.0)
			_ram_hit()
			if global_position.x <= arena_left + 230.0:
				state = "ram_return"
				state_t = 0.0
				game.shake(10.0, 0.35)
				game.fx.explosion(global_position + Vector2(-180, -40), 0.8)
				GS.sfx(&"explosion")
		"ram_return":
			global_position.y = move_toward(global_position.y, hover_y - 60.0, 260.0 * delta)
			if state_t > 0.4:
				global_position.x = move_toward(global_position.x, home.x, 420.0 * delta)
			if global_position.distance_to(Vector2(home.x, hover_y - 60.0)) < 6.0:
				_to_idle()
		"missiles":
			_hover(delta)
			if state_t < 0.9 and int(state_t * 10.0) % 2 == 0 and missile_marks.size() < 6:
				var x := randf_range(arena_left + 80.0, arena_right - 380.0)
				if missile_marks.is_empty() and game.player != null:
					x = clampf(game.player.global_position.x, arena_left + 60.0, arena_right - 60.0)
				missile_marks.append([x, 1.1])
				game.proj.add_marker(Vector2(x, GS.GROUND_Y), 1.1, 85.0)
				game.fx.smoke(global_position + Vector2(60, -175), 2, 12.0)
				GS.sfx(&"rocket")
			for m in missile_marks:
				m[1] -= delta
				if m[1] <= 0.35 and m[1] + delta > 0.35:
					game.proj.fire(P.K.MISSILE, Vector2(m[0], game.view_rect().position.y - 40.0), Vector2(0, 700), P.TEAM_ENEMY, 18.0, {"radius": 85.0})
			if state_t > 2.4:
				missile_marks.clear()
				_to_idle()
		"laser":
			# charge: thin aim line tracks the player, locks 0.35s before firing
			_hover(delta)
			var p0 := player()
			if state_t < 0.85 and p0 != null:
				var want: float = (p0.center() - _mount()).angle()
				laser_angle = lerp_angle(laser_angle, want, 1.0 - exp(-8.0 * delta))
			turret_angle = laser_angle
			turret_glow = 1.0
			if int(state_t * 30.0) % 3 == 0 and state_t < 1.2:
				game.fx.sparks(_laser_from(), Vector2.from_angle(laser_angle + PI), 1, Color(1, 0.4, 0.3), 200.0)
			if state_t >= 1.2 and state_t - delta < 1.2:
				GS.sfx(&"laser_fire")
				game.shake(8.0, 0.3)
				game.zoom_punch(0.03)
				if game.post != null:
					game.post.flash(Color(1, 0.35, 0.25), 0.2)
			if state_t >= 1.2:
				var p1 := player()
				if p1 != null:
					var want2: float = (p1.center() - _mount()).angle()
					laser_angle += clampf(wrapf(want2 - laser_angle, -PI, PI), -0.32 * delta, 0.32 * delta)
				turret_angle = laser_angle
				_laser_damage(delta)
				var hitp := _laser_end()
				if int(state_t * 40.0) % 2 == 0:
					game.fx.sparks(hitp, Vector2.UP, 2, GS.C_YELLOW, 500.0)
					game.fx.dust(hitp, 1, 1.4)
				game.shake(2.0, 0.05)
			if state_t > 2.4:
				_to_idle()
		"drones":
			_hover(delta)
			if state_t > 0.5 and state_t - delta <= 0.5:
				for i in 2:
					game.spawn_enemy("drone", global_position + Vector2(-60 + i * 120, -160), {})
				game.fx.popup(center() + Vector2(0, -120), "DRONES OUT!", GS.C_ORANGE, 24)
			if state_t > 1.2:
				_to_idle()
	# smoke when damaged
	if hp < max_hp * 0.5 and int(anim_t * 20.0) % 3 == 0:
		game.fx.smoke(global_position + Vector2(randf_range(-120, 120), -140), 1, 16.0, Color(0.15, 0.13, 0.12, 0.55))
	if hp < max_hp * 0.25 and int(anim_t * 20.0) % 4 == 0:
		game.fx.embers(global_position + Vector2(randf_range(-100, 100), -120), 1)
	queue_redraw()


func _hover(delta: float) -> void:
	var target := Vector2(home.x + sin(anim_t * 0.7) * 50.0, hover_y - 60.0 + sin(anim_t * 2.2) * 10.0)
	global_position = global_position.move_toward(target, 160.0 * delta)


func _to_idle() -> void:
	state = "idle"
	state_t = 0.0


func _next_pattern() -> void:
	var seq1 := ["volley", "ram_prep", "volley", "volley"]
	var seq2 := ["volley", "laser", "missiles", "ram_prep", "drones", "laser", "volley", "missiles", "ram_prep"]
	var seq: Array = seq1 if phase == 1 else seq2
	state = seq[pattern_i % seq.size()]
	pattern_i += 1
	state_t = 0.0
	if state == "volley":
		shots_left = 3 if phase == 1 else 5
	if state == "drones" and GS.game.count_enemies("drone") >= 2:
		state = "volley"
		shots_left = 4
	if state == "ram_prep":
		GS.game.fx.callout(center() + Vector2(0, -130), "RAM INCOMING!", GS.C_RED, 30)
		GS.sfx(&"alarm")
	if state == "laser":
		laser_angle = turret_angle
		GS.sfx(&"laser_charge")
		GS.game.fx.callout(center() + Vector2(0, -130), "LASER!", GS.C_RED, 30)


func _mount() -> Vector2:
	return global_position + Vector2(-20, -160)


func _aim_turret(delta: float) -> void:
	var p := player()
	if p == null:
		return
	var want: float = (p.center() - _mount()).angle()
	if want < 0.0:
		want += TAU
	want = clampf(want, PI * 0.55, PI * 1.25)
	turret_angle = lerp_angle(turret_angle, want, 1.0 - exp(-4.0 * delta))


func _fire_shell() -> void:
	var dir := Vector2.from_angle(turret_angle)
	var from := _mount() + dir * 130.0
	GS.game.proj.fire(P.K.SHELL, from, dir * (520.0 if phase == 1 else 600.0), P.TEAM_ENEMY, 16.0, {"radius": 64.0})
	GS.game.fx.muzzle(from, turret_angle, 1.4, Color(1, 0.55, 0.2))
	GS.game.fx.smoke(from, 3, 14.0)
	GS.game.shake(3.0, 0.1)
	GS.sfx(&"rocket")


func _laser_from() -> Vector2:
	return _mount() + Vector2.from_angle(laser_angle) * 130.0


## Beam end: first ground hit along the ray (or 1400px).
func _laser_end() -> Vector2:
	var from := _laser_from()
	var dir := Vector2.from_angle(laser_angle)
	var d := 20.0
	while d < 1400.0:
		var pt := from + dir * d
		var gy: float = GS.game.ground_top(pt.x)
		if pt.y >= gy:
			return Vector2(pt.x, gy)
		d += 24.0
	return from + dir * 1400.0


func _laser_damage(delta: float) -> void:
	laser_hit_cd = maxf(0.0, laser_hit_cd - delta)
	var p := player()
	if p == null or not p.is_hittable() or laser_hit_cd > 0.0:
		return
	var a := _laser_from()
	var b := _laser_end()
	var c: Vector2 = p.center()
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	if (a + ab * t).distance_to(c) < 34.0:
		laser_hit_cd = 0.5
		p.take_damage(20.0, Vector2(signf(c.x - a.x), -0.6))


func _ram_hit() -> void:
	var p := player()
	if p == null or not p.is_hittable():
		return
	var r := hurt_rect().grow(-10.0)
	if r.intersects(p.hurt_rect()):
		p.take_damage(30.0, Vector2(-1, -0.6))


func _dying(delta: float) -> void:
	dying_t += delta
	boom_cd -= delta
	var game := GS.game
	global_position.y += 30.0 * delta
	if boom_cd <= 0.0:
		boom_cd = 0.12
		var off := Vector2(randf_range(-170, 170), randf_range(-160, -10))
		game.fx.explosion(global_position + off, randf_range(0.6, 1.1))
		game.shake(5.0, 0.12)
		GS.sfx(&"explosion")
	if dying_t > 3.0:
		for i in 5:
			game.fx.explosion(center() + Vector2(randf_range(-160, 160), randf_range(-80, 60)), 1.6)
		game.fx.chunks(center(), 30, Color("#8a6a3a"))
		game.shake(16.0, 0.6)
		game.flash_screen(0.8)
		GS.sfx(&"explosion")
		game.on_boss_defeated(self)
		remove()


func _draw() -> void:
	var jitter := Vector2(randf_range(-3, 3), randf_range(-2, 2)) if (hurt_shake > 0.0 or state == "dying" or state == "ram_prep") else Vector2.ZERO
	# thruster flames
	if state != "ram" and state != "ram_prep":
		for x in [-120.0, 0.0, 120.0]:
			var flick := 0.8 + 0.2 * sin(anim_t * 40.0 + x)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 22, -8), Vector2(x + 22, -8), Vector2(x, 44.0 * flick)]), Color(1.0, 0.55, 0.15, 0.75))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 11, -8), Vector2(x + 11, -8), Vector2(x, 24.0 * flick)]), Color(1.0, 0.95, 0.6, 0.9))
	SpriteLib.draw(self, "boss", "hull", Vector2(0, -85) + jitter, false, HULL_SCALE)
	# turret: source barrel points left; rotate about its rear hub
	var hub := Vector2(62, 8)
	var local_mount := _mount() - global_position + jitter
	var rot := turret_angle - PI
	var base := Transform2D(rot, local_mount)
	var glow := Color(1.0 + turret_glow * 0.8, 1.0, 1.0 - turret_glow * 0.4)
	SpriteLib.draw(self, "boss_turret", "turret", hub * -1.0 + Vector2(hub.x, 0) - Vector2(hub.x, 0), false, TURRET_SCALE, glow, 0.0, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if turret_glow > 0.0:
		var tip := local_mount + Vector2.from_angle(turret_angle) * 130.0
		draw_circle(tip, 14.0 + 8.0 * sin(anim_t * 40.0), Color(1, 0.4, 0.1, 0.55 * turret_glow))
	if state == "ram_prep":
		draw_alert(state_t)
		# danger strip along the ram lane
		var lane_w := global_position.x - arena_left
		var blink := 0.35 + 0.3 * sin(state_t * 22.0)
		draw_rect(Rect2(-lane_w, -70, lane_w - 160.0, 70), Color(1, 0.1, 0.05, 0.16 * blink + 0.08))
		for i in int(lane_w / 90.0):
			var x := -200.0 - i * 90.0 + fmod(state_t * 260.0, 90.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, -52), Vector2(x - 30, -35), Vector2(x, -18)]), Color(1, 0.3, 0.1, blink))
	if state == "volley" and state_t < 0.55:
		var tip2 := local_mount + Vector2.from_angle(turret_angle) * 130.0
		draw_line(tip2, tip2 + Vector2.from_angle(turret_angle) * 900.0, Color(1, 0.3, 0.1, 0.35 * (0.5 + 0.5 * sin(state_t * 40.0))), 2.0)
	if state == "laser":
		var la := _laser_from() - global_position
		var lb := _laser_end() - global_position
		if state_t < 1.2:
			var k := state_t / 1.2
			draw_line(la, lb, Color(1, 0.25, 0.2, 0.3 + 0.5 * k * (0.6 + 0.4 * sin(state_t * 50.0))), 1.5 + 2.5 * k)
			draw_circle(la, 10.0 + 18.0 * k, Color(1, 0.4, 0.3, 0.5 * k))
		else:
			var f := 1.0 - clampf((state_t - 2.1) / 0.3, 0.0, 1.0)
			var wob := 1.0 + 0.15 * sin(anim_t * 60.0)
			draw_line(la, lb, Color(1, 0.2, 0.1, 0.35 * f), 64.0 * wob * f)
			draw_line(la, lb, Color(1, 0.55, 0.3, 0.8 * f), 30.0 * wob * f)
			draw_line(la, lb, Color(1, 1, 0.9, f), 11.0 * wob * f)
			draw_circle(la, 30.0 * wob * f, Color(1, 0.9, 0.7, 0.9 * f))
			draw_circle(lb, 40.0 * wob * f, Color(1, 0.6, 0.3, 0.6 * f))
