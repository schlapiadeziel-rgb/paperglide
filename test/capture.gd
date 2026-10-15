extends SceneTree
## Visual QA: renders the title and several gameplay moments to PNGs.
## Usage: godot --audio-driver Dummy --path . --script test/capture.gd -- <outdir> [shots]

var out := "/tmp/cap"
var shots: Array = ["title", "start", "combat", "town", "canyon", "outpost", "boss"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		shots = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("[capture] ", name)


func _goto(game: Node, x: float) -> void:
	var p = game.player
	# enter the stage that owns x (theme, music, ambient) like the real flow
	for i in game.level.stages.size():
		var st: Dictionary = game.level.stages[i]
		if x >= float(st.x0) and x < float(st.x1) and game.stage_i != i:
			game._enter_stage(i)
			game.background.set_theme(str(st.theme), true)
	game.cam_left = maxf(game.cam_left, x - 520.0)
	p.global_position = Vector2(x, game.ground_top(x) - 2.0)
	p.velocity = Vector2.ZERO
	p.god = true
	p.hp = p.max_hp
	await _frames(3)
	game.snap_camera()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	if "title" in shots:
		var title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
		root.add_child(title)
		await _frames(50)
		await _snap("title")
		title.queue_free()
		await _frames(2)
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(40)
	if "start" in shots:
		await _snap("start")
	if "pause" in shots:
		game.hud.toggle_pause()
		await _frames(3)
		await _snap("pause")
		game.hud.controls_panel.visible = true
		await _frames(2)
		await _snap("pause_controls")
		game.hud.toggle_pause()
		await _frames(2)
	if "combat" in shots:
		await _goto(game, 860.0)
		Input.action_press(&"shoot")
		await _frames(20)
		Input.action_release(&"shoot")
		await _frames(4)
		await _snap("combat")
		game.player.grenades = 5
		game.player.item_sel = 0
		Input.action_press(&"use_item")
		await _frames(2)
		Input.action_release(&"use_item")
		await _frames(40)
		await _snap("grenade")
	if "town" in shots:
		await _goto(game, 2900.0)
		await _frames(40)
		await _snap("town")
	if "canyon" in shots:
		await _goto(game, 5420.0)
		await _frames(40)
		await _snap("canyon")
	if "swing" in shots:
		await _goto(game, 5470.0)
		await _frames(10)
		game.player.facing = 1.0
		Input.action_press(&"aim_up")
		Input.action_press(&"move_right")
		Input.action_press(&"grapple")
		await _frames(3)
		Input.action_release(&"grapple")
		Input.action_release(&"aim_up")
		var sx: float = game.player.global_position.x
		var ax: float = game.anchors[0].global_position.x
		var saw_swing := false
		for i in 240:
			await process_frame
			saw_swing = saw_swing or game.player.state == "swing"
			if game.player.state == "swing" and game.player.global_position.x > ax + 40.0 and game.player.velocity.y < 0.0:
				break
		await _snap("swing")
		print("[capture] swing state=%s saw=%s x=%.0f v=%s from %.0f" % [game.player.state, saw_swing, game.player.global_position.x, str(game.player.velocity), sx])
		Input.action_press(&"jump")
		await _frames(3)
		Input.action_release(&"jump")
		await _frames(90)
		Input.action_release(&"move_right")
		print("[capture] after swing x=%.0f y=%.0f floor=%s" % [game.player.global_position.x, game.player.global_position.y, game.player.is_on_floor()])
		await _snap("swing_land")
	if "carry" in shots:
		await _goto(game, 6980.0)
		await _frames(5)
		var e = game.spawn_enemy("grunt", game.player.global_position + Vector2(240, 0), {})
		game.spawn_enemy("grunt", game.player.global_position + Vector2(460, 0), {})
		await _frames(10)
		game.player.facing = 1.0
		Input.action_press(&"grapple")
		await _frames(2)
		Input.action_release(&"grapple")
		await _frames(8)
		await _snap("grapple_reel")
		await _frames(40)
		await _snap("carry")
	if "outpost" in shots:
		await _goto(game, 8300.0)
		await _frames(40)
		await _snap("outpost")
	if "fury" in shots:
		await _goto(game, 9500.0)
		for i in 4:
			game.spawn_enemy("grunt", game.player.global_position + Vector2(260 + i * 90, 0), {})
		await _frames(10)
		game.style.fury = 100.0
		game._start_fury()
		game.player.facing = 1.0
		Input.action_press(&"shoot")
		await _frames(45)
		await _snap("fury")
		Input.action_release(&"shoot")
		await _frames(20)
	if "chain" in shots:
		await _goto(game, 10000.0)
		var base: Vector2 = game.player.global_position + Vector2(320, 0)
		for i in 3:
			game._spawn_prop("barrel" if i != 1 else "fuel_tank", base + Vector2(i * 70, -10), "")
		game.spawn_enemy("grunt", base + Vector2(100, 0), {})
		game.spawn_enemy("grunt", base + Vector2(200, 0), {})
		await _frames(20)
		game.explode(base, 90.0, 5.0, 0, 1.0)
		await _frames(12)
		await _snap("chain")
		await _frames(30)
		await _snap("chain_after")
	if "tally" in shots:
		game._begin_tally()
		await _frames(150)
		await _snap("tally")
		await _frames(400)
	if "boss" in shots:
		for e in game.enemies.duplicate():
			e.remove()
		game.locks.clear()
		game.lock_active = false
		await _goto(game, 11800.0)
		await _frames(20)
		await _goto(game, 12100.0)
		await _frames(240)
		await _snap("boss")
		game.player.weapon = "rocket"
		game.player.ammo = 99
		game.player.facing = 1.0
		Input.action_press(&"shoot")
		await _frames(90)
		Input.action_release(&"shoot")
		await _snap("boss_fight")
		print("[capture] boss hp=%.0f/%.0f phase=%s" % [game.boss.hp, game.boss.max_hp, str(game.boss.get("phase"))])
		game.boss.take_hit(99999.0, Vector2.RIGHT, "explosion")
		await _frames(60)
		await _snap("boss_dying")
		await _frames(400)
		await _snap("results")
	quit(0)
