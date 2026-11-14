extends Control
## Chinese title screen and player-facing settings for the notebook-paper flyer.

const PAGE_BACKGROUND_SCRIPT: Script = preload("res://scripts/notebook_page_background.gd")
const PLANE_TEXTURE: Texture2D = preload("res://assets/player/paper_plane.png")
const GAME_SCENE := "res://scenes/game.tscn"
const UPDATE_CHECKER_SCRIPT: Script = preload("res://scripts/update_checker.gd")
const RELEASES_PAGE_URL := "https://github.com/schlapiadeziel-rgb/paperglide/releases"
const ONLINE_LEADERBOARD_SCRIPT: Script = preload("res://scripts/online_leaderboard.gd")
const NATIVE_LEADERBOARD_ORIGIN := "https://paperglide-hvglp97k.manus.game"
const ACCENT_COLORS: Array[Color] = [
	Color("#e5a092"), Color("#e8c66f"), Color("#8dbfaf"),
	Color("#91b7d9"), Color("#b09acf"), Color("#abc884"),
]

var _started := false
var _best := 0
var _start_button: Button
var _settings_button: Button
var _leaderboard_button: Button
var _leaderboard_overlay: Control
var _leaderboard_client
var _leaderboard_status_label: Label
var _leaderboard_rank_label: Label
var _leaderboard_rows: VBoxContainer
var _leaderboard_refresh_button: Button
var _leaderboard_new_guest_button: Button
var _leaderboard_loading := false
var _leaderboard_guest_expired := false
var _pending_release_url := ""
var _update_overlay: Control
var _settings_overlay: Control
var _settings_status_label: Label
var _update_checker
var _page_background: Node2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_configure_audio()
	_page_background = PAGE_BACKGROUND_SCRIPT.new() as Node2D
	_page_background.name = "NotebookPageTheme"
	_page_background.z_index = -100
	add_child(_page_background)
	_leaderboard_client = ONLINE_LEADERBOARD_SCRIPT.new()
	_leaderboard_client.name = "OnlineLeaderboardClient"
	if OS.get_name() == "Android":
		_leaderboard_client.native_game_origin = NATIVE_LEADERBOARD_ORIGIN
	add_child(_leaderboard_client)
	var config := ConfigFile.new()
	if config.load("user://paper_flight.cfg") == OK:
		_best = maxi(0, int(config.get_value("flight", "best", 0)))
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "点击开始飞行"
	_start_button.position = Vector2(96.0, 432.0)
	_start_button.size = Vector2(204.0, 68.0)
	_start_button.add_theme_font_size_override("font_size", 20)
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

	_leaderboard_button = _make_update_button("排行榜", Color("#8f9b73"))
	_leaderboard_button.name = "LeaderboardButton"
	_leaderboard_button.position = Vector2(308.0, 432.0)
	_leaderboard_button.size = Vector2(146.0, 68.0)
	_leaderboard_button.custom_minimum_size = Vector2(146.0, 48.0)
	_leaderboard_button.add_theme_font_size_override("font_size", 18)
	_leaderboard_button.pressed.connect(open_leaderboard)
	add_child(_leaderboard_button)

	_settings_button = _make_update_button("设置", Color("#668b8c"))
	_settings_button.name = "SettingsButton"
	_settings_button.position = Vector2(466.0, 432.0)
	_settings_button.size = Vector2(134.0, 68.0)
	_settings_button.custom_minimum_size = Vector2(134.0, 48.0)
	_settings_button.add_theme_font_size_override("font_size", 18)
	_settings_button.pressed.connect(open_settings)
	add_child(_settings_button)
	_start_button.grab_focus()
	queue_redraw()
	_start_update_check()


func _draw() -> void:
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
	if is_instance_valid(_settings_overlay) or is_instance_valid(_update_overlay) or is_instance_valid(_leaderboard_overlay):
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
		if event.keycode == KEY_ESCAPE and is_instance_valid(_leaderboard_overlay):
			_close_leaderboard()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			start_game()
			get_viewport().set_input_as_handled()


func start_game() -> void:
	if _started or is_instance_valid(_settings_overlay) or is_instance_valid(_update_overlay) or is_instance_valid(_leaderboard_overlay):
		return
	_started = true
	get_tree().change_scene_to_file(GAME_SCENE)


func open_settings() -> void:
	if _started or is_instance_valid(_settings_overlay) or is_instance_valid(_leaderboard_overlay):
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
	panel.position = Vector2(300.0, 38.0)
	panel.size = Vector2(680.0, 644.0)
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
		margin.add_theme_constant_override("margin_" + edge, 16)
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
	subtitle.text = "轨迹与页面主题只改变外观，不影响碰撞或分数。设置保存在本机；三连星纸盾可抵挡一次撞击。"
	subtitle.custom_minimum_size = Vector2(0.0, 42.0)
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
	var trail_option := _make_option_button(FlightPreferences.TRAIL_STYLE_NAMES, FlightPreferences.get_trail_style_index())
	trail_option.name = "TrailStyleSelect"
	trail_option.item_selected.connect(FlightPreferences.set_trail_style_index)
	_add_settings_row(stack, "飞行轨迹涂鸦", trail_option)
	var theme_option := _make_option_button(FlightPreferences.PAGE_THEME_NAMES, FlightPreferences.get_page_theme_index())
	theme_option.name = "NotebookThemeSelect"
	theme_option.item_selected.connect(func(index: int):
		FlightPreferences.set_page_theme_index(index)
		if is_instance_valid(_page_background):
			_page_background.call("refresh")
	)
	_add_settings_row(stack, "笔记本页面", theme_option)

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

	var version := String(ProjectSettings.get_setting("application/config/version", "1.4.0"))
	var version_label := Label.new()
	version_label.text = "当前版本  v%s" % version
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.custom_minimum_size = Vector2(0.0, 24.0)
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color("#829092"))
	stack.add_child(version_label)


