extends Node2D
## Distant floating islands and glowing sky lanterns drifting behind the arena.

var theme: Dictionary = G.THEMES[0]
var islands: Array[Dictionary] = []
var lanterns: Array[Dictionary] = []
var t := 0.0
var glow_node: Node2D


func _ready() -> void:
	for i in 7:
		islands.append({"x": randf_range(-80.0, 1360.0), "y": randf_range(150.0, 560.0), "s": randf_range(0.35, 1.0),
			"speed": randf_range(4.0, 12.0) * (1.0 if randf() < 0.5 else -1.0), "ph": randf() * TAU,
			"trees": randi() % 4})
	islands.sort_custom(func(a, b): return a["s"] < b["s"])
	for i in 24:
		lanterns.append({"x": randf_range(0.0, 1280.0), "y": randf_range(0.0, 800.0), "s": randf_range(0.45, 1.1),
			"speed": randf_range(10.0, 28.0), "ph": randf() * TAU})
	glow_node = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_node.material = mat
	add_child(glow_node)
	glow_node.draw.connect(_draw_glow)


func _process(delta: float) -> void:
	t += delta
	for isl in islands:
		isl["x"] += isl["speed"] * isl["s"] * delta
		if isl["x"] > 1400.0:
			isl["x"] = -120.0
		elif isl["x"] < -120.0:
			isl["x"] = 1400.0
	for l in lanterns:
		l["y"] -= l["speed"] * l["s"] * delta
		if l["y"] < -40.0:
			l["y"] = 780.0
			l["x"] = randf_range(0.0, 1280.0)
	queue_redraw()
	glow_node.queue_redraw()


func _lantern_pos(l: Dictionary) -> Vector2:
	return Vector2(l["x"] + sin(t * 0.8 + l["ph"]) * 14.0, l["y"])


func _draw() -> void:
	var far: Color = theme["far"]
	var mid: Color = theme["sky_mid"]
	for isl in islands:
		var s: float = isl["s"]
		var col := mid.lerp(far, 0.35 + s * 0.6)
		var p := Vector2(isl["x"], isl["y"] + sin(t * 0.6 + isl["ph"]) * 6.0)
		var under := PackedVector2Array([
			p + Vector2(-70, 0) * s, p + Vector2(-48, 26) * s, p + Vector2(-20, 58) * s, p + Vector2(-4, 96) * s,
			p + Vector2(12, 62) * s, p + Vector2(40, 30) * s, p + Vector2(70, 0) * s])
		draw_colored_polygon(under, col.darkened(0.15))
		draw_set_transform(p, 0.0, Vector2(70.0 * s, 16.0 * s))
		draw_circle(Vector2.ZERO, 1.0, col.lightened(0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in isl["trees"]:
			var tp := p + Vector2((-30 + k * 22) * s, -6 * s)
			draw_line(tp, tp + Vector2(0, -16) * s, col.darkened(0.2), maxf(1.0, 3.0 * s))
			draw_circle(tp + Vector2(0, -20) * s, 11.0 * s, col.lightened(0.05))
	var lc: Color = theme["lantern"]
	for l in lanterns:
		var s: float = l["s"]
		var p := _lantern_pos(l)
		draw_set_transform(p, sin(t * 0.8 + l["ph"]) * 0.12, Vector2(7.0 * s, 9.0 * s))
		draw_circle(Vector2.ZERO, 1.0, lc.lightened(0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(p + Vector2(-4, -10) * s, Vector2(8, 3) * s), lc.darkened(0.4))
		draw_rect(Rect2(p + Vector2(-4, 7) * s, Vector2(8, 3) * s), lc.darkened(0.4))


func _draw_glow() -> void:
	var lc: Color = theme["lantern"]
	for l in lanterns:
		var s: float = l["s"]
		var flick := 0.8 + 0.2 * sin(t * 6.0 + l["ph"] * 3.0)
		G.glow(glow_node, _lantern_pos(l), 30.0 * s, Color(lc, 0.55 * flick))
