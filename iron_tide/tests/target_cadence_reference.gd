extends "res://tests/target_cadence_actor.gd"
func _target_refresh_interval()->float:
	if side!="ally" and not is_instance_valid(attack_target) and not has_move_order and not attack_move and not attack_ordered and _return_timer<=0.0:
		var world:=_battle_world()
		if world!=null and world.units.size()>=128:return TARGET_REFRESH*2.0
	return TARGET_REFRESH
