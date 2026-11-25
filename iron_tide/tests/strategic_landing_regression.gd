extends "res://tests/base_recovery_regression.gd"
const Ops = preload("res://scripts/world/skirmish_operations.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Landing = preload("res://scripts/world/skirmish_landing.gd")
const Support = preload("res://scripts/world/skirmish_support.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for layout in ["crossings", "strait"]:
		for size in [2400, 3200, 4000]:
			var soviet: bool = size == 3200
			BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size":size, "map_layout":layout, "starting_funds":12000, "enemy_base":"soviet" if soviet else "allied", "fog_of_war":true})
			screen = load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode = Node.PROCESS_MODE_DISABLED
			battle = screen.battle
			for b in battle.buildings: b._buildup_play = -1
			var ai = battle.skirmish_ai
			var rect: Rect2 = battle.water_rects[0]
			var home := Landing.beach(battle, rect, ai.rally)
			var away := Landing.beach(battle, rect, battle.player_start())
			prefix = str(layout) + "/" + str(size) + " "
			check(home.has("land") and away.has("land"), prefix + "open beaches")
			check(battle.buildings.filter(func(b): return b.is_refinery()).size() >= 2, prefix + "both mining openings")
			var intact: Array = battle.buildings.filter(func(b): return b.special.get("bridge_repaired",false))
			if layout == "crossings":
				check(intact.size() == 1 and battle.path_service.same_zone(home.land, away.land), prefix + "intact crossing connects opposite starts")
				Sites.break_bridge(intact[0])
				check(not battle.path_service.same_zone(home.land, away.land), prefix + "breaking only intact bridge severs ground route")
				Sites.repair(intact[0])
				check(battle.path_service.same_zone(home.land, away.land), prefix + "bridge repairs restore route")
			else:
				check(intact.is_empty() and not battle.path_service.same_zone(home.land, away.land), prefix + "strait separates armies")
			check(battle.path_service.same_zone(home.sea, away.sea,true), prefix + "continuous fleet route")
			if layout == "strait" and size < 4000: await landing(ai, home, away, soviet)
			if size == 2400 and layout == "crossings": await strategic(ai)
			await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func landing(ai, home: Dictionary, away: Dictionary, soviet: bool) -> void:
	var id := "SAPC" if soviet else "LCRF"
	var yard_id: String = battle.roster_id("GAYARD","enemy")
	var yard_point: Vector2 = Ops.build_spot(ai,yard_id)
	check(yard_point.is_finite(), prefix + "AI can place real yard")
	if not yard_point.is_finite(): return
	var yard = battle._place_building(yard_id,"enemy",yard_point,true)
	yard._buildup_play = -1
	Ops.train_navy(ai, 0, true)
	check(yard.production.has(id), prefix + "AI prioritizes paid transport production")
	yard._process(120)
	var ships: Array = battle.units.filter(func(u): return u.unit_id == id)
	check(ships.size() == 1, prefix + "transport exits shipyard")
	if ships.is_empty(): return
	var ship = ships[0]
	var troops := []
	for i in 2:
		troops.append(battle.spawn_unit("E2" if soviet else "E1","enemy", home.land + Vector2(65 + i * 40, 65)))
	for u in troops + [ship]:
		u.process_mode = Node.PROCESS_MODE_ALWAYS
		u.set_physics_process(false)
	for b in battle.buildings: b.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	ship.order_stop()
	var rest_position: Vector2 = ship.position
	var idle_heights: Array[float] = []
	for frame in 180:
		ship._physics_process(1.0 / 60.0)
		if frame >= 60: idle_heights.append(ship._visual_lift())
	check(idle_heights.max() - idle_heights.min() > 2 and ship.position.is_equal_approx(rest_position) and not ship.is_air_target(), prefix + "parked hovercraft bobs while its world position and target domain stay fixed")
	var sailing_heights: Array[float] = []
	var crossed := false
	var resumed := false
	for frame in 10800:
		if frame % 60 == 0: Landing.tick(ai, ship, [])
		for u in troops + [ship]: u._physics_process(1.0 / 60.0)
		if ship.logistics.passengers.size() == 2 and battle.on_water(ship.position): crossed = true
		if ship.special.get("beach_mission", {}).get("phase") == "sail" and battle.on_water(ship.position) and ship.velocity.length() > 10 and ship._visual_lift() > 10:
			sailing_heights.append(ship._visual_lift())
		if crossed and not resumed and soviet:
			var codec := preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot := codec.capture(battle)
			check(BattleSaves.validate(snapshot).is_empty(), prefix + "loaded transport mission serializes")
			codec.restore(battle,snapshot)
			battle.paused = false
			get_tree().paused = false
			ai = battle.skirmish_ai
			ship = battle.units.filter(func(u): return u.unit_id == id)[0]
			troops = ship.logistics.passengers.duplicate()
			for u in troops + [ship]:
				u.process_mode = Node.PROCESS_MODE_ALWAYS
				u.set_physics_process(false)
			await get_tree().physics_frame
			resumed = true
		if ship.special.get("beach_mission",{}).get("phase","") == "return_sea": break
	var info := [ship.position, ship.special.get("beach_mission"), ship.is_amphibious, ship.logistics.passengers.size(), troops[0].position, troops[0].move_target]
	check(crossed, prefix + "both real passengers cross water aboard", info)
	check(sailing_heights.size() > 60 and sailing_heights.max() - sailing_heights.min() > 2, prefix + "loaded hovercraft keeps bobbing under way")
	check(troops.all(func(u): return u.embarked_in == null and not u.special.has("ai_transport_reserved") and battle.path_service.same_zone(u.position, away.land) and u.attack_move), prefix + "unloaded infantry attack on opposing bank",info)
	var pickup: Vector2 = ship.special.beach_mission.home.land
	for frame in 9000:
		if frame % 60 == 0: Landing.tick(ai, ship, [])
		for unit in troops: unit._physics_process(1.0 / 60.0)
		ship._physics_process(1.0 / 60.0)
		if ship.special.beach_mission.phase == "load" and ship.position.distance_to(pickup) < 60: break
	check(ship.special.beach_mission.phase == "load" and ship.position.distance_to(pickup) < 60, prefix + "empty ship returns to its original pickup beach", [ship.special.beach_mission,ship.position,ship.move_target,ship.has_move_order])

func strategic(ai) -> void:
	var goal: Vector2 = battle.player_start()
	var radar = battle._place_building("NARADR","enemy",ai.rally,true)
	radar._buildup_play = -1
	radar._sw_charge = radar.sw_recharge()
	battle.enemy_power.low = false
	check(not battle.position_visible_to("enemy",goal), "recon target initially hidden")
	Ops.tick(ai)
	var planes: Array = battle.units.filter(func(u): return u.unit_id == "SPYP")
	check(planes.size() == 1 and radar._sw_charge == 0, "AI launches radar scout through shared recharge")
	if not planes.is_empty():
		var plane = planes[0]
		for i in 1000:
			preload("res://scripts/units/soviet_specials.gd").fly_scout(plane,0.1)
			if battle.position_visible_to("enemy",goal) or plane.is_queued_for_deletion(): break
		check(battle.position_visible_to("enemy",goal), "actual aerial photography reveals target")
	var lab = battle._place_building("GATECH","enemy",ai.rally + Vector2(240,0),true)
	lab._buildup_play = -1
	lab._sw_charge = lab.sw_recharge()
	var enemy_hq = battle.buildings.filter(func(b): return b.side == "enemy" and b.is_hq)[0]
	var attacker = battle.spawn_unit("MTNK","ally",enemy_hq.position + Vector2(130,0))
	enemy_hq.hp *= 0.6
	battle.fog.rebuild()
	Support.consider(ai,lab,[attacker])
	check(lab.sw_ready(), "no blackout for old damage alone")
	attacker.attack_target = enemy_hq
	Ops.tick(ai)
	check(enemy_hq.special.get("force_shield_left",0) > 0 and battle.allied_state.get("blackout_enemy",0) > 0, "AI shield protects targeted HQ and incurs blackout")
	battle.allied_state.erase("blackout_enemy")
	battle.enemy_power.low = false
	var device = battle._place_building("GACSPH","enemy",ai.rally + Vector2(-180,0),true)
	device._buildup_play = -1
	device._sw_charge = device.sw_recharge()
	var tank = battle.spawn_unit("MTNK","enemy",ai.rally + Vector2(175,180))
	var origin: Vector2 = tank.position
	var infantry = battle.spawn_unit("E2","enemy",origin+Vector2(0,40))
	var target = battle.buildings.filter(func(b): return b.side == "ally" and b.is_hq)[0]
	battle._chrono_source_point = Vector2(25,25)
	battle.fog._reveal("enemy",target.position,420)
	Support.consider(ai,device,[target])
	check(tank.position == origin and device.sw_ready(), "mixed source with organic infantry rejected")
	infantry.position += Vector2(0,350)
	Support.consider(ai,device,[target])
	check(tank.position.distance_to(target.position) < 400 and tank.attack_target == target and device._sw_charge == 0 and battle._chrono_source_point == Vector2(25,25), "AI armour attacks from safe landing without changing player targeting")
	await get_tree().process_frame
