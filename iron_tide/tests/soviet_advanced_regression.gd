extends "res://tests/soviet_defense_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var old := OS.get_environment("IRON_TIDE_PRE_ADVANCED_SAVE")
	if not old.is_empty():
		var previous := BattleSaves.read_path(old)
		check(previous.ok, "previous Soviet match opens under new content hash", previous.get("message", ""))
	start_soviet("苏俄", "allied", "prebuilt")
	await run_advanced()
	await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks, "failed":failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func aim(unit, target) -> bool:
	unit.order_stop()
	battle.clear_selection()
	battle.select_unit(unit, false)
	battle.force_attack(target)
	unit.hull_angle = unit.position.direction_to(target.position).angle()
	unit.turret_angle = unit.hull_angle
	unit._refresh_weapon_derived()
	return unit._try_fire_ready()

func check_apoc_burst(tank, target, expected: int) -> void:
	tank.order_stop()
	tank.attack_target = target
	tank.attack_ordered = true
	tank.turret_angle = tank.position.direction_to(target.position).angle()
	tank.aim_dir = Vector2.from_angle(tank.turret_angle)
	tank.hull_angle = tank.turret_angle + PI / 2.0
	tank._cd_timer = 0.0
	var rounds: Array[Vector2] = []
	for i in expected:
		var count_before: int = battle.projectiles_root.get_child_count()
		if i == 0: tank._try_fire_ready()
		else: tank._update_burst(0.2)
		if battle.projectiles_root.get_child_count() == count_before: break
		var shell = battle.projectiles_root.get_child(-1)
		rounds.append(shell.global_position)
		check(shell.global_position.is_equal_approx(tank._weapon_muzzle(i % 2)), "ground round starts at the firing barrel")
		var flash = battle.effects_root.get_child(-1)
		check(flash is Ra2Fx and flash.global_position.is_equal_approx(shell.global_position), "muzzle flash and shell share a barrel tip")
		shell.free()
	check(rounds.size() == expected and rounds[0].distance_to(rounds[1]) > 3.0, "distinct gun barrels fire actual burst " + str(expected))
	tank.order_stop()

