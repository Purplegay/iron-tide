class_name ForceFirePoint
extends RefCounted
## An order coordinate, never a scene actor/collider or an automatic target.
var global_position := Vector2.ZERO
var side := "enemy"
var is_naval := false
var hp := 1.0
var _dead := false
var special: Dictionary = {}
var armor := "none"
var ra2_armor := "none"
var is_air := false
var radius := 0.0
var display_name := "地面"
var position: Vector2:
	get: return global_position

func art_center() -> Vector2:
	return global_position

func receive_hit(damage: float, _attack_type := "bullet", _bonus: Dictionary = {}, source = null, _warhead := "") -> void:
	var world = null
	if is_instance_valid(source) and source is Unit: world = source._battle_world()
	elif is_instance_valid(source) and source is Building: world = source.battle
	preload("res://scripts/world/bridge_damage.gd").hit(world,global_position,damage,source)
