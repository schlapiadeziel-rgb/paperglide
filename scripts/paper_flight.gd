extends Node2D
## A single-tap paper-plane flyer set on a ruled notebook page.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/world/notebook_background.png")
const PLANE_TEXTURE: Texture2D = preload("res://assets/player/paper_plane.png")
const PIPE_TEXTURE: Texture2D = preload("res://assets/hazards/pencil_pipes.png")
const SAVE_PATH := "user://paper_flight.cfg"
const VIEW_SIZE := Vector2(1280.0, 720.0)
const PLAYER_X := 270.0
const PLAYER_HALF_WIDTH := 42.0
const PLAYER_HALF_HEIGHT := 23.0
const PIPE_HALF_WIDTH := 72.0
const GAP_HEIGHT := 244.0
const BASE_SCROLL_SPEED := 285.0
const BASE_SPAWN_INTERVAL := 1.75
const MAX_DIFFICULTY_LEVEL := 8
const DIFFICULTY_STEP_SECONDS := 8.0

var state := "ready" # ready, playing, over
var score := 0
var best_score := 0
var player_y := 360.0
var player_velocity := 0.0
var gravity := 1180.0
var flap_impulse := -405.0
var scroll_speed := BASE_SCROLL_SPEED
var spawn_interval := BASE_SPAWN_INTERVAL
var spawn_timer := 0.6
var difficulty_level := 0
var run_elapsed := 0.0
var _idle_time := 0.0
var _obstacles: Array[Dictionary] = []
var _plane: Sprite2D
var _plane_shadow: Polygon2D
var _overlay: PanelContainer
var _title_label: Label
var _message_label: Label
var _hint_label: Label
var _score_label: Label
var _best_label: Label
var _difficulty_label: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_best()
	_configure_audio()
	var backdrop := Sprite2D.new()
	backdrop.name = "NotebookPage"
	backdrop.texture = BACKGROUND_TEXTURE
	backdrop.position = VIEW_SIZE * 0.5
	backdrop.scale = VIEW_SIZE / Vector2(BACKGROUND_TEXTURE.get_width(), BACKGROUND_TEXTURE.get_height())
	backdrop.z_index = -100
	add_child(backdrop)

	_plane_shadow = Polygon2D.new()
	_plane_shadow.name = "SoftPaperShadow"
	var shadow_points := PackedVector2Array()
	for point in 24:
		var angle := TAU * float(point) / 24.0
		shadow_points.append(Vector2(cos(angle) * 43.0, sin(angle) * 10.0))
	_plane_shadow.polygon = shadow_points
	_plane_shadow.color = Color(0.24, 0.30, 0.34, 0.16)
	_plane_shadow.position = Vector2(PLAYER_X + 18.0, player_y + 45.0)
	_plane_shadow.z_index = 4
	add_child(_plane_shadow)

	_plane = Sprite2D.new()
	_plane.name = "FoldedPaperPlane"
	_plane.texture = PLANE_TEXTURE
	_plane.position = Vector2(PLAYER_X, player_y)
	_plane.scale = Vector2(0.06, 0.06)
	_plane.z_index = 10
	add_child(_plane)
	_build_hud()
	_sync_hud()


func _process(delta: float) -> void:
	_idle_time += delta
	if state == "ready":
		player_y = 360.0 + sin(_idle_time * 2.1) * 8.0
		_sync_plane()
	elif state == "over":
		_sync_plane()


