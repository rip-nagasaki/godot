extends Node
## Shared constants, palettes, input setup and drawing helpers (autoload "G").

const W := 1280.0
const H := 720.0
const WINS_NEEDED := 5

const P_COLORS: Array[Color] = [Color("ff7a3d"), Color("3db8ff")]
const P_DARK: Array[Color] = [Color("a8361a"), Color("1a5fa8")]
const P_LIGHT: Array[Color] = [Color("ffc9a3"), Color("b5e6ff")]
const P_NAMES: Array[String] = ["MANGO", "BERRY"]

## Each round picks a sky theme so the arena keeps changing mood.
const THEMES: Array[Dictionary] = [
	{
		"name": "Sunset Fair",
		"sky_top": Color("241a55"), "sky_mid": Color("b8457e"), "sky_bot": Color("ffb36b"),
		"cloud": Color("ffcfa8"), "stars": 0.35, "aurora": 0.0,
		"sun": Color("fff0b8"), "sun_pos": Vector2(0.82, 0.62),
		"top": Color("7cd957"), "top2": Color("a7ee72"), "side": Color("9a6440"), "side2": Color("4a2a1e"),
		"far": Color("6a3a72"), "lantern": Color("ffb347"),
	},
	{
		"name": "Aurora Night",
		"sky_top": Color("040820"), "sky_mid": Color("0f2f5e"), "sky_bot": Color("1d6c7e"),
		"cloud": Color("5fbfc0"), "stars": 1.0, "aurora": 1.0,
		"sun": Color("e8f4ff"), "sun_pos": Vector2(0.15, 0.2),
		"top": Color("3fbf8f"), "top2": Color("6fe0b0"), "side": Color("4b5d8a"), "side2": Color("1c2142"),
		"far": Color("17375e"), "lantern": Color("8ff7ff"),
	},
	{
		"name": "Candy Morning",
		"sky_top": Color("3fa8f5"), "sky_mid": Color("9ad8ff"), "sky_bot": Color("ffd9ef"),
		"cloud": Color("ffffff"), "stars": 0.0, "aurora": 0.0,
		"sun": Color("fffbe0"), "sun_pos": Vector2(0.2, 0.25),
		"top": Color("ff8fc8"), "top2": Color("ffb8de"), "side": Color("b07ad8"), "side2": Color("5b3a8a"),
		"far": Color("8fc4f0"), "lantern": Color("ff6fae"),
	},
	{
		"name": "Golden Hour",
		"sky_top": Color("3d2a6b"), "sky_mid": Color("e0705a"), "sky_bot": Color("ffd27a"),
		"cloud": Color("ffe2b0"), "stars": 0.1, "aurora": 0.0,
		"sun": Color("ffe28a"), "sun_pos": Vector2(0.5, 0.78),
		"top": Color("e8c94f"), "top2": Color("f7e27e"), "side": Color("a0603a"), "side2": Color("5a2e1e"),
		"far": Color("8a4a6a"), "lantern": Color("ff8a3d"),
	},
	{
		"name": "Cosmic Drift",
		"sky_top": Color("0a0418"), "sky_mid": Color("3a1460"), "sky_bot": Color("8a2a8a"),
		"cloud": Color("c070ff"), "stars": 1.0, "aurora": 0.45,
		"sun": Color("ffb8f0"), "sun_pos": Vector2(0.78, 0.3),
		"top": Color("6f7cff"), "top2": Color("9aa6ff"), "side": Color("5a3a9a"), "side2": Color("22104a"),
		"far": Color("2a1450"), "lantern": Color("ff7af0"),
	},
	{
		"name": "Mint Breeze",
		"sky_top": Color("1d6f8f"), "sky_mid": Color("5ec7b8"), "sky_bot": Color("e6ffd9"),
		"cloud": Color("f4fff4"), "stars": 0.0, "aurora": 0.0,
		"sun": Color("ffffe8"), "sun_pos": Vector2(0.7, 0.2),
		"top": Color("5fd068"), "top2": Color("8fe88a"), "side": Color("7a6a50"), "side2": Color("3a3228"),
		"far": Color("3f8f8f"), "lantern": Color("ffe05a"),
	},
]

var glow_tex: Texture2D
var font: Font
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_setup_input()
	_make_glow_texture()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Fredoka", "Fredoka One", "Nunito", "Baloo 2", "Arial Rounded MT Bold",
		"Segoe UI Black", "Segoe UI", "Helvetica Neue", "DejaVu Sans", "sans-serif"])
	sf.font_weight = 800
	font = sf


func _make_glow_texture() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	glow_tex = t


# ---------------------------------------------------------------- input

