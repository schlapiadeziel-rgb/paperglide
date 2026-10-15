extends Node
## Staggered asset streaming (autoload "Segments").
##
## The boot PCK only carries what the title screen and Stage 1 need. Stage
## media listed in segment_manifest.gd is excluded from the PCK and shipped as
## loose files beside index.html (web/export.json). On the Web this node
## downloads them in order with HTTPRequest and decodes one file per frame
## into ImageTexture / AudioStreamOggVorbis. Native and editor runs read the
## same files straight from res://.
##
## Background work is throttled: nothing new is fetched or decoded while the
## game reports it is "busy" (many enemies/particles, boss fight, slow frames)
## unless a stage gate is waiting on the segment (force mode).

signal segment_ready(id: String)
signal progress_changed(id: String, fraction: float)

const MANIFEST := preload("res://scripts/segment_manifest.gd")
const BgmPlayer := preload("res://scripts/manus/browser_bgm_player.gd")
const MAX_RETRIES := 4

var web := OS.has_feature("web")
var _res: Dictionary = {}          # res path -> Resource
var _streamed: Dictionary = {}     # res path -> segment id
var _ready_ids: Dictionary = {}    # segment id -> true
var _queue: Array = []             # pending rows [seg, res, flat, bytes]
var _decode: Array = []            # downloaded rows awaiting decode [row, bytes]
var _prewarm: Array = []           # music resources to pre-decode for browser audio
var _http: HTTPRequest
var _inflight: Array = []
var _retries := 0
var _retry_wait := 0.0
var _bytes_done: Dictionary = {}
var _bytes_total: Dictionary = {}
var _force: Dictionary = {}        # segment id -> true while a gate waits
var _frame_ms_avg := 16.0
var paused_reason := ""            # for HUD/debug
var failed := ""                   # segment that exhausted retries
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for seg in MANIFEST.ORDER:
		_bytes_total[seg] = 0
		_bytes_done[seg] = 0
		for row in MANIFEST.FILES[seg]:
			_streamed[row[0]] = seg
			_bytes_total[seg] += int(row[2])
			_queue.append([seg, row[0], row[1], int(row[2])])
	_http = HTTPRequest.new()
	_http.name = "SegmentHTTP"
	_http.use_threads = true
	_http.timeout = 60.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Begin background streaming (called by the title screen once it is visible).
func start() -> void:
	started = true


func is_streamed(path: String) -> bool:
	return _streamed.has(path)


func is_ready(seg: String) -> bool:
	return _ready_ids.has(seg)


## Resource for a streamed path, or null if it hasn't arrived yet.
## Non-streamed paths fall through to a normal load.
func get_res(path: String) -> Resource:
	if _res.has(path):
		return _res[path]
	if _streamed.has(path):
		if not web and ResourceLoader.exists(path):
			var r := load(path)
			_res[path] = r
			return r
		return null
	return load(path) if ResourceLoader.exists(path) else null


func progress(seg: String) -> float:
	if is_ready(seg):
		return 1.0
	var total := float(_bytes_total.get(seg, 0))
	return clampf(float(_bytes_done.get(seg, 0)) / maxf(total, 1.0), 0.0, 0.99)


## A stage gate is waiting: ignore the busy throttle for this segment (and
## every segment before it).
func require(seg: String) -> void:
	started = true
	_force[seg] = true
	if failed != "":
		failed = ""
		_retries = 0
		_retry_wait = 0.0


func _forced_for(seg: String) -> bool:
	var idx: int = MANIFEST.ORDER.find(seg)
	for s in _force:
		if MANIFEST.ORDER.find(s) >= idx:
			return true
	return false


## Heat check: the game exposes load_pressure() (0 = calm, >=1 = busy).
func _busy() -> bool:
	if _frame_ms_avg > 24.0:
		paused_reason = "frame time"
		return true
	var g = GS.game
	if g != null and is_instance_valid(g) and g.has_method("load_pressure"):
		if float(g.load_pressure()) >= 1.0:
			paused_reason = "combat"
			return true
	paused_reason = ""
	return false