func open_leaderboard() -> void:
	if _started or is_instance_valid(_leaderboard_overlay) or is_instance_valid(_settings_overlay) or is_instance_valid(_update_overlay):
		return
	_leaderboard_guest_expired = false
	_leaderboard_overlay = Control.new()
	_leaderboard_overlay.name = "LeaderboardOverlay"
	_leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leaderboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_leaderboard_overlay.z_index = 60
	add_child(_leaderboard_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.20, 0.25, 0.29, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leaderboard_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(320.0, 54.0)
	panel.size = Vector2(640.0, 612.0)
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
	_leaderboard_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	stack.add_child(heading_row)
	var heading := Label.new()
	heading.text = "纸飞机排行榜"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("#354550"))
	heading_row.add_child(heading)
	var close_button := _make_update_button("关闭", Color("#668b8c"))
	close_button.name = "LeaderboardCloseButton"
	close_button.custom_minimum_size = Vector2(112.0, 44.0)
	close_button.pressed.connect(_close_leaderboard)
	heading_row.add_child(close_button)
	var subtitle := Label.new()
	subtitle.text = "访客身份保存在本机，不跨设备同步；排行榜记录客户端报告的休闲成绩，并非防作弊竞赛榜。"
	subtitle.custom_minimum_size = Vector2(0.0, 42.0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#667b88"))
	stack.add_child(subtitle)
	_leaderboard_status_label = Label.new()
	_leaderboard_status_label.name = "LeaderboardStatus"
	_leaderboard_status_label.text = "正在连接线上榜单……"
	_leaderboard_status_label.custom_minimum_size = Vector2(0.0, 24.0)
	_leaderboard_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leaderboard_status_label.add_theme_font_size_override("font_size", 15)
	_leaderboard_status_label.add_theme_color_override("font_color", Color("#47827f"))
	stack.add_child(_leaderboard_status_label)
	_leaderboard_rank_label = Label.new()
	_leaderboard_rank_label.name = "LeaderboardPersonalRank"
	_leaderboard_rank_label.text = "个人名次读取中……"
	_leaderboard_rank_label.custom_minimum_size = Vector2(0.0, 26.0)
	_leaderboard_rank_label.add_theme_font_size_override("font_size", 17)
	_leaderboard_rank_label.add_theme_color_override("font_color", Color("#d87362"))
	stack.add_child(_leaderboard_rank_label)
	var scroll := ScrollContainer.new()
	scroll.name = "LeaderboardScroll"
	scroll.custom_minimum_size = Vector2(0.0, 330.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_leaderboard_rows = VBoxContainer.new()
	_leaderboard_rows.name = "LeaderboardRows"
	_leaderboard_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_leaderboard_rows)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	_leaderboard_refresh_button = _make_update_button("刷新榜单", Color("#668b8c"))
	_leaderboard_refresh_button.name = "LeaderboardRefreshButton"
	_leaderboard_refresh_button.custom_minimum_size = Vector2(142.0, 44.0)
	_leaderboard_refresh_button.pressed.connect(_refresh_leaderboard)
	actions.add_child(_leaderboard_refresh_button)
	_leaderboard_new_guest_button = _make_update_button("新建访客", Color("#9b8060"))
	_leaderboard_new_guest_button.name = "LeaderboardNewGuestButton"
	_leaderboard_new_guest_button.custom_minimum_size = Vector2(150.0, 44.0)
	_leaderboard_new_guest_button.visible = false
	_leaderboard_new_guest_button.tooltip_text = "过期访客的个人身份无法找回；已提交的旧分数仍留在公开榜单。"
	_leaderboard_new_guest_button.pressed.connect(_create_new_guest)
	actions.add_child(_leaderboard_new_guest_button)
	_refresh_leaderboard()


func _refresh_leaderboard(create_new_guest: bool = false) -> void:
	if _leaderboard_loading or not is_instance_valid(_leaderboard_overlay) or not is_instance_valid(_leaderboard_client):
		return
	_leaderboard_loading = true
	_leaderboard_refresh_button.disabled = true
	_leaderboard_new_guest_button.visible = false
	_leaderboard_status_label.text = "正在连接线上榜单……"
	_leaderboard_rank_label.text = "个人名次读取中……"
	for row in _leaderboard_rows.get_children():
		_leaderboard_rows.remove_child(row)
		row.queue_free()
	if create_new_guest:
		_leaderboard_client.forget_guest()
		_leaderboard_guest_expired = false
	var read_only: bool = bool(_leaderboard_client.get("read_only"))
	var guest_issue := ""
	if not read_only:
		if _leaderboard_guest_expired:
			guest_issue = "访客身份已过期"
		else:
			var guest_result: Dictionary = await _leaderboard_client.ensure_guest(_new_guest_display_name())
			if not is_inside_tree() or not is_instance_valid(_leaderboard_overlay):
				return
			if not guest_result.get("ok", false):
				guest_issue = _leaderboard_error_text(guest_result)
				_leaderboard_guest_expired = guest_result.get("error") == "guest_session_expired" or bool(guest_result.get("guestExpired", false))
	var board_result: Dictionary = await _leaderboard_client.read_board(20)
	if not is_inside_tree() or not is_instance_valid(_leaderboard_overlay):
		return
	if bool(board_result.get("guestExpired", false)):
		_leaderboard_guest_expired = true
	_leaderboard_loading = false
	_leaderboard_refresh_button.disabled = false
	if not board_result.get("ok", false):
		var error_code := str(board_result.get("error", ""))
		_leaderboard_guest_expired = _leaderboard_guest_expired or error_code == "guest_session_expired"
		_leaderboard_status_label.text = "排行榜暂时无法读取：%s" % _leaderboard_error_text(board_result)
		if not guest_issue.is_empty():
			_leaderboard_status_label.text += "；访客身份：%s" % guest_issue
		_leaderboard_rank_label.text = "线上失败不会影响离线游戏或本机最佳分。"
		_leaderboard_new_guest_button.visible = _leaderboard_guest_expired and not read_only
		return
	var board_data: Dictionary = board_result.get("data", {})
	var entries: Array = board_data.get("entries", [])
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row := Label.new()
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color("#435b64"))
		row.text = "%02d   %s   ·   %d 道障碍" % [
			int(entry.get("rank", index + 1)),
			str(entry.get("displayName", "纸飞机访客")),
			int(entry.get("score", 0)),
		]
		_leaderboard_rows.add_child(row)
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "榜单暂时还没有成绩，先飞一局吧。"
		empty_label.custom_minimum_size = Vector2(0.0, 42.0)
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color("#667b88"))
		_leaderboard_rows.add_child(empty_label)
	var personal_rank: Variant = board_data.get("myRank", null)
	if personal_rank is Dictionary:
		_leaderboard_rank_label.text = "我的最好：第 %d 名 · %d 道障碍" % [
			int(personal_rank.get("rank", 0)),
			int(personal_rank.get("score", 0)),
		]
	elif read_only:
		_leaderboard_rank_label.text = "历史版本只读；榜单仅供浏览。"
	elif _leaderboard_guest_expired or not guest_issue.is_empty():
		_leaderboard_rank_label.text = "个人名次暂不可用；离线飞行与本机最佳纪录仍可使用。"
	else:
		_leaderboard_rank_label.text = "个人最好：尚未登榜"
	_leaderboard_new_guest_button.visible = _leaderboard_guest_expired and not read_only
	if _leaderboard_guest_expired:
		_leaderboard_status_label.text = "已读取 %d 条公开记录；访客身份已过期，新建访客后可查看新的个人名次。" % entries.size()
	elif not guest_issue.is_empty():
		_leaderboard_status_label.text = "已读取 %d 条公开记录；访客连接暂不可用：%s。" % [entries.size(), guest_issue]
	else:
		_leaderboard_status_label.text = "已读取 %d 条记录 · 在线榜单为客户端报告成绩" % entries.size()


