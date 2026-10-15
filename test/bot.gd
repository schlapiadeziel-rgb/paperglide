extends SceneTree
## Naive bot (not invulnerable): runs right, shoots, hops, grapples and throws.
## Prints progress, damage taken and deaths as a coarse difficulty signal.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 20:
		await physics_frame
	var p = game.player
	var deaths := 0
	var last_lives: int = game.lives
	var frames := 0
	var max_x := 0.0
	Input.action_press(&"shoot")
	while frames < 60 * 150:
		frames += 1
		await physics_frame
		if game.game_state in ["gameover", "victory"]:
			break
		if game.lives < last_lives:
			deaths += 1
			last_lives = game.lives
			print("[bot] died at x=%.0f t=%ds" % [p.global_position.x, frames / 60])
			for e in game.enemies:
				if is_instance_valid(e):
					print("   alive: %s state=%s pos=%s hp=%.0f" % [e.kind_name, e.state, str(e.global_position.round()), e.hp])
		max_x = maxf(max_x, p.global_position.x)
		var near_enemy := false
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead and absf(e.global_position.x - p.global_position.x) < 300.0:
				near_enemy = true
		var drone_over := false
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead and e.kind_name == "drone" and absf(e.global_position.x - p.global_position.x) < 260.0:
				drone_over = true
		# walk unless an enemy is close; hop periodically / over chasms
		var behind := false
		var vr: Rect2 = game.view_rect()
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead and e.kind_name != "drone" and vr.has_point(e.global_position) and e.global_position.x < p.global_position.x - 20.0:
				behind = true
		if behind and frames % 120 < 60:
			Input.action_release(&"move_right")
			Input.action_press(&"move_left")
		elif near_enemy and frames % 90 < 50:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_press(&"move_right")
		var ahead: float = game.ground_top(p.global_position.x + 90.0)
		var hop: bool = frames % 70 == 0 or (ahead > 900.0 and p.is_on_floor())
		if hop:
			Input.action_press(&"jump")
		elif frames % 70 == 12:
			Input.action_release(&"jump")
		if ahead > 900.0:
			Input.action_press(&"aim_up")
			if frames % 20 == 0:
				Input.action_press(&"grapple")
		elif frames % 150 == 40:
			Input.action_press(&"grapple")
		else:
			Input.action_release(&"grapple")
			if p.state == "swing" and p.velocity.y < 0.0 and p.velocity.x > 0.0:
				Input.action_press(&"jump")
			if drone_over and frames % 60 < 40:
				Input.action_press(&"aim_up")
			else:
				Input.action_release(&"aim_up")
		if p.carried != null and frames % 30 == 0:
			Input.action_press(&"grab")
		elif frames % 30 == 2:
			Input.action_release(&"grab")
		if near_enemy and frames % 240 == 100:
			Input.action_press(&"use_item")
		elif frames % 240 == 104:
			Input.action_release(&"use_item")
		if frames % 600 == 0:
			print("[bot] t=%ds x=%.0f hp=%.0f lives=%d weapon=%s score=%d boss=%s" % [frames / 60, p.global_position.x, p.hp, game.lives, p.weapon, game.score, game.boss_state])
	print("[BOT] end state=%s t=%ds max_x=%.0f deaths=%d score=%d kills=%d" % [game.game_state, frames / 60, max_x, deaths, game.score, game.stats.get("kills", -1)])
	quit(0)
