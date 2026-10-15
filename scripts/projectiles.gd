extends Node2D
## Batched projectiles for both teams. Collision is swept segment-vs-rect
## against game.targets() (player team) or the player/hostage (enemy team),
## plus a world ray so shots stop on terrain.

enum K { BULLET, HMG, PELLET, ROCKET, GRENADE, EBULLET, SHELL, MORTAR, BOMB, MISSILE }
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const TEAM_NONE := -1

var list: Array[Dictionary] = []
# marker: {pos, t, max_t, radius}
var markers: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	z_index = 45


var fired_total := 0


func fire(kind: int, pos: Vector2, vel: Vector2, team: int, dmg: float, extra: Dictionary = {}) -> Dictionary:
	fired_total += 1
	var p := {
		"kind": kind, "pos": pos, "vel": vel, "team": team, "dmg": dmg,
		"life": 1.6, "gravity": 0.0, "radius": 0.0, "rot": 0.0, "age": 0.0,
	}
	match kind:
		K.PELLET:
			p.life = 0.42
		K.ROCKET:
			p.life = 2.2
			p.radius = 95.0
		K.GRENADE:
			p.life = 1.5
			p.gravity = 1500.0
			p.radius = 115.0
		K.EBULLET:
			p.life = 3.0
		K.SHELL:
			p.life = 3.5
			p.radius = 70.0
		K.MORTAR:
			p.life = 6.0
			p.gravity = 900.0
			p.radius = 80.0
		K.BOMB:
			p.life = 4.0
			p.gravity = 1100.0
			p.radius = 70.0
		K.MISSILE:
			p.life = 4.0
			p.radius = 85.0
	p.merge(extra, true)
	list.append(p)
	return p


func add_marker(pos: Vector2, time: float, radius: float) -> void:
	markers.append({"pos": pos, "t": 0.0, "max_t": time, "radius": radius})


func clear() -> void:
	list.clear()
	markers.clear()


func _physics_process(delta: float) -> void:
	var game := GS.game
	if game == null:
		return
	_time += delta
	var space := get_world_2d().direct_space_state
	var view: Rect2 = game.view_rect().grow(260.0)
	var alive: Array[Dictionary] = []
	for p in list:
		if _step(p, delta, space, game, view):
			alive.append(p)
	list = alive
	for m in markers:
		m.t += delta
	markers = markers.filter(func(m): return m.t < m.max_t)
	queue_redraw()


