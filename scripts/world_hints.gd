extends Node2D
## Contextual world-space prompts: grab prompt over nearby props, grapple
## prompt over rings in range, and a throw prompt while carrying.

var t := 0.0
var throws_hinted := 0


func _ready() -> void:
	z_index = 80


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var g := GS.game
	if g == null or g.player == null:
		return
	var p = g.player
	if not p.is_hittable() or not p.controls:
		return
	var bob := sin(t * 6.0) * 3.0
	if p.carried == null and p.hook_state == "none":
		var best: Node = null
		var bd := 90.0
		for o in g.grabbables():
			var d: float = o.center().distance_to(p.center())
			if d < bd:
				bd = d
				best = o
		if best != null:
			var at: Vector2 = best.hurt_rect().position + Vector2(best.hurt_rect().size.x * 0.5 - 12.0, -14.0 + bob)
			UIKit.key(self, at, "L", 16)
	elif p.carried != null and g.stats.thrown < 3:
		UIKit.key(self, p.global_position + Vector2(-44, -160 + bob), "L", 15)
		UIKit.text(self, UIKit.BOLD, p.global_position + Vector2(-14, -160 + bob), "THROW", 15, UIKit.CREAM, 4)
	if p.state != "swing" and p.hook_state == "none":
		for a in g.anchors:
			if a.global_position.distance_to(p.center()) < p.grapple_range + 20.0 and g.view_rect().has_point(a.global_position):
				var ap: Vector2 = a.global_position + Vector2(-38, -48 + bob)
				var w := UIKit.key(self, ap, "W", 15)
				UIKit.text(self, UIKit.BOLD, ap + Vector2(w + 4, 0), "+", 16, UIKit.CREAM, 4)
				UIKit.key(self, ap + Vector2(w + 18, 0), "K", 15)
