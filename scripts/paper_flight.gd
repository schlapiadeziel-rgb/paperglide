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
const PICKUP_RADIUS := 18.0
const PICKUP_BOB_PIXELS := 5.0
const BASE_SCROLL_SPEED := 285.0
const BASE_SPAWN_INTERVAL := 1.75
const MAX_DIFFICULTY_LEVEL := 8
const DIFFICULTY_STEP_SECONDS := 8.0
const PENCIL_PALETTE: Array[Color] = [
	Color("#e5a092"), Color("#e8c66f"), Color("#8dbfaf"),
	Color("#91b7d9"), Color("#b09acf"), Color("#abc884"),
]

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
var _obstacle_palette_index := 0
var _gate_spawn_count := 0
var stickers_collected := 0
var sticker_streak := 0
var _reward_timer := 0.0
var _plane: Sprite2D
var _plane_shadow: Polygon2D
var _overlay: PanelContainer
var _title_label: Label
var _message_label: Label
var _hint_label: Label
var _score_label: Label
var _best_label: Label
var _difficulty_label: Label
var _sticker_label: Label
var _reward_label: Label


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
	if _reward_timer > 0.0:
		_reward_timer = maxf(0.0, _reward_timer - delta)
		if _reward_timer <= 0.0 and is_instance_valid(_reward_label):
			_reward_label.visible = false
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
	_obstacle_palette_index = 0
	_gate_spawn_count = 0
	stickers_collected = 0
	sticker_streak = 0
	_reward_timer = 0.0
	if is_instance_valid(_reward_label):
		_reward_label.visible = false
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
			_update_pickup(obstacle, x, gap_center, step)
			if not bool(obstacle["passed"]) and x + PIPE_HALF_WIDTH < PLAYER_X:
				if bool(obstacle.get("has_star", false)) and not bool(obstacle.get("star_collected", false)):
					sticker_streak = 0
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
		_difficulty_label.text = "节奏 %d" % (difficulty_level + 1)


func _spawn_obstacle(x: float, gap_center: float) -> void:
	var gate := Node2D.new()
	gate.name = "PencilPipeGate"
	gate.position = Vector2(x, gap_center)
	gate.z_index = 2
	var art := Sprite2D.new()
	art.texture = PIPE_TEXTURE
	var gate_color: Color = PENCIL_PALETTE[_obstacle_palette_index % PENCIL_PALETTE.size()]
	art.modulate = gate_color
	_obstacle_palette_index += 1
	art.scale = Vector2(0.55, 0.38)
	# The pencil tube is centered in its transparent canvas; the tiny optical
	# correction keeps its visual axis on the collision column.
	art.position = Vector2(-1.0, 10.0)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gate.add_child(art)
	var has_star := _gate_spawn_count % 2 == 0
	var obstacle: Dictionary = {
		"node": gate,
		"x": x,
		"gap_center": gap_center,
		"passed": false,
		"has_star": has_star,
		"star_collected": false,
	}
	if has_star:
		var pickup_offset := randf_range(-58.0, 58.0)
		var pickup_phase := randf_range(0.0, TAU)
		var star := _build_doodle_star(gate_color)
		star.position = Vector2(0.0, pickup_offset)
		gate.add_child(star)
		obstacle["star"] = star
		obstacle["pickup_offset"] = pickup_offset
		obstacle["pickup_phase"] = pickup_phase
	add_child(gate)
	_obstacles.append(obstacle)
	_gate_spawn_count += 1


func _update_pickup(obstacle: Dictionary, x: float, gap_center: float, step: float) -> void:
	if not bool(obstacle.get("has_star", false)) or bool(obstacle.get("star_collected", false)):
		return
	var star := obstacle.get("star") as Node2D
	if not is_instance_valid(star):
		return
	var phase := float(obstacle.get("pickup_phase", 0.0))
	var base_offset := float(obstacle.get("pickup_offset", 0.0))
	star.position.y = base_offset + sin(run_elapsed * 3.4 + phase) * PICKUP_BOB_PIXELS
	star.rotation += step * 1.5
	var star_y := gap_center + star.position.y
	var overlaps_star := absf(x - PLAYER_X) <= PLAYER_HALF_WIDTH + PICKUP_RADIUS and absf(star_y - player_y) <= PLAYER_HALF_HEIGHT + PICKUP_RADIUS
	if overlaps_star:
		_collect_star(obstacle, star)


