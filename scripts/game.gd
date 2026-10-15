extends Node2D
## Side Scroller — mission orchestrator: three stages (town / canyon /
## fortress) with streamed assets, arena locks & waves, STYLE rank + FURY,
## chain reactions, trauma camera, hit-stop / slow-mo, post FX, stage tally,
## death/respawn, boss flow and results.

const LEVEL := preload("res://scripts/level_data.gd")
const HERO := preload("res://scripts/hero.gd")
const PROP := preload("res://scripts/prop.gd")
const PICKUP := preload("res://scripts/pickup.gd")
const WOBJ := preload("res://scripts/world_object.gd")
const FX := preload("res://scripts/fx.gd")
const PROJ := preload("res://scripts/projectiles.gd")
const TERRAIN := preload("res://scripts/terrain.gd")
const BG := preload("res://scripts/background.gd")
const HUD := preload("res://scripts/hud.gd")
const DECOR := preload("res://scripts/decor.gd")
const HINTS := preload("res://scripts/world_hints.gd")
const STYLE := preload("res://scripts/style.gd")
const POST := preload("res://scripts/post.gd")
const CATALOG := preload("res://scripts/audio_catalog.gd")
const ENEMY := {
	"grunt": preload("res://scripts/enemy_grunt.gd"),
	"shield": preload("res://scripts/enemy_shield.gd"),
	"brute": preload("res://scripts/enemy_brute.gd"),
	"drone": preload("res://scripts/enemy_drone.gd"),
	"mortar": preload("res://scripts/enemy_mortar.gd"),
	"boss": preload("res://scripts/boss.gd"),
}
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const SAVE_PATH := "user://grapple_strike.cfg"

var level: Dictionary
var player: CharacterBody2D
var fx: Node2D
var proj: Node2D
var terrain: Node2D
var decor: Node2D
var hud: CanvasLayer
var post: CanvasLayer
var camera: Camera2D
var world: Node2D
var layer_enemies: Node2D
var layer_props: Node2D
var layer_objects: Node2D
var layer_pickups: Node2D
var background: Node2D
var style: RefCounted

var enemies: Array = []
var props_list: Array = []
var captives_list: Array = []
var anchors: Array = []
var nests: Array = []
var pending: Array = []
var tips: Array = []
var tips_shown: Dictionary = {}

var stage_i := 0
var stage_stats := {"t0": 0.0, "kills0": 0, "captives0": 0, "score0": 0}
var tally: Dictionary = {}
var music_wanted := ""
var music_playing := ""

var cam_left := 0.0
var cam_y := 360.0
var locks: Array = []
var lock: Dictionary = {}
var lock_active := false
var wave_i := 0
var wave_delay := 0.0
var go_t := 0.0
var boss: Node = null
var boss_state := "none"  # none, intro, fight, dying, dead
var supply_t := 0.0

var score := 0
var best_score := 0
var combo := 0
var combo_t := 0.0
var best_combo := 0
var lives := 3
var stats := {"kills": 0, "thrown": 0, "strikes": 0, "captives": 0, "captives_total": 0, "continues": 0, "chains": 0, "best_chain": 0, "furies": 0}
var mission_time := 0.0
var game_state := "play"  # play, dead_wait, tally, gameover, victory
var state_t := 0.0
var checkpoint_x := 0.0

# camera juice
var trauma := 0.0
var kick_off := Vector2.ZERO
var zoom_extra := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var hitstop_left := 0.0
var slowmo_left := 0.0
var slowmo_scale := 1.0
var flash_a := 0.0

var chain_best_now := 0
var chain_t := 0.0
var heartbeat_t := 0.0
var in_combat_t := 0.0
var _targets_frame := -1
var _targets_cache: Array = []
var _cull_t := 0.0
var _retry_t := 0.0


func _ready() -> void:
	GS.game = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	level = LEVEL.data()
	if has_node("/root/TuningStore"):
		TuningStore.begin_run()
	lives = int(GS.tuning("lives", 3.0))
	best_score = _load_best()
	style = STYLE.new()
	style.setup()
	style.rank_changed.connect(_on_rank_changed)
	style.fury_ready.connect(_on_fury_ready)
	_noise.frequency = 0.9
	_build()
	if has_node("/root/Segments"):
		Segments.start()
		Segments.segment_ready.connect(_on_segment_ready)
	if has_node("/root/GameAudio"):
		GameAudio.begin_game()
	_apply_stage_theme(true)
	GS.sfx(&"mission_start")
	GS.sfx(&"vo_mission_start")
	hud.banner("MISSION START!", "Operation: Dust Fang", 2.2)
	hud.stage_intro(stage().name, stage().sub, 2.4)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if GS.game == self:
		GS.game = null
	if has_node("/root/TuningStore"):
		TuningStore.end_run()


func stage() -> Dictionary:
	return level.stages[stage_i]


