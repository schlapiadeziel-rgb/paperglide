extends CharacterBody2D
## Commando "Rook" — run, jump, 8-way-ish aim, four guns, knife, grapple
## gauntlet (grab light foes/props, zip-strike heavies, swing on rings, rip
## shields), carry & throw, grenades / medkits / barrier cells.

const P := preload("res://scripts/projectiles.gd")

const WEAPONS := {
	"pistol": {"rate": 0.13, "hold": 0.19, "speed": 1500.0, "dmg": 1.0, "kind": P.K.BULLET, "cue": &"pistol", "spread": 0.02},
	"hmg": {"rate": 0.075, "hold": 0.075, "speed": 1650.0, "dmg": 1.0, "kind": P.K.HMG, "cue": &"hmg", "spread": 0.07, "ammo": 200},
	"spread": {"rate": 0.3, "hold": 0.34, "speed": 1250.0, "dmg": 1.0, "kind": P.K.PELLET, "cue": &"spread", "pellets": 5, "arc": 0.55, "ammo": 45},
	"rocket": {"rate": 0.42, "hold": 0.5, "speed": 500.0, "dmg": 6.0, "kind": P.K.ROCKET, "cue": &"rocket", "ammo": 24},
}
const ITEMS := ["grenade", "medkit", "barrier"]
const STAND := Vector2(34, 92)
const CROUCH := Vector2(34, 62)

signal died
signal hurt

# tuning
var move_speed := 330.0
var accel := 3200.0
var friction := 3600.0
var jump_power := 1000.0
var jump_release := 420.0
var gravity := 2400.0
var coyote := 0.1
var jbuf := 0.12
var grapple_range := 470.0
var grapple_speed := 2300.0
var throw_speed := 840.0
var fire_scale := 1.0

var max_hp := 100.0
var hp := 100.0
var facing := 1.0
var state := "normal"  # normal, zip, swing, dead, cutscene
var controls := true
var god := false  # QA captures only
var coyote_t := 0.0
var jump_buf_t := 0.0
var invuln_t := 0.0
var hurt_t := 0.0
var barrier_t := 0.0
var action_t := 0.0
var action_pose := ""
var anim_t := 0.0
var run_phase := 0.0
var fire_cd := 0.0
var drop_t := 0.0
var dead_t := 0.0
var crouching := false
var was_floor := true
var fall_speed := 0.0
var last_safe := Vector2.ZERO

var weapon := "pistol"
var ammo := 0
var grenades := 5
var medkits := 1
var barriers := 0
var item_sel := 0

var carried: Node = null
var carried_is_enemy := false

var hook_state := "none"  # none, out, reel, retract
var hook_pos := Vector2.ZERO
var hook_vel := Vector2.ZERO
var hook_dir := Vector2.RIGHT
var hook_up := false
var hook_target: Node = null
var zip_target: Node = null
var zip_t := 0.0
var swing_anchor := Vector2.ZERO
var swing_len := 200.0
var swing_target := 180.0
var swing_t := 0.0

var _shape: RectangleShape2D
var _col: CollisionShape2D
var _mat: ShaderMaterial
var _flash_t := 0.0

# v2 juice / systems
var fury := false
var nest: Node = null
var nest_aim := 0.0
var afterimages: Array = []   # [global_pos, sheet, frame, flip, life]
var _after_t := 0.0
var _step_t := 0.0
var _reel_fx_t := 0.0
var recoil := 0.0
var squash := 0.0
var fury_t := 0.0


func _ready() -> void:
	collision_layer = GS.L_PLAYER
	collision_mask = GS.L_WORLD | GS.L_PLATFORM
	floor_snap_length = 10.0
	floor_max_angle = deg_to_rad(50)
	safe_margin = 0.5
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_col = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = STAND
	_col.shape = _shape
	_col.position = Vector2(0, -STAND.y * 0.5)
	add_child(_col)
	_mat = SpriteLib.flash_material(Color(1, 0.3, 0.25))
	material = _mat
	_load_tuning()
	hp = max_hp
	last_safe = global_position


func _load_tuning() -> void:
	move_speed = GS.tuning("move_speed", 330.0)
	accel = GS.tuning("acceleration", 3200.0)
	friction = GS.tuning("friction", 3600.0)
	jump_power = GS.tuning("jump_power", 1000.0)
	jump_release = GS.tuning("jump_release_speed", 420.0)
	gravity = GS.tuning("gravity", 2400.0)
	coyote = GS.tuning("coyote_time", 0.1)
	jbuf = GS.tuning("jump_buffer", 0.12)
	grapple_range = GS.tuning("grapple_range", 470.0)
	grapple_speed = GS.tuning("grapple_speed", 2300.0)
	throw_speed = GS.tuning("throw_speed", 840.0)
	fire_scale = GS.tuning("fire_rate_scale", 1.0)
	max_hp = GS.tuning("player_max_hp", 100.0)


# ---- queries --------------------------------------------------------------

func center() -> Vector2:
	return global_position + Vector2(0, -(CROUCH.y if crouching else STAND.y) * 0.5)


