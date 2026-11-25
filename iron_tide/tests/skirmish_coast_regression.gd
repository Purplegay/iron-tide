extends "res://tests/ground_control_regression.gd"

const Ops = preload("res://scripts/world/skirmish_operations.gd")

func exercise(mode: String) -> void:
	for faction in ["allied","soviet"]:
		await naval_ai_opening(mode,faction)
		await restricted_water(mode,faction)
	for size in [2400, 3200, 4000]:
		BattleRequest.configure_skirmish(mode, {"map_size":size, "enemy_base":"soviet", "opening":"prebuilt", "fog_of_war":true})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		prefix = "%s %s: " % [mode, size]
		var crossings: Array = battle.buildings.filter(func(b): return b.special.has("bridge_span"))
		var intact: Array = crossings.filter(func(b): return b.special.bridge_repaired)
		check(crossings.size() == 4 and intact.size() == 2, prefix + "both lake crossings have two repair huts")
		if intact.size() == 2:
			var span: Rect2 = intact[0].special.bridge_span
			var west := Vector2(span.position.x - 15, span.get_center().y)
			var east := Vector2(span.end.x + 15, span.get_center().y)
			if size == 3200: await crossing_traffic(intact[0])
			check(battle.path_service.line_walkable(west, east, battle.path_service.cost), prefix + "ground route crosses the entire new bridge from bank to bank")
			if size == 3200 and mode == MatchRules.RA2 and DisplayServer.get_name() != "headless":
				var patrol: Array = []
				for point in [west, span.get_center(), east]:
					patrol.append(battle.spawn_unit("E1", "ally", point))
				battle.fog.rebuild()
				battle.camera.zoom = Iso.cam_zoom(1.4)
				battle.center_on(span.get_center())
				battle.camera.reset_smoothing()
				battle.camera.force_update_scroll()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				battle.get_viewport().get_texture().get_image().save_png(output_dir.path_join("inland-bridge.png"))
				for soldier in patrol:
					battle.units.erase(soldier)
					soldier.free()
				battle.fog.rebuild()
		var sea: Rect2 = battle.water_rects[1]
		check(sea.get_area() / float(size * size) >= 0.35, prefix + "open sea covers at least 35%")
		var dry_ore := true
		for node in get_tree().get_nodes_in_group("resource_nodes"):
			if battle.on_water(node.position): dry_ore = false
		check(dry_ore, prefix + "all generated ore stays on land")
		var ports: Array[Vector2] = []
		for side in ["ally","enemy"]:
			var id: String = battle.roster_id("GAYARD",side)
			var yard_data: Dictionary = GameData.get_building(id)
			var hq_y: float = size * (0.8 if side == "ally" else 0.16)
			var berth := Vector2.INF
			for dx in range(40, 241, 40):
				for dy in range(-320, 441, 40):
					var p: Vector2 = battle.snap_build_pos(Vector2(sea.position.x + dx, hq_y + dy))
					if battle.build_spot_ok(p,yard_data,true,side).ok:
						berth = p
						break
				if berth.is_finite(): break
			check(berth.is_finite(), prefix + side + " can place shipyard from starting base")
			if berth.is_finite():
				var yard = battle._place_building(id,side,berth,true)
				var exit_point: Vector2 = yard._spawn_point("DEST" if id == "GAYARD" else "SUB")
				check(exit_point.is_finite() and battle.on_water(exit_point), prefix + side + " ship exits into water")
				if exit_point.is_finite(): ports.append(exit_point)
		if ports.size() == 2:
			check(battle.path_service.same_zone(ports[0],ports[1],true) and not battle.path_service.find_path(ports[0],ports[1],true).is_empty(), prefix + "shipyard exits connected by a navigable route")
			for building in battle.buildings:
				if building.special.has("bridge_span"):
					preload("res://scripts/world/civilian_sites.gd").repair(building)
					check(battle.path_service.same_zone(ports[0],ports[1],true), prefix + "repaired bridge preserves naval route")
		var miners: Dictionary = {}
		for unit in battle.units:
			if unit.unit_id in ["CMIN","HARV"]: miners[unit.side] = unit.position
		check(miners.size() == 2 and battle.path_service.same_zone(miners.ally,miners.enemy), prefix + "starting miners share a land route between bases")
		await finish()
		if mode == MatchRules.RA2:
			BattleRequest.configure_skirmish(mode, {"map_size":size,"opening":"mcv","enemy_base":"soviet","fog_of_war":true})
			screen = load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode = Node.PROCESS_MODE_DISABLED
			battle = screen.battle
			for side in ["ally","enemy"]:
				var mcvs: Array = battle.units.filter(func(u): return u.side == side and u.unit_id in ["AMCV","SMCV"])
				var placement: Dictionary = battle.construction_deploy_check(mcvs[0]) if mcvs.size() == 1 else {"ok":false,"reason":"missing MCV"}
				check(placement.ok, prefix + side + " MCV can deploy at spawn",placement.get("reason",""))
			Ra2Sfx.stop_all()
			Music.stop()
			Music.player.stream = null
			await finish()

