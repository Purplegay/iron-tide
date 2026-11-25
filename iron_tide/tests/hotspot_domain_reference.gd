extends Unit
func _weapon_domain_valid(target, check_cover := false, resolved_weapon: Dictionary = {}) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(47)
	if not is_instance_valid(target): return false
	if not BattleRequest.house_teams.is_empty() and target.side != side and BattleRequest.friendly(side,target.side) and not ForceFire.active(self,target): return false
	if unit_id == "R3APOC" and special.get("soviet_mode", false):
		if not (target is Building or (target is Unit and target.ground_contact_eligible() and not AlliedAbilities.infantry(target))): return false
	if unit_id == "SQD" and not SovietSpecials.squid_target(target): return false
	if unit_id in ["IVAN","CIVAN"] and not SovietSpecials.accepts_bomb(self,target): return false
	if unit_id == "DRON" and not SovietWeapons.can_infest(target): return false
	if not NavalContact.weapon_allows(self, target): return false
	# Callers that already resolved the live weapon can share it within this
	# decision. Never retain it across ticks, target changes or passenger changes.
	var active := resolved_weapon if not resolved_weapon.is_empty() else _weapon_for_target(target)
	var c4 := CommandoCombat.building_c4(self, target)
	if not c4:
		var air: bool = target.is_air_target() if target.has_method("is_air_target") else target.get("is_air") == true
		if air:
			if not CombatMath.can_hit_air(active): return false
		else:
			var projectile: Dictionary = GameData.ra2_projectile(str(active.get("ra2_projectile", "")))
			var projectile_flags: Dictionary = projectile.get("extra", {})
			if projectile_flags.has("AG") and str(projectile_flags.AG).to_lower() in ["no", "false", "0"]:
				return false
			var raw: Dictionary = GameData.ra2_source_units.get(unit_id, {}).get("extra", {})
			if int(raw.get("LandTargeting", 0)) == 1 and target.get("is_naval") != true and not (target is Building and target.data.get("water_bound", false)):
				return false
	if not c4 and not AlliedAbilities.valid_weapon_target(self, target, active): return false
	var world := _battle_world()
	if world != null and not target is ForceFirePoint and not world.actor_visible_to(side,target,self) and not (unit_id=="DLPH" and NavalContact.visible_grip(world,side,target)):
		return false
	if c4: return not AlliedAbilities.frozen(self) and not AlliedAbilities.frozen(target)
	if check_cover and world is Battle and not world.wall_cells.is_empty() and WallArt.shot_blocked(world, self, target, active): return false
	if CommandoCombat.handles(self) and CommandoCombat.versus(active, target) <= 0.0: return false
	if target.has_method("ignores_warhead") and target.ignores_warhead(str(active.get("ra2_warhead", ""))):
		return false
	return true
