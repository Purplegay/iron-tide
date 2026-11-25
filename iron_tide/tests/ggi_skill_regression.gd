extends "res://tests/deploy_pointer_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = screen.hud
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	get_window().focus_entered.emit()
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var unit = actor("GGI", "ally", Vector2(1600, 1600))
	var peer = actor("GGI", "ally", Vector2(1650, 1650))
	var other = actor("E1", "ally", Vector2(1550, 1650))
	var target = actor("MTNK", "enemy", Vector2(1800, 1600))
	var far = actor("MTNK", "enemy", Vector2(2150, 1600))
	far.hp = 1.0
	unit.sight = 800.0
	await render_frame()
	battle.select_unit(unit, false)
	battle._emit_selection()
	check(unit.ability_at(0).id == "ggi_deploy" and unit.ability_at(1).id == "ggi_guard", mode + " innate E/Q exist without unlocks")
	check(hud.ability_panel.visible and hud._ability_btns.size() >= 2, mode + " actual HUD shows innate abilities")
	check(hud._ability_btns[2].tooltip_text.contains("[E]") and hud._ability_btns[0].tooltip_text.contains("[Q]"), mode + " tooltips match shortcuts")
	var stats: Dictionary = unit.bonuses.duplicate(true)
	var money: float = battle.funds
	await key(KEY_E)
	hud._update_ability_live()
	check(unit.is_deployed() and unit._active_weapon().ra2_weapon_id == "YR_MissileLauncher", mode + " E switches original missile weapon")
	check(not unit.is_prone() and not unit.crushable and unit.min_range == 55.0, mode + " preserves GGI protection and missile blind spot")
	check(hud._ability_btns[2].get_meta("name_label").text == "收起导弹" and hud._ability_btns[2].get_meta("cd").text == "✓", mode + " deployed button shows current state")
	await key(KEY_J)
	hud._update_ability_live()
	check(not unit.is_deployed() and hud._ability_btns[2].get_meta("name_label").text == "部署导弹", mode + " J synchronizes skill state")
	# Real pointer deployment and skill button share exactly the same state.
	place_art_at(unit, Vector2(650, 400))
	battle._last_click_ms = 0
	await point(Vector2(650, 400))
	# Restore the synthetic viewport focus after native render-window creation.
	get_window().focus_entered.emit()
	await gesture(Vector2(650, 400), Vector2(650, 400))
	hud._update_ability_live()
	check(unit.is_deployed() and unit.ability_info(0).active, mode + " mouse deployment synchronizes skill state")
	hud._ability_btns[2].pressed.emit()
	check(not unit.is_deployed() and unit.ability_info(0).cooldown == 0.0, mode + " skill button immediately undeploys without artificial cooldown")
	unit.position = Vector2(1600, 1600)
	unit.order_move(Vector2(1900, 1600))
	unit.order_queue.append(Vector2(2000, 1600))
	unit.fire_stance = "none"
	await key(KEY_Q)
	check(unit.hold_position and not unit.has_move_order and unit.order_queue.is_empty() and unit.fire_stance == "free", mode + " Q halts movement/queue and enables automatic fire")
	unit._refresh_target()
	check(unit.attack_target == target, mode + " guard chooses reachable target over far low-health target")
	check(await damage_automatically(unit, target) > 0.0, mode + " standing guard fires real weapon and damages target")
	check(unit.position.distance_to(Vector2(1600, 1600)) < 0.01, mode + " standing guard remains in place")
	target.position = Vector2(2200, 1600)
	unit._cancel_burst()
	unit._refresh_target()
	for tick in 60: unit._physics_process(1.0 / 60.0)
	check(unit.attack_target == null and not unit.has_move_order and unit.position.distance_to(Vector2(1600, 1600)) < 0.01, mode + " guard never pursues distant enemies")
	await key(KEY_E)
	check(unit.is_deployed() and unit.hold_position, mode + " deploy and hold remain independent toggles")
	target.position = Vector2(1900, 1600)
	target.hp = target.max_hp
	check(await damage_automatically(unit, target) > 0.0, mode + " deployed guard fires real missiles")
	target.position = unit.position + Vector2(30, 0)
	unit._cancel_burst()
	unit._refresh_target()
	check(unit.attack_target == null and not unit._weapon_target_valid(target), mode + " guard respects missile blind spot")
	hud._update_ability_live()
	await photo(mode + "-ggi-both-skills-active")
	hud._ability_btns[0].pressed.emit()
	check(not unit.hold_position and unit.is_deployed(), mode + " guard button releases hold without undeploying")
	await key(KEY_E)
	unit.order_move(Vector2(1800, 1500))
	check(unit.has_move_order and unit.move_speed > 0.0, mode + " releasing both toggles restores move orders")
	check(unit.bonuses == stats and battle.funds == money, mode + " toggles add no combat bonuses or cost")
	# Native slots never cast an unrelated ability on another selected unit.
	other.skills.clear()
	for i in 2:
		var ability := Ability.new()
		ability.setup({"id": "fixture_heal_" + str(i), "effect": "heal", "value": 0.2, "cooldown": 10})
		other.skills.append(ability)
	other.hp = other.max_hp * 0.5
	battle.select_unit(peer, true)
	battle.select_unit(other, true)
	check(battle.use_ability_selected(0) == 2 and unit.is_deployed() and peer.is_deployed(), mode + " group E deploys both guardians")
	check(other.skills[0].cd_left == 0.0 and other.hp == other.max_hp * 0.5, mode + " group E does not cast other unit's slot zero")
	check(battle.use_ability_selected(1) == 2 and unit.hold_position and peer.hold_position and other.skills[1].cd_left == 0.0, mode + " group Q guards only guardians")
	battle.select_unit(other, false)
	battle.select_unit(unit, true)
	check(battle.use_ability_selected(0) == 0 and unit.is_deployed() and other.hp == other.max_hp * 0.5, mode + " retired unassigned skill cannot cast or toggle mixed guardian")
	battle.select_unit(unit, false)
	battle._emit_selection()
	for blocked in ["stunned", "embarked", "dead", "repairing"]:
		unit._stun_timer = 1.0 if blocked == "stunned" else 0.0
		unit.embarked_in = peer if blocked == "embarked" else null
		unit.hp = 0.0 if blocked == "dead" else unit.max_hp
		unit.repairing = blocked == "repairing"
		for slot in 2:
			check(not unit.ability_ready(slot) and not unit.use_ability(slot), mode + blocked + " blocks native slot " + str(slot))
	unit._stun_timer = 0.0
	unit.embarked_in = null
	unit.hp = unit.max_hp
	unit.repairing = false
	check(unit.ability_ready(0) and unit.ability_ready(1), mode + " native skills recover after temporary restrictions")
	await check_group_deploy_priority(mode)
	screen.free()
	await get_tree().process_frame

