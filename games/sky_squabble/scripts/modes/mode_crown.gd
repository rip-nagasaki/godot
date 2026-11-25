extends "res://scripts/modes/mode_base.gd"
## Keep-away: hold the crown long enough to be crowned champion.

const TARGET := 12.0

var pos := Vector2.ZERO
var h := 0.0
var vh := 0.0
var vel := Vector2.ZERO
var holder := -1
var state := "fly"
var grab_delay := 0.0
var respawn_t := 0.0
var sparkle_t := 0.0


func _init() -> void:
	id = "crown"
	title = "Crown Keeper"
	rule = "Hold the crown for 12 seconds! Dash your rival to steal it."
	layout = "clover"
	time_limit = 50.0


func spawn_point(i: int) -> Vector2:
	return game.arena.center + Vector2(-205.0 if i == 0 else 205.0, 0.0)


func setup() -> void:
	_respawn_crown()


func _respawn_crown() -> void:
	pos = game.arena.center
	h = 520.0
	vh = 0.0
	vel = Vector2.ZERO
	state = "fly"
	holder = -1
	grab_delay = 0.0


func update(dt: float) -> void:
	t += dt
	grab_delay -= dt
	match state:
		"held":
			var b = game.blobs[holder]
			pos = b.position
			scores[holder] += dt
			sparkle_t -= dt
			if sparkle_t <= 0.0:
				sparkle_t = 0.12
				game.fx.stars(b.head_pos(), Color("ffe066"), 1, 90.0)
			if scores[holder] >= TARGET:
				scores[holder] = TARGET
				finish(holder)
		"fly":
			vh -= 1500.0 * dt
			h += vh * dt
			pos += vel * dt
			vel *= exp(-1.2 * dt)
			if h <= 0.0:
				h = 0.0
				if vh < -220.0:
					vh = -vh * 0.4
					Sfx.play("blip", -8.0, 1.6)
				else:
					vh = 0.0
					vel = Vector2.ZERO
					if game.arena.is_on_ground(pos):
						state = "idle"
					else:
						state = "gone"
						respawn_t = 1.0
						game.fx.stars(pos, Color("ffe066"), 8, 160.0)
		"idle":
			for b in game.blobs:
				if grab_delay <= 0.0 and b.is_active() and b.position.distance_to(pos) < b.radius + 24.0:
					_grab(b)
					break
		"gone":
			respawn_t -= dt
			if respawn_t <= 0.0:
				_respawn_crown()
	if state == "fly" and h < 30.0 and grab_delay <= 0.0:
		for b in game.blobs:
			if b.is_active() and b.position.distance_to(pos) < b.radius + 24.0:
				_grab(b)
				break
	for i in 2:
		game.blobs[i].speed_mult = 0.9 if (state == "held" and holder == i) else 1.0
	check_overtime()


func _grab(b) -> void:
	holder = b.idx
	state = "held"
	Sfx.play("big_pickup", -2.0)
	game.fx.burst(b.head_pos(), Color("ffe066"), 20, 300.0, 6.0)
	game.fx.ring(b.head_pos(), Color("ffe066"), 10.0, 80.0, 0.4, 6.0)
	game.fx.popup(b.head_pos() + Vector2(0, -30), "CROWNED!", b.color.lightened(0.4), 26.0)


func _drop(b, fling: Vector2) -> void:
	holder = -1
	state = "fly"
	pos = b.position
	h = 50.0
	vh = 480.0
	vel = fling
	grab_delay = 0.35
	Sfx.play("steal", -2.0)
	game.fx.stars(b.head_pos(), Color("ffe066"), 8, 220.0)


func on_hit(_attacker, victim) -> void:
	if state == "held" and holder == victim.idx:
		var dir: Vector2 = victim.vel.normalized() if victim.vel.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		_drop(victim, dir.rotated(randf_range(-0.6, 0.6)) * randf_range(160.0, 260.0))


func on_fall(b) -> void:
	if state == "held" and holder == b.idx:
		holder = -1
		state = "gone"
		respawn_t = 1.2


func avoid_points() -> Array:
	return [spawn_point(0), spawn_point(1), game.arena.center]


func light_points() -> Array:
	if state == "held" or state == "gone":
		return []
	return [[pos, 130.0]]


func score_label(i: int) -> String:
	return "%.1fs" % scores[i]


func _crown_draw_pos() -> Vector2:
	if state == "held":
		return game.blobs[holder].head_pos() + Vector2(0, sin(t * 6.0) * 2.0)
	return pos + Vector2(0, -h - 16.0 + (sin(t * 3.0) * 4.0 if state == "idle" else 0.0))


func draw_ground(ci: CanvasItem) -> void:
	if state == "fly" or state == "idle":
		var k := clampf(1.0 - h / 520.0, 0.2, 1.0)
		ci.draw_set_transform(pos, 0.0, Vector2(1.0, 0.45))
		ci.draw_circle(Vector2.ZERO, 22.0 * k, Color(0, 0, 0, 0.3 * k))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if state == "idle":
			ci.draw_set_transform(pos, 0.0, Vector2(1.0, 0.45))
			ci.draw_arc(Vector2.ZERO, 34.0 + sin(t * 4.0) * 4.0, 0.0, TAU, 32, Color(1, 0.9, 0.4, 0.6), 3.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_top(ci: CanvasItem) -> void:
	if state == "gone":
		return
	var tilt := sin(t * 2.5) * 0.12
	G.draw_crown(ci, _crown_draw_pos(), 0.95, Color("ffd23f"), tilt)


func draw_glow(ci: CanvasItem) -> void:
	if state == "gone":
		return
	G.glow(ci, _crown_draw_pos(), 70.0 + sin(t * 5.0) * 8.0, Color(1, 0.8, 0.3, 0.45))


func draw_hud(ci: CanvasItem) -> void:
	for i in 2:
		var w := 190.0
		var x := 640.0 - 20.0 - w if i == 0 else 660.0
		var r := Rect2(x, 116, w, 20)
		var f := clampf(scores[i] / TARGET, 0.0, 1.0)
		ci.draw_rect(r.grow(3), Color(0, 0, 0, 0.45))
		ci.draw_rect(r, Color(1, 1, 1, 0.2))
		if i == 0:
			ci.draw_rect(Rect2(r.end.x - w * f, r.position.y, w * f, r.size.y), G.P_COLORS[0])
		else:
			ci.draw_rect(Rect2(r.position, Vector2(w * f, r.size.y)), G.P_COLORS[1])
		var lx := r.position.x - 42.0 if i == 0 else r.end.x + 42.0
		G.text(ci, Vector2(lx, 126), score_label(i), 20, G.P_COLORS[i].lightened(0.35), 5)
	G.draw_crown(ci, Vector2(640, 124), 0.55, Color("ffd23f"))


func draw_icon(ci: CanvasItem, pos_i: Vector2, s: float, tt: float) -> void:
	G.glow(ci, pos_i, 60.0 * s, Color(1, 0.85, 0.3, 0.5))
	G.draw_crown(ci, pos_i + Vector2(0, sin(tt * 3.0) * 4.0 * s), 1.6 * s, Color("ffd23f"), sin(tt * 2.0) * 0.15)
