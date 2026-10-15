extends Node2D
## Layered, batched visual effects.
##   _decals : ground scorch marks / fire patches (under actors)
##   _n      : alpha-blended layer (smoke, debris, casings, dust, text)
##   _a      : additive glow layer (flashes, sparks, embers, rings, fireballs)
## Everything is plain arrays drawn by three CanvasItems; caps + density
## keep the Web build at 60 fps. Screen-space parts (shockwave distortion,
## vignette, flash) are forwarded to the game's post-process layer.

const FONT := preload("res://assets/template/game/fonts/ChakraPetch-Bold.ttf")
const FONT_D := preload("res://assets/template/game/fonts/BlackOpsOne-Regular.ttf")
const KP := "res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/"
const KS := "res://assets/template/game/catalog/kenney_smoke/PNG/"
const T_GLOW := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/light_02.png")
const T_CIRCLE := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/circle_05.png")
const T_FLARE := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/flare_01.png")
const T_SPARK := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/spark_05.png")
const T_SPARK2 := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/spark_06.png")
const T_STAR := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/star_06.png")
const T_FIRE := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/fire_01.png")
const T_SMOKE_K := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/smoke_04.png")
const T_DIRT := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/dirt_02.png")
const T_SLASH := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/slash_03.png")
const T_TRACE := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/trace_04.png")
const T_TWIRL := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/twirl_02.png")
const T_MAGIC := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/magic_03.png")
const T_MUZZLE_K := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/muzzle_02.png")
const T_SCORCH_K := preload("res://assets/template/game/catalog/kenney_particles/PNG (Transparent)/scorch_01.png")
const T_PUFF := [
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff00.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff03.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff06.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff09.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff12.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/White puff/whitePuff15.png"),
]
const T_BLACK := [
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/Black smoke/blackSmoke00.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/Black smoke/blackSmoke04.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/Black smoke/blackSmoke08.png"),
	preload("res://assets/template/game/catalog/kenney_smoke/PNG/Black smoke/blackSmoke12.png"),
]
const EX_FRAMES := ["ex0", "ex1", "ex2", "ex3", "ex4", "ex5", "ex6", "ex7"]
const MAX_N := 520
const MAX_A := 620
const MAX_DECALS := 36

# particle layout (both layers):
# [0 kind, 1 pos, 2 vel, 3 life, 4 max_life, 5 size, 6 color, 7 rot, 8 spin,
#  9 gravity, 10 tex, 11 grow, 12 drag, 13 extra]
enum K { LINE, DOT, TEX, RECT, SPRITE, CASING, FLIP }

var _n: Node2D
var _a: Node2D
var _decals: Node2D
var parts_n: Array = []
var parts_a: Array = []
var decals: Array = []      # [pos, tex(or sheet/frame), scale, rot, life, max, color, kind]
var fires: Array = []       # [pos, life, scale, emit_t]
var texts: Array = []       # [pos, text, t, color, size, big]
var density := 1.0
var ambient := ""           # town / canyon / fortress
var _amb_t := 0.0


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_decals = Node2D.new()
	_decals.name = "Decals"
	_decals.z_as_relative = false
	_decals.z_index = -1
	_decals.draw.connect(_draw_decals)
	add_child(_decals)
	_n = Node2D.new()
	_n.name = "Normal"
	_n.draw.connect(_draw_normal)
	add_child(_n)
	_a = Node2D.new()
	_a.name = "Additive"
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_a.material = m
	_a.draw.connect(_draw_add)
	add_child(_a)


func particle_count() -> int:
	return parts_n.size() + parts_a.size()


# ---- low level ----------------------------------------------------------------

func _pn(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity: float = 0.0, spin: float = 0.0, tex: Variant = null, grow: float = 0.0, drag: float = 0.0, extra: Variant = null) -> void:
	if parts_n.size() >= MAX_N:
		parts_n.remove_at(0)
	parts_n.append([kind, pos, vel, life, life, size, color, randf() * TAU, spin, gravity, tex, grow, drag, extra])


