extends Node2D
## A squishy jelly fighter. Position is the point on the ground under the blob.

enum { ALIVE, FALLING, GONE, DROPPING }

const BASE_SPEED := 340.0
const DASH_SPEED := 980.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 0.8

var game
var idx := 0
var color := Color.WHITE
var dark := Color.BLACK
var light := Color.WHITE

var state := ALIVE
var vel := Vector2.ZERO
var base_radius := 26.0
var radius := 26.0
var facing := Vector2.RIGHT
var input_dir := Vector2.ZERO
var dash_t := 0.0
var dash_cd := 0.0
var dash_cd_max := DASH_COOLDOWN
var stun := 0.0
var invuln := 0.0
var fall_t := 0.0
var fall_vel := Vector2.ZERO
var drop_h := 0.0
var drop_start := 1.0
var drop_vh := 0.0
var land_invuln := 0.0
var respawn_timer := -1.0
var frozen := true
var speed_mult := 1.0
var power := 1.0
var hit_this_dash := false

# Visual state
var t := 0.0
var wobble := 0.0
var wobble_v := 0.0
var hop := 0.0
var blink := 0.0
var next_blink := 2.0
var face := ""
var face_t := 0.0
var trail: Array[Vector2] = []
var celebrate := false
var sad := false
var look := Vector2.ZERO


func setup(g, i: int) -> void:
	game = g
	idx = i
	color = G.P_COLORS[i]
	dark = G.P_DARK[i]
	light = G.P_LIGHT[i]
	facing = Vector2.RIGHT if i == 0 else Vector2.LEFT
	next_blink = randf_range(1.0, 3.0)


func is_active() -> bool:
	return state == ALIVE


func is_dashing() -> bool:
	return state == ALIVE and dash_t > 0.0


func reset_for_round() -> void:
	vel = Vector2.ZERO
	dash_t = 0.0
	dash_cd = 0.0
	stun = 0.0
	invuln = 0.0
	respawn_timer = -1.0
	speed_mult = 1.0
	celebrate = false
	sad = false
	face = ""
	trail.clear()
	z_index = 0


func drop_in(at: Vector2, height: float = 560.0, invuln_after: float = 0.0) -> void:
	position = at
	state = DROPPING
	drop_h = height
	drop_start = maxf(1.0, height)
	drop_vh = 0.0
	vel = Vector2.ZERO
	dash_t = 0.0
	stun = 0.0
	z_index = 0
	land_invuln = invuln_after
	trail.clear()


func start_fall() -> void:
	if state != ALIVE:
		return
	state = FALLING
	fall_t = 0.0
	fall_vel = vel * 0.6
	dash_t = 0.0
	face = "ouch"
	face_t = 2.0
	z_index = -3 if position.y < game.arena.center.y + 20.0 else 0
	Sfx.play("fall", -2.0)


func take_hit(knock: Vector2, stun_time: float) -> void:
	vel = knock
	stun = stun_time
	dash_t = 0.0
	wobble_v += 40.0
	face = "ouch"
	face_t = 0.5


func _state_offset() -> Vector2:
	if state == DROPPING:
		return Vector2(0, -drop_h)
	if state == FALLING:
		return Vector2(0, fall_t * fall_t * 700.0)
	return Vector2.ZERO


func head_pos() -> Vector2:
	return position + _state_offset() + Vector2(0, -radius * 0.45 - _hop_offset() - radius * 1.05)


func body_center() -> Vector2:
	return position + _state_offset() + Vector2(0, -radius * 0.45 - _hop_offset())


func _hop_offset() -> float:
	if celebrate:
		return absf(sin(t * 7.0)) * 26.0
	if state == ALIVE and vel.length() > 60.0 and dash_t <= 0.0:
		return absf(sin(hop)) * 6.0
	return 0.0


