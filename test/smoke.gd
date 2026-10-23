extends SceneTree
## Bounded smoke test for the one-touch paper-plane loop and requested advanced features.

var _failed := false
var _saved_record_snapshot := PackedByteArray()
var _had_saved_record := false
var _saved_preferences_snapshot := PackedByteArray()
var _had_saved_preferences := false
var _snapshots_ready := false


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var snapshot_ok := true
	_had_saved_record = FileAccess.file_exists("user://paper_flight.cfg")
	if _had_saved_record:
		var record_file := FileAccess.open("user://paper_flight.cfg", FileAccess.READ)
		if record_file != null:
			_saved_record_snapshot = record_file.get_buffer(record_file.get_length())
		else:
			snapshot_ok = false
	_had_saved_preferences = FileAccess.file_exists("user://paper_flight_settings.cfg")
	if _had_saved_preferences:
		var preference_file := FileAccess.open("user://paper_flight_settings.cfg", FileAccess.READ)
		if preference_file != null:
			_saved_preferences_snapshot = preference_file.get_buffer(preference_file.get_length())
		else:
			snapshot_ok = false
	_snapshots_ready = snapshot_ok
	await _frames(2)
	var preferences := root.get_node_or_null("FlightPreferences")
	if preferences == null:
		return _fail("player preference store autoload is missing")
	preferences.set_difficulty_index(1)
	preferences.set_plane_skin_index(0)
	preferences.set_star_shield_enabled(true)
	preferences.set_trail_style_index(1)
	preferences.set_page_theme_index(0)
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
		{"tag_name": "v1.5.1-android-debug", "draft": false, "html_url": "https://github.com/schlapiadeziel-rgb/paperglide/releases/tag/v1.5.1-android-debug", "assets": [{"name": "paperglide-android-v1.5.1.apk"}]},
	]
	var update: Dictionary = checker.find_newer_release(mock_releases, "1.0.0")
	if String(update.get("version", "")) != "1.5.1":
		return _fail("update checker did not find the newer APK release")
	if not checker.find_newer_release(mock_releases, "1.5.1").is_empty():
		return _fail("update checker offered an equal or older release")
	var update_results: Array = []
	checker.check_finished.connect(func(found: bool, version: String, url: String): update_results.append([found, version, url]))
	checker._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(mock_releases).to_utf8_buffer())
	if update_results.is_empty() or not bool(update_results[0][0]) or String(update_results[0][1]) != "1.5.1":
		return _fail("manual update check did not report the newer APK release")
	checker.free()
	var title := title_scene.instantiate()
	root.add_child(title)
	await _frames(2)
	if not title.has_method("start_game"):
		return _fail("title screen has no start action")
	if not title.has_method("open_settings"):
		return _fail("title screen has no settings action")
	title.open_settings()
	if not is_instance_valid(title._settings_overlay):
		return _fail("settings overlay did not open")
	var title_background := title.find_child("NotebookPageTheme", true, false)
	if title_background == null or not title_background.has_method("refresh"):
		return _fail("title screen notebook page theme renderer is missing")
	for control_name in ["DifficultySelect", "PlaneSkinSelect", "TrailStyleSelect", "NotebookThemeSelect", "SoundToggle", "SfxVolume", "ShieldRewardToggle", "CheckUpdatesButton"]:
		if title._settings_overlay.find_child(control_name, true, false) == null:
			return _fail("settings control is missing: %s" % control_name)
	preferences.set_trail_style_index(3)
	preferences.set_page_theme_index(2)
	var saved_preferences := ConfigFile.new()
	if saved_preferences.load("user://paper_flight_settings.cfg") != OK:
		return _fail("new visual settings were not saved locally")
	if int(saved_preferences.get_value("preferences", "trail_style", -1)) != 3 or int(saved_preferences.get_value("preferences", "page_theme", -1)) != 2:
		return _fail("trail style or page theme did not persist")
	preferences.set_trail_style_index(1)
	preferences.set_page_theme_index(0)
	var settings_touch := InputEventScreenTouch.new()
	settings_touch.pressed = true
	title._gui_input(settings_touch)
	if bool(title.get("_started")):
		return _fail("touch outside a settings action started the game behind the modal")
	title._close_settings()
	title.queue_free()
	await _frames(1)

	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if game._plane.modulate != preferences.get_plane_skin_color():
		return _fail("selected paper-plane color was not applied in gameplay")
	if game.state != "ready":
		return _fail("game did not start in the ready state")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(640.0, 360.0)
	game._unhandled_input(touch)
	if game.state != "playing":
		return _fail("touch did not start the flight")
	var pause_button := game.find_child("PauseButton", true, false) as Button
	var pause_overlay := game.find_child("PauseOverlay", true, false) as Control
	var resume_button := game.find_child("ResumeButton", true, false) as Button
	var pause_restart_button := game.find_child("RestartButton", true, false) as Button
	if pause_button == null or pause_overlay == null or resume_button == null or pause_restart_button == null:
		return _fail("in-flight pause controls or modal are missing")
	var pause_key := InputEventKey.new()
	pause_key.pressed = true
	pause_key.keycode = KEY_P
	game._unhandled_input(pause_key)
	if game.state != "paused" or not paused or not pause_overlay.visible:
		return _fail("P shortcut did not pause the flight")
	var frozen_y: float = game.player_y
	var frozen_velocity: float = game.player_velocity
	var frozen_spawn_timer: float = game.spawn_timer
	var frozen_elapsed: float = game.run_elapsed
	game._simulate_frame(0.5)
	if not is_equal_approx(game.player_y, frozen_y) or not is_equal_approx(game.player_velocity, frozen_velocity) or not is_equal_approx(game.spawn_timer, frozen_spawn_timer) or not is_equal_approx(game.run_elapsed, frozen_elapsed):
		return _fail("flight simulation advanced while paused")
	var resume_key := InputEventKey.new()
	resume_key.pressed = true
	resume_key.keycode = KEY_ESCAPE
	game._unhandled_input(resume_key)
	if game.state != "playing" or paused or pause_overlay.visible:
		return _fail("Escape shortcut did not resume the flight")
	pause_button.emit_signal("pressed")
	if game.state != "paused":
		return _fail("screen pause button did not pause the flight")
	resume_button.emit_signal("pressed")
	if game.state != "playing" or paused:
		return _fail("pause-card resume action did not continue the flight")
	pause_button.emit_signal("pressed")
	pause_restart_button.emit_signal("pressed")
	if game.state != "playing" or paused or game.score != 0:
		return _fail("pause-card restart did not reset and resume the flight")
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
	if int(game._flight_trail.call("get_sample_count")) < 1:
		return _fail("enabled doodle trail did not record the flight path")
	preferences.set_trail_style_index(0)
	game._flight_trail.call("advance", 20.0, Vector2(game.PLAYER_X, game.player_y), true)
	if int(game._flight_trail.call("get_sample_count")) != 0:
		return _fail("turning off the doodle trail did not clear it")
	preferences.set_trail_style_index(1)
	game._flight_trail.call("reset")
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
	if game._reward_label.text != "三连星章！获得纸盾":
		return _fail("third consecutive star did not trigger the shield badge")
	if game.shield_charges != 1:
		return _fail("three consecutive stars did not grant one paper shield")
	if game.score != 1:
		return _fail("star pickups changed the primary obstacle score")
	game._clear_obstacles()
	game.player_y = 500.0
	game.player_velocity = 0.0
	game._spawn_obstacle(game.PLAYER_X, 180.0)
	game._simulate_frame(0.01)
	if game.state != "playing" or game.shield_charges != 0 or game.shield_invulnerability_time <= 0.0:
		return _fail("paper shield did not absorb one pipe collision")

	game._clear_obstacles()
	game.player_y = 360.0
	game.player_velocity = 0.0
	game.run_elapsed = 0.0
	game.difficulty_level = 0
	game._apply_difficulty()
	var normal_gap: float = game.active_gap_height
	var normal_speed: float = game.scroll_speed
	preferences.set_difficulty_index(0)
	game._apply_difficulty()
	var easy_speed: float = game.scroll_speed
	if game.active_gap_height <= normal_gap or easy_speed >= normal_speed:
		return _fail("easy difficulty did not widen the gap and reduce base speed")
	preferences.set_difficulty_index(2)
	game._apply_difficulty()
	if game.active_gap_height >= normal_gap or game.scroll_speed <= normal_speed:
		return _fail("challenge difficulty did not narrow the gap and raise base speed")
	preferences.set_difficulty_index(1)
	game._apply_difficulty()
	game.spawn_timer = 999.0
	for _frame in 70:
		game._simulate_frame(0.12)
	if game.difficulty_level < 1 or game.scroll_speed <= base_speed or game.spawn_interval >= base_interval:
		return _fail("survival time did not raise speed and tighten obstacle rhythm")

	game.player_y = 500.0
	game.shield_charges = 0
	game.shield_invulnerability_time = 0.0
	game._spawn_obstacle(game.PLAYER_X, 180.0)
	game._simulate_frame(0.01)
	if game.state != "over":
		return _fail("pipe collision did not end the run")
	if audio != null and audio.get_play_count(&"paper_bump") < 1:
		return _fail("collision produced no registered landing cue")
	game._unhandled_input(touch)
	if game.state != "playing" or game.score != 0:
		return _fail("touch after game over did not restart the run")
	if game.stickers_collected != 0 or game.sticker_streak != 0 or game.shield_charges != 0:
		return _fail("replay did not reset stickers, chain and shield")

	print("[SMOKE_PASS] paper flyer: settings, manual update result, pause/resume, flight, score, difficulty, plane skin, star shield, SFX and replay verified")
	_restore_saved_record()
	_restore_saved_preferences()
	# The Dummy output clock is independent from simulated physics delta. Let the
	# final short one-shots drain so the native test process releases MP3 streams.
	await create_timer(0.8).timeout
	game.queue_free()
	title = null
	game = null
	await _frames(2)
	quit(0)


func _restore_saved_record() -> void:
	if not _snapshots_ready:
		return
	if _had_saved_record:
		var record_file := FileAccess.open("user://paper_flight.cfg", FileAccess.WRITE)
		if record_file != null:
			record_file.store_buffer(_saved_record_snapshot)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://paper_flight.cfg"))


func _restore_saved_preferences() -> void:
	if not _snapshots_ready:
		return
	if _had_saved_preferences:
		var preference_file := FileAccess.open("user://paper_flight_settings.cfg", FileAccess.WRITE)
		if preference_file != null:
			preference_file.store_buffer(_saved_preferences_snapshot)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://paper_flight_settings.cfg"))


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("[SMOKE_FAIL] " + message)
	print("[SMOKE_FAIL] " + message)
	_restore_saved_record()
	_restore_saved_preferences()
	quit(1)
