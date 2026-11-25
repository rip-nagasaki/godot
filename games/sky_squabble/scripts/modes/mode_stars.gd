extends "res://scripts/modes/mode_base.gd"
## Collect falling stars. Getting bonked knocks some of yours loose.

var items: Array[Dictionary] = []
var spawn_timer := 1.0


func _init() -> void:
	id = "stars"
	title = "Star Catch"
	rule = "Grab the falling stars! Dash your rival to knock their stars loose."
	layout = "peanut"
	time_limit = 35.0
	respawn_delay = 1.1


func spawn_point(i: int) -> Vector2:
	return game.arena.center + Vector2(-245.0 if i == 0 else 245.0, 0.0)


func _spawn(p: Vector2, height: float, value: int, v: Vector2, vh: float, delay: float) -> void:
	items.append({"p": p, "h": height, "vh": vh, "vel": v, "value": value, "delay": delay,
		"t": randf() * 5.0, "rot": randf() * TAU, "spin": randf_range(-3.0, 3.0)})


func update(dt: float) -> void:
	t += dt
	spawn_timer -= dt
	if spawn_timer <= 0.0 and items.size() < 10:
		spawn_timer = randf_range(0.45, 0.85)
		var gold := randf() < 0.12
		_spawn(game.arena.random_point(40.0), 650.0, 3 if gold else 1, Vector2.ZERO, 0.0, 0.0)
	var i := items.size() - 1
	while i >= 0:
		var s: Dictionary = items[i]
		s["t"] += dt
		s["rot"] += s["spin"] * dt
		s["delay"] -= dt
		s["vh"] -= 1500.0 * dt
		s["h"] += s["vh"] * dt
		if s["h"] <= 0.0:
			s["h"] = 0.0
			if s["vh"] < -160.0:
				s["vh"] = -s["vh"] * 0.35
				if s["value"] > 1:
					Sfx.play("blip", -10.0, 1.8)
			else:
				s["vh"] = 0.0
		s["p"] += s["vel"] * dt
		s["vel"] *= exp(-3.0 * dt)
		var removed := false
		if s["h"] < 40.0 and s["delay"] <= 0.0:
			for b in game.blobs:
				if b.is_active() and b.position.distance_to(s["p"]) < b.radius + 20.0:
					_collect(b, s)
					items.remove_at(i)
					removed = true
					break
		if not removed and s["h"] <= 0.0 and s["vh"] == 0.0 and not game.arena.is_on_ground(s["p"]):
			game.fx.stars(s["p"], Color("ffe066"), 4, 120.0)
			items.remove_at(i)
		i -= 1
	check_overtime()


func _collect(b, s: Dictionary) -> void:
	var v: int = s["value"]
	scores[b.idx] += v
	if v > 1:
		Sfx.play("big_pickup", -2.0)
		game.fx.ring(s["p"], Color("ffd23f"), 10.0, 90.0, 0.45, 8.0)
	else:
		Sfx.play("pickup", -4.0, 1.0 + scores[b.idx] * 0.01)
	game.fx.stars(s["p"] + Vector2(0, -20), Color("ffe066"), 5 + v * 2, 220.0)
	game.fx.popup(s["p"] + Vector2(0, -40), "+%d" % v, b.color.lightened(0.4), 24.0 + v * 4.0)


func _lose_stars(b, n: int, scatter: bool) -> void:
	n = mini(n, int(scores[b.idx]))
	if n <= 0:
		return
	scores[b.idx] -= n
	game.fx.popup(b.head_pos(), "-%d" % n, Color(1, 0.5, 0.5), 26.0)
	if scatter:
		for k in n:
			var dir := Vector2.from_angle(randf() * TAU)
			_spawn(b.position, 30.0, 1, dir * randf_range(180.0, 320.0), randf_range(380.0, 520.0), 0.45)


func on_hit(_attacker, victim) -> void:
	_lose_stars(victim, 3, true)
	Sfx.play("steal", -4.0)


func on_fall(b) -> void:
	_lose_stars(b, 2, false)


func draw_ground(ci: CanvasItem) -> void:
	for s in items:
		var hh: float = s["h"]
		var k := clampf(1.0 - hh / 650.0, 0.15, 1.0)
		var p: Vector2 = s["p"]
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
		ci.draw_circle(Vector2.ZERO, 16.0 * k, Color(0, 0, 0, 0.28 * k))
		if hh > 120.0:
			ci.draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 24, Color(1, 0.9, 0.4, 0.5 * k), 2.5)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star_pos(s: Dictionary) -> Vector2:
	var bob := sin(s["t"] * 4.0) * 3.0 if s["h"] <= 0.0 else 0.0
	return s["p"] + Vector2(0, -s["h"] - 16.0 + bob)


func draw_top(ci: CanvasItem) -> void:
	for s in items:
		var gold: bool = s["value"] > 1
		var r := 17.0 if gold else 12.0
		var col := Color("ffb627") if gold else Color("ffe45c")
		if s["delay"] > 0.0 and int(s["delay"] * 20.0) % 2 == 0:
			col.a = 0.5
		G.draw_star(ci, _star_pos(s), r, col, s["rot"], Color("8a4b00"))


func draw_glow(ci: CanvasItem) -> void:
	for s in items:
		var gold: bool = s["value"] > 1
		G.glow(ci, _star_pos(s), 46.0 if gold else 30.0, Color(1, 0.8, 0.3, 0.5 if gold else 0.35))


func light_points() -> Array:
	var out := []
	for s in items:
		if s["value"] > 1 and s["h"] <= 0.0:
			out.append([s["p"], 100.0])
	return out


func draw_hud(ci: CanvasItem) -> void:
	for i in 2:
		var cx := 560.0 if i == 0 else 720.0
		var r := Rect2(cx - 55, 110, 110, 34)
		ci.draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
		ci.draw_rect(r, G.P_DARK[i])
		G.draw_star(ci, Vector2(r.position.x + 20, 127), 11.0, Color("ffe45c"), 0.0)
		G.text(ci, Vector2(cx + 12, 127), score_label(i), 24, Color.WHITE, 4)


func draw_icon(ci: CanvasItem, pos: Vector2, s: float, tt: float) -> void:
	G.glow(ci, pos, 60.0 * s, Color(1, 0.8, 0.3, 0.5))
	G.draw_star(ci, pos + Vector2(-18, 8) * s, 22.0 * s, Color("ffe45c"), tt, Color("8a4b00"))
	G.draw_star(ci, pos + Vector2(22, -14) * s, 15.0 * s, Color("ffb627"), -tt * 1.3, Color("8a4b00"))
	G.draw_star(ci, pos + Vector2(16, 24) * s, 10.0 * s, Color("ffe45c"), tt * 2.0, Color("8a4b00"))