func _pa(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity: float = 0.0, spin: float = 0.0, tex: Variant = null, grow: float = 0.0, drag: float = 0.0, extra: Variant = null) -> void:
	if parts_a.size() >= MAX_A:
		parts_a.remove_at(0)
	parts_a.append([kind, pos, vel, life, life, size, color, randf() * TAU, spin, gravity, tex, grow, drag, extra])


func _count(n: int) -> int:
	# density scales with tuning and backs off when the screen is very busy
	var busy := 1.0 if particle_count() < 700 else 0.55
	return maxi(1, int(round(n * density * busy)))


func _post() -> Node:
	return GS.game.post if GS.game != null and "post" in GS.game else null


# ---- public API (kept from v1) ----------------------------------------------------

func sparks(pos: Vector2, dir: Vector2, count: int = 6, color: Color = GS.C_YELLOW, speed: float = 420.0) -> void:
	for i in _count(count):
		var a := dir.angle() + randf_range(-0.9, 0.9)
		_pa(K.LINE, pos, Vector2.from_angle(a) * speed * randf_range(0.4, 1.15), randf_range(0.14, 0.34), randf_range(2.0, 3.6), color, 900.0, 0.0, null, 0.0, 1.5)


func debris(pos: Vector2, count: int, color: Color, speed: float = 380.0, size: float = 7.0) -> void:
	for i in _count(count):
		var v := Vector2(randf_range(-1, 1), randf_range(-1.4, -0.3)).normalized() * speed * randf_range(0.4, 1.2)
		_pn(K.RECT, pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), v, randf_range(0.7, 1.4), size * randf_range(0.6, 1.3), color.darkened(randf_range(0, 0.35)), 1400.0, randf_range(-12, 12), null, 0.0, 0.0, true)


func chunks(pos: Vector2, count: int, color: Color) -> void:
	for i in _count(count):
		var v := Vector2(randf_range(-1, 1), randf_range(-1.5, -0.4)).normalized() * randf_range(220, 560)
		if randf() < 0.5:
			_pn(K.SPRITE, pos, v, randf_range(0.9, 1.6), randf_range(0.12, 0.22), Color.WHITE.lerp(color, 0.4), 1500.0, randf_range(-14, 14), ["vfx_c", "rocks"], 0.0, 0.0, true)
		else:
			_pn(K.RECT, pos, v, randf_range(0.9, 1.6), randf_range(6, 12), color.darkened(randf_range(0, 0.4)), 1500.0, randf_range(-14, 14), null, 0.0, 0.0, true)


func smoke(pos: Vector2, count: int = 3, size: float = 18.0, color: Color = Color(0.3, 0.27, 0.26, 0.55)) -> void:
	for i in _count(count):
		_pn(K.TEX, pos + Vector2(randf_range(-10, 10), randf_range(-8, 8)), Vector2(randf_range(-30, 30), randf_range(-80, -25)), randf_range(0.7, 1.3), size * randf_range(1.6, 2.4), color, -25.0, randf_range(-1.2, 1.2), T_PUFF[randi() % T_PUFF.size()], 1.2, 1.8)


func dust(pos: Vector2, count: int = 5, spread: float = 1.0) -> void:
	var col := Color(0.88, 0.72, 0.52, 0.5)
	if ambient == "canyon":
		col = Color(0.85, 0.5, 0.32, 0.5)
	elif ambient == "fortress":
		col = Color(0.62, 0.6, 0.6, 0.5)
	for i in _count(count):
		var side := -1.0 if i % 2 == 0 else 1.0
		_pn(K.TEX, pos + Vector2(randf_range(-8, 8), -4), Vector2(side * randf_range(50, 170) * spread, randf_range(-60, -12)), randf_range(0.35, 0.65), randf_range(20, 30), col, 0.0, randf_range(-2, 2), T_PUFF[randi() % T_PUFF.size()], 1.4, 3.0)