func _build() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "Backdrop"
	bg_layer.layer = -10
	add_child(bg_layer)
	background = BG.new()
	bg_layer.add_child(background)

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	decor = DECOR.new()
	decor.name = "Decor"
	world.add_child(decor)
	decor.build(level.decor)
	terrain = TERRAIN.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	terrain.build(level)
	layer_objects = _layer("Objects")
	layer_props = _layer("Props")
	layer_enemies = _layer("Enemies")
	player = HERO.new()
	player.name = "Player"
	player.add_to_group("player")
	player.global_position = level.start
	world.add_child(player)
	player.died.connect(_on_player_died)
	layer_pickups = _layer("Pickups")
	proj = PROJ.new()
	proj.name = "Projectiles"
	world.add_child(proj)
	fx = FX.new()
	fx.name = "Fx"
	world.add_child(fx)
	var hints := HINTS.new()
	hints.name = "Hints"
	world.add_child(hints)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.ignore_rotation = false
	add_child(camera)
	camera.make_current()
	checkpoint_x = level.start.x

	for p in level.props:
		_spawn_prop(p[0], Vector2(p[1], p[2]), p[3])
	for p in level.pickups:
		spawn_pickup(p[0], Vector2(p[1], p[2]), false)
	for c in level.captives:
		var o := WOBJ.new()
		layer_objects.add_child(o)
		o.setup("captive", Vector2(c[0], c[1]), {"item": c[2]})
		captives_list.append(o)
	stats.captives_total = level.captives.size()
	for a in level.anchors:
		var o2 := WOBJ.new()
		layer_objects.add_child(o2)
		o2.setup("anchor", Vector2(a[0], a[1]), {})
		anchors.append(o2)
	for x in level.checkpoints:
		var o3 := WOBJ.new()
		layer_objects.add_child(o3)
		o3.setup("checkpoint", Vector2(x, terrain.ground_top(x)), {})
	for n in level.get("nests", []):
		var o4 := WOBJ.new()
		layer_objects.add_child(o4)
		o4.setup("nest", Vector2(n[0], terrain.ground_top(n[0])), {})
		o4.facing = 1.0
		nests.append(o4)
	for st in level.stages:
		if float(st.gate) < 90000.0:
			var o5 := WOBJ.new()
			layer_objects.add_child(o5)
			o5.setup("goal", Vector2(float(st.gate) + 60.0, terrain.ground_top(float(st.gate))), {})
	for e in level.enemies:
		var d: Dictionary = e[3]
		pending.append({"kind": e[0], "pos": Vector2(e[1], e[2]), "data": d, "at": float(d.get("at", e[1] - 30.0))})
	pending.sort_custom(func(a, b): return a.at < b.at)
	locks = level.locks.duplicate(true)
	tips = level.tutorial.duplicate(true)

	post = POST.new()
	post.name = "Post"
	add_child(post)
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	cam_left = 0.0
	_update_camera(0.0, true)


func _layer(n: String) -> Node2D:
	var l := Node2D.new()
	l.name = n
	world.add_child(l)
	return l


# ---- stages & streaming ----------------------------------------------------------

func _apply_stage_theme(instant: bool) -> void:
	var st := stage()
	if background.has_method("set_theme"):
		background.set_theme(str(st.theme), instant)
	fx.ambient = str(st.theme)
	music_wanted = str(CATALOG.STAGE_BGM.get(int(st.id), CATALOG.TITLE_BGM_PATH))
	_try_music()


func _try_music() -> void:
	if music_wanted.is_empty() or music_wanted == music_playing:
		return
	if not has_node("/root/GameAudio"):
		return
	if GameAudio.set_music_track(music_wanted):
		music_playing = music_wanted


func _on_segment_ready(_id: String) -> void:
	_try_music()
	terrain.queue_redraw()
	decor.queue_redraw()
	if background.has_method("refresh"):
		background.refresh()


## Background loader heat check: >= 1.0 means "busy — don't stream now".
func load_pressure() -> float:
	if get_tree().paused:
		return 0.0
	if game_state != "play" and game_state != "dead_wait":
		return 0.0
	if boss_state in ["intro", "fight", "dying"]:
		return 1.0
	if lock_active or style.fury_active or chain_t > 0.0:
		return 1.0
	var vis := 0
	var vr := view_rect().grow(120.0)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and vr.has_point(e.global_position):
			vis += 1
	var p := vis / 4.0
	p = maxf(p, float(fx.particle_count()) / 260.0)
	p = maxf(p, float(proj.list.size()) / 30.0)
	return p