func hurt_rect() -> Rect2:
	var s := CROUCH if crouching else STAND
	return Rect2(global_position - Vector2(s.x * 0.5 - 4.0, s.y - 4.0), Vector2(s.x - 8.0, s.y - 6.0))


func is_hittable() -> bool:
	return state != "dead" and state != "cutscene"


func set_fury(on: bool) -> void:
	fury = on
	fury_t = 0.0
	if on:
		invuln_t = maxf(invuln_t, 0.6)


func hostage() -> Node:
	if carried != null and carried_is_enemy and is_instance_valid(carried):
		return carried
	return null


func weapon_label() -> String:
	return {"pistol": "PISTOL", "hmg": "HEAVY MG", "spread": "SPREAD", "rocket": "ROCKETS"}[weapon]


func item_count(i: int) -> int:
	return [grenades, medkits, barriers][i]


func _in(action: StringName) -> bool:
	return controls and Input.is_action_pressed(action)


func _just(action: StringName) -> bool:
	return controls and Input.is_action_just_pressed(action)


# ---- main loop --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	anim_t += delta
	invuln_t = maxf(0.0, invuln_t - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	barrier_t = maxf(0.0, barrier_t - delta)
	action_t = maxf(0.0, action_t - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	jump_buf_t = maxf(0.0, jump_buf_t - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	_mat.set_shader_parameter("flash", clampf(_flash_t / 0.12, 0.0, 1.0) * 0.8)
	recoil = move_toward(recoil, 0.0, delta * 60.0)
	squash = move_toward(squash, 0.0, delta * 3.5)
	_update_afterimages(delta)
	if drop_t > 0.0:
		drop_t -= delta
		if drop_t <= 0.0:
			collision_mask |= GS.L_PLATFORM
	if _just(&"jump"):
		jump_buf_t = jbuf
	match state:
		"dead":
			_dead_step(delta)
		"cutscene":
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.y = minf(velocity.y + gravity * delta, 1400.0)
			move_and_slide()
		"zip":
			_zip_step(delta)
		"swing":
			_swing_step(delta)
		"nest":
			_nest_step(delta)
		_:
			_normal_step(delta)
	if state != "dead":
		_update_hook(delta)
		_update_carried()
		_clamp_to_camera()
		if global_position.y > GS.KILL_Y:
			_fall_out()
	queue_redraw()


func _normal_step(delta: float) -> void:
	var ix := 0.0
	if controls:
		ix = Input.get_axis(&"move_left", &"move_right")
	var on_floor := is_on_floor()
	var want_crouch := on_floor and _in(&"aim_down") and carried == null and hook_state == "none"
	_set_crouch(want_crouch)
	var speed_mul := 1.0
	if crouching:
		speed_mul = 0.0
	elif carried != null:
		speed_mul = 0.82
	if ix != 0.0 and action_pose != "slash":
		facing = signf(ix)
	var target := ix * move_speed * speed_mul
	var rate := accel if absf(ix) > 0.0 else friction
	if not on_floor:
		rate *= 0.8
	velocity.x = move_toward(velocity.x, target, rate * delta)
	velocity.y = minf(velocity.y + gravity * delta, 1500.0)
	if on_floor:
		coyote_t = coyote
	else:
		coyote_t = maxf(0.0, coyote_t - delta)
	# drop through one-way platforms
	if jump_buf_t > 0.0 and on_floor and _in(&"aim_down") and _on_platform():
		jump_buf_t = 0.0
		collision_mask &= ~GS.L_PLATFORM
		drop_t = 0.22
		global_position.y += 2.0
		_set_crouch(false)
	elif jump_buf_t > 0.0 and (on_floor or coyote_t > 0.0):
		_set_crouch(false)
		velocity.y = -jump_power
		jump_buf_t = 0.0
		coyote_t = 0.0
		GS.sfx(&"jump")
		GS.game.fx.dust(global_position, 5, 0.8)
		squash = -0.6
	if not _in(&"jump") and velocity.y < -jump_release:
		velocity.y = -jump_release
	fall_speed = maxf(fall_speed, velocity.y)
	move_and_slide()
	var now_floor := is_on_floor()
	if now_floor and not was_floor:
		if fall_speed > 500.0:
			GS.sfx(&"land")
			GS.game.fx.dust(global_position, 6, 1.0)
			GS.game.fx.ground_puff(global_position)
			squash = clampf(fall_speed / 1400.0, 0.3, 1.0)
		elif fall_speed > 200.0:
			squash = 0.25
		fall_speed = 0.0
	was_floor = now_floor
	if now_floor and absf(velocity.x) > 200.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.26
			GS.game.fx.dust(global_position + Vector2(-facing * 10.0, 0), 1, 0.5)
	if now_floor and not _on_platform():
		_track_safe()
	run_phase += absf(velocity.x) * delta / 17.0
	_handle_actions()


func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var col := c.get_collider()
		if n.y < -0.5 and col is Node and (col as Node).is_in_group("platform"):
			return true
	return false


func _track_safe() -> void:
	var game := GS.game
	var gl: float = game.ground_top(global_position.x - 50.0)
	var gr: float = game.ground_top(global_position.x + 50.0)
	if absf(gl - global_position.y) < 8.0 and absf(gr - global_position.y) < 8.0:
		last_safe = global_position


func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	crouching = on
	var s := CROUCH if on else STAND
	_shape.size = s
	_col.position = Vector2(0, -s.y * 0.5)


func _clamp_to_camera() -> void:
	var view: Rect2 = GS.game.player_bounds()
	var x := clampf(global_position.x, view.position.x + 22.0, view.end.x - 22.0)
	if x != global_position.x:
		global_position.x = x
		velocity.x = 0.0


# ---- actions ------------------------------------------------------------------

func _handle_actions() -> void:
	if not controls:
		return
	if _just(&"switch_item"):
		item_sel = (item_sel + 1) % ITEMS.size()
		GS.sfx(&"ui_selection")
	if _just(&"use_item"):
		_use_item()
	if _just(&"grab"):
		if carried != null:
			_throw()
		elif _try_mount_nest():
			pass
		else:
			_try_grab()
		return
	if _just(&"grapple"):
		if carried != null:
			_throw()
		elif hook_state == "none":
			_launch_hook()
		return
	if carried != null:
		if _just(&"shoot"):
			_throw()
		return
	if hook_state != "none":
		return
	var w: Dictionary = WEAPONS[weapon]
	var pressed := _just(&"shoot")
	var held := _in(&"shoot")
	if pressed or (held and fire_cd <= 0.0):
		if pressed:
			var target := _melee_target()
			if target != null:
				_slash(target)
				return
		if fire_cd <= 0.0 or (pressed and fire_cd < float(w.rate) * 0.5 / fire_scale):
			_fire(w, pressed)


func aim_dir() -> Vector2:
	if _in(&"aim_up"):
		if _in(&"move_left") or _in(&"move_right"):
			return Vector2(facing, -1.0).normalized()
		return Vector2.UP
	if _in(&"aim_down") and not is_on_floor():
		return Vector2.DOWN
	return Vector2(facing, 0.0)


func _muzzle(dir: Vector2) -> Vector2:
	var off := Vector2(50, -89)
	if dir.y < -0.9:
		off = Vector2(16, -124)
	elif dir.y < -0.3:
		off = Vector2(40, -114)
	elif dir.y > 0.9:
		off = Vector2(6, -30)
	elif crouching:
		off = Vector2(48, -62)
	elif not is_on_floor():
		off = Vector2(44, -70)
	return global_position + Vector2(off.x * facing, off.y)


func _fire(w: Dictionary, tapped: bool) -> void:
	var dir := aim_dir()
	var from := _muzzle(dir)
	var game := GS.game
	var kind: int = w.kind
	var pellets := int(w.get("pellets", 1))
	var dmg_mul := 1.6 if fury else 1.0
	var extra: Dictionary = {"radius": 95.0} if kind == P.K.ROCKET else {}
	if fury:
		extra["gold"] = true
		extra["pierce"] = 2
	for i in pellets:
		var a := dir.angle()
		if pellets > 1:
			a += lerpf(-float(w.arc) * 0.5, float(w.arc) * 0.5, float(i) / float(pellets - 1))
		a += randf_range(-float(w.spread if w.has("spread") else 0.0), float(w.spread if w.has("spread") else 0.0))
		var v := Vector2.from_angle(a) * float(w.speed)
		game.proj.fire(kind, from, v, P.TEAM_PLAYER, float(w.dmg) * dmg_mul, extra.duplicate())
	var mcol := Color(1.0, 0.78, 0.25) if fury else Color(1.0, 0.85, 0.35)
	game.fx.muzzle(from, dir.angle(), 1.2 if weapon != "pistol" else 0.8, mcol, weapon)
	recoil = 5.0 if weapon in ["pistol", "spread"] else 3.0
	game.kick(-dir, 3.0 if weapon == "rocket" else (1.6 if weapon == "spread" else 0.8))
	if weapon in ["pistol", "hmg"]:
		game.fx.casing(from - Vector2(facing * 30.0, -6.0), facing)
	if weapon == "rocket":
		game.fx.smoke(from - dir * 20.0, 3, 12.0, Color(0.85, 0.85, 0.85, 0.6))
		game.shake(2.5, 0.08)
	elif weapon == "hmg":
		game.shake(0.8, 0.04)
	elif weapon == "spread":
		game.shake(1.6, 0.06)
	GS.sfx(w.cue)
	fire_cd = (float(w.rate) if tapped else float(w.hold)) / fire_scale * (0.55 if fury else 1.0)
	if weapon != "pistol" and not fury:
		ammo -= 1
		if ammo <= 0:
			weapon = "pistol"
			ammo = 0
			game.fx.popup(global_position + Vector2(0, -130), "OUT OF AMMO", GS.C_CREAM, 18)


func _melee_target() -> Node:
	var reach := Rect2(global_position + Vector2(0 if facing > 0 else -78, -96), Vector2(78, 96))
	for e in GS.game.enemies:
		if is_instance_valid(e) and e.is_targetable() and e.kind_name in ["grunt", "shield", "brute"]:
			if reach.intersects(e.hurt_rect()):
				return e
	return null


func _slash(target: Node) -> void:
	action_pose = "slash"
	action_t = 0.24
	GS.sfx(&"slash")
	var res: String = target.take_hit(4.0, Vector2(facing, 0), "melee")
	var game := GS.game
	if res == "block":
		game.fx.sparks(target.center(), Vector2(-facing, -0.3), 8, Color(1, 1, 0.8))
		GS.sfx(&"ricochet")
	else:
		game.hitstop(0.05)
		game.shake(3.0, 0.1)
		game.fx.sparks(target.center(), Vector2(facing, -0.2), 8, Color(1, 1, 1))
		game.fx.hit_flash(target.center(), Color(1, 1, 0.9))
		GS.sfx_var(&"punch", 3)
	fire_cd = 0.2


func _use_item() -> void:
	var game := GS.game
	match ITEMS[item_sel]:
		"grenade":
			if grenades <= 0:
				GS.sfx(&"invalid")
				return
			grenades -= 1
			var v := Vector2(facing * 560.0 + velocity.x * 0.4, -560.0)
			if _in(&"aim_up"):
				v = Vector2(facing * 260.0, -820.0)
			game.proj.fire(P.K.GRENADE, global_position + Vector2(facing * 20.0, -96.0), v, P.TEAM_PLAYER, 14.0)
			action_pose = "throw"
			action_t = 0.2
			GS.sfx(&"throw")
			game.style_bonus(2.0)
		"medkit":
			if medkits <= 0 or hp >= max_hp:
				GS.sfx(&"invalid")
				return
			medkits -= 1
			hp = minf(max_hp, hp + 50.0)
			game.fx.popup(global_position + Vector2(0, -130), "+50 HP", Color("#7dff8a"), 22)
			game.fx.heal_burst(center())
			GS.sfx(&"powerup")
		"barrier":
			if barriers <= 0:
				GS.sfx(&"invalid")
				return
			barriers -= 1
			barrier_t = 6.0
			game.fx.ring(center(), 80.0, Color(0.4, 0.9, 1.0, 0.9), 0.4)
			game.fx.pickup_burst(center(), GS.C_CYAN)
			GS.sfx(&"powerup")
	game.on_item_used(ITEMS[item_sel])


func collect(kind: String) -> void:
	var game := GS.game
	match kind:
		"medkit":
			if hp < max_hp:
				hp = minf(max_hp, hp + 35.0)
			else:
				medkits += 1
			GS.sfx(&"pickup")
		"grenades":
			grenades = mini(grenades + 5, 30)
			GS.sfx(&"pickup")
		"shield":
			barriers = mini(barriers + 1, 5)
			GS.sfx(&"pickup")
		"hmg", "spread", "rocket":
			if weapon == kind:
				ammo += int(WEAPONS[kind].ammo)
			else:
				weapon = kind
				ammo = int(WEAPONS[kind].ammo)
			GS.sfx(&"powerup")
			GS.sfx(StringName("vo_" + kind))
		"medal":
			game.add_score(500, global_position + Vector2(0, -120), "")
			GS.sfx(&"pickup")
		"gold":
			game.add_score(1000, global_position + Vector2(0, -120), "")
			GS.sfx(&"pickup")
	var col := GS.C_YELLOW
	match kind:
		"medkit":
			col = Color("#7dff8a")
		"shield":
			col = GS.C_CYAN
		"hmg", "spread", "rocket":
			col = GS.C_ORANGE
	game.fx.pickup_burst(center() + Vector2(0, -10), col)
	game.on_item_collected(kind)


# ---- grab / carry / throw -------------------------------------------------------

func _try_grab() -> void:
	var game := GS.game
	var best: Node = null
	var best_d := 90.0
	for t in game.grabbables():
		var d: float = t.center().distance_to(center())
		if d < best_d:
			best_d = d
			best = t
	if best != null:
		if best.is_enemy and best.grapple_kind() == "shield":
			best.rip_shield(self)
			return
		if best.grapple_kind() == "light":
			best.on_grappled(self)
			_carry(best)
			return
	GS.sfx(&"invalid")


func _carry(t: Node) -> void:
	carried = t
	carried_is_enemy = t.is_enemy
	t.set_carried(self)
	hook_state = "none"
	hook_target = null
	GS.sfx(&"grab")
	GS.game.on_grabbed(t)


func carry_point() -> Vector2:
	if carried_is_enemy:
		return global_position + Vector2(facing * 66.0, -8.0 + sin(anim_t * 20.0) * 2.0)
	return global_position + Vector2(facing * 8.0, -118.0)


func _update_carried() -> void:
	if carried == null:
		return
	if not is_instance_valid(carried) or carried.dead or carried.carry_state != "carried":
		carried = null
		return
	carried.carry_update(carry_point(), facing)
	if carried_is_enemy:
		carried.facing = -facing


func drop_carried() -> void:
	if carried != null and is_instance_valid(carried):
		carried.release_drop()
	carried = null


func _throw() -> void:
	if carried == null:
		return
	var v := Vector2(facing * throw_speed + velocity.x * 0.35, -throw_speed * 0.36)
	if _in(&"aim_up"):
		v = Vector2(facing * throw_speed * 0.3, -throw_speed * 1.1)
	elif _in(&"aim_down") and is_on_floor():
		v = Vector2(facing * 160.0, -140.0)
	elif _in(&"aim_down"):
		v = Vector2(facing * 200.0, throw_speed * 0.6)
	var t := carried
	carried = null
	t.global_position = global_position + Vector2(facing * 40.0, -60.0 if carried_is_enemy else -100.0)
	t.thrown(v, self)
	action_pose = "throw"
	action_t = 0.22
	GS.sfx(&"throw")
	GS.game.kick(Vector2(facing, 0), 2.0)
	GS.game.fx.speed_line(t.center(), v.normalized(), Color(1, 0.95, 0.8, 0.6))
	GS.game.on_thrown(t)


# ---- grapple -------------------------------------------------------------------

func _hand() -> Vector2:
	if hook_up:
		return global_position + Vector2(16.0 * facing, -124.0)
	return global_position + Vector2(56.0 * facing, -83.0)


func _launch_hook() -> void:
	var dir := Vector2(facing, 0)
	hook_up = false
	if _in(&"aim_up"):
		if _in(&"move_left") or _in(&"move_right"):
			dir = Vector2(facing, -1.0).normalized()
		else:
			dir = Vector2.UP
			hook_up = true
	# Auto-aim: snap to a nearby anchor/enemy within a cone for readability.
	var snap: Variant = GS.game.grapple_assist(_hand(), dir, grapple_range)
	if snap != null:
		dir = (snap - _hand()).normalized()
		hook_up = dir.y < -0.85
	hook_dir = dir
	hook_pos = _hand()
	hook_vel = dir * grapple_speed
	hook_state = "out"
	_set_crouch(false)
	GS.sfx(&"grapple_fire")


func _update_hook(delta: float) -> void:
	match hook_state:
		"out":
			var steps := 3
			for i in steps:
				var prev := hook_pos
				hook_pos += hook_vel * delta / steps
				if _hook_check(prev, hook_pos):
					return
			if hook_pos.distance_to(_hand()) > grapple_range:
				hook_state = "retract"
		"reel":
			if hook_target == null or not is_instance_valid(hook_target) or hook_target.dead or hook_target.carry_state != "reeled":
				hook_state = "retract"
				hook_target = null
				return
			var arrived: bool = hook_target.reel_to(carry_point(), delta)
			hook_pos = hook_target.center()
			if arrived:
				_carry(hook_target)
		"retract":
			var h := _hand()
			hook_pos = hook_pos.move_toward(h, 2800.0 * delta)
			if hook_pos.distance_to(h) < 24.0:
				hook_state = "none"


func _hook_check(prev: Vector2, now: Vector2) -> bool:
	var game := GS.game
	# anchors
	for a in game.anchors:
		if a.global_position.distance_to(now) < 40.0:
			_start_swing(a.global_position)
			return true
	# enemies & props
	for t in game.grabbables():
		if GS.segment_hits_rect(prev, now, t.hurt_rect().grow(8.0)):
			_hook_attach(t)
			return true
	# pickups: pull them in
	for p in game.pickups():
		if p.global_position.distance_to(now) < 40.0:
			p.magnet = self
			hook_state = "retract"
			GS.sfx(&"grapple_hit")
			return true
	for c in game.captives():
		if c.is_captive_tied() and GS.segment_hits_rect(prev, now, c.hurt_rect()):
			c.free_captive()
			hook_state = "retract"
			return true
	var q := PhysicsRayQueryParameters2D.create(prev, now, GS.L_WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		hook_pos = hit.position
		game.fx.sparks(hook_pos, hit.normal, 6, Color(0.7, 0.95, 1.0))
		GS.sfx(&"ricochet")
		hook_state = "retract"
		return true
	return false


func _hook_attach(t: Node) -> void:
	var game := GS.game
	GS.sfx(&"grapple_hit")
	game.fx.sparks(hook_pos, -hook_dir, 8, Color(0.6, 0.95, 1.0), 380.0)
	game.fx.latch(hook_pos)
	game.style_bonus(6.0)
	match t.grapple_kind():
		"light":
			t.on_grappled(self)
			hook_target = t
			hook_state = "reel"
			game.hitstop(0.04)
			GS.sfx(&"reel_zip")
		"shield":
			t.rip_shield(self)
			hook_state = "retract"
			game.hitstop(0.06)
			GS.sfx_var(&"metal", 3)
		"heavy":
			zip_target = t
			zip_t = 0.0
			state = "zip"
			hook_state = "reel_zip"
			hook_pos = t.center()
			_set_crouch(false)
			GS.sfx(&"reel_zip")
		_:
			hook_state = "retract"


func _zip_step(delta: float) -> void:
	zip_t += delta
	if zip_target == null or not is_instance_valid(zip_target) or zip_target.dead:
		state = "normal"
		hook_state = "retract"
		return
	var tc: Vector2 = zip_target.center()
	hook_pos = tc
	var to := tc - center()
	velocity = to.normalized() * 1500.0
	_after_t = 0.0
	GS.game.fx.speed_line(center(), to.normalized())
	var col := move_and_collide(velocity * delta)
	var close: bool = zip_target.hurt_rect().grow(26.0).intersects(hurt_rect())
	if close or zip_t > 0.55 or col != null:
		if close or zip_t <= 0.55:
			_grapple_strike(zip_target)
		state = "normal"
		hook_state = "none"
		zip_target = null


func _grapple_strike(t: Node) -> void:
	var game := GS.game
	var dmg := 9.0 if t.kind_name != "boss" else 12.0
	var dir := Vector2(signf(t.center().x - center().x), 0)
	if dir.x == 0.0:
		dir.x = facing
	facing = dir.x
	t.grapple_kick(dmg, dir)
	velocity = Vector2(-dir.x * 420.0, -720.0)
	invuln_t = maxf(invuln_t, 0.45)
	action_pose = "slash"
	action_t = 0.3
	game.hitstop(0.09)
	game.shake(9.0, 0.22)
	game.zoom_punch(0.07)
	game.fx.ring(t.center() - dir * 40.0, 80.0, Color(1, 1, 0.8, 0.9), 0.25)
	game.fx.sparks(t.center() - dir * 40.0, -dir, 16, Color(1, 1, 0.8), 600.0)
	game.fx.hit_flash(t.center(), Color(0.7, 0.95, 1.0))
	if game.post != null:
		game.post.shockwave(t.center(), 0.8)
	game.fx.popup(t.center() + Vector2(0, -80), "GRAPPLE KICK!", GS.C_CYAN, 26)
	GS.sfx(&"slash")
	GS.sfx_var(&"punch", 3)
	GS.sfx_var(&"metal", 3)


func _start_swing(anchor: Vector2) -> void:
	swing_anchor = anchor
	var grip := global_position + Vector2(0, -126)
	swing_len = clampf((grip - anchor).length(), 130.0, grapple_range)
	# Target rope length keeps the arc's lowest point clear of the ground.
	var ground: float = minf(GS.game.ground_top(anchor.x), GS.GROUND_Y)
	swing_target = clampf(ground - 126.0 - 36.0 - anchor.y, 120.0, 230.0)
	swing_t = 0.0
	state = "swing"
	hook_state = "swing"
	hook_pos = anchor
	_set_crouch(false)
	# yank toward the ring with forward momentum
	var to := (anchor - grip).normalized()
	velocity = velocity * 0.4 + to * 520.0 + Vector2(facing * 420.0, 0)
	GS.sfx(&"grapple_hit")
	GS.game.fx.sparks(anchor, Vector2.DOWN, 8, Color(0.6, 0.95, 1.0))
	GS.game.fx.latch(anchor)
	GS.game.on_swing()


func _swing_step(delta: float) -> void:
	swing_t += delta
	var ix := Input.get_axis(&"move_left", &"move_right") if controls else 0.0
	if ix != 0.0:
		facing = signf(ix)
	var grip := global_position + Vector2(0, -126)
	var rel := grip - swing_anchor
	var dist := rel.length()
	var radial := rel / maxf(dist, 1.0)
	var tangent := Vector2(-radial.y, radial.x)
	velocity.y += gravity * 0.9 * delta
	velocity += tangent * tangent.dot(Vector2(ix, 0)) * 1400.0 * delta
	if swing_len > swing_target + 1.0:
		swing_len = move_toward(swing_len, swing_target, 700.0 * delta)
	elif _in(&"aim_up") and swing_t > 0.35:
		swing_len = maxf(130.0, swing_len - 260.0 * delta)
	elif _in(&"aim_down"):
		swing_len = minf(grapple_range, swing_len + 260.0 * delta)
	var next := grip + velocity * delta
	var nrel := next - swing_anchor
	if nrel.length() > swing_len:
		next = swing_anchor + nrel.normalized() * swing_len
		var r2 := nrel.normalized()
		var out := velocity.dot(r2)
		if out > 0.0:
			velocity -= r2 * out
	var motion := next - grip
	var col := move_and_collide(motion)
	if col != null:
		velocity = velocity.slide(col.get_normal())
		if col.get_normal().y < -0.6 and swing_t > 0.45:
			_release_swing(false)
			return
	velocity = velocity.limit_length(1500.0)
	hook_pos = swing_anchor
	if _just(&"jump"):
		jump_buf_t = 0.0
		_release_swing(true)
	elif _just(&"grapple"):
		_release_swing(false)
	_handle_swing_fire()


func _handle_swing_fire() -> void:
	# You can still shoot while swinging.
	var w: Dictionary = WEAPONS[weapon]
	if (_just(&"shoot") or (_in(&"shoot") and fire_cd <= 0.0)) and fire_cd <= 0.0:
		_fire(w, _just(&"shoot"))


func _release_swing(boost: bool) -> void:
	state = "normal"
	hook_state = "retract"
	hook_pos = swing_anchor
	if boost:
		velocity.y = minf(velocity.y, 0.0) - 520.0
		velocity.x += facing * 120.0
		GS.sfx(&"jump")
	coyote_t = 0.0


# ---- damage / death -------------------------------------------------------------

func take_damage(amount: float, dir: Vector2) -> void:
	if not is_hittable() or invuln_t > 0.0 or god:
		return
	var game := GS.game
	if barrier_t > 0.0:
		game.fx.sparks(center(), -dir, 6, GS.C_CYAN)
		game.fx.impact_spark(center() - dir * 50.0, -dir, GS.C_CYAN)
		return
	amount *= GS.tuning("enemy_damage_scale", 1.0)
	if fury:
		amount *= 0.5
	if state == "nest":
		_dismount_nest()
	hp -= amount
	hurt_t = 0.28
	invuln_t = 1.0
	_flash_t = 0.12
	GS.sfx(&"player_hurt")
	game.shake(7.0, 0.2)
	game.hitstop(0.05)
	game.fx.sparks(center(), -dir, 10, GS.C_RED, 300.0)
	game.on_player_hurt(amount, dir)
	hurt.emit()
	if state == "normal":
		velocity = Vector2(signf(dir.x) * 280.0 if dir.x != 0.0 else -facing * 280.0, -320.0)
	if hp <= 0.0:
		hp = 0.0
		die()


func die() -> void:
	if state == "dead":
		return
	if nest != null:
		_dismount_nest()
	drop_carried()
	hook_state = "none"
	zip_target = null
	state = "dead"
	dead_t = 0.0
	_set_crouch(false)
	velocity = Vector2(-facing * 220.0, -560.0)
	collision_mask = GS.L_WORLD | GS.L_PLATFORM
	died.emit()


func _dead_step(delta: float) -> void:
	dead_t += delta
	velocity.y = minf(velocity.y + gravity * delta, 1500.0)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	move_and_slide()


func _fall_out() -> void:
	drop_carried()
	hook_state = "none"
	state = "normal"
	var game := GS.game
	var loss := 12.0 * GS.tuning("enemy_damage_scale", 1.0)
	hp -= loss
	GS.sfx(&"player_hurt")
	if hp <= 0.0:
		hp = 0.0
		global_position = last_safe
		velocity = Vector2.ZERO
		die()
		return
	global_position = last_safe + Vector2(0, -10)
	velocity = Vector2.ZERO
	invuln_t = 1.6
	game.fx.popup(global_position + Vector2(0, -130), "-%d" % int(round(loss)), GS.C_RED, 22)
	game.snap_camera()


func respawn(pos: Vector2) -> void:
	state = "normal"
	hp = max_hp
	invuln_t = 2.5
	global_position = pos
	velocity = Vector2(0, 200)
	weapon = "pistol"
	ammo = 0
	grenades = maxi(grenades, 5)
	hook_state = "none"
	carried = null
	last_safe = pos
	controls = true
	nest = null
	fury = false
	afterimages.clear()


# ---- drawing ----------------------------------------------------------------------

func _pose() -> Array:
	# returns [sheet, frame]
	if state == "dead":
		return ["hero", "dead" if is_on_floor() and dead_t > 0.2 else "hurt"]
	if hurt_t > 0.0:
		return ["hero", "hurt"]
	if action_t > 0.0 and not action_pose.is_empty():
		return ["hero", action_pose]
	if state == "nest":
		return ["hero", "crouch"]
	if state == "swing":
		return ["hero", "aim_up"]
	if state == "zip" or hook_state == "reel_zip":
		return ["hero", "grapple"]
	if hook_state in ["out", "reel", "retract"]:
		return ["hero", "aim_up" if hook_up else "grapple"]
	if carried != null:
		return ["hero", "grapple" if carried_is_enemy else "carry"]
	if not is_on_floor():
		if _in(&"aim_down"):
			return ["hero", "aim_down"]
		if _in(&"aim_up"):
			return ["hero", "aim_up"]
		return ["hero", "jump"]
	if crouching:
		return ["hero", "crouch"]
	if _in(&"aim_up"):
		return ["hero", "aim_up"]
	if absf(velocity.x) > 30.0:
		return ["hero_run", "run%d" % (int(run_phase) % 8)]
	return ["hero", "idle" if int(anim_t * 2.0) % 2 == 0 else "idle2"]


func _draw() -> void:
	var visible_frame := not (invuln_t > 0.0 and state != "dead" and hurt_t <= 0.0 and int(anim_t * 20.0) % 2 == 0)
	if fury:
		visible_frame = true
	# afterimages (zip, swing and FURY)
	for a in afterimages:
		var k: float = a[4] / 0.28
		var ac := Color(1.0, 0.75, 0.2, 0.45 * k) if fury else Color(0.45, 0.9, 1.0, 0.4 * k)
		SpriteLib.draw(self, a[1], a[2], a[0] - global_position, a[3], 1.0, ac)
	if fury:
		var pulse := 0.5 + 0.5 * sin(anim_t * 16.0)
		draw_circle(Vector2(0, -52), 64.0 + pulse * 6.0, Color(1.0, 0.7, 0.15, 0.10))
		draw_arc(Vector2(0, -52), 60.0 + pulse * 8.0, 0, TAU, 36, Color(1.0, 0.8, 0.3, 0.45), 2.5)
	# cable behind the body
	if hook_state != "none":
		var from := _hand() - global_position
		if state == "swing":
			from = Vector2(0, -126)
		var to := hook_pos - global_position
		var glow := 0.5 + 0.5 * sin(anim_t * 30.0)
		draw_line(from, to, Color(0.3, 0.85, 1.0, 0.18 + 0.12 * glow), 10.0)
		draw_line(from, to, Color(0.08, 0.1, 0.12), 5.0)
		draw_line(from, to, Color(0.6, 0.92, 1.0).lerp(Color.WHITE, glow * 0.5), 2.0)
		# energy nodes travelling along the cable
		var seg_len := from.distance_to(to)
		if seg_len > 20.0:
			for i in 3:
				var f := fmod(anim_t * 2.6 + i / 3.0, 1.0)
				draw_circle(from.lerp(to, f), 3.0, Color(0.8, 0.97, 1.0, 0.9))
		var ang := (to - from).angle()
		_draw_claw(to, ang)
	if visible_frame:
		var pose := _pose()
		var rot := 0.0
		if state == "swing":
			rot = clampf(velocity.x / 1400.0, -0.5, 0.5)
		var base := Transform2D.IDENTITY
		if rot != 0.0:
			var pivot := Vector2(0, -126)
			base = Transform2D(rot, pivot) * Transform2D(0.0, -pivot)
		if squash != 0.0 and not GS.reduced_motion():
			var sq := Vector2(1.0 + squash * 0.16, 1.0 - squash * 0.14)
			base = base * Transform2D(0.0, sq, 0.0, Vector2.ZERO)
		var mod := Color(1.0, 0.93, 0.7) if fury else Color.WHITE
		SpriteLib.draw(self, pose[0], pose[1], Vector2(-facing * recoil, 0), facing < 0.0, 1.0, mod, 0.0, base)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if barrier_t > 0.0:
		var k := 0.6 + 0.4 * sin(anim_t * 12.0)
		var fade := minf(1.0, barrier_t)
		draw_circle(Vector2(0, -52), 70.0, Color(0.3, 0.85, 1.0, 0.12 * fade))
		draw_arc(Vector2(0, -52), 70.0, 0, TAU, 40, Color(0.5, 0.95, 1.0, 0.7 * k * fade), 3.0)


func _draw_claw(p: Vector2, ang: float) -> void:
	draw_set_transform(p, ang, Vector2.ONE)
	draw_circle(Vector2.ZERO, 8.0, Color(0.08, 0.1, 0.12))
	draw_circle(Vector2.ZERO, 5.5, Color(0.6, 0.9, 1.0))
	for s in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(10, s * 9), Vector2(18, s * 4)]), Color(0.08, 0.1, 0.12), 5.0)
		draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(10, s * 9), Vector2(18, s * 4)]), Color(0.75, 0.8, 0.85), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- v2: afterimages, FURY aura, mounted MG --------------------------------------

