extends CanvasLayer
## Combat HUD (generated UI kit art), screen-space UI particles, banners,
## stage intro cards, stage tally, streaming loader overlay, pause menu and
## results. Everything is drawn in screen space at 1280x720.

const RANK_COLORS := [Color("#9aa3ad"), Color("#46e0ff"), Color("#7dff8a"), Color("#ffd23f"), Color("#ff5a1f")]

var root: Control
var canvas: Control
var fx_canvas: Control
var pause_panel: Control
var results_panel: Control
var controls_panel: Control
var _results_shown := false

var _tip_queue: Array = []
var _tip := ""
var _tip_t := 0.0
var _banner := ""
var _banner_sub := ""
var _banner_kind := "neutral"
var _banner_t := 0.0
var _banner_len := 0.0
var _toast := ""
var _toast_t := 0.0
var _hp_shown := 100.0
var _hp_trail := 100.0
var _boss_trail := 1.0
var _score_shown := 0.0
var _score_punch := 0.0
var _hurt_flash := 0.0
var _rank_pop := 0.0
var _rank_up := true
var _fury_flash := 0.0
var _fury_ready_t := 0.0
var _slot_bump: Array = [0.0, 0.0, 0.0]
var _weapon_flash := 0.0
var _last_weapon := "pistol"
var _wave_t := 0.0
var _wave_text := ""
var _go_t := 0.0
var _stage_t := 0.0
var _stage_len := 0.0
var _stage_name := ""
var _stage_sub := ""
var _t := 0.0

var _tally: Dictionary = {}
var _tally_t := -1.0
var _tally_ticks := 0
var _loading := false
var _load_frac := 0.0
var _load_failed := false
var _load_name := ""

# UI particles: [pos, vel, life, max_life, size, color, kind, rot]
var _parts: Array = []
enum UP { SPARK, STAR, RING, SHARD, GLOW }


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	root.add_child(canvas)
	_build_pause()
	_build_results()
	fx_canvas = Control.new()
	fx_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_canvas.draw.connect(_draw_parts)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx_canvas.material = add
	root.add_child(fx_canvas)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	_t += real
	var g := GS.game
	if g == null:
		return
	if _tip_t > 0.0:
		_tip_t -= real
	elif not _tip_queue.is_empty():
		_tip = _tip_queue.pop_front()
		_tip_t = 6.5
		GS.sfx(&"tutorial")
	_banner_t = maxf(0.0, _banner_t - real)
	_toast_t = maxf(0.0, _toast_t - real)
	_hurt_flash = maxf(0.0, _hurt_flash - real * 2.5)
	_score_punch = maxf(0.0, _score_punch - real * 4.0)
	_rank_pop = maxf(0.0, _rank_pop - real * 2.2)
	_fury_flash = maxf(0.0, _fury_flash - real * 2.0)
	_weapon_flash = maxf(0.0, _weapon_flash - real * 2.5)
	_wave_t = maxf(0.0, _wave_t - real)
	_go_t = maxf(0.0, _go_t - real)
	_stage_t = maxf(0.0, _stage_t - real)
	for i in 3:
		_slot_bump[i] = maxf(0.0, _slot_bump[i] - real * 4.0)
	var p = g.player
	_hp_shown = move_toward(_hp_shown, p.hp, 160.0 * real)
	if p.hp < _hp_trail:
		_hp_trail = move_toward(_hp_trail, p.hp, 45.0 * real)
	else:
		_hp_trail = p.hp
	_score_shown = move_toward(_score_shown, float(g.score), maxf(400.0, absf(g.score - _score_shown) * 6.0) * real)
	if p.weapon != _last_weapon or (p.state == "nest") != (_last_weapon == "mg"):
		_last_weapon = "mg" if p.state == "nest" else p.weapon
		_weapon_flash = 1.0
		_burst(Vector2(120, 196), 14, GS.C_ORANGE, 260.0, UP.SPARK)
	if g.style.can_fury():
		_fury_ready_t += real
		if fmod(_fury_ready_t, 0.12) < real:
			_emit(Vector2(randf_range(118, 400), 92 + randf_range(-10, 10)), Vector2(randf_range(-30, 30), randf_range(-80, -30)), 0.6, 5.0, Color(1, 0.8, 0.3), UP.STAR)
	if _tally_t >= 0.0:
		_tally_t += real
		var ticks := mini(5, int((_tally_t - 0.4) / 0.45) + 1) if _tally_t > 0.4 else 0
		while _tally_ticks < ticks:
			_tally_ticks += 1
			GS.sfx(&"tally_tick")
			_burst(Vector2(840, 250 + _tally_ticks * 48), 10, GS.C_YELLOW, 220.0, UP.SPARK)
			if _tally_ticks == 5:
				GS.sfx(&"banner_slam")
				_burst(Vector2(640, 540), 30, GS.C_ORANGE, 420.0, UP.SHARD)
	_step_parts(real)
	root.modulate.a = GS.tuning("hud_opacity", 1.0)
	canvas.queue_redraw()
	fx_canvas.queue_redraw()


# ---- public API ---------------------------------------------------------------

func tip(text: String) -> void:
	if _tip_t > 0.0 and _tip_t < 5.0:
		_tip_t = minf(_tip_t, 0.6)
	_tip_queue.append(text)


func banner(title: String, sub: String, time: float, kind: String = "neutral") -> void:
	_banner = title
	_banner_sub = sub
	_banner_t = time
	_banner_len = time
	_banner_kind = kind
	_burst(Vector2(640, 262), 26, GS.C_ORANGE if kind != "alert" else GS.C_RED, 420.0, UP.SHARD)


func toast(text: String) -> void:
	_toast = text
	_toast_t = 2.0
	_burst(Vector2(640, 170), 12, GS.C_CYAN, 260.0, UP.STAR)