func crossing_traffic(hut) -> void:
	var nav = battle.path_service
	var span: Rect2 = hut.special.bridge_span
	var center := span.get_center()
	var north := center - Vector2(0, 100)
	var south := center + Vector2(0, 70)
	check(nav.line_walkable(north, south, nav.water_cost) and not nav.find_path(north, south, true).is_empty(), prefix + "continuous naval passage beneath intact deck")
	var tank = battle.spawn_unit("MTNK", "ally", center - Vector2(90, 0))
	var ship = battle.spawn_unit("DEST", "ally", center - Vector2(0, 60))
	for u in [tank, ship]:
		u.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		u.order_stop()
	tank.hull_angle = 0.0
	ship.hull_angle = PI / 2
	await get_tree().physics_frame
	tank.order_move(center + Vector2(125, 0))
	ship.order_move(south)
	var closest := INF
	for i in 600:
		tank._physics_process(1.0 / 60.0)
		ship._physics_process(1.0 / 60.0)
		closest = minf(closest, tank.position.distance_to(ship.position))
		if i % 30 == 0: await get_tree().physics_frame
		if tank.position.x > center.x + 80 and ship.position.y > center.y + 40: break
	battle._update_depth_order()
	check(closest < tank.radius + ship.radius and tank.position.x > center.x + 80 and ship.position.y > center.y + 40, prefix + "moving ship and tank cross in the same space", [closest,str(tank.position-center),str(ship.position-center)])
	check(ship.z_index < battle.get_node("CivilianSiteVisual").z_index and tank.z_index > battle.get_node("CivilianSiteVisual").z_index, prefix + "ship drawn beneath bridge and tank")
	check(ship.get_collision_exceptions().is_empty() and tank.get_collision_exceptions().is_empty(), prefix + "no residual collision exceptions")
	for u in [ship, tank]:
		battle.units.erase(u)
		u.free()
	var sites = preload("res://scripts/world/civilian_sites.gd")
	sites.break_bridge(hut)
	check(nav.is_blocked(center) and not nav.is_blocked(center,true) and nav.line_walkable(north,south,nav.water_cost), prefix + "demolition closes only the land route")
	sites.repair(hut)
	check(not nav.is_blocked(center) and not nav.is_blocked(center,true), prefix + "repair restores dual use")

