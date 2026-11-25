extends Node2D
## Lightweight particle system drawn with _draw(). Particles flagged as glow are
## rendered by an additive child layer for a bright, juicy look.

enum { DOT, SPARK, RING, CONFETTI, STAR, TEXT, SMOKE, GLOW }


class P:
	var kind := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var max_life := 1.0
	var size := 4.0
	var size2 := 0.0
	var color := Color.WHITE
	var gravity := 0.0
	var drag := 0.0
	var rot := 0.0
	var spin := 0.0
	var glow := false
	var label := ""


var parts: Array[P] = []
var glow_layer: Node2D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	glow_layer = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = mat
	glow_layer.z_index = 1
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)


func clear() -> void:
	parts.clear()


func _process(delta: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var p := parts[i]
		p.life -= delta
		if p.life <= 0.0:
			parts.remove_at(i)
		else:
			p.vel.y += p.gravity * delta
			if p.drag > 0.0:
				p.vel *= exp(-p.drag * delta)
			p.pos += p.vel * delta
			p.rot += p.spin * delta
		i -= 1
	queue_redraw()
	glow_layer.queue_redraw()


func _add(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color) -> P:
	var p := P.new()
	p.kind = kind
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.color = color
	if parts.size() > 1400:
		parts.remove_at(0)
	parts.append(p)
	return p


func _rand_dir() -> Vector2:
	return Vector2.RIGHT.rotated(rng.randf() * TAU)


# ---------------------------------------------------------------- emitters

func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 260.0, size: float = 6.0, life: float = 0.6) -> void:
	for i in count:
		var p := _add(DOT, pos, _rand_dir() * speed * rng.randf_range(0.3, 1.0), life * rng.randf_range(0.6, 1.2),
			size * rng.randf_range(0.6, 1.3), color)
		p.drag = 3.0


func sparks(pos: Vector2, color: Color, count: int = 12, speed: float = 520.0, dir: Vector2 = Vector2.ZERO, spread: float = PI) -> void:
	for i in count:
		var d := _rand_dir()
		if dir != Vector2.ZERO:
			d = dir.normalized().rotated(rng.randf_range(-spread, spread) * 0.5)
		var p := _add(SPARK, pos, d * speed * rng.randf_range(0.4, 1.0), rng.randf_range(0.2, 0.45), rng.randf_range(2.0, 4.0), color)
		p.drag = 4.0
		p.glow = true


func ring(pos: Vector2, color: Color, r0: float = 10.0, r1: float = 90.0, life: float = 0.45, width: float = 6.0) -> void:
	var p := _add(RING, pos, Vector2.ZERO, life, r0, color)
	p.size2 = r1
	p.rot = width


func confetti(pos: Vector2, colors: Array, count: int = 40, speed: float = 520.0) -> void:
	for i in count:
		var v := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.6, -0.4)).normalized() * speed * rng.randf_range(0.4, 1.1)
		var p := _add(CONFETTI, pos, v, rng.randf_range(1.4, 2.6), rng.randf_range(5.0, 9.0), colors[rng.randi() % colors.size()])
		p.gravity = 520.0
		p.drag = 1.6
		p.spin = rng.randf_range(-12.0, 12.0)
		p.rot = rng.randf() * TAU


func confetti_rain(colors: Array, count: int = 60) -> void:
	for i in count:
		var p := _add(CONFETTI, Vector2(rng.randf_range(0, 1280), rng.randf_range(-200, -10)),
			Vector2(rng.randf_range(-60, 60), rng.randf_range(60, 200)), rng.randf_range(3.0, 4.5),
			rng.randf_range(5.0, 9.0), colors[rng.randi() % colors.size()])
		p.gravity = 60.0
		p.spin = rng.randf_range(-10.0, 10.0)
		p.rot = rng.randf() * TAU


func stars(pos: Vector2, color: Color, count: int = 6, speed: float = 200.0) -> void:
	for i in count:
		var p := _add(STAR, pos, _rand_dir() * speed * rng.randf_range(0.4, 1.0), rng.randf_range(0.5, 0.9),
			rng.randf_range(5.0, 9.0), color)
		p.drag = 3.0
		p.spin = rng.randf_range(-6.0, 6.0)


