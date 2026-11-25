extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	check(GameData.unit_in_production_catalog("R3MIRAGE") == (mode == MatchRules.EXTENDED), mode + ": expansion roster isolated")
	check(GameData.unit_in_production_catalog("MGTK"), mode + ": RA2 mirage remains available")
	if mode == MatchRules.RA2:
		screen.free()
		await get_tree().process_frame
		return
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var factory = battle._place_building("GAWEAP", "ally", Vector2(900,900),true)
	check(not factory.can_queue("R3MIRAGE"), "RA3 clearance prerequisite enforced")
	for pair in [["GATECH",Vector2(1150,900)],["GAPOWR",Vector2(1150,1200)],["GACNST",Vector2(900,1200)]]:
		battle._place_building(pair[0],"ally",pair[1],true)
	for b in battle.buildings: b._buildup_play = -1.0
	check(not factory.can_queue("R3MIRAGE"), "RA2 lab does not substitute for RA3 highest clearance")
	var base=battle.buildings.filter(func(b):return b.building_id=="GACNST")[0]
	var refinery=battle._place_building("GAREFN","ally",Vector2(600,1200),true);refinery._buildup_play=-1.0
	battle.paused=false;battle.funds=10000.0
	check(Ra3Clearance.start(base),"actual advanced clearance purchase")
	Ra3Clearance.tick(base,float(Ra3Clearance.TIERS[2].seconds))
	check(not factory.can_queue("R3MIRAGE"),"advanced clearance alone does not unlock Mirage")
	check(Ra3Clearance.start(base),"actual highest clearance purchase")
	Ra3Clearance.tick(base,float(Ra3Clearance.TIERS[3].seconds))
	check(factory.can_queue("R3MIRAGE"), "factory in highest clearance radius unlocks production")
	check(is_equal_approx(BattleClock.production_real_seconds(GameData.ra2_build_time(GameData.get_unit("R3MIRAGE")),GameData.get_unit("R3MIRAGE")),15.0), "15 seconds production at normal speed")
	battle.funds = 10000.0
	factory.build_speed = 1.0
	check(factory.enqueue("R3MIRAGE"), "actual factory enqueue")
	for frame in 149: factory._process(0.1)
	check(not factory.production.is_empty() and not battle.units.any(func(u): return u.unit_id == "R3MIRAGE"), "native factory still building at14.9 seconds")
	for frame in 2: factory._process(0.1)
	check(is_equal_approx(battle.funds,8400.0), "native production charges exactly1600")
	check(battle.units.any(func(u): return u.unit_id == "R3MIRAGE"), "actual factory spawns new unit")
	var tank = actor("R3MIRAGE","ally",Vector2(1800,1800))
	var friend = actor("MTNK","ally",Vector2(1900,1800))
	var plane = actor("JUMPJET","ally",Vector2(1900,1850))
	var enemy = actor("MTNK","enemy",Vector2(2020,1800))
	enemy.max_hp = 5000; enemy.hp = 5000
	var nearby = actor("MTNK","enemy",Vector2(2100,1850))
	var aircraft = actor("JUMPJET","enemy",Vector2(2000,1900))
	var q := UnitSkillLayout.index(tank,0)
	check(q >= 0 and tank.skills[q].id == Ra3Mirage.SKILL, "innate Q field installed")
	check(tank._ra2.get("facings") == 32 and tank._ra2_tur.is_empty(), "32 facings contain whole vehicle with no detached turret")
	check(tank._weapon_art.get("muzzles",[]).size() == 32, "all facings have model muzzle")
	check(ResourceLoader.exists(GameData.ra2_cameo_path("R3MIRAGE")), "production and selection portrait available")
	check(Ra3Mirage.disguised(tank), "idle tank disguises")
	tank.order_move(tank.position + Vector2(200,0))
	check(not Ra3Mirage.disguised(tank), "movement reveals disguise")
	tank.order_stop(); tank.special.reveal = 0
	check(not tank._weapon_domain_valid(aircraft), "prism cannot attack airborne targets")
	var hp_before: float = enemy.hp
	var neighbor_hp: float = nearby.hp
	var friend_hp: float = friend.hp
	var aircraft_hp: float = aircraft.hp
	tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(is_equal_approx(hp_before-enemy.hp,125.0), "normal prism applies adapted 125 once")
	check(is_equal_approx(neighbor_hp-nearby.hp,15.625), "secondary prism applies adapted 15.625 once")
	check(friend.hp == friend_hp and aircraft.hp == aircraft_hp, "scatter excludes friendly and air")
	check(not Ra3Mirage.disguised(tank), "shot reveals tank")
	check(tank.use_ability(q) and Ra3Mirage.field_active(tank), "real Q switches to field mode")
	check(not tank.use_ability(q) and not tank.ability_info(q).ready and not tank.ability_ready(q), "2-second switch cooldown enforced and displayed")
	check(not tank._weapon_domain_valid(enemy), "field mode blocks weapon target")
	hp_before = enemy.hp
	tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(enemy.hp == hp_before, "field mode cannot emit damage")
	friend.special.reveal = 0
	check(Ra3Mirage.field_conceals(friend,"enemy") and not battle.actor_visible_to("enemy",friend), "covered ally hidden from enemy targeting and visibility")
	check(battle.actor_visible_to("ally",friend), "covered ally remains selectable by owner")
	check(not Ra3Mirage.field_conceals(tank,"enemy") and not Ra3Mirage.field_conceals(plane,"enemy"), "caster and flying units excluded")
	friend.special.reveal = 2.0
	check(not Ra3Mirage.field_conceals(friend,"enemy"), "firing or damage exposes covered ally")
	friend.special.reveal = 0
	friend.position = tank.position + Vector2(400,0)
	check(not Ra3Mirage.field_conceals(friend,"enemy"), "leaving field removes concealment immediately")
	friend.position = tank.position + Vector2(100,0)
	var dog = actor("DOG","enemy",friend.position+Vector2(30,0))
	check(not Ra3Mirage.field_conceals(friend,"enemy"), "detector reveals field beneficiary")
	remove_actor(dog)
	var second = actor("R3MIRAGE","ally",tank.position+Vector2(60,40))
	Ra3Mirage.toggle(second)
	check(not Ra3Mirage.field_conceals(second,"enemy"), "broadcasting tanks cannot conceal each other")
	tank.hp = 0
	check(Ra3Mirage.field_conceals(friend,"enemy"), "overlapping live field retains coverage")
	second.hp = 0
	check(not Ra3Mirage.field_conceals(friend,"enemy"), "destroyed casters leave no stale concealment")
	tank.hp = tank.max_hp; second.hp = second.max_hp
	Ra3Mirage.tick(tank,2.1)
	check(tank.use_ability(q) and not Ra3Mirage.field_active(tank), "field deactivates after cooldown")
	tank._grant_veteran(3,false); tank.bonuses = {}
	hp_before = enemy.hp
	tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(is_equal_approx(hp_before-enemy.hp,156.25) and tank._active_weapon().range == 281.25, "elite weapon changes damage and range")
	Ra3Mirage.tick(tank,2.1); tank.use_ability(q)
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	battle.select_unit(tank,false)
	battle._emit_selection()
	get_window().focus_entered.emit()
	Ra3Mirage.tick(tank,2.1)
	await key(KEY_Q)
	check(not Ra3Mirage.field_active(tank), "actual Q key deactivates selected field")
	Ra3Mirage.tick(tank,2.1)
	await key(KEY_Q)
	check(Ra3Mirage.field_active(tank), "actual Q key reactivates selected field")
	var saved := BattleSaves.save_slot(battle,"quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok,"new unit and skill save via real save slot")
	if loaded.ok:
		for row in loaded.snapshot.records:
			if row.kind == "unit": row.groups.erase(Ra3Mirage.SOURCE_GROUP)
		BattleSaves.Snapshot.new().restore(battle,loaded.snapshot)
		var restored: Array = battle.units.filter(func(u): return u.unit_id == "R3MIRAGE" and u.veteran_level == 3)
		check(restored.size() == 1 and Ra3Mirage.field_active(restored[0]),"field mode restored after load")
		check(restored.size() == 1 and restored[0].is_in_group(Ra3Mirage.SOURCE_GROUP), "older save reconstructs the field lookup group")
		check(restored.size() == 1 and float(restored[0].special.get("ra3_field_cd",0)) > 0.0,"toggle cooldown restored after load")
	if DisplayServer.get_name() != "headless":
		battle.paused = false; get_tree().paused = false
		var show_tanks: Array = battle.units.filter(func(u): return u.unit_id == "R3MIRAGE")
		if not show_tanks.is_empty():
			var showcase = show_tanks.back()
			showcase.special.ra3_field = true
			showcase.special.reveal = 5.0
			battle.select_unit(showcase,false)
			battle.camera.position = showcase.position
			battle.camera.zoom = Iso.cam_zoom(2.0)
			screen.hud.select_prod_tab("vehicle")
			screen.hud._refresh_production()
			showcase.queue_redraw()
			await check_realtime_model(showcase)
		for frame in 5: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join("battle.png"))
	screen.free()
	Music.stop(); Ra2Sfx.stop_all()
	await get_tree().create_timer(0.05).timeout

