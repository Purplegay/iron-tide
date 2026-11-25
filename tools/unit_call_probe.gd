extends RefCounted
# Isolated diagnostic instrumentation. Never retains actor objects.
static var actors: Dictionary = {}
static func hit(actor, point: int) -> void:
	var id: int = actor.get_instance_id()
	if not actors.has(id): actors[id]={"instance":id,"type":actor.unit_id,"side":actor.side,"counts":[0,0,0,0,0,0,0,0]}
	actors[id].counts[point]+=1
static func take() -> Array:
	var rows: Array = actors.values()
	actors={}
	return rows
