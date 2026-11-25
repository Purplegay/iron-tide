extends RefCounted
## Enemy-only deployment policy. Uses exported weapons and ordinary unit orders.
## Timing and tactical thresholds are IronTide adaptations, not native AI scripts.

const Soviet = preload("res://scripts/units/soviet_specials.gd")

static func release(unit, resume := false) -> void:
	var mission: Dictionary = unit.special.get("ai_deploy_mission", {})
	if unit.is_deployed() and unit.unit_id in ["E1", "GGI", "DESO", "SCHP"]:
		if not unit.set_deployed(false, false): return
	unit.special.erase("ai_rad_approach")
	unit.special.erase("ai_deploy_mission")
	unit.special.erase("ai_deploy_quiet")
	if not resume or mission.is_empty(): return
	var target = mission.get("target")
	if AlliedAbilities.alive(target) and not BattleRequest.friendly(target.side,unit.side) and unit._battle_world().actor_visible_to(unit.side, target):
		preload("res://scripts/world/skirmish_operations.gd").order_attack(unit, target)
	elif mission.get("moving", false):
		unit.ai_order("move",mission.point, mission.attack)
	elif mission.get("guard", false):
		unit.ai_order("guard")
	else:
		unit.ai_order("stop")

static func remember(unit) -> void:
	if not unit.special.has("ai_deploy_mission"):
		unit.special.ai_deploy_mission = {"moving":unit.has_move_order, "point":unit.move_target,
			"attack":unit.attack_move, "guard":unit.hold_position, "target":unit.attack_target if unit.attack_ordered else null}

# Use the same range, armor verses and falloff as the live radiation field.
static func radiation_weight(actor, point: Vector2, radius: float, warhead: String) -> float:
	if not Soviet.radiation_susceptible(actor): return 0.0
	return maxf(0.0, 1.0 - actor.position.distance_to(point) / radius) * GameData.ra2_verse(warhead, actor.ra2_armor)

static func radiation_score(world, unit, visible: Array, point: Vector2, radius: float, warhead: String) -> float:
	var score := 0.0
	for enemy in visible:
		score += radiation_weight(enemy, point, radius, warhead)
	if score < 1.0: return 0.0
	for friend in world.units:
		if friend != unit and world.actor_alive(friend) and BattleRequest.friendly(friend.side,unit.side) and radiation_weight(friend, point, radius, warhead) > 0:
			return 0.0
	return score

static func desolator(world, unit, visible: Array) -> void:
	var radius := float(unit.data.deployed_weapon.range)
	var warhead: String = Soviet.radiation_rules().warhead
	var nearby := visible.filter(func(enemy): return enemy.position.distance_to(unit.position) <= maxf(unit.sight, radius) + radius and Soviet.radiation_susceptible(enemy))
	if radiation_score(world, unit, nearby, unit.position, radius, warhead) >= 1.0:
		if not unit.is_deployed():
			remember(unit)
			unit.set_deployed(true, false)
			unit.special.erase("ai_rad_approach")
		return
	if unit.is_deployed():
		release(unit, true)
		return
	# Step to a reachable edge of a nearby group, without chasing across the map.
	var best := Vector2.INF
	var best_score := 0.0
	for enemy in nearby:
		if unit.position.distance_to(enemy.position) > maxf(unit.sight, radius): continue
		if radiation_weight(enemy, enemy.position, radius, warhead) <= 0.0: continue
		var point: Vector2 = enemy.position.move_toward(unit.position, radius * 0.4)
		if not world.path_service.same_zone(unit.position, point): continue
		var score := radiation_score(world, unit, nearby, point, radius, warhead)
		if score > best_score:
			best_score = score
			best = point
	if best.is_finite():
		if not unit.special.has("ai_rad_approach") or not unit.has_move_order or unit.move_target.distance_to(best) > PathService.CELL:
			remember(unit)
			unit.ai_order("move",best)
			unit.special.ai_rad_approach = true
	elif unit.special.has("ai_rad_approach"):
		release(unit, true)

static func threatens_landing(target, unit) -> bool:
	if target is Building and not target.is_operational(): return false
	var gun: Dictionary = target._weapon_for_target(null) if target is Unit else target.weapon
	if gun.is_empty(): return false
	var raw: Dictionary = GameData.ra2_projectile(str(gun.get("ra2_projectile",""))).get("extra", {})
	if str(raw.get("AG","yes")).to_lower() in ["no","false","0"]: return false
	var distance: float = target.position.distance_to(unit.position)
	return distance >= float(gun.get("min_range",0)) and distance <= float(gun.range) and CombatMath.full_damage(gun,unit.armor,target.bonuses,null,unit.ra2_armor) > 0.0