func _physics_process(delta: float) -> void:
	_simulate_frame(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_primary_action()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		handle_primary_action()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		handle_primary_action()
		get_viewport().set_input_as_handled()


func handle_primary_action() -> void:
	match state:
		"ready":
			start_run()
		"playing":
			flap()
		"over":
			start_run()


func start_run() -> void:
	_clear_obstacles()
	score = 0
	player_y = 360.0
	player_velocity = 0.0
	run_elapsed = 0.0
	difficulty_level = 0
	_apply_difficulty()
	spawn_timer = 0.55
	state = "playing"
	var audio := get_node_or_null("/root/GameAudio")
	if is_instance_valid(audio) and not bool(audio.get("enabled")):
		audio.begin_game()
	flap()
	_sync_hud()


func flap() -> void:
	if state != "playing":
		return
	player_velocity = flap_impulse
	_play_sound(&"paper_flap")
	_sync_plane()


func _simulate_frame(delta: float) -> void:
	if state != "playing" or delta <= 0.0:
		return
	var step := minf(delta, 0.12)
	run_elapsed += step
	var next_level := mini(int(run_elapsed / DIFFICULTY_STEP_SECONDS), MAX_DIFFICULTY_LEVEL)
	if next_level != difficulty_level:
		difficulty_level = next_level
		_apply_difficulty()
		_sync_hud()
	player_velocity = minf(player_velocity + gravity * step, 820.0)
	player_y += player_velocity * step
	spawn_timer -= step
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		var center_margin := GAP_HEIGHT * 0.5 + 42.0
		_spawn_obstacle(VIEW_SIZE.x + 120.0, randf_range(center_margin, VIEW_SIZE.y - center_margin))

	if player_y - PLAYER_HALF_HEIGHT < 26.0 or player_y + PLAYER_HALF_HEIGHT > VIEW_SIZE.y - 24.0:
		_end_run()
		_sync_plane()
		return

	for i in range(_obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = _obstacles[i]
		var x := float(obstacle["x"]) - scroll_speed * step
		obstacle["x"] = x
		var node := obstacle["node"] as Node2D
		if is_instance_valid(node):
			node.position.x = x
		var gap_center := float(obstacle["gap_center"])
		var overlaps_x := absf(x - PLAYER_X) < PIPE_HALF_WIDTH + PLAYER_HALF_WIDTH
		var safely_in_gap := player_y - PLAYER_HALF_HEIGHT > gap_center - GAP_HEIGHT * 0.5 and player_y + PLAYER_HALF_HEIGHT < gap_center + GAP_HEIGHT * 0.5
		if overlaps_x and not safely_in_gap:
			_end_run()
			break
		if not bool(obstacle["passed"]) and x + PIPE_HALF_WIDTH < PLAYER_X:
			obstacle["passed"] = true
			score += 1
			best_score = maxi(best_score, score)
			_play_sound(&"gate_pass")
			_sync_hud()
		_obstacles[i] = obstacle
		if x < -PIPE_HALF_WIDTH - 100.0:
			if is_instance_valid(node):
				node.queue_free()
			_obstacles.remove_at(i)
	_sync_plane()


func _apply_difficulty() -> void:
	# A gentle timed ramp keeps the first gates readable, then tightens the rhythm.
	scroll_speed = BASE_SCROLL_SPEED + float(difficulty_level) * 18.0
	spawn_interval = maxf(1.39, BASE_SPAWN_INTERVAL - float(difficulty_level) * 0.045)
	if is_instance_valid(_difficulty_label):
		_difficulty_label.text = "節奏 %d" % (difficulty_level + 1)


func _spawn_obstacle(x: float, gap_center: float) -> void:
	var gate := Node2D.new()
	gate.name = "PencilPipeGate"
	gate.position = Vector2(x, gap_center)
	gate.z_index = 2
	var art := Sprite2D.new()
	art.texture = PIPE_TEXTURE
	art.scale = Vector2(0.55, 0.38)
	# The pencil tube is centered in its transparent canvas; the tiny optical
	# correction keeps its visual axis on the collision column.
	art.position = Vector2(-1.0, 10.0)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gate.add_child(art)
	add_child(gate)
	_obstacles.append({"node": gate, "x": x, "gap_center": gap_center, "passed": false})


func _clear_obstacles() -> void:
	for obstacle in _obstacles:
		var node := obstacle["node"] as Node2D
		if is_instance_valid(node):
			node.queue_free()
	_obstacles.clear()


func _end_run() -> void:
	if state != "playing":
		return
	state = "over"
	best_score = maxi(best_score, score)
	_save_best()
	_play_sound(&"paper_bump")
	_sync_hud()


func _play_sound(cue: StringName) -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if is_instance_valid(audio) and audio.has_method("play"):
		audio.play(cue)


func _configure_audio() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if not is_instance_valid(audio) or bool(audio.get("enabled")) or bool(audio.get("_catalog_configured")):
		return
	var paths: Dictionary[StringName, String] = {
		&"paper_flap": "res://assets/audio/flight_flap.mp3",
		&"gate_pass": "res://assets/audio/gate_pass.mp3",
		&"paper_bump": "res://assets/audio/paper_bump.mp3",
	}
	var cues: Dictionary[StringName, AudioStream] = {}
	for cue in paths:
		var stream := load(paths[cue]) as AudioStream
		if stream != null:
			cues[cue] = stream
	if cues.size() == paths.size():
		audio.configure(null, cues)


func _sync_plane() -> void:
	if is_instance_valid(_plane):
		_plane.position = Vector2(PLAYER_X, player_y)
		_plane.rotation = clampf(player_velocity / 1200.0, -0.34, 0.5)
	if is_instance_valid(_plane_shadow):
		_plane_shadow.position = Vector2(PLAYER_X + 18.0, player_y + 45.0)
		_plane_shadow.color.a = clampf(0.20 - absf(player_y - 360.0) * 0.00025, 0.08, 0.20)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var eyebrow := _new_label("紙頁 · 01", 18, Color("#465c6d"))
	eyebrow.position = Vector2(38.0, 24.0)
	eyebrow.size = Vector2(220.0, 36.0)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(eyebrow)

	_score_label = _new_label("0", 58, Color("#344450"))
	_score_label.position = Vector2(500.0, 18.0)
	_score_label.size = Vector2(280.0, 78.0)
	root.add_child(_score_label)

	var score_caption := _new_label("穿過的障礙", 15, Color("#5e7180"))
	score_caption.position = Vector2(500.0, 82.0)
	score_caption.size = Vector2(280.0, 30.0)
	root.add_child(score_caption)

	_difficulty_label = _new_label("節奏 1", 17, Color("#496d86"))
	_difficulty_label.position = Vector2(1000.0, 24.0)
	_difficulty_label.size = Vector2(240.0, 36.0)
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_difficulty_label)

	var instruction := _new_label("輕點 / 空格：向上飛", 16, Color("#496274"))
	instruction.position = Vector2(0.0, 666.0)
	instruction.size = Vector2(1280.0, 32.0)
	root.add_child(instruction)

	_overlay = PanelContainer.new()
	_overlay.name = "FlightNote"
	_overlay.position = Vector2(370.0, 236.0)
	_overlay.size = Vector2(540.0, 250.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.99, 0.975, 0.92, 0.94)
	panel_style.border_color = Color("#9aafbc")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.18, 0.24, 0.28, 0.16)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	_overlay.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_overlay)

	var margin := MarginContainer.new()
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	_overlay.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	_title_label = _new_label("准备好起飞了吗？", 30, Color("#344450"))
	stack.add_child(_title_label)
	_message_label = _new_label("轻点一下，让折叠纸飞机向上跃起。", 17, Color("#526879"))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_message_label)
	_best_label = _new_label("最佳纪录  0", 16, Color("#6888a0"))
	stack.add_child(_best_label)
	_hint_label = _new_label("点击 / 空格 开始", 18, Color("#3f7193"))
	stack.add_child(_hint_label)


func _new_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _sync_hud() -> void:
	if not is_instance_valid(_overlay):
		return
	_score_label.text = str(score)
	_best_label.text = "最佳纪录  %d" % best_score
	_difficulty_label.text = "節奏 %d" % (difficulty_level + 1)
	_overlay.visible = state != "playing"
	_score_label.visible = state != "ready"
	if state == "ready":
		_title_label.text = "准备好起飞了吗？"
		_message_label.text = "轻点一下，让折叠纸飞机向上跃起。"
		_hint_label.text = "点击 / 空格 开始"
	elif state == "over":
		_title_label.text = "紙飛機落地了"
		_message_label.text = "這次穿過了 %d 道鉛筆管道。" % score
		_hint_label.text = "點擊 / 空格，再飛一次"


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = maxi(0, int(config.get_value("flight", "best", 0)))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("flight", "best", best_score)
	config.save(SAVE_PATH)
