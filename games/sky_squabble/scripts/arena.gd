extends Node2D
## The floating island. Shapes are unions of polygons drawn as a 2.5D extruded block.

var center := Vector2(640, 405)
var polys: Array[PackedVector2Array] = []
var rims: Array[PackedVector2Array] = []
var inners: Array[PackedVector2Array] = []
var bounds := Rect2()
var layout := ""
var shrink := 1.0
var appear := 1.0
var icy := 0.0
var theme: Dictionary = G.THEMES[0]
var walls := false
var rink := Rect2()
var goal_half := 88.0
var goal_depth := 56.0
var deco: Array[Dictionary] = []
var hangers: Array[Dictionary] = []
var pattern_pts := PackedVector2Array()
var t := 0.0

const DEPTH := 58.0
const LAYERS := 10


func build(layout_name: String) -> void:
	layout = layout_name
	polys.clear()
	walls = false
	shrink = 1.0
	icy = 0.0
	center = Vector2(640, 410)
	var sv := randf() * 10.0
	match layout_name:
		"title":
			center = Vector2(640, 470)
			polys.append(G.circle_poly(Vector2.ZERO, 200, 64, 0.02, sv))
		"circle":
			polys.append(G.circle_poly(Vector2.ZERO, 250, 72, 0.018, sv))
		"rect":
			polys.append(G.round_rect_poly(Rect2(-410, -225, 820, 450), 70))
		"square":
			polys.append(G.round_rect_poly(Rect2(-285, -215, 570, 430), 80))
		"clover":
			polys.append(G.circle_poly(Vector2.ZERO, 150, 56, 0.02, sv))
			polys.append(G.circle_poly(Vector2(-205, 0), 128, 56, 0.025, sv + 1.0))
			polys.append(G.circle_poly(Vector2(205, 0), 128, 56, 0.025, sv + 2.0))
			polys.append(G.circle_poly(Vector2(0, -145), 118, 56, 0.025, sv + 3.0))
			polys.append(G.circle_poly(Vector2(0, 145), 118, 56, 0.025, sv + 4.0))
		"peanut":
			polys.append(G.circle_poly(Vector2(-245, 0), 175, 64, 0.02, sv))
			polys.append(G.round_rect_poly(Rect2(-250, -105, 500, 210), 60))
			polys.append(G.circle_poly(Vector2(245, 0), 175, 64, 0.02, sv + 2.0))
		"rink":
			walls = true
			rink = Rect2(-450, -228, 900, 456)
			polys.append(G.round_rect_poly(rink.grow_individual(goal_depth + 24, 30, goal_depth + 24, 30), 46))
	rims.clear()
	inners.clear()
	bounds = Rect2()
	for i in polys.size():
		var p := polys[i]
		var grown := Geometry2D.offset_polygon(p, 6.0)
		rims.append(grown[0] if grown.size() > 0 else p)
		var shrunk := Geometry2D.offset_polygon(p, -14.0)
		inners.append(shrunk[0] if shrunk.size() > 0 else p)
		var r := Rect2(p[0], Vector2.ZERO)
		for v in p:
			r = r.expand(v)
		bounds = r if i == 0 else bounds.merge(r)
	_make_decorations()
	queue_redraw()


func _make_decorations() -> void:
	deco.clear()
	hangers.clear()
	pattern_pts.clear()
	var step := 64.0
	var y := floorf(bounds.position.y / step) * step
	while y < bounds.end.y:
		var x := floorf(bounds.position.x / step) * step + (step * 0.5 if int(absf(y) / step) % 2 == 0 else 0.0)
		while x < bounds.end.x:
			if _inside_rel(Vector2(x, y), 26.0):
				pattern_pts.append(Vector2(x, y))
			x += step
		y += step
	var count := int(bounds.get_area() / 7000.0)
	if layout == "rink":
		count = 0
	if layout == "rect":
		count = 6
	var tries := 0
	while deco.size() < count and tries < 2000:
		tries += 1
		var q := Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
		if not _inside_rel(q, 22.0):
			continue
		var kind: String = ["tuft", "tuft", "flower", "flower", "pebble", "mushroom"][randi() % 6]
		var flower_cols := [Color("ff5fa2"), Color("fff26b"), Color("ffffff"), Color("b28dff"), Color("ff8f5f")]
		deco.append({"p": q, "kind": kind, "s": randf_range(0.7, 1.25), "c": flower_cols[randi() % flower_cols.size()],
			"ph": randf() * TAU})
	# hanging rocks and vines under bottom-facing edges
	for poly in polys:
		var n := poly.size()
		for i in range(0, n, 3):
			var a := poly[(i - 1 + n) % n]
			var b := poly[(i + 1) % n]
			# polygons wind clockwise on screen, so orthogonal() points outward
			var normal := (b - a).orthogonal().normalized()
			if normal.y > 0.45 and randf() < 0.75:
				hangers.append({"p": poly[i], "w": randf_range(10, 26), "l": randf_range(20, 70),
					"vine": randf() < 0.35, "ph": randf() * TAU})