func _begin_tally() -> void:
	game_state = "tally"
	state_t = 0.0
	player.controls = false
	player.state = "cutscene"
	player.hook_state = "none"
	if style.fury_active:
		_end_fury()
	proj.clear()
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			if view_rect().grow(60.0).has_point(e.global_position):
				e.die(Vector2(0, -1), "explosion")
			else:
				e.remove()
	var secs := mission_time - float(stage_stats.t0)
	var kills: int = stats.kills - int(stage_stats.kills0)
	var rescued: int = stats.captives - int(stage_stats.captives0)
	var time_bonus := maxi(0, 4000 - int(secs) * 20)
	var bonus: int = time_bonus + kills * 100 + rescued * 1000 + style.rank * 1000
	tally = {
		"stage": stage(), "time": secs, "kills": kills, "rescued": rescued,
		"rank": style.letter(), "rank_i": style.rank, "time_bonus": time_bonus, "bonus": bonus,
		"stage_score": score - int(stage_stats.score0),
	}
	score += bonus
	GS.sfx(&"stage_clear")
	GS.sfx(&"vo_stage_clear")
	hud.show_tally(tally)
	fx.pickup_burst(player.center(), GS.C_YELLOW)
	if has_node("/root/Segments") and stage_i + 1 < level.stages.size():
		# the gate is waiting: stream the next stage at full speed
		Segments.require(str(level.stages[stage_i + 1].seg))


func _update_tally(delta: float) -> void:
	if state_t < 4.6 or stage_i + 1 >= level.stages.size():
		return
	var next: Dictionary = level.stages[stage_i + 1]
	var seg := str(next.seg)
	var seg_ok := true
	if has_node("/root/Segments"):
		seg_ok = Segments.is_ready(seg)
		if not seg_ok:
			Segments.require(seg)
			var failed: bool = Segments.failed != ""
			hud.show_loading(str(next.name), Segments.progress(seg), failed)
			if failed:
				_retry_t -= delta
				if _retry_t <= 0.0:
					_retry_t = 3.0
					Segments.require(seg)
	if seg_ok:
		_enter_stage(stage_i + 1)


func _enter_stage(i: int) -> void:
	stage_i = i
	hud.hide_tally()
	hud.hide_loading()
	stage_stats = {"t0": mission_time, "kills0": stats.kills, "captives0": stats.captives, "score0": score}
	_apply_stage_theme(false)
	player.state = "normal"
	player.controls = true
	game_state = "play"
	state_t = 0.0
	hud.stage_intro(stage().name, stage().sub, 2.6)
	GS.sfx(&"banner_slam")
	GS.sfx(&"vo_go")
	if post != null:
		post.flash(Color(1, 0.95, 0.8), 0.35)


# ---- spawning ---------------------------------------------------------------

func spawn_enemy(kind: String, pos: Vector2, data: Dictionary) -> Node:
	var e: Node = ENEMY[kind].new()
	e.add_to_group("enemy")
	layer_enemies.add_child(e)
	e.setup(pos, data)
	enemies.append(e)
	e.removed.connect(func(): enemies.erase(e))
	return e


func _spawn_prop(kind: String, pos: Vector2, content: String) -> Node:
	var p := PROP.new()
	p.setup(pos, {"kind": kind, "content": content})
	layer_props.add_child(p)
	props_list.append(p)
	p.removed.connect(func(): props_list.erase(p))
	return p


func spawn_pickup(kind: String, pos: Vector2, pop: bool) -> Node:
	var p := PICKUP.new()
	p.add_to_group("pickup")
	layer_pickups.add_child(p)
	p.setup(kind, pos, pop)
	return p


func count_enemies(kind: String) -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.kind_name == kind:
			n += 1
	return n


# ---- queries used by entities --------------------------------------------------

func view_rect() -> Rect2:
	return Rect2(cam_left, cam_y - 360.0, GS.VIEW_W, GS.VIEW_H)


func cam_pos() -> Vector2:
	return Vector2(cam_left + 640.0, cam_y)


func player_bounds() -> Rect2:
	return view_rect()


func ground_top(x: float) -> float:
	return terrain.ground_top(x) if terrain != null else GS.GROUND_Y


func targets() -> Array:
	var f := Engine.get_physics_frames()
	if f == _targets_frame:
		return _targets_cache
	_targets_frame = f
	_targets_cache = []
	for e in enemies:
		if is_instance_valid(e) and e.is_targetable():
			_targets_cache.append(e)
	for p in props_list:
		if is_instance_valid(p) and not p.dead and p.carry_state == "":
			_targets_cache.append(p)
	for c in captives_list:
		if is_instance_valid(c) and c.is_captive_tied():
			_targets_cache.append(c)
	return _targets_cache


func grabbables() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.is_targetable() and e.grapple_kind() != "none":
			out.append(e)
	for p in props_list:
		if is_instance_valid(p) and not p.dead and p.carry_state == "":
			out.append(p)
	return out


func pickups() -> Array:
	return get_tree().get_nodes_in_group("pickup")


func captives() -> Array:
	return captives_list.filter(func(c): return is_instance_valid(c))