func stage_intro(n: String, sub: String, time: float) -> void:
	_stage_name = n
	_stage_sub = sub
	_stage_t = time
	_stage_len = time


func wave_pop(i: int, total: int) -> void:
	_wave_text = "WAVE %d / %d" % [i, total]
	_wave_t = 1.4
	GS.sfx(&"banner_slam")


func go_arrow() -> void:
	_go_t = 3.0


func score_pulse() -> void:
	_score_punch = 1.0
	if randf() < 0.6:
		_burst(Vector2(640 + randf_range(-90, 90), 44), 3, GS.C_YELLOW, 160.0, UP.SPARK)


func rank_pop(_r: int, up: bool) -> void:
	_rank_pop = 1.0
	_rank_up = up
	var c: Color = RANK_COLORS[clampi(_r, 0, 4)]
	if up:
		_burst(_rank_pos(), 26, c, 380.0, UP.STAR)
		_emit(_rank_pos(), Vector2.ZERO, 0.45, 60.0, c, UP.RING)
	else:
		_burst(_rank_pos(), 12, Color(0.6, 0.6, 0.65), 200.0, UP.SHARD)


func fury_ready() -> void:
	_fury_flash = 1.0
	_fury_ready_t = 0.0
	_emit(Vector2(260, 92), Vector2.ZERO, 0.5, 120.0, Color(1, 0.8, 0.3), UP.RING)
	_burst(Vector2(260, 92), 30, Color(1, 0.8, 0.3), 380.0, UP.STAR)


func fury_start() -> void:
	_fury_flash = 1.0
	banner("FURY!", "Golden overdrive - piercing rounds, double fire rate", 1.4, "fury")
	_burst(Vector2(640, 360), 60, Color(1, 0.75, 0.2), 700.0, UP.SPARK)


func fury_end() -> void:
	_burst(Vector2(260, 92), 14, Color(0.7, 0.6, 0.5), 160.0, UP.SHARD)


func hurt() -> void:
	_hurt_flash = 1.0
	_burst(Vector2(64, 60), 10, GS.C_RED, 260.0, UP.SHARD)


func item_used(item: String) -> void:
	var i: int = ["grenade", "medkit", "barrier"].find(item)
	if i >= 0:
		_slot_bump[i] = 1.0
		_burst(_slot_center(i), 14, [GS.C_ORANGE, Color("#7dff8a"), GS.C_CYAN][i], 260.0, UP.SPARK)


func item_flash(kind: String) -> void:
	var i: int = ["grenades", "medkit", "shield"].find(kind)
	if i >= 0:
		_slot_bump[i] = 1.0
		_burst(_slot_center(i), 18, GS.C_YELLOW, 300.0, UP.STAR)
	elif kind in ["medal", "gold"]:
		_burst(Vector2(640, 44), 16, GS.C_YELLOW, 300.0, UP.STAR)


func show_tally(d: Dictionary) -> void:
	_tally = d
	_tally_t = 0.0
	_tally_ticks = 0
	banner("STAGE CLEAR!", str(d.stage.name), 2.0, "win")


func hide_tally() -> void:
	_tally_t = -1.0


func show_loading(n: String, frac: float, failed: bool) -> void:
	_loading = true
	_load_name = n
	_load_frac = frac
	_load_failed = failed


func hide_loading() -> void:
	_loading = false


func results_visible() -> bool:
	return _results_shown


# ---- UI particles -------------------------------------------------------------

func _emit(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: int) -> void:
	if _parts.size() > 420:
		return
	_parts.append([pos, vel, life, life, size, color, kind, randf() * TAU])


func _burst(pos: Vector2, n: int, color: Color, speed: float, kind: int) -> void:
	var k := GS.tuning("particles_density", 1.0)
	for i in maxi(1, int(n * k)):
		var a := randf() * TAU
		var v := Vector2.from_angle(a) * randf_range(0.35, 1.0) * speed
		var sz := randf_range(3.0, 7.0) if kind != UP.SHARD else randf_range(4.0, 9.0)
		_emit(pos, v, randf_range(0.35, 0.8), sz, color.lerp(Color.WHITE, randf() * 0.4), kind)


func _step_parts(dt: float) -> void:
	for p in _parts:
		p[2] -= dt
		p[0] += p[1] * dt
		p[1] *= pow(0.06, dt)
		if p[6] == UP.SHARD:
			p[1].y += 600.0 * dt
		p[7] += dt * 6.0
	_parts = _parts.filter(func(p): return p[2] > 0.0)


func _draw_parts() -> void:
	var c := fx_canvas
	for p in _parts:
		var k: float = p[2] / p[3]
		var col: Color = p[5]
		col.a = k
		var pos: Vector2 = p[0]
		var s: float = p[4]
		match int(p[6]):
			UP.SPARK:
				var v: Vector2 = p[1]
				var tail := v * 0.035
				c.draw_line(pos - tail, pos, col, s * 0.6 * (0.4 + k))
			UP.STAR:
				var r := s * (0.5 + k)
				c.draw_line(pos - Vector2(r * 2.2, 0), pos + Vector2(r * 2.2, 0), col, 2.0)
				c.draw_line(pos - Vector2(0, r * 2.2), pos + Vector2(0, r * 2.2), col, 2.0)
				c.draw_circle(pos, r * 0.6, col)
			UP.RING:
				var rr := s * (1.6 - k)
				c.draw_arc(pos, rr, 0, TAU, 40, col, 4.0 * k + 1.0)
			UP.SHARD:
				c.draw_set_transform(pos, p[7], Vector2.ONE)
				c.draw_rect(Rect2(-s * 0.5, -s * 0.25, s, s * 0.5), col)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			UP.GLOW:
				c.draw_circle(pos, s * (1.0 + (1.0 - k)), Color(col, col.a * 0.4))


# ---- layout helpers -------------------------------------------------------------

func _tex(sheet: String, frame: String) -> Texture2D:
	return SpriteLib.tex(sheet, frame)


