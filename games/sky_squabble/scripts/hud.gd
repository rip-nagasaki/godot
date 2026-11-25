extends Control
## All on-screen UI: title screen, scoreboard, round cards, banners and transitions.

enum { TITLE, INTRO, PLAY, ROUND_END, MATCH_END }

const CREAM := Color("fff6e0")
const INK := Color(0.1, 0.05, 0.16)

var game
var banners: Array[Dictionary] = []
var flash_col := Color(1, 1, 1, 0)
var t := 0.0


func _ready() -> void:
	size = Vector2(G.W, G.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_banner(text: String, col: Color, dur: float, font_size: int) -> void:
	banners = [{"text": text, "col": col, "dur": dur, "t": 0.0, "size": font_size}]


func flash(col: Color, strength: float) -> void:
	flash_col = Color(col, strength)


func _process(delta: float) -> void:
	t += delta
	if not game.paused:
		var i := banners.size() - 1
		while i >= 0:
			banners[i]["t"] += delta
			if banners[i]["t"] > banners[i]["dur"]:
				banners.remove_at(i)
			i -= 1
	flash_col.a = move_toward(flash_col.a, 0.0, delta * 1.4)
	queue_redraw()


func _draw() -> void:
	match game.state:
		TITLE:
			_draw_title()
		INTRO, PLAY, ROUND_END:
			_draw_topbar()
			if game.state == INTRO:
				_draw_card()
				_draw_countdown()
			if game.state == ROUND_END:
				_draw_round_score()
		MATCH_END:
			_draw_champion()
	_draw_banners()
	if game.paused:
		_draw_pause()
	if flash_col.a > 0.0:
		draw_rect(Rect2(0, 0, G.W, G.H), flash_col)
	_draw_wipe()


# ---------------------------------------------------------------- helpers

func _panel(r: Rect2, fill: Color, border: Color, corner: float = 18.0, bw: float = 4.0) -> void:
	var outer := G.round_rect_poly(r.grow(bw), corner + bw, 6)
	draw_colored_polygon(outer, border)
	draw_colored_polygon(G.round_rect_poly(r, corner, 6), fill)


func _key(center: Vector2, label: String, w: float = 38.0) -> void:
	var r := Rect2(center - Vector2(w * 0.5, 17), Vector2(w, 34))
	draw_colored_polygon(G.round_rect_poly(Rect2(r.position + Vector2(0, 4), r.size), 7, 4), Color(0, 0, 0, 0.45))
	draw_colored_polygon(G.round_rect_poly(r, 7, 4), CREAM)
	G.text(self, center + Vector2(0, -1), label, 16, INK)


func _face(c: Vector2, r: float, i: int, mood: String = "") -> void:
	draw_circle(c, r + 3.0, G.P_DARK[i])
	draw_circle(c, r, G.P_COLORS[i])
	draw_circle(c + Vector2(-r * 0.35, -r * 0.45), r * 0.22, Color(1, 1, 1, 0.5))
	for s in [-1, 1]:
		var e := c + Vector2(s * r * 0.34, -r * 0.05)
		if mood == "win":
			draw_arc(e + Vector2(0, 3), r * 0.17, PI * 1.1, PI * 1.9, 8, INK, 3.0)
		else:
			draw_set_transform(e, 0.0, Vector2(r * 0.2, r * 0.25))
			draw_circle(Vector2.ZERO, 1.0, Color.WHITE)
			draw_set_transform(e + Vector2(0, r * 0.04), 0.0, Vector2(r * 0.1, r * 0.13))
			draw_circle(Vector2.ZERO, 1.0, INK)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(c + Vector2(0, r * 0.25), r * 0.18, 0.3, PI - 0.3, 8, INK, 2.5)


# ---------------------------------------------------------------- title

func _draw_title() -> void:
	# Wobbly rainbow logo
	var logo := "SKY SQUABBLE"
	var size_l := 92
	var total := G.text_width(logo, size_l) + (logo.length() - 1) * 4.0
	var x := 640.0 - total * 0.5
	var palette := [Color("ff7a3d"), Color("ffd23f"), Color("7cd957"), Color("3db8ff"), Color("b28dff"), Color("ff5fa2")]
	for i in logo.length():
		var ch := logo[i]
		var w := G.text_width(ch, size_l)
		if ch != " ":
			var y := 112.0 + sin(t * 3.0 + i * 0.55) * 8.0
			var rot := sin(t * 2.0 + i) * 0.06
			var c: Color = palette[i % palette.size()]
			draw_set_transform(Vector2(x + w * 0.5, y + 6), rot, Vector2.ONE)
			G.text(self, Vector2.ZERO, ch, size_l, Color(0, 0, 0, 0.35))
			draw_set_transform(Vector2(x + w * 0.5, y), rot, Vector2.ONE)
			G.text(self, Vector2.ZERO, ch, size_l, c, 16, Color("2a1640"))
			G.text(self, Vector2(-w * 0.12, -size_l * 0.18), ".", 30, Color(1, 1, 1, 0.6))
		x += w + 4.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	G.text(self, Vector2(640, 186), "A jelly party brawl for two players", 26, CREAM, 8, Color("2a1640"))

	for i in 2:
		_draw_player_card(i)

	var tips := [
		"6 mini-games  +  8 wild twists  =  no two rounds alike",
		"Dash into your rival to send them flying!",
		"First to %d round wins is the Sky Champion" % G.WINS_NEEDED,
	]
	var tip: String = tips[int(t / 3.5) % tips.size()]
	_panel(Rect2(340, 668, 600, 38), Color(0.08, 0.05, 0.16, 0.75), Color(1, 1, 1, 0.25), 18, 2)
	G.text(self, Vector2(640, 686), tip, 19, CREAM)
	G.text(self, Vector2(1180, 700), "Esc: pause", 14, Color(1, 1, 1, 0.5))


func _draw_player_card(i: int) -> void:
	var r := Rect2(60 if i == 0 else 900, 250, 320, 330)
	var col: Color = G.P_COLORS[i]
	var ready: bool = game.ready_p[i]
	var bounce := sin(t * 4.0 + i * 2.0) * 3.0
	_panel(r, Color(0.08, 0.05, 0.16, 0.8), col if ready else col.darkened(0.3), 24, 5)
	_face(Vector2(r.position.x + 52, r.position.y + 52 + bounce), 28.0, i, "win" if ready else "")
	G.text(self, Vector2(r.position.x + 190, r.position.y + 42), G.P_NAMES[i], 40, col.lightened(0.15), 8, INK)
	G.text(self, Vector2(r.position.x + 190, r.position.y + 78), "Player %d" % (i + 1), 18, Color(1, 1, 1, 0.7))
	var y := r.position.y + 130
	G.text(self, Vector2(r.position.x + 56, y), "MOVE", 20, CREAM)
	if i == 0:
		_key(Vector2(r.position.x + 200, y - 22), "W")
		_key(Vector2(r.position.x + 158, y + 18), "A")
		_key(Vector2(r.position.x + 200, y + 18), "S")
		_key(Vector2(r.position.x + 242, y + 18), "D")
	else:
		_key(Vector2(r.position.x + 200, y - 22), "^")
		_key(Vector2(r.position.x + 158, y + 18), "<")
		_key(Vector2(r.position.x + 200, y + 18), "v")
		_key(Vector2(r.position.x + 242, y + 18), ">")
	y += 82
	G.text(self, Vector2(r.position.x + 56, y), "DASH", 20, CREAM)
	_key(Vector2(r.position.x + 200, y), "SPACE" if i == 0 else "ENTER", 110)
	G.text(self, Vector2(r.position.x + 160, y + 36), "or gamepad %d  (A)" % (i + 1), 15, Color(1, 1, 1, 0.55))
	y += 86
	if ready:
		_panel(Rect2(r.position.x + 40, y - 22, 240, 44), col, Color.WHITE, 16, 3)
		G.text(self, Vector2(r.get_center().x, y), "READY!", 28, Color.WHITE, 6, INK)
	else:
		var a := 0.55 + 0.45 * sin(t * 5.0)
		G.text(self, Vector2(r.get_center().x, y), "Press DASH when ready", 21, Color(col.lightened(0.4), a), 5, INK)


# ---------------------------------------------------------------- in-game HUD

func _draw_topbar() -> void:
	for i in 2:
		var r := Rect2(18 if i == 0 else 942, 14, 320, 70)
		var col: Color = G.P_COLORS[i]
		_panel(r, Color(0.08, 0.05, 0.16, 0.78), col, 20, 4)
		var face_x := r.position.x + 40 if i == 0 else r.end.x - 40
		var mood := ""
		if game.state == ROUND_END and game.round_winner == i:
			mood = "win"
		_face(Vector2(face_x, r.get_center().y), 22.0, i, mood)
		var name_x := r.position.x + 130 if i == 0 else r.end.x - 130
		G.text(self, Vector2(name_x, r.position.y + 22), G.P_NAMES[i], 24, col.lightened(0.2), 6, INK)
		for k in G.WINS_NEEDED:
			var px := name_x - 2.0 * 26.0 + k * 26.0
			var pp := Vector2(px, r.position.y + 50)
			if k < game.wins[i]:
				var pop := 1.0
				if game.state == ROUND_END and game.round_winner == i and k == game.wins[i] - 1:
					pop = 1.0 + maxf(0.0, 0.8 - game.state_t) * 1.5
				G.draw_star(self, pp, 11.0 * pop, Color("ffd23f"), 0.0, Color("6b3a00"))
			else:
				draw_circle(pp, 9.0, Color(1, 1, 1, 0.12))
				draw_arc(pp, 9.0, 0.0, TAU, 16, Color(1, 1, 1, 0.3), 2.0)

	var m = game.mode
	if m == null:
		return
	# center: timer dial, mode title, twist pill
	var c := Vector2(640, 52)
	draw_circle(c, 44.0, Color(0.08, 0.05, 0.16, 0.85))
	draw_arc(c, 44.0, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
	if m.time_limit > 0.0 and not m.overtime:
		var f: float = clampf(m.time_left / m.time_limit, 0.0, 1.0)
		var tc := Color("7cf0a0").lerp(Color("ff5050"), clampf(1.0 - m.time_left / 10.0, 0.0, 1.0))
		draw_arc(c, 38.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48, tc, 7.0)
		var secs := int(ceil(m.time_left))
		var pulse := 1.0 + (0.25 * maxf(0.0, 1.0 - fmod(m.time_left, 1.0) * 3.0) if secs <= 5 else 0.0)
		draw_set_transform(c, 0.0, Vector2(pulse, pulse))
		G.text(self, Vector2.ZERO, str(secs), 34, Color.WHITE, 6, INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif m.overtime:
		var a := 0.6 + 0.4 * sin(t * 10.0)
		G.text(self, c, "OT", 30, Color(1, 0.6, 0.25, a), 6, INK)
	else:
		m.draw_icon(self, c, 0.55, t)
	G.text(self, Vector2(482, 40), m.title.to_upper(), 24, CREAM, 6, INK)
	G.text(self, Vector2(482, 66), "Round %d" % game.round_num, 16, Color(1, 1, 1, 0.65), 4, INK)
	var tw = game.twist
	if tw != null:
		var label: String = tw.title.to_upper()
		var w := G.text_width(label, 17) + 28.0
		var pr := Rect2(798 - w * 0.5, 38, w, 30)
		var pc := _twist_color(tw.id)
		_panel(pr, pc.darkened(0.45), pc, 14, 3)
		G.text(self, pr.get_center(), label, 17, Color.WHITE, 4, INK)
		if tw.id == "wind":
			var wv: Vector2 = tw.wind
			var ac := Vector2(pr.end.x + 30, pr.get_center().y)
			var tip := ac + wv.normalized() * 18.0
			draw_line(ac - wv.normalized() * 18.0, tip, CREAM, 4.0)
			draw_colored_polygon(PackedVector2Array([tip + wv.normalized() * 8.0, tip + wv.normalized().orthogonal() * 7.0,
				tip - wv.normalized().orthogonal() * 7.0]), CREAM)
	if game.state != INTRO:
		m.draw_hud(self)


func _twist_color(id: String) -> Color:
	match id:
		"ice":
			return Color("8fe3ff")
		"wind":
			return Color("b8f5d0")
		"bumpers":
			return Color("ff4f8b")
		"meteors":
			return Color("ff7a3d")
		"turbo":
			return Color("ffd23f")
		"giant":
			return Color("b28dff")
		"dark":
			return Color("6b6bd6")
	return Color("9ad8ff")


func _draw_card() -> void:
	var st: float = game.state_t
	if st > 3.45:
		return
	var k_in := G.ease_out_back(clampf((st - 0.15) / 0.5, 0.0, 1.0))
	var k_out := clampf((st - 3.1) / 0.3, 0.0, 1.0)
	var y_off := (1.0 - k_in) * -520.0 + k_out * k_out * 700.0
	var r := Rect2(330, 210 + y_off, 620, 330)
	var lc: Color = game.theme["lantern"]
	_panel(r, Color(0.08, 0.05, 0.16, 0.9), lc, 28, 6)
	var m = game.mode
	_panel(Rect2(r.get_center().x - 80, r.position.y - 20, 160, 40), lc, Color.WHITE, 18, 3)
	G.text(self, Vector2(r.get_center().x, r.position.y), "ROUND %d" % game.round_num, 22, INK)
	var icon_c := Vector2(r.position.x + 110, r.position.y + 120)
	draw_circle(icon_c, 70.0, Color(1, 1, 1, 0.08))
	m.draw_icon(self, icon_c, 1.3, t)
	G.text(self, Vector2(r.position.x + 400, r.position.y + 78), m.title.to_upper(), 46, CREAM, 10, INK)
	var lines := G.wrap(m.rule, 21, 360.0)
	for li in lines.size():
		G.text(self, Vector2(r.position.x + 400, r.position.y + 128 + li * 28), lines[li], 21, Color(1, 1, 1, 0.9))
	var tw = game.twist
	var tc := _twist_color(tw.id)
	var tr := Rect2(r.position.x + 30, r.position.y + 222, r.size.x - 60, 74)
	_panel(tr, tc.darkened(0.6), tc, 16, 3)
	G.text(self, Vector2(tr.get_center().x, tr.position.y + 22), "TWIST:  " + tw.title.to_upper(), 24, tc.lightened(0.3), 5, INK)
	G.text(self, Vector2(tr.get_center().x, tr.position.y + 52), tw.desc, 18, CREAM)
	if st > 1.4:
		G.text(self, Vector2(r.get_center().x, r.end.y + 26), "press DASH to skip", 15, Color(1, 1, 1, 0.5))


func _draw_countdown() -> void:
	var cd: int = game.countdown
	if cd < 1:
		return
	var local := fmod(game.state_t - 3.4, 0.55) / 0.55
	var s := 1.8 - G.ease_out_back(clampf(local * 2.0, 0.0, 1.0)) * 0.8
	var a := 1.0 - clampf((local - 0.7) / 0.3, 0.0, 1.0)
	draw_set_transform(Vector2(640, 330), 0.0, Vector2(s, s))
	draw_circle(Vector2.ZERO, 70.0, Color(0.08, 0.05, 0.16, 0.6 * a))
	G.text(self, Vector2.ZERO, str(cd), 110, Color(1, 0.95, 0.6, a), 14, Color(INK, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_round_score() -> void:
	var st: float = game.state_t
	if st < 0.9:
		return
	var a := clampf((st - 0.9) / 0.3, 0.0, 1.0)
	var r := Rect2(440, 430, 400, 96)
	_panel(r, Color(0.08, 0.05, 0.16, 0.85 * a), Color(1, 1, 1, 0.4 * a), 22, 3)
	for i in 2:
		var cx := r.position.x + (90.0 if i == 0 else 310.0)
		_face(Vector2(cx - 40 if i == 0 else cx + 40, r.get_center().y), 22.0, i, "win" if game.round_winner == i else "")
		G.text(self, Vector2(cx + 20 if i == 0 else cx - 20, r.get_center().y), str(game.wins[i]), 52, Color(G.P_COLORS[i].lightened(0.2), a), 8, INK)
	G.text(self, r.get_center(), "-", 40, Color(1, 1, 1, a))
	G.text(self, Vector2(640, r.end.y + 22), "First to %d wins" % G.WINS_NEEDED, 17, Color(1, 1, 1, 0.6 * a))


func _draw_champion() -> void:
	var w: int = game.match_winner
	if w < 0:
		return
	var col: Color = G.P_COLORS[w]
	var s := 1.0 + sin(t * 3.0) * 0.04
	draw_set_transform(Vector2(640, 110), sin(t * 1.5) * 0.03, Vector2(s, s))
	G.text(self, Vector2.ZERO, G.P_NAMES[w], 110, col.lightened(0.1), 18, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	G.text(self, Vector2(640, 196), "IS THE SKY CHAMPION!", 44, Color("ffe066"), 10, INK)
	G.draw_crown(self, Vector2(640, 26), 1.2, Color("ffd23f"), sin(t * 2.0) * 0.1)
	G.text(self, Vector2(640, 250), "%d  -  %d" % [game.wins[0], game.wins[1]], 34, CREAM, 8, INK)
	if game.state_t > 2.5:
		var a := 0.55 + 0.45 * sin(t * 5.0)
		_panel(Rect2(440, 660, 400, 40), Color(0.08, 0.05, 0.16, 0.8), Color(1, 1, 1, 0.3), 18, 2)
		G.text(self, Vector2(640, 680), "Press DASH to play again", 22, Color(1, 1, 1, a))


func _draw_banners() -> void:
	for b in banners:
		var bt: float = b["t"]
		var dur: float = b["dur"]
		var k_in := G.ease_out_elastic(clampf(bt / 0.6, 0.0, 1.0))
		var k_out := clampf((bt - (dur - 0.25)) / 0.25, 0.0, 1.0)
		var s := maxf(0.01, k_in * (1.0 - k_out * 0.5))
		var a := 1.0 - k_out
		var col: Color = b["col"]
		var size_b: int = b["size"]
		var text_s: String = b["text"]
		var w := G.text_width(text_s, size_b) + 80.0
		draw_set_transform(Vector2(640, 300), sin(t * 2.0) * 0.02, Vector2(s, s))
		var ribbon := Rect2(-w * 0.5, -size_b * 0.75, w, size_b * 1.5)
		draw_colored_polygon(G.round_rect_poly(ribbon.grow(12), size_b * 0.45, 6), Color(INK, 0.6 * a))
		draw_colored_polygon(G.round_rect_poly(ribbon.grow(6), size_b * 0.4, 6), Color(col, 0.95 * a))
		draw_colored_polygon(G.round_rect_poly(ribbon, size_b * 0.35, 6), Color(0.1, 0.06, 0.2, 0.92 * a))
		G.text(self, Vector2.ZERO, text_s, size_b, Color(col, a), 12, Color(INK, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, G.W, G.H), Color(0.03, 0.02, 0.08, 0.65))
	_panel(Rect2(440, 250, 400, 200), Color(0.08, 0.05, 0.16, 0.95), Color(1, 1, 1, 0.5), 24, 4)
	G.text(self, Vector2(640, 300), "PAUSED", 54, CREAM, 10, INK)
	G.text(self, Vector2(640, 360), "Esc / P  -  resume", 20, Color(1, 1, 1, 0.8))
	G.text(self, Vector2(640, 396), "Q  -  quit to title", 20, Color(1, 1, 1, 0.8))


func _draw_wipe() -> void:
	var wp: float = game.wipe
	if wp <= 0.0:
		return
	var cols := [G.P_COLORS[0], CREAM, G.P_COLORS[1], Color("ffd23f")]
	var step := 120.0
	for j in 8:
		for i in 13:
			var delay := (i + j) / 20.0
			var k := clampf(wp * 1.6 - delay * 0.6, 0.0, 1.0)
			if k <= 0.0:
				continue
			var c := Vector2(i * step - 30.0, j * step - 40.0)
			draw_circle(c, 112.0 * k, cols[(i + j) % cols.size()])
