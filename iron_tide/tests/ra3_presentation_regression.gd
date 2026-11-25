extends "res://tests/allied_abilities_regression.gd"

func capture(label: String) -> void:
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(label+".png"))

func v3(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func check_native_cpu() -> void:
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ra3_laser_cpu.json"))
	for i in oracle.cases.size():
		var c: Dictionary=oracle.cases[i]
		var start:=v3(c.start); var end:=v3(c.end)
		var width:=Ra3WeaponFx.native_half_width(end-start,v3(c.camera)-(start+end)*0.5,c.width)
		check(width.distance_to(v3(c.half_width))<0.0001,"billboard width matches Uprising instructions case %d"%i)
		check(absf(Ra3WeaponFx.native_opacity(c.now,c.created,c.expires,c.fade_in,c.fade_out)-float(c.opacity))<0.00001,"linear opacity matches Uprising instructions case %d"%i)
	var old_k:=Iso.K; var old_angle:=Iso.ANGLE
	for k in [0.4,0.5,0.625]:
		Iso.K=k
		for angle in [0.0,PI/4.0]:
			Iso.ANGLE=angle
			var point:=Vector2(1120,980); var ground:=Vector2(1100,1000)
			var endpoint:=Ra3WeaponFx.endpoint_3d(point,ground)
			var screen:=Vector2(endpoint.x,endpoint.y*k-endpoint.z*sqrt(1.0-k*k))
			check(screen.distance_to(Iso.dir(point))<0.001,"orthographic adapter preserves muzzle pixels at %.3f/%.3f"%[k,angle])
	Iso.K=old_k; Iso.ANGLE=old_angle

func native_texel(image: Image, uv: Vector2) -> Color:
	var x:=clampf(uv.x*image.get_width()-0.5,0.0,image.get_width()-1.0)
	var y:=uv.y*image.get_height()-0.5
	var x0:=floori(x); var y0:=floori(y)
	var a:=image.get_pixel(x0,posmod(y0,image.get_height())).lerp(image.get_pixel(mini(x0+1,image.get_width()-1),posmod(y0,image.get_height())),x-x0)
	var b:=image.get_pixel(x0,posmod(y0+1,image.get_height())).lerp(image.get_pixel(mini(x0+1,image.get_width()-1),posmod(y0+1,image.get_height())),x-x0)
	return a.lerp(b,y-y0)

func check_beam_pixels(fx) -> void:
	# Isolate the actual production shader/texture; camera, HUD, fire and model
	# animation must not be allowed to masquerade as beam motion or fading.
	var viewport := SubViewport.new()
	viewport.size=Vector2i(64,256); viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var strip := TextureRect.new()
	strip.texture=Ra3WeaponFx.BEAM; strip.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	strip.position=Vector2(20,0); strip.size=Vector2(fx.beam_width(),256)
	strip.material=fx.beam_material
	strip.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	strip.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	viewport.add_child(strip)
	var frames: Array[Image]=[]
	var samples: Array[Vector2]=[Vector2(0.0,1.0),Vector2(0.2,1.0),Vector2(0.2,0.5),Vector2(0.2,0.003),Vector2(0.75,1.0),Vector2(1.25,1.0),Vector2(1.49,1.0),Vector2(3.0,1.0)]
	for sample in samples:
		fx.beam_material.set_shader_parameter("age",sample.x)
		fx.beam_material.set_shader_parameter("opacity",sample.y)
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var picture:=viewport.get_texture().get_image()
		picture.save_png(output_dir.path_join("isolated-prism-%d.png"%frames.size()))
		frames.append(picture)
	var changed:=0; var energies: Array[float]=[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
	var widest_core:=0
	for y in 256:
		var bright_width:=0
		for x in 64:
			var first:=frames[0].get_pixel(x,y)
			if maxf(first.r,maxf(first.g,first.b))>0.2: bright_width+=1
			if first!=frames[1].get_pixel(x,y): changed+=1
			for i in frames.size():
				var c:=frames[i].get_pixel(x,y)
				energies[i]+=c.r+c.g+c.b
		widest_core=maxi(widest_core,bright_width)
	check(changed>100,"opposing texture scroll changes isolated beam pixels",changed)
	check(energies[0]>1.0 and widest_core<fx.beam_width()*0.65,"native texture product confines lit core within world-projected billboard",widest_core)
	check(energies[1]>energies[2] and energies[2]>energies[3] and energies[3]<energies[1]*0.05,"vertex opacity smoothly removes real rendered beam energy",energies)
	check(energies[4]<energies[1] and energies[5]<energies[4] and energies[6]<energies[1]*0.05,"native opposing U scroll fades beam with CPU opacity fixed at one",energies)
	check(energies[7]<0.01,"clamped U cannot wrap and resurrect an expired bright stripe",energies[7])
	var texture_one: Image=Ra3WeaponFx.BEAM.get_image()
	var texture_two: Image=fx.beam_material.get_shader_parameter("secondary").get_image()
	var max_error:=0.0
	for i in frames.size():
		for x in range(21,57,3):
			for y in range(8,250,19):
				var uv:=Vector2((x+0.5-20)/fx.beam_width(),(y+0.5)/256.0)
				var scroll:=Vector2(0.2,0.3)*samples[i].x
				var product:=native_texel(texture_one,uv+scroll)*native_texel(texture_two,uv-scroll)
				var actual:=frames[i].get_pixel(x,y)
				for channel in 3:
					# Compatibility's RGBA8 target clamps source RGB before blending.
					max_error=maxf(max_error,absf(actual[channel]-clampf(product[channel]*4.0,0.0,1.0)*product.a*samples[i].y))
	check(max_error<0.035,"rendered RGB agrees with original RGBA product and Clamp-U/Wrap-V sampling",max_error)
	viewport.free()

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	check_native_cpu()
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects=[]; battle.path_service.set_water([]); battle._refresh_pathing()
	var tank = actor("R3MIRAGE","ally",Vector2(1800,1800))
	tank.special.reveal=10
	var enemy = actor("MTNK","enemy",Vector2(1990,1800))
	enemy.max_hp=10000; enemy.hp=10000
	var second = actor("MTNK","enemy",Vector2(2050,1860))
	var native_fx = tank.get_node("Ra3MirageFx")
	native_fx.set_process(false)
	screen.hud.process_mode=Node.PROCESS_MODE_ALWAYS; screen.hud.set_process(false)
	battle.select_unit(tank,false); battle._emit_selection(); get_window().focus_entered.emit()
	for id in ["R3MIRAGE","R3FUTURE","R3HARBINGER","MTNK"]:
		var data: Dictionary=GameData.get_unit(id)
		var selected_icon:=UnitIcon.new();selected_icon.setup(data,Color.WHITE)
		check(selected_icon.cameo_texture.resource_path==GameData.ra2_cameo_path(id),id+": selection uses native Button/cameo")
		selected_icon.free()
		var card: Button=screen.hud._make_cameo(data,float(data.cost),0)
		var production_icon=card.get_child(0).get_child(0)
		var expected: String=GameData.ra2_art[id].get("portrait",GameData.ra2_cameo_path(id))
		check(production_icon.cameo_texture.resource_path==expected,id+": real production card uses Portrait, RA2 retains cameo")
		card.free()
		var tile: Control=screen.hud._make_queue_tile(null,id,1,0)
		check(tile.get_child(0).cameo_texture.resource_path==expected,id+": production queue uses same Portrait")
		tile.free()
	screen.hud._prod_sig=""
	screen.hud._refresh_production()
	var button: Button = screen.hud._ability_btns[0]
	check(button.has_meta("skill_texture"),"Q button has original image instead of generic glyph")
	check(button.get_meta("skill_texture").texture.resource_path.ends_with("field_on.png"),"inactive Q shows SDK activation icon")
	await key(KEY_Q)
	screen.hud._update_ability_live()
	check(button.get_meta("skill_texture").texture.resource_path.ends_with("field_off.png"),"active Q changes to SDK strike mode icon")
	check("无冷却" not in button.tooltip_text and "2.0s" in button.tooltip_text,"toggle tooltip reports real 2-second cooldown")
	check(button.get_meta("cd").text=="2s" and button.disabled,"native icon retains cooldown overlay and disabled input")
	native_fx._process(0.5)
	check(native_fx.strength>0.0 and native_fx.strength<0.5 and native_fx.field.visible and native_fx.field.scale==Vector3.ONE,"Q plays original visibility curve without scaling geometry")
	native_fx._process(3.0)
	check(native_fx.strength==1.0,"native field reaches full visibility")
	check(native_fx.field.mesh.surface_get_array_index_len(0)==726,"field uses original 242-triangle geometry")
	check(native_fx.field_material.get_shader_parameter("cloud").resource_path.ends_with("FXCloud03.png"),"field samples native cloud texture")
	check(native_fx.field_material.get_shader_parameter("distortion").resource_path.ends_with("FXFracTileNRM.png"),"field samples native distortion texture")
	if battle.fog == null:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog); battle.fog.setup(battle)
	if battle.fog != null:
		battle.fog.rebuild()
		var scout = actor("R3MIRAGE","enemy",Vector2(40,40))
		scout.special.reveal=10
		VehicleTracks.sample(scout,0.1); scout.position+=Vector2(20,0); VehicleTracks.sample(scout,0.1)
		check(not battle.position_visible_to("ally",scout.position) and battle.get_node_or_null("VehicleTracks")==null,"unseen enemy creates no observable ground tracks")
		remove_actor(scout)
		battle.fog.free(); battle.fog=null
	# Actual movement path, then sample boundaries; velocity alone never leaves marks.
	tank.order_move(tank.position+Vector2(140,0))
	for frame in 90:
		tank._physics_process(1.0/60.0)
		await get_tree().physics_frame
	var tracks = battle.get_node_or_null("VehicleTracks")
	check(tracks != null and tracks.marks.size()>8,"real moving tank deposits paired tread marks")
	tank.order_stop()
	VehicleTracks.sample(tank,0.1)
	var count: int = tracks.marks.size()
	VehicleTracks.sample(tank,0.1)
	check(tracks.marks.size()==count,"stationary tank creates no marks")
	var before: Vector2 = tank.position
	tank.position+=Vector2(800,0); VehicleTracks.sample(tank,0.1)
	check(tracks.marks.size()==count,"teleport creates no long track bridge")
	tank.position=before; VehicleTracks.sample(tank,0.1)
	tank.visible=false; tank.position+=Vector2(20,0); VehicleTracks.sample(tank,0.1)
	check(tracks.marks.size()==count,"hidden actor emits no tracks")
	tank.visible=true; tank.hull_angle=PI*0.5; tank.position+=Vector2(0,20); VehicleTracks.sample(tank,0.1)
	check(tracks.marks.size()>count and is_equal_approx(float(tracks.marks.back().angle),PI*0.5),"turning changes ground mark orientation")
	var hover = actor("ROBO","ally",tank.position)
	count=tracks.marks.size(); VehicleTracks.sample(hover,0.1); hover.position+=Vector2(20,0); VehicleTracks.sample(hover,0.1)
	check(tracks.marks.size()==count,"hover tank does not leave tracked-vehicle marks")
	remove_actor(hover)
	battle.camera.position=tank.position+Vector2(80,0); battle.camera.zoom=Iso.cam_zoom(1.4)
	native_fx._process(0.5); tank.special.reveal=10; tank.queue_redraw()
	await capture("field-tracks-icons")
	var with_tracks := stage.get_texture().get_image().get_data()
	tracks.visible=false
	await capture("tracks-hidden-comparison")
	var without_tracks := stage.get_texture().get_image().get_data()
	var changed := 0
	for pixel in range(0,with_tracks.size(),4):
		if with_tracks[pixel]!=without_tracks[pixel] or with_tracks[pixel+1]!=without_tracks[pixel+1] or with_tracks[pixel+2]!=without_tracks[pixel+2]: changed+=1
	check(changed>20,"ground tracks change actual battlefield pixels",changed)
	tracks.visible=true

	var field_image: Image = native_fx.viewport.get_texture().get_image()
	check(not field_image.is_invisible(),"native field renders nonempty pixels")
	field_image.save_png(output_dir.path_join("field-mesh.png"))
	Ra3Mirage.tick(tank,2.1); await key(KEY_Q); native_fx._process(0.25)
	check(native_fx.strength==1.0,"reverse playback preserves native final-frame hold")
	native_fx._process(2.0)
	check(native_fx.strength>0.0 and native_fx.strength<1.0,"reverse native visibility channel fades field")
	native_fx._process(1.2); check(native_fx.strength==0 and not native_fx.visible,"shutdown clears field overlay")
	tank.attack_target=null; tank.attack_ordered=false
	var hp: float = enemy.hp; tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(is_equal_approx(hp-enemy.hp,125.0),"RA3 FX emits normal hit damage exactly once")
	var effects: Array = Effects._host().get_children().filter(func(node):return node is Ra3WeaponFx)
	check(effects.size()>=2,"primary and scatter both use native RA3 prism FX")
	for fx in effects:
		fx.set_process(false); fx._process(0.08)
		check(fx.beam_material.shader.resource_path.ends_with("ra3_prism.gdshader"),"RA3 two-layer scrolling prism shader attached")
	await capture("prism-normal")
	for fx in effects:fx.free()
	tank._grant_veteran(3,false); tank.bonuses={}; hp=enemy.hp; tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(is_equal_approx(hp-enemy.hp,156.25),"elite FX keeps upgraded damage exactly once")
	effects=Effects._host().get_children().filter(func(node):return node is Ra3WeaponFx)
	for fx in effects:
		fx.set_process(false); fx._process(0.08)
		check(fx.beam_material.get_shader_parameter("secondary").resource_path.ends_with("FXAlliedPrismBeam.png" if fx.scatter else "FXAlliedPrismBeam_Vet.png"),"elite primary uses Veteran layer; scatter inherits original node texture")
	await capture("prism-elite")
	for fx in effects:fx._process(2.0)
	await get_tree().process_frame
	check(not Effects._host().get_children().any(func(node):return node is Ra3WeaponFx),"weapon effects expire and clean up")
	for i in VehicleTracks.LIMIT+10:tracks.add_mark(tank.position,0,true)
	check(tracks.marks.size()==VehicleTracks.LIMIT,"ground marks have bounded storage")
	tracks._process(VehicleTracks.LIFETIME+0.1); check(tracks.marks.is_empty(),"old ground marks fade and expire")
	await check_fade_transitions(tank,enemy)
	var snapshot := BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	check(battle.get_node_or_null("VehicleTracks")==null,"loading clears nonpersistent ground marks")
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().create_timer(0.05).timeout

func check_fade_transitions(tank, enemy) -> void:
	tank._grant_veteran(0,false)
	var model: Ra3UnitModel = tank._ra3_model
	model.set_process(false)
	tank.order_stop(); tank.velocity=Vector2.ZERO
	tank.special.ra3_field=false; tank.special.reveal=10.0
	model.advance_disguise(1.0)
	var start := model.body_opacity()
	tank.special.reveal=0.0
	model.advance_disguise(0.2)
	check(model.disguise_blend>0.0 and model.disguise_blend<1.0 and model.body_opacity()<start,"idle disguise fades model instead of instant swap")
	await capture("idle-fade-enter")
	model.advance_disguise(0.5)
	check(is_equal_approx(model.body_opacity(),0.5) and model.disguise_weight()==1.0,"owner idle opacity reaches SDK target 0.5")
	await capture("idle-fade-settled")
	var hidden_before: bool = Ra3Mirage.disguised(tank)
	var health: float = enemy.hp
	tank._fire_shot(enemy)
	resolve_ra3_hits()
	check(hidden_before and not Ra3Mirage.disguised(tank) and enemy.hp<health,"shot reveals and deals damage before visual crossfade completes")
	model.advance_disguise(0.2)
	check(model.disguise_weight()>0.0 and model.disguise_weight()<1.0 and model.body_opacity()>0.5,"leaving disguise blends back instead of instant swap")
	await capture("idle-fade-leave")
	model.advance_disguise(0.5)
	check(model.body_opacity()==1.0 and model.disguise_weight()==0.0,"revealed tank returns fully opaque without repeated body flicker")
	for fx in Effects._host().get_children():
		if fx is Ra3WeaponFx: fx.free()
	var fx := Ra3WeaponFx.spawn(tank,enemy,tank._weapon_muzzle())
	fx.set_process(false)
	check(fx.beam_lifetime()==1.5 and float(Ra3WeaponFx.sdk.beam_fade_out)==0.0,"primary follows SDK 1.5s lifetime and zero extra FadeOutTime")
	check(float(Ra3WeaponFx.sdk.primary_width)==25.0 and float(Ra3WeaponFx.sdk.scatter_width)==5.0,"SDK primary/scatter widths 25/5")
	await check_beam_pixels(fx)
	for age in [0.06,0.30,0.75,1.49,1.5]:
		fx._process(age-fx.age)
		check(fx.beam_opacity()==(1.0 if age<1.5 else 0.0),"native zero-envelope opacity and draw expiration at %.2f" % age)
		if age<1.5: await capture("sdk-primary-%.2f" % age)
	fx.free()
	fx=Ra3WeaponFx.spawn(tank,enemy,tank._weapon_muzzle())
	fx.set_process(false)
	var old_from := fx.from
	tank.position+=Vector2(12,0); enemy.position+=Vector2(0,15)
	fx._process(0.1)
	check(fx.from.distance_to(tank._weapon_muzzle())<0.01 and fx.from!=old_from and fx.to.distance_to(enemy.art_center())<0.01,"long-lived beam follows source muzzle and moving target")
	fx.free()
	fx=Ra3WeaponFx.spawn(tank,enemy,tank._weapon_muzzle(),true,tank)
	fx.set_process(false); fx._process(0.49)
	check(fx.beam_opacity()==1.0 and fx.beam_lifetime()==0.5,"native scatter has no invented tail and lasts 0.5s")
	fx._process(0.01); check(fx.beam_opacity()==0.0,"native scatter stops at SDK lifetime")
	fx.free()
	var mid := Ra3WeaponFx.particle_color("AlliedPrismHitFlash",0.5)
	var late := Ra3WeaponFx.particle_color("AlliedPrismHitFlash",0.82)
	check(mid.r>late.r and late.r>0.0 and late.r<0.02,"SDK hit flash RGB fades gradually to black")
	check(Ra3WeaponFx.particle_color("AlliedPrismHitFlash",25.0/30.0)==Color.BLACK,"hit flash ends at 25 source frames")
	check(Ra3WeaponFx.particle_color("AlliedPrismHitFIre",0.1)==Color.BLACK and Ra3WeaponFx.particle_color("AlliedPrismHitFIre",0.4)!=Color.BLACK,"fire obeys SDK five-frame initial delay")
	var visual = tank.get_node("Ra3MirageFx")
	visual.disguise_lifetime=1.0; visual.disguise_age=0.5
	check(visual.disguise_opacity()==1.0,"idle disguise FX alpha 1 at native midpoint")
	visual.disguise_age=0.75; check(is_equal_approx(visual.disguise_opacity(),0.5),"idle disguise FX linearly fades after midpoint")
	visual.disguise_age=1.0; check(visual.disguise_opacity()==0.0,"idle disguise FX reaches zero before removal")
	model.set_process(true)
