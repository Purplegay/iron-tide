extends "res://tests/allied_abilities_regression.gd"

func weapon_effects() -> Array:
	return Effects._host().get_children().filter(func(node): return node is Ra3WeaponFx)

func clear_weapon_effects() -> void:
	for fx in weapon_effects(): fx.free()

func capture_beam(label: String, fx) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
	# Isolate the actual emitted beam draw node: battlefield textures, deaths,
	# model subviewports and HUD can change pixels even when the beam is absent.
	var viewport := SubViewport.new()
	viewport.size=stage.size; viewport.transparent_bg=true
	viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform=stage.get_canvas_transform()
	fx.beam.reparent(viewport,false); fx.beam.queue_redraw()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var with_beam := viewport.get_texture().get_image()
	with_beam.save_png(output_dir.path_join(label+"-isolated-beam.png"))
	fx.beam.visible=false
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var a := with_beam.get_data()
	var b := viewport.get_texture().get_image().get_data()
	var changed := 0
	for i in range(0,a.size(),4):
		if a[i]!=b[i] or a[i+1]!=b[i+1] or a[i+2]!=b[i+2]: changed+=1
	check(changed>20,label+": actual lethal beam draws pixels independently of other effects",changed)
	fx.beam.reparent(fx,false); fx.beam.visible=true
	viewport.free()

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units+battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects=[]; battle.path_service.set_water([]); battle._refresh_pathing()
	if battle.fog != null: battle.fog.free(); battle.fog=null
	var tank = actor("R3MIRAGE","ally",Vector2(1800,1800))
	tank.special.reveal=10.0
	battle.camera.position=Vector2(1900,1800)
	battle.camera.zoom=Iso.cam_zoom(1.4); battle.camera.force_update_scroll()
	for kind in ["unit","building"]:
		var target = actor("MTNK","enemy",Vector2(2000,1800)) if kind=="unit" else battle._place_building("GAPOWR","enemy",Vector2(2000,1800),true)
		target.hp=1.0
		var end: Vector2 = target.art_center()
		tank._fire_shot(target)
		resolve_ra3_hits()
		var effects := weapon_effects()
		check(not AlliedAbilities.alive(target),kind+": real shot kills target")
		check(effects.size()==1,kind+": exactly one primary FX spawned")
		var fx = effects[0]
		fx.set_process(false); fx._process(0.016)
		check(fx.beam_opacity()==1.0,kind+": lethal shot visible on first frame")
		await get_tree().process_frame
		fx._process(0.064)
		check(fx.to.is_equal_approx(end) and fx.beam_opacity()==1.0,kind+": freed victim keeps impact endpoint and beam")
		await capture_beam("lethal-"+kind,fx)
		fx._process(1.42)
		check(fx.beam_opacity()==0.0,kind+": primary still ends at 1.5 seconds")
		fx._process(1.0); await get_tree().process_frame
		check(weapon_effects().is_empty(),kind+": FX lifetime cleanup")
		if is_instance_valid(target): target.free()
	# The building case can eject real escapees. They belong to that case;
	# keep the next two-target scatter fixture independent of crew RNG.
	for extra in battle.units.duplicate():
		if is_instance_valid(extra) and extra != tank: remove_actor(extra)
	# Killing the primary target must not cancel any outgoing scatter segments.
	var center = actor("MTNK","enemy",Vector2(2000,1800))
	var victim = actor("MTNK","enemy",Vector2(2080,1840))
	center.hp=1.0; victim.hp=1.0
	var impact: Vector2=center.art_center()
	var impact_ground: Vector2=center.position
	var scatter_end: Vector2=victim.art_center()
	tank._fire_shot(center)
	resolve_ra3_hits()
	var effects := weapon_effects()
	check(not AlliedAbilities.alive(center) and not AlliedAbilities.alive(victim),"primary and scatter actually kill both victims")
	check(effects.size()==2,"one primary and one scatter FX; no duplicated damage shot")
	for fx in effects: fx.set_process(false)
	await get_tree().process_frame
	tank.position+=Vector2(20,0)
	for fx in effects:
		fx._process(0.08)
		check(fx.beam_opacity()==1.0,"dead scatter endpoint does not suppress emitted segment")
		if fx.scatter:
			check(fx.from.is_equal_approx(impact) and fx.to.is_equal_approx(scatter_end),"scatter retains both destroyed endpoints")
			check(fx.origin_ground.is_equal_approx(impact_ground),"scatter fog origin uses impact ground position")
			await capture_beam("lethal-scatter",fx)
			fx._process(0.42)
			check(fx.beam_opacity()==0.0,"lethal scatter still ends at 0.5 seconds")
		else:
			check(fx.from.distance_to(tank._weapon_muzzle())<0.01 and fx.to.is_equal_approx(impact),"live shooter follows muzzle with frozen dead target endpoint")
	clear_weapon_effects()
	# Source removal also leaves an already emitted visual; live target still tracks.
	var survivor=actor("MTNK","enemy",Vector2(2050,1850))
	var fx=Ra3WeaponFx.spawn(tank,survivor,tank._weapon_muzzle())
	fx.set_process(false)
	var muzzle: Vector2=fx.from
	remove_actor(tank); survivor.position+=Vector2(0,20)
	fx._process(0.1)
	check(fx.beam_opacity()==1.0 and fx.from.is_equal_approx(muzzle),"freed source preserves emitted beam origin")
	check(fx.to.distance_to(survivor.art_center())<0.01,"remaining live endpoint still tracks independently")
	clear_weapon_effects()
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame
