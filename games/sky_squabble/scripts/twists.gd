extends RefCounted
## Round modifiers ("twists") that shake up every mini-game.

const DEFS := {
	"calm": ["Clear Skies", "No surprises... for now."],
	"ice": ["Frozen Floor", "Super slippery! Hard to stop."],
	"wind": ["Gusty Gale", "Strong winds push everyone around."],
	"bumpers": ["Bumper Bash", "Bouncy bumpers fling you away!"],
	"meteors": ["Meteor Shower", "Watch the sky and dodge the rocks!"],
	"turbo": ["Turbo Rush", "Everything is super fast!"],
	"giant": ["Giant Jellies", "You're HUGE and hit harder."],
	"dark": ["Lights Out", "It's dark... stay near the light!"],
}

var game
var id := "calm"
var title := ""
var desc := ""
var t := 0.0
var wind := Vector2.ZERO
var wind_target := Vector2.ZERO
var wind_change := 0.0
var bumpers: Array[Dictionary] = []
var meteors: Array[Dictionary] = []
var scorches: Array[Dictionary] = []
var meteor_timer := 2.5
var fx_timer := 0.0


func setup(g, twist_id: String) -> void:
	game = g
	id = twist_id
	title = DEFS[id][0]
	desc = DEFS[id][1]
	t = 0.0
	match id:
		"wind":
			wind_target = Vector2.from_angle(randf() * TAU) * 320.0
			wind_change = 5.0
		"meteors":
			meteor_timer = 3.0
		"bumpers":
			_place_bumpers()


func _place_bumpers() -> void:
	var avoid: Array = game.mode.avoid_points()
	var tries := 0
	while bumpers.size() < 4 and tries < 600:
		tries += 1
		# relax the spacing rules gradually so small islands still get bumpers
		var relax := minf(1.0, tries / 400.0)
		var p: Vector2 = game.arena.random_point(lerpf(70.0, 45.0, relax))
		var ok := true
		for a in avoid:
			if p.distance_to(a) < lerpf(130.0, 85.0, relax):
				ok = false
		for b in bumpers:
			if p.distance_to(b["p"]) < lerpf(170.0, 120.0, relax):
				ok = false
		if ok:
			bumpers.append({"p": p, "rel": p - game.arena.center, "r": 30.0, "flash": 0.0, "hue": bumpers.size()})


func params() -> Dictionary:
	var p := {"speed": 1.0, "control": 1.0, "dash_cd": 1.0, "wind": wind, "radius": 1.0}
	match id:
		"ice":
			p["control"] = 0.13
		"turbo":
			p["speed"] = 1.35
			p["dash_cd"] = 0.5
			p["control"] = 1.4
		"giant":
			p["radius"] = 1.5
	return p


func power_mult() -> float:
	return 1.3 if id == "giant" else 1.0


func is_dark() -> bool:
	return id == "dark"


func update(dt: float) -> void:
	t += dt
	fx_timer -= dt
	match id:
		"wind":
			wind_change -= dt
			if wind_change <= 0.0:
				wind_change = randf_range(4.0, 7.0)
				wind_target = Vector2.from_angle(wind_target.angle() + randf_range(PI * 0.5, PI * 1.5)) * randf_range(260.0, 360.0)
				Sfx.play("whoosh", -6.0)
			wind = wind.lerp(wind_target, minf(1.0, dt * 1.2))
			if fx_timer <= 0.0:
				fx_timer = 0.03
				var d := wind.normalized()
				var start := Vector2(640, 360) - d * 760.0 + d.orthogonal() * randf_range(-500.0, 500.0)
				game.fx.streak(start, d * randf_range(700.0, 1000.0), Color(1, 1, 1, 0.35), 1.6)
		"ice":
			if fx_timer <= 0.0:
				fx_timer = 0.05
				game.fx.drift(Vector2(randf_range(0, 1280), -10), Vector2(randf_range(-30, 30), randf_range(50, 110)),
					Color(1, 1, 1, 0.8), randf_range(2.0, 4.0), 8.0)
		"turbo":
			if fx_timer <= 0.0:
				fx_timer = 0.02
				for b in game.blobs:
					if b.is_active() and b.vel.length() > 200.0:
						game.fx.trail_dot(b.body_center() - b.vel.normalized() * b.radius, Color(1.0, 0.9, 0.4, 0.6), 8.0, 0.2)
		"bumpers":
			for b in bumpers:
				b["flash"] = maxf(0.0, b["flash"] - dt * 3.0)
				b["p"] = game.arena.center + (b["rel"] as Vector2) * game.arena.shrink
		"meteors":
			meteor_timer -= dt
			if meteor_timer <= 0.0:
				meteor_timer = randf_range(1.2, 2.2)
				_spawn_meteor()
			var i := meteors.size() - 1
			while i >= 0:
				var m: Dictionary = meteors[i]
				m["t"] += dt
				if m["t"] >= m["dur"]:
					_impact(m["p"])
					meteors.remove_at(i)
				i -= 1
	var j := scorches.size() - 1
	while j >= 0:
		scorches[j]["life"] -= dt
		if scorches[j]["life"] <= 0.0:
			scorches.remove_at(j)
		j -= 1


func _spawn_meteor() -> void:
	var target: Vector2 = game.arena.random_point(30.0)
	var alive := []
	for b in game.blobs:
		if b.is_active():
			alive.append(b)
	if alive.size() > 0 and randf() < 0.6:
		var b = alive[randi() % alive.size()]
		target = b.position + b.vel * 0.6 + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
	meteors.append({"p": target, "t": 0.0, "dur": 1.5, "rot": randf() * TAU})


