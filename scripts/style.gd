extends RefCounted
## STYLE rank (D-C-B-A-S) + FURY meter.
## Varied kills fill the style gauge; repeating the same method gives less.
## The gauge drains over time and a hit drops you a rank. Rank multiplies
## score. FURY fills with style and is spent for golden overdrive.

signal rank_changed(rank: int, up: bool)
signal fury_ready()

const RANKS := ["D", "C", "B", "A", "S"]
const NAMES := ["DULL", "COOL", "BRUTAL", "AWESOME", "STYLISH!"]
const MULT := [1.0, 1.5, 2.0, 2.5, 3.0]
const WEIGHT := {
	"bullet": 0.8, "melee": 1.3, "explosion": 1.25, "thrown": 1.6, "shield": 1.4,
	"strike": 1.8, "kick": 1.4, "stomp": 1.5, "fall": 1.2, "mg": 0.7, "fury": 1.0,
}

var rank := 0
var gauge := 0.0          # 0..100 within the current rank
var fury := 0.0           # 0..100
var fury_active := false
var fury_t := 0.0
var fury_len := 8.0
var recent: Array = []    # last few kill methods
var peak_rank := 0
var _ready_sent := false
var _decay := 1.0


func setup() -> void:
	fury_len = GS.tuning("fury_duration", 8.0)
	_decay = GS.tuning("style_decay", 1.0)


func mult() -> float:
	return MULT[rank]


func letter() -> String:
	return RANKS[rank]


func rank_name() -> String:
	return NAMES[rank]


func add_kill(how: String, airborne: bool = false) -> void:
	var w: float = WEIGHT.get(how, 1.0)
	var reps := recent.count(how)
	w /= 1.0 + 0.45 * reps
	if airborne:
		w *= 1.35
	recent.append(how)
	if recent.size() > 5:
		recent.pop_front()
	_add(24.0 * w)
	if not fury_active:
		fury = minf(100.0, fury + 7.5 * w * (1.0 + rank * 0.15))
		if fury >= 100.0 and not _ready_sent:
			_ready_sent = true
			fury_ready.emit()


## Small style gains: stylish non-kill actions (grapple latch, big combo hits).
func add_bonus(amount: float) -> void:
	_add(amount)
	if not fury_active:
		fury = minf(100.0, fury + amount * 0.25)
		if fury >= 100.0 and not _ready_sent:
			_ready_sent = true
			fury_ready.emit()


func _add(amount: float) -> void:
	gauge += amount
	while gauge >= 100.0:
		if rank < RANKS.size() - 1:
			gauge -= 100.0
			rank += 1
			peak_rank = maxi(peak_rank, rank)
			rank_changed.emit(rank, true)
		else:
			gauge = 100.0
			break


func on_player_hit() -> void:
	if rank > 0:
		rank -= 1
		gauge = 45.0
		rank_changed.emit(rank, false)
	else:
		gauge = maxf(0.0, gauge - 40.0)


func can_fury() -> bool:
	return fury >= 100.0 and not fury_active


func start_fury() -> bool:
	if not can_fury():
		return false
	fury_active = true
	fury_t = fury_len
	_ready_sent = false
	return true


## Returns true on the frame FURY ends.
func update(delta: float, in_combat: bool) -> bool:
	var ended := false
	if fury_active:
		fury_t -= delta
		fury = maxf(0.0, 100.0 * fury_t / fury_len)
		if fury_t <= 0.0:
			fury_active = false
			fury = 0.0
			ended = true
	var drain := (4.0 + rank * 3.5) * _decay * (1.0 if in_combat else 0.35)
	if fury_active:
		drain *= 0.2
	gauge -= drain * delta
	if gauge < 0.0:
		if rank > 0:
			rank -= 1
			gauge = 75.0
			rank_changed.emit(rank, false)
		else:
			gauge = 0.0
	return ended
