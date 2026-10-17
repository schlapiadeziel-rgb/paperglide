extends Node
## Android-only, non-blocking checker for newer APK releases on the public project repository.

signal update_available(version: String, release_url: String)
signal check_finished(found_update: bool, version: String, release_url: String)
signal check_failed(message: String)

const RELEASES_API_URL := "https://api.github.com/repos/schlapiadeziel-rgb/paperglide/releases?per_page=10"
const RELEASE_PAGE_PREFIX := "https://github.com/schlapiadeziel-rgb/paperglide/releases/"

var _request: HTTPRequest


func check_for_update() -> void:
	if not OS.has_feature("android") or is_instance_valid(_request):
		return
	_request = HTTPRequest.new()
	_request.timeout = 8.0
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	var error := _request.request(RELEASES_API_URL, [
		"Accept: application/vnd.github+json",
		"User-Agent: PaperFlight-Android",
		"X-GitHub-Api-Version: 2022-11-28",
	])
	if error != OK:
		_request.queue_free()
		_request = null
		check_failed.emit("无法连接 GitHub，请稍后重试。")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_request := _request
	_request = null
	if is_instance_valid(completed_request):
		completed_request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_failed.emit("更新检查失败，请检查网络后重试。")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array):
		check_failed.emit("GitHub 返回的版本信息暂不可用。")
		return
	var current_version := str(ProjectSettings.get_setting("application/config/version", "1.1.0"))
	var update := find_newer_release(parsed as Array, current_version)
	if not update.is_empty():
		var newer_version := String(update["version"])
		var release_url := String(update["url"])
		update_available.emit(newer_version, release_url)
		check_finished.emit(true, newer_version, release_url)
	else:
		check_finished.emit(false, current_version, "")


func find_newer_release(releases: Array, current_version: String) -> Dictionary:
	var newest := {}
	for item in releases:
		if not (item is Dictionary):
			continue
		var release: Dictionary = item
		if bool(release.get("draft", false)):
			continue
		var version := _version_core(String(release.get("tag_name", "")))
		if version.is_empty() or not is_version_newer(version, current_version):
			continue
		var assets: Variant = release.get("assets", [])
		if not (assets is Array) or not _contains_apk(assets as Array):
			continue
		var release_url := String(release.get("html_url", ""))
		if not release_url.begins_with(RELEASE_PAGE_PREFIX):
			continue
		if newest.is_empty() or is_version_newer(version, String(newest["version"])):
			newest = {"version": version, "url": release_url}
	return newest


func _contains_apk(assets: Array) -> bool:
	for item in assets:
		if item is Dictionary and String(item.get("name", "")).to_lower().ends_with(".apk"):
			return true
	return false


func is_version_newer(candidate: String, current: String) -> bool:
	var candidate_parts := _version_parts(candidate)
	var current_parts := _version_parts(current)
	if candidate_parts.size() != 3 or current_parts.size() != 3:
		return false
	for index in 3:
		if candidate_parts[index] == current_parts[index]:
			continue
		return candidate_parts[index] > current_parts[index]
	return false


func _version_core(tag: String) -> String:
	var core := tag.trim_prefix("v").split("-")[0]
	return core if _version_parts(core).size() == 3 else ""


func _version_parts(value: String) -> Array[int]:
	var parts := value.trim_prefix("v").split("-")[0].split(".")
	if parts.size() != 3:
		return []
	var numbers: Array[int] = []
	for part in parts:
		if not part.is_valid_int():
			return []
		numbers.append(int(part))
	return numbers
