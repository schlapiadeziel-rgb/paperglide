extends Node
## Small player-facing preferences shared by the title screen and flight scene.

const SETTINGS_PATH := "user://paper_flight_settings.cfg"
const DIFFICULTIES: Array[Dictionary] = [
	{"name": "轻松", "gap_height": 278.0, "base_speed": 250.0, "base_interval": 1.90, "min_interval": 1.52},
	{"name": "标准", "gap_height": 244.0, "base_speed": 285.0, "base_interval": 1.75, "min_interval": 1.39},
	{"name": "挑战", "gap_height": 214.0, "base_speed": 315.0, "base_interval": 1.58, "min_interval": 1.28},
]
const PLANE_SKIN_NAMES: Array[String] = ["原纸色", "樱花粉", "柠檬黄", "薄荷绿", "晴空蓝", "薰衣草紫"]
const PLANE_SKIN_COLORS: Array[Color] = [
	Color("#fffaf0"), Color("#ffe2dc"), Color("#fff0c8"),
	Color("#def2e7"), Color("#deebff"), Color("#eee2fb"),
]
const TRAIL_STYLE_NAMES: Array[String] = ["关闭", "铅笔虚线", "星星尾迹", "彩色纸屑"]
const PAGE_THEME_NAMES: Array[String] = ["横线页", "方格页", "点阵页"]

var difficulty_index := 1
var plane_skin_index := 0
var star_shield_enabled := true
var trail_style_index := 1
var page_theme_index := 0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_difficulty: Variant = config.get_value("preferences", "difficulty", difficulty_index)
	if saved_difficulty is int:
		difficulty_index = clampi(saved_difficulty, 0, DIFFICULTIES.size() - 1)
	var saved_skin: Variant = config.get_value("preferences", "plane_skin", plane_skin_index)
	if saved_skin is int:
		plane_skin_index = clampi(saved_skin, 0, PLANE_SKIN_NAMES.size() - 1)
	var saved_shield: Variant = config.get_value("preferences", "star_shield", star_shield_enabled)
	if saved_shield is bool:
		star_shield_enabled = saved_shield
	var saved_trail: Variant = config.get_value("preferences", "trail_style", trail_style_index)
	if saved_trail is int:
		trail_style_index = clampi(saved_trail, 0, TRAIL_STYLE_NAMES.size() - 1)
	var saved_theme: Variant = config.get_value("preferences", "page_theme", page_theme_index)
	if saved_theme is int:
		page_theme_index = clampi(saved_theme, 0, PAGE_THEME_NAMES.size() - 1)


func get_difficulty_index() -> int:
	return difficulty_index


func get_difficulty_name() -> String:
	return String(DIFFICULTIES[difficulty_index]["name"])


func get_difficulty_profile() -> Dictionary:
	return DIFFICULTIES[difficulty_index].duplicate()


func set_difficulty_index(value: int) -> void:
	var next_value := clampi(value, 0, DIFFICULTIES.size() - 1)
	if next_value == difficulty_index:
		return
	difficulty_index = next_value
	_save()


func get_plane_skin_index() -> int:
	return plane_skin_index


func get_plane_skin_name() -> String:
	return PLANE_SKIN_NAMES[plane_skin_index]


func get_plane_skin_color() -> Color:
	return PLANE_SKIN_COLORS[plane_skin_index]


func set_plane_skin_index(value: int) -> void:
	var next_value := clampi(value, 0, PLANE_SKIN_NAMES.size() - 1)
	if next_value == plane_skin_index:
		return
	plane_skin_index = next_value
	_save()


func is_star_shield_enabled() -> bool:
	return star_shield_enabled


func set_star_shield_enabled(value: bool) -> void:
	if value == star_shield_enabled:
		return
	star_shield_enabled = value
	_save()


func get_trail_style_index() -> int:
	return trail_style_index


func set_trail_style_index(value: int) -> void:
	var next_value := clampi(value, 0, TRAIL_STYLE_NAMES.size() - 1)
	if next_value == trail_style_index:
		return
	trail_style_index = next_value
	_save()


func get_page_theme_index() -> int:
	return page_theme_index


func set_page_theme_index(value: int) -> void:
	var next_value := clampi(value, 0, PAGE_THEME_NAMES.size() - 1)
	if next_value == page_theme_index:
		return
	page_theme_index = next_value
	_save()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "difficulty", difficulty_index)
	config.set_value("preferences", "plane_skin", plane_skin_index)
	config.set_value("preferences", "star_shield", star_shield_enabled)
	config.set_value("preferences", "trail_style", trail_style_index)
	config.set_value("preferences", "page_theme", page_theme_index)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Paper Flight could not save player preferences: %s" % error_string(error))
