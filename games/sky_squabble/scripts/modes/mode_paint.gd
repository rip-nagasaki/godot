extends "res://scripts/modes/mode_base.gd"
## Territory painting: most ground in your color when time runs out wins.

const CELL := 20.0

var cols := 0
var rows := 0
var origin := Vector2.ZERO
var grid := PackedByteArray()
var valid := 0
var counts := [0, 0]
var buckets: Array[Dictionary] = []
var bucket_timer := 5.0


func _init() -> void:
	id = "paint"
	title = "Paint Panic"
	rule = "Cover the most ground in your color! Dash for big splats."
	layout = "rect"
	time_limit = 35.0
	respawn_delay = 1.0


func spawn_point(i: int) -> Vector2:
	return game.arena.center + Vector2(-300.0 if i == 0 else 300.0, 0.0)


func setup() -> void:
	var b: Rect2 = game.arena.bounds
	origin = game.arena.center + b.position
	cols = int(ceil(b.size.x / CELL))
	rows = int(ceil(b.size.y / CELL))
	grid.resize(cols * rows)
	valid = 0
	for y in rows:
		for x in cols:
			var p := origin + Vector2(x + 0.5, y + 0.5) * CELL
			if game.arena.is_safe_point(p, CELL * 0.4):
				grid[y * cols + x] = 0
				valid += 1
			else:
				grid[y * cols + x] = 255


func paint_circle(p: Vector2, r: float, owner: int) -> int:
	var changed := 0
	var x0 := maxi(0, int((p.x - r - origin.x) / CELL))
	var x1 := mini(cols - 1, int((p.x + r - origin.x) / CELL))
	var y0 := maxi(0, int((p.y - r - origin.y) / CELL))
	var y1 := mini(rows - 1, int((p.y + r - origin.y) / CELL))
	var v := owner + 1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * cols + x
			var g := grid[i]
			if g == 255 or g == v:
				continue
			var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
			if c.distance_squared_to(p) > r * r:
				continue
			if g > 0:
				counts[g - 1] -= 1
			if v > 0:
				counts[v - 1] += 1
			grid[i] = v
			changed += 1
	scores[0] = float(counts[0])
	scores[1] = float(counts[1])
	return changed


func update(dt: float) -> void:
	t += dt
	for b in game.blobs:
		if b.is_active():
			paint_circle(b.position, b.radius * (1.7 if b.is_dashing() else 1.05), b.idx)
	bucket_timer -= dt
	if bucket_timer <= 0.0 and buckets.size() < 2:
		bucket_timer = randf_range(4.0, 7.0)
		buckets.append({"p": game.arena.random_point(60.0), "t": 0.0})
	var i := buckets.size() - 1
	while i >= 0:
		var bk: Dictionary = buckets[i]
		bk["t"] += dt
		for b in game.blobs:
			if b.is_active() and b.position.distance_to(bk["p"]) < b.radius + 22.0:
				paint_circle(bk["p"], 125.0, b.idx)
				Sfx.play("big_pickup", -2.0)
				Sfx.play("splat", 0.0)
				game.fx.burst(bk["p"], b.color, 30, 420.0, 9.0, 0.8)
				game.fx.ring(bk["p"], b.color, 20.0, 140.0, 0.5, 10.0)
				game.fx.popup(bk["p"] + Vector2(0, -40), "SPLASH!", b.color.lightened(0.3), 30.0)
				game.shake(6.0)
				buckets.remove_at(i)
				break
		i -= 1
	check_overtime()


func on_hit(attacker, victim) -> void:
	if attacker == null:
		return
	paint_circle(victim.position, 80.0, attacker.idx)
	Sfx.play("splat", -2.0)
	game.fx.burst(victim.position, attacker.color, 18, 320.0, 8.0, 0.6)


func on_explosion(pos: Vector2, radius: float) -> void:
	paint_circle(pos, radius, -1)


func score_label(i: int) -> String:
	return "%d%%" % int(round(100.0 * counts[i] / maxf(1.0, valid)))