func smoke(pos: Vector2, color: Color, count: int = 8, speed: float = 120.0, size: float = 22.0) -> void:
	for i in count:
		var p := _add(SMOKE, pos + _rand_dir() * rng.randf() * 10.0, _rand_dir() * speed * rng.randf_range(0.3, 1.0),
			rng.randf_range(0.6, 1.1), size * rng.randf_range(0.6, 1.2), color)
		p.drag = 2.5
		p.gravity = -40.0


func glow_puff(pos: Vector2, color: Color, size: float = 80.0, life: float = 0.35) -> void:
	var p := _add(GLOW, pos, Vector2.ZERO, life, size, color)
	p.glow = true


func popup(pos: Vector2, label: String, color: Color, size: float = 30.0) -> void:
	var p := _add(TEXT, pos, Vector2(0, -70), 1.1, size, color)
	p.label = label
	p.drag = 2.0


func streak(pos: Vector2, vel: Vector2, color: Color, life: float) -> void:
	_add(SPARK, pos, vel, life, 2.5, color)


func drift(pos: Vector2, vel: Vector2, color: Color, size: float, life: float) -> void:
	_add(DOT, pos, vel, life, size, color)


func trail_dot(pos: Vector2, color: Color, size: float, life: float = 0.25) -> void:
	var p := _add(DOT, pos, Vector2.ZERO, life, size, color)
	p.glow = true


func explosion(pos: Vector2, scale_f: float = 1.0) -> void:
	glow_puff(pos, Color(1.0, 0.7, 0.3), 260.0 * scale_f, 0.5)
	ring(pos, Color(1.0, 0.9, 0.6), 20.0, 220.0 * scale_f, 0.5, 14.0)
	ring(pos, Color(1.0, 0.5, 0.2), 10.0, 150.0 * scale_f, 0.65, 8.0)
	sparks(pos, Color(1.0, 0.8, 0.3), int(40 * scale_f), 900.0 * scale_f)
	smoke(pos, Color(0.25, 0.2, 0.28, 0.9), int(16 * scale_f), 260.0 * scale_f, 34.0 * scale_f)
	burst(pos, Color(1.0, 0.55, 0.15), int(24 * scale_f), 500.0 * scale_f, 9.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for p in parts:
		if not p.glow:
			_draw_particle(self, p)


func _draw_glow() -> void:
	for p in parts:
		if p.glow:
			_draw_particle(glow_layer, p)


func _draw_particle(ci: CanvasItem, p: P) -> void:
	var k := p.life / p.max_life
	var c := p.color
	match p.kind:
		DOT:
			c.a *= minf(1.0, k * 2.0)
			ci.draw_circle(p.pos, maxf(0.5, p.size * (0.4 + 0.6 * k)), c)
		SPARK:
			c.a *= k
			ci.draw_line(p.pos, p.pos - p.vel * 0.045, c, p.size * k + 0.5)
		RING:
			var e := 1.0 - pow(k, 2.0)
			var r := lerpf(p.size, p.size2, e)
			c.a *= k
			ci.draw_arc(p.pos, r, 0.0, TAU, 48, c, maxf(1.0, p.rot * k))
		CONFETTI:
			c.a *= minf(1.0, k * 3.0)
			var flutter := absf(sin(p.rot * 1.3))
			ci.draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.25 + flutter * 0.75))
			ci.draw_rect(Rect2(-p.size * 0.5, -p.size * 0.35, p.size, p.size * 0.7), c)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		STAR:
			c.a *= minf(1.0, k * 2.0)
			ci.draw_colored_polygon(G.star_points(p.pos, p.size * (0.5 + 0.5 * k), p.size * 0.45, 5, p.rot), c)
		TEXT:
			c.a *= minf(1.0, k * 3.0)
			var s := 1.0 + maxf(0.0, (k - 0.8)) * 3.0
			ci.draw_set_transform(p.pos, 0.0, Vector2(s, s))
			G.text(ci, Vector2.ZERO, p.label, int(p.size), c, 6, Color(0, 0, 0, 0.6 * c.a))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		SMOKE:
			c.a *= k * 0.7
			ci.draw_circle(p.pos, p.size * (1.6 - k * 0.6), c)
		GLOW:
			c.a *= k
			G.glow(ci, p.pos, p.size * (1.2 - 0.4 * k), c)