func _create_new_guest() -> void:
	if _leaderboard_loading:
		return
	_refresh_leaderboard(true)


func _close_leaderboard() -> void:
	if is_instance_valid(_leaderboard_overlay):
		_leaderboard_overlay.queue_free()
	_leaderboard_overlay = null
	_leaderboard_status_label = null
	_leaderboard_rank_label = null
	_leaderboard_rows = null
	_leaderboard_refresh_button = null
	_leaderboard_new_guest_button = null
	_leaderboard_loading = false
	if is_instance_valid(_leaderboard_button):
		_leaderboard_button.grab_focus()


func _leaderboard_error_text(result: Dictionary) -> String:
	var error_code := str(result.get("error", "online_leaderboard_unavailable"))
	match error_code:
		"online_leaderboard_not_configured":
			return "此平台尚未连接线上榜单服务；网页托管版本部署后可用。"
		"online_leaderboard_unavailable":
			return "网络或线上服务暂不可用，请稍后刷新。"
		"guest_session_expired":
			return "本机访客身份已过期；旧成绩仍在榜，但无法找回该身份。"
		"leaderboard_read_only":
			return "当前版本为只读预览，无法创建访客或提交成绩。"
		"client_upgrade_required":
			return "排行榜规则已更新，请刷新游戏版本后再试。"
		_:
			return "线上服务返回：%s" % error_code


func _new_guest_display_name() -> String:
	return "纸飞机-%04d" % (randi() % 10000)


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