func _impact(p: Vector2) -> void:
	game.fx.explosion(p, 0.55)
	game.shake(9.0)
	Sfx.play("meteor", -2.0)
	scorches.append({"p": p, "life": 5.0})
	for b in game.blobs:
		if b.is_active() and b.position.distance_to(p) < 95.0 + b.radius:
			var dir: Vector2 = (b.position - p)
			dir = dir.normalized() if dir.length() > 1.0 else Vector2.from_angle(randf() * TAU)
			b.take_hit(dir * 760.0, 0.4)
			game.on_external_hit(b)
	game.mode.on_explosion(p, 95.0)


## Pushes a circle out of bumpers. Returns [pos, vel, hit].
func collide_circle(pos: Vector2, vel: Vector2, r: float) -> Array:
	var hit := false
	for b in bumpers:
		var d: Vector2 = pos - b["p"]
		var dist := d.length()
		var min_d: float = r + b["r"]
		if dist < min_d:
			var n := d / dist if dist > 0.01 else Vector2.UP
			pos = b["p"] + n * min_d
			vel = n * maxf(760.0, vel.length() * 0.9)
			b["flash"] = 1.0
			hit = true
			game.fx.ring(b["p"], Color(1, 1, 1, 0.8), b["r"], b["r"] + 40.0, 0.3, 6.0)
			game.fx.sparks(pos, Color(1, 0.9, 0.5), 8, 380.0, n, PI * 0.8)
			Sfx.play("boing", -3.0)
	return [pos, vel, hit]


# ---------------------------------------------------------------- drawing

func draw_ground(ci: CanvasItem) -> void:
	for s in scorches:
		var a: float = clampf(s["life"] / 2.0, 0.0, 1.0)
		ci.draw_set_transform(s["p"], 0.0, Vector2(1.0, 0.55))
		ci.draw_circle(Vector2.ZERO, 52.0, Color(0.1, 0.05, 0.05, 0.35 * a))
		ci.draw_circle(Vector2.ZERO, 30.0, Color(0.15, 0.05, 0.0, 0.4 * a))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in meteors:
		var k: float = m["t"] / m["dur"]
		var p: Vector2 = m["p"]
		var pulse := 0.5 + 0.5 * sin(m["t"] * (10.0 + k * 20.0))
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
		ci.draw_circle(Vector2.ZERO, 95.0, Color(1, 0.15, 0.1, 0.10 + 0.12 * pulse))
		ci.draw_arc(Vector2.ZERO, 95.0, 0.0, TAU, 48, Color(1, 0.3, 0.2, 0.8), 4.0)
		ci.draw_arc(Vector2.ZERO, 95.0 * (1.0 - k), 0.0, TAU, 48, Color(1, 0.8, 0.3, 0.9), 3.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in bumpers:
		var p: Vector2 = b["p"]
		ci.draw_set_transform(p + Vector2(0, 8), 0.0, Vector2(1.0, 0.45))
		ci.draw_circle(Vector2.ZERO, b["r"] + 10.0, Color(0, 0, 0, 0.28))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_top(ci: CanvasItem) -> void:
	for b in bumpers:
		var p: Vector2 = b["p"]
		var f: float = b["flash"]
		var r: float = b["r"] * (1.0 + f * 0.25)
		var col := Color("ff4f8b") if int(b["hue"]) % 2 == 0 else Color("ffc83d")
		ci.draw_set_transform(p + Vector2(0, -4), 0.0, Vector2(1.0, 0.6))
		ci.draw_circle(Vector2(0, 14), r + 2.0, col.darkened(0.55))
		ci.draw_rect(Rect2(-r - 2.0, 0, r * 2.0 + 4.0, 14), col.darkened(0.55))
		ci.draw_circle(Vector2(0, 12), r, col.darkened(0.25))
		ci.draw_rect(Rect2(-r, 0, r * 2.0, 12), col.darkened(0.25))
		ci.draw_circle(Vector2.ZERO, r + 2.0, col.darkened(0.4))
		ci.draw_circle(Vector2.ZERO, r, col.lerp(Color.WHITE, f * 0.8))
		ci.draw_circle(Vector2.ZERO, r * 0.55, Color.WHITE.lerp(col, 0.3))
		for i in 8:
			var a := TAU * i / 8.0 + t * 1.5
			var on := (int(t * 6.0) + i) % 2 == 0
			ci.draw_circle(Vector2.from_angle(a) * r * 0.8, 3.0, Color(1, 1, 0.8) if on else col.darkened(0.3))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		G.draw_star(ci, p + Vector2(0, -4), r * 0.35, col, t)
	for m in meteors:
		var k: float = m["t"] / m["dur"]
		var h := pow(1.0 - k, 2.0) * 700.0
		var p: Vector2 = m["p"] + Vector2(h * 0.35, -h)
		for i in 5:
			var tp := p + Vector2(i * 9.0, -i * 26.0)
			ci.draw_circle(tp, 18.0 - i * 3.0, Color(1.0, 0.5 - i * 0.08, 0.1, 0.6 - i * 0.1))
		var rock := G.circle_poly(p, 20.0, 10, 0.12, m["rot"])
		ci.draw_colored_polygon(rock, Color("5a3a3a"))
		ci.draw_circle(p + Vector2(-5, -5), 7.0, Color("8a5a4a"))


func draw_glow(ci: CanvasItem) -> void:
	for b in bumpers:
		G.glow(ci, b["p"], 60.0 + b["flash"] * 50.0, Color(1, 0.6, 0.8, 0.25 + b["flash"] * 0.5))
	for m in meteors:
		var k: float = m["t"] / m["dur"]
		var h := pow(1.0 - k, 2.0) * 700.0
		G.glow(ci, m["p"] + Vector2(h * 0.35, -h), 60.0, Color(1, 0.5, 0.2, 0.6))