func _step(p: Dictionary, delta: float, space: PhysicsDirectSpaceState2D, game: Node, view: Rect2) -> bool:
	p.age += delta
	p.life -= delta
	var prev: Vector2 = p.pos
	var vel: Vector2 = p.vel
	var kind: int = p.kind
	if kind == K.ROCKET:
		var speed := minf(vel.length() + 2600.0 * delta, 1500.0)
		var target = game.nearest_target(p.pos, vel.normalized(), 520.0)
		if target != null and p.age > 0.08:
			var want: Vector2 = (target.hurt_rect().get_center() - p.pos).normalized()
			var ang := vel.angle()
			ang = rotate_toward(ang, want.angle(), 3.2 * delta)
			vel = Vector2.from_angle(ang) * speed
		else:
			vel = vel.normalized() * speed
			if int(p.age * 60.0) % 2 == 0:
				game.fx.smoke(p.pos - vel.normalized() * 14.0, 1, 7.0, Color(0.85, 0.85, 0.85, 0.5))
			game.fx.trail(p.pos - vel.normalized() * 22.0, Color(1.0, 0.6, 0.2, 0.5), 22.0)
	elif kind == K.MISSILE:
		vel.y = minf(vel.y + 1800.0 * delta, 1300.0)
		if int(p.age * 60.0) % 3 == 0:
			game.fx.smoke(p.pos - Vector2(0, 16), 1, 7.0, Color(0.7, 0.7, 0.7, 0.5))
	vel.y += float(p.gravity) * delta
	var pos: Vector2 = prev + vel * delta
	p.vel = vel
	p.rot += delta * (14.0 if kind == K.GRENADE else 0.0)
	var team: int = p.team

	# Team hits
	if team == TEAM_PLAYER:
		for t in game.targets():
			if not is_instance_valid(t) or p.has("ignore") and p.ignore == t:
				continue
			var r: Rect2 = t.hurt_rect()
			if GS.segment_hits_rect(prev, pos, r.grow(float(p.get("hit_pad", 2.0)))):
				if kind in [K.ROCKET, K.GRENADE]:
					game.explode(pos, p.radius, _explosive_dmg(p), TEAM_PLAYER, 1.0)
					return false
				var res: String = t.take_hit(p.dmg, vel.normalized(), "bullet")
				if res == "block":
					GS.sfx(&"ricochet")
					game.fx.sparks(pos, Vector2(-signf(vel.x), -0.6).normalized(), 7, Color(1, 1, 0.8), 380.0)
					game.fx.impact_spark(pos, Vector2(-signf(vel.x), 0), Color(1, 1, 0.8))
					GS.sfx_var(&"metal", 3)
					p.team = TEAM_NONE
					p.vel = Vector2(-vel.x * 0.5, -absf(vel.x) * 0.45)
					p.gravity = 1400.0
					p.life = 0.35
					p.pos = pos
					return true
				var gold: bool = p.get("gold", false)
				var icol := Color(1.0, 0.8, 0.25) if gold else Color(1.0, 0.9, 0.5)
				game.fx.impact_spark(pos, -vel.normalized(), icol)
				var kn: String = str(t.get("kind_name")) if "kind_name" in t else ""
				if kn in ["drone", "mortar", "boss"]:
					GS.sfx_var(&"metal", 3)
				if int(p.get("pierce", 0)) > 0 and res == "hit":
					p.pierce = int(p.pierce) - 1
					p.ignore = t
					p.pos = pos
					return true
				return false
	elif team == TEAM_ENEMY:
		var player = game.player
		if player != null and player.is_hittable():
			var hostage = player.hostage()
			if hostage != null and GS.segment_hits_rect(prev, pos, hostage.hurt_rect()):
				if kind in [K.SHELL, K.MORTAR, K.BOMB, K.MISSILE]:
					game.explode(pos, p.radius, p.dmg, TEAM_ENEMY, 0.9)
				else:
					hostage.hostage_hit(p.dmg)
					game.fx.sparks(pos, -vel.normalized(), 5, GS.C_RED, 260.0)
				return false
			if GS.segment_hits_rect(prev, pos, player.hurt_rect()):
				if kind in [K.SHELL, K.MORTAR, K.BOMB, K.MISSILE]:
					game.explode(pos, p.radius, p.dmg, TEAM_ENEMY, 0.9)
				else:
					player.take_damage(p.dmg, vel.normalized())
					game.fx.sparks(pos, -vel.normalized(), 6, GS.C_RED, 260.0)
				return false

	# World collision (platforms stop falling explosives only)
	var mask := GS.L_WORLD
	if p.gravity > 0.0 and vel.y > 0.0:
		mask |= GS.L_PLATFORM
	var q := PhysicsRayQueryParameters2D.create(prev, pos, mask)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector2 = hit.position
		var n: Vector2 = hit.normal
		if (mask & GS.L_PLATFORM) and n.y > -0.5 and hit.collider is Node and (hit.collider as Node).is_in_group("platform"):
			pass  # side of a one-way platform: ignore
		else:
			match kind:
				K.GRENADE:
					if p.age < 0.9 and absf(n.y) > 0.5:
						p.pos = hp + n * 2.0
						p.vel = Vector2(vel.x * 0.55, -absf(vel.y) * 0.42) if n.y < 0 else vel.bounce(n) * 0.5
						if team == TEAM_PLAYER:
							game.panic_near(hp, 260.0, 1.3)
						GS.sfx_var(&"thud", 2)
						return true
					elif absf(n.x) > 0.5:
						p.pos = hp + n * 2.0
						p.vel = vel.bounce(n) * 0.5
						return true
					game.explode(hp, p.radius, _explosive_dmg(p), team, 1.0)
					return false
				K.ROCKET:
					game.explode(hp, p.radius, _explosive_dmg(p), team, 1.0)
					return false
				K.SHELL, K.MORTAR, K.BOMB, K.MISSILE:
					game.explode(hp, p.radius, p.dmg, team, 1.0 if kind != K.BOMB else 0.8)
					return false
				_:
					game.fx.impact_spark(hp, n, Color(1.0, 0.9, 0.5) if team == TEAM_PLAYER else Color(1.0, 0.4, 0.4))
					if n.y < -0.5:
						game.fx.dust(hp, 2, 0.5)
					else:
						game.fx.debris(hp, 2, Color("#6a5a4a"), 200.0, 4.0)
					return false
	p.pos = pos
	if p.life <= 0.0:
		if kind in [K.GRENADE, K.ROCKET, K.SHELL, K.MORTAR, K.BOMB, K.MISSILE]:
			game.explode(pos, p.radius, _explosive_dmg(p) if team == TEAM_PLAYER else p.dmg, team, 0.9)
		return false
	if not view.has_point(pos) and kind not in [K.MORTAR, K.MISSILE, K.GRENADE]:
		return false
	if pos.y > GS.KILL_Y:
		return false
	return true


