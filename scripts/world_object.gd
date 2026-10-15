extends Node2D
## Small world objects: tied captive (rescue for items/score), grapple ring
## anchor, and checkpoint flag. Selected by `kind`.

var kind := "captive"
var data: Dictionary = {}
var t := 0.0
var state := "idle"
var state_t := 0.0
var facing := 1.0
var alpha := 1.0
var flag_rise := 0.0
# MG nest
const P := preload("res://scripts/projectiles.gd")
var aim := 0.0
var heat := 0.0
var overheat_t := 0.0
var fire_cd := 0.0
var gunner: Node = null
var recoil := 0.0


func setup(k: String, pos: Vector2, d: Dictionary) -> void:
	kind = k
	data = d
	global_position = pos
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 2 if kind != "anchor" else 1


# ---- captive --------------------------------------------------------------

func hurt_rect() -> Rect2:
	return Rect2(global_position - Vector2(22, 96), Vector2(44, 96))


func center() -> Vector2:
	return global_position + Vector2(0, -50)


func is_captive_tied() -> bool:
	return kind == "captive" and state == "idle"


func take_hit(_dmg: float, _dir: Vector2, _kind: String) -> String:
	if is_captive_tied():
		free_captive()
		return "hit"
	return "none"


func free_captive() -> void:
	if not is_captive_tied():
		return
	state = "salute"
	state_t = 0.0
	var game := GS.game
	GS.sfx(&"rescue")
	game.on_captive_freed(self)
	game.fx.popup(global_position + Vector2(0, -120), "THANK YOU!", GS.C_CREAM, 22)
	game.fx.ring(center(), 60.0, Color(1, 1, 0.7, 0.9), 0.35)
	game.fx.pickup_burst(center(), GS.C_YELLOW)
	game.fx.splinters(center(), 0.6)


# ---- MG nest ----------------------------------------------------------------

func can_mount() -> bool:
	return kind == "nest" and gunner == null


func mount(h: Node) -> void:
	gunner = h
	GS.game.on_nest_mounted(self)


func dismount() -> void:
	gunner = null


func seat_position() -> Vector2:
	return global_position + Vector2(-facing * 46.0, 0)


func muzzle() -> Vector2:
	return global_position + Vector2(0, -52) + Vector2(facing, 0).rotated(aim * facing) * 74.0


func try_fire(fury: bool) -> void:
	if overheat_t > 0.0 or fire_cd > 0.0:
		return
	var game := GS.game
	fire_cd = 0.06 if not fury else 0.045
	var dir := Vector2(facing, 0).rotated(aim * facing + randf_range(-0.035, 0.035))
	var from := muzzle()
	var extra: Dictionary = {"gold": true, "pierce": 2} if fury else {}
	game.proj.fire(P.K.HMG, from, dir * 1750.0, P.TEAM_PLAYER, 1.5 if not fury else 2.2, extra)
	game.fx.muzzle(from, dir.angle(), 1.4, Color(1.0, 0.85, 0.35), "mg")
	game.fx.casing(global_position + Vector2(-facing * 10.0, -48.0), facing)
	game.kick(-dir, 1.3)
	game.shake(1.2, 0.05)
	recoil = 6.0
	GS.sfx(&"mg_nest")
	if not fury:
		heat += 0.03
	if heat >= 1.0:
		heat = 1.0
		overheat_t = 1.8
		GS.sfx(&"overheat")
		game.fx.popup(global_position + Vector2(0, -110), "OVERHEAT!", GS.C_RED, 22)


func _physics_process(delta: float) -> void:
	t += delta
	state_t += delta
	var game := GS.game
	match kind:
		"captive":
			if state == "idle":
				var p = game.player
				if p != null and p.is_hittable() and p.hurt_rect().grow(12.0).intersects(hurt_rect()):
					free_captive()
			elif state == "salute":
				if state_t > 0.9:
					state = "run"
					state_t = 0.0
					var item := str(data.get("item", ""))
					if not item.is_empty():
						game.spawn_pickup(item, global_position + Vector2(20, -60), true)
			elif state == "run":
				facing = -1.0
				global_position.x -= 260.0 * delta
				alpha = maxf(0.0, 1.0 - state_t / 1.4)
				if alpha <= 0.0:
					queue_free()
		"checkpoint":
			if state == "idle" and game.player != null and game.player.global_position.x > global_position.x - 20.0:
				state = "active"
				state_t = 0.0
				game.on_checkpoint(self)
			if state == "active":
				flag_rise = minf(1.0, flag_rise + delta * 2.5)
		"nest":
			fire_cd = maxf(0.0, fire_cd - delta)
			recoil = move_toward(recoil, 0.0, delta * 50.0)
			if overheat_t > 0.0:
				overheat_t -= delta
				heat = maxf(0.0, heat - delta * 0.5)
				if fmod(t, 0.1) < delta:
					game.fx.smoke(muzzle() + Vector2(-facing * 30.0, -6), 1, 12.0, Color(0.9, 0.9, 0.9, 0.5))
			elif fire_cd <= 0.0:
				heat = maxf(0.0, heat - delta * 0.42)
			if gunner == null:
				aim = move_toward(aim, 0.0, delta)
		"goal":
			if state == "idle" and game.player != null and game.player.global_position.x > global_position.x - 40.0:
				state = "active"
				state_t = 0.0
				game.fx.pickup_burst(global_position + Vector2(0, -100), GS.C_YELLOW)
			if state == "active":
				flag_rise = minf(1.0, flag_rise + delta * 2.5)
	queue_redraw()


