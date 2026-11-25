extends Node2D
## Game flow: title -> (intro -> play -> round end) x N -> champion.

const Blob := preload("res://scripts/blob.gd")
const Arena := preload("res://scripts/arena.gd")
const Fx := preload("res://scripts/fx.gd")
const Hud := preload("res://scripts/hud.gd")
const Bg := preload("res://scripts/bg.gd")
const Twists := preload("res://scripts/twists.gd")
const DrawLayer := preload("res://scripts/draw_layer.gd")
const SKY_SHADER := preload("res://shaders/sky.gdshader")
const DARK_SHADER := preload("res://shaders/dark.gdshader")

const MODES := {
	"sumo": preload("res://scripts/modes/mode_sumo.gd"),
	"paint": preload("res://scripts/modes/mode_paint.gd"),
	"crown": preload("res://scripts/modes/mode_crown.gd"),
	"stars": preload("res://scripts/modes/mode_stars.gd"),
	"bomb": preload("res://scripts/modes/mode_bomb.gd"),
	"ball": preload("res://scripts/modes/mode_ball.gd"),
}
const TWIST_IDS := ["ice", "wind", "bumpers", "meteors", "turbo", "giant", "dark"]
const HIT_WORDS := ["BONK!", "POW!", "WHAM!", "SPLAT!", "BOING!", "SQUISH!"]

enum { TITLE, INTRO, PLAY, ROUND_END, MATCH_END }

var state := TITLE
var state_t := 0.0
var blobs: Array = []
var arena: Node2D
var fx: Node2D
var hud: Control
var bg: Node2D
var cam: Camera2D
var sky_mat: ShaderMaterial
var dark_mat: ShaderMaterial
var darkness := 0.0
var actors: Node2D
var mode = null
var twist = null
var theme: Dictionary = G.THEMES[0]
var wins := [0, 0]
var round_num := 0
var mode_bag: Array = []
var last_mode := ""
var last_twist := ""
var ready_p := [false, false]
var start_timer := -1.0
var shake_amt := 0.0
var hitstop_t := 0.0
var world_speed := 1.0
var paused := false
var countdown := -1
var dropped := false
var round_winner := -1
var match_winner := -1
var firework_t := 0.0
var wipe := 0.0
var wipe_dir := 0
var wipe_cb: Callable


func _ready() -> void:
	# Background sky + distant scenery
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var sky := ColorRect.new()
	sky.size = Vector2(G.W, G.H)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.material = sky_mat
	bg_layer.add_child(sky)
	bg = Bg.new()
	bg_layer.add_child(bg)

	# World layers
	arena = Arena.new()
	add_child(arena)
	var ground_layer := DrawLayer.new()
	ground_layer.draw_fn = _draw_ground
	ground_layer.z_index = 1
	add_child(ground_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	actors.z_index = 2
	add_child(actors)
	var top_layer := DrawLayer.new()
	top_layer.draw_fn = _draw_top
	top_layer.z_index = 3
	add_child(top_layer)
	var glow_layer := DrawLayer.new()
	glow_layer.draw_fn = _draw_glow
	glow_layer.z_index = 4
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add_mat
	add_child(glow_layer)
	fx = Fx.new()
	fx.z_index = 5
	add_child(fx)

	cam = Camera2D.new()
	cam.position = Vector2(G.W, G.H) * 0.5
	add_child(cam)
	cam.make_current()

	# Darkness overlay for the "Lights Out" twist
	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 5
	add_child(dark_layer)
	var dark := ColorRect.new()
	dark.size = Vector2(G.W, G.H)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_mat = ShaderMaterial.new()
	dark_mat.shader = DARK_SHADER
	dark.material = dark_mat
	dark_layer.add_child(dark)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)

	for i in 2:
		var b := Blob.new()
		b.setup(self, i)
		actors.add_child(b)
		blobs.append(b)

	twist = Twists.new()
	twist.setup(self, "calm")
	_apply_theme(G.THEMES[0], 0.01)
	go_title()


# ---------------------------------------------------------------- flow

