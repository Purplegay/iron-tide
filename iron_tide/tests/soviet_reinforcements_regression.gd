extends "res://tests/soviet_opening_regression.gd"

func capture_arm(depot, phase: String) -> void:
	if DisplayServer.get_name() == "headless": return
	depot.queue_redraw()
	battle.camera.position = depot.position
	battle.camera.zoom = Iso.cam_zoom(1.6)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("soviet-repair-" + phase + ".png"))

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var previous := OS.get_environment("IRON_TIDE_V07_SAVE")
	if not previous.is_empty(): check(BattleSaves.read_path(previous).ok, "original v0.7 Soviet save")
	start_soviet("苏俄", "allied", "prebuilt")
	var barracks = actor("NAHAND", "ally")
	check(barracks.queue_block_reason("FLAKT").contains("苏联雷达") and not barracks.enqueue("FLAKT"), "radar prerequisite prevents early training")
	battle.request_structure("NARADR")
	battle._tick_structure_queue(120)
	var site := placement("NARADR", "ally")
	if battle.struct_ready.has("NARADR") and site != Vector2.INF:
		battle.request_structure("NARADR")
		battle._try_place_building(site)
	check(actor("NARADR","ally") != null, "radar constructed via Soviet yard")
	var factory = battle._place_building("NAWEAP", "ally", Vector2(1400, 1700), true)
	for pair in [[barracks,"FLAKT"],[barracks,"SENGINEER"],[factory,"HTK"]]:
		var id: String = pair[1]
		var producer = pair[0]
		var price: float = GameData.get_unit(id).cost
		var before: float = battle.funds
		check(producer.enqueue(id), "legally queue " + id)
		producer._process(120.0)
		var u = actor(id,"ally")
		check(u != null and is_equal_approx(before-battle.funds,price), "paid factory exit " + id)
		check(not GameData.ra2_sound_files(Ra2Sfx.voice_id(GameData.get_unit(id),"select")).is_empty() and ResourceLoader.exists(GameData.ra2_cameo_path(id)), "original cameo and selection voice " + id)
	var aircraft = battle.spawn_unit("JUMPJET","enemy",Vector2(1000,1500))
	aircraft.logistics.air_lift = 1.0
	var ground = battle.spawn_unit("MTNK","enemy",Vector2(1050,1500))
	for id in ["HTK","FLAKT"]:
		var u = actor(id,"ally")
		if u == null: continue
		u.order_stop()
		u.set_fire_stance("defend")
		u.position = Vector2(1000,1000)
		ground.position = u.position + Vector2(50,0)
		aircraft.position = u.position + Vector2(400,0)
		var ground_gun: Dictionary = u._weapon_for_target(ground)
		var air_gun: Dictionary = u._weapon_for_target(aircraft)
		check(not ground_gun.ra2_aa and air_gun.ra2_aa and air_gun.range == (550 if id=="HTK" else 440), "native distinct domains " + id)
		ground.position = u.position + Vector2(700,0)
		u._refresh_target()
		check(u.attack_target == aircraft and u._weapon_target_valid(aircraft), "acquires plane beyond ground range " + id)
		# Close shot always lies inside the one-cell warhead, for every random roll.
		aircraft.position = u.position + Vector2(90,0)
		ground.position = aircraft.position
		var below_hp: float = ground.hp
		u._refresh_weapon_derived()
		u.turret_angle = 0
		u.hull_angle = 0
		u._cd_timer = 0
		aircraft.hp = aircraft.max_hp
		var health: float = aircraft.hp
		check(u._try_fire_ready() and is_equal_approx(u._cd_timer,air_gun.cooldown), "launch AA shot at native ROF " + id)
		for shot in u._pick_projectile_parent().get_children():
			if shot is Projectile and shot.target == aircraft and not shot.is_queued_for_deletion():
				for frame in 160:
					if shot.is_queued_for_deletion(): break
					shot._physics_process(1.0/60.0)
		check(aircraft.hp < health and ground.hp == below_hp, "airburst damages aircraft and spares vehicle below " + id)
		ground.position = u.position + Vector2(150,0)
		u.attack_target = ground
		u._refresh_weapon_derived()
		u._cd_timer = 0
		var tank_health: float = ground.hp
		var fired: bool = u._try_fire_ready()
		for shell in u._pick_projectile_parent().get_children():
			if shell is Projectile and shell.target == ground:
				for i in 160:
					if shell.is_queued_for_deletion(): break
					shell._physics_process(1.0 / 60.0)
		check(fired and ground.hp < tank_health and is_equal_approx(u._cd_timer,ground_gun.cooldown), "switches back to ground gun and damages armor " + id)
		u.credit_kill(u._vet_need * 3.0, "enemy")
		check(u._weapon_for_target(ground).name.ends_with("E") and u._weapon_for_target(aircraft).name.ends_with("E"), "elite swaps both weapons " + id)
	var carrier = actor("HTK","ally")
	if carrier != null:
		carrier.position = Vector2(1200,1600)
		carrier.order_stop()
		for i in 5:
			var troop = battle.spawn_unit("E2","ally",carrier.position+Vector2(5,0))
			check(troop.logistics.request_board(carrier), "board seat " + str(i+1))
			troop.logistics.tick(0.1)
		var extra = battle.spawn_unit("E2","ally",carrier.position+Vector2(6,0))
		check(carrier.logistics.used_capacity()==5 and not extra.logistics.request_board(carrier), "sixth seat denied")
		check(BattleSaves.save_slot(battle,"slot1").ok and BattleSaves.read_slot("slot1").ok, "loaded Soviet transport can be saved and read")
		check(carrier.deploy(), "E / deploy initiates unloading")
		for i in 6: carrier.logistics.tick(0.4)
		check(carrier.logistics.used_capacity()==0, "all passengers disembark")
	var engineer = actor("SENGINEER","ally")
	if engineer != null:
		var target = actor("GAPOWR","enemy")
		check(UnitSkillLayout.primary_id(engineer.unit_id)=="allied_engineer" and engineer.weapon.is_empty(), "native Q and no attack gun")
		var arrival: Vector2 = AlliedAbilities.approach(engineer,target)
		engineer.position = arrival + target.position.direction_to(arrival)*120.0
		engineer.process_mode = Node.PROCESS_MODE_ALWAYS
		engineer.set_physics_process(false)
		check(AlliedAbilities.default_order(engineer,target)=="allied_engineer" and AlliedAbilities.use(engineer,"allied_engineer",target), "engineer receives capture order")
		for i in 600:
			await get_tree().physics_frame
			if not battle.actor_alive(engineer): break
			engineer._physics_process(1.0 / 60.0)
		check(target.side=="ally" and not battle.actor_alive(engineer), "capture consumes engineer")
	var sapper = battle.spawn_unit("SENGINEER","ally",barracks.position)
	barracks.hp -= 100
	check(AlliedAbilities.use(sapper,"allied_engineer",barracks), "repair order accepted on damaged friendly building")
	sapper.position = AlliedAbilities.approach(sapper,barracks)
	AlliedAbilities.tick_action(sapper,0.1)
	check(barracks.hp == barracks.max_hp and not battle.actor_alive(sapper), "engineer repairs friendly building and is consumed")
	var depot = battle._place_building("NADEPT","ally",Vector2(1900,1700),true)
	depot._process(10.0)
	var repair_target = battle.spawn_unit("HTNK","ally",RepairDock.pad(depot))
	repair_target.hp -= 100
	check(repair_target.order_repair(depot), "Soviet depot accepts vehicle")
	repair_target.position = RepairDock.pad(depot)
	depot._process(1.0)
	depot._process(0.02)
	check(depot._layer_visible("specialanim") and not depot._layer_visible("specialanimtwo"), "extends when vehicle reaches pad")
	depot._process(1.5)
	await capture_arm(depot,"extend")
	depot._process(1.9)
	check(depot._layer_visible("specialanimtwo") and not depot._layer_visible("specialanimthree"), "switches to work loop")
	await capture_arm(depot,"work")
	depot.hp = depot.max_hp * 0.25
	for layer in depot._ra2_anim:
		if str(layer.kind).begins_with("specialanim"):
			var expected: Array = {"specialanim":[50,71],"specialanimtwo":[72,78],"specialanimthree":[79,99]}[layer.kind]
			var pose: Dictionary = depot._anim_layer(layer)
			check(pose.loopStart==expected[0] and pose.loopEnd==expected[1] and pose.frames==100 and pose.shadow, "damaged pose and shadow " + layer.kind)
	repair_target.order_stop()
	depot._process(0.02)
	depot._process(0.02)
	check(depot._layer_visible("specialanimthree"), "retracts after departure")
	depot._process(1.6)
	await capture_arm(depot,"damaged-retract")
	depot._process(1.7)
	check(depot._layer_visible("idleanim") and not depot._layer_visible("specialanimthree"), "returns to idle")
	await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	report.close()
	get_tree().quit(0 if failed == 0 else 1)