func _collect_star(obstacle: Dictionary, star: Node2D) -> void:
	obstacle["star_collected"] = true
	star.visible = false
	stickers_collected += 1
	sticker_streak += 1
	_reward_timer = 1.35
	_reward_label.text = "三连星章！" if sticker_streak % 3 == 0 else "收下星星贴纸 +1"
	_sync_hud()


func _build_doodle_star(fill_color: Color) -> Node2D:
	var star := Node2D.new()
	star.name = "DoodleStarSticker"
	star.z_index = 10
	var halo_points := PackedVector2Array()
	for point in 20:
		var halo_angle := TAU * float(point) / 20.0
		halo_points.append(Vector2(cos(halo_angle) * 22.0, sin(halo_angle) * 22.0))
	var halo := Polygon2D.new()
	halo.polygon = halo_points
	halo.color = Color(fill_color.r, fill_color.g, fill_color.b, 0.18)
	star.add_child(halo)
	var star_points := PackedVector2Array()
	for point in 10:
		var radius := 18.0 if point % 2 == 0 else 8.5
		var angle := -PI * 0.5 + float(point) * PI / 5.0
		star_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	var fill := Polygon2D.new()
	fill.polygon = star_points
	fill.color = fill_color.lightened(0.12)
	star.add_child(fill)
	var outline_points := star_points.duplicate()
	outline_points.append(star_points[0])
	var outline := Line2D.new()
	outline.points = outline_points
	outline.width = 2.4
	outline.default_color = Color("#8c6b4f")
	star.add_child(outline)
	return star


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

	var eyebrow := _new_label("纸页 · 01", 18, Color("#3f7b82"))
	eyebrow.position = Vector2(38.0, 24.0)
	eyebrow.size = Vector2(220.0, 36.0)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(eyebrow)
	for index in PENCIL_PALETTE.size():
		var color_stroke := ColorRect.new()
		color_stroke.position = Vector2(40.0 + float(index) * 20.0, 61.0)
		color_stroke.size = Vector2(14.0, 3.0)
		color_stroke.color = PENCIL_PALETTE[index]
		color_stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(color_stroke)

	_score_label = _new_label("0", 58, Color("#d87362"))
	_score_label.position = Vector2(500.0, 18.0)
	_score_label.size = Vector2(280.0, 78.0)
	root.add_child(_score_label)

	var score_caption := _new_label("穿过的障碍", 16, Color("#5e7180"))
	score_caption.position = Vector2(500.0, 82.0)
	score_caption.size = Vector2(280.0, 30.0)
	root.add_child(score_caption)

	_sticker_label = _new_label("贴纸 0  ·  连击 0", 18, Color("#977548"))
	_sticker_label.position = Vector2(770.0, 24.0)
	_sticker_label.size = Vector2(215.0, 36.0)
	_sticker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_sticker_label)
	_reward_label = _new_label("", 20, Color("#b97750"))
	_reward_label.position = Vector2(440.0, 116.0)
	_reward_label.size = Vector2(400.0, 36.0)
	_reward_label.visible = false
	root.add_child(_reward_label)

	_difficulty_label = _new_label("节奏 1", 18, Color("#806ca0"))
	_difficulty_label.position = Vector2(1000.0, 24.0)
	_difficulty_label.size = Vector2(240.0, 36.0)
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_difficulty_label)

	var instruction := _new_label("轻触 / 空格：向上飞", 17, Color("#417f8b"))
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
	panel_style.border_color = Color("#d59a7d")
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
	_best_label = _new_label("最佳纪录  0", 16, Color("#6c8f67"))
	stack.add_child(_best_label)
	_hint_label = _new_label("点击 / 空格 开始", 18, Color("#c96f5e"))
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
	_difficulty_label.text = "节奏 %d" % (difficulty_level + 1)
	_sticker_label.text = "贴纸 %d  ·  连击 %d" % [stickers_collected, sticker_streak]
	_reward_label.visible = state == "playing" and _reward_timer > 0.0
	_overlay.visible = state != "playing"
	_score_label.visible = state != "ready"
	if state == "ready":
		_title_label.text = "准备好起飞了吗？"
		_message_label.text = "轻点起飞，穿过铅笔管道；收集星星贴纸，连成三连！"
		_hint_label.text = "点击 / 空格 开始"
	elif state == "over":
		_title_label.text = "纸飞机落地了"
		_message_label.text = "穿过 %d 道管道，收集 %d 枚星星贴纸。" % [score, stickers_collected]
		_hint_label.text = "点击 / 空格，再飞一次"


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = maxi(0, int(config.get_value("flight", "best", 0)))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("flight", "best", best_score)
	config.save(SAVE_PATH)