func go_title() -> void:
	state = TITLE
	state_t = 0.0
	mode = null
	twist = Twists.new()
	twist.setup(self, "calm")
	ready_p = [false, false]
	start_timer = -1.0
	wins = [0, 0]
	match_winner = -1
	fx.clear()
	_apply_theme(G.THEMES[0], 1.0)
	arena.build("title")
	arena.appear = 1.0
	for b in blobs:
		b.reset_for_round()
		b.frozen = false
		b.drop_in(_title_spawn(b.idx), 500.0 + b.idx * 120.0)


func _title_spawn(i: int) -> Vector2:
	return arena.center + Vector2(-90.0 if i == 0 else 90.0, 0.0)


func start_match() -> void:
	wins = [0, 0]
	round_num = 0
	mode_bag.clear()
	last_mode = ""
	last_twist = ""
	transition(_setup_round)


func transition(cb: Callable) -> void:
	if wipe_dir != 0:
		return
	wipe_dir = 1
	wipe_cb = cb
	Sfx.play("whoosh", -3.0)


func _pick_mode() -> String:
	if mode_bag.is_empty():
		mode_bag = MODES.keys()
		mode_bag.shuffle()
		if mode_bag[0] == last_mode:
			mode_bag.push_back(mode_bag.pop_front())
	return mode_bag.pop_front()


func _pick_twist(mode_id: String) -> String:
	if round_num == 1:
		return "calm"
	var options: Array = TWIST_IDS.duplicate()
	options.append("calm")
	options.erase(last_twist)
	if mode_id == "ball":
		options.erase("giant")
	return options[randi() % options.size()]


func _setup_round() -> void:
	round_num += 1
	var mid := _pick_mode()
	last_mode = mid
	mode = MODES[mid].new()
	mode.game = self
	mode.time_left = mode.time_limit
	var tid := _pick_twist(mid)
	last_twist = tid
	var choices: Array = G.THEMES.duplicate()
	choices.erase(theme)
	_apply_theme(choices[randi() % choices.size()], 1.2)
	fx.clear()
	arena.build(mode.layout)
	arena.appear = 0.0
	arena.icy = 1.0 if tid == "ice" else 0.0
	mode.setup()
	twist = Twists.new()
	twist.setup(self, tid)
	for b in blobs:
		b.reset_for_round()
		b.frozen = true
		b.state = Blob.GONE
	state = INTRO
	state_t = 0.0
	countdown = -1
	dropped = false
	round_winner = -1
	world_speed = 1.0


func _apply_theme(th: Dictionary, dur: float) -> void:
	var old := theme
	theme = th
	arena.theme = th
	bg.theme = th
	var tw := create_tween()
	tw.tween_method(_blend_sky.bind(old, th), 0.0, 1.0, dur)


func _blend_sky(k: float, a: Dictionary, b: Dictionary) -> void:
	sky_mat.set_shader_parameter("top_color", (a["sky_top"] as Color).lerp(b["sky_top"], k))
	sky_mat.set_shader_parameter("mid_color", (a["sky_mid"] as Color).lerp(b["sky_mid"], k))
	sky_mat.set_shader_parameter("bottom_color", (a["sky_bot"] as Color).lerp(b["sky_bot"], k))
	sky_mat.set_shader_parameter("cloud_color", (a["cloud"] as Color).lerp(b["cloud"], k))
	sky_mat.set_shader_parameter("sun_color", (a["sun"] as Color).lerp(b["sun"], k))
	sky_mat.set_shader_parameter("sun_pos", (a["sun_pos"] as Vector2).lerp(b["sun_pos"], k))
	sky_mat.set_shader_parameter("star_amount", lerpf(a["stars"], b["stars"], k))
	sky_mat.set_shader_parameter("aurora", lerpf(a["aurora"], b["aurora"], k))


func _end_round(w: int) -> void:
	state = ROUND_END
	state_t = 0.0
	round_winner = w
	world_speed = 0.25
	for b in blobs:
		b.frozen = true
	if w >= 0:
		wins[w] += 1
		blobs[w].celebrate = true
		blobs[1 - w].sad = true
		Sfx.play("win", -2.0)
		fx.confetti_rain([G.P_COLORS[w], G.P_LIGHT[w], Color.WHITE, Color("ffe066")], 90)
		hud.add_banner("%s WINS THE ROUND!" % G.P_NAMES[w], G.P_COLORS[w].lightened(0.25), 2.6, 58)
	else:
		Sfx.play("bump", 0.0, 0.6)
		hud.add_banner("DRAW!", Color.WHITE, 2.4, 70)


