extends Control
## Chinese title screen and player-facing settings for the notebook-paper flyer.

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/world/notebook_background.png")
const PLANE_TEXTURE: Texture2D = preload("res://assets/player/paper_plane.png")
const GAME_SCENE := "res://scenes/game.tscn"
const UPDATE_CHECKER_SCRIPT: Script = preload("res://scripts/update_checker.gd")
const RELEASES_PAGE_URL := "https://github.com/schlapiadeziel-rgb/paperglide/releases"
const ACCENT_COLORS: Array[Color] = [
	Color("#e5a092"), Color("#e8c66f"), Color("#8dbfaf"),
	Color("#91b7d9"), Color("#b09acf"), Color("#abc884"),
]

var _started := false
var _best := 0
var _start_button: Button
var _settings_button: Button
var _pending_release_url := ""
var _update_overlay: Control
var _settings_overlay: Control
var _settings_status_label: Label
var _update_checker


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_configure_audio()
	var config := ConfigFile.new()
	if config.load("user://paper_flight.cfg") == OK:
		_best = maxi(0, int(config.get_value("flight", "best", 0)))
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "点击开始飞行"
	_start_button.position = Vector2(96.0, 432.0)
	_start_button.size = Vector2(320.0, 68.0)
	_start_button.add_theme_font_size_override("font_size", 23)
	_start_button.add_theme_color_override("font_color", Color("#fffaf0"))
	_start_button.add_theme_color_override("font_hover_color", Color("#fffaf0"))
	_start_button.add_theme_color_override("font_pressed_color", Color("#fffaf0"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#d6816f")
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0.20, 0.29, 0.35, 0.22)
	normal.shadow_size = 9
	normal.shadow_offset = Vector2(0.0, 4.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#bd695d")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#9f554e")
	_start_button.add_theme_stylebox_override("normal", normal)
	_start_button.add_theme_stylebox_override("hover", hover)
	_start_button.add_theme_stylebox_override("pressed", pressed)
	_start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start_button.pressed.connect(start_game)
	add_child(_start_button)

	_settings_button = _make_update_button("设置", Color("#668b8c"))
	_settings_button.name = "SettingsButton"
	_settings_button.position = Vector2(432.0, 432.0)
	_settings_button.size = Vector2(168.0, 68.0)
	_settings_button.add_theme_font_size_override("font_size", 22)
	_settings_button.pressed.connect(open_settings)
	add_child(_settings_button)
	_start_button.grab_focus()
	queue_redraw()
	_start_update_check()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(BACKGROUND_TEXTURE, rect, false)
	# Soft paper wash on the copy side keeps the title legible without hiding the page.
	draw_rect(Rect2(42.0, 78.0, 590.0, 540.0), Color(0.99, 0.975, 0.92, 0.46), true)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(104.0, 150.0), "NOTEBOOK FLIGHT  ·  01", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#47827f"))
		draw_string(font, Vector2(100.0, 278.0), "纸上飞行", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 76, Color("#354550"))
		draw_string(font, Vector2(106.0, 328.0), "折一架纸飞机，穿过云朵与铅笔管道。", HORIZONTAL_ALIGNMENT_LEFT, 520.0, 21, Color("#a6675f"))
		draw_string(font, Vector2(106.0, 376.0), "轻点向上，松开后交给重力。", HORIZONTAL_ALIGNMENT_LEFT, 520.0, 18, Color("#667b88"))
		draw_string(font, Vector2(104.0, 550.0), "点击 / 空格  飞行　　最佳纪录  %d" % _best, HORIZONTAL_ALIGNMENT_LEFT, 540.0, 16, Color("#557c78"))
	draw_rect(Rect2(104.0, 164.0, 34.0, 4.0), ACCENT_COLORS[0], true)
	draw_rect(Rect2(144.0, 164.0, 22.0, 4.0), ACCENT_COLORS[1], true)
	draw_rect(Rect2(172.0, 164.0, 28.0, 4.0), ACCENT_COLORS[2], true)
	# A hand-drawn looping flight path leads into the plane.
	for i in range(11):
		var x := 720.0 + float(i) * 17.0
		var y := 442.0 + sin(float(i) * 0.45) * 10.0
		draw_line(Vector2(x, y), Vector2(x + 9.0, y - 2.0), ACCENT_COLORS[i % ACCENT_COLORS.size()], 2.5, true)
	var plane_rect := Rect2(708.0, 180.0, 470.0, 314.0)
	var plane_tint: Color = FlightPreferences.get_plane_skin_color()
	plane_tint.a = 0.96
	draw_texture_rect(PLANE_TEXTURE, plane_rect, false, plane_tint)
	_draw_sparkle(Vector2(1160.0, 154.0), 10.0, ACCENT_COLORS[2])
	_draw_sparkle(Vector2(698.0, 520.0), 8.0, ACCENT_COLORS[1])
	_draw_sparkle(Vector2(1144.0, 548.0), 9.0, ACCENT_COLORS[4])
	# Notebook margin / page corner marks.
	draw_line(Vector2(64.0, 92.0), Vector2(64.0, 620.0), Color(0.78, 0.48, 0.5, 0.48), 2.0, true)
	draw_line(Vector2(90.0, 606.0), Vector2(440.0, 606.0), Color(0.40, 0.56, 0.66, 0.55), 2.0, true)


func _draw_sparkle(center: Vector2, radius: float, color: Color) -> void:
	draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), color, 2.0, true)
	draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), color, 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(_settings_overlay) or is_instance_valid(_update_overlay):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_game()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		start_game()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and is_instance_valid(_settings_overlay):
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and is_instance_valid(_update_overlay):
			_close_update_notice()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			start_game()
			get_viewport().set_input_as_handled()