func nest_near(pos: Vector2, r: float) -> Node:
	var best: Node = null
	var bd := r
	for n in nests:
		if is_instance_valid(n):
			var d: float = n.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = n
	return best


func nearest_target(pos: Vector2, dir: Vector2, max_range: float) -> Node:
	var best: Node = null
	var best_d := max_range
	for e in enemies:
		if not is_instance_valid(e) or not e.is_targetable():
			continue
		var to: Vector2 = e.hurt_rect().get_center() - pos
		var d := to.length()
		if d < best_d and to.normalized().dot(dir) > 0.55:
			best_d = d
			best = e
	return best


## Soft aim-assist for the grapple: snap to an anchor or grabbable within a cone.
func grapple_assist(from: Vector2, dir: Vector2, max_range: float) -> Variant:
	var best: Variant = null
	var best_s := 0.0
	for a in anchors:
		var to: Vector2 = a.global_position - from
		var d := to.length()
		if d < max_range + 10.0 and d > 30.0:
			var dot := to.normalized().dot(dir)
			var s := dot * 1.4 - d / max_range * 0.3
			if dot > 0.55 and s > best_s:
				best_s = s
				best = a.global_position
	for e in grabbables():
		var to2: Vector2 = e.center() - from
		var d2 := to2.length()
		if d2 < max_range and d2 > 20.0:
			var dot2 := to2.normalized().dot(dir)
			var s2 := dot2 - d2 / max_range * 0.3
			if dot2 > 0.9 and s2 > best_s:
				best_s = s2
				best = e.center()
	return best


# ---- combat services -----------------------------------------------------------

## team: 0 = player-owned (hurts enemies/props), 1 = enemy (hurts player),
## -1 = neutral barrel (hurts both, player at 60%), -2 = visual only.
## chain_n > 0 when this blast was set off by another explosion.
func explode(pos: Vector2, radius: float, dmg: float, team: int, scale: float, chain_n: int = 0) -> void:
	fx.explosion(pos, scale)
	if chain_n > 0:
		GS.sfx(&"chain_boom")
		_register_chain(pos, chain_n)
	else:
		GS.sfx(&"explosion")
	if scale >= 1.0:
		GS.sfx_var(&"crash", 2)
	shake(6.0 * scale, 0.25)
	zoom_punch(0.018 * scale)
	if post != null:
		post.flash(Color(1.0, 0.88, 0.65), 0.07 * scale)
	if dmg <= 0.0 or team == -2:
		return
	if team != 1:
		panic_near(pos, radius * 2.4, 1.1)
		for t in targets().duplicate():
			if not is_instance_valid(t) or t in captives_list:
				continue
			var r: Rect2 = t.hurt_rect()
			var closest := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
			var d := closest.distance_to(pos)
			if d <= radius * (1.25 if t.has_method("is_explosive") and t.is_explosive() else 1.0):
				if t.has_method("is_explosive") and t.is_explosive():
					t.ignite(chain_n + 1, 0.1 + randf() * 0.08 + d / radius * 0.08)
					continue
				var falloff := 1.0 - 0.5 * d / radius
				t.take_hit(dmg * falloff, (r.get_center() - pos).normalized(), "explosion")
	if team != 0 and player != null and player.is_hittable():
		var pr: Rect2 = player.hurt_rect()
		var pc := Vector2(clampf(pos.x, pr.position.x, pr.end.x), clampf(pos.y, pr.position.y, pr.end.y))
		if pc.distance_to(pos) <= radius * 0.85:
			var h = player.hostage()
			if h != null and signf(pos.x - player.global_position.x) == player.facing:
				h.hostage_hit(dmg)
			else:
				player.take_damage(dmg * (0.6 if team == -1 else 1.0), (pr.get_center() - pos).normalized())


func _register_chain(pos: Vector2, n: int) -> void:
	var count := n + 1
	chain_t = 1.4
	if count > chain_best_now:
		chain_best_now = count
		stats.best_chain = maxi(stats.best_chain, count)
		fx.callout(pos + Vector2(0, -150), "CHAIN x%d!" % count, GS.C_ORANGE, 34 + mini(count, 6) * 4)
		add_score(250 * n, pos + Vector2(0, -100), "")
		style.add_bonus(10.0)
		if count == 3:
			GS.sfx(&"vo_chain")
			stats.chains += 1
		if count >= 4:
			slowmo(0.45, 0.35)