func _go_champion() -> void:
	state = MATCH_END
	state_t = 0.0
	mode = null
	twist = Twists.new()
	twist.setup(self, "calm")
	fx.clear()
	_apply_theme(G.THEMES[1], 0.6)
	arena.build("title")
	arena.appear = 1.0
	for b in blobs:
		b.reset_for_round()
		b.frozen = true
		b.drop_in(_title_spawn(b.idx) + Vector2(0, 10), 400.0)
		b.celebrate = b.idx == match_winner
		b.sad = b.idx != match_winner
	Sfx.play("win", 0.0)


# ---------------------------------------------------------------- effects API used by modes/twists

func shake(amount: float) -> void:
	shake_amt = minf(30.0, maxf(shake_amt, amount))


func hitstop(duration: float) -> void:
	hitstop_t = maxf(hitstop_t, duration)


func banner(text: String, col: Color, dur: float = 1.6, size: int = 54) -> void:
	hud.add_banner(text, col, dur, size)


func flash(col: Color, strength: float) -> void:
	hud.flash(col, strength)


func on_external_hit(b) -> void:
	if mode != null and state == PLAY:
		mode.on_hit(null, b)


func respawn_blob(b) -> void:
	var p: Vector2 = _title_spawn(b.idx) if mode == null else mode.spawn_point(b.idx)
	var other = blobs[1 - b.idx]
	if not arena.is_safe_point(p, 40.0) or (other.is_active() and other.position.distance_to(p) < 90.0):
		p = arena.random_point(70.0)
	b.drop_in(p, 560.0, 1.0)
	Sfx.play("respawn", -6.0)
	if mode != null:
		mode.on_respawn(b)


# ---------------------------------------------------------------- main loop

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if paused and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		paused = false
		fx.set_process(true)
		transition(go_title)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_update_wipe(dt)
	if Input.is_action_just_pressed("pause") and state != TITLE and wipe_dir == 0:
		paused = not paused
		fx.set_process(not paused)
		Sfx.play("blip", -4.0)
	if paused:
		return
	state_t += dt
	world_speed = move_toward(world_speed, 1.0, dt * 1.2)
	var wdt := dt * world_speed

	match state:
		TITLE:
			_world_step(wdt)
			_title_logic(dt)
		INTRO:
			_intro_logic(dt)
			_world_step(wdt)
		PLAY:
			if hitstop_t > 0.0:
				hitstop_t -= dt
			else:
				_world_step(wdt)
				mode.update(wdt)
				twist.update(wdt)
				_timer_logic(wdt)
				if mode.finished:
					_end_round(mode.winner)
		ROUND_END:
			_world_step(wdt)
			if state_t > 3.2 and wipe_dir == 0:
				if round_winner >= 0 and wins[round_winner] >= G.WINS_NEEDED:
					match_winner = round_winner
					transition(_go_champion)
				else:
					transition(_setup_round)
		MATCH_END:
			_world_step(wdt)
			_champion_logic(dt)

	_update_camera(dt)
	_update_darkness(dt)


func _update_wipe(dt: float) -> void:
	if wipe_dir == 0:
		return
	wipe += wipe_dir * dt * 2.4
	if wipe_dir > 0 and wipe >= 1.0:
		wipe = 1.0
		wipe_dir = -1
		if wipe_cb.is_valid():
			wipe_cb.call()
	elif wipe_dir < 0 and wipe <= 0.0:
		wipe = 0.0
		wipe_dir = 0


func _title_logic(dt: float) -> void:
	for i in 2:
		if not ready_p[i] and Input.is_action_just_pressed("p%d_dash" % i):
			ready_p[i] = true
			Sfx.play("ready", 0.0)
			fx.popup(blobs[i].head_pos() + Vector2(0, -30), "READY!", G.P_COLORS[i].lightened(0.4), 28.0)
	if ready_p[0] and ready_p[1] and start_timer < 0.0:
		start_timer = 1.0
		Sfx.play("go", 0.0)
	if start_timer > 0.0:
		start_timer -= dt
		if start_timer <= 0.0:
			start_match()