func naval_ai_opening(mode: String, faction: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size":3200, "enemy_base":faction, "opening":"prebuilt", "starting_funds":12000, "fog_of_war":true})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var ai = battle.skirmish_ai
	var label := "%s %s navy: " % [mode,faction]
	var yard_id: String = battle.roster_id("GAYARD","enemy")
	var ship_id := "DEST" if faction == "allied" else "SUB"
	var ship
	var paid_yard := false
	var paid_ship := false
	# Advance ordinary AI decisions and its actual paid construction/production queues.
	for turn in 80:
		ai._process(9.0)
		if battle.enemy_struct_queue.any(func(job):return job.id == yard_id): paid_yard = true
		battle._tick_structure_queue(60.0)
		for b in battle.buildings.duplicate():
			if b.side != "enemy": continue
			if b.building_id == yard_id and b.production.has(ship_id): paid_ship = true
			b._process(60.0)
		for u in battle.units:
			if u.side=="enemy" and u.unit_id==ship_id: ship=u;break
		if ship != null: break
		await get_tree().physics_frame
	check(paid_yard and paid_ship and ship != null,label+"builds working yard and launches first combat ship without seeing player ships",[paid_yard,paid_ship,battle.enemy_funds])
	if ship != null:
		check(ship.has_move_order and battle.on_water(ship.move_target), label+"receives water departure order on launch")
		ship.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		await get_tree().physics_frame
		Ops.tick(ai)
		var origin: Vector2 = ship.position
		check(ship.has_move_order and battle.on_water(ship.move_target) and ship.move_target.distance_to(origin)>600,label+"sails out to scout unseen coast")
		for frame in 600:
			ship._physics_process(1.0/60.0)
			if frame%60 == 0: await get_tree().physics_frame
			if ship.position.distance_to(origin)>120: break
		check(ship.position.distance_to(origin)>120 and battle.on_water(ship.position),label+"physically clears port in water",str(ship.position))
		var target = battle.spawn_unit("DEST","ally",ship.position + Vector2(95,0))
		battle.fog.rebuild()
		Ops.tick(ai)
		check(ship.attack_target==target and ship.attack_ordered,label+"engages a revealed ship")
		var hp: float=target.hp
		for frame in 360:
			ship._physics_process(1.0/60.0)
			for shot in battle.projectiles_root.get_children():
				if shot is Projectile and not shot._detonated: shot._physics_process(1.0/60.0)
			if frame%60==0: await get_tree().physics_frame
			if target.hp<hp:break
		check(target.hp<hp,label+"naval fire damages opponent")
		await sustained_navy(ai,yard_id,mode,faction)
	await finish()

func sustained_navy(ai,yard_id:String,mode:String,faction:String) -> void:
	var yard=battle.buildings.filter(func(b):return b.side=="enemy" and b.building_id==yard_id)[0]
	var miner=battle.units.filter(func(u):return u.side=="enemy" and u.is_harvester)[0]
	var original_difficulty:int=ai.difficulty
	var player_miner=battle.units.filter(func(u):return u.side=="ally" and u.is_harvester)[0]
	for level in 4:
		ai.difficulty=level
		miner.cargo=4;miner.cargo_gems=0
		var value:float=miner.cargo_value()*preload("res://scripts/world/economy_cycle.gd").income_factor(battle,"enemy")
		var before:float=ai.funds
		miner._unload_cargo(4)
		check(is_equal_approx(ai.funds-before,value*[1,1,2,4][level]),faction+" ore payout at difficulty "+str(level),[ai.funds-before,value])
		var after_delivery:float=ai.funds
		battle.credit_income("enemy",100)
		check(is_equal_approx(ai.funds-after_delivery,100.0*[1,1,1.5,2][level]),faction+" separate ordinary income "+str(level))
		if level==2:
			player_miner.cargo=4;player_miner.cargo_gems=0
			var player_value:float=player_miner.cargo_value()*preload("res://scripts/world/economy_cycle.gd").income_factor(battle,"ally")
			var player_before:float=battle.funds
			player_miner._unload_cargo(4)
			check(is_equal_approx(battle.funds-player_before,player_value),faction+" player unload remains at face value on hard")
			battle.credit_side("enemy",50)
			check(is_equal_approx(ai.funds-before,2*value+150+50),faction+" refund is face value on hard")
	# Exercise consecutive purchases past the old force quotas with an established war chest.
	battle.enemy_funds=1000
	Ops.train_navy(ai,1000)
	check(yard.production.is_empty(),faction+" shipyard respects reserved funds")
	# One ore delivery can fund the first instalment but not an entire warship.
	var outstanding: float = preload("res://scripts/world/skirmish_tactics.gd").committed(battle)
	battle.enemy_funds = outstanding + 300
	Ops.train_navy(ai, 0, false)
	check(yard.production.is_empty(), faction + " off-turn spending leaves land budget intact")
	Ops.train_navy(ai, 1400, true)
	check(yard.production.is_empty(), faction + " naval priority preserves miner reserve")
	Ops.train_navy(ai, 0, true)
	check(yard.production.size() == 1, faction + " idle yard starts a ship from one partial payment")
	if yard.production.size() == 1:
		var uid: String = yard.production[0]
		battle.enemy_funds = 300
		yard._process(180)
		check(is_equal_approx(yard.production_paid, 300) and yard.production.has(uid), faction + " unpaid ship waits after spending only available funds")
		Ops.train_navy(ai, 0, true)
		check(yard.production.size() == 1, faction + " no unfunded second ship")
		battle.credit_side("enemy", battle.production_price(GameData.get_unit(uid), "enemy") - 300)
		yard._process(180)
		check(yard.production.is_empty() and battle.units.back().unit_id == uid, faction + " next ore delivery completes paid ship")
	if faction=="allied" and not battle.buildings.any(func(b):return b.side=="enemy" and b.building_id=="GATECH"):
		battle._place_building("GATECH","enemy",ai.base_center+Vector2(120,40),true)
	battle.enemy_funds=80000
	Ops.train_navy(ai, 0)
	Ops.train_navy(ai, 0)
	check(yard.production.size() == mini(2, yard.queue_capacity()), faction + " funded yard has successor ready")
	var ordered:Array=[]
	for turn in 36:
		ai._try_train()
		if yard.production.is_empty():continue
		var uid:String=yard.production[0]
		var previous:int=battle.units.size()
		var before:float=ai.funds
		yard._process(180)
		if battle.units.size()>previous:
			var ship=battle.units.back()
			if ship.is_naval and ship.side=="enemy" and ship.unit_id==uid:
				ordered.append(uid)
				check(is_equal_approx(before-ai.funds,battle.production_price(GameData.get_unit(uid),"enemy")),faction+" yard pays for "+uid)
				# Move this hull offshore to keep the port clear in this stepped-clock fixture.
				ship.position=battle.water_rects[1].get_center()+Vector2(0,ordered.size()*40)
		if ordered.size()>=9:break
	check(ordered.size()==9,mode+" "+faction+" launches nine further ships without losing the existing fleet",ordered)
	if faction=="allied":check("DLPH" in ordered,mode+" Allied AI purchases and launches a dolphin after tech unlock",ordered)
	ai.difficulty=original_difficulty

func restricted_water(mode: String, faction: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size":3200, "enemy_base":faction, "opening":"prebuilt", "fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var ai = battle.skirmish_ai
	var tag := mode+" "+faction+" pocket: "
	var port := Vector2(950,1300)
	var river := Rect2(port-Vector2(260,260),Vector2(520,520))
	var ocean := Rect2(1800,700,1300,2200)
	battle.water_rects.assign([river,ocean])
	var nav = battle.path_service
	nav.set_water(battle.water_rects)
	var yard_id: String = battle.roster_id("GAYARD","enemy")
	var yard = battle._place_building(yard_id,"enemy",port,true)
	yard._buildup_play = -1
	var basin: Dictionary = Ops.naval_basin(yard)
	check(basin.zone>0 and basin.interval==4,tag+" small connected river despite large separate sea")
	battle.enemy_funds=80000
	Ops.train_navy(ai,0,true)
	check(yard.production.is_empty(),tag+" leaves first purchasing turn to land")
	for i in 4: Ops.train_navy(ai,0)
	check(yard.production.size()==1,tag+" one order in four funded decisions",yard.production.duplicate())
	Ops.train_navy(ai,0)
	check(yard.production.size()==2,tag+" second patrol hull can be ordered")
	var dock = battle._place_building(yard_id,"enemy",port+Vector2(240,0),true)
	dock._buildup_play=-1
	for i in 8: Ops.train_navy(ai,0)
	check(dock.production.is_empty() and Ops.naval_basin(dock).zone==Ops.naval_basin(yard).zone,tag+" second yard shares count of ships on order")
	var hostiles := []
	for i in 3: hostiles.append(battle.spawn_unit("DEST","ally",ocean.get_center()+Vector2(i*60,0)))
	check(not Ops.limited_navy_turn(ai,dock,Ops.naval_basin(dock),hostiles,true),tag+" warships in unrelated sea do not raise local demand")
	for i in hostiles.size(): hostiles[i].position=port+Vector2(i*40,-200)
	check(Ops.limited_navy_turn(ai,dock,Ops.naval_basin(dock),hostiles,true),tag+" outnumbered in same water can reinforce")
	battle.water_rects[0] = Rect2(520,850,960,960)
	nav.set_water(battle.water_rects)
	battle._refresh_pathing()
	check(Ops.naval_basin(yard).interval==2,tag+" enlarged basin reclassified after terrain change")
	await finish()
