extends "res://scripts/modes/mode_base.gd"
## Hot potato: the bomb has a hidden fuse. Touch your rival to pass it on.

var holder := 0
var fuse := 15.0
var pass_cd := 0.0
var tick_t := 0.0
var spark_t := 0.0
var exploded := false
var end_timer := -1.0
var hop := 0.0
var from_pos := Vector2.ZERO


func _init() -> void:
	id = "bomb"
	title = "Hot Potato"
	rule = "Don't hold the bomb when it blows! Touch your rival to pass it."
	layout = "square"
	time_limit = 0.0
	respawn_delay = 0.9


func spawn_point(i: int) -> Vector2:
	return game.arena.center + Vector2(-170.0 if i == 0 else 170.0, 0.0)


func setup() -> void:
	holder = randi() % 2
	fuse = randf_range(14.0, 21.0)


func _bomb_pos() -> Vector2:
	var b = game.blobs[holder]
	var target: Vector2 = b.head_pos() + Vector2(0, -6)
	if hop > 0.0:
		var k := 1.0 - hop / 0.2
		return from_pos.lerp(target, k) + Vector2(0, -sin(k * PI) * 60.0)
	return target


func update(dt: float) -> void:
	t += dt
	if exploded:
		if end_timer > 0.0:
			end_timer -= dt
			if end_timer <= 0.0:
				finish(1 - holder)
		return
	fuse -= dt
	pass_cd -= dt
	hop -= dt
	for i in 2:
		game.blobs[i].speed_mult = 1.12 if i == holder else 1.0
	tick_t -= dt
	if tick_t <= 0.0:
		tick_t = clampf(fuse / 9.0, 0.09, 0.7)
		Sfx.play("tick", -6.0, 1.0 + clampf((6.0 - fuse) * 0.1, 0.0, 0.6))
	spark_t -= dt
	if spark_t <= 0.0 and game.blobs[holder].state != 2:
		spark_t = 0.05
		game.fx.sparks(_bomb_pos() + Vector2(14, -26), Color(1, 0.8, 0.3), 2, 160.0, Vector2.UP, PI)
	if fuse <= 0.0:
		_explode()


func _explode() -> void:
	exploded = true
	end_timer = 1.4
	var b = game.blobs[holder]
	var p: Vector2 = b.body_center()
	game.fx.explosion(p, 1.5)
	game.flash(Color(1, 0.9, 0.7), 0.5)
	game.shake(28.0)
	game.hitstop(0.12)
	Sfx.play("explode", 2.0)
	if b.is_active():
		b.take_hit(Vector2.from_angle(randf_range(-PI * 0.8, -PI * 0.2)) * 400.0, 1.5)
	b.sad = true


func on_contact(a, b) -> void:
	if exploded or pass_cd > 0.0:
		return
	var victim = null
	if a.idx == holder:
		victim = b
	elif b.idx == holder:
		victim = a
	if victim == null or not victim.is_active():
		return
	from_pos = _bomb_pos()
	holder = victim.idx
	pass_cd = 0.7
	hop = 0.2
	Sfx.play("steal", -2.0, 0.8)
	game.fx.ring(victim.position, Color(1, 0.4, 0.3), 10.0, 70.0, 0.35, 6.0)
	game.fx.popup(victim.head_pos() + Vector2(0, -40), "PASSED!", Color(1, 0.6, 0.5), 24.0)


func light_points() -> Array:
	return [[_bomb_pos(), 120.0]]


func draw_top(ci: CanvasItem) -> void:
	if exploded:
		return
	var b = game.blobs[holder]
	if b.state == 2:
		return
	var danger := clampf((5.0 - fuse) / 5.0, 0.0, 1.0)
	var flash := 0.0
	if danger > 0.0:
		flash = (0.5 + 0.5 * sin(t * (8.0 + danger * 30.0))) * danger
	var s := 1.0 + flash * 0.15
	G.draw_bomb(ci, _bomb_pos(), 18.0 * s, flash, t)


func draw_glow(ci: CanvasItem) -> void:
	if exploded:
		return
	var p := _bomb_pos()
	G.glow(ci, p + Vector2(14, -26), 26.0 + sin(t * 30.0) * 5.0, Color(1, 0.8, 0.3, 0.8))
	var danger := clampf((5.0 - fuse) / 5.0, 0.0, 1.0)
	if danger > 0.0:
		G.glow(ci, p, 90.0, Color(1, 0.2, 0.1, 0.35 * danger * (0.5 + 0.5 * sin(t * 20.0))))


func draw_hud(ci: CanvasItem) -> void:
	if exploded:
		return
	var c: Color = G.P_COLORS[holder]
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (2.0 if fuse < 5.0 else 0.0)
	G.draw_bomb(ci, Vector2(520, 128) + jitter, 13.0, 0.0, t)
	G.text(ci, Vector2(660, 127) + jitter, "%s has the bomb!" % G.P_NAMES[holder], 22, c.lightened(0.3), 5)


func draw_icon(ci: CanvasItem, pos: Vector2, s: float, tt: float) -> void:
	G.glow(ci, pos + Vector2(16, -24) * s, 30.0 * s, Color(1, 0.8, 0.3, 0.8))
	G.draw_bomb(ci, pos + Vector2(0, sin(tt * 6.0) * 3.0 * s), 30.0 * s, 0.5 + 0.5 * sin(tt * 8.0), tt)