func _inside_rel(q: Vector2, margin: float) -> bool:
	if not _in_polys(q):
		return false
	if margin <= 0.0:
		return true
	for i in 8:
		if not _in_polys(q + Vector2.RIGHT.rotated(TAU * i / 8.0) * margin):
			return false
	return true


func _in_polys(q: Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(q, poly):
			return true
	return false


func is_on_ground(p: Vector2) -> bool:
	if walls:
		return true
	return _in_polys((p - center) / maxf(0.01, shrink))


func is_safe_point(p: Vector2, margin: float) -> bool:
	if walls:
		var r := Rect2(rink.position + center, rink.size).grow(-margin)
		return r.has_point(p)
	return _inside_rel((p - center) / maxf(0.01, shrink), margin / maxf(0.01, shrink))


func random_point(margin: float = 40.0) -> Vector2:
	for i in 300:
		var q := Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
		var p := center + q * shrink
		if is_safe_point(p, margin):
			return p
	return center


## Keeps a circle inside the rink walls. Returns [pos, vel, hit].
func collide_walls(pos: Vector2, vel: Vector2, r: float, can_enter_goal: bool) -> Array:
	var R := Rect2(rink.position + center, rink.size)
	var hit := false
	var bounce := 0.85
	var mouth := absf(pos.y - center.y) < goal_half - r * 0.25
	var in_pocket := pos.x < R.position.x or pos.x > R.end.x
	if in_pocket and can_enter_goal:
		var top := center.y - goal_half + r
		var bot := center.y + goal_half - r
		if pos.y < top:
			pos.y = top
			vel.y = absf(vel.y) * bounce
			hit = true
		elif pos.y > bot:
			pos.y = bot
			vel.y = -absf(vel.y) * bounce
			hit = true
		var back_l := R.position.x - goal_depth + r
		var back_r := R.end.x + goal_depth - r
		if pos.x < back_l:
			pos.x = back_l
			vel.x = absf(vel.x) * 0.4
		elif pos.x > back_r:
			pos.x = back_r
			vel.x = -absf(vel.x) * 0.4
		return [pos, vel, hit]
	if pos.y - r < R.position.y:
		pos.y = R.position.y + r
		vel.y = absf(vel.y) * bounce
		hit = true
	elif pos.y + r > R.end.y:
		pos.y = R.end.y - r
		vel.y = -absf(vel.y) * bounce
		hit = true
	if not (mouth and can_enter_goal):
		if pos.x - r < R.position.x:
			pos.x = R.position.x + r
			vel.x = absf(vel.x) * bounce
			hit = true
		elif pos.x + r > R.end.x:
			pos.x = R.end.x - r
			vel.x = -absf(vel.x) * bounce
			hit = true
	return [pos, vel, hit]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if polys.is_empty():
		return
	var e := clampf(appear, 0.0, 1.5)
	var rise := (1.0 - e) * 620.0
	var s := shrink
	var base := center + Vector2(0, rise + sin(t * 0.8) * 2.0)
	var side: Color = theme["side"]
	var side2: Color = theme["side2"]
	var top: Color = theme["top"]
	var top2: Color = theme["top2"]

	# soft shadow / glow beneath the island
	G.glow(self, base + Vector2(0, DEPTH + 90) * s, (bounds.size.x * 0.5 + 60) * s, Color(0, 0, 0, 0.18))

	# extruded cliff with strata
	for li in range(LAYERS, 0, -1):
		var k := float(li) / LAYERS
		var col := side.lerp(side2, k)
		if li % 3 == 0:
			col = col.darkened(0.12)
		draw_set_transform(base + Vector2(0, DEPTH * k * s), 0.0, Vector2(s, s))
		for poly in polys:
			draw_colored_polygon(poly, col)
	draw_set_transform(base, 0.0, Vector2(s, s))
	for h in hangers:
		var p: Vector2 = h["p"] + Vector2(0, DEPTH - 4)
		var w: float = h["w"]
		var l: float = h["l"]
		if h["vine"]:
			var pts := PackedVector2Array()
			for j in 8:
				var yy := l * 1.4 * j / 7.0
				pts.append(h["p"] + Vector2(sin(t * 1.5 + h["ph"] + j * 0.6) * 4.0, yy))
			draw_polyline(pts, top.darkened(0.3), 3.0)
			draw_circle(pts[pts.size() - 1], 4.0, top)
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-w, -2), p + Vector2(w, -2), p + Vector2(w * 0.2, l)]), side2.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, -2), p + Vector2(0, -2), p + Vector2(-w * 0.1, l * 0.7)]), side.darkened(0.1))

	# grassy rim and top surface
	for poly in rims:
		draw_colored_polygon(poly, top.darkened(0.38))
	for poly in polys:
		draw_colored_polygon(poly, top)
	for poly in inners:
		draw_colored_polygon(poly, top2)
	# subtle diamond pattern on the inner top
	var pattern_col := Color(top.darkened(0.08), 0.35)
	for q in pattern_pts:
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -9), q + Vector2(14, 0), q + Vector2(0, 9), q + Vector2(-14, 0)]), pattern_col)

	if icy > 0.01:
		for poly in inners:
			draw_colored_polygon(poly, Color(0.78, 0.94, 1.0, 0.6 * icy))
		for i in pattern_pts.size():
			var q := pattern_pts[i]
			var tw := sin(t * 2.5 + i * 1.7)
			if tw > 0.3:
				var k := (tw - 0.3) / 0.7
				var c := Color(1, 1, 1, 0.8 * k * icy)
				draw_line(q + Vector2(-7 * k, 0), q + Vector2(7 * k, 0), c, 2.0)
				draw_line(q + Vector2(0, -7 * k), q + Vector2(0, 7 * k), c, 2.0)

	for d in deco:
		_draw_deco(d, top)

	if walls:
		_draw_rink()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_deco(d: Dictionary, top: Color) -> void:
	var p: Vector2 = d["p"]
	var s: float = d["s"]
	match d["kind"]:
		"tuft":
			var sway := sin(t * 2.0 + d["ph"]) * 2.0
			var c := top.darkened(0.3)
			draw_line(p, p + Vector2(-5 + sway, -10) * s, c, 2.5)
			draw_line(p, p + Vector2(sway, -13) * s, c, 2.5)
			draw_line(p, p + Vector2(5 + sway, -10) * s, c, 2.5)
		"flower":
			var c: Color = d["c"]
			draw_line(p, p + Vector2(0, -8 * s), top.darkened(0.35), 2.0)
			var fc := p + Vector2(sin(t * 2.0 + d["ph"]) * 1.5, -9 * s)
			for k in 5:
				draw_circle(fc + Vector2.RIGHT.rotated(TAU * k / 5.0 + d["ph"]) * 4.0 * s, 3.2 * s, c)
			draw_circle(fc, 2.6 * s, Color("ffd23f"))
		"pebble":
			draw_circle(p + Vector2(1, 2), 5.5 * s, Color(0, 0, 0, 0.15))
			draw_circle(p, 5.0 * s, Color("c9c2d6"))
			draw_circle(p + Vector2(-1.5, -1.5), 2.0 * s, Color("eeeaf5"))
		"mushroom":
			draw_rect(Rect2(p + Vector2(-2.5, -8) * s, Vector2(5, 8) * s), Color("f4ead8"))
			draw_circle(p + Vector2(0, -9) * s, 7.0 * s, Color("ff5a5a"))
			draw_circle(p + Vector2(-3, -11) * s, 1.8 * s, Color.WHITE)
			draw_circle(p + Vector2(3, -9) * s, 1.4 * s, Color.WHITE)


