class_name ForceFire
extends RefCounted
## Ctrl-left orders share normal aiming, movement, ammo, cooldown and damage paths.
const KEY := "force_fire_target"

static func active(actor, target) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(target): return false
	if actor is Unit and (OpenTopped.active(actor) or actor.embarked_in is Building):
		return active(actor.embarked_in, target)
	return actor.special.get(KEY) == target and (not actor is Unit or actor.attack_ordered)

static func clear(actor) -> void:
	actor.special.erase(KEY)
	actor.special.erase("planned_attack")
	actor.special.erase("finished_attack_route")

static func pick(world, point: Vector2, sampled_actor = null, has_sample := false):
	if not point.is_finite() or point.x < 0 or point.y < 0 or point.x >= world.map_size or point.y >= world.map_size: return null
	# The unrestricted pointer pick already covers both units and buildings.
	var actor = sampled_actor if has_sample else world._pick_at(point, false)
	if world.actor_alive(actor) and world.actor_visible_to("ally", actor): return actor
	var ground := ForceFirePoint.new()
	ground.global_position = point
	ground.is_naval = world.path_service != null and world.path_service.in_water(point)
	return ground

static func selection(world) -> Array:
	if not world.selected_units.is_empty(): return world.selected_units
	return [world.selected_building] if world.actor_alive(world.selected_building) else []

static func reason(world, actor, target) -> String:
	if not world.actor_alive(actor) or actor.side != "ally" or not is_instance_valid(target): return "没有可下令的作战单位"
	if actor == target: return "不能直接攻击自身"
	if not world.actor_alive(target): return "目标已失效"
	if not target is ForceFirePoint and not world.actor_visible_to(actor.side, target,actor): return "目标不在视野中"
	if target is Unit and target.embarked_in != null: return "不能攻击载具内的乘员"
	var raw: Dictionary = AlliedAbilities.source(actor) if actor is Unit else GameData.ra2_source_buildings.get(actor.building_id, {}).get("extra", {})
	if GameData._ra2_flag(raw.get("NoManualFire", false)): return "该单位不能手动开火"
	if actor is Building and actor.data.has("garrison_weapons"):
		return preload("res://scripts/units/civilian_orders.gd").order_block_reason(actor,target,true)
	var weapon: Dictionary = actor._weapon_for_target(target) if actor is Unit else actor.weapon
	var blocked := weapon_reason(actor.side,target,weapon)
	if not blocked.is_empty(): return blocked
	if actor is Unit:
		if actor.embarked_in != null or actor._stun_timer > 0.0 or AlliedAbilities.frozen(actor): return "当前状态无法攻击"
		if actor.is_harvester or not actor.power_disabled_reason().is_empty(): return "当前单位无法开火"
		if actor.logistics.ammo_max > 0 and actor.logistics.ammo <= 0: return "弹药不足，先返场补充"
		if not actor.attack_domain_valid(target): return "武器不能攻击这种目标"
		if actor.is_deployed() and CommandoCombat.distance_to(actor, target) > OpenTopped.command_range(actor, target): return "部署状态下目标超出射程"
	else:
		if not actor.is_operational() or AlliedAbilities.frozen(actor): return "建筑尚未建成或未供电"
		if not actor._valid_weapon_target(target, true): return "目标不在建筑武器的有效射程内"
	return ""

static func weapon_reason(owner_side: String, target, weapon: Dictionary) -> String:
	if weapon.is_empty() or float(weapon.get("damage", 0.0)) <= 0.0: return "没有可用于攻击的武器"
	var wh := str(weapon.get("ra2_warhead", ""))
	if target is Building and target.ignores_warhead(wh): return "该弹头不能破坏围墙"
	if BattleRequest.friendly(target.side,owner_side) and Ra2Damage._extra(wh, "AffectsAllies").to_lower() in ["no", "false", "0"]: return "该武器不能伤害友军"
	if not target is ForceFirePoint and Ra2Damage.has(wh) and GameData.ra2_verse(wh, Ra2Damage.armor_of(target)) == 0.0: return "武器对该目标无效"
	return ""