## Draw a UI-kit texture at `pos` (top-left) with `scale`; returns its drawn rect.
func _kit(c: CanvasItem, sheet: String, frame: String, pos: Vector2, scale: float, mod: Color = Color.WHITE) -> Rect2:
	var t := _tex(sheet, frame)
	if t == null:
		return Rect2(pos, Vector2.ZERO)
	var r := Rect2(pos, t.get_size() * scale)
	c.draw_texture_rect(t, r, false, mod)
	return r


func _kit_centered(c: CanvasItem, sheet: String, frame: String, center: Vector2, scale: float, mod: Color = Color.WHITE) -> Rect2:
	var t := _tex(sheet, frame)
	if t == null:
		return Rect2(center, Vector2.ZERO)
	var sz := t.get_size() * scale
	var r := Rect2(center - sz * 0.5, sz)
	c.draw_texture_rect(t, r, false, mod)
	return r


func _rank_pos() -> Vector2:
	return Vector2(canvas.size.x - 372.0 if canvas != null and canvas.size.x > 0 else 908.0, 58.0)


func _slot_center(i: int) -> Vector2:
	var W := canvas.size.x if canvas != null and canvas.size.x > 0 else 1280.0
	return Vector2(W - 236.0 + i * 76.0, 50.0)


# ---- drawing -------------------------------------------------------------------

func _draw_hud() -> void:
	var g := GS.game
	if g == null or g.player == null:
		return
	var c := canvas
	var p = g.player
	var W := c.size.x
	var H := c.size.y
	# fallback vignette when post FX are disabled
	if GS.tuning("post_fx", 1.0) < 0.5:
		var low := 1.0 - clampf(p.hp / p.max_hp / 0.3, 0.0, 1.0)
		var vig := maxf(_hurt_flash * 0.5, low * (0.25 + 0.15 * sin(_t * 6.0)))
		if vig > 0.01:
			for i in 6:
				var w := 18.0 + i * 16.0
				var col := Color(0.8, 0.05, 0.02, vig * (0.35 - i * 0.05))
				c.draw_rect(Rect2(0, 0, W, w), col)
				c.draw_rect(Rect2(0, H - w, W, w), col)
				c.draw_rect(Rect2(0, 0, w, H), col)
				c.draw_rect(Rect2(W - w, 0, w, H), col)
	if g.flash_a > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), Color(1, 0.97, 0.9, g.flash_a * 0.5))

	if _tally_t < 0.0 or _tally_t < 0.6:
		_draw_player_block(c, g, p)
		_draw_score_block(c, g, W)
		_draw_style_block(c, g, W)
		_draw_items(c, p, W)
	_draw_boss(c, g, W, H)
	_draw_tip(c, g, W, H)
	_draw_banner(c, W, H)
	_draw_stage_card(c, W, H)
	if _wave_t > 0.0:
		var a := clampf(_wave_t / 0.3, 0.0, 1.0) * clampf((1.4 - _wave_t) / 0.15, 0.0, 1.0)
		var s := 1.0 + 0.4 * clampf((_wave_t - 1.2) / 0.2, 0.0, 1.0)
		c.draw_set_transform(Vector2(W * 0.5, 220), 0.0, Vector2(s, s))
		UIKit.centered(c, UIKit.DISPLAY, 0, 0, _wave_text, 34, Color(UIKit.ORANGE, a), 7)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _toast_t > 0.0:
		var a3 := clampf(_toast_t / 0.3, 0.0, 1.0)
		var pop := 1.0 + 0.3 * clampf((_toast_t - 1.8) / 0.2, 0.0, 1.0)
		c.draw_set_transform(Vector2(W * 0.5, 170), 0.0, Vector2(pop, pop))
		UIKit.centered(c, UIKit.DISPLAY, 0, 0, _toast, 32, Color(UIKit.CYAN, a3), 7)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _go_t > 0.0 and int(_t * 3.0) % 2 == 0:
		var gx := W - 170.0
		var gy := H * 0.45
		var bob := sin(_t * 10.0) * 8.0
		UIKit.text(c, UIKit.DISPLAY, Vector2(gx - 20 + bob, gy + 16), "GO", 52, UIKit.YELLOW, 9)
		c.draw_colored_polygon(PackedVector2Array([Vector2(gx + 66 + bob, gy - 26), Vector2(gx + 112 + bob, gy), Vector2(gx + 66 + bob, gy + 26)]), UIKit.INK)
		c.draw_colored_polygon(PackedVector2Array([Vector2(gx + 71 + bob, gy - 17), Vector2(gx + 103 + bob, gy), Vector2(gx + 71 + bob, gy + 17)]), UIKit.YELLOW)
	if _tally_t >= 0.0:
		_draw_tally(c, W, H)
	if _loading:
		_draw_loading(c, W, H)


