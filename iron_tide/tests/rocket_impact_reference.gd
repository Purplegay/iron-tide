extends RefCounted
# Frozen pre-optimization full-scan oracle; do not derive from the spatial implementation.
static func impact_candidates(shot) -> Array:
	var result: Array
	var native_spread: bool = shot.base_damage > 0 and not str(shot.ra2_warhead).begins_with("RA3_") and Ra2Damage.cells(shot.ra2_warhead) > 0.0
	if native_spread or shot.splinters.get("force_fire", false):
		result = shot.get_tree().get_nodes_in_group("ally_targets") + shot.get_tree().get_nodes_in_group("enemy_targets")
	elif not BattleRequest.house_teams.is_empty():
		result = shot.get_tree().get_nodes_in_group(BattleRequest.foes_group(shot.owner_side))
	else:
		result = shot.get_tree().get_nodes_in_group("ally_targets" if shot.owner_side == "ally" else "enemy_targets")
	# A projectile can outlive its target. Use its last known layer in that case.
	var ground_only: bool = shot.splinters.get("bomb_drop", false) or (is_instance_valid(shot.target) and shot.target is ForceFirePoint)
	if native_spread or ground_only or shot.splinters.has("flak_airburst"):
		var air: bool = shot.splinters.get("impact_air", false)
		if ground_only:
			air = false
		elif shot.splinters.get("hero_air_shell", false):
			air = true
		elif shot.splinters.has("flak_airburst"):
			air = shot.splinters.flak_airburst
		elif AlliedAbilities.alive(shot.target) and shot.target is Unit:
			air = shot.target.is_air_target()
		result = result.filter(func(actor):
			if not AlliedAbilities.alive(actor): return false
			if actor is Unit: return actor.embarked_in == null and actor.is_air_target() == air
			return not air)
	if Ra2Damage._extra(shot.ra2_warhead, "AffectsAllies").to_lower() in ["no", "false", "0"]:
		result = result.filter(func(actor): return not BattleRequest.friendly(actor.side,shot.owner_side))
	return result

