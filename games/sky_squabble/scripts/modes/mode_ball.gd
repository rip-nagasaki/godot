extends "res://scripts/modes/mode_base.gd"
## Goal Rush: bonk the ball into the rival's goal. Mango defends the left goal.

const BR := 20.0
const TARGET := 3

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var h := 0.0
var vh := 0.0
var spin := 0.0
var last := -1
var goal_pause := -1.0
var trail_t := 0.0


func _init() -> void:
	id = "ball"
	title = "Goal Rush"
	rule = "Bash the ball into your rival's goal! First to 3."
	layout = "rink"
	time_limit = 60.0


func spawn_point(i: int) -> Vector2:
	return game.arena.center + Vector2(-250.0 if i == 0 else 250.0, 0.0)


func setup() -> void:
	_reset_ball()


func _reset_ball() -> void:
	pos = game.arena.center
	vel = Vector2.ZERO
	h = 520.0
	vh = 0.0
	last = -1


func update(dt: float) -> void:
	t += dt
	if goal_pause > 0.0:
		goal_pause -= dt
		if goal_pause <= 0.0 and not finished:
			for b in game.blobs:
				b.reset_for_round()
				b.frozen = false
				b.drop_in(spawn_point(b.idx), 420.0)
			_reset_ball()
		return
	if h > 0.0 or vh != 0.0:
		vh -= 1600.0 * dt
		h += vh * dt
		if h <= 0.0:
			h = 0.0
			if vh < -200.0:
				vh = -vh * 0.45
				Sfx.play("bump", -6.0, 1.4)
			else:
				vh = 0.0
	var friction := 0.25 if game.twist.id == "ice" else 0.75
	vel *= exp(-friction * dt)
	vel += (game.twist.wind as Vector2) * dt * 1.3
	pos += vel * dt
	spin += vel.length() * dt / BR
	var res: Array = game.arena.collide_walls(pos, vel, BR, true)
	pos = res[0]
	vel = res[1]
	if res[2] and vel.length() > 250.0:
		Sfx.play("bump", -8.0, 1.5)
		game.fx.sparks(pos, Color.WHITE, 4, 200.0)
	res = game.twist.collide_circle(pos, vel, BR)
	pos = res[0]
	vel = res[1]
	if h < 30.0:
		for b in game.blobs:
			if not b.is_active():
				continue
			var d: Vector2 = pos - b.position
			var dist := d.length()
			var min_d: float = BR + b.radius
			if dist < min_d:
				var n := d / dist if dist > 0.01 else Vector2.RIGHT
				pos = b.position + n * min_d
				var rel: float = (vel - b.vel).dot(n)
				if rel < 0.0:
					vel -= n * rel * 1.7
				if b.is_dashing():
					vel = n * maxf(vel.length(), 1050.0 * game.twist.power_mult()) + b.vel * 0.2
					game.fx.sparks(pos, b.color.lightened(0.4), 12, 500.0, n, PI * 0.7)
					game.fx.ring(pos, Color.WHITE, 8.0, 50.0, 0.25, 5.0)
					Sfx.play("bonk", -4.0, 1.5)
					game.shake(5.0)
				elif absf(rel) > 120.0:
					Sfx.play("bump", -8.0, 1.3)
				last = b.idx
	if vel.length() > 1400.0:
		vel = vel.normalized() * 1400.0
	trail_t -= dt
	if trail_t <= 0.0 and vel.length() > 450.0:
		trail_t = 0.015
		var tc := Color.WHITE if last < 0 else G.P_COLORS[last].lightened(0.3)
		game.fx.trail_dot(pos + Vector2(0, -BR - h), tc, BR * 0.8, 0.25)
	var R := Rect2(game.arena.rink.position + game.arena.center, game.arena.rink.size)
	if pos.x < R.position.x - BR * 0.6:
		_goal(1)
	elif pos.x > R.end.x + BR * 0.6:
		_goal(0)


func _goal(scorer: int) -> void:
	scores[scorer] += 1
	goal_pause = 1.8
	Sfx.play("goal", 0.0)
	game.shake(16.0)
	game.fx.confetti(pos, [G.P_COLORS[scorer], G.P_LIGHT[scorer], Color.WHITE, Color("ffe066")], 70, 650.0)
	game.fx.explosion(pos, 0.6)
	game.banner("GOAL!", G.P_COLORS[scorer].lightened(0.2), 1.4, 90)
	vel = Vector2.ZERO
	for b in game.blobs:
		b.frozen = true
	game.blobs[scorer].celebrate = true
	if scores[scorer] >= TARGET:
		finish(scorer)
	elif overtime:
		finish(scorer)


func light_points() -> Array:
	return [[pos + Vector2(0, -h), 140.0]]


func draw_ground(ci: CanvasItem) -> void:
	if goal_pause > 0.0 and goal_pause < 1.6:
		return
	var k := clampf(1.0 - h / 520.0, 0.2, 1.0)
	ci.draw_set_transform(pos + Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, BR * 1.1 * k, Color(0, 0, 0, 0.3 * k))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := pos + Vector2(0, -BR - h)
	ci.draw_circle(c, BR + 3.0, Color("2a2440"))
	ci.draw_circle(c, BR, Color("fdfbff"))
	# rolling stripes
	var ang := vel.angle() if vel.length() > 1.0 else 0.0
	for i in 3:
		var off := fmod(spin * 0.5 + i / 3.0, 1.0) * 2.0 - 1.0
		var x := off * BR
		var hw := sqrt(maxf(0.0, BR * BR - x * x))
		var a := c + Vector2(x, -hw).rotated(ang)
		var b := c + Vector2(x, hw).rotated(ang)
		ci.draw_line(a, b, Color("ff5d8f") if i % 2 == 0 else Color("3dd6d0"), 4.0)
	ci.draw_circle(c + Vector2(-6, -7), 5.0, Color(1, 1, 1, 0.9))


func draw_glow(ci: CanvasItem) -> void:
	G.glow(ci, pos + Vector2(0, -BR - h), 40.0, Color(1, 1, 1, 0.25))


func draw_hud(ci: CanvasItem) -> void:
	for i in 2:
		var cx := 590.0 if i == 0 else 690.0
		var r := Rect2(cx - 32, 108, 64, 40)
		ci.draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
		ci.draw_rect(r, G.P_DARK[i])
		G.text(ci, Vector2(cx, 128), str(int(scores[i])), 30, Color.WHITE, 4)
	G.text(ci, Vector2(640, 128), ":", 30, Color.WHITE, 4)


func draw_icon(ci: CanvasItem, p: Vector2, s: float, tt: float) -> void:
	ci.draw_rect(Rect2(p + Vector2(22, -28) * s, Vector2(22, 56) * s), Color(1, 1, 1, 0.3))
	ci.draw_rect(Rect2(p + Vector2(22, -28) * s, Vector2(22, 56) * s), Color.WHITE, false, 3.0 * s)
	var bp := p + Vector2(-24 + fmod(tt * 40.0, 50.0), sin(tt * 6.0) * 4.0) * s
	ci.draw_circle(bp, 17.0 * s, Color("2a2440"))
	ci.draw_circle(bp, 14.0 * s, Color.WHITE)
	ci.draw_line(bp + Vector2(-4, -13) * s, bp + Vector2(-4, 13) * s, Color("ff5d8f"), 3.0 * s)