func draw_ground(ci: CanvasItem) -> void:
	var cols_c := [G.P_COLORS[0].darkened(0.05), G.P_COLORS[1].darkened(0.05)]
	for y in rows:
		for x in cols:
			var g := grid[y * cols + x]
			if g == 0 or g == 255:
				continue
			var c := origin + Vector2(x + 0.5, y + 0.5) * CELL
			var col: Color = cols_c[g - 1]
			var edge := false
			if x == 0 or x == cols - 1 or y == 0 or y == rows - 1:
				edge = true
			else:
				var i := y * cols + x
				edge = grid[i - 1] != g or grid[i + 1] != g or grid[i - cols] != g or grid[i + cols] != g
			if edge:
				ci.draw_circle(c, CELL * 0.72, col)
			else:
				ci.draw_rect(Rect2(c - Vector2(CELL, CELL) * 0.5 - Vector2(1, 1), Vector2(CELL + 2, CELL + 2)), col)
	for bk in buckets:
		var p: Vector2 = bk["p"]
		var bob := sin(bk["t"] * 4.0) * 4.0
		ci.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
		ci.draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.25))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var top := p + Vector2(0, -26 + bob)
		ci.draw_rect(Rect2(top + Vector2(-17, 0), Vector2(34, 30)), Color("e6e6f0"))
		ci.draw_rect(Rect2(top + Vector2(-17, 0), Vector2(34, 30)), Color("7a7a90"), false, 3.0)
		var hue := fmod(bk["t"] * 0.3, 1.0)
		ci.draw_set_transform(top, 0.0, Vector2(1.0, 0.4))
		ci.draw_circle(Vector2.ZERO, 17.0, Color.from_hsv(hue, 0.8, 1.0))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ci.draw_circle(top + Vector2(-8, 10), 5.0, Color.from_hsv(hue, 0.8, 1.0))
		ci.draw_rect(Rect2(top + Vector2(-10.5, 0), Vector2(5, 10)), Color.from_hsv(hue, 0.8, 1.0))
		ci.draw_arc(top + Vector2(0, -2), 16.0, PI, TAU, 12, Color("7a7a90"), 2.5)


func draw_glow(ci: CanvasItem) -> void:
	for bk in buckets:
		G.glow(ci, bk["p"] + Vector2(0, -16), 60.0, Color.from_hsv(fmod(bk["t"] * 0.3, 1.0), 0.6, 1.0, 0.35))


func light_points() -> Array:
	var out := []
	for bk in buckets:
		out.append([bk["p"], 110.0])
	return out


func draw_hud(ci: CanvasItem) -> void:
	var w := 420.0
	var r := Rect2(640 - w * 0.5, 116, w, 22)
	var f0: float = counts[0] / maxf(1.0, valid)
	var f1: float = counts[1] / maxf(1.0, valid)
	ci.draw_rect(r.grow(3), Color(0, 0, 0, 0.45))
	ci.draw_rect(r, Color(1, 1, 1, 0.25))
	ci.draw_rect(Rect2(r.position, Vector2(w * f0, r.size.y)), G.P_COLORS[0])
	ci.draw_rect(Rect2(Vector2(r.end.x - w * f1, r.position.y), Vector2(w * f1, r.size.y)), G.P_COLORS[1])
	ci.draw_line(Vector2(640, r.position.y - 4), Vector2(640, r.end.y + 4), Color.WHITE, 2.0)
	G.text(ci, Vector2(r.position.x - 40, 127), score_label(0), 22, G.P_COLORS[0].lightened(0.3), 5)
	G.text(ci, Vector2(r.end.x + 40, 127), score_label(1), 22, G.P_COLORS[1].lightened(0.3), 5)


func draw_icon(ci: CanvasItem, pos: Vector2, s: float, tt: float) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + tt * 0.5
		ci.draw_circle(pos + Vector2(cos(a), sin(a)) * 30.0 * s - Vector2(14 * s, 0), (10.0 + 4.0 * sin(i * 2.0)) * s, G.P_COLORS[0])
	for i in 6:
		var a := TAU * i / 6.0 - tt * 0.5
		ci.draw_circle(pos + Vector2(cos(a), sin(a)) * 24.0 * s + Vector2(26 * s, 6 * s), (9.0 + 4.0 * cos(i * 2.0)) * s, G.P_COLORS[1])
	ci.draw_circle(pos - Vector2(14 * s, 0), 22.0 * s, G.P_COLORS[0])
	ci.draw_circle(pos + Vector2(26 * s, 6 * s), 18.0 * s, G.P_COLORS[1])