## Lit grenades / fire make light troops run for it.
func panic_near(pos: Vector2, r: float, t: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < r:
			e.scare(pos.x, t)


## An enemy spotted the player: its squad-mates nearby snap to attention.
func alert_squad(src: Node) -> void:
	for e in enemies:
		if is_instance_valid(e) and e != src and not e.dead and e.global_position.distance_to(src.global_position) < 560.0:
			e.alerted()


func shake(amount: float, time: float) -> void:
	var k := GS.tuning("screen_shake", 1.0)
	if GS.reduced_motion():
		k = 0.0
	trauma = minf(1.0, trauma + amount / 16.0 * k * clampf(time / 0.2, 0.6, 1.6))


func kick(dir: Vector2, amount: float) -> void:
	if GS.reduced_motion():
		return
	kick_off += dir.normalized() * amount * GS.tuning("screen_shake", 1.0)
	kick_off = kick_off.limit_length(14.0)


func zoom_punch(amount: float) -> void:
	if GS.reduced_motion():
		return
	zoom_extra = minf(0.12, maxf(zoom_extra, amount))


func hitstop(time: float) -> void:
	if GS.reduced_motion():
		return
	var t := minf(time, 0.12) * GS.tuning("hitstop_scale", 1.0)
	if t <= 0.0:
		return
	hitstop_left = maxf(hitstop_left, t)


func slowmo(time: float, scale: float) -> void:
	if GS.reduced_motion():
		return
	slowmo_left = maxf(slowmo_left, time)
	slowmo_scale = minf(slowmo_scale if slowmo_left > 0.0 else 1.0, scale)


func flash_screen(a: float) -> void:
	if not GS.reduced_motion():
		flash_a = maxf(flash_a, a)
		if post != null:
			post.flash(Color.WHITE, a * 0.6)


func add_score(value: int, pos: Vector2, label: String) -> void:
	var mult: float = style.mult()
	var v := int(round(value * mult))
	score += v
	var s := "+%d" % v
	if mult > 1.0:
		s += " x%s" % str(mult)
	if not label.is_empty():
		s = label + "  " + s
	fx.popup(pos, s, GS.C_YELLOW, 20 if label.is_empty() else 24)
	hud.score_pulse()


func combo_mult() -> float:
	return style.mult()


func style_bonus(amount: float) -> void:
	style.add_bonus(amount)


func on_enemy_killed(e: Node, how: String) -> void:
	if game_state == "tally":
		return
	stats.kills += 1
	combo += 1
	combo_t = 3.0
	best_combo = maxi(best_combo, combo)
	var method := how
	if player.state == "nest" and how == "bullet":
		method = "mg"
	var airborne: bool = not player.is_on_floor() and player.state != "nest"
	style.add_kill(method, airborne)
	var bonus := 1.0
	var label := ""
	match how:
		"thrown":
			bonus = 2.0
			label = "THROWN!"
			stats.thrown += 1
		"melee":
			bonus = 1.5
			label = "KNIFED!"
		"explosion":
			bonus = 1.25
			label = "BOOM!"
		"kick":
			bonus = 1.5
			label = "STRIKE!"
			stats.strikes += 1
		"shield":
			label = "HUMAN SHIELD"
	if airborne and label.is_empty():
		label = "AIR KILL!"
	if e.kind_name != "boss":
		add_score(int(e.score_value * bonus), e.center() + Vector2(0, -60), label)
	if combo >= 5 and combo % 5 == 0:
		fx.callout(e.center() + Vector2(0, -130), "%d HIT COMBO!" % combo, GS.C_CYAN, 30)
	if e.kind_name in ["grunt", "shield"] and randf() < 0.14:
		spawn_pickup(["grenades", "grenades", "medkit", "medal"][randi() % 4], e.center(), true)
	if e.kind_name in ["brute", "mortar"]:
		spawn_pickup("medkit" if randf() < 0.5 else "grenades", e.center(), true)
		hitstop(0.1)
		shake(10.0, 0.35)
		zoom_punch(0.05)
	else:
		hitstop(0.035)
	# last enemy of the last wave of an arena: slow-motion beat
	if lock_active and wave_i == lock.waves.size() - 1:
		var left := 0
		for o in enemies:
			if is_instance_valid(o) and not o.dead and o != e and o.wave_tag == e.wave_tag and e.wave_tag != "":
				left += 1
		if left == 0 and e.wave_tag != "":
			slowmo(0.7, 0.3)
			zoom_punch(0.06)


func on_captive_freed(_c: Node) -> void:
	stats.captives += 1
	add_score(1000, player.global_position + Vector2(0, -150), "RESCUE!")
	style.add_bonus(12.0)


func on_checkpoint(o: Node) -> void:
	checkpoint_x = o.global_position.x
	GS.sfx(&"checkpoint")
	hud.toast("CHECKPOINT")
	fx.pickup_burst(o.global_position + Vector2(0, -120), GS.C_CYAN)


func on_item_collected(kind: String) -> void:
	hud.item_flash(kind)


func on_item_used(item: String) -> void:
	hud.item_used(item)


func on_nest_mounted(_n: Node) -> void:
	_show_tip_once("nest_use", "[J] fire    [W]/[S] aim    watch the HEAT gauge    [L] hop off")


func on_grabbed(t: Node) -> void:
	if t.is_enemy:
		_show_tip_once("hostage", "Holding an enemy blocks bullets!  [L] or [J] to THROW him")
	else:
		_show_tip_once("throw", "Throw it with [L] or [J]    hold [W] to lob it high")


func on_thrown(_t: Node) -> void:
	pass


func on_swing() -> void:
	style.add_bonus(5.0)


func on_player_hurt(amount: float, _dir: Vector2) -> void:
	if post != null:
		post.hurt(clampf(amount / 22.0, 0.6, 1.5))
	style.on_player_hit()
	combo = 0
	hud.hurt()


func on_boss_ready(_b: Node) -> void:
	boss_state = "fight"
	supply_t = 8.0


func on_boss_dying(_b: Node) -> void:
	boss_state = "dying"
	proj.clear()
	slowmo(1.4, 0.25)
	zoom_punch(0.1)
	if post != null:
		post.flash(Color.WHITE, 0.6)
		post.shockwave(boss.center() if is_instance_valid(boss) else cam_pos(), 1.6)
	for e in enemies.duplicate():
		if is_instance_valid(e) and e != boss and not e.dead:
			e.die(Vector2(-1, -1), "explosion")


func on_boss_defeated(_b: Node) -> void:
	boss_state = "dead"
	score += 10000
	fx.callout(cam_pos() + Vector2(0, -160), "BOSS DOWN!  +10000", GS.C_YELLOW, 40)
	game_state = "victory"
	state_t = 0.0
	player.controls = false
	player.state = "cutscene"
	if style.fury_active:
		_end_fury()
	if has_node("/root/GameAudio"):
		GameAudio.set_music_track(CATALOG.VICTORY_BGM_PATH)


# ---- STYLE / FURY -----------------------------------------------------------------

func _on_rank_changed(r: int, up: bool) -> void:
	hud.rank_pop(r, up)
	if up:
		GS.sfx(&"rank_up")
		if r == 4:
			GS.sfx(&"vo_stylish")
			if post != null:
				post.flash(Color(1.0, 0.85, 0.3), 0.18)
	else:
		GS.sfx(&"rank_down")


func _on_fury_ready() -> void:
	hud.fury_ready()
	_show_tip_once("fury_ready", "FURY READY!  Press [F] for golden overdrive")


func _start_fury() -> void:
	if not style.start_fury():
		return
	stats.furies += 1
	player.set_fury(true)
	if post != null:
		post.fury_target = 1.0
		post.shockwave(player.center(), 1.4)
		post.flash(Color(1.0, 0.8, 0.3), 0.4)
	fx.fury_burst(player.center())
	GS.sfx(&"fury_on")
	GS.sfx(&"vo_fury")
	hitstop(0.1)
	zoom_punch(0.09)
	shake(8.0, 0.3)
	panic_near(player.center(), 460.0, 1.3)
	hud.fury_start()


func _end_fury() -> void:
	style.fury_active = false
	style.fury = 0.0
	player.set_fury(false)
	if post != null:
		post.fury_target = 0.0
	GS.sfx(&"fury_off")
	hud.fury_end()


# ---- player death / continue ------------------------------------------------------

func _on_player_died() -> void:
	lives -= 1
	combo = 0
	game_state = "dead_wait"
	state_t = 0.0
	shake(10.0, 0.4)
	slowmo(0.6, 0.3)
	if style.fury_active:
		_end_fury()
	if post != null:
		post.flash(Color(0.9, 0.1, 0.05), 0.3)


func _respawn_player() -> void:
	var view := view_rect()
	var x := clampf(player.last_safe.x, view.position.x + 120.0, view.end.x - 200.0)
	var gy := ground_top(x)
	var tries := 0
	while gy > GS.KILL_Y and tries < 30:
		x += 60.0
		gy = ground_top(x)
		tries += 1
	player.respawn(Vector2(x, view.position.y - 40.0))
	proj.clear()
	fx.ring(Vector2(x, gy - 60.0), 260.0, Color(0.5, 0.95, 1.0, 0.9), 0.5)
	fx.heal_burst(Vector2(x, gy - 60.0))
	if post != null:
		post.flash(Color(0.6, 0.95, 1.0), 0.25)
		post.shockwave(Vector2(x, gy - 60.0), 0.9)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.kind_name in ["grunt", "shield"] and absf(e.global_position.x - x) < 240.0:
			e.stun_t = 1.2
			e.velocity = Vector2(signf(e.global_position.x - x) * 300.0, -300.0)
	game_state = "play"


func continue_mission() -> void:
	stats.continues += 1
	score = int(score * 0.5)
	lives = int(GS.tuning("lives", 3.0))
	hud.hide_results()
	_respawn_player()


func restart_mission() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func quit_to_title() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if has_node("/root/GameAudio"):
		GameAudio.stop_game()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _load_best() -> int:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		return int(cf.get_value("best", "score", 0))
	return 0


func _save_best() -> void:
	if score <= best_score:
		return
	best_score = score
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("best", "score", score)
	cf.save(SAVE_PATH)


func rank() -> String:
	if stats.continues > 0:
		return "C"
	var s: int = score + style.peak_rank * 2000
	if s >= 70000:
		return "S"
	if s >= 50000:
		return "A"
	if s >= 30000:
		return "B"
	return "C"


# ---- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	_update_time_scale(real)
	flash_a = maxf(0.0, flash_a - real * 2.5)
	state_t += delta
	if game_state == "play" or game_state == "dead_wait":
		mission_time += delta
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	chain_t = maxf(0.0, chain_t - delta)
	if chain_t <= 0.0:
		chain_best_now = 0
	_update_style(delta)
	_update_low_hp(real)
	match game_state:
		"play":
			if stage_i + 1 < level.stages.size() and not lock_active:
				if player.global_position.x >= float(stage().gate) - 10.0 and player.state == "normal":
					_begin_tally()
		"tally":
			_update_tally(delta)
		"dead_wait":
			if state_t > 1.6:
				if lives > 0:
					_respawn_player()
				else:
					game_state = "gameover"
					state_t = 0.0
					GS.sfx(&"game_over")
					_save_best()
					hud.show_results(false)
		"victory":
			if state_t > 2.4 and not hud.results_visible():
				GS.sfx(&"stage_clear")
				_save_best()
				hud.show_results(true)
	_spawn_pending()
	_update_locks(delta)
	_update_tips()
	_update_boss_arena(delta)
	_update_camera(delta, false)
	_cull(delta)


func _update_time_scale(real: float) -> void:
	if hitstop_left > 0.0:
		hitstop_left -= real
	if slowmo_left > 0.0:
		slowmo_left -= real
		if slowmo_left <= 0.0:
			slowmo_scale = 1.0
	var ts := 1.0
	if slowmo_left > 0.0:
		ts = slowmo_scale
	if hitstop_left > 0.0:
		ts = 0.06
	if get_tree().paused:
		ts = 1.0
	Engine.time_scale = ts


func _update_style(delta: float) -> void:
	var busy := lock_active or boss_state == "fight"
	if not busy:
		for e in enemies:
			if is_instance_valid(e) and not e.dead and view_rect().has_point(e.global_position):
				busy = true
				break
	in_combat_t = 2.0 if busy else maxf(0.0, in_combat_t - delta)
	if game_state == "play":
		if style.update(delta, in_combat_t > 0.0):
			_end_fury()
		if InputMap.has_action(&"fury") and Input.is_action_just_pressed(&"fury") and player.controls:
			if style.can_fury():
				_start_fury()
			else:
				GS.sfx(&"invalid")


func _update_low_hp(real: float) -> void:
	if post == null:
		return
	var low: bool = player.state != "dead" and player.hp / maxf(player.max_hp, 1.0) < 0.3 and game_state == "play"
	post.low_hp = 1.0 if low else 0.0
	if low:
		heartbeat_t -= real
		if heartbeat_t <= 0.0:
			heartbeat_t = 0.9
			GS.sfx(&"heartbeat")


func _update_camera(delta: float, snap: bool) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	var end_left: float = float(level.end_x) - GS.VIEW_W
	var target_left := player.global_position.x - 520.0
	var max_left := end_left
	if lock_active:
		max_left = minf(max_left, float(lock.cam_left))
	if boss_state != "none":
		max_left = minf(max_left, float(level.boss.cam_left))
	if stage_i + 1 < level.stages.size():
		max_left = minf(max_left, float(stage().gate) + 170.0 - GS.VIEW_W)
	target_left = minf(target_left, max_left)
	if snap:
		cam_left = maxf(cam_left, target_left)
	elif target_left > cam_left:
		var smooth := GS.tuning("camera_smoothing", 8.0)
		cam_left = minf(target_left, lerpf(cam_left, target_left, 1.0 - exp(-smooth * delta)) + 1.0)
	var ty := clampf(player.global_position.y - 240.0, 220.0, 360.0)
	if player.state == "dead":
		ty = cam_y
	cam_y = ty if snap else lerpf(cam_y, ty, 1.0 - exp(-4.0 * delta))
	# trauma shake (smooth noise, squared falloff), recoil kick, zoom punch
	_noise_t += real * 60.0
	var tr2 := trauma * trauma
	var off := Vector2(_noise.get_noise_2d(_noise_t, 0.0), _noise.get_noise_2d(0.0, _noise_t)) * 26.0 * tr2
	camera.rotation = _noise.get_noise_2d(_noise_t, 91.0) * 0.03 * tr2
	trauma = maxf(0.0, trauma - real * 1.5)
	kick_off = kick_off.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * real))
	zoom_extra = move_toward(zoom_extra, 0.0, real * 0.3)
	var fury_zoom: float = 0.025 if style.fury_active else 0.0
	camera.zoom = Vector2.ONE * (1.0 + zoom_extra + fury_zoom)
	camera.position = cam_pos() + off + kick_off