func _intro_logic(_dt: float) -> void:
	arena.appear = G.ease_out_back(clampf(state_t / 0.9, 0.0, 1.0))
	if not dropped and state_t > 0.8:
		dropped = true
		for b in blobs:
			b.drop_in(mode.spawn_point(b.idx), 600.0 + b.idx * 80.0)
	# let impatient players skip the rules card
	if state_t > 1.4 and state_t < 3.3:
		for i in 2:
			if Input.is_action_just_pressed("p%d_dash" % i):
				state_t = 3.3
	var cd := -1
	if state_t >= 3.4:
		cd = 3 - int((state_t - 3.4) / 0.55)
	if cd != countdown and cd >= 0:
		countdown = cd
		if cd > 0:
			Sfx.play("beep", 0.0)
		else:
			Sfx.play("go", 0.0)
			state = PLAY
			state_t = 0.0
			for b in blobs:
				b.frozen = false
			hud.add_banner("GO!", Color("fff3a0"), 0.8, 110)


func _timer_logic(dt: float) -> void:
	if mode.time_limit <= 0.0 or mode.overtime or mode.finished:
		return
	var before := int(ceil(mode.time_left))
	mode.time_left -= dt
	var after := int(ceil(mode.time_left))
	if after != before and after <= 5 and after > 0:
		Sfx.play("beep", -6.0, 1.3)
	if mode.time_left <= 0.0:
		mode.time_left = 0.0
		mode.on_time_up()
		if mode.overtime and not mode.finished:
			hud.add_banner("OVERTIME! Next point wins!", Color("ff9f43"), 1.8, 48)
			Sfx.play("goal", -4.0, 0.8)


func _champion_logic(dt: float) -> void:
	firework_t -= dt
	if firework_t <= 0.0:
		firework_t = randf_range(0.25, 0.6)
		var p := Vector2(randf_range(150, 1130), randf_range(120, 380))
		var c := Color.from_hsv(randf(), 0.6, 1.0)
		if randf() < 0.5:
			c = G.P_COLORS[match_winner].lightened(0.2)
		fx.sparks(p, c, 36, 520.0)
		fx.ring(p, c, 5.0, 120.0, 0.7, 4.0)
		fx.glow_puff(p, c, 140.0, 0.5)
		fx.stars(p, c.lightened(0.3), 6, 200.0)
		Sfx.play("meteor", -14.0, 1.8)
	if state_t > 2.5:
		for i in 2:
			if Input.is_action_just_pressed("p%d_dash" % i) and wipe_dir == 0:
				transition(go_title)


func _world_step(dt: float) -> void:
	if dt <= 0.0:
		return
	var p: Dictionary = twist.params()
	for b in blobs:
		b.step(dt, p)
	for b in blobs:
		if not b.is_active():
			continue
		if arena.walls:
			var res: Array = arena.collide_walls(b.position, b.vel, b.radius, false)
			b.position = res[0]
			b.vel = res[1]
		var r2: Array = twist.collide_circle(b.position, b.vel, b.radius)
		if r2[2]:
			b.position = r2[0]
			b.vel = r2[1]
			b.dash_t = 0.0
			b.stun = maxf(b.stun, 0.2)
			b.wobble_v += 30.0
	_collide_blobs()
	if not arena.walls:
		for b in blobs:
			if b.is_active() and not arena.is_on_ground(b.position):
				b.start_fall()
				fx.smoke(b.position, Color(1, 1, 1, 0.5), 6, 100.0, 14.0)
				if mode != null and state == PLAY:
					mode.on_fall(b)
				if state == TITLE or state == MATCH_END or (state == PLAY and mode.allows_respawn()):
					b.respawn_timer = mode.respawn_delay if mode != null else 0.9


