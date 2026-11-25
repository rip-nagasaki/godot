extends Node2D
## Redraws every frame through a callback, so game logic can draw into a chosen layer.

var draw_fn: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
