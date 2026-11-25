extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	if mode == MatchRules.RA2:
		check(not GameData.unit_in_production_catalog(Ra3Mirage.ID), "native assets do not unlock RA3 in RA2 mode")
		screen.free()
		await get_tree().process_frame
		return
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var tank = actor(Ra3Mirage.ID, "ally", Vector2(1800,1800))
	var ra2 = actor("MTNK", "ally", Vector2(1900,1800))
	var foe = actor("MTNK", "enemy", Vector2(2000,1800))
	for kind in ["select","move","attack","created","move_attack","move_special","select_mirage","select_battle","select_under_fire","retreat"]:
		var id := Ra2Sfx.voice_id(tank.data, kind)
		var files := GameData.ra2_sound_files(id)
		check(id.begins_with("RA3_") and not files.is_empty(), kind + " resolves native SDK audio event")
		for file in files:
			var stream = load(GameData.ra2_sfx_path(file))
			check(stream is AudioStreamWAV and stream.get_length() > 0.1, "PCM decodes: " + file.get_file())
	check(GameData.ra2_sfx_path("example.wav") == "res://assets/ra2/sfx/example.wav", "RA2 path resolution unchanged")
	check(not Ra2Sfx.voice_id(ra2.data,"select").begins_with("RA3_"), "RA2 voices remain independent")
	check(GameData.ra2_sound_files(Ra2Sfx.voice_id(tank.data,"created")).size() == 1, "SDK commented creation clips excluded")
	check(Ra2Sfx.play_voice(tank.data,"select",tank.position,0), "native selection reaches real audio player")
	tank.order_move(Vector2(2200,1800), true)
	check(tank.command_voice_kind("move") == "move_attack", "attack move chooses native acknowledgement")
	tank.order_stop(); tank.special.ra3_field = true
	check(tank.command_voice_kind("move") == "move_special" and tank.command_voice_kind("select") == "select_mirage", "field voice overrides")
	tank.special.ra3_field = false; tank.attack_target = foe
	check(tank.command_voice_kind("select") == "select_battle", "battle selection voice")
	tank.receive_hit(1.0,"bullet",{},foe)
	check(tank.command_voice_kind("select") == "select_under_fire", "under fire selection voice")
	Ra3Mirage.tick(tank,3.1); tank.attack_target = null
	check(tank.command_voice_kind("select") == "select", "under fire voice expires")
	check(GameData.ra2_sound_files("RA3_MirageFire").size() == 3, "three original prism fire samples")
	check(Ra2Sfx.play("RA3_MirageFire",tank.position), "native weapon sample plays")
	if DisplayServer.get_name() != "headless":
		await render_native(tank,ra2)
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().create_timer(0.05).timeout

func render_native(tank, ra2) -> void:
	battle.paused = false; get_tree().paused = false
	battle.camera.position = tank.position; battle.camera.zoom = Iso.cam_zoom(2.0)
	tank.special.reveal = 30.0
	var model: Ra3UnitModel = tank._ra3_model
	model.animation.enabled = false
	var anim := model.animation
	check(anim.skeleton.get_bone_count() == 22 and anim.skin.get_bind_count() == 22, "22 real skeleton bones and inverse bind matrices")
	for mesh in model.hull.get_children():
		if mesh is MeshInstance3D:
			check(mesh.get_node(mesh.skeleton) == anim.skeleton and mesh.skin == anim.skin, "mesh references skin and skeleton")
	anim.sample("IDLA",0)
	check(anim.muzzle().distance_to(model.muzzle_local) < 0.001, "bind emitter matches previously verified SDK muzzle")
	var idle_start := anim.skeleton.get_bone_global_pose(3)
	anim.sample("IDLA",0.7)
	check(not anim.skeleton.get_bone_global_pose(3).is_equal_approx(idle_start), "native idle changes bone transforms")
	anim.sample("MOVA",0)
	var move_start := anim.muzzle()
	anim.sample("MOVA",0.7)
	check(anim.muzzle().distance_to(move_start) > 0.001, "native movement animates emitter")
	var pose := anim.skeleton.get_bone_global_pose(3)
	anim.sample("MOVA",0.7 + 121.0/30.0)
	check(anim.skeleton.get_bone_global_pose(3).is_equal_approx(pose), "121 frame movement loops at native 30fps")
	anim.enabled = true; anim.advance(0.1,true)
	check(anim.clip == "MOVA", "movement selects MOVA")
	anim.advance(0.1,false)
	check(anim.clip == "IDLA", "stop selects IDLA")
	anim.enabled = false
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	model.viewport.get_texture().get_image().save_png(output_dir.path_join("native-model.png"))
	check(Ra3Wreck.spawn(ra2) == null, "RA2 death does not create RA3 wreck")
	tank.velocity = Vector2(20,0)
	tank._die()
	var wrecks := get_tree().get_nodes_in_group("ra3_wrecks")
	check(wrecks.size() == 1, "real death creates one native wreck")
	tank._die()
	check(get_tree().get_nodes_in_group("ra3_wrecks").size() == 1, "repeat death cannot duplicate debris")
	var wreck: Ra3Wreck = wrecks[0]
	check(wreck.parts.size() == 11 and Ra3Wreck.meshes.size() == 15, "11 COL bodies retain all 15 surfaces")
	check(not wreck.is_in_group("combatants") and not wreck.is_in_group("obstacles"), "wreck cannot block paths or take damage")
	wreck.set_process(false); wreck.age = 0.6; wreck._process(0)
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	wreck.viewport.get_texture().get_image().save_png(output_dir.path_join("native-wreck.png"))
	wreck.age=5; check(is_equal_approx(wreck.opacity(),1), "SDK fade begins after five seconds")
	wreck.age=7; check(is_equal_approx(wreck.opacity(),0.5), "SDK four second fade midpoint")
	wreck.age=9; wreck._process(0)
	check(wreck.is_queued_for_deletion(), "wreck expires at end of draw lifetime")
	await get_tree().process_frame
	var erased=actor(Ra3Mirage.ID,"ally",Vector2(1800,1800))
	erased._die(null,true)
	check(get_tree().get_nodes_in_group("ra3_wrecks").filter(func(n): return not n.is_queued_for_deletion()).is_empty(), "temporal erasure leaves no physical debris")
	var restored=actor(Ra3Mirage.ID,"ally",Vector2(1800,1800))
	var saved := BattleSaves.save_slot(battle,"quick")
	var loaded := BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok,"native unit uses existing save schema")
	for i in Ra3Wreck.MAX_WRECKS + 2: Ra3Wreck.spawn(restored)
	var active := get_tree().get_nodes_in_group("ra3_wrecks").filter(func(n): return not n.is_queued_for_deletion())
	check(active.size() == Ra3Wreck.MAX_WRECKS,"same-frame deaths respect cosmetic wreck cap")
	if loaded.ok: BattleSaves.Snapshot.new().restore(battle,loaded.snapshot)
	check(get_tree().get_nodes_in_group("ra3_wrecks").is_empty(), "save restore cleanup removes cosmetic debris")
