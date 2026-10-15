extends RefCounted
## Operation: Dust Fang — three stages on one continuous strip. Ground top is y=600.
## All positions are world pixels; enemies spawn lazily when the camera's
## right edge reaches their `x` (or `at` for timed entries).
## Stage media for 2 and 3 is streamed (Segments); a gate at each stage end
## shows the tally card and waits for the next segment if needed.

const G := 600.0

static func data() -> Dictionary:
	return {
		"start": Vector2(140, G),
		"end_x": 12880.0,
		"stages": [
			{"id": 1, "name": "DUST FANG TOWN", "sub": "Stage 1  -  Frontier outskirts", "x0": -400.0, "x1": 5460.0, "gate": 5380.0, "seg": "stage1", "theme": "town"},
			{"id": 2, "name": "RUSTLINE CANYON", "sub": "Stage 2  -  The old rail trestle", "x0": 5460.0, "x1": 9000.0, "gate": 8960.0, "seg": "stage2", "theme": "canyon"},
			{"id": 3, "name": "JACKAL FORTRESS", "sub": "Stage 3  -  Iron Jackal stronghold", "x0": 9000.0, "x1": 12880.0, "gate": 99999.0, "seg": "stage3", "theme": "fortress"},
		],
		"grounds": [
			# [x0, x1, top]
			[-400.0, 5500.0, G],
			[5900.0, 6300.0, G],
			[6800.0, 12880.0, G],
		],
		"platforms": [
			# [x, y, width]
			[1780.0, 440.0, 300.0],
			[2660.0, 440.0, 260.0], [3000.0, 330.0, 240.0], [3480.0, 440.0, 300.0], [3900.0, 380.0, 260.0],
			[6000.0, 440.0, 200.0],
			[7250.0, 450.0, 240.0],
			[8450.0, 440.0, 260.0], [9150.0, 420.0, 240.0], [9600.0, 440.0, 260.0],
			[11700.0, 420.0, 220.0], [12100.0, 420.0, 220.0],
		],
		"blocks": [
			# solid crate stacks [x, width, height]
			[8000.0, 128.0, 96.0], [8660.0, 128.0, 128.0], [10420.0, 128.0, 96.0],
		],
		"decor": [
			# [sheet, frame, x, y(bottom), scale, flip]
			["decor", "palm", 60.0, G, 1.0, false], ["decor", "jeep", 560.0, G + 6, 0.9, false], ["decor", "wire", 1080.0, G + 4, 0.6, false],
			["decor", "tent", 1600.0, G + 4, 0.8, false], ["decor", "agave", 2080.0, G + 8, 0.6, false], ["decor", "palm", 2400.0, G, 0.9, true],
			["decor", "wall", 2790.0, G + 6, 0.85, false], ["decor", "tower", 3350.0, G + 6, 1.0, false], ["decor", "wall", 3620.0, G + 6, 0.8, true],
			["decor", "rubble", 4150.0, G + 10, 0.7, false], ["decor", "palm", 4600.0, G, 1.05, false], ["decor", "wire", 4980.0, G + 4, 0.6, true],
			["decor", "agave", 5300.0, G + 8, 0.55, true],
			# stage 2 - canyon
			["decor_canyon", "hoodoo", 6120.0, G + 8, 0.95, false], ["decor_canyon", "cactus", 6960.0, G + 8, 0.7, false],
			["decor_canyon", "water_tower", 7380.0, G + 6, 1.0, false], ["decor_canyon", "boxcar", 7800.0, G + 8, 0.95, true],
			["decor_canyon", "minecart", 8250.0, G + 6, 0.75, false], ["decor_canyon", "boulders", 8620.0, G + 10, 0.7, false],
			["decor_canyon", "skull", 7060.0, G + 10, 0.55, true], ["decor_canyon", "pier", 6870.0, G + 8, 0.8, false],
			# stage 3 - fortress
			["decor_fortress", "watchtower", 9120.0, G + 6, 1.0, false], ["decor_fortress", "hedgehog", 9460.0, G + 8, 0.55, false],
			["decor_fortress", "silo", 9860.0, G + 8, 1.0, false], ["decor_fortress", "banner", 10300.0, G + 6, 0.9, false],
			["decor_fortress", "pipes", 10720.0, G + 8, 0.9, true], ["decor_fortress", "radar", 11060.0, G + 6, 1.0, false],
			["decor_fortress", "crates", 11360.0, G + 8, 0.75, false], ["decor_fortress", "jeep", 12380.0, G + 8, 0.85, true],
			["decor_fortress", "banner", 12720.0, G + 6, 0.9, true],
		],
		"props": [
			# [kind, x, y, content]
			["crate", 760.0, G, "grenades"], ["barrel", 1300.0, G, ""], ["crate", 2000.0, G, "medkit"],
			["barrel", 3060.0, G, ""], ["crate", 3350.0, G, "grenades"], ["ammo_crate", 3560.0, 440.0, "shield"],
			["barrel", 3820.0, G, ""],
			# chain-reaction alley in front of the square ambush
			["barrel", 4470.0, G, ""], ["barrel", 4540.0, G, ""], ["fuel_tank", 4620.0, G, ""], ["crate", 4760.0, G, "medkit"],
			["barrel", 4960.0, G, ""], ["fuel_tank", 5030.0, G, ""],
			# stage 2
			["crate", 6180.0, G, "grenades"], ["barrel", 6960.0, G, ""], ["fuel_tank", 7030.0, G, ""], ["barrel", 7100.0, G, ""],
			["ammo_crate", 7700.0, G, "spread"], ["barrel", 8200.0, G, ""], ["fuel_tank", 8270.0, G, ""], ["ammo_crate", 8720.0, G, "rocket"],
			# stage 3
			["barrel", 9120.0, G, ""], ["crate", 9480.0, G, "medkit"], ["fuel_tank", 10150.0, G, ""], ["barrel", 10210.0, G, ""],
			["crate", 10640.0, G, "grenades"], ["fuel_tank", 11600.0, G, ""], ["barrel", 11990.0, G, ""],
		],
		"pickups": [
			["medal", 1930.0, 430.0], ["medal", 3120.0, 320.0], ["gold", 4020.0, 370.0],
			["medal", 6100.0, 430.0], ["gold", 7370.0, 440.0], ["gold", 9270.0, 410.0], ["medal", 9700.0, 430.0],
		],
		"captives": [
			[1560.0, G, "hmg"], [3200.0, 330.0, "spread"], [6100.0, G, "rocket"],
			[7330.0, 450.0, "grenades"], [8780.0, G, "medkit"], [9420.0, G, "hmg"], [10560.0, G, "shield"],
		],
		"anchors": [
			[5700.0, 300.0], [6550.0, 290.0], [11950.0, 200.0],
		],
		"nests": [
			# mounted heavy MG emplacements [x]
			[9560.0],
		],
		"checkpoints": [2500.0, 5620.0, 7650.0, 9060.0, 11120.0],
		"enemies": [
			# [kind, x, y, data]
			["grunt", 980.0, G, {}], ["grunt", 1400.0, G, {}], ["grunt", 1470.0, G, {"facing": -1.0}],
			["grunt", 1930.0, 440.0, {}], ["grunt", 2200.0, G, {"enter": true, "at": 2250.0}], ["grunt", 2320.0, G, {}],
			["shield", 2960.0, G, {}], ["grunt", 2780.0, 440.0, {}], ["grunt", 3120.0, 330.0, {}],
			["drone", 3300.0, 250.0, {}], ["grunt", 3420.0, G, {}], ["drone", 3700.0, 230.0, {}],
			["shield", 3860.0, G, {}], ["grunt", 4020.0, 380.0, {}], ["grunt", 3960.0, G, {}],
			# stage 2
			["drone", 6080.0, 210.0, {"at": 5800.0}], ["grunt", 6060.0, 440.0, {}], ["grunt", 6240.0, G, {}],
			["drone", 6950.0, 220.0, {"at": 6700.0}], ["grunt", 6950.0, G, {}], ["shield", 7120.0, G, {}],
			["mortar", 7420.0, G, {}], ["grunt", 7300.0, 450.0, {}], ["grunt", 7520.0, G, {}],
			["drone", 7600.0, 200.0, {}], ["drone", 7660.0, 250.0, {}],
			# stage 3 (outside locks)
			["mortar", 10000.0, G, {}], ["grunt", 10600.0, G, {}],
		],
		"locks": [
			{
				"name": "Ambush at the square", "cam_left": 4000.0,
				"waves": [
					[["grunt", 5100.0, G, {"enter": true}], ["grunt", 5180.0, G, {"enter": true}], ["shield", 5150.0, G, {"enter": true}], ["drone", 5000.0, 240.0, {"enter": true}]],
					[["grunt", 4500.0, G, {"drop": true}], ["grunt", 4900.0, G, {"drop": true}], ["drone", 5000.0, 220.0, {"enter": true}], ["shield", 5150.0, G, {"enter": true}], ["grunt", 5220.0, G, {"enter": true}]],
				],
			},
			{
				"name": "Rustline rail yard", "cam_left": 7700.0,
				"waves": [
					[["brute", 8850.0, G, {"enter": true}], ["grunt", 8800.0, G, {"enter": true}], ["grunt", 8600.0, 440.0, {"drop": true}]],
					[["drone", 8700.0, 220.0, {"enter": true}], ["drone", 8800.0, 260.0, {"enter": true}], ["drone", 8900.0, 200.0, {"enter": true}], ["shield", 8850.0, G, {"enter": true}], ["grunt", 8100.0, G, {"drop": true}]],
				],
			},
			{
				"name": "Fortress breach - man the MG!", "cam_left": 9200.0,
				"waves": [
					[["grunt", 10380.0, G, {"enter": true}], ["grunt", 10440.0, G, {"enter": true}], ["grunt", 10500.0, G, {"enter": true}], ["shield", 10460.0, G, {"enter": true}]],
					[["drone", 10300.0, 220.0, {"enter": true}], ["drone", 10400.0, 180.0, {"enter": true}], ["grunt", 10380.0, G, {"enter": true}], ["grunt", 10450.0, G, {"enter": true}], ["grunt", 9700.0, 440.0, {"drop": true}]],
					[["brute", 10460.0, G, {"enter": true}], ["shield", 10400.0, G, {"enter": true}], ["grunt", 10500.0, G, {"enter": true}], ["grunt", 10540.0, G, {"enter": true}]],
				],
			},
			{
				"name": "Outpost gate", "cam_left": 10180.0,
				"waves": [
					[["brute", 11300.0, G, {"enter": true}], ["grunt", 11350.0, G, {"enter": true}], ["grunt", 11420.0, G, {"enter": true}]],
					[["shield", 11380.0, G, {"enter": true}], ["drone", 11200.0, 240.0, {"enter": true}], ["drone", 11300.0, 200.0, {"enter": true}], ["grunt", 10600.0, G, {"drop": true}], ["grunt", 11000.0, G, {"drop": true}]],
				],
			},
		],
		"boss": {"cam_left": 11520.0, "home": Vector2(12500.0, 540.0), "arena_left": 11520.0, "arena_right": 12800.0},
		"tutorial": [
			# [x, text, id]
			[0.0, "[A][D] move    [SPACE] jump", "move"],
			[380.0, "[J] shoot    hold [W] aim up    [S] crouch", "shoot"],
			[640.0, "[L] pick up the crate    [L] again to throw it", "grab"],
			[1120.0, "Shoot or throw things at [RED BARRELS] - explosions CHAIN!", "barrel"],
			[1460.0, "Touch or shoot captives to free them - they bring gifts", "captive"],
			[1700.0, "[K] fires the grapple - hook an enemy to reel him in", "grapple"],
			[2280.0, "[E] throw grenade    [Q] switch item (grenade / medkit / barrier)", "items"],
			[2900.0, "Mix up your kills to raise your STYLE rank - it multiplies score", "style"],
			[4300.0, "FURY meter full? Press [F] for golden overdrive!", "fury_hint"],
			[5560.0, "Glowing rings: hold [W] + [K] to SWING    [SPACE] to let go", "swing"],
			[7180.0, "Mortar! Stay out of the red target zones", "mortar"],
			[7760.0, "HEAVY! [K] grapple him to zip in for a GRAPPLE KICK", "heavy"],
			[9300.0, "Stand at the MG nest and press [L] to man it    [L] again to hop off", "nest"],
		],
	}
