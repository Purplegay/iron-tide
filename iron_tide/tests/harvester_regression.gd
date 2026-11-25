extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	seed(20261020)
	print("HARVEST ", mode, " initial map")
	await check_starting_miners(mode)
	print("HARVEST ", mode, " controlled return")
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	# The two fixed refinery/ore fixtures below exercise land logistics.
	# The real coastal map and its water were already exercised above.
	battle.water_rects.clear()
	battle.path_service.set_water([])
	battle._refresh_pathing()
	for actor in battle.units.duplicate():
		actor.free()
	battle.units.clear()
	for ore in get_tree().get_nodes_in_group("resource_nodes"):
		ore.amount = 0.0
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(2050, 1600))
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	check(miner._pick_home_base() == null, mode + ": no operational refinery means no substitute HQ unloading")
	miner._back_in = true
	miner._dock_phase = 1
	miner.order_move(Vector2(2200, 1600))
	check(not miner._back_in and miner._dock_phase == 0, mode + ": manual move cancels reverse posture")
	var ore := ResourceNode.new()
	ore.position = Vector2(2200, 1600)
	battle.add_child(ore)
	ore.process_mode = Node.PROCESS_MODE_DISABLED
	miner._back_in = true
	miner._dock_phase = 1
	miner.order_harvest(ore)
	check(not miner._back_in and miner._dock_phase == 0, mode + ": new harvest order cancels docking")
	check(miner._path_pts.is_empty(), mode + ": new harvest order discards the old manual path")
	var refinery = battle._place_building("GAREFN", "ally", Vector2(1600, 1600), true)
	refinery._buildup_play = -1.0
	check_route_and_berth(mode,refinery,ore)
	await check_stranded_miner(mode)

	var factory = battle._place_building("GAWEAP", "ally", Vector2(1000, 1600), true)
	factory._buildup_play = -1.0
	check(refinery.can_queue("CMIN") and factory.can_queue("CMIN"), mode + ": original factory and unlocked refinery both produce miners")
	var enemy_refinery = battle._place_building("GAREFN", "enemy", Vector2(2600, 1600), true)
	enemy_refinery._buildup_play = -1.0
	var enemy = battle.spawn_unit("CMIN", "enemy", Vector2(2800, 1600))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	check(enemy._pick_home_base() == enemy_refinery, mode + ": enemy miners select their own refinery")
	battle.units.erase(enemy)
	enemy.free()
	# The last resource can be depleted while a miner still has a full load.
	ore.amount = 0.0
	miner._unlock_dock()
	miner._back_in = false
	miner._path_pts.clear()
	miner.home_base = refinery
	miner.harvest_state = "to_base"
	miner.has_move_order = false
	miner.cargo = miner.cargo_cap
	var funds: float = battle.funds
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	for tick in 2400:
		await get_tree().physics_frame
		if miner.cargo == 0.0:
			break
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	check(miner.cargo == 0.0 and battle.funds > funds, mode + ": full cargo returns and pays even when all ore is depleted",
		{"state": miner.harvest_state, "position": str(miner.global_position), "cargo": miner.cargo})
	check(not miner._back_in, mode + ": unloading releases reverse state")
	print("HARVEST ", mode, " round trips")
	await check_round_trips(mode, miner, ore, refinery)
	print("HARVEST ", mode, " manufacturing")
	await check_production(mode, refinery, factory)
	screen.free()
	await get_tree().process_frame