func _draw_player_block(c: Control, g: Node, p: Node) -> void:
	# portrait (shakes when hurt, golden in FURY)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _hurt_flash
	var pf := "fury" if g.style.fury_active else ("hurt" if _hurt_flash > 0.2 or p.hp / p.max_hp < 0.3 else "normal")
	var pscale := 0.52 if pf != "fury" else 0.46
	_kit(c, "ui_portrait", pf, Vector2(10, 8) + shake, pscale)
	# health bar
	var bx := 104.0
	var bs := 0.52
	var br := _kit(c, "ui_bar", "health", Vector2(bx, 14), bs)
	var inner := Rect2(br.position + Vector2(66, 13) * bs, Vector2(541, 33) * bs)
	var frac := clampf(_hp_shown / p.max_hp, 0.0, 1.0)
	var trail := clampf(_hp_trail / p.max_hp, 0.0, 1.0)
	var realf := clampf(p.hp / p.max_hp, 0.0, 1.0)
	var hc := Color("#5fe36a") if realf > 0.5 else (UIKit.YELLOW if realf > 0.25 else UIKit.RED)
	if realf <= 0.25 and int(_t * 6.0) % 2 == 0:
		hc = hc.lerp(Color.WHITE, 0.35)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)), Color(1, 0.9, 0.8, 0.85))
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y)), hc)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y * 0.3)), Color(1, 1, 1, 0.3))
	for s in range(1, 10):
		var sx := inner.position.x + inner.size.x * s / 10.0
		c.draw_line(Vector2(sx, inner.position.y), Vector2(sx, inner.end.y), Color(0, 0, 0, 0.35), 2.0)
	UIKit.text(c, UIKit.BOLD, Vector2(br.end.x + 6, br.position.y + 26), "%d" % ceili(p.hp), 18, UIKit.CREAM, 4)
	# FURY bar
	var fs := 0.48
	var fr := _kit(c, "ui_bar", "fury", Vector2(bx + 4, 46), fs)
	var fin := Rect2(fr.position + Vector2(77, 18) * fs, Vector2(517, 41) * fs)
	var fk: float = g.style.fury / 100.0
	var fcol := Color(1.0, 0.55, 0.1).lerp(Color(1.0, 0.85, 0.25), fk)
	if g.style.fury_active:
		fcol = Color(1.0, 0.85, 0.3).lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 18.0))
	c.draw_rect(Rect2(fin.position, Vector2(fin.size.x * fk, fin.size.y)), fcol)
	# moving shimmer
	if fk > 0.02:
		var sx2 := fin.position.x + fmod(_t * 220.0, maxf(fin.size.x * fk, 1.0))
		c.draw_rect(Rect2(sx2, fin.position.y, 10, fin.size.y), Color(1, 1, 1, 0.35))
	if g.style.can_fury():
		var pulse := 0.5 + 0.5 * sin(_t * 10.0)
		c.draw_rect(fin.grow(3.0 + pulse * 3.0), Color(1, 0.8, 0.3, 0.25 + 0.25 * pulse), false, 3.0)
		UIKit.text(c, UIKit.DISPLAY, Vector2(fr.end.x + 4, fr.position.y + 28), "[F] FURY!", 18, UIKit.YELLOW.lerp(Color.WHITE, pulse * 0.5), 5)
	elif g.style.fury_active:
		UIKit.text(c, UIKit.DISPLAY, Vector2(fr.end.x + 4, fr.position.y + 28), "%.1f" % g.style.fury_t, 18, UIKit.YELLOW, 5)
	else:
		UIKit.text(c, UIKit.BOLD, Vector2(fr.end.x + 4, fr.position.y + 26), "FURY", 14, Color(1, 0.8, 0.5, 0.8), 4)
	# lives
	for i in maxi(g.lives, 0):
		_draw_life(c, Vector2(26 + i * 24, 108))
	# weapon plate
	var ws := 0.6
	var wf := 1.0 + _weapon_flash * 0.12
	var wr := _kit(c, "ui_plate", "weapon", Vector2(bx, 126) - Vector2(4, 4) * _weapon_flash, ws * wf)
	var wname: String = "mg" if p.state == "nest" else p.weapon
	var it := _tex("ui_weapon", wname)
	if it != null:
		var box := Rect2(wr.position + Vector2(10, 10) * ws * wf, Vector2(85, 80) * ws * wf)
		var isz := it.get_size()
		var k2: float = minf(box.size.x / isz.x, box.size.y / isz.y) * 1.25
		var dst := Rect2(box.get_center() - isz * k2 * 0.5, isz * k2)
		c.draw_texture_rect(it, dst, false, Color(1, 1, 1).lerp(Color(1, 0.9, 0.5), _weapon_flash))
	var ammo_s := "INF" if (p.weapon == "pistol" or g.style.fury_active) and p.state != "nest" else ("%d" % p.ammo)
	if p.state == "nest":
		ammo_s = "MG"
	var dig := Rect2(wr.position + Vector2(100, 13) * ws * wf, Vector2(147, 59) * ws * wf)
	UIKit.text(c, UIKit.DISPLAY, Vector2(dig.position.x + 4, dig.end.y - 6), ammo_s, 24, UIKit.CREAM if ammo_s != "INF" else UIKit.YELLOW, 5)
	var wl: String = "HEAVY MG NEST" if p.state == "nest" else p.weapon_label()
	UIKit.text(c, UIKit.BOLD, Vector2(wr.end.x + 8, wr.position.y + 36), wl, 16, UIKit.ORANGE, 4)
	if p.barrier_t > 0.0:
		UIKit.text(c, UIKit.BOLD, Vector2(wr.end.x + 8, wr.position.y + 56), "BARRIER %.1fs" % p.barrier_t, 15, UIKit.CYAN, 4)


