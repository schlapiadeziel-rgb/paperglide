extends Node2D
## Bounded, cosmetic flight-trail doodles; it never participates in gameplay checks.

const MAX_DISTANCE := 290.0
const SAMPLE_SPACING := 20.0
const MAX_SAMPLES := 22
const TRAIL_COLORS: Array[Color] = [
	Color("#e5a092"), Color("#e8c66f"), Color("#8dbfaf"),
	Color("#91b7d9"), Color("#b09acf"), Color("#abc884"),
]

var _world_distance := 0.0
var _anchor_x := 270.0
var _last_sample_distance := -1000000.0
var _style_index := 1
var _samples: Array[Dictionary] = []


func reset() -> void:
	_world_distance = 0.0
	_last_sample_distance = -1000000.0
	_samples.clear()
	queue_redraw()


func clear() -> void:
	_last_sample_distance = -1000000.0
	_samples.clear()
	queue_redraw()


func advance(distance_delta: float, plane_position: Vector2, active: bool) -> void:
	_anchor_x = plane_position.x
	_world_distance += maxf(0.0, distance_delta)
	_style_index = FlightPreferences.get_trail_style_index()
	if not active or _style_index == 0:
		if not _samples.is_empty():
			clear()
		return
	while not _samples.is_empty() and _world_distance - float(_samples[0]["distance"]) > MAX_DISTANCE:
		_samples.pop_front()
	if _world_distance - _last_sample_distance >= SAMPLE_SPACING:
		_samples.append({"distance": _world_distance, "y": plane_position.y})
		_last_sample_distance = _world_distance
		if _samples.size() > MAX_SAMPLES:
			_samples.pop_front()
	queue_redraw()


func get_sample_count() -> int:
	return _samples.size()


func _draw() -> void:
	if _style_index <= 0 or _samples.size() < 2:
		return
	match _style_index:
		1:
			_draw_pencil_dashes()
		2:
			_draw_star_doodles()
		3:
			_draw_paper_confetti()


func _draw_pencil_dashes() -> void:
	for index in range(_samples.size() - 1):
		if index % 2 != 0:
			continue
		var first: Dictionary = _samples[index]
		var second: Dictionary = _samples[index + 1]
		var alpha := minf(_fade(first), _fade(second)) * 0.76
		var ink := Color("#827565")
		ink.a = alpha
		var wobble := sin(float(index) * 1.7) * 1.4
		draw_line(_screen_position(first) + Vector2(0.0, wobble), _screen_position(second) - Vector2(0.0, wobble), ink, 2.2, true)


func _draw_star_doodles() -> void:
	for index in range(0, _samples.size(), 2):
		var sample: Dictionary = _samples[index]
		var center := _screen_position(sample)
		var radius := 3.4 + _fade(sample) * 1.5
		var ink: Color = TRAIL_COLORS[index % TRAIL_COLORS.size()]
		ink.a = _fade(sample) * 0.86
		draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), ink, 1.8, true)
		draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), ink, 1.8, true)
		draw_line(center - Vector2(radius * 0.55, radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), ink, 1.3, true)


func _draw_paper_confetti() -> void:
	for index in range(0, _samples.size(), 2):
		var sample: Dictionary = _samples[index]
		var center := _screen_position(sample)
		var radius := 4.2
		var angle := float(index) * 0.63
		var corners := PackedVector2Array()
		for corner in 4:
			var corner_angle := angle + float(corner) * PI * 0.5
			corners.append(center + Vector2(cos(corner_angle), sin(corner_angle)) * radius)
		var paper: Color = TRAIL_COLORS[index % TRAIL_COLORS.size()]
		paper.a = _fade(sample) * 0.82
		draw_colored_polygon(corners, paper)


func _screen_position(sample: Dictionary) -> Vector2:
	var distance_behind := maxf(0.0, _world_distance - float(sample["distance"]))
	return Vector2(_anchor_x - distance_behind, float(sample["y"]))


func _fade(sample: Dictionary) -> float:
	var distance_behind := maxf(0.0, _world_distance - float(sample["distance"]))
	return 1.0 - clampf(distance_behind / MAX_DISTANCE, 0.0, 1.0)