static func value(unit, target, weapon: Dictionary) -> float:
	if weapon.is_empty(): return 0.0
	var airborne: bool = target is Unit and target.is_air_target()
	if airborne and not CombatMath.can_hit_air(weapon): return 0.0
	if not airborne and not bool(weapon.get("ra2_ag", true)): return 0.0
	var distance: float = unit.global_position.distance_to(target.global_position)
	if distance > float(weapon.get("range", 0)) or distance < float(weapon.get("min_range", 0)): return 0.0
	return CombatMath.full_damage(weapon, target.armor, {}, target.bonuses, target.ra2_armor, 0.0, target) \
		* maxi(1, int(weapon.get("burst", 1))) / maxf(0.1, float(weapon.get("cooldown", 1)))

static func tick(ai, dt: float) -> void:
	var world = ai.battle
	if world.paused or world.ended or world.get_tree().paused or ai.enemy_base == "swarm": return
	var elapsed := float(ai.ai_state.get("ai_micro_elapsed", 0.0)) + dt
	if elapsed < 0.5:
		ai.ai_state.ai_micro_elapsed = elapsed
		return
	ai.ai_state.ai_micro_elapsed = 0.0
	var contacts := {}
	for unit in world.units:
		if not is_instance_valid(unit) or unit.side != ai.house_id: continue
		if unit.unit_id not in ["E1","GGI","DESO","SCHP"] and not (unit.is_naval and unit._return_timer>0.0): continue
		if not world.actor_alive(unit): continue
		if not world.ai_dispatch.defer_job(world,unit,"micro",elapsed): unit_decision(ai,unit,null,elapsed,contacts)

static func unit_decision(ai,unit,visible,elapsed:float,batch:Dictionary = {}) -> void:
	var world = ai.battle
	if unit.is_naval and unit._return_timer > 0.0:
		preload("res://scripts/world/skirmish_operations.gd").naval_counterfire(ai, unit)
	if unit.unit_id not in ["E1", "GGI", "DESO", "SCHP"]: return
	if unit.special.has("ai_oil_post"): return
	if unit.embarked_in != null or unit.repairing or unit._stun_timer > 0.0 \
			or unit.special.has("temporal_by") or unit.logistics.boarding != null \
			or unit.special.get("ai_transport_reserved", false) or unit.fire_stance == "none": return
	if visible == null and (unit.unit_id in ["DESO", "SCHP"] or world.units.size() < 96 or batch.has(ai.house_id)):
		visible = ai.Operations.visible_contacts(ai, null, batch)
	if unit.unit_id == "DESO":
		desolator(world, unit, visible)
		return
	if unit.unit_id == "SCHP":
		if unit.special.has("siege_progress"): return
		if visible.any(func(enemy): return threatens_landing(enemy, unit)):
			if unit.is_deployed(): release(unit, true)
			return
	var primary: Dictionary = unit.data.get("elite_weapon", unit.weapon) if unit.veteran_level >= 2 else unit.weapon
	var deployed: Dictionary = unit.data.get("elite_deployed_weapon", unit.data.get("deployed_weapon", {})) if unit.veteran_level >= 2 else unit.data.get("deployed_weapon", {})
	var chosen = null
	var score := 0.0
	var standing_score := 0.0
	var outer := maxf(float(primary.get("range", 0.0)), float(deployed.get("range", 0.0)))
	var origin: Vector2 = unit.global_position
	var local := visible == null
	var candidates: Array = world.neighborhood.nearby(origin, outer) if local else visible
	for target in candidates:
		if not is_instance_valid(target) or origin.distance_squared_to(target.global_position) > outer * outer:
			continue
		if target is Building and WallArt.is_wall(target.data): continue
		if local and (not world.actor_alive(target) or not BattleRequest.is_house(target.side) or BattleRequest.friendly(target.side,ai.house_id) or not world.actor_visible_to(ai.house_id,target)):
			continue
		var standing := value(unit, target, primary)
		standing_score = maxf(standing_score, standing)
		var deployed_value := value(unit, target, deployed)
		if deployed_value <= standing * 1.1: continue
		# Prefer a useful weapon match and finishing an already wounded target.
		var priority: float = deployed_value / maxf(1.0, target.hp)
		if priority > score or (local and priority == score and chosen != null and earlier_contact(world, target, chosen)):
			score = priority
			chosen = target
	if chosen != null:
		if not unit.is_deployed():
			remember(unit)
			if not unit.set_deployed(true, false):
				unit.special.erase("ai_deploy_mission")
				return
		unit.special.ai_deploy_quiet = 0.0
		unit.attack_target = chosen
		unit.attack_ordered = unit.unit_id == "SCHP"
	elif unit.is_deployed():
		var quiet := float(unit.special.get("ai_deploy_quiet", 0.0)) + elapsed
		unit.special.ai_deploy_quiet = quiet
		# Immediate response to the GGI minimum-range/anti-infantry case;
		# brief no-contact grace avoids oscillation at the edge of sight.
		if standing_score > 0.0 or quiet >= 2.0: release(unit, true)

# Match the global contact list's stable tie order (units before buildings).
static func earlier_contact(world, a, b) -> bool:
	if (a is Unit) != (b is Unit):
		return a is Unit
	var list: Array = world.units if a is Unit else world.buildings
	return list.find(a) < list.find(b)