func embers(pos: Vector2, count: int = 8) -> void:
	for i in _count(count):
		_pa(K.DOT, pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Vector2(randf_range(-170, 170), randf_range(-360, -70)), randf_range(0.6, 1.3), randf_range(2.0, 4.0), Color(1.0, randf_range(0.45, 0.8), 0.15), 320.0, 0.0, null, 0.0, 0.6)


func casing(pos: Vector2, facing: float) -> void:
	_pn(K.CASING, pos, Vector2(-facing * randf_range(60, 160), randf_range(-340, -210)), 3.5, 1.0, Color("#f0c060"), 1500.0, randf_range(-24, 24), null, 0.0, 0.0, true)


## Weapon-specific sprite muzzle flash (+ glow and smoke wisp).
func muzzle(pos: Vector2, angle: float, size: float = 1.0, color: Color = Color(1.0, 0.85, 0.35), style: String = "") -> void:
	var frame := "flash_pistol"
	if style == "hmg" or style == "mg":
		frame = "flash_hmg"
	elif style == "spread":
		frame = "flash_spread"
	elif style == "enemy":
		frame = "flash_pistol"
	var s := size * randf_range(0.85, 1.1)
	_pa(K.SPRITE, pos + Vector2.from_angle(angle) * 18.0 * s, Vector2.ZERO, 0.055, 0.75 * s, Color(color, 1.0).lerp(Color.WHITE, 0.3), 0.0, 0.0, ["vfx_a", frame], 0.0, 0.0, angle)
	_pa(K.TEX, pos, Vector2.ZERO, 0.08, 70.0 * s, Color(color.r, color.g * 0.8, color.b * 0.5, 0.55), 0.0, 0.0, T_GLOW, -2.0)
	if randf() < 0.5:
		_pn(K.TEX, pos, Vector2.from_angle(angle) * 40.0 + Vector2(0, -30), 0.4, 14.0 * s, Color(0.8, 0.78, 0.75, 0.22), -40.0, randf_range(-2, 2), T_PUFF[randi() % T_PUFF.size()], 1.6, 2.0)


func ring(pos: Vector2, radius: float, color: Color = Color(1, 0.9, 0.6, 0.8), time: float = 0.3) -> void:
	_pa(K.SPRITE, pos, Vector2.ZERO, time, radius / 45.0, color, 0.0, 0.0, ["vfx_b", "ring"], 2.6, 0.0, 0.0)