func _draw_score_block(c: Control, g: Node, W: float) -> void:
	var punch := 1.0 + _score_punch * 0.12
	var sr := _kit_centered(c, "ui_plate", "score", Vector2(W * 0.5, 44), 0.86 * punch)
	var sc := "%07d" % int(_score_shown)
	var inner := Rect2(sr.position + Vector2(76, 10) * 0.86 * punch, Vector2(190, 55) * 0.86 * punch)
	c.draw_set_transform(inner.get_center() + Vector2(0, 13), 0.0, Vector2(punch, punch))
	UIKit.centered(c, UIKit.DISPLAY, 0, 0, sc, 32, UIKit.CREAM.lerp(UIKit.YELLOW, _score_punch), 6)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UIKit.centered(c, UIKit.BOLD, W * 0.5, 96, "HI %07d" % maxi(g.best_score, g.score), 14, Color(1, 0.85, 0.5, 0.85), 4)
	# stage progress: three segments
	var pr := Rect2(W * 0.5 - 150, 106, 300, 6)
	var stages: Array = g.level.stages
	var end_x := float(g.level.end_x)
	c.draw_rect(pr.grow(2.0), Color(0, 0, 0, 0.55))
	for i in stages.size():
		var st: Dictionary = stages[i]
		var x0 := pr.position.x + pr.size.x * clampf(float(st.x0) / end_x, 0.0, 1.0)
		var x1 := pr.position.x + pr.size.x * clampf(float(st.x1) / end_x, 0.0, 1.0)
		var done: bool = i < g.stage_i
		var cur: bool = i == g.stage_i
		var col := UIKit.ORANGE if done else (Color(1, 0.8, 0.4, 0.55) if cur else Color(1, 1, 1, 0.15))
		c.draw_rect(Rect2(x0 + 1, pr.position.y, x1 - x0 - 2, pr.size.y), col)
		UIKit.centered(c, UIKit.BOLD, (x0 + x1) * 0.5, pr.end.y + 16, str(i + 1), 12, UIKit.CREAM if cur else Color(1, 1, 1, 0.5), 3)
	var prog := clampf(g.player.global_position.x / end_x, 0.0, 1.0)
	c.draw_circle(Vector2(pr.position.x + pr.size.x * prog, pr.get_center().y), 6.0, UIKit.INK)
	c.draw_circle(Vector2(pr.position.x + pr.size.x * prog, pr.get_center().y), 4.5, UIKit.YELLOW)
	c.draw_rect(Rect2(pr.end.x - 3, pr.position.y - 4, 6, 14), UIKit.RED)
	# combo
	if g.combo >= 2:
		var pulse := 1.0 + 0.08 * sin(_t * 14.0)
		c.draw_set_transform(Vector2(W * 0.5, 146), 0.0, Vector2(pulse, pulse))
		UIKit.centered(c, UIKit.DISPLAY, 0, 0, "%d HIT COMBO" % g.combo, 22, UIKit.ORANGE if g.combo < 10 else UIKit.RED, 5)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var cw := 160.0 * clampf(g.combo_t / 3.0, 0.0, 1.0)
		c.draw_rect(Rect2(W * 0.5 - 80, 154, 160, 4), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(W * 0.5 - 80, 154, cw, 4), UIKit.YELLOW)


func _draw_style_block(c: Control, g: Node, _W: float) -> void:
	var st = g.style
	var rp := _rank_pos()
	var pop := 1.0 + _rank_pop * (0.45 if _rank_up else -0.15)
	var wob := sin(_t * 30.0) * 0.12 * _rank_pop if _rank_up else randf_range(-1, 1) * 0.08 * _rank_pop
	var rc: Color = RANK_COLORS[st.rank]
	var t := _tex("ui_rank", st.letter())
	if t != null:
		var sz := t.get_size() * 0.42 * pop
		c.draw_set_transform(rp, wob, Vector2.ONE)
		c.draw_texture_rect(t, Rect2(-sz * 0.5, sz), false)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# style gauge under the emblem
	var gr := Rect2(rp.x - 44, rp.y + 46, 88, 7)
	c.draw_rect(gr.grow(2.0), UIKit.INK)
	c.draw_rect(Rect2(gr.position, Vector2(gr.size.x * clampf(st.gauge / 100.0, 0.0, 1.0), gr.size.y)), rc)
	UIKit.centered(c, UIKit.DISPLAY, rp.x, rp.y + 74, st.rank_name(), 16, rc, 4)
	UIKit.centered(c, UIKit.BOLD, rp.x, rp.y + 92, "SCORE x%s" % str(st.mult()), 13, UIKit.CREAM, 3)


func _draw_items(c: Control, p: Node, _W: float) -> void:
	var icons := ["grenades", "medkit", "shield"]
	var labels := ["GRENADE", "MEDKIT", "BARRIER"]
	for i in 3:
		var cen := _slot_center(i)
		var sel: bool = p.item_sel == i
		var bump: float = 1.0 + _slot_bump[i] * 0.25
		if sel:
			_kit_centered(c, "ui_plate", "slot_hi", cen, 0.5 * bump)
		else:
			_kit_centered(c, "ui_plate", "slot", cen, 0.5 * bump, Color(1, 1, 1, 0.9))
		var cnt: int = p.item_count(i)
		SpriteLib.draw(c, "items", icons[i], cen + Vector2(0, 2), false, 0.5 * bump, Color(1, 1, 1, 1.0 if cnt > 0 else 0.35))
		UIKit.text(c, UIKit.BOLD, cen + Vector2(10, 30), "%d" % cnt, 18, UIKit.CREAM if cnt > 0 else Color(1, 0.5, 0.4), 4)
		if sel:
			UIKit.centered(c, UIKit.BOLD, cen.x, cen.y + 54, labels[i], 12, UIKit.YELLOW, 4)
	var kx := _slot_center(0).x - 30.0
	UIKit.key(c, Vector2(kx, 128), "E", 13)
	UIKit.text(c, UIKit.BOLD, Vector2(kx + 24, 128), "use", 13, UIKit.CREAM, 4)
	UIKit.key(c, Vector2(kx + 70, 128), "Q", 13)
	UIKit.text(c, UIKit.BOLD, Vector2(kx + 94, 128), "switch", 13, UIKit.CREAM, 4)


