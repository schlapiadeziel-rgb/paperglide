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
	var checker_script := load("res://scripts/update_checker.gd") as Script
	if checker_script == null:
		return _fail("Android update checker script failed to load")
	var checker = checker_script.new()
	var mock_releases: Array = [
		{"tag_name": "v1.0.0-android-debug", "draft": false, "html_url": "https://github.com/schlapiadeziel-rgb/paperglide/releases/tag/v1.0.0-android-debug", "assets": [{"name": "paperglide-android-debug.apk"}]},
		{"tag_name": "v1.1.0-android-debug", "draft": false, "html_url": "https://github.com/schlapiadeziel-rgb/paperglide/releases/tag/v1.1.0-android-debug", "assets": [{"name": "paperglide-android-debug.apk"}]},
	]
	var update: Dictionary = checker.find_newer_release(mock_releases, "1.0.0")
	if String(update.get("version", "")) != "1.1.0":
		return _fail("update checker did not find the newer APK release")
	if not checker.find_newer_release(mock_releases, "1.1.0").is_empty():
		return _fail("update checker offered an equal or older release")
	checker.free()
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
	var first_gate := game._obstacles.back()["node"] as Node2D
	var first_art := first_gate.get_child(0) as Sprite2D
	var first_tint: Color = first_art.modulate
	game._spawn_obstacle(game.PLAYER_X + 1600.0, 360.0)
	var second_gate := game._obstacles.back()["node"] as Node2D
	var second_art := second_gate.get_child(0) as Sprite2D
	if first_tint == second_art.modulate:
		return _fail("successive pencil gates did not use varied palette colors")
	if not bool(game._obstacles[0].get("has_star", false)) or bool(game._obstacles[1].get("has_star", true)):
		return _fail("star stickers were not placed on alternating gates")
	for _frame in 13:
		game._simulate_frame(0.1)
	if game.score != 1:
		return _fail("passing a pipe gate did not add exactly one point (score=%d)" % game.score)
	if audio != null and audio.get_play_count(&"gate_pass") < 1:
		return _fail("passing a pipe gate produced no registered sound cue")

	game._clear_obstacles()
	game._obstacle_palette_index = 0
	game._gate_spawn_count = 0
	game.stickers_collected = 0
	game.sticker_streak = 0
	game.run_elapsed = 0.0
	game.player_velocity = 0.0
	for pickup_index in 3:
		if pickup_index > 0:
			game._spawn_obstacle(game.PLAYER_X + 400.0, 360.0)
		game._spawn_obstacle(game.PLAYER_X + 50.0, 360.0)
		var reward_gate: Dictionary = game._obstacles.back()
		var star := reward_gate.get("star") as Node2D
		if not bool(reward_gate.get("has_star", false)) or not is_instance_valid(star):
			return _fail("an alternating pencil gate had no collectible star")
		game.player_y = 360.0 + float(reward_gate.get("pickup_offset", 0.0))
		game._simulate_frame(0.01)
		if game.stickers_collected != pickup_index + 1 or game.sticker_streak != pickup_index + 1:
			return _fail("flying through a star did not add to the sticker chain")
	if game._reward_label.text != "三连星章！":
		return _fail("third consecutive star did not trigger the star badge")
	if game.score != 1:
		return _fail("star pickups changed the primary obstacle score")

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
	if game.stickers_collected != 0 or game.sticker_streak != 0:
		return _fail("replay did not reset the sticker count and chain")

	print("[SMOKE_PASS] paper flyer: flight, obstacle score, alternating star pickups, three-star badge, streak reset, SFX, difficulty and replay verified")
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