func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, device: int, axis: JoyAxis, dir: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	var keys := [
		{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "dash": [KEY_SPACE, KEY_G, KEY_F]},
		{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
			"dash": [KEY_ENTER, KEY_KP_ENTER, KEY_KP_0, KEY_SLASH]},
	]
	for p in 2:
		for a in ["left", "right", "up", "down", "dash"]:
			var action := "p%d_%s" % [p, a]
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action, 0.25)
			for k in keys[p][a]:
				_add_key(action, k)
		_add_joy_axis("p%d_left" % p, p, JOY_AXIS_LEFT_X, -1.0)
		_add_joy_axis("p%d_right" % p, p, JOY_AXIS_LEFT_X, 1.0)
		_add_joy_axis("p%d_up" % p, p, JOY_AXIS_LEFT_Y, -1.0)
		_add_joy_axis("p%d_down" % p, p, JOY_AXIS_LEFT_Y, 1.0)
		_add_joy_button("p%d_left" % p, p, JOY_BUTTON_DPAD_LEFT)
		_add_joy_button("p%d_right" % p, p, JOY_BUTTON_DPAD_RIGHT)
		_add_joy_button("p%d_up" % p, p, JOY_BUTTON_DPAD_UP)
		_add_joy_button("p%d_down" % p, p, JOY_BUTTON_DPAD_DOWN)
		_add_joy_button("p%d_dash" % p, p, JOY_BUTTON_A)
		_add_joy_button("p%d_dash" % p, p, JOY_BUTTON_X)
		_add_joy_button("p%d_dash" % p, p, JOY_BUTTON_RIGHT_SHOULDER)
	if InputMap.has_action("pause"):
		InputMap.erase_action("pause")
	InputMap.add_action("pause")
	_add_key("pause", KEY_ESCAPE)
	_add_key("pause", KEY_P)
	_add_joy_button("pause", 0, JOY_BUTTON_START)
	_add_joy_button("pause", 1, JOY_BUTTON_START)


# ---------------------------------------------------------------- drawing helpers

func text(ci: CanvasItem, center: Vector2, s: String, size: int, col: Color,
		outline: int = 0, ocol: Color = Color(0, 0, 0, 0.55)) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(center.x - w * 0.5, center.y + size * 0.36)
	if outline > 0:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func text_width(s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func wrap(s: String, size: int, max_w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in s.split(" "):
		var test := w if cur == "" else cur + " " + w
		if text_width(test, size) > max_w and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


func glow(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(glow_tex, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func star_points(pos: Vector2, r_out: float, r_in: float, points: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * i / (points * 2) - PI * 0.5
		var r := r_out if i % 2 == 0 else r_in
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	return pts


func draw_star(ci: CanvasItem, pos: Vector2, r: float, col: Color, rot: float = 0.0, outline: Color = Color(0, 0, 0, 0)) -> void:
	if outline.a > 0.0:
		ci.draw_colored_polygon(star_points(pos, r + 3.5, r * 0.5 + 2.5, 5, rot), outline)
	ci.draw_colored_polygon(star_points(pos, r, r * 0.5, 5, rot), col)
	ci.draw_colored_polygon(star_points(pos + Vector2(-r * 0.12, -r * 0.12), r * 0.45, r * 0.22, 5, rot),
		col.lightened(0.45))


func draw_crown(ci: CanvasItem, pos: Vector2, s: float, col: Color, rot: float = 0.0) -> void:
	ci.draw_set_transform(pos, rot, Vector2(s, s))
	var body := PackedVector2Array([
		Vector2(-20, 10), Vector2(-24, -14), Vector2(-11, -2), Vector2(0, -20),
		Vector2(11, -2), Vector2(24, -14), Vector2(20, 10)])
	var outline := PackedVector2Array()
	for p in body:
		outline.append(p * 1.18 + Vector2(0, 1))
	ci.draw_colored_polygon(outline, Color("6b3a00"))
	ci.draw_colored_polygon(body, col)
	ci.draw_rect(Rect2(-20, 4, 40, 7), col.darkened(0.2))
	ci.draw_circle(Vector2(0, -20), 4.0, Color("ff4f7a"))
	ci.draw_circle(Vector2(-24, -14), 3.5, Color("4fd8ff"))
	ci.draw_circle(Vector2(24, -14), 3.5, Color("7aff6b"))
	ci.draw_circle(Vector2(0, 7), 3.0, Color("ff4f7a"))
	ci.draw_line(Vector2(-14, -4), Vector2(-8, 2), Color(1, 1, 1, 0.6), 2.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_bomb(ci: CanvasItem, pos: Vector2, r: float, flash: float, t: float) -> void:
	var body := Color("2b2440").lerp(Color("ff3030"), flash)
	ci.draw_circle(pos, r + 3.0, Color("120c1e"))
	ci.draw_circle(pos, r, body)
	ci.draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.35))
	var cap := pos + Vector2(r * 0.45, -r * 0.8)
	ci.draw_rect(Rect2(cap - Vector2(6, 5), Vector2(12, 9)), Color("6b6b80"))
	var fuse_end := cap + Vector2(9 + sin(t * 9.0) * 2.0, -11)
	ci.draw_line(cap, fuse_end, Color("c8a070"), 3.0)
	ci.draw_circle(fuse_end, 4.0 + sin(t * 40.0) * 1.5, Color("ffe066"))
	ci.draw_circle(fuse_end, 2.0, Color.WHITE)


func circle_poly(c: Vector2, r: float, n: int = 48, wobble: float = 0.0, seed_v: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var rr := r * (1.0 + wobble * sin(a * 5.0 + seed_v) + wobble * 0.6 * sin(a * 9.0 + seed_v * 2.3))
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func round_rect_poly(rect: Rect2, corner: float, seg: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [
		[rect.position + Vector2(rect.size.x - corner, corner), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - corner, rect.size.y - corner), 0.0],
		[rect.position + Vector2(corner, rect.size.y - corner), PI * 0.5],
		[rect.position + Vector2(corner, corner), PI],
	]
	for c in cs:
		for i in seg + 1:
			var a: float = c[1] + (PI * 0.5) * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * corner)
	return pts


func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func ease_out_elastic(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * (TAU / 3.0)) + 1.0