func _draw_boss(c: Control, g: Node, W: float, H: float) -> void:
	if g.boss == null or not is_instance_valid(g.boss) or not (g.boss_state in ["fight", "dying"]):
		return
	var b = g.boss
	var bs := 0.8
	var t := _tex("ui_bar", "boss")
	if t == null:
		return
	var sz := t.get_size() * bs
	var br := Rect2(Vector2(W * 0.5 - sz.x * 0.5, H - sz.y - 6), sz)
	var shake := Vector2.ZERO
	var frac := clampf(b.hp / b.max_hp, 0.0, 1.0)
	if frac < _boss_trail - 0.002:
		shake = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	_boss_trail = move_toward(_boss_trail, frac, 0.25 * get_process_delta_time() / maxf(Engine.time_scale, 0.05))
	br.position += shake
	var inner := Rect2(br.position + Vector2(122, 45) * bs, Vector2(546, 54) * bs)
	c.draw_rect(inner, Color(0.15, 0.03, 0.03))
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * _boss_trail, inner.size.y)), Color(1, 0.85, 0.7))
	var hc := Color("#ff3b1f").lerp(Color("#ff9a1f"), 0.5 + 0.5 * sin(_t * 4.0))
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y)), hc)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y * 0.3)), Color(1, 1, 1, 0.25))
	c.draw_texture_rect(t, br, false)
	UIKit.text(c, UIKit.DISPLAY, Vector2(inner.position.x + 6, inner.position.y - 8), "RHINO CRAWLER", 20, UIKit.RED, 5)


func _draw_tip(c: Control, g: Node, W: float, H: float) -> void:
	if _tip_t <= 0.0 or _tip.is_empty():
		return
	var a := clampf(_tip_t / 0.4, 0.0, 1.0) * clampf((6.5 - _tip_t) / 0.3, 0.0, 1.0)
	var ty := H - 150.0 if g.boss_state in ["fight", "dying"] else H - 44.0
	var tr := Rect2(W * 0.5 - 470, ty - 30, 940, 44)
	c.draw_set_transform(Vector2(0, (1.0 - a) * 30.0), 0.0, Vector2.ONE)
	UIKit.panel(c, tr, Color(0.07, 0.05, 0.04, 0.85 * a), Color(UIKit.ORANGE, a), 12.0)
	UIKit.rich_tip(c, W * 0.5, ty, _tip, 19)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner(c: Control, W: float, H: float) -> void:
	if _banner_t <= 0.0:
		return
	var k := _banner_len - _banner_t
	var intro := clampf(k / 0.22, 0.0, 1.0)
	var outro := clampf(_banner_t / 0.35, 0.0, 1.0)
	var a2 := minf(intro, outro)
	var scale := lerpf(2.0, 1.0, ease(intro, 0.35))
	var cy := H * 0.36
	var plate := "neutral"
	var col := UIKit.YELLOW
	match _banner_kind:
		"alert":
			plate = "lose"
			col = Color("#fff2d6")
		"win":
			plate = "win"
		"fury":
			plate = "win"
			col = Color("#fff2d6")
	var slam := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * clampf(1.0 - k / 0.35, 0.0, 1.0) if intro >= 1.0 else Vector2.ZERO
	var t := _tex("ui_banner", plate)
	if t != null:
		var sz := t.get_size() * 0.9 * Vector2(lerpf(0.2, 1.0, ease(intro, 0.3)), 1.0)
		c.draw_texture_rect(t, Rect2(Vector2(W * 0.5, cy) - sz * 0.5 + slam, sz), false, Color(1, 1, 1, a2))
	if _banner_kind == "alert":
		var stripe := Color(0.9, 0.1, 0.05, (0.4 + 0.3 * sin(_t * 14.0)) * a2)
		c.draw_rect(Rect2(0, cy - 90, W, 6), stripe)
		c.draw_rect(Rect2(0, cy + 84, W, 6), stripe)
	c.draw_set_transform(Vector2(W * 0.5, cy) + slam, 0.0, Vector2(scale, scale))
	UIKit.centered(c, UIKit.DISPLAY, 0, 20, _banner, 60, Color(col, a2), 10)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UIKit.centered(c, UIKit.BOLD, W * 0.5, cy + 76, _banner_sub, 20, Color(UIKit.CREAM, a2), 5)


func _draw_stage_card(c: Control, W: float, H: float) -> void:
	if _stage_t <= 0.0 or _banner_t > 0.0 and _banner_len - _banner_t < 1.2:
		return
	var k := _stage_len - _stage_t
	var slide := ease(clampf(k / 0.35, 0.0, 1.0), 0.3)
	var out := clampf(_stage_t / 0.4, 0.0, 1.0)
	var x := lerpf(-600.0, 0.0, slide) + (1.0 - out) * 700.0
	var y := H * 0.40
	var a := out
	c.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 50), Vector2(x + 720, y - 50), Vector2(x + 680, y + 50), Vector2(x, y + 50)]), Color(0.07, 0.04, 0.03, 0.82 * a))
	c.draw_rect(Rect2(x, y - 50, 690, 5), Color(UIKit.ORANGE, a))
	c.draw_rect(Rect2(x, y + 45, 660, 5), Color(UIKit.ORANGE, a))
	UIKit.text(c, UIKit.DISPLAY, Vector2(x + 60, y + 14), _stage_name, 46, Color(UIKit.YELLOW, a), 8)
	UIKit.text(c, UIKit.BOLD, Vector2(x + 64, y + 40), _stage_sub, 18, Color(UIKit.CREAM, a), 4)


