extends "res://scripts/modes/mode_base.gd"
## Classic ring-out: last jelly standing wins. The island crumbles over time.

const CRUMBLE_AT := 10.0

var crumbling := false
var loser := -1
var end_timer := -1.0
var debris_t := 0.0


func _init() -> void:
	id = "sumo"
	title = "Sky Sumo"
	rule = "Knock your rival off the island!"
	layout = "circle"
	time_limit = 0.0


func allows_respawn() -> bool:
	return false


func update(dt: float) -> void:
	t += dt
	if t > CRUMBLE_AT and not finished:
		if not crumbling:
			crumbling = true
			game.banner("THE ISLAND IS CRUMBLING!", Color("ffd166"), 1.4, 46)
			Sfx.play("meteor", -4.0, 0.6)
			game.shake(8.0)
		game.arena.shrink = maxf(0.38, 1.0 - (t - CRUMBLE_AT) * 0.032)
		debris_t -= dt
		if debris_t <= 0.0:
			debris_t = 0.04
			var a := randf() * TAU
			var r: float = 250.0 * game.arena.shrink
			var p: Vector2 = game.arena.center + Vector2(cos(a), sin(a)) * r
			game.fx.drift(p, Vector2(randf_range(-30, 30), randf_range(120, 260)), game.arena.theme["side"], randf_range(3.0, 7.0), 0.9)
	if end_timer > 0.0:
		end_timer -= dt
		if end_timer <= 0.0:
			finish(1 - loser)


func on_fall(b) -> void:
	if loser == -1:
		loser = b.idx
		end_timer = 1.0


func draw_hud(ci: CanvasItem) -> void:
	if loser != -1:
		return
	if not crumbling:
		var left := int(ceil(CRUMBLE_AT - t))
		G.text(ci, Vector2(640, 128), "Island crumbles in %d" % left, 20, Color(1, 1, 1, 0.85), 5)
	else:
		var a := 0.6 + 0.4 * sin(t * 8.0)
		G.text(ci, Vector2(640, 128), "CRUMBLING!", 22, Color(1, 0.82, 0.4, a), 5)


func draw_icon(ci: CanvasItem, pos: Vector2, s: float, tt: float) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(s, s * 0.45))
	ci.draw_circle(Vector2(0, 30), 46.0, Color("4a2a1e"))
	ci.draw_circle(Vector2.ZERO, 46.0, Color("7cd957"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bx := sin(tt * 3.0) * 6.0 * s
	ci.draw_circle(pos + Vector2(-14 * s + bx, -10 * s), 13.0 * s, G.P_COLORS[0])
	ci.draw_circle(pos + Vector2(34 * s + bx * 2.0, -24 * s), 13.0 * s, G.P_COLORS[1])
	ci.draw_line(pos + Vector2(4 * s, -14 * s), pos + Vector2(20 * s, -20 * s), Color.WHITE, 4.0 * s)
