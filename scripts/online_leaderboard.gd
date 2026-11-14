class_name OnlineLeaderboard
extends Node
## Optional HTTP adapter. Keep the game's offline score store and UI independent.
## Scores are client-reported, not verified competitive records.

@export var board_id: String = "paper-flight-score-v1"
@export var rules_version: String = "v1"
@export var read_only: bool = false
# For native exports only: configure a trusted HTTPS game origin, never a database URL.
@export var native_game_origin: String = ""
var _token: String = ""
var _api_root: String = ""
var _identity_file: String = ""
var _guest_expired := false
var _upgrade_required := false

func _ready() -> void:
	_api_root = _derive_api_root()
	if OS.has_feature("web"):
		read_only = read_only or bool(JavaScriptBridge.eval("window.__MANUS_GAME_HISTORY__?.readOnly === true", true))
	if not read_only and not _api_root.is_empty():
		# API-root-specific storage avoids sharing a test guest identity with production.
		_identity_file = "user://leaderboard_%s.cfg" % _api_root.sha256_text().substr(0, 16)
		_load_identity()


func _load_identity() -> void:
	var saved := ConfigFile.new()
	if saved.load(_identity_file) == OK:
		_token = str(saved.get_value("guest", "token", ""))
		_guest_expired = bool(saved.get_value("guest", "expired", false))
		if _guest_expired:
			_token = ""

func _derive_api_root() -> String:
	if OS.has_feature("web"):
		var history_root := str(JavaScriptBridge.eval("window.__MANUS_GAME_HISTORY__?.apiRoot || ''", true))
		if history_root == "https://game-history.invalid/api/leaderboards/v1":
			return history_root
		var origin := str(JavaScriptBridge.eval("window.location.origin", true))
		var path := str(JavaScriptBridge.eval("window.location.pathname", true))
		# Managed preview URLs may have an ingress prefix before /__manus__/game-preview/.
		var preview_marker := path.find("/__manus__/game-preview/")
		if preview_marker >= 0:
			return origin + path.substr(0, preview_marker) + "/api/leaderboards/v1"
		return origin + "/api/leaderboards/v1"
	if native_game_origin.begins_with("https://"):
		return native_game_origin.trim_suffix("/") + "/api/leaderboards/v1"
	return ""

func ensure_guest(display_name: String) -> Dictionary:
	if read_only:
		return {"ok": false, "error": "leaderboard_read_only"}
	if _guest_expired:
		return {"ok": false, "status": 410, "error": "guest_session_expired"}
	if not _token.is_empty():
		return {"ok": true}
	var result := await _request("/guests", HTTPClient.METHOD_POST, {"displayName": display_name})
	if result.get("ok", false):
		_token = str(result.get("data", {}).get("token", ""))
		var saved := ConfigFile.new()
		saved.set_value("guest", "token", _token)
		if saved.save(_identity_file) != OK:
			result["identity_persistent"] = false
	return result

func read_board(limit: int = 20) -> Dictionary:
	var path := "/boards/%s?limit=%d" % [board_id.uri_encode(), clampi(limit, 1, 100)]
	var result: Dictionary = await _request(path, HTTPClient.METHOD_GET)
	if not result.get("ok", false) and int(result.get("status", 0)) == 401 and result.get("error") == "guest_session_expired":
		# The public board remains readable without a guest token; retry this GET only.
		result = await _request(path, HTTPClient.METHOD_GET)
	if _guest_expired:
		result["guestExpired"] = true
	return result

func begin_run(release_sha: String = "") -> Dictionary:
	if read_only:
		return {"ok": false, "error": "leaderboard_read_only"}
	if _token.is_empty():
		return {"ok": false, "error": "guest_session_required"}
	var payload := {"protocolVersion": 1, "rulesVersion": rules_version}
	if not release_sha.is_empty():
		payload["releaseSha"] = release_sha
	return await _request("/boards/%s/runs" % board_id.uri_encode(), HTTPClient.METHOD_POST, payload)

func submit_run(run_id: String, score: int, duration_ms: int) -> Dictionary:
	if read_only:
		return {"ok": false, "error": "leaderboard_read_only"}
	# Preserve run_id, score and duration_ms on timeout/retry. Never create a fresh run to retry a submission.
	return await _request("/runs/%s" % run_id.uri_encode(), HTTPClient.METHOD_PUT, {"score": score, "durationMs": duration_ms})

func forget_guest() -> void:
	_token = ""
	_guest_expired = false
	if FileAccess.file_exists(_identity_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_identity_file))


func _mark_guest_expired() -> void:
	_token = ""
	_guest_expired = true
	var saved := ConfigFile.new()
	saved.set_value("guest", "expired", true)
	saved.save(_identity_file)

func _request(path: String, method: HTTPClient.Method, payload: Dictionary = {}) -> Dictionary:
	# An incompatible loaded client must not keep creating or submitting ranked runs.
	if _upgrade_required and method != HTTPClient.METHOD_GET:
		return {"ok": false, "status": 426, "error": "client_upgrade_required"}
	if _api_root.is_empty():
		return {"ok": false, "error": "online_leaderboard_not_configured"}
	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)
	var headers := PackedStringArray(["Accept: application/json"])
	if not _token.is_empty():
		headers.append("Authorization: Bearer " + _token)
		headers.append("X-Guest-Token: " + _token)
	var encoded := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		encoded = JSON.stringify(payload)
	var start_error := request.request(_api_root + path, headers, method, encoded)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "online_leaderboard_unavailable"}
	var reply: Array = await request.request_completed
	request.queue_free()
	if reply[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "online_leaderboard_unavailable"}
	var status: int = reply[1]
	var parsed: Variant = JSON.parse_string(reply[3].get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "error": "invalid_server_response"}
	if status == 401 and not _token.is_empty():
		if parsed.get("error") == "guest_session_expired":
			_mark_guest_expired()
		else:
			forget_guest()
	if status == 426 and parsed.get("error") == "client_upgrade_required":
		_upgrade_required = true
	if status < 200 or status >= 300:
		return {"ok": false, "status": status, "error": parsed.get("error", "online_leaderboard_unavailable")}
	return {"ok": true, "data": parsed}
