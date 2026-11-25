extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2: return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog!=null: battle.fog.free(); battle.fog=null
	var tank=actor("R3MIRAGE","ally",Vector2(1800,1800))
	var foe=actor("MTNK","enemy",Vector2(2000,1800))
	tank.special.reveal=10.0; tank.order_stop()
	var audio := Ra3MirageAudio.ensure(tank)
	var field := tank.get_node("Ra3MirageFx") as Ra3MirageFx
	field.set_process(false)
	check(Ra3MirageFx.source.frames==101 and Ra3MirageFx.source.fps==30,"native field uses 101 frames at 30 FPS")
	field.advance_field(0.5,true)
	check(absf(field.strength-0.216)<0.001,"native field frame 15 follows original smooth visibility samples")
	field.advance_field(0.5,true)
	check(absf(field.strength-0.648)<0.001,"native field frame 30 matches original sample")
	field.advance_field(10.0,true)
	check(field.strength==1.0 and is_equal_approx(field.field_time,100.0/30.0),"ONCE clamps at last source frame")
	field.advance_field(1.0,false)
	check(field.strength==1.0,"ONCE_BACKWARDS includes original opaque hold")
	field.advance_field(1.5,false)
	check(absf(field.strength-0.5)<0.001,"reverse reaches source midpoint")
	field.advance_field(0.2,true)
	check(field.strength>0.5 and field.strength<1.0,"toggle reversal continues from current pose without popping")
	field.advance_field(20.0,false)
	check(field.strength==0.0 and field.field_time==0.0,"reverse finishes without residual field")
	check(field.field_material.shader.resource_path.ends_with("ra3_field_lightning.gdshader"),"runtime uses FXLightning material adapter")
	check(field.field.scale==Vector3.ONE,"native field geometry never expands via uniform scaling")
	check(field.field_material.get_shader_parameter("edge_fade")==3.0,"native edge fade parameter applied")
	check(field.field_material.get_shader_parameter("hdr_multiplier")==2.0,"native HDR multiplier applied")
	var field_arrays:=field.field.mesh.surface_get_arrays(0)
	var colors: PackedColorArray=field_arrays[Mesh.ARRAY_COLOR]
	var black:=0
	for color in colors:
		if color.r==0.0 and color.g==0.0 and color.b==0.0: black+=1
	check(colors.size()==160 and black==89,"native field vertex mask preserves89 black vertices")
	var disguise_arrays:=field.disguise.mesh.surface_get_arrays(0)
	check(disguise_arrays[Mesh.ARRAY_TEX_UV2].size()==160,"disguise second texture coordinates retained")
	check(field.disguise_material.shader.resource_path.ends_with("ra3_disguise.gdshader"),"disguise uses its own DefaultW3D material")
	field.field_time=0.0; field.strength=0.0
	tank.special.reveal=0.0; field.was_disguised=false; field._process(0.04)
	check(field.disguise.visible and field.disguise_size.y==1.0,"entering disguise emits source particle without vertical inflation")
	field._process(1.1)
	check(not field.visible,"idle disguise particle expires without a persistent shell")
	tank.special.reveal=10.0; field._process(0.1)
	check(not field.visible,"reveal does not restart disguise shell")
	tank.special.reveal=0.0; field._process(0.04)
	tank.order_move(tank.position+Vector2(200,0)); field._process(0.04)
	check(not field.visible,"moving interrupts entry particle instead of retaining a normal-mode shell")
	tank.order_stop(); tank.special.reveal=10.0
	check(audio.source.audio.ALL_Mirage_WeaponFire1.sounds.size()==10 and audio.source.audio.ALL_Mirage_WeaponFire2.sounds.size()==3,"both SDK weapon layers imported")
	check(audio.source.audio.ALL_Mirage_WeaponFire2.Delay==[200.0,250.0],"native delayed second layer retained")
	check(audio.source.audio.ALL_MirageField_StartAndEndLoop.PitchShift==[45.0,50.0],"native field loop pitch retained")
	Ra3Mirage.toggle(tank)
	check(audio.events_started.has("ALL_MirageField_StartPlayer"),"Q plays player start sample")
	audio.advance(0.1)
	check(is_instance_valid(audio.loop_player) and audio.loop_player.playing,"active Q starts actual native loop player")
	check(audio.loop_player.pitch_scale>=1.45 and audio.loop_player.pitch_scale<=1.5,"loop player consumes SDK pitch range")
	var first_loop=audio.loop_player
	audio.advance(1.0)
	check(audio.loop_player==first_loop,"continuous field does not restart ambience")
	tank.special.ra3_field_cd=0.0; Ra3Mirage.toggle(tank); audio.advance(0.1)
	check(audio.events_started.has("ALL_MirageField_StopPlayer") and audio.loop_gain>0 and audio.loop_gain<1,"Q off plays stop and fades owned loop")
	audio.advance(0.2)
	check(audio.loop_player==null,"loop removed after shutdown")
	await get_tree().process_frame
	audio.fire()
	check(audio.events_started.has("ALL_Mirage_WeaponFire1"),"weapon layer one starts immediately")
	await get_tree().create_timer(0.3).timeout
	check(audio.events_started.has("ALL_Mirage_WeaponFire2"),"weapon layer two reaches actual player after native delay")
	var delayed_before := audio.events_started.count("ALL_Mirage_WeaponFire2")
	audio.fire(); get_tree().paused=true
	await get_tree().create_timer(0.3,true).timeout
	check(audio.events_started.count("ALL_Mirage_WeaponFire2")==delayed_before,"pause freezes delayed weapon audio")
	get_tree().paused=false
	await get_tree().create_timer(0.3).timeout
	check(audio.events_started.count("ALL_Mirage_WeaponFire2")==delayed_before+1,"resume plays delayed second layer exactly once")
	for rank in [1,2,3]:
		check(Ra3Mirage.rank_texture(rank).resource_path.ends_with("rank%d.png" % rank),"native RA3 rank %d icon" % rank)
	check(Ra3Mirage.rank_texture(0)==null,"recruit has no rank badge")
	tank._grant_veteran(3,false); battle.select_unit(tank,false); battle._emit_selection()
	screen.hud._refresh_veterancy_live(tank)
	check(screen.hud.sel_rank_icon.texture.resource_path.ends_with("rank3.png"),"selection HUD uses native heroic star")
	var model: Ra3UnitModel=tank._ra3_model
	check(model.prop_mesh.mesh==Ra3MirageFx.mesh_for("disguise_tree"),"idle disguise uses original RA3 tree mesh")
	check(model.prop_mesh.material_override.get_shader_parameter("diffuse_map").resource_path.ends_with("AP_MirageDisguises01.png"),"idle disguise uses original RA3 tree texture")
	battle.camera.position=tank.position; battle.camera.zoom=Iso.cam_zoom(1.5)
	tank.special.ra3_field=true; field._process(4.0)
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	field.viewport.get_texture().get_image().save_png(output_dir.path_join("native-field.png"))
	check(not field.viewport.get_texture().get_image().is_invisible(),"new native field draws nonempty pixels")
	stage.get_texture().get_image().save_png(output_dir.path_join("native-field-battle.png"))
	tank.special.ra3_field=false; field._process(4.0); tank.special.reveal=0.0
	model.advance_disguise(1.0); model._process(0.2)
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	model.prop_viewport.get_texture().get_image().save_png(output_dir.path_join("native-tree.png"))
	check(not model.prop_viewport.get_texture().get_image().is_invisible(),"native disguise renders nonempty pixels")
	tank.embarked_in=foe; audio.advance(0.1)
	check(audio.loop_player==null and not audio.audible(),"embarkation suppresses native field audio")
	tank.embarked_in=null
	var weak_audio=weakref(audio); tank.free()
	check(weak_audio.get_ref()==null,"unit removal owns and clears all native audio nodes")
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame
