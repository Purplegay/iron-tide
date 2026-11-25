extends Node
## Render cadence is independent of the 15 Hz rules step. Hidden/paused units stop.
func _process(_delta:float) -> void:
	var actor=get_parent()
	if actor.night_skin==null or actor._dead or actor.embarked_in!=null:return
	if not actor.is_physics_processing() or not actor.is_visible_in_tree():return
	if actor._body_visibility!=null and not actor._body_visibility.is_on_screen():return
	actor.queue_redraw()