## Full layered explosion. scale ~1 for grenades, 1.3 barrels, 1.8 fuel tanks.
func explosion(pos: Vector2, scale: float = 1.0) -> void:
	var s := scale
	# 1) white-hot flash + glow; overlapping chain blasts get progressively
	# dimmer flashes so additive stacking never blows out to flat white.
	var now := Time.get_ticks_msec() / 1000.0
	_boom_heat = maxf(0.0, _boom_heat - (now - _boom_last) * 2.5) + 1.0
	_boom_last = now
	var fa := 1.0 / (1.0 + (_boom_heat - 1.0) * 0.8)
	_pa(K.TEX, pos, Vector2.ZERO, 0.16, 250.0 * s, Color(1, 0.95, 0.8, 0.8 * fa), 0.0, 0.0, T_GLOW, 1.5)
	_pa(K.TEX, pos, Vector2.ZERO, 0.1, 150.0 * s, Color(1, 1, 1, 0.75 * fa), 0.0, 0.0, T_CIRCLE, 2.0)
	# 2) fireball flipbook + additive fireball sprite
	_pn(K.FLIP, pos, Vector2.ZERO, 0.55, 1.25 * s, Color.WHITE, 0.0, 0.0, null, 0.0, 0.0, randf() * TAU)
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.28, 1.25 * s, Color(1, 0.8, 0.5, 0.9), 0.0, randf_range(-2, 2), ["vfx_b", "fireball"], 1.6)
	for i in _count(int(4 * s)):
		var a := randf() * TAU
		_pa(K.TEX, pos + Vector2.from_angle(a) * 20.0 * s, Vector2.from_angle(a) * randf_range(90, 220) * s, randf_range(0.25, 0.45), randf_range(50, 80) * s, Color(1, randf_range(0.45, 0.7), 0.15, 0.85), -60.0, randf_range(-3, 3), T_FIRE, 0.8, 3.0)
	# 3) shock ring (+ screen distortion)
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.36, 0.6 * s, Color(1, 0.9, 0.7, 0.9), 0.0, 0.0, ["vfx_b", "ring"], 5.5 * minf(s, 1.8))
	var post := _post()
	if post != null:
		post.shockwave(pos, 0.5 + 0.35 * s)
	# 4) rolling smoke
	for i in _count(int(5 * s)):
		var dark := randf() < 0.55
		var tex: Texture2D = T_BLACK[randi() % T_BLACK.size()] if dark else T_PUFF[randi() % T_PUFF.size()]
		var col := Color(1, 1, 1, 0.75) if dark else Color(0.42, 0.37, 0.34, 0.7)
		var v := Vector2(randf_range(-110, 110), randf_range(-170, -60)) * s
		_pn(K.TEX, pos + Vector2(randf_range(-26, 26), randf_range(-20, 10)) * s, v, randf_range(1.1, 2.0), randf_range(40, 62) * s, col, -30.0, randf_range(-1.5, 1.5), tex, 1.1, 1.6, 0.18)
	# 5) debris, sparks, embers
	debris(pos, int(9 * s), Color("#4a3a30"), 520.0 * s, 6.0)
	chunks(pos, int(4 * s), Color("#6a5040"))
	sparks(pos, Vector2.UP, int(14 * s), GS.C_YELLOW, 700.0 * s)
	embers(pos, int(10 * s))
	# 6) ground scorch + sideways ground dust
	var gy := _ground_y(pos.x)
	if absf(pos.y - gy) < 110.0:
		scorch(Vector2(pos.x, gy), 0.8 + s * 0.4)
		for i in _count(int(4 * s)):
			var side := -1.0 if i % 2 == 0 else 1.0
			_pn(K.TEX, Vector2(pos.x, gy - 6), Vector2(side * randf_range(200, 380) * s, randf_range(-40, -5)), randf_range(0.5, 0.8), randf_range(28, 40) * s, Color(0.75, 0.62, 0.48, 0.55), 0.0, 0.0, T_PUFF[randi() % T_PUFF.size()], 1.4, 3.2)


func popup(pos: Vector2, text: String, color: Color = GS.C_YELLOW, size: int = 22) -> void:
	# Stack instead of overlapping: nudge up past any young popup nearby.
	var p := pos + Vector2(randf_range(-6, 6), 0)
	for pass_i in 5:
		var hit := false
		for tx in texts:
			if float(tx[2]) < 0.45 and absf(tx[0].x - p.x) < 90.0 and absf(tx[0].y - p.y) < float(size) + 2.0:
				hit = true
				break
		if not hit:
			break
		p.y -= float(size) + 6.0
	texts.append([p, text, 0.0, color, size, size >= 28])


var _boom_heat := 0.0
var _boom_last := 0.0


## Huge centred call-out (CHAIN x3!, BOWLED!, FURY!).
func callout(pos: Vector2, text: String, color: Color, size: int = 40) -> void:
	texts.append([pos, text, 0.0, color, size, true])


func clear() -> void:
	parts_n.clear()
	parts_a.clear()
	texts.clear()
	fires.clear()


# ---- new effects ------------------------------------------------------------------

func impact_spark(pos: Vector2, normal: Vector2, color: Color = Color(1, 0.85, 0.4)) -> void:
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.09, randf_range(0.35, 0.5), color, 0.0, 0.0, ["vfx_a", "spark_burst"], 1.5, 0.0, randf() * TAU)
	_pa(K.TEX, pos, Vector2.ZERO, 0.08, 46.0, Color(color, 0.7), 0.0, 0.0, T_GLOW, 1.0)
	sparks(pos, normal, 4, color, 380.0)


func hit_flash(pos: Vector2, color: Color = Color(1, 1, 1)) -> void:
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.1, randf_range(0.45, 0.6), color, 0.0, 0.0, ["vfx_a", "hit_x"], 1.2, 0.0, randf_range(-0.4, 0.4))


