extends Node2D
## Detached presentation only: never registered as a projectile or saved actor.
const Visual = preload("res://scripts/units/projectile_visual.gd")
var points: Array[Vector2] = []
var color := Color.WHITE
var decrement := 16.0 / 255.0
var age := 0.0

func _process(delta: float) -> void:
	var world := get_parent().get_parent()
	if world.get("paused") == true or world.get("ended") == true: return
	age += delta
	if age * 15.0 * decrement >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	Visual.paint_path(self, points, "line", color, decrement, color, age * 15.0)