func start_game() -> void:
	if _started or is_instance_valid(_settings_overlay) or is_instance_valid(_update_overlay):
		return
	_started = true
	get_tree().change_scene_to_file(GAME_SCENE)


func open_settings() -> void:
	if _started or is_instance_valid(_settings_overlay):
		return
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.z_index = 50
	add_child(_settings_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.20, 0.25, 0.29, 0.34)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(330.0, 52.0)
	panel.size = Vector2(620.0, 616.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff8e9")
	panel_style.border_color = Color("#d59a7d")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.18, 0.24, 0.28, 0.28)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0.0, 5.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_settings_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	stack.add_child(heading_row)
	var heading := Label.new()
	heading.text = "飞行设置"
	heading.custom_minimum_size = Vector2(0.0, 42.0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("#354550"))
	heading_row.add_child(heading)
	var close_button := _make_update_button("关闭", Color("#668b8c"))
	close_button.custom_minimum_size = Vector2(104.0, 42.0)
	close_button.pressed.connect(_close_settings)
	heading_row.add_child(close_button)
	var subtitle := Label.new()
	subtitle.text = "选项会保存在这台设备上。三连收集星星可获得一次纸盾护航。"
	subtitle.custom_minimum_size = Vector2(0.0, 28.0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#667b88"))
	stack.add_child(subtitle)

	var difficulty_option := _make_option_button(FlightPreferences.DIFFICULTIES.map(func(item: Dictionary) -> String: return String(item["name"])), FlightPreferences.get_difficulty_index())
	difficulty_option.name = "DifficultySelect"
	difficulty_option.item_selected.connect(func(index: int): FlightPreferences.set_difficulty_index(index))
	_add_settings_row(stack, "飞行难度", difficulty_option)
	var skin_option := _make_option_button(FlightPreferences.PLANE_SKIN_NAMES, FlightPreferences.get_plane_skin_index())
	skin_option.name = "PlaneSkinSelect"
	skin_option.item_selected.connect(func(index: int):
		FlightPreferences.set_plane_skin_index(index)
		queue_redraw()
	)
	_add_settings_row(stack, "纸飞机涂装", skin_option)

	var audio = get_node_or_null("/root/GameAudio")
	var sound_toggle := CheckButton.new()
	sound_toggle.name = "SoundToggle"
	sound_toggle.text = "开启"
	sound_toggle.custom_minimum_size = Vector2(170.0, 40.0)
	sound_toggle.add_theme_font_size_override("font_size", 17)
	sound_toggle.button_pressed = not bool(audio.is_bus_muted(&"SFX")) if is_instance_valid(audio) else true
	sound_toggle.toggled.connect(func(enabled: bool):
		if is_instance_valid(audio):
			audio.set_bus_muted(&"SFX", not enabled)
	)
	_add_settings_row(stack, "音效", sound_toggle)

	var volume_slider := HSlider.new()
	volume_slider.name = "SfxVolume"
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0
	volume_slider.custom_minimum_size = Vector2(250.0, 40.0)
	volume_slider.value = float(audio.get_bus_volume(&"SFX")) * 100.0 if is_instance_valid(audio) else 80.0
	volume_slider.value_changed.connect(func(value: float):
		if is_instance_valid(audio):
			audio.set_bus_volume(&"SFX", value / 100.0)
	)
	_add_settings_row(stack, "音效音量", volume_slider)

	var shield_toggle := CheckButton.new()
	shield_toggle.name = "ShieldRewardToggle"
	shield_toggle.text = "开启"
	shield_toggle.custom_minimum_size = Vector2(170.0, 40.0)
	shield_toggle.add_theme_font_size_override("font_size", 17)
	shield_toggle.button_pressed = FlightPreferences.is_star_shield_enabled()
	shield_toggle.toggled.connect(FlightPreferences.set_star_shield_enabled)
	_add_settings_row(stack, "三连星纸盾奖励", shield_toggle)

	var update_row := HBoxContainer.new()
	update_row.add_theme_constant_override("separation", 14)
	stack.add_child(update_row)
	var update_button := _make_update_button("检查更新", Color("#d6816f"))
	update_button.name = "CheckUpdatesButton"
	update_button.custom_minimum_size = Vector2(176.0, 46.0)
	update_button.pressed.connect(_manual_update_check)
	update_row.add_child(update_button)
	_settings_status_label = Label.new()
	_settings_status_label.name = "UpdateStatus"
	_settings_status_label.text = "Android 版可检查带 APK 的 GitHub 更新。"
	_settings_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_settings_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_status_label.add_theme_font_size_override("font_size", 14)
	_settings_status_label.add_theme_color_override("font_color", Color("#5b7078"))
	update_row.add_child(_settings_status_label)

	var version := String(ProjectSettings.get_setting("application/config/version", "1.3.0"))
	var version_label := Label.new()
	version_label.text = "当前版本  v%s" % version
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.custom_minimum_size = Vector2(0.0, 24.0)
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color("#829092"))
	stack.add_child(version_label)