func check_realtime_model(tank) -> void:
	# Compare geometry with simulation and tread UV movement held constant.
	tank.set_physics_process(false)
	tank.order_stop()
	tank.velocity = Vector2.ZERO
	var model: Ra3UnitModel = tank._ra3_model
	model.animation.enabled = false
	model.animation.sample("IDLA", 0.0)
	check(model != null, "graphical runtime uses original realtime 3D mesh")
	if model == null: return
	var peer: Ra3UnitModel
	for u in battle.units:
		if u != tank and u.unit_id == Ra3Mirage.ID: peer = u._ra3_model; break
	var bodies=model.hull.get_children().filter(func(n):return n is MeshInstance3D)
	var peers=peer.hull.get_children().filter(func(n):return n is MeshInstance3D) if peer!=null else []
	check(bodies.size()==peers.size() and bodies.size()>=2 and bodies[0].mesh==peers[0].mesh and bodies[1].mesh==peers[1].mesh, "models share immutable mesh resources")
	tank.visible = false
	model._process(0.0)
	check(model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden models suspend rendering")
	tank.visible = true
	model._process(0.0)
	check(model.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "unchanged pose resumes rendering after visibility returns")
	check(not bool(tank.data.move.turret), "original fixed hardpoint has no independent turret")
	check(model.muzzle_local.distance_to(Vector3(1.23912601172924,19.3952465057373,0.0)) < 0.0001, "FX_Weapon emitter is above prism, not front headlights")
	var last_image: PackedByteArray
	for heading in [0.0, 0.03, 1.47, 3.1, 5.9]:
		tank.hull_angle = heading
		tank.turret_angle = heading + 0.61
		model.sync_pose(true)
		tank.queue_redraw()
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture := model.viewport.get_texture().get_image()
		check(not picture.is_invisible(), "3D texture has visible model at heading %.2f" % heading)
		var raw := picture.get_data()
		if not last_image.is_empty(): check(raw != last_image, "continuous rotation changes actual rendered pixels at %.2f" % heading)
		last_image = raw
		# Layer 2 contains additional shadow-mask copies. Only layer 1 is the
		# actual vehicle, and every body/tread mesh must retain the same rig.
		var visible_parts: Array = model.hull.get_children().filter(func(n): return n is MeshInstance3D and n.layers == 1)
		check(is_equal_approx(model.hull.rotation.y, Iso.eff_angle() - heading) and visible_parts.size() == 2 and visible_parts.all(func(n): return n.transform.is_equal_approx(Transform3D.IDENTITY) and n.skin == model.animation.skin and n.get_node(n.skeleton) == model.animation.skeleton), "body and all tracks share one heading despite different aim %.2f" % heading)
		var tip := model.hull.transform * Vector3(1.23912601172924, 19.3952465057373, 0.0) # independently resolved SKL FX_Weapon ancestor translations
		var expected := model.camera.unproject_position(tip) / Vector2(model.RESOLUTION) * model.SIZE + model.draw_rect.position
		check(Iso.dir(tank._weapon_muzzle() - tank.global_position).distance_to(expected) < 0.02, "beam muzzle agrees with actual 3D camera projection %.2f" % heading)
		check(tank.hit_test(tank.art_center()), "rendered tank body is selectable %.2f" % heading)
		var empty: Vector2 = tank.global_position + RA2Art.art_dir(model.draw_rect.position + Vector2(1,1))
		check(not tank.hit_test(empty), "transparent model canvas does not intercept selection %.2f" % heading)
	# Aiming behind the vehicle must not detach any visible panel or track.
	model.set_process(false)
	model.viewport.get_texture().get_image().save_png(output_dir.path_join("aim-before.png"))
	var before_aim := model.viewport.get_texture().get_image().get_data()
	var muzzle_before := model.muzzle()
	tank.turret_angle += PI
	model.sync_pose(true)
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	model.viewport.get_texture().get_image().save_png(output_dir.path_join("aim-after.png"))
	var after_aim := model.viewport.get_texture().get_image().get_data()
	var different_channels := 0
	var largest_delta := 0
	for index in before_aim.size():
		var difference := absi(int(before_aim[index])-int(after_aim[index]))
		if difference>0: different_channels+=1
		largest_delta=maxi(largest_delta,difference)
	# OpenGL/MSAA repeat render differed by one red byte (1/255) in one pixel.
	# Permit only four such quantization bytes, not geometry/texture movement.
	check(different_channels<=4 and largest_delta<=1, "aim-only change leaves vehicle pixels unchanged within GPU quantization", {"channels":different_channels,"max_delta":largest_delta})
	check(model.muzzle().distance_to(muzzle_before) < 0.001, "aim-only change leaves fixed emitter on chassis")
	tank.hull_angle = 0.0; tank.turret_angle = 0.0
	model.sync_pose(true); tank.queue_redraw()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	model.viewport.get_texture().get_image().save_png(output_dir.path_join("model-3d.png"))