func _draw_tally(c: Control, W: float, H: float) -> void:
	var a := clampf(_tally_t / 0.4, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.01, 0.55 * a))
	var r := Rect2(W * 0.5 - 330, 200, 660, 360)
	c.draw_set_transform(Vector2(0, (1.0 - a) * 60.0), 0.0, Vector2.ONE)
	UIKit.panel(c, r, Color(0.08, 0.06, 0.05, 0.92), UIKit.ORANGE, 14.0)
	UIKit.centered(c, UIKit.DISPLAY, W * 0.5, r.position.y + 50, "STAGE %d CLEAR" % int(_tally.stage.id), 40, UIKit.YELLOW, 8)
	var secs := int(_tally.time)
	var rows := [
		["TIME", "%d:%02d" % [secs / 60, secs % 60], "+%d" % int(_tally.time_bonus)],
		["ENEMIES DOWN", "%d" % int(_tally.kills), "+%d" % (int(_tally.kills) * 100)],
		["CAPTIVES FREED", "%d" % int(_tally.rescued), "+%d" % (int(_tally.rescued) * 1000)],
		["STYLE RANK", str(_tally.rank), "+%d" % (int(_tally.rank_i) * 1000)],
		["STAGE BONUS", "", "+%d" % int(_tally.bonus)],
	]
	var y := r.position.y + 100.0
	for i in rows.size():
		if i >= _tally_ticks:
			break
		var row: Array = rows[i]
		var big := i == 4
		UIKit.text(c, UIKit.BOLD, Vector2(r.position.x + 40, y), row[0], 22 if not big else 26, UIKit.CREAM if not big else UIKit.YELLOW, 4)
		UIKit.text(c, UIKit.BOLD, Vector2(r.position.x + 330, y), row[1], 22, UIKit.CYAN, 4)
		var vw := UIKit.text_w(UIKit.DISPLAY, row[2], 24 if not big else 32)
		UIKit.text(c, UIKit.DISPLAY, Vector2(r.end.x - 40 - vw, y), row[2], 24 if not big else 32, UIKit.YELLOW if not big else UIKit.ORANGE, 5)
		y += 48.0
	if _tally_ticks >= 5 and not _loading:
		var blink := 0.6 + 0.4 * sin(_t * 6.0)
		UIKit.centered(c, UIKit.BOLD, W * 0.5, r.end.y - 18, "Moving out...", 18, Color(UIKit.CREAM, blink), 4)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loading(c: Control, W: float, _H: float) -> void:
	var r := Rect2(W * 0.5 - 300, 580, 600, 70)
	UIKit.panel(c, r, Color(0.07, 0.05, 0.04, 0.9), UIKit.CYAN, 10.0)
	var label := "DEPLOYING TO %s" % _load_name
	if _load_failed:
		label = "SIGNAL LOST - RETRYING..."
	UIKit.text(c, UIKit.DISPLAY, Vector2(r.position.x + 20, r.position.y + 30), label, 20, UIKit.CYAN if not _load_failed else UIKit.RED, 4)
	var bar := Rect2(r.position.x + 20, r.position.y + 42, r.size.x - 110, 12)
	c.draw_rect(bar.grow(2.0), UIKit.INK)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _load_frac, bar.size.y)), UIKit.CYAN)
	var sx := bar.position.x + fmod(_t * 260.0, maxf(bar.size.x * _load_frac, 1.0))
	c.draw_rect(Rect2(sx, bar.position.y, 14, bar.size.y), Color(1, 1, 1, 0.4))
	UIKit.text(c, UIKit.BOLD, Vector2(bar.end.x + 12, bar.end.y), "%d%%" % int(_load_frac * 100.0), 18, UIKit.CREAM, 4)


func _draw_life(c: Control, pos: Vector2) -> void:
	# little helmet icon
	c.draw_circle(pos, 10.0, UIKit.INK)
	c.draw_circle(pos, 8.0, Color("#6b7a3a"))
	c.draw_rect(Rect2(pos.x - 9, pos.y, 18, 4), UIKit.INK)
	c.draw_rect(Rect2(pos.x - 5, pos.y - 3, 10, 3), UIKit.RED)


# ---- pause menu -----------------------------------------------------------------

func _menu_box(title: String) -> Array:
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.01, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(420, 0)
	center.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", UIKit.DISPLAY)
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", UIKit.YELLOW)
	t.add_theme_color_override("font_outline_color", UIKit.INK)
	t.add_theme_constant_override("outline_size", 10)
	box.add_child(t)
	root.add_child(panel)
	return [panel, box, t]


