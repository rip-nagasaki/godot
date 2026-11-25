extends RefCounted
## Base class for the mini-games. Each round picks one of these.

var game
var id := ""
var title := ""
var rule := ""
var layout := "circle"
var time_limit := 40.0
var time_left := 40.0
var finished := false
var winner := -1
var overtime := false
var respawn_delay := 1.3
var scores: Array[float] = [0.0, 0.0]
var t := 0.0


func setup() -> void:
	pass


## Where each player starts (and respawns).
func spawn_point(i: int) -> Vector2:
	var c: Vector2 = game.arena.center
	return c + Vector2(-150.0 if i == 0 else 150.0, 0.0)


## Points that twists (like bumpers) should keep clear of.
func avoid_points() -> Array:
	return [spawn_point(0), spawn_point(1), game.arena.center]


func update(_dt: float) -> void:
	pass


func on_hit(_attacker, _victim) -> void:
	pass


func on_contact(_a, _b) -> void:
	pass


func on_fall(_b) -> void:
	pass


func on_respawn(_b) -> void:
	pass


func on_explosion(_pos: Vector2, _radius: float) -> void:
	pass


func allows_respawn() -> bool:
	return true


## Extra light pools for the "Lights Out" twist: Array of [Vector2, radius].
func light_points() -> Array:
	return []


func on_time_up() -> void:
	if scores[0] != scores[1]:
		finish(0 if scores[0] > scores[1] else 1)
	else:
		overtime = true


func check_overtime() -> void:
	if overtime and not finished and scores[0] != scores[1]:
		finish(0 if scores[0] > scores[1] else 1)


func finish(w: int) -> void:
	if finished:
		return
	finished = true
	winner = w


func score_label(i: int) -> String:
	return str(int(scores[i]))


func draw_ground(_ci: CanvasItem) -> void:
	pass


func draw_top(_ci: CanvasItem) -> void:
	pass


func draw_glow(_ci: CanvasItem) -> void:
	pass


## Mode-specific HUD under the timer.
func draw_hud(_ci: CanvasItem) -> void:
	pass


## Small pictogram used on the round intro card.
func draw_icon(_ci: CanvasItem, _pos: Vector2, _s: float, _t: float) -> void:
	pass
