extends SceneTree
## Progression test: walks the hero through the whole mission (god mode),
## clears each lock arena by killing spawned enemies, defeats the boss and
## asserts the victory results appear. Guards against soft-locks.

var game: Node
var fails := 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	push_error("[PROGRESS_FAIL] " + msg)
	print("[PROGRESS_FAIL] " + msg)
	quit(1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 20:
		await physics_frame
	var p = game.player
	p.god = true
	var total_locks: int = game.locks.size()
	var cleared := 0
	var frames := 0
	var x: float = p.global_position.x
	var end_x: float = float(game.level.end_x)
	var boss_seen := false
	while frames < 60 * 240:
		frames += 1
		await physics_frame
		if game.game_state == "victory" or game.hud.results_visible():
			break
		# advance through the level on safe ground, hopping chasms
		var cam_right: float = game.cam_left + 1280.0 - 120.0
		if x < cam_right and x < end_x - 200.0:
			x += 9.0
		var gy: float = game.ground_top(x)
		var safe_x := x
		var tries := 0
		while gy > 900.0 and tries < 80:
			safe_x += 10.0
			gy = game.ground_top(safe_x)
			tries += 1
		if safe_x != x:
			x = safe_x
		p.global_position = Vector2(x, gy - 1.0)
		p.velocity = Vector2.ZERO
		p.hp = p.max_hp
		# clear enemies that are on screen once they have entered
		if frames % 20 == 0:
			for e in game.enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.state != "enter" and game.view_rect().grow(40).has_point(e.global_position):
					e.take_hit(9999.0, Vector2.RIGHT, "explosion")
		if game.lock_active and frames % 60 == 0:
			pass
		if game.boss != null and is_instance_valid(game.boss):
			boss_seen = true
			if game.boss_state == "fight" and frames % 30 == 0:
				game.boss.take_hit(30.0, Vector2.RIGHT, "explosion")
		if frames % 600 == 0:
			print("[progress] t=%ds x=%.0f cam=%.0f lock=%s locks_left=%d enemies=%d boss=%s" % [frames / 60, x, game.cam_left, game.lock_active, game.locks.size(), game.enemies.size(), game.boss_state])
	cleared = total_locks - game.locks.size()
	print("[progress] frames=%d cleared=%d/%d boss_seen=%s state=%s score=%d" % [frames, cleared, total_locks, boss_seen, game.game_state, game.score])
	for i in 50:
		await create_timer(0.1).timeout
		if game.hud.results_visible():
			break
	if cleared != total_locks:
		return _fail("not all arenas triggered (%d/%d)" % [cleared, total_locks])
	if not boss_seen:
		return _fail("boss never spawned")
	if game.game_state != "victory":
		return _fail("mission did not reach victory (state=%s boss=%s)" % [game.game_state, game.boss_state])
	if not game.hud.results_visible():
		return _fail("results screen not shown")
	print("[PROGRESS_PASS] all %d arenas cleared, boss defeated in %.1fs sim, score %d" % [total_locks, frames / 60.0, game.score])
	# Free the test-owned mission while the tree and audio server still run.
	if root.has_node("GameAudio"):
		root.get_node("GameAudio").stop_game()
	game.queue_free()
	game = null
	p = null
	for frame in 3:
		await process_frame
	await create_timer(0.2).timeout
	quit(0)