## params: speed, control, dash_cd, wind, radius
func step(dt: float, params: Dictionary) -> void:
	t += dt
	face_t -= dt
	if face_t <= 0.0:
		face = ""
	blink -= dt
	next_blink -= dt
	if next_blink <= 0.0:
		blink = 0.12
		next_blink = randf_range(1.5, 4.0)
	# jelly spring
	wobble_v += (-wobble * 180.0 - wobble_v * 9.0) * dt
	wobble += wobble_v * dt
	radius = lerpf(radius, base_radius * float(params.get("radius", 1.0)), minf(1.0, dt * 6.0))

	match state:
		DROPPING:
			drop_vh += 2200.0 * dt
			drop_h -= drop_vh * dt
			if drop_h <= 0.0:
				_land()
		FALLING:
			fall_t += dt
			position += fall_vel * dt
			fall_vel *= exp(-1.5 * dt)
			if fall_t > 0.9:
				state = GONE
		GONE:
			if respawn_timer > 0.0:
				respawn_timer -= dt
				if respawn_timer <= 0.0:
					respawn_timer = -1.0
					game.respawn_blob(self)
		ALIVE:
			_move(dt, params)
	queue_redraw()


func _land() -> void:
	state = ALIVE
	drop_h = 0.0
	invuln = land_invuln
	wobble_v -= 60.0
	Sfx.play("land", -4.0)
	game.fx.ring(position, Color(1, 1, 1, 0.7), 8.0, 50.0, 0.35, 5.0)
	game.fx.smoke(position, Color(1, 1, 1, 0.5), 6, 120.0, 12.0)
	game.shake(3.0)


func _move(dt: float, params: Dictionary) -> void:
	dash_cd -= dt
	stun -= dt
	invuln -= dt
	input_dir = Vector2.ZERO
	if not frozen:
		input_dir = Input.get_vector("p%d_left" % idx, "p%d_right" % idx, "p%d_up" % idx, "p%d_down" % idx)
	if input_dir.length() > 0.15:
		facing = input_dir.normalized()
	look = look.lerp(facing if input_dir.length() > 0.15 else facing * 0.4, minf(1.0, dt * 10.0))

	var spd: float = BASE_SPEED * float(params.get("speed", 1.0)) * speed_mult
	var control: float = 9.0 * float(params.get("control", 1.0))
	if stun > 0.0:
		control *= 0.1
	if dash_t > 0.0:
		dash_t -= dt
		control = 0.0
		trail.append(position)
		if trail.size() > 7:
			trail.remove_at(0)
		game.fx.trail_dot(body_center(), color.lightened(0.2), radius * 0.6, 0.22)
		if dash_t <= 0.0:
			vel *= 0.55
	elif trail.size() > 0:
		trail.remove_at(0)

	var desired := input_dir * spd
	vel += (desired - vel) * minf(1.0, control * dt)
	vel += (params.get("wind", Vector2.ZERO) as Vector2) * dt
	position += vel * dt
	if vel.length() > 60.0:
		hop += dt * 16.0

	if not frozen and stun <= 0.0 and dash_cd <= 0.0 and Input.is_action_just_pressed("p%d_dash" % idx):
		_start_dash(params)


func _start_dash(params: Dictionary) -> void:
	var dir := input_dir.normalized() if input_dir.length() > 0.2 else facing
	facing = dir
	vel = dir * DASH_SPEED * sqrt(float(params.get("speed", 1.0)))
	dash_t = DASH_TIME
	dash_cd_max = DASH_COOLDOWN * float(params.get("dash_cd", 1.0))
	dash_cd = dash_cd_max
	hit_this_dash = false
	wobble_v += 25.0
	Sfx.play("dash", -6.0)
	game.fx.ring(position, Color(color, 0.8), 6.0, 40.0, 0.25, 4.0)
	game.fx.smoke(position, Color(1, 1, 1, 0.35), 4, 80.0, 9.0)


# ---------------------------------------------------------------- drawing