func _collide_blobs() -> void:
	var a = blobs[0]
	var b = blobs[1]
	if not a.is_active() or not b.is_active():
		return
	var d: Vector2 = b.position - a.position
	var dist := d.length()
	var min_d: float = a.radius + b.radius
	if dist >= min_d:
		return
	var n := d / dist if dist > 0.01 else Vector2.RIGHT
	var overlap := min_d - dist
	a.position -= n * overlap * 0.5
	b.position += n * overlap * 0.5
	var ad: bool = a.is_dashing()
	var bd: bool = b.is_dashing()
	var cp: Vector2 = (a.body_center() + b.body_center()) * 0.5
	if ad and bd:
		a.take_hit(-n * 560.0, 0.25)
		b.take_hit(n * 560.0, 0.25)
		fx.sparks(cp, Color(1, 1, 0.85), 26, 820.0)
		fx.glow_puff(cp, Color(1, 1, 1), 130.0, 0.3)
		fx.ring(cp, Color.WHITE, 10.0, 110.0, 0.35, 8.0)
		fx.popup(cp + Vector2(0, -40), "CLASH!", Color("fff3a0"), 34.0)
		Sfx.play("clash", 0.0)
		shake(14.0)
		hitstop(0.09)
	elif ad:
		_strike(a, b, n, cp)
	elif bd:
		_strike(b, a, -n, cp)
	else:
		var rel: float = (b.vel - a.vel).dot(n)
		if rel < 0.0:
			var j := -rel * 0.8
			a.vel -= n * j
			b.vel += n * j
			if -rel > 160.0:
				Sfx.play("bump", -6.0)
				fx.ring(cp, Color(1, 1, 1, 0.5), 6.0, 36.0, 0.2, 3.0)
				a.wobble_v += 15.0
				b.wobble_v += 15.0
		a.vel -= n * 40.0
		b.vel += n * 40.0
	if mode != null and state == PLAY:
		mode.on_contact(a, b)


func _strike(att, vic, n: Vector2, cp: Vector2) -> void:
	att.dash_t = 0.0
	if vic.invuln > 0.0:
		vic.vel += n * 300.0
		att.vel = -n * 200.0
		return
	var power: float = (640.0 + att.vel.length() * 0.35) * twist.power_mult()
	vic.take_hit(n * power + vic.vel * 0.15, 0.35)
	att.vel = -n * 140.0
	att.wobble_v += 30.0
	fx.sparks(cp, Color(1, 1, 0.75), 14, 620.0, n, PI * 0.9)
	fx.ring(cp, att.color.lightened(0.3), 10.0, 72.0, 0.3, 7.0)
	fx.burst(cp, att.color, 10, 300.0, 6.0)
	fx.stars(cp, Color(1, 0.95, 0.5), 4, 250.0)
	fx.glow_puff(cp, att.color.lightened(0.3), 90.0, 0.25)
	fx.popup(cp + Vector2(0, -36), HIT_WORDS[randi() % HIT_WORDS.size()], Color.WHITE, 30.0)
	Sfx.play("bonk", 0.0)
	shake(10.0)
	hitstop(0.07)
	if mode != null and state == PLAY:
		mode.on_hit(att, vic)


func _update_camera(dt: float) -> void:
	shake_amt = move_toward(shake_amt, 0.0, dt * 45.0)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amt


func _update_darkness(dt: float) -> void:
	var want := 1.0 if (twist != null and twist.is_dark() and (state == INTRO or state == PLAY)) else 0.0
	darkness = move_toward(darkness, want, dt * 1.5)
	dark_mat.set_shader_parameter("darkness", darkness * 0.92)
	if darkness <= 0.0:
		return
	var ct := get_viewport().get_canvas_transform()
	var lights: Array = []
	for b in blobs:
		if b.state != Blob.GONE:
			lights.append([b.body_center(), 210.0])
	if mode != null:
		lights.append_array(mode.light_points())
	for i in 4:
		var v := Vector4.ZERO
		if i < lights.size():
			var sp: Vector2 = ct * (lights[i][0] as Vector2)
			v = Vector4(sp.x, sp.y, lights[i][1], 0.0)
		dark_mat.set_shader_parameter("light%d" % i, v)


# ---------------------------------------------------------------- layer drawing

func _draw_ground(ci: CanvasItem) -> void:
	if mode != null:
		mode.draw_ground(ci)
	if twist != null:
		twist.draw_ground(ci)


func _draw_top(ci: CanvasItem) -> void:
	if twist != null:
		twist.draw_top(ci)
	if mode != null:
		mode.draw_top(ci)


func _draw_glow(ci: CanvasItem) -> void:
	if twist != null:
		twist.draw_glow(ci)
	if mode != null:
		mode.draw_glow(ci)
