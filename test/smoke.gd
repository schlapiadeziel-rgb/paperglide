extends SceneTree
## Bounded smoke test for the one-touch paper-plane loop and requested advanced features.

var _failed := false
var _saved_record_snapshot := PackedByteArray()
var _had_saved_record := false


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_had_saved_record = FileAccess.file_exists("user://paper_flight.cfg")
	if _had_saved_record:
		var record_file := FileAccess.open("user://paper_flight.cfg", FileAccess.READ)
		if record_file != null:
			_saved_record_snapshot = record_file.get_buffer(record_file.get_length())
	await _frames(2)
	var title_scene := load("res://scenes/title_screen.tscn") as PackedScene
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	if title_scene == null or game_scene == null:
		return _fail("title or game scene failed to load")
	var title := title_scene.instantiate()
	root.add_child(title)
	await _frames(2)
	if not title.has_method("start_game"):
		return _fail("title screen has no start action")
	title.queue_free()
	await _frames(1)

	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if game.state != "ready":
		return _fail("game did not start in the ready state")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(640.0, 360.0)
	game._unhandled_input(touch)
	if game.state != "playing":
		return _fail("touch did not start the flight")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game.state = "ready"
	game._unhandled_input(click)
	if game.state != "playing":
		return _fail("click did not start the flight")
	if game.player_velocity >= 0.0:
		return _fail("starting click did not lift the plane")
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.get_play_count(&"paper_flap") < 1:
		return _fail("starting flap produced no registered sound cue")

	game.player_y = 360.0
	game.player_velocity = 0.0
	game._simulate_frame(0.08)
	if game.player_y <= 360.0:
		return _fail("gravity did not pull the plane down between taps")
	game.player_y = 360.0
	game.flap()
	var lifted_velocity: float = game.player_velocity
	game._simulate_frame(0.08)
	if lifted_velocity >= 0.0 or game.player_y >= 360.0:
		return _fail("tap did not send the plane upward")

	game.gravity = 0.0
	game.player_y = 360.0
	game.player_velocity = 0.0
	game.run_elapsed = 0.0
	game.difficulty_level = 0
	game._apply_difficulty()
	game.spawn_timer = 999.0
	var base_speed: float = game.scroll_speed
	var base_interval: float = game.spawn_interval
	game._spawn_obstacle(game.PLAYER_X + 250.0, 360.0)
	for _frame in 13:
		game._simulate_frame(0.1)
	if game.score != 1:
		return _fail("passing a pipe gate did not add exactly one point (score=%d)" % game.score)
	if audio != null and audio.get_play_count(&"gate_pass") < 1:
		return _fail("passing a pipe gate produced no registered sound cue")

	game._clear_obstacles()
	game.player_y = 360.0
	game.player_velocity = 0.0
	game.run_elapsed = 0.0
	game.difficulty_level = 0
	game._apply_difficulty()
	game.spawn_timer = 999.0
	for _frame in 70:
		game._simulate_frame(0.12)
	if game.difficulty_level < 1 or game.scroll_speed <= base_speed or game.spawn_interval >= base_interval:
		return _fail("survival time did not raise speed and tighten obstacle rhythm")

	game.player_y = 500.0
	game._spawn_obstacle(game.PLAYER_X, 180.0)
	game._simulate_frame(0.01)
	if game.state != "over":
		return _fail("pipe collision did not end the run")
	if audio != null and audio.get_play_count(&"paper_bump") < 1:
		return _fail("collision produced no registered landing cue")
	game._unhandled_input(touch)
	if game.state != "playing" or game.score != 0:
		return _fail("touch after game over did not restart the run")

	print("[SMOKE_PASS] paper flyer: touch, click, gravity, flap, scoring, SFX, timed difficulty ramp, collision and replay verified")
	_restore_saved_record()
	# The Dummy output clock is independent from simulated physics delta. Let the
	# final short one-shots drain so the native test process releases MP3 streams.
	await create_timer(0.8).timeout
	game.queue_free()
	title = null
	game = null
	await _frames(2)
	quit(0)


func _restore_saved_record() -> void:
	if _had_saved_record:
		var record_file := FileAccess.open("user://paper_flight.cfg", FileAccess.WRITE)
		if record_file != null:
			record_file.store_buffer(_saved_record_snapshot)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://paper_flight.cfg"))


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("[SMOKE_FAIL] " + message)
	print("[SMOKE_FAIL] " + message)
	quit(1)