func _make_option_button(items: Array, selected_index: int) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(250.0, 42.0)
	option.add_theme_font_size_override("font_size", 17)
	for item in items:
		option.add_item(String(item))
	option.select(clampi(selected_index, 0, maxi(0, items.size() - 1)))
	return option


func _add_settings_row(stack: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 46.0)
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190.0, 42.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#435b64"))
	row.add_child(label)
	row.add_child(control)
	stack.add_child(row)


func _close_settings() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null
	_settings_status_label = null
	if is_instance_valid(_settings_button):
		_settings_button.grab_focus()


func _manual_update_check() -> void:
	if not is_instance_valid(_settings_status_label):
		return
	if not OS.has_feature("android"):
		_settings_status_label.text = "Android APK 更新检查仅适用于 Android；已打开 GitHub 下载页。"
		OS.shell_open(RELEASES_PAGE_URL)
		return
	_settings_status_label.text = "正在检查 GitHub 最新 Android 版本……"
	_ensure_update_checker()
	_update_checker.check_for_update()


func _on_update_check_finished(found_update: bool, version: String, _release_url: String) -> void:
	if not is_instance_valid(_settings_status_label):
		return
	if found_update:
		_settings_status_label.text = "发现新版本 v%s，已显示下载提示。" % version
	else:
		_settings_status_label.text = "已是最新版本（v%s）。" % version


func _on_update_check_failed(message: String) -> void:
	if is_instance_valid(_settings_status_label):
		_settings_status_label.text = message


func _start_update_check() -> void:
	if not OS.has_feature("android"):
		return
	_ensure_update_checker()
	_update_checker.check_for_update()


func _ensure_update_checker() -> void:
	if is_instance_valid(_update_checker):
		return
	_update_checker = UPDATE_CHECKER_SCRIPT.new()
	_update_checker.update_available.connect(_show_update_notice)
	_update_checker.check_finished.connect(_on_update_check_finished)
	_update_checker.check_failed.connect(_on_update_check_failed)
	add_child(_update_checker)


func _show_update_notice(version: String, release_url: String) -> void:
	if _started or is_instance_valid(_update_overlay):
		return
	_pending_release_url = release_url
	_update_overlay = Control.new()
	_update_overlay.name = "UpdateNoticeOverlay"
	_update_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_overlay.z_index = 100
	add_child(_update_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.20, 0.25, 0.29, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(340.0, 238.0)
	panel.size = Vector2(600.0, 244.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#fff8e9")
	panel_style.border_color = Color("#d59a7d")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.18, 0.24, 0.28, 0.22)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0.0, 5.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_update_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var heading := Label.new()
	heading.text = "发现新版本 · %s" % version
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("#3d5962"))
	stack.add_child(heading)
	var message := Label.new()
	message.text = "打开 GitHub 下载页查看 Android 安装包；下载与安装由你确认。"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 17)
	message.add_theme_color_override("font_color", Color("#5b7078"))
	stack.add_child(message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var later_button := _make_update_button("稍后", Color("#668b8c"))
	later_button.pressed.connect(_close_update_notice)
	actions.add_child(later_button)
	var download_button := _make_update_button("打开下载页", Color("#d6816f"))
	download_button.pressed.connect(_open_release_page)
	actions.add_child(download_button)


func _open_release_page() -> void:
	if not _pending_release_url.is_empty():
		OS.shell_open(_pending_release_url)
	_close_update_notice()


func _close_update_notice() -> void:
	if is_instance_valid(_update_overlay):
		_update_overlay.queue_free()
	_update_overlay = null
	_pending_release_url = ""


func _make_update_button(text: String, fill: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(156.0, 48.0)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#fffaf0"))
	button.add_theme_color_override("font_hover_color", Color("#fffaf0"))
	button.add_theme_color_override("font_pressed_color", Color("#fffaf0"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.darkened(0.10)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.22)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


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