func _draw() -> void:
	match kind:
		"captive":
			var mod := Color(1, 1, 1, alpha)
			if state == "idle":
				var wob := sin(t * 3.0) * 0.04
				SpriteLib.draw(self, "props", "pow_tied", Vector2.ZERO, false, 1.0, mod, wob)
				# "HELP" bubble
				var y := -118.0 + sin(t * 4.0) * 3.0
				draw_rect(Rect2(-30, y - 16, 60, 24), Color(1, 1, 1, 0.92))
				draw_rect(Rect2(-30, y - 16, 60, 24), GS.C_INK, false, 2.0)
				draw_string(UIKit.BOLD, Vector2(-25, y + 2), "HELP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GS.C_RED)
			else:
				var hop := -absf(sin(state_t * 14.0)) * 8.0 if state == "run" else 0.0
				SpriteLib.draw(self, "props", "pow_free", Vector2(0, hop), facing < 0.0, 1.0, mod)
		"anchor":
			var p = GS.game.player if GS.game != null else null
			var in_range := false
			if p != null:
				in_range = p.center().distance_to(global_position) < p.grapple_range + 20.0
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			if in_range:
				draw_arc(Vector2.ZERO, 34.0 + pulse * 8.0, 0, TAU, 32, Color(0.3, 0.9, 1.0, 0.5 + 0.4 * pulse), 4.0)
			draw_line(Vector2(0, -400), Vector2(0, -26), Color(0.15, 0.13, 0.12, 0.9), 4.0)
			SpriteLib.draw(self, "props", "anchor", Vector2(0, 36), false, 1.0)
		"checkpoint":
			draw_line(Vector2(0, 0), Vector2(0, -130), Color("#2b2320"), 5.0)
			var fy := lerpf(-40.0, -120.0, flag_rise)
			var col := GS.C_CYAN if state == "active" else Color("#9a8f86")
			var wave := sin(t * 6.0) * 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(3, fy), Vector2(58, fy + 12 + wave), Vector2(3, fy + 30)]), col)
			draw_polyline(PackedVector2Array([Vector2(3, fy), Vector2(58, fy + 12 + wave), Vector2(3, fy + 30)]), GS.C_INK, 2.0)
			draw_circle(Vector2(0, -132), 6.0, GS.C_YELLOW)
		"nest":
			SpriteLib.draw(self, "props2", "nest_base", Vector2.ZERO, facing < 0.0, 1.0)
			var hk := heat
			var gun_mod := Color(1.0, 1.0 - hk * 0.45, 1.0 - hk * 0.7)
			var pivot := Vector2(0, -52)
			var base := Transform2D(aim * facing, pivot) * Transform2D(0.0, Vector2(-facing * recoil, 0))
			SpriteLib.draw(self, "props2", "mg_gun", Vector2(facing * 10.0, 18.0), facing < 0.0, 1.0, gun_mod, 0.0, base)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			# glowing barrel when hot
			if hk > 0.3:
				var mz := muzzle() - global_position - Vector2(facing * 20.0, 0)
				draw_circle(mz, 7.0 + hk * 4.0, Color(1.0, 0.35, 0.1, (hk - 0.3) * 0.6))
			# heat gauge
			if gunner != null or hk > 0.05:
				var w := 64.0
				var r := Rect2(-w * 0.5, -104, w, 8)
				draw_rect(r.grow(2.0), GS.C_INK)
				var hc := Color(1.0, 0.8, 0.2).lerp(GS.C_RED, hk)
				if overheat_t > 0.0 and int(t * 10.0) % 2 == 0:
					hc = Color.WHITE
				draw_rect(Rect2(r.position, Vector2(w * hk, 8)), hc)
				draw_string(UIKit.BOLD, Vector2(-w * 0.5, -110), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_CREAM)
			elif gunner == null:
				var bob := sin(t * 5.0) * 4.0
				draw_string(UIKit.BOLD, Vector2(-34, -92 + bob), "[L] MAN IT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GS.C_YELLOW)
		"goal":
			SpriteLib.draw(self, "props2", "sign", Vector2(-70, 0), false, 1.2)
			draw_line(Vector2(0, 0), Vector2(0, -170), Color("#2b2320"), 6.0)
			var gy := lerpf(-60.0, -160.0, flag_rise)
			var gw := sin(t * 6.0) * 6.0
			var pts := PackedVector2Array([Vector2(3, gy), Vector2(78, gy + 16 + gw), Vector2(3, gy + 38)])
			draw_colored_polygon(pts, GS.C_YELLOW if state == "active" else GS.C_ORANGE)
			draw_polyline(pts, GS.C_INK, 2.5)
			draw_circle(Vector2(0, -172), 7.0, GS.C_YELLOW)
			if state == "idle":
				var gb := sin(t * 4.0) * 4.0
				draw_string(UIKit.DISPLAY, Vector2(-60, -196 + gb), "STAGE END", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GS.C_YELLOW)