func check_starting_miners(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var miners: Array = []
	var loaded: Dictionary = {}
	var returned: Dictionary = {}
	var enemy_funds_before: float = battle.enemy_funds
	for unit in battle.units:
		if unit.is_harvester:
			miners.append(unit)
			unit.process_mode = Node.PROCESS_MODE_ALWAYS
			check(is_instance_valid(unit.home_base), mode + ": starting " + unit.side + " miner owns an actual refinery")
			if not is_instance_valid(unit.home_base):
				screen.free()
				await get_tree().process_frame
				return
			unit.home_base.process_mode = Node.PROCESS_MODE_ALWAYS
			check(not battle.path_service.is_blocked(unit.position), mode + ": starting miner has a walkable spawn")
	check(miners.filter(func(u): return u.side == "ally").size() == 2, mode + ": both starting miners are preserved")
	check(miners.filter(func(u): return u.side == "enemy").size() == 1, mode + ": enemy starts with one real miner")
	for tick in 18000:
		await get_tree().physics_frame
		for miner in miners:
			if miner.cargo > 0.0:
				loaded[miner] = true
			elif loaded.has(miner) and miner.harvest_state == "to_node":
				returned[miner] = true
		if returned.size() == miners.size():
			break
	var states: Array = []
	for miner in miners:
		states.append({"position": str(miner.position), "state": miner.harvest_state, "cargo": miner.cargo})
	check(returned.keys().filter(func(u): return u.side == "ally").size() == 2,
		mode + ": both initial miners complete a real map collection and deposit", states)
	check(returned.keys().any(func(u): return u.side == "enemy") and battle.enemy_funds > enemy_funds_before,
		mode + ": enemy miner completes real collection, docking and owner payment", states)
	screen.free()
	await get_tree().process_frame

func photo(name: String) -> void:
	print("HARVEST photo ", name)
	battle._update_depth_order()
	screen.hud._update_production_live()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var drawn := Engine.get_frames_drawn()
		for tick in 120:
			await get_tree().process_frame
			if Engine.get_frames_drawn() > drawn:
				break
		check(Engine.get_frames_drawn() > drawn, name + ": rendering advances before capture")
		if Engine.get_frames_drawn() <= drawn:
			return
		stage.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func check_round_trips(mode: String, miner, ore, refinery) -> void:
	ore.amount = ore.max_amount
	miner.order_harvest(ore)
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	var deliveries := 0
	var last_cargo: float = miner.cargo
	var bad_reverse := 0
	var backwards_travel := 0
	var chrono_returns := 0
	var saw_reverse := false
	var saw_unload := false
	var funds: float = battle.funds
	var last_pos: Vector2 = miner.global_position
	battle.camera.position = refinery.global_position + Vector2(220, 0)
	battle.camera.zoom = Vector2(1.5, 0.75)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for tick in 12000:
		await get_tree().physics_frame
		if last_cargo > 0.0 and miner.cargo == 0.0:
			deliveries += 1
		last_cargo = miner.cargo
		var travel: Vector2 = miner.global_position - last_pos
		if miner._back_in:
			saw_reverse = true
			if miner._dock_phase != 1 or miner.global_position.distance_to(miner._dock_pt) > 66.0:
				bad_reverse += 1
		elif travel.length() > maxf(12.0, miner.move_speed / 60.0 * 2.0):
			chrono_returns += 1
			check(miner.unit_id == "CMIN" and miner.harvest_state == "to_base" and miner.cargo > 0.0 and miner.velocity.is_zero_approx() and miner.global_position.distance_to(miner._dock_stage()) < 0.1,
				mode + ": discontinuous return is a loaded teleport to refinery staging, not ordinary movement")
		elif travel.length() > 0.1 and travel.normalized().dot(Vector2.RIGHT.rotated(miner.hull_angle)) < -0.05:
			backwards_travel += 1
		last_pos = miner.global_position
		if miner.harvest_state == "unloading" and not saw_unload:
			saw_unload = true
			refinery._tick_anim_state(0.0)
			check(refinery._anim_state == "special" and refinery.unloading_miner() == miner,
				mode + ": real harvest-return cycle activates original unloading animation")
			check(miner.global_position.distance_to(miner._dock_pt) <= miner.DOCK_STOP + 1.0,
				mode + ": unload starts only at the dock")
			await photo(mode + "-miner-unloading")
			last_pos = miner.global_position
		if deliveries == 2:
			break
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	check(deliveries == 2 and battle.funds > funds, mode + ": two real mine-return-unload cycles complete",
		{"deliveries": deliveries, "state": miner.harvest_state, "pos": str(miner.global_position), "dock": str(miner._dock_pt)})
	check(saw_reverse and saw_unload and bad_reverse == 0, mode + ": reversing is confined to the dock approach", bad_reverse)
	check(chrono_returns == 2, mode + ": each complete collection cycle includes one chrono return", chrono_returns)
	check(backwards_travel == 0, mode + ": long-distance travel faces forwards", backwards_travel)
	# A move order must be honored, then automatic collection can resume.
	miner.position = Vector2(2250, 2000)
	var destination := Vector2(2400, 2000)
	miner.order_move(destination)
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	for tick in 600:
		await get_tree().physics_frame
		if not miner.has_move_order:
			break
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	check(not miner.has_move_order and miner.global_position.distance_to(destination) <= miner.ARRIVE_EPS + 5.0,
		mode + ": manual movement reaches its destination", str(miner.global_position))
	# Losing the refinery must preserve cargo, not unload at another building.
	refinery.under_construction = true
	miner.home_base = refinery
	miner.harvest_state = "to_base"
	miner.cargo = miner.cargo_cap
	var held: float = miner.cargo
	funds = battle.funds
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	for tick in 90:
		await get_tree().physics_frame
	miner.process_mode = Node.PROCESS_MODE_DISABLED
	check(miner.cargo == held and battle.funds == funds and not miner._back_in,
		mode + ": unavailable refinery preserves cargo and clears reversing")
	refinery.under_construction = false
	# Two returning miners share one dock without forcing entry after a timeout.
	miner.position = Vector2(2050, 1600)
	var peer = battle.spawn_unit("CMIN", "ally", Vector2(2110, 1660))
	for u in [miner, peer]:
		u.process_mode = Node.PROCESS_MODE_ALWAYS
		u.home_base = refinery
		u.harvest_state = "to_base"
		u.has_move_order = false
		u.cargo = u.cargo_cap
		u._unlock_dock()
		u._clear_field()
	var paid: Array = []
	var overlap := false
	for tick in 3600:
		await get_tree().physics_frame
		var holders := 0
		for u in [miner, peer]:
			if u._dock_phase == 1:
				holders += 1
			if u.cargo == 0.0 and not paid.has(u):
				paid.append(u)
		overlap = overlap or holders > 1
		if paid.size() == 2:
			break
	for u in [miner, peer]:
		u.process_mode = Node.PROCESS_MODE_DISABLED
	check(paid.size() == 2 and not overlap, mode + ": two miners unload sequentially without dock deadlock",
		{"paid": paid.size(), "overlap": overlap, "a": str(miner.global_position), "b": str(peer.global_position)})
	battle.units.erase(peer)
	peer.free()
	battle.units.erase(miner)
	miner.free()

func click_button(button: Button) -> void:
	await get_tree().process_frame
	var center := button.get_global_rect().get_center()
	await mouse_button(center, true)
	await mouse_button(center, false)

func check_production(mode: String, refinery, factory) -> void:
	var hud = screen.hud
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_process(false)
	battle.select_building(refinery)
	battle._emit_selection()
	battle.power_low = false
	GM.no_build_time = false
	check(is_instance_valid(hud._refinery_btn), mode + ": selecting refinery exposes the manufacture action")
	check(hud._unit_catalog().has("CMIN") and factory.enqueue("CMIN"),
		mode + ": miner returns to war-factory sidebar and backend")
	factory.cancel_at(0)
	check(str(GameData.get_unit("CMIN").built_at) == "GAWEAP" and str(GameData.unit_index["CMIN"].built_at) == "GAWEAP",
		mode + ": original production owner is preserved")
	check(GM.unlock_production_tech and not hud._refinery_btn.disabled and hud._refinery_btn.tooltip_text.contains("调试已解锁"), mode + ": debug technology is explicitly unlocked by default")
	GM.unlock_production_tech = false
	hud._update_refinery_live()
	check(not refinery.can_queue("CMIN") and not refinery.enqueue("CMIN") and hud._refinery_btn.disabled and hud._refinery_btn.get_node("Content/Caption").text.contains("需要科技：矿场矿车制造"), mode + ": locked technology blocks UI and backend with named reason")
	check(factory.can_queue("CMIN"), mode + ": refinery technology never locks original war-factory miners")
	check(not battle.production_technology.unlock("unknown", "ally") and battle.production_technology.unlock("refinery_miner", "ally"), mode + ": valid technology can be granted independently of debug")
	hud._update_refinery_live()
	check(refinery.can_queue("CMIN") and not hud._refinery_btn.disabled and not battle.production_technology.is_unlocked("refinery_miner", "enemy"), mode + ": real grant enables only owner side")
	var next_match = load("res://scripts/rules/production_technology.gd").new()
	check(not next_match.is_unlocked("refinery_miner", "ally"), mode + ": technology grants do not leak across matches")
	battle.production_technology.unlocked.clear()
	GM.unlock_production_tech = true
	hud._update_refinery_live()
	var price: float = GameData.get_unit("CMIN").cost
	var duration: float = GameData.ra2_build_time(GameData.get_unit("CMIN")) / refinery.build_speed / refinery.production_work_rate("CMIN")
	battle.funds = price * 3.0
	var funds: float = battle.funds
	var units: int = battle.units.size()
	await click_button(hud._refinery_btn)
	check(refinery.production == ["CMIN"] and not refinery.enqueue("CMIN"),
		mode + ": actual HUD click starts exactly one miner")
	refinery._process(duration * 0.5)
	hud._update_refinery_live()
	check(is_equal_approx(battle.funds, funds - price * 0.5) and is_equal_approx(refinery.queue_progress(), 0.5),
		mode + ": manufacture charges once in proportion to progress")
	check(hud._refinery_btn.disabled and hud._refinery_btn.get_node("Content/Caption").text.contains("50%"),
		mode + ": busy action displays live progress and prevents duplicate activation")
	var paid_before: float = refinery.production_paid
	GM.unlock_production_tech = false
	refinery._process(duration)
	hud._update_refinery_live()
	check(is_equal_approx(refinery.queue_progress(), 0.5) and refinery.production_paid == paid_before and hud._refinery_btn.get_node("Content/Caption").text.contains("需要科技"), mode + ": locking technology pauses paid production without losing or charging progress")
	GM.unlock_production_tech = true
	hud._update_refinery_live()
	await photo(mode + "-refinery-manufacturing")
	await click_button(hud._refinery_cancel)
	check(refinery.production_paused() and is_equal_approx(refinery.queue_progress(), 0.5), mode + ": first cancel action pauses and preserves paid progress")
	await click_button(hud._refinery_cancel)
	check(refinery.production.is_empty() and is_equal_approx(battle.funds, funds) and battle.units.size() == units,
		mode + ": actual cancel button refunds paid progress without spawning")
	battle.funds = 0.0
	await click_button(hud._refinery_btn)
	refinery._process(duration)
	check(refinery.progress == 0.0 and refinery.production == ["CMIN"],
		mode + ": no funds pauses manufacturing")
	battle.funds = price * 0.25
	refinery._process(duration)
	check(is_equal_approx(refinery.queue_progress(), 0.25) and is_zero_approx(battle.funds),
		mode + ": partial funds buy only affordable progress")
	var saved_cost: PackedFloat32Array = battle.path_service.cost.duplicate()
	battle.path_service.cost.fill(-1.0)
	battle.funds = price
	refinery._process(duration)
	check(refinery.exit_blocked and refinery.production == ["CMIN"] and battle.units.size() == units,
		mode + ": blocked exit keeps the completed miner pending")
	funds = battle.funds
	refinery._process(duration)
	check(battle.funds == funds and battle.units.size() == units, mode + ": blocked exit does not charge or spawn again")
	battle.path_service.cost = saved_cost
	refinery._process(0.0)
	check(battle.units.size() == units + 1 and refinery.production.is_empty(), mode + ": cleared exit releases exactly one miner")
	var produced = battle.units[-1]
	check(produced.is_harvester and produced.home_base == refinery and produced.harvest_state == "to_node" and not produced.has_move_order,
		mode + ": new miner belongs to its refinery and automatically starts collecting")
	refinery._buildup_play = 0.0
	check(not refinery.enqueue("CMIN"), mode + ": unfinished refinery cannot activate manufacture")
	refinery._buildup_play = -1.0

func check_route_and_berth(mode: String, refinery, ore) -> void:
	var start:Vector2=ore.position+Vector2(320,0)
	var far=battle.spawn_unit("HARV","ally",start)
	far.order_harvest(ore)
	var bend:Vector2=start+Vector2(250,0)
	far.set_agent_path(PackedVector2Array([start,bend,ore.position]))
	for step in 6:
		far.position=start+Vector2(20*step,0)
		far._track_stuck(0.8,ore.position,true)
	check(far.resource_node==ore and far._path_pts.size()==3 and far._stuck_n==0,mode+": travelling away from the ore toward a valid bend retains the mine and route")
	far._track_stuck(1.3,ore.position,true)
	check(far._path_pts.is_empty() and far._stuck_n==1,mode+": a genuinely stationary miner still retries")
	var near=battle.spawn_unit("HARV","ally",refinery.refinery_dock_point(far.radius)+refinery.refinery_dock_direction()*far.DOCK_STAGE_BACK)
	for u in [far,near]:
		u.home_base=refinery
		u.harvest_state="to_base"
		u._lock_dock()
	check(near._dock_occupied()==false and far._dock_occupied(),mode+": a distant road miner cannot reserve the berth ahead of an arrival")
	near._dock_phase=1
	far.position=near.position+Vector2(25,0)
	check(far._dock_occupied(),mode+": arriving peer waits while another miner reverses")
	for u in [far,near]:
		u._unlock_dock()
		battle.units.erase(u)
		u.free()

func check_stranded_miner(mode: String) -> void:
	var coast := Rect2(2500,2100,300,300)
	battle.water_rects=[coast]
	battle.path_service.set_water([coast])
	var u=battle.spawn_unit("HARV","ally",Vector2(2502,2200))
	u.process_mode=Node.PROCESS_MODE_ALWAYS
	u.set_physics_process(false)
	await get_tree().physics_frame
	var start:Vector2=u.position
	for tick in 30: u._move_water_safe()
	check(not battle.in_water_world(u.position) and u.position.distance_to(start)<30,mode+": miner just inside the waterline drives back to the nearby bank")
	u.position=coast.get_center()
	var middle:Vector2=u.position
	for tick in 30: u._move_water_safe()
	check(u.position==middle,mode+": shore recovery cannot drive across open water")
	battle.units.erase(u)
	u.free()
	battle.water_rects.clear()
	battle.path_service.set_water([])
