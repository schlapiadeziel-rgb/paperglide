extends Control
## Chinese title screen for the notebook-paper flyer.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/world/notebook_background.png")
const PLANE_TEXTURE: Texture2D = preload("res://assets/player/paper_plane.png")
const GAME_SCENE := "res://scenes/game.tscn"

var _started := false
var _best := 0
var _start_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_configure_audio()
	var config := ConfigFile.new()
	if config.load("user://paper_flight.cfg") == OK:
		_best = maxi(0, int(config.get_value("flight", "best", 0)))
	_start_button = Button.new()
	_start_button.text = "点击开始飞行"
	_start_button.position = Vector2(96.0, 432.0)
	_start_button.size = Vector2(320.0, 68.0)
	_start_button.add_theme_font_size_override("font_size", 23)
	_start_button.add_theme_color_override("font_color", Color("#fffaf0"))
	_start_button.add_theme_color_override("font_hover_color", Color("#fffaf0"))
	_start_button.add_theme_color_override("font_pressed_color", Color("#fffaf0"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#557f9e")
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0.20, 0.29, 0.35, 0.22)
	normal.shadow_size = 9
	normal.shadow_offset = Vector2(0.0, 4.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#3f6f93")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#385f7c")
	_start_button.add_theme_stylebox_override("normal", normal)
	_start_button.add_theme_stylebox_override("hover", hover)
	_start_button.add_theme_stylebox_override("pressed", pressed)
	_start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start_button.pressed.connect(start_game)
	add_child(_start_button)
	_start_button.grab_focus()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(BACKGROUND_TEXTURE, rect, false)
	# Soft paper wash on the copy side keeps the title legible without hiding the page.
	draw_rect(Rect2(42.0, 78.0, 590.0, 540.0), Color(0.99, 0.975, 0.92, 0.46), true)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(104.0, 150.0), "NOTEBOOK FLIGHT  ·  01", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#52718a"))
		draw_string(font, Vector2(100.0, 278.0), "纸上飞行", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 76, Color("#354550"))
		draw_string(font, Vector2(106.0, 328.0), "折一架纸飞机，穿过云朵与铅笔管道。", HORIZONTAL_ALIGNMENT_LEFT, 520.0, 21, Color("#536a79"))
		draw_string(font, Vector2(106.0, 376.0), "轻点向上，松开后交给重力。", HORIZONTAL_ALIGNMENT_LEFT, 520.0, 18, Color("#667b88"))
		draw_string(font, Vector2(104.0, 550.0), "点击 / 空格  飞行　　最佳纪录  %d" % _best, HORIZONTAL_ALIGNMENT_LEFT, 540.0, 16, Color("#54738c"))
	# A hand-drawn looping flight path leads into the plane.
	for i in range(11):
		var x := 720.0 + float(i) * 17.0
		var y := 442.0 + sin(float(i) * 0.45) * 10.0
		draw_line(Vector2(x, y), Vector2(x + 9.0, y - 2.0), Color("#6f93aa"), 2.0, true)
	var plane_rect := Rect2(708.0, 180.0, 470.0, 314.0)
	draw_texture_rect(PLANE_TEXTURE, plane_rect, false, Color(1.0, 1.0, 1.0, 0.96))
	# Notebook margin / page corner marks.
	draw_line(Vector2(64.0, 92.0), Vector2(64.0, 620.0), Color(0.78, 0.48, 0.5, 0.48), 2.0, true)
	draw_line(Vector2(90.0, 606.0), Vector2(440.0, 606.0), Color(0.40, 0.56, 0.66, 0.55), 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_game()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		start_game()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		start_game()
		get_viewport().set_input_as_handled()


func start_game() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file(GAME_SCENE)


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
