extends "res://scripts/ui/battle_cursor.gd"
func original_sample_pointer(world: Vector2) -> String:
	# Edge scrolling moves the entire world beneath a stationary cursor.
	# Actual clicks still perform their own pixel hit-test at dispatch.
	if battle.edge_panning and not battle.dragging and battle.command_mode.is_empty() and battle.armed_build.is_empty() and battle.cast_slot < 0 and not Input.is_key_pressed(KEY_CTRL):
		battle._set_hover(null)
		return "pan"
	if battle.dragging or battle._rmb_panning:
		battle._set_hover(null)
		return original_resolve(world)
	var hit = battle._pick_at(world, false)
	battle._set_hover(hit)
	return original_resolve(world, hit == null)

func original_resolve(world: Vector2, empty_pixels := false) -> String:
	if battle._rmb_panning or battle.dragging:
		return "pan" if battle._rmb_panning else "arrow"
	if battle.command_mode == "mcv_site": return "deploy" if battle.mcv_site(world).ok else "blocked"
	if not battle.armed_build.is_empty():
		return "move" if battle.build_spot_ok(world, GameData.get_building(battle.armed_build), true).ok else "blocked"
	if battle.command_mode == "superweapon" and is_instance_valid(battle._armed_superweapon):
		var source = battle._armed_superweapon
		match source.sw_type():
			"SpyPlane": return "spy_plane"
			"AmerParaDrop": return "para_drop" if source.sw_ready() and preload("res://scripts/world/american_paradrop.gd").valid_zone(battle,world) else "blocked"
			"IronCurtain", "MultiMissile":
				if not source.sw_ready() or not preload("res://scripts/units/soviet_specials.gd").can_aim_at(source,world): return "blocked"
				return "iron" if source.sw_type()=="IronCurtain" else "nuke"
	if battle.cast_slot >= 0:
		var caster = battle.selected_skill_unit()
		if is_instance_valid(caster):
			var skill = caster.ability_at(battle.cast_slot)
			if skill != null and skill.id == "allied_engineer":
				var site = battle.support_order_target(world)
				if not AlliedAbilities.can_order(caster, site, skill.id): return "enter_blocked"
				return engineer_cursor(caster, site)
	if battle.cast_slot >= 0 or battle.command_mode == "superweapon":
		return "attack"
	if battle.command_mode in ["repair", "sell"]:
		var action: String = battle.command_mode
		var building = battle._pick_building_at(world, "")
		return action if battle.building_action_reason(action, building).is_empty() else action + "_blocked"
	if battle.command_mode.is_empty() and Input.is_key_pressed(KEY_CTRL) and not ForceFire.selection(battle).is_empty():
		return "attack" if ForceFire.available(battle, ForceFire.pick(battle, world)) else "blocked"
	var target = null if empty_pixels else battle._pick_enemy_at(world)
	if target != null and not battle.actor_alive(target):
		target = null
	if battle.has_selected_attack_building() and target!=null and battle.command_mode in ["","attack"]:
		return attack_cursor(target)
	if battle.command_mode == "attack":
		return attack_cursor(target) if target != null else ("attack" if ForceFire.available(battle, ForceFire.pick(battle, world)) else "blocked")
	if battle.command_mode == "attack_move":
		return "attack_move"
	if battle.command_mode in ["move", "patrol"]:
		return "move"
	var friendly = null if empty_pixels else battle._pick_at(world)
	if is_instance_valid(battle.selected_building) and not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
		if battle.can_click_evacuate(friendly):
			return "undeploy"
	var deploy_target = battle.pointer_deploy_candidate()
	if deploy_target != null and deploy_target == friendly and not Input.is_key_pressed(KEY_SHIFT):
		if not deploy_target.deploy_building_id().is_empty(): return "deploy" if battle.construction_deploy_check(deploy_target).ok else "blocked"
		if deploy_target.unit_id == "SCHP" and not deploy_target.logistics.SiegeChopper.can_begin(deploy_target, not deploy_target.is_deployed()): return "blocked"
		if deploy_target.is_deployed():
			return "undeploy"
		return "deploy_infantry" if deploy_target.unit_id == "E1" else "deploy"
	var friendly_building = null if empty_pixels else battle._pick_building_at(world, "ally")
	if not Input.is_key_pressed(KEY_CTRL) and not battle.refinery_return_miners(friendly_building).is_empty():
		return "enter" if friendly_building.is_operational() else "enter_blocked"
	if battle.command_mode == "harvest":
		return "harvest"
	if not Input.is_key_pressed(KEY_CTRL):
		var landing: Dictionary = battle.airfield_order_status(friendly_building)
		if not landing.is_empty(): return "enter" if not landing.available.is_empty() else "enter_blocked"
	var special_target = battle.support_target_from_pick(world, friendly, true, empty_pixels)
	for unit in battle.selected_units:
		if not battle.actor_alive(unit): continue
		var action := AlliedAbilities.default_order(unit, special_target)
		if action == "ivan_bridge": return "attack"
		if action == "allied_engineer": return engineer_cursor(unit, special_target)
		if not action.is_empty(): return "repair" if action in ["allied_repair", "allied_bridge", "tesla_charge"] else "enter"
	if not Input.is_key_pressed(KEY_CTRL):
		var boarding: Dictionary = battle.boarding_order_status(special_target)
		if not boarding.is_empty():
			return "enter" if not boarding.passengers.is_empty() else "enter_blocked"
	if battle._cursor_on_ore(world):
		return "harvest"
	var depot = battle.repair_facility_from_pick(world, friendly_building)
	if depot != null and depot.is_repair_depot() and not battle.selected_units.is_empty():
		for unit in battle.selected_units:
			if battle.actor_alive(unit) and unit.can_repair_at(depot): return "repair"
		return "repair_blocked"
	if target != null and not battle.selected_units.is_empty():
		return attack_cursor(target)
	var selectable = friendly if friendly != null else battle.inspected_target_on(target)
	if is_instance_valid(selectable) and selectable.hp > 0.0 and not selectable.is_queued_for_deletion():
		return "select"
	if not battle.selected_units.is_empty() and battle.right_click_move:
		return "move"
	return "arrow"