func ground_puff(pos: Vector2) -> void:
	_pn(K.SPRITE, pos, Vector2(0, -20), 0.4, 0.35, Color(1, 1, 1, 0.8), 0.0, 0.0, ["vfx_c", "dust"], 1.2)


func death_burst(pos: Vector2, how: String, facing: float) -> void:
	hit_flash(pos, Color(1, 0.95, 0.8))
	_pa(K.TEX, pos, Vector2.ZERO, 0.18, 120.0, Color(1, 0.85, 0.6, 0.7), 0.0, 0.0, T_GLOW, 1.6)
	sparks(pos, Vector2(-facing, -0.6), 8, GS.C_YELLOW, 460.0)
	if how in ["melee"]:
		_pa(K.TEX, pos, Vector2.ZERO, 0.16, 110.0, Color(1, 0.95, 0.9, 0.9), 0.0, randf_range(-1, 1), T_SLASH, 0.8)
	if how == "fury":
		_pa(K.TEX, pos, Vector2.ZERO, 0.3, 140.0, Color(1, 0.75, 0.2, 0.9), 0.0, 3.0, T_STAR, 1.5)
	for i in _count(3):
		_pa(K.SPRITE, pos + Vector2(randf_range(-10, 10), randf_range(-20, 10)), Vector2(randf_range(-80, 80), randf_range(-160, -60)), randf_range(0.4, 0.7), randf_range(0.14, 0.22), Color(1, 0.9, 0.5), 200.0, randf_range(-6, 6), ["vfx_a", "sparkle"], 0.0, 0.5)


func splinters(pos: Vector2, s: float = 1.0) -> void:
	for i in _count(int(5 * s)):
		var v := Vector2(randf_range(-1, 1), randf_range(-1.5, -0.4)).normalized() * randf_range(240, 520)
		_pn(K.SPRITE, pos, v, randf_range(0.8, 1.3), randf_range(0.14, 0.22), Color.WHITE, 1500.0, randf_range(-16, 16), ["vfx_c", "splinters"], 0.0, 0.0, true)


func shards(pos: Vector2, s: float = 1.0) -> void:
	for i in _count(int(5 * s)):
		var v := Vector2(randf_range(-1, 1), randf_range(-1.5, -0.4)).normalized() * randf_range(260, 560)
		_pn(K.SPRITE, pos, v, randf_range(0.8, 1.3), randf_range(0.14, 0.22), Color.WHITE, 1500.0, randf_range(-16, 16), ["vfx_c", "shards"], 0.0, 0.0, true)


func scorch(pos: Vector2, s: float = 1.0) -> void:
	if decals.size() >= MAX_DECALS:
		decals.remove_at(0)
	decals.append([pos + Vector2(0, 2), ["vfx_c", "scorch"], s * randf_range(0.9, 1.15), 0.0, 14.0, 14.0, Color(1, 1, 1, 0.9), randf() < 0.5])
	_decals.queue_redraw()


func fire_patch(pos: Vector2, time: float) -> void:
	fires.append([pos, time, 1.0, 0.0])


func flame_lick(pos: Vector2) -> void:
	_pa(K.TEX, pos, Vector2(randf_range(-10, 10), -90), 0.35, randf_range(26, 36), Color(1, 0.55, 0.15, 0.8), -80.0, randf_range(-2, 2), T_FIRE, 0.5, 1.0)
	if randf() < 0.4:
		_pn(K.TEX, pos + Vector2(0, -20), Vector2(randf_range(-10, 10), -60), 1.0, 20.0, Color(0.2, 0.18, 0.18, 0.4), -20.0, 1.0, T_BLACK[randi() % T_BLACK.size()], 1.4, 1.0)


func mushroom(pos: Vector2) -> void:
	for i in _count(6):
		var t: Texture2D = T_BLACK[randi() % T_BLACK.size()]
		_pn(K.TEX, pos + Vector2(randf_range(-20, 20), -i * 16.0), Vector2(randf_range(-30, 30), -140.0 - i * 26.0), randf_range(1.6, 2.4), randf_range(50, 70), Color(1, 1, 1, 0.7), -10.0, randf_range(-1, 1), t, 0.9, 1.0)