static func available(world, target) -> bool:
	for actor in selection(world):
		if reason(world, actor, target).is_empty(): return true
	return false

static func issue(world, point: Vector2, append := false) -> int:
	var target = pick(world, point)
	var ordered := []
	var feedback := "没有可下令的作战单位"
	for actor in selection(world):
		var blocked := reason(world, actor, target)
		if not blocked.is_empty():
			feedback = blocked
			continue
		if actor is Unit:
			actor.order_target(target, true, append)
			ordered.append(actor)
			continue
		if actor.building_id=="R3REAPERTURRET":
			preload("res://scripts/units/ra3_reaper_split.gd").clear(actor)
		elif actor.data.has("charged_weapon"):
			actor.special.erase("coil_ordered_target")
		actor.special.erase("defense_ordered_target")
		actor.special[KEY] = target
		actor.attack_target = target
		ordered.append(actor)
	if not ordered.is_empty():
		world._add_order_mark(target.global_position, "attack")
		var voices := ordered.filter(func(actor): return actor is Unit)
		if not voices.is_empty(): world._play_group_voice(voices, "attack")
		Events.emit_message("强制攻击：" + str(target.display_name), Color(1.0, 0.65, 0.35))
	else: Events.emit_message(feedback, Color(1.0, 0.8, 0.5))
	return ordered.size()

static func impact_candidates(shot) -> Array:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(59)
	var result: Array
	var native_spread: bool = shot.base_damage > 0 and not str(shot.ra2_warhead).begins_with("RA3_") and Ra2Damage.cells(shot.ra2_warhead) > 0.0
	var groups: Array[String] = []
	if native_spread or shot.splinters.get("force_fire", false):
		groups.assign(["ally_targets", "enemy_targets"])
	elif not BattleRequest.house_teams.is_empty():
		groups.append(BattleRequest.foes_group(shot.owner_side))
	else:
		groups.append("ally_targets" if shot.owner_side == "ally" else "enemy_targets")
	result = _near_impact_groups(shot, groups)
	preload("res://scripts/world/battle_call_counters.gd").iterations(59, result.size())
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

# Only narrow the broad phase; the caller retains its exact distance, layer and
# damage rules. Group order and scene-tree order preserve chained-hit ordering.
static func _near_impact_groups(shot, groups: Array[String]) -> Array:
	var host: Node = shot.get_parent()
	var world = host.get_parent() if host != null else null
	var result: Array = []
	var spread := Ra2Damage.cells(shot.ra2_warhead) * Ra2Damage.PX_PER_CELL
	spread*=maxf(1.0,float(shot.splinters.get("spread_scale",1.0)))
	# Legacy AoE/ground shots use mutable actor radii rather than CellSpread.
	# Retain their existing path until that separate bound has an exact index.
	if not world is Battle or spread <= 0.0:
		for group in groups: result.append_array(shot.get_tree().get_nodes_in_group(group))
		return result
	var reach := spread
	# Falling bombs measure distance to a building footprint, not its origin.
	if shot.splinters.has("drop_height"): reach += world.neighborhood.max_footprint
	var nearby: Array = world.neighborhood.nearby(shot.target_point, reach)
	if nearby.size() * 2 >= world.neighborhood.membership.size():
		for group in groups: result.append_array(shot.get_tree().get_nodes_in_group(group))
		return result
	nearby.sort_custom(_scene_before)
	for group in groups:
		for actor in nearby:
			if actor.is_in_group(group): result.append(actor)
	return result

static func _scene_before(a: Node, b: Node) -> bool:
	return b.is_greater_than(a)

static func instant_ground(source, target: ForceFirePoint, weapon: Dictionary, damage: float, bonuses: Dictionary, host: Node) -> void:
	var shot := Projectile.new()
	shot.setup(target.global_position, target, weapon, damage, bonuses, source.side, source)
	shot.ra2_inviso = true
	host.add_child(shot)