func _rail(a: Vector2, b: Vector2, c1: Color, c2: Color) -> void:
	draw_line(a + Vector2(0, 6), b + Vector2(0, 6), Color(0, 0, 0, 0.25), 16.0)
	draw_line(a, b, c1.darkened(0.45), 16.0)
	draw_line(a, b, c1, 11.0)
	var ln := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, ln)
	var d := 0.0
	while d < ln - 12.0:
		draw_line(a + dir * d, a + dir * minf(d + 12.0, ln), c2, 11.0)
		d += 24.0
	draw_line(a + Vector2(0, -3), b + Vector2(0, -3), Color(1, 1, 1, 0.25), 3.0)


func _draw_rink() -> void:
	var R := rink
	var line_col := Color(1, 1, 1, 0.35)
	draw_line(Vector2(0, R.position.y), Vector2(0, R.end.y), line_col, 4.0)
	draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 48, line_col, 4.0)
	draw_circle(Vector2.ZERO, 8.0, line_col)
	for sgn in [-1.0, 1.0]:
		var gx: float = R.position.x if sgn < 0 else R.end.x
		var box := Rect2(Vector2(gx if sgn < 0 else gx - 110, -goal_half - 40), Vector2(110, (goal_half + 40) * 2))
		draw_rect(box, line_col, false, 4.0)
		draw_arc(Vector2(gx - sgn * 110, 0), 50.0, -PI * 0.5 if sgn < 0 else PI * 0.5, PI * 0.5 if sgn < 0 else PI * 1.5, 24, line_col, 4.0)
	# goals (left defended by player 1, right by player 2)
	for gi in 2:
		var sgn := -1.0 if gi == 0 else 1.0
		var gx := R.position.x if gi == 0 else R.end.x
		var pc: Color = G.P_COLORS[gi]
		var pocket := Rect2(Vector2(gx - goal_depth if gi == 0 else gx, -goal_half), Vector2(goal_depth, goal_half * 2))
		draw_rect(pocket, Color(0.05, 0.03, 0.1, 0.55))
		var i := 0.0
		while i <= goal_depth:
			draw_line(Vector2(pocket.position.x + i, -goal_half), Vector2(pocket.position.x + i, goal_half), Color(1, 1, 1, 0.25), 1.5)
			i += 10.0
		var j := -goal_half
		while j <= goal_half:
			draw_line(Vector2(pocket.position.x, j), Vector2(pocket.end.x, j), Color(1, 1, 1, 0.25), 1.5)
			j += 10.0
		G.glow(self, Vector2(gx + sgn * goal_depth * 0.5, 0), goal_half * 1.4, Color(pc, 0.25 + 0.1 * sin(t * 3.0)))
		var back := gx + sgn * goal_depth
		_rail(Vector2(gx, -goal_half), Vector2(back, -goal_half), pc, Color.WHITE)
		_rail(Vector2(gx, goal_half), Vector2(back, goal_half), pc, Color.WHITE)
		_rail(Vector2(back, -goal_half), Vector2(back, goal_half), pc, Color.WHITE)
		draw_circle(Vector2(gx, -goal_half), 10.0, pc.darkened(0.3))
		draw_circle(Vector2(gx, goal_half), 10.0, pc.darkened(0.3))
	var rc := Color("ffffff")
	var rc2 := Color("ff5d8f")
	_rail(R.position, Vector2(R.end.x, R.position.y), rc, rc2)
	_rail(Vector2(R.position.x, R.end.y), R.end, rc, rc2)
	_rail(R.position, Vector2(R.position.x, -goal_half), rc, rc2)
	_rail(Vector2(R.position.x, goal_half), Vector2(R.position.x, R.end.y), rc, rc2)
	_rail(Vector2(R.end.x, R.position.y), Vector2(R.end.x, -goal_half), rc, rc2)
	_rail(Vector2(R.end.x, goal_half), R.end, rc, rc2)