func latch(pos: Vector2) -> void:
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.16, 0.55, Color(0.6, 0.95, 1.0), 0.0, 0.0, ["vfx_a", "latch"], 1.8, 0.0, randf() * TAU)
	_pa(K.TEX, pos, Vector2.ZERO, 0.18, 100.0, Color(0.3, 0.85, 1.0, 0.8), 0.0, 0.0, T_GLOW, 1.2)
	sparks(pos, Vector2.UP, 8, GS.C_CYAN, 420.0)


func speed_line(pos: Vector2, dir: Vector2, color: Color = Color(0.7, 0.95, 1.0, 0.6)) -> void:
	_pa(K.LINE, pos + Vector2(randf_range(-30, 30), randf_range(-40, 40)), -dir * randf_range(500, 800), 0.14, 2.0, color, 0.0, 0.0, null, 0.0, 0.0)


func trail(pos: Vector2, color: Color = Color(1, 0.9, 0.6, 0.35), size: float = 26.0) -> void:
	_pa(K.TEX, pos, Vector2.ZERO, 0.22, size, color, 0.0, 0.0, T_CIRCLE, -1.5)


func heal_burst(pos: Vector2) -> void:
	for i in _count(8):
		_pa(K.SPRITE, pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)), Vector2(randf_range(-40, 40), randf_range(-160, -80)), randf_range(0.6, 1.0), randf_range(0.2, 0.32), Color(0.5, 1.0, 0.6), -60.0, 0.0, ["vfx_b", "heal"], 0.0, 1.0)
	ring(pos, 70.0, Color(0.4, 1.0, 0.5, 0.8), 0.35)


func pickup_burst(pos: Vector2, color: Color) -> void:
	_pa(K.TEX, pos, Vector2.ZERO, 0.25, 120.0, Color(color, 0.8), 0.0, 3.0, T_STAR, 1.2)
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.3, 0.45, color, 0.0, 0.0, ["vfx_b", "burst"], 2.0)
	for i in _count(7):
		var a := i * TAU / 7.0
		_pa(K.SPRITE, pos, Vector2.from_angle(a) * 220.0, 0.45, 0.18, color, 0.0, 4.0, ["vfx_a", "sparkle"], -1.0, 3.0)


func fury_burst(pos: Vector2) -> void:
	_pa(K.TEX, pos, Vector2.ZERO, 0.5, 420.0, Color(1, 0.75, 0.2, 0.9), 0.0, 1.5, T_STAR, 1.0)
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.45, 1.0, Color(1, 0.8, 0.3), 0.0, 0.0, ["vfx_b", "ring"], 7.0)
	_pa(K.SPRITE, pos, Vector2.ZERO, 0.4, 1.2, Color(1, 0.85, 0.4), 0.0, 2.0, ["vfx_b", "burst"], 2.0)
	for i in _count(24):
		var a := randf() * TAU
		_pa(K.DOT, pos, Vector2.from_angle(a) * randf_range(200, 600), randf_range(0.5, 0.9), randf_range(2.5, 4.5), Color(1, 0.8, 0.2), 200.0, 0.0, null, 0.0, 2.0)
	var post := _post()
	if post != null:
		post.shockwave(pos, 1.0)


## Golden afterimage / aura ember for FURY.
func fury_ember(pos: Vector2) -> void:
	_pa(K.DOT, pos + Vector2(randf_range(-30, 30), randf_range(-60, 10)), Vector2(randf_range(-40, 40), randf_range(-160, -60)), randf_range(0.4, 0.8), randf_range(2.0, 3.5), Color(1, 0.75, 0.2), -40.0, 0.0, null, 0.0, 0.5)


func laser_charge(pos: Vector2, k: float) -> void:
	_pa(K.TEX, pos + Vector2.from_angle(randf() * TAU) * 90.0 * (1.0 - k), Vector2.ZERO, 0.12, 10.0 + 20.0 * k, Color(1, 0.3, 0.2, 0.9), 0.0, 0.0, T_CIRCLE, 0.0)