func snap_camera() -> void:
	_update_camera(0.0, true)


func _spawn_pending() -> void:
	var edge := cam_left + GS.VIEW_W + 80.0
	while not pending.is_empty() and float(pending[0].at) <= edge:
		var s: Dictionary = pending.pop_front()
		spawn_enemy(s.kind, s.pos, s.data)


func _update_locks(delta: float) -> void:
	if go_t > 0.0:
		go_t -= delta
	if not lock_active:
		if not locks.is_empty() and cam_left >= float(locks[0].cam_left) - 0.5:
			lock = locks.pop_front()
			lock_active = true
			wave_i = 0
			wave_delay = 0.6
			hud.banner("AMBUSH!", str(lock.name), 1.8, "alert")
			GS.sfx(&"alarm")
			GS.sfx(&"banner_slam")
		return
	var tag := "lock_%d_%d" % [int(lock.cam_left), wave_i]
	if wave_delay > 0.0:
		wave_delay -= delta
		if wave_delay <= 0.0 and wave_i < lock.waves.size():
			for w in lock.waves[wave_i]:
				var d: Dictionary = (w[3] as Dictionary).duplicate()
				d["wave"] = tag
				spawn_enemy(w[0], Vector2(w[1], w[2]), d)
			hud.wave_pop(wave_i + 1, lock.waves.size())
		return
	var alive := 0
	var vr := view_rect()
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.wave_tag == tag:
			# failsafe: a lock enemy stuck off-screen for 8s is removed so arenas never soft-lock
			var off: bool = e.carry_state == "" and e.state != "enter" and (e.global_position.x < vr.position.x - 30.0 or e.global_position.x > vr.end.x + 30.0 or e.global_position.y > GS.KILL_Y)
			var t_off: float = (float(e.get_meta("off_t", 0.0)) + delta) if off else 0.0
			e.set_meta("off_t", t_off)
			if t_off > 8.0:
				e.remove()
				continue
			alive += 1
	if alive == 0:
		wave_i += 1
		if wave_i >= lock.waves.size():
			lock_active = false
			go_t = 3.0
			hud.go_arrow()
			hud.toast("AREA CLEAR!")
			GS.sfx(&"stage_clear")
			GS.sfx(&"vo_go")
			add_score(2000, player.global_position + Vector2(0, -150), "CLEAR")
		else:
			wave_delay = 1.0


