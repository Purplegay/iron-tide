extends Ra2Fx
## Unit warp rings, independent of the Chronosphere superweapon blast.
## Original Flat/Layer=ground/Translucent art; playback uses the documented adapter.

var world: Node

static func spawn(battle, pos: Vector2, image: String) -> Node:
	var metadata := RA2Art.fx(image)
	if metadata.is_empty():
		return null
	var effect = load("res://scripts/world/chrono_miner_fx.gd").new()
	effect.world = battle
	effect.anim = metadata
	effect.fps = float(metadata.get("fps", NOMINAL_FPS))
	effect.position = pos
	effect.z_as_relative = false
	effect.z_index = DepthLayers.GROUND_OBJ + 1
	effect.tint = Color(1.0, 1.0, 1.0, 0.5)
	# Initialize visibility synchronously: deferred fog filtering must not flash
	# a hidden enemy's destination for a frame.
	effect.visible = battle.position_visible_to("ally", pos)
	battle.effects_root.add_child(effect)
	return effect

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		queue_free()
		return
	visible = world.position_visible_to("ally", global_position)
	if world.paused or world.ended:
		return
	super._process(maxf(0.0, delta))