func _ground_y(x: float) -> float:
	if GS.game != null and GS.game.has_method("ground_top"):
		return GS.game.ground_top(x)
	return GS.GROUND_Y


# ---- update ------------------------------------------------------------------------

func _process(delta: float) -> void:
	density = clampf(GS.tuning("particles_density", 1.0), 0.2, 1.0)
	_step(parts_n, delta)
	_step(parts_a, delta)
	# lingering fires
	var i := fires.size() - 1
	while i >= 0:
		var f: Array = fires[i]
		f[1] -= delta
		f[3] -= delta
		if f[1] <= 0.0:
			fires.remove_at(i)
		elif f[3] <= 0.0:
			f[3] = 0.09
			var spread := 34.0 * float(f[2])
			flame_lick(f[0] + Vector2(randf_range(-spread, spread), -4))
			if randf() < 0.3:
				embers(f[0] + Vector2(0, -20), 1)
		i -= 1
	# decals fade
	var changed := false
	var j := decals.size() - 1
	while j >= 0:
		decals[j][4] -= delta
		if decals[j][4] <= 0.0:
			decals.remove_at(j)
			changed = true
		elif decals[j][4] < 2.0:
			changed = true
		j -= 1
	if changed:
		_decals.queue_redraw()
	for t in texts:
		t[2] += delta
		t[0].y -= (26.0 if t[5] else 52.0) * delta
	texts = texts.filter(func(t): return t[2] < (1.4 if t[5] else 1.0))
	_ambient(delta)
	_n.queue_redraw()
	_a.queue_redraw()


