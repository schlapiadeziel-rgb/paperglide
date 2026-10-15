extends "res://scripts/enemy_base.gd"
## Heavy brute: stomps forward, winds up, then charges. Too heavy to carry —
## grappling him zips the commando in for a stunning strike.

var cooldown := 1.2
var charge_dir := -1.0
var step_frame := -1


func _init() -> void:
	super()
	sheet = "brute"
	kind_name = "brute"
	body_size = Vector2(84, 150)
	max_hp = 34.0
	score_value = 1000
	contact_damage = 12.0
	gravity_force = 2400.0


func grapple_kind() -> String:
	return "heavy"


func grapple_kick(dmg: float, dir: Vector2) -> void:
	take_hit(dmg, dir, "kick")
	if not dead:
		state = "stunned"
		state_t = 0.0
		velocity.x = signf(dir.x) * 180.0


func take_hit(dmg: float, dir: Vector2, kind: String) -> String:
	if state == "stunned":
		dmg *= 1.5
	return super(dmg, dir, kind)


func _ai(delta: float) -> void:
	var d := to_player()
	var dist := absf(d.x)
	cooldown = maxf(0.0, cooldown - delta)
	var game := GS.game
	match state:
		"idle":
			frame = "walk0"
			velocity.x = 0.0
			if player_alive() and on_screen(-60.0):
				state = "walk"
				state_t = 0.0
				GS.sfx(&"alarm")
				game.fx.popup(center() + Vector2(0, -110), "HEAVY!", GS.C_RED, 26)
		"walk":
			contact_damage = 12.0
			face_player()
			var dir := facing if dist > 90.0 else 0.0
			if dir != 0.0 and (not floor_ahead(dir, 30.0) or wall_ahead(dir)):
				dir = 0.0
			velocity.x = dir * 72.0
			var fi := int(anim_t * 5.0) % 4
			frame = "walk%d" % fi
			if fi != step_frame and fi % 2 == 0 and dir != 0.0:
				game.shake(2.0, 0.08)
				game.fx.dust(global_position + Vector2(facing * 20, 0), 3, 0.6)
			step_frame = fi
			if cooldown <= 0.0 and player_alive() and dist < 560.0 and absf(d.y) < 140.0 and on_screen(-80.0):
				state = "windup"
				state_t = 0.0
				charge_dir = facing
		"windup":
			velocity.x = 0.0
			frame = "windup"
			if int(state_t * 20.0) % 3 == 0:
				game.fx.smoke(global_position + Vector2(-facing * 30, -130), 1, 12.0, Color(0.9, 0.9, 0.9, 0.5))
			if state_t > 0.75 / rate_scale:
				state = "charge"
				state_t = 0.0
				GS.sfx(&"grab")
		"charge":
			contact_damage = 26.0
			frame = "punch"
			velocity.x = charge_dir * 640.0
			if int(state_t * 30.0) % 2 == 0:
				game.fx.dust(global_position, 2, 1.2)
			if not floor_ahead(charge_dir, 40.0) or wall_ahead(charge_dir) or state_t > 1.0:
				if wall_ahead(charge_dir):
					state = "stunned"
					game.shake(6.0, 0.2)
					game.fx.sparks(center() + Vector2(charge_dir * 50, 0), Vector2(-charge_dir, -0.3), 12)
				else:
					state = "recover"
				state_t = 0.0
				velocity.x = 0.0
		"recover":
			contact_damage = 12.0
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			frame = "walk0"
			if state_t > 0.6:
				state = "walk"
				state_t = 0.0
				cooldown = randf_range(1.6, 2.4) / rate_scale
		"stunned":
			contact_damage = 0.0
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			frame = "stunned"
			if state_t > 1.5:
				state = "walk"
				state_t = 0.0
				cooldown = 1.0
	_gravity_move(delta)


func _on_die(_how: String) -> void:
	GS.game.explode(center(), 90.0, 0.0, -2, 1.1)
	GS.game.fx.chunks(center(), 12, Color("#5b4a3a"))


func current_frame() -> String:
	if dead:
		return "dead" if is_on_floor() else "stunned"
	return frame


func _draw_extra() -> void:
	if dead:
		return
	if state == "windup":
		draw_alert(state_t)
	if state == "stunned":
		for i in 3:
			var a := anim_t * 5.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 34.0, -body_size.y - 12.0 + sin(a) * 8.0)
			draw_circle(p, 6.0, GS.C_YELLOW)
			draw_circle(p, 3.0, Color.WHITE)