func _explosive_dmg(p: Dictionary) -> float:
	return float(p.dmg)


func _draw() -> void:
	for m in markers:
		var k: float = m.t / m.max_t
		var pulse := 0.5 + 0.5 * sin(_time * 22.0)
		var c := Color(1.0, 0.15, 0.1, 0.35 + 0.35 * pulse)
		var r: float = m.radius * (0.55 + 0.45 * k)
		draw_set_transform(m.pos, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, r, Color(1, 0.1, 0.05, 0.16 + 0.12 * k))
		draw_arc(Vector2.ZERO, m.radius, 0, TAU, 40, c, 4.0)
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1, 0.8, 0.2, 0.8), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in list:
		var pos: Vector2 = p.pos
		var vel: Vector2 = p.vel
		var dir := vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
		if p.get("gold", false) and int(p.kind) in [K.BULLET, K.HMG, K.PELLET]:
			draw_line(pos - dir * 34.0, pos, Color(1.0, 0.6, 0.05, 0.35), 14.0)
			draw_line(pos - dir * 26.0, pos, Color(1.0, 0.8, 0.2, 0.9), 6.0)
			draw_line(pos - dir * 18.0, pos, Color(1.0, 1.0, 0.85), 3.0)
			continue
		match int(p.kind):
			K.BULLET:
				draw_line(pos - dir * 22.0, pos, Color(1.0, 0.5, 0.1, 0.18), 12.0)
				draw_line(pos - dir * 16.0, pos, Color(1.0, 0.55, 0.1, 0.55), 7.0)
				draw_line(pos - dir * 12.0, pos, Color(1.0, 0.95, 0.55), 3.5)
			K.HMG:
				draw_line(pos - dir * 30.0, pos, Color(1.0, 0.45, 0.05, 0.2), 14.0)
				draw_line(pos - dir * 24.0, pos, Color(1.0, 0.45, 0.05, 0.6), 9.0)
				draw_line(pos - dir * 18.0, pos, Color(1.0, 0.92, 0.5), 4.5)
			K.PELLET:
				draw_circle(pos, 8.0, Color(0.2, 0.85, 1.0, 0.45))
				draw_circle(pos, 4.5, Color(0.85, 1.0, 1.0))
			K.ROCKET:
				draw_set_transform(pos, dir.angle(), Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(-26, -3), Vector2(-40, 0), Vector2(-26, 3)]), Color(1, 0.8, 0.2, 0.9))
				draw_rect(Rect2(-22, -5, 22, 10), Color("#556b2f"))
				draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(10, 0), Vector2(0, 5)]), GS.C_RED)
				draw_rect(Rect2(-22, -5, 32, 10), GS.C_INK, false, 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.GRENADE:
				draw_set_transform(pos, p.rot, Vector2.ONE)
				draw_circle(Vector2.ZERO, 9.0, GS.C_INK)
				draw_circle(Vector2.ZERO, 7.0, Color("#5d6b2a"))
				draw_rect(Rect2(-3, -11, 6, 5), Color("#8a8f98"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.EBULLET:
				draw_circle(pos, 14.0, Color(1.0, 0.1, 0.3, 0.14))
				draw_circle(pos, 9.0, Color(1.0, 0.1, 0.35, 0.35))
				draw_circle(pos, 6.0, Color("#ff3b5c"))
				draw_circle(pos, 3.0, Color(1, 0.9, 0.9))
			K.SHELL:
				draw_line(pos - dir * 30.0, pos, Color(1.0, 0.35, 0.1, 0.4), 16.0)
				draw_circle(pos, 14.0, GS.C_INK)
				draw_circle(pos, 11.0, Color("#ff5a1f"))
				draw_circle(pos, 5.0, Color(1, 0.95, 0.7))
			K.MORTAR, K.BOMB:
				draw_circle(pos, 11.0, GS.C_INK)
				draw_circle(pos, 8.5, Color("#40444c"))
				if int(p.age * 12.0) % 2 == 0:
					draw_circle(pos + Vector2(0, -3), 3.0, GS.C_RED)
			K.MISSILE:
				draw_set_transform(pos, PI * 0.5, Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(-30, -4), Vector2(-46, 0), Vector2(-30, 4)]), Color(1, 0.7, 0.2, 0.9))
				draw_rect(Rect2(-28, -6, 28, 12), Color("#5a1d1d"))
				draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(12, 0), Vector2(0, 6)]), Color("#d9d9d9"))
				draw_rect(Rect2(-28, -6, 40, 12), GS.C_INK, false, 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_circle(pos, 3.0, Color(1, 1, 0.8, 0.8))