func _step(list: Array, delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p: Array = list[i]
		p[3] -= delta
		if p[3] <= 0.0:
			list.remove_at(i)
			i -= 1
			continue
		var vel: Vector2 = p[2]
		vel.y += p[9] * delta
		if p[12] > 0.0:
			vel *= maxf(0.0, 1.0 - p[12] * delta)
		var pos: Vector2 = p[1] + vel * delta
		if p[13] is bool and p[13] and vel.y > 0.0:
			var gy := _ground_y(pos.x)
			if pos.y > gy - 2.0 and pos.y < gy + 40.0:
				pos.y = gy - 2.0
				vel = Vector2(vel.x * 0.45, -vel.y * 0.28)
				if absf(vel.y) < 40.0:
					vel = Vector2(vel.x * 0.6, 0.0)
					p[8] *= 0.5
		p[1] = pos
		p[2] = vel
		p[7] += p[8] * delta
		i -= 1


func _ambient(delta: float) -> void:
	if GS.game == null or ambient == "" or GS.reduced_motion():
		return
	_amb_t -= delta
	if _amb_t > 0.0:
		return
	var vr: Rect2 = GS.game.view_rect()
	match ambient:
		"town":
			_amb_t = 0.18
			_pa(K.DOT, Vector2(randf_range(vr.position.x, vr.end.x), randf_range(vr.position.y + 120, vr.end.y - 60)), Vector2(randf_range(10, 40), randf_range(-12, 6)), 3.0, randf_range(1.2, 2.2), Color(1, 0.85, 0.55, 0.35), 0.0, 0.0, null, 0.0, 0.0)
		"canyon":
			_amb_t = 0.05
			_pn(K.LINE, Vector2(vr.end.x + 20, randf_range(vr.position.y + 80, vr.end.y - 40)), Vector2(-randf_range(500, 800), randf_range(20, 60)), 2.2, 1.4, Color(0.9, 0.55, 0.35, 0.28), 0.0, 0.0, null, 0.0, 0.0)
		"fortress":
			_amb_t = 0.12
			_pa(K.DOT, Vector2(randf_range(vr.position.x, vr.end.x), vr.end.y + 10), Vector2(randf_range(-30, 30), randf_range(-140, -60)), 3.2, randf_range(1.5, 3.0), Color(1, randf_range(0.4, 0.65), 0.15, 0.8), -10.0, 0.0, null, 0.0, 0.0)


# ---- drawing -------------------------------------------------------------------------

func _draw_list(ci: CanvasItem, list: Array) -> void:
	for p in list:
		var k: float = p[3] / p[4]          # 1 -> 0
		var age: float = 1.0 - k
		var col: Color = p[6]
		match p[0]:
			K.LINE:
				var v: Vector2 = p[2]
				ci.draw_line(p[1], p[1] - v * 0.035, Color(col, col.a * k), p[5])
			K.DOT:
				ci.draw_circle(p[1], p[5] * (0.4 + k * 0.6), Color(col, col.a * minf(1.0, k * 2.0)))
			K.TEX:
				var tex: Texture2D = p[10]
				var sz: float = p[5] * maxf(0.05, 1.0 + p[11] * age)
				var a: float = col.a * (k if p[13] == null else minf(1.0, age / float(p[13])) * k)
				ci.draw_set_transform(p[1], p[7], Vector2.ONE)
				ci.draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(col, a))
			K.SPRITE:
				var sf: Array = p[10]
				var sc: float = p[5] * maxf(0.05, 1.0 + p[11] * age)
				var rot: float = p[13] if p[13] is float else p[7]
				var a2: float = col.a * (k if p[4] < 0.5 else minf(1.0, k * 2.5))
				SpriteLib.draw(ci, sf[0], sf[1], p[1], false, sc, Color(col, a2), rot)
			K.RECT:
				var s2: float = p[5]
				ci.draw_set_transform(p[1], p[7], Vector2.ONE)
				ci.draw_rect(Rect2(-s2 * 0.5, -s2 * 0.35, s2, s2 * 0.7), Color(col, minf(1.0, k * 3.0)))
				ci.draw_rect(Rect2(-s2 * 0.5, -s2 * 0.35, s2, s2 * 0.7), Color(0, 0, 0, 0.45 * minf(1.0, k * 3.0)), false, 1.5)
			K.CASING:
				ci.draw_set_transform(p[1], p[7], Vector2.ONE)
				var ca := minf(1.0, k * 4.0)
				ci.draw_rect(Rect2(-3.5, -1.5, 7, 3), Color(0.25, 0.15, 0.05, ca))
				ci.draw_rect(Rect2(-3, -1, 6, 2), Color(col, ca))
			K.FLIP:
				var idx := clampi(int(age * 8.0), 0, 7)
				SpriteLib.draw(ci, "explosion", EX_FRAMES[idx], p[1], false, p[5], Color.WHITE, p[13])
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_decals() -> void:
	for d in decals:
		var a: float = minf(1.0, d[4] / 2.0) * d[6].a
		var sf: Array = d[1]
		SpriteLib.draw(_decals, sf[0], sf[1], d[0], d[7], d[2], Color(1, 1, 1, a))


func _draw_normal() -> void:
	_draw_list(_n, parts_n)
	# floating text
	for t in texts:
		var big: bool = t[5]
		var dur := 1.4 if big else 1.0
		var a := 1.0 - clampf((t[2] - dur * 0.65) / (dur * 0.35), 0.0, 1.0)
		var pop := 1.0 + maxf(0.0, 0.22 - t[2]) * (4.0 if big else 2.2)
		if big and t[2] < 0.08:
			pop = lerpf(2.2, 1.9, t[2] / 0.08)
		var size := int(t[4] * pop)
		var font: Font = FONT_D if big else FONT
		var w := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos: Vector2 = t[0] - Vector2(w * 0.5, 0)
		_n.draw_string_outline(font, pos + Vector2(0, 3), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10 if big else 7, Color(0, 0, 0, 0.45 * a))
		_n.draw_string_outline(font, pos, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8 if big else 6, Color(0.08, 0.04, 0.02, a))
		_n.draw_string(font, pos, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(t[3], a))
		if big:
			_n.draw_string(font, pos + Vector2(0, -size * 0.18), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.25 * a))


func _draw_add() -> void:
	_draw_list(_a, parts_a)
