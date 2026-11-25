# Frozen v0.30.46 function: independent before-change oracle.
extends "res://scripts/world/ai_unit_dispatch.gd"
func _entry(world,unit) -> Dictionary:
	return world.allied_state.get_or_add(WAITING,{}).get_or_add(unit,{"owner":unit.side})
