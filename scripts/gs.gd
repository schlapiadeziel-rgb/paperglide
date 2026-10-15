class_name GS
extends RefCounted
## Shared constants and the active-world handle for Side Scroller.

const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_PROPS := 8
const L_PLATFORM := 16

const GROUND_Y := 600.0
const VIEW_W := 1280.0
const VIEW_H := 720.0
const KILL_Y := 1000.0

# Palette used by procedural FX, HUD and UI.
const C_INK := Color("#1a0f0a")
const C_ORANGE := Color("#ff8a1f")
const C_YELLOW := Color("#ffd23f")
const C_RED := Color("#e63b2e")
const C_CYAN := Color("#46e0ff")
const C_STEEL := Color("#3a3f4a")
const C_SAND := Color("#e0a764")
const C_CREAM := Color("#fff2d6")
const C_GOLD := Color("#ffc21a")
const C_FURY := Color("#ffb300")
const VARIANTS := ["_a", "_b", "_c", "_d"]

## The running game scene (set by game.gd); entities reach shared systems through it.
static var game: Node = null

static func tuning(key: String, fallback: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var store: Node = tree.root.get_node_or_null("/root/TuningStore") if tree != null else null
	if store == null or not store.has_method("get_value"):
		return fallback
	if not (store.values.has(key) or store.defaults.has(key)):
		return fallback
	return float(store.get_value(key))

static func reduced_motion() -> bool:
	return tuning("reduced_motion", 0.0) > 0.5

static func sfx(cue: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var audio: Node = tree.root.get_node_or_null("/root/GameAudio") if tree != null else null
	if audio != null:
		audio.play(cue)

## Random layered variant: sfx_var(&"punch", 3) plays punch_a/b/c.
static func sfx_var(base: StringName, count: int) -> void:
	sfx(StringName(String(base) + VARIANTS[randi() % clampi(count, 1, 4)]))

## Segment vs rect test used for hitscan-style projectile sweeps.
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var p := a[axis]
		var dd := d[axis]
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(dd) < 0.0001:
			if p < lo or p > hi:
				return false
		else:
			var ta := (lo - p) / dd
			var tb := (hi - p) / dd
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true