func _update_tips() -> void:
	while not tips.is_empty() and player.global_position.x >= float(tips[0][0]):
		var t: Array = tips.pop_front()
		_show_tip_once(t[2], t[1])


func _show_tip_once(id: String, text: String) -> void:
	if tips_shown.has(id):
		return
	tips_shown[id] = true
	hud.tip(text)


func _update_boss_arena(delta: float) -> void:
	if boss_state == "none":
		if cam_left >= float(level.boss.cam_left) - 0.5 and not lock_active:
			boss_state = "intro"
			hud.banner("WARNING!", "Rhino Crawler approaching", 2.6, "alert")
			GS.sfx(&"alarm")
			GS.sfx(&"vo_warning")
			if has_node("/root/GameAudio"):
				if GameAudio.set_music_track(CATALOG.BOSS_BGM_PATH):
					music_playing = CATALOG.BOSS_BGM_PATH
			music_wanted = CATALOG.BOSS_BGM_PATH
			var b: Dictionary = level.boss
			boss = spawn_enemy("boss", b.home, {"arena_left": b.arena_left, "arena_right": b.arena_right})
		return
	if boss_state == "fight":
		supply_t -= delta
		if supply_t <= 0.0:
			supply_t = 16.0
			var x := randf_range(float(level.boss.arena_left) + 120.0, float(level.boss.arena_left) + 700.0)
			var kind: String = ["barrel", "crate", "ammo_crate", "fuel_tank"][randi() % 4]
			var content: String = ["grenades", "medkit", "hmg", "rocket", "spread"][randi() % 5] if kind in ["crate", "ammo_crate"] else ""
			_spawn_prop(kind, Vector2(x, view_rect().position.y - 60.0), content)
			hud.toast("SUPPLY DROP!")


func _cull(delta: float) -> void:
	_cull_t -= delta
	if _cull_t > 0.0:
		return
	_cull_t = 0.4
	var near := view_rect().grow(500.0)
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		if e.global_position.x < cam_left - 380.0 and e != boss and e.carry_state == "":
			e.remove()
			continue
		e.set_physics_process(near.has_point(e.global_position) or e.carry_state != "")
	for p in props_list:
		if is_instance_valid(p):
			p.set_physics_process(near.has_point(p.global_position) or p.carry_state != "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and game_state in ["play", "dead_wait"]:
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