func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	draw_set_transform(c, rot, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _body_poly(center: Vector2, r: float, stretch: float, dir: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 30
	var ang := dir.angle()
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a), sin(a)) * r * (1.0 + 0.035 * sin(a * 3.0 + t * 7.0) * (1.0 + absf(wobble) * 0.08))
		# squash and stretch along movement direction
		p = p.rotated(-ang)
		p.x *= 1.0 + stretch
		p.y *= 1.0 - stretch * 0.55
		p = p.rotated(ang)
		# jelly wobble: vertical squish
		p.y *= 1.0 + wobble * 0.008
		p.x *= 1.0 - wobble * 0.006
		# flat-ish bottom
		if p.y > r * 0.55:
			p.y = lerpf(p.y, r * 0.55, 0.5)
		pts.append(center + p)
	return pts


func _draw() -> void:
	if state == GONE:
		return
	var r := radius
	var off := Vector2.ZERO
	var sc := 1.0
	var alpha := 1.0
	if state == FALLING:
		off.y = fall_t * fall_t * 700.0
		sc = maxf(0.15, 1.0 - fall_t * 0.85)
		alpha = clampf(1.2 - fall_t * 1.2, 0.0, 1.0)
	elif state == DROPPING:
		off.y = -drop_h
	if invuln > 0.0 and int(invuln * 14.0) % 2 == 0:
		alpha *= 0.45

	# shadow
	if state != FALLING:
		var k := 1.0
		if state == DROPPING:
			k = clampf(1.0 - drop_h / drop_start, 0.2, 1.0)
		_ellipse(Vector2(0, r * 0.12), r * 1.05 * k, r * 0.42 * k, Color(0, 0, 0, 0.28 * k))

	# dash cooldown ring at the feet
	if state == ALIVE and not frozen:
		var ready_k := 1.0 - clampf(dash_cd / maxf(0.01, dash_cd_max), 0.0, 1.0)
		var ring_col := Color(color.lightened(0.3), 0.55 if ready_k >= 1.0 else 0.25)
		draw_set_transform(Vector2(0, r * 0.12), 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, r * 1.25, -PI * 0.5, -PI * 0.5 + TAU * ready_k, 32, ring_col, 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# dash afterimages
	for i in trail.size():
		var k2 := float(i + 1) / (trail.size() + 1)
		draw_circle(trail[i] - position + Vector2(0, -r * 0.45), r * (0.55 + 0.4 * k2), Color(color, 0.18 * k2 * alpha))

	var center := off + Vector2(0, (-r * 0.45 - _hop_offset()) * sc)
	var speed := vel.length()
	var stretch := clampf(speed / 1400.0, 0.0, 0.3)
	if dash_t > 0.0:
		stretch = 0.38
	if state == DROPPING:
		stretch = clampf(drop_vh / 2500.0, 0.0, 0.35)
	var sdir := vel.normalized() if speed > 1.0 else Vector2.RIGHT
	if state == DROPPING:
		sdir = Vector2.DOWN
	var rr := r * sc

	var outline := _body_poly(center, rr + 3.5, stretch, sdir)
	var body := _body_poly(center, rr, stretch, sdir)
	draw_colored_polygon(outline, Color(dark, alpha))
	draw_colored_polygon(body, Color(color, alpha))
	# belly shading and rim light
	var belly := _body_poly(center + Vector2(0, rr * 0.22), rr * 0.68, stretch * 0.5, sdir)
	draw_colored_polygon(belly, Color(color.lerp(light, 0.35), alpha * 0.7))
	_ellipse(center + Vector2(-rr * 0.38, -rr * 0.45), rr * 0.32, rr * 0.18, Color(1, 1, 1, 0.55 * alpha), -0.5)
	draw_circle(center + Vector2(-rr * 0.05, -rr * 0.62), rr * 0.07, Color(1, 1, 1, 0.7 * alpha))

	_draw_face(center, rr, alpha)

	# dizzy stars
	if state == ALIVE and stun > 0.05:
		for i in 3:
			var a := t * 7.0 + TAU * i / 3.0
			var p := center + Vector2(cos(a) * rr * 0.9, -rr * 1.05 + sin(a) * rr * 0.25)
			draw_colored_polygon(G.star_points(p, 6.0, 2.6, 5, a), Color(1, 0.95, 0.4, alpha))


func _draw_face(center: Vector2, rr: float, alpha: float) -> void:
	var lk := look * rr * 0.16
	var eye_y := center.y - rr * 0.1
	var spacing := rr * 0.36
	var ink := Color(0.13, 0.07, 0.16, alpha)
	var f := face
	if celebrate:
		f = "win"
	elif sad:
		f = "sad"
	elif state == ALIVE and stun > 0.05:
		f = "dizzy"
	for side in [-1, 1]:
		var ec := Vector2(center.x + side * spacing + lk.x, eye_y + lk.y)
		match f:
			"ouch":
				draw_line(ec + Vector2(-5, -5), ec + Vector2(5, 0), ink, 3.5)
				draw_line(ec + Vector2(-5, 5), ec + Vector2(5, 0), ink, 3.5)
			"win":
				draw_arc(ec + Vector2(0, 3), rr * 0.17, PI * 1.1, PI * 1.9, 10, ink, 3.5)
			"dizzy":
				draw_arc(ec, rr * 0.14, t * 10.0, t * 10.0 + PI * 1.5, 10, ink, 2.5)
				draw_arc(ec, rr * 0.06, t * 10.0 + PI, t * 10.0 + PI * 2.5, 8, ink, 2.0)
			_:
				var bl := 0.15 if blink > 0.0 else 1.0
				_ellipse(ec, rr * 0.2, rr * 0.25 * bl, Color(1, 1, 1, alpha))
				if bl > 0.5:
					var pupil := ec + look * rr * 0.07 + Vector2(0, rr * 0.03)
					_ellipse(pupil, rr * 0.11, rr * 0.14, ink)
					draw_circle(pupil + Vector2(-rr * 0.04, -rr * 0.05), rr * 0.04, Color(1, 1, 1, alpha))
				if f == "sad":
					draw_line(ec + Vector2(-rr * 0.2, -rr * 0.32 - side * 3.0), ec + Vector2(rr * 0.2, -rr * 0.32 + side * 3.0), ink, 3.0)
	# cheeks
	_ellipse(Vector2(center.x - spacing * 1.45 + lk.x, eye_y + rr * 0.28), rr * 0.13, rr * 0.08, Color(1, 0.35, 0.5, 0.35 * alpha))
	_ellipse(Vector2(center.x + spacing * 1.45 + lk.x, eye_y + rr * 0.28), rr * 0.13, rr * 0.08, Color(1, 0.35, 0.5, 0.35 * alpha))
	# mouth
	var mc := Vector2(center.x + lk.x * 1.2, eye_y + rr * 0.36 + lk.y)
	match f:
		"ouch", "dizzy":
			_ellipse(mc, rr * 0.1, rr * 0.13, ink)
		"win":
			draw_arc(mc + Vector2(0, -rr * 0.06), rr * 0.2, 0.1, PI - 0.1, 12, ink, 3.0)
			_ellipse(mc + Vector2(0, rr * 0.04), rr * 0.13, rr * 0.08, Color(1, 0.45, 0.5, alpha))
		"sad":
			draw_arc(mc + Vector2(0, rr * 0.12), rr * 0.14, PI + 0.3, TAU - 0.3, 10, ink, 3.0)
		_:
			if dash_t > 0.0:
				_ellipse(mc, rr * 0.12, rr * 0.08, ink)
			else:
				draw_arc(mc + Vector2(0, -rr * 0.05), rr * 0.13, 0.25, PI - 0.25, 10, ink, 3.0)