func _update_afterimages(delta: float) -> void:
	for a in afterimages:
		a[4] -= delta
	afterimages = afterimages.filter(func(a): return a[4] > 0.0)
	if state == "dead":
		return
	var trail := fury or state == "zip" or (state == "swing" and velocity.length() > 600.0)
	if not trail:
		return
	_after_t -= delta
	if _after_t <= 0.0:
		_after_t = 0.045
		var pose := _pose()
		afterimages.append([global_position, pose[0], pose[1], facing < 0.0, 0.28])
		if afterimages.size() > 8:
			afterimages.pop_front()
	if fury:
		fury_t += delta
		if fmod(fury_t, 0.06) < delta:
			GS.game.fx.fury_ember(center())


func _try_mount_nest() -> bool:
	var n: Node = GS.game.nest_near(global_position, 90.0)
	if n == null or not n.can_mount():
		return false
	nest = n
	state = "nest"
	hook_state = "none"
	_set_crouch(false)
	velocity = Vector2.ZERO
	facing = n.facing
	nest_aim = 0.0
	n.mount(self)
	GS.sfx(&"grab")
	return true


func _dismount_nest() -> void:
	if nest != null and is_instance_valid(nest):
		nest.dismount()
	nest = null
	if state == "nest":
		state = "normal"
		velocity = Vector2(-facing * 160.0, -300.0)


func _nest_step(delta: float) -> void:
	if nest == null or not is_instance_valid(nest):
		state = "normal"
		return
	global_position = global_position.lerp(nest.seat_position(), minf(1.0, delta * 20.0))
	velocity = Vector2.ZERO
	facing = nest.facing
	var up := _in(&"aim_up")
	var down := _in(&"aim_down")
	var target := -0.42 if up else (0.2 if down else 0.0)
	nest_aim = move_toward(nest_aim, target, delta * 2.4)
	nest.aim = nest_aim
	if _just(&"grab") or _just(&"jump") or _just(&"grapple"):
		jump_buf_t = 0.0
		_dismount_nest()
		return
	if _in(&"shoot"):
		nest.try_fire(fury)
	if _just(&"use_item"):
		_use_item()