func check_group_deploy_priority(mode: String) -> void:
	var gi = actor("E1", "ally", Vector2(1400, 1400))
	var ggi = actor("GGI", "ally", Vector2(1450, 1400))
	var unselected = actor("E1", "ally", Vector2(1500, 1400))
	var vehicle = actor("AMCV", "ally", Vector2(1350, 1400))
	unselected.deploy()
	for first in [gi, ggi]:
		var second = ggi if first == gi else gi
		if first.is_deployed(): first.deploy()
		if second.is_deployed(): second.deploy()
		battle.select_unit(first, false)
		battle.select_unit(second, true)
		battle.select_unit(vehicle, true)
		battle._emit_selection()
		await key(KEY_E)
		check(gi.is_deployed() and ggi.is_deployed(), mode + " group E deploys GI and GGI together with " + first.unit_id + " first")
		first.deploy()
		screen.hud._update_ability_live()
		check(screen.hud._ability_btns[2].get_meta("name_label").text == "全部部署", mode + " mixed states advertise deployment with standing leader")
		await key(KEY_E)
		check(gi.is_deployed() and ggi.is_deployed(), mode + " mixed group E deploys standing member without reversing deployed peer")
		check(unselected.is_deployed() and is_instance_valid(vehicle) and not vehicle._dead, mode + " group E leaves unselected infantry and MCV unchanged")
		check(screen.hud._ability_btns[2].get_meta("name_label").text == "全部起立", mode + " fully deployed group advertises standing")
		second.deploy()
		screen.hud._ability_btns[2].pressed.emit()
		check(gi.is_deployed() and ggi.is_deployed(), mode + " E button deploys mixed group with deployed leader")
		check(gi.is_prone() and not ggi.is_prone() and ggi._active_weapon().ra2_weapon_id == "YR_MissileLauncher", mode + " mixed infantry retain their distinct deployed stances and weapons")
		await key(KEY_E)
		check(not gi.is_deployed() and not ggi.is_deployed(), mode + " fully deployed GI and GGI stand together on next E")
	# Same-type selection follows the same priority, without touching other types.
	var gi_peer = actor("E1", "ally", Vector2(1550, 1400))
	gi_peer.deploy()
	battle.select_unit(gi, false)
	battle.select_unit(gi_peer, true)
	battle._emit_selection()
	await key(KEY_E)
	check(gi.is_deployed() and gi_peer.is_deployed() and not ggi.is_deployed(), mode + " same-type mixed state deploys only selected infantry")
	await key(KEY_E)
	check(not gi.is_deployed() and not gi_peer.is_deployed(), mode + " same-type fully deployed group stands together")
	battle.select_unit(gi, false)
	battle.select_unit(ggi, true)
	battle._emit_selection()
	gi.deploy()
	ggi._stun_timer = 1.0
	await key(KEY_E)
	check(gi.is_deployed() and not ggi.is_deployed(), mode + " blocked standing member cannot deploy and does not reverse deployed peers")
	ggi._stun_timer = 0.0
	await key(KEY_E)
	check(gi.is_deployed() and ggi.is_deployed(), mode + " recovered standing member deploys on next E")
	ggi._stun_timer = 1.0
	await key(KEY_E)
	check(not gi.is_deployed() and ggi.is_deployed(), mode + " fully deployed group stands only members able to act")
	ggi._stun_timer = 0.0
	await key(KEY_E)
	check(gi.is_deployed() and ggi.is_deployed(), mode + " partial stand result returns to deployment priority")
	await key(KEY_E)
	check(not gi.is_deployed() and not ggi.is_deployed(), mode + " all recovered deployed members stand together")

func actor(id: String, side: String, at: Vector2):
	var unit = battle.spawn_unit(id, side, at)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.order_stop()
	return unit

func damage_automatically(unit, target) -> float:
	var before: float = target.hp
	unit._cd_timer = 0.0
	unit._cancel_burst()
	unit._think_timer = 0.0
	unit.attack_target = null
	unit.attack_ordered = false
	unit.hull_angle = unit.position.direction_to(target.position).angle()
	unit.turret_angle = unit.hull_angle
	var host: Node = unit._pick_projectile_parent()
	var previous := host.get_children()
	for tick in 60:
		unit._physics_process(1.0 / 60.0)
		if host.get_child_count() > previous.size(): break
	for child in host.get_children():
		if previous.has(child) or not child is Projectile: continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if child.is_queued_for_deletion(): break
			child._physics_process(1.0 / 60.0)
		child.free()
	await get_tree().process_frame
	return before - target.hp