func _process(delta: float) -> void:
	_frame_ms_avg = lerpf(_frame_ms_avg, delta * 1000.0 / maxf(Engine.time_scale, 0.05), 0.08)
	if not started:
		return
	# 1) decode at most one downloaded file per frame
	if not _decode.is_empty():
		var seg: String = _decode[0][0][0]
		if _forced_for(seg) or not _busy():
			var item: Array = _decode.pop_front()
			_decode_row(item[0], item[1])
			_check_ready()
			return
	# 2) pre-decode music into the browser audio cache when calm
	if not _prewarm.is_empty() and not _busy():
		var stream: AudioStream = _prewarm.pop_front()
		_prewarm_music(stream)
		return
	# 3) start the next download
	if _inflight.is_empty() and not _queue.is_empty():
		if _retry_wait > 0.0:
			_retry_wait -= delta
			return
		if failed != "":
			return
		var row: Array = _queue[0]
		if not _forced_for(row[0]) and _busy():
			return
		_queue.pop_front()
		if web:
			_fetch(row)
		else:
			_decode.append([row, PackedByteArray()])


func _fetch(row: Array) -> void:
	var url := str(JavaScriptBridge.eval("new URL(%s, document.baseURI).href" % JSON.stringify(row[2]), true))
	_inflight = row
	var err := _http.request(url)
	if err != OK:
		_fail(row)


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var row: Array = _inflight
	_inflight = []
	if row.is_empty():
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.is_empty():
		_fail(row)
		return
	_retries = 0
	_decode.append([row, body])


func _fail(row: Array) -> void:
	_inflight = []
	_retries += 1
	_queue.push_front(row)
	if _retries > MAX_RETRIES:
		failed = row[0]
		push_warning("Segments: giving up on %s after %d tries" % [row[2], _retries])
	else:
		_retry_wait = 0.6 * _retries


func _decode_row(row: Array, bytes: PackedByteArray) -> void:
	var path: String = row[1]
	var res: Resource = null
	if not web:
		res = load(path) if ResourceLoader.exists(path) else null
	elif path.ends_with(".webp"):
		var img := Image.new()
		if img.load_webp_from_buffer(bytes) == OK:
			var tex := ImageTexture.create_from_image(img)
			tex.resource_path = path
			res = tex
	elif path.ends_with(".ogg"):
		var ogg := AudioStreamOggVorbis.load_from_buffer(bytes)
		if ogg != null:
			ogg.loop = true
			ogg.resource_path = path
			res = ogg
			if web:
				_prewarm.append(ogg)
	if res == null:
		push_warning("Segments: failed to decode " + path)
	else:
		_res[path] = res
	_bytes_done[row[0]] = int(_bytes_done[row[0]]) + int(row[3])
	progress_changed.emit(row[0], progress(row[0]))


func _check_ready() -> void:
	for seg in MANIFEST.ORDER:
		if _ready_ids.has(seg):
			continue
		var pending := false
		for q in _queue:
			if q[0] == seg:
				pending = true
				break
		if not pending:
			for d in _decode:
				if d[0][0] == seg:
					pending = true
					break
		if not pending and not _inflight.is_empty() and _inflight[0] == seg:
			pending = true
		if pending:
			return
		_ready_ids[seg] = true
		_force.erase(seg)
		segment_ready.emit(seg)


## The browser music backend decodes a whole track the first time it plays;
## doing that now (while calm) keeps later music switches hitch-free.
func _prewarm_music(stream: AudioStream) -> void:
	var p := BgmPlayer.new()
	p.stream = stream
	p.buffer_key = stream.resource_path
	add_child(p)
	if p.has_method("prepare"):
		p.prepare()
	p.queue_free()