static func kit_button_style(b: Button, size: int = 26) -> void:
	UIKit.style_button(b, size)
	var tn := SpriteLib.tex("ui_plate", "button")
	var th := SpriteLib.tex("ui_plate", "button_hi")
	if tn == null or th == null:
		return
	var sn := StyleBoxTexture.new()
	sn.texture = tn
	sn.texture_margin_left = 45
	sn.texture_margin_right = 18
	sn.texture_margin_top = 13
	sn.texture_margin_bottom = 20
	sn.content_margin_left = 40
	sn.content_margin_right = 16
	var sh := StyleBoxTexture.new()
	sh.texture = th
	sh.texture_margin_left = 66
	sh.texture_margin_right = 33
	sh.texture_margin_top = 39
	sh.texture_margin_bottom = 39
	sh.expand_margin_left = 22
	sh.expand_margin_right = 12
	sh.expand_margin_top = 22
	sh.expand_margin_bottom = 22
	sh.content_margin_left = 40
	sh.content_margin_right = 16
	b.add_theme_stylebox_override("normal", sn)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("focus", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", UIKit.CREAM)
	b.add_theme_color_override("font_hover_color", UIKit.YELLOW)
	b.add_theme_color_override("font_focus_color", UIKit.YELLOW)


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	kit_button_style(b, 26)
	b.custom_minimum_size = Vector2(380, 56)
	b.pressed.connect(func():
		GS.sfx(&"ui_confirm")
		var r := b.get_global_rect()
		_burst(r.get_center(), 24, GS.C_YELLOW, 360.0, UP.STAR)
		cb.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func():
		GS.sfx(&"ui_hover")
		var r := b.get_global_rect()
		for i in 10:
			var px := randf_range(r.position.x, r.end.x)
			var py := r.position.y if i % 2 == 0 else r.end.y
			_emit(Vector2(px, py), Vector2(randf_range(-40, 40), randf_range(-90, -20) if i % 2 == 0 else randf_range(20, 90)), 0.45, 4.0, GS.C_ORANGE, UP.SPARK))
	box.add_child(b)
	return b


func _build_pause() -> void:
	var parts := _menu_box("PAUSED")
	pause_panel = parts[0]
	var box: VBoxContainer = parts[1]
	_button(box, "RESUME", toggle_pause)
	_button(box, "CONTROLS", func(): controls_panel.visible = not controls_panel.visible)
	_button(box, "RESTART MISSION", func(): GS.game.restart_mission())
	_button(box, "QUIT TO TITLE", func(): GS.game.quit_to_title())
	controls_panel = _controls_card()
	controls_panel.visible = false
	pause_panel.add_child(controls_panel)


func _controls_card() -> Control:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(func():
		var W := card.size.x
		var r := Rect2(W * 0.5 + 240, 130, 400, 460)
		UIKit.panel(card, r)
		var rows := [["A / D", "Move"], ["SPACE", "Jump (S+SPACE: drop)"], ["J", "Shoot / knife up close"], ["W / S", "Aim up / crouch, aim down"], ["K", "Grapple (W+K: up / swing)"], ["L", "Grab / throw / man MG"], ["E", "Use item"], ["Q", "Switch item"], ["F", "FURY overdrive"], ["ESC", "Pause"]]
		var y := r.position.y + 44
		UIKit.text(card, UIKit.DISPLAY, Vector2(r.position.x + 24, y - 6), "CONTROLS", 24, UIKit.YELLOW, 5)
		y += 34
		for row in rows:
			UIKit.key(card, Vector2(r.position.x + 24, y), row[0], 15)
			UIKit.text(card, UIKit.BOLD, Vector2(r.position.x + 130, y), row[1], 17, UIKit.CREAM, 4)
			y += 37)
	return card


func toggle_pause() -> void:
	var tree := get_tree()
	var now := not tree.paused
	tree.paused = now
	pause_panel.visible = now
	controls_panel.visible = false
	Engine.time_scale = 1.0
	if now:
		_banner_t = minf(_banner_t, 0.0)
		(pause_panel.get_child(1).get_child(0).get_child(1) as Button).grab_focus()
	GS.sfx(&"ui_pause")


func _unhandled_input(event: InputEvent) -> void:
	if pause_panel.visible and event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


# ---- results ------------------------------------------------------------------------

var _res_title: Label
var _res_stats: Control
var _res_box: VBoxContainer
var _res_continue: Button
var _res_win := false
var _res_t := 0.0


func _build_results() -> void:
	var parts := _menu_box("MISSION COMPLETE")
	results_panel = parts[0]
	_res_box = parts[1]
	_res_title = parts[2]
	_res_stats = Control.new()
	_res_stats.custom_minimum_size = Vector2(460, 290)
	_res_stats.draw.connect(_draw_results)
	_res_box.add_child(_res_stats)
	_res_continue = _button(_res_box, "CONTINUE", func(): GS.game.continue_mission())
	_button(_res_box, "PLAY AGAIN", func(): GS.game.restart_mission())
	_button(_res_box, "TITLE SCREEN", func(): GS.game.quit_to_title())


func show_results(win: bool) -> void:
	_results_shown = true
	_res_win = win
	_res_t = 0.0
	_res_title.text = "MISSION COMPLETE" if win else "MISSION FAILED"
	_res_title.add_theme_color_override("font_color", UIKit.YELLOW if win else UIKit.RED)
	_res_continue.visible = not win
	results_panel.visible = true
	results_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(results_panel, "modulate:a", 1.0, 0.5)
	(_res_continue if not win else _res_box.get_child(3)).grab_focus()
	if win:
		_burst(Vector2(640, 120), 60, GS.C_YELLOW, 600.0, UP.STAR)
		_burst(Vector2(640, 120), 40, GS.C_ORANGE, 500.0, UP.SHARD)


func hide_results() -> void:
	_results_shown = false
	results_panel.visible = false


func _draw_results() -> void:
	var g := GS.game
	if g == null:
		return
	_res_t += get_process_delta_time() / maxf(Engine.time_scale, 0.05)
	var c := _res_stats
	var st: Dictionary = g.stats
	var t := int(g.mission_time)
	var rows := [
		["SCORE", "%d" % g.score],
		["ENEMIES DOWN", "%d" % st.kills],
		["THROWN KILLS", "%d" % st.thrown],
		["GRAPPLE KICKS", "%d" % st.strikes],
		["CAPTIVES FREED", "%d / %d" % [st.captives, st.captives_total]],
		["BEST CHAIN", "x%d" % st.best_chain],
		["PEAK STYLE", ["D", "C", "B", "A", "S"][g.style.peak_rank]],
		["TIME", "%d:%02d" % [t / 60, t % 60]],
	]
	var y := 24.0
	var shown := mini(rows.size(), int(_res_t / 0.12))
	for i in shown:
		var r: Array = rows[i]
		UIKit.text(c, UIKit.BOLD, Vector2(0, y), r[0], 20, UIKit.CREAM, 4)
		var w := UIKit.text_w(UIKit.BOLD, r[1], 22)
		UIKit.text(c, UIKit.BOLD, Vector2(300 - w, y), r[1], 22, UIKit.YELLOW, 4)
		y += 32
	if _res_win and _res_t > 1.0:
		var letter: String = g.rank()
		var pop := 1.0 + 0.5 * clampf(1.0 - (_res_t - 1.0) / 0.25, 0.0, 1.0)
		UIKit.text(c, UIKit.BOLD, Vector2(344, 30), "RANK", 18, UIKit.CREAM, 4)
		var tx := SpriteLib.tex("ui_rank", letter)
		if tx != null:
			var sz := tx.get_size() * 0.6 * pop
			c.draw_texture_rect(tx, Rect2(Vector2(390, 110) - sz * 0.5, sz), false)
		else:
			UIKit.text(c, UIKit.DISPLAY, Vector2(346, 140), letter, 96, UIKit.ORANGE, 10)
	if g.score >= g.best_score and g.score > 0 and _res_t > 1.3:
		var blink := 0.7 + 0.3 * sin(_res_t * 8.0)
		UIKit.text(c, UIKit.DISPLAY, Vector2(326, 230), "NEW BEST!", 22, Color(UIKit.CYAN, blink), 4)
	c.queue_redraw()