func run_advanced() -> void:
	var factory = actor("NAWEAP", "ally")
	if factory == null: factory = ready_building("NAWEAP", Vector2(1000,1250))
	for id in ["DRON","APOC","V3","NATECH"]:
		check(RA2Art.has_art(id) and ResourceLoader.exists(GameData.ra2_cameo_path(id)), id + " original artwork and portrait")
	check(not factory.enqueue("APOC") and not factory.enqueue("V3"), "lab and radar required")
	check(not factory.buildable.has("V3ROCKET"), "missile excluded from war factory")
	ready_building("NARADR", Vector2(1200,1250))
	battle.request_structure("NATECH")
	battle._tick_structure_queue(180)
	var spot := placement("NATECH", "ally")
	check(spot.is_finite() and battle.struct_ready.has("NATECH"), "lab legal footprint and paid ready state")
	if not spot.is_finite(): return
	battle.request_structure("NATECH")
	battle._try_place_building(spot)
	var lab = actor("NATECH","ally")
	check(lab != null, "lab placed via construction yard")
	if lab == null: return
	lab._process(8)
	for id in ["APOC","DRON","V3"]:
		var funds: float = battle.funds
		check(factory.enqueue(id), "enqueue " + id)
		factory._process(180)
		check(actor(id,"ally") != null and is_equal_approx(funds - battle.funds, float(GameData.get_unit(id).cost)), "produce and pay " + id)
	var tank = actor("APOC","ally")
	var drone = actor("DRON","ally")
	var truck = actor("V3","ally")
	if tank == null or drone == null or truck == null: return
	var pos: Vector2 = factory.position + Vector2(30,190)
	tank.position = pos - Vector2(100,0)
	truck.position = pos - Vector2(480,0)
	var host = battle.spawn_unit("MTNK","enemy",pos)
	host.order_stop()
	drone.position = pos - Vector2(18,0)
	var plane = battle.spawn_unit("JUMPJET","enemy",pos)
	plane.logistics.air_lift = 40
	check(tank._weapon_for_target(host).burst == 2 and tank._weapon_for_target(plane).name == "MammothTusk", "ordinary ground and air loadouts")
	check_apoc_burst(tank, host, 2)
	tank.hp -= 10
	tank._physics_process(1)
	check(tank.hp == tank.max_hp - 9, "native self healing")
	tank._grant_veteran(2,false)
	check(tank._weapon_for_target(host).name == "120mmxE" and tank._weapon_for_target(plane).name == "MammothTusk", "elite ground and air loadouts")
	host.position = tank.position + Vector2(0, 115)
	check_apoc_burst(tank, host, 4)
	host.position = pos
	for id in ["APOC", "DRON", "V3"]:
		var voice := Ra2Sfx.voice_id(GameData.get_unit(id), "select")
		check(not GameData.ra2_sound_files(voice).is_empty(), id + " native selection speech resolves")
	if DisplayServer.get_name() != "headless":
		var old_pos: Vector2 = truck.position
		var old_drone: Vector2 = drone.position
		drone.position = pos + Vector2(15,90)
		truck.position = pos - Vector2(150, 55)
		battle.camera.position = pos - Vector2(60, 0)
		for zoom in [1.0,2.0]:
			battle.camera.zoom = Iso.cam_zoom(zoom)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			for unit in [tank,truck,drone]: unit.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("vehicles-%dx.png" % int(zoom)))
		truck.position = old_pos
		drone.position = old_drone
	check(not drone._weapon_domain_valid(plane) and not drone._weapon_domain_valid(lab), "drone rejects air and buildings")
	check(aim(drone,host) and drone.special.has("pounce"), "attack starts physical leap")
	drone._physics_process(0.12)
	check(drone.embarked_in == host and not drone.visible and host.special.get("parasite") == drone, "single attached drone")
	var before: float = host.hp
	var sparks_before: int = battle.effects_root.get_children().filter(func(fx): return fx is Effects.Sparks).size()
	host._physics_process(0.1)
	check(host.hp < before, "parasite damages live vehicle")
	check(is_equal_approx(host._rock_amp, 1.0) and is_zero_approx(host._rock_dir.dot(Vector2.from_angle(host.hull_angle))), "inside attack rolls hull sideways at full strength")
	check(battle.effects_root.get_children().filter(func(fx): return fx is Effects.Sparks).size() == sparks_before + 1, "parasite strike sparks once on the hull")
	var pulse := int(host.rock_events)
	var hull_position: Vector2 = host.position
	var hp_after: float = host.hp
	host.special.gm_stationary = true
	host._physics_process(0.4)
	check(host.rock_events == pulse and host.hp == hp_after and not host.rocking_pose().is_equal_approx(Transform2D.IDENTITY) and host.position == hull_position, "rock advances between bites on stationary target without displacement")
	host._physics_process(Ra2Damage.rocking_seconds())
	check(host.rocking_pose().is_equal_approx(Transform2D.IDENTITY), "host settles between bites")
	host.special.erase("gm_stationary")
	check(not aim(truck,plane), "V3 rejects airborne targets")
	check(aim(truck,host), "V3 launches on explicit ground order")
	var missile = actor("V3ROCKET","ally")
	check(missile != null and missile.is_air_target() and missile.hp == 50 and truck._ra2.tex == RA2Art.art("V3WO").tex, "interceptable native missile and empty rack")
	if missile == null: return
	battle.select_all_combat()
	check(not battle.selected_units.has(missile), "missile excluded from army selection")
	check(tank._weapon_for_target(missile).name == "MammothTusk", "defenders classify payload as an air target")
	missile._physics_process(2)
	check(missile.position.is_equal_approx(preload("res://scripts/units/dread_missile.gd").mount(truck,0)) and missile.special.flight.phase=="rack" and missile.special.flight.pitch>deg_to_rad(90.0*0.21), "V3 raises on native rear rail before moving downrange")
	var flight=preload("res://scripts/units/dread_missile.gd")
	for cells in [5.0,18.0]:
		var probe=battle.spawn_unit("V3ROCKET","ally",truck.position)
		var destination: Vector2 = truck.position + Vector2.RIGHT * cells * Ra2Damage.PX_PER_CELL
		probe.special.flight={"source":truck,"elapsed":0.0,"aim":destination,"altitude":165.0}
		flight.prepare(probe,truck,0)
		var reached: bool=flight.advance(probe,probe.special.flight,90.0)
		check(reached and probe.position.is_equal_approx(destination), "V3 reaches fixed aim at "+str(cells)+" cells")
		battle.units.erase(probe)
		probe.free()
	var saved := BattleSaves.save_slot(battle, "slot1")
	var disk := BattleSaves.read_slot("slot1")
	check(saved.ok and disk.ok, "in-flight missile and parasite saved")
	if not disk.ok: return
	BattleSaves.Snapshot.new().restore(battle,disk.snapshot)
	get_tree().paused = false
	battle.paused = false
	host = actor("MTNK","enemy")
	drone = actor("DRON","ally")
	truck = actor("V3","ally")
	lab = actor("NATECH","ally")
	missile = actor("V3ROCKET","ally")
	check(is_same(truck.special.get("raising_missile_0"),missile), "saved rack links to restored missile")
	check(is_equal_approx(missile.special.flight.elapsed, 2) and drone.embarked_in == host and host.special.parasite == drone, "both active relationships restored")
	if battle.fog == null:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog)
		battle.fog.setup(battle)
	var fog = battle.fog
	fog.rebuild()
	var remote: Vector2 = Vector2(400, 2800)
	var destination: Vector2 = Vector2(2200, 2200)
	check(not fog.is_visible_at("ally", remote) and not fog.is_visible_at("ally", destination), "test sites start outside allied sight")
	host.position = remote
	fog.rebuild()
	var near: Vector2 = remote + Vector2.RIGHT * fog.vision_radius(drone) * 0.8
	check(host.visible and fog.is_visible_at("ally", near) and not drone.visible, "restored parasite reveals its own radius around its host")
	battle.clear_selection()
	var center: Vector2 = host.art_center()
	var pixel: Vector2 = battle.get_viewport().get_canvas_transform() * center
	var select_voice := Ra2Sfx.voice_id(drone.data, "select")
	Ra2Sfx._voice_lock.erase(select_voice)
	var before_selection := Ra2Sfx.a_voice_plays
	battle._apply_selection(center,false,Rect2(pixel-Vector2(30,30),Vector2(60,60)))
	check(battle.inspected_drones==[drone] and battle.selected_units.is_empty(),"box over host inspects its allied drone only")
	check(Ra2Sfx.a_voice_plays == before_selection + 1 and Ra2Sfx._voice_lock.has(select_voice), "box selection plays attached drone select sound")
	Ra2Sfx._voice_lock.erase(select_voice)
	battle._emit_selection()
	check(Ra2Sfx.a_voice_plays == before_selection + 1, "HUD refresh does not repeat the attached drone sound")
	check(screen.hud.sel_strip_title.text.contains("寄生中") and screen.hud.sel_hp_bar!=null,"inspection shows drone portrait and health")
	var previous_move: Vector2 = drone.move_target
	var previous_order: bool = drone.has_move_order
	battle._issue_order(destination)
	check(drone.embarked_in==host and drone.move_target==previous_move and drone.has_move_order==previous_order,"inspected drone ignores ground orders")
	if DisplayServer.get_name() != "headless":
		battle.camera.position=host.position
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		center=host.art_center()
		battle._apply_selection(center,false,Rect2())
		check(battle.inspected_drones==[drone] and battle.selected_units.is_empty(),"real host pixels select only the attached drone")
		battle._apply_selection(center,true,Rect2())
		check(battle.inspected_drones.is_empty(),"shift clicking the host removes inspection")
		before_selection = Ra2Sfx.a_voice_plays
		battle._apply_selection(center,false,Rect2())
		check(Ra2Sfx.a_voice_plays == before_selection + 1 and Ra2Sfx._voice_lock.has(select_voice), "click selection plays attached drone select sound")
	host.position = destination
	fog.rebuild()
	check(host.visible and not fog.is_visible_at("ally", remote) and fog.is_explored_at("ally", remote), "sight follows host without leaving live vision")
	host.position = pos
	var depot = battle._place_building("GADEPT","enemy",pos + Vector2(220,140),true)
	depot._process(8)
	# The scene is manually driven; repair access still needs the real physics body.
	host.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	check(host.order_repair(depot), "infested vehicle accepts repair order")
	host.position = preload("res://scripts/buildings/repair_dock.gd").pad(depot)
	host.add_to_group("repair_docked")
	fog.rebuild()
	var death_fx_before := get_tree().get_nodes_in_group("yr_death_effects")
	var funds_before: float = battle.enemy_funds
	battle.enemy_funds = 0
	depot._process_repair(1.5)
	check(host.special.get("parasite") == drone and get_tree().get_nodes_in_group("yr_death_effects") == death_fx_before, "unpaid repair leaves the parasite and plays no destruction")
	battle.enemy_funds = funds_before
	var hull_center: Vector2 = host.art_center()
	var damaged_hp: float = host.hp
	var die_sound := Ra2Sfx.voice_id(drone.data, "die")
	Ra2Sfx._voice_lock.erase(die_sound)
	depot._process(1.5)
	var fx_added := get_tree().get_nodes_in_group("yr_death_effects").filter(func(f): return not death_fx_before.has(f))
	check(fx_added.size() == 1 and fx_added[0].visible and fx_added[0].global_position.is_equal_approx(hull_center) and fx_added[0].playback.size() > 1, "paid repair plays one visible SHP animation on the host hull")
	check(host.hp > damaged_hp and Ra2Sfx._voice_lock.has(die_sound), "host gains health while its parasite plays the native destruction sound")
	if fx_added.size() == 1:
		var effect = fx_added[0]
		effect._process(1.1 / effect.fps)
		check(effect.frame != 0, "drone destruction advances through original frames")
		depot._process_repair(1.5)
		check(get_tree().get_nodes_in_group("yr_death_effects").size() == death_fx_before.size() + 1, "next repair tick does not replay the destruction")
	battle._refresh_inspected_drones()
	check(battle.inspected_drones.is_empty() and battle.selected_units.is_empty(),"repair cleanup clears drone inspection")
	check(not host.special.has("parasite") and drone.is_queued_for_deletion(), "paid repair removes parasite")
	host.position = remote
	fog.rebuild()
	check(not fog.is_visible_at("ally", remote), "repair removes parasite vision")
	before = host.hp
	Ra2Sfx._eva_last.erase("EVA_UNITLOST")
	missile.receive_hit(1, "flak", {}, depot)
	check(not missile._dead and not Ra2Sfx._eva_last.has("EVA_UNITLOST"), "nonlethal flak on V3 rocket does not announce a loss")
	missile.receive_hit(10000, "flak", {}, depot)
	check(not Ra2Sfx._eva_last.has("EVA_UNITLOST"), "intercepting V3 rocket does not announce a loss")
	missile._physics_process(15)
	check(missile._dead and host.hp == before, "destroyed missile cannot detonate")
	host.position = pos
	check(is_equal_approx(truck._cd_timer,400.0/15.0),"intercepted V3 begins 400 tick regeneration immediately")
	truck.set_fire_stance("none")
	truck.order_stop()
	truck._physics_process(399.0/15.0)
	check(not aim(truck,host),"V3 cannot fire one tick early")
	truck.set_fire_stance("none")
	truck.order_stop()
	truck._physics_process(1.01/15.0)
	check(aim(truck,host) and is_equal_approx(truck._cd_timer,460.0/15.0), "V3 holds rack for 60 ticks before 400 tick refill")
	missile = actor("V3ROCKET","ally")
	if missile != null:
		before = host.hp
		var phases := {}
		for i in 1100:
			phases[missile.special.flight.phase] = true
			missile._physics_process(1.0/15)
			if missile.is_queued_for_deletion(): break
		check(phases.has("boost") and phases.has("curve"),"V3 accelerates then follows lazy terminal arc")
		check(host.hp < before and missile.is_queued_for_deletion(), "payload detonates at ordered coordinates")
		check(not Ra2Sfx._eva_last.has("EVA_UNITLOST"), "V3 impact does not announce a loss")
	truck.receive_hit(100000)
	check(truck._dead and Ra2Sfx._eva_last.has("EVA_UNITLOST"), "destroying the allied V3 launcher still announces a unit loss")
	battle.power_low = false
	lab._sw_charge = lab.sw_recharge()
	check(lab.fire_superweapon(lab.position) and battle.side_power_low("ally"), "force shield activates and cuts owner power")
	before = lab.hp
	lab.receive_hit(200)
	check(lab.hp == before, "building protected while shield lasts")
	lab._process(34)
	lab.receive_hit(100)
	check(lab.hp < before, "force shield expires")
	var victim = battle.spawn_unit("MTNK", "enemy", pos)
	var survivor = battle.spawn_unit("DRON", "ally", pos - Vector2(18, 0))
	check(aim(survivor, victim), "second drone attacks")
	survivor._physics_process(0.12)
	battle.select_unit(survivor,false)
	victim.hp = 1
	victim._physics_process(0.1)
	battle._refresh_inspected_drones()
	check(battle.inspected_drones.is_empty() and battle.selected_units==[survivor],"inspected drone becomes commandable upon release")
	battle._issue_order(pos + Vector2(110, 70))
	check(victim._dead and survivor.embarked_in == null and survivor.visible and battle.selected_units == [survivor] and survivor.has_move_order, "drilling through host restores selection and movement")
