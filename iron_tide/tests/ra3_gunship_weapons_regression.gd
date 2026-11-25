extends "res://tests/allied_abilities_regression.gd"
const Impact=preload("res://scripts/units/ra3_gunship_impact.gd")
const Resolution=preload("res://scripts/units/ra3_fx_resolution.gd")
const Tracer=preload("res://scripts/units/ra3_gunship_tracer.gd")

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	if DisplayServer.get_name()=="headless":screen.free();return
	seed(48120)
	var plane=actor("R3HARBINGER","ally",Vector2(1500,1500))
	plane.logistics.air_lift=1.0;plane.hull_angle=0;plane.turret_angle=0
	var target=actor("MTNK","enemy",Vector2(1800,1500))
	var model=plane._ra3_model;model.set_process(false)
	plane.attack_target=target;plane.attack_ordered=true
	preload("res://scripts/units/ra3_gunship_aim.gd").tick(plane,1.0)
	model._sample(1.0)
	check(is_equal_approx(float(model.gunship_yaw[14]),PI/4.0),"official side cannon respects explicit 45 degree combat deflection")
	Ra3Expansion.use(plane,Vector2.INF)
	plane.special.ra3_aim_front_pitch=0.0
	preload("res://scripts/units/ra3_gunship_mounts.gd").tick(plane,0.1)
	model.gunship_pitch.clear();model._sample(0.1)
	var front:=-1
	for i in model.source.bones.size():
		if str(model.source.bones[i].name).to_upper()=="TURRET_PITCH_FRONT":front=i
	check(front>=0 and is_equal_approx(float(model.gunship_pitch[front]),deg_to_rad(20.0)*0.1),"official front pitches at 20 degrees per second")
	preload("res://scripts/units/ra3_gunship_aim.gd").tick(plane,1.0)
	model._sample(1.0)
	check(float(model.gunship_pitch[front])<=PI/6.0,"official front respects XML minimum pitch -30 degrees")
	for level in [0,3]:
		plane.veteran_level=level;plane.set_meta("ra3_tracer_credit",0.0)
		var count:=0
		for shot in 20:
			Tracer.spawn(plane,target.position)
			var tracer=get_tree().get_nodes_in_group("ra3_gunship_tracers")[-1]
			tracer.set_process(false);count+=tracer.streaks.size()
			check(float(plane.get_meta("ra3_tracer_credit"))>=0 and float(plane.get_meta("ra3_tracer_credit"))<1,"fractional emission retained "+str(level)+"/"+str(shot))
			if shot==0:
				check(is_equal_approx(tracer.width,12) and is_equal_approx(tracer.lifetime,35.0/30.0),"native width and lifetime "+str(level))
				check(tracer.head_color==(Color.RED if level==3 else Color.WHITE),"native rank head color "+str(level))
				check(tracer.texture.resource_path.ends_with("FXTracerHeroic.png" if level==3 else "FXTracer.png"),"native rank texture "+str(level))
				tracer._process(0.8)
				var hits:=get_tree().get_nodes_in_group("ra3_gunship_bullet_hits")
				check(hits.size()==(tracer.streaks.size() if level==3 else 0),"only heroic tracer owns TracerHitFx "+str(level))
				for hit in hits:
					hit.set_process(false)
					check(hit.rows.size()>=7,"heroic FX inherits spark/flash and 5..6 native ricochets")
					hit.free()
			tracer.free()
		check(count>=30 and count<=48,"20 shots preserve 0.5..0.8 per frame instead of rounded fixed count",count)
	# Real damage entry: ordinary hit exists even when the target dies on this shot.
	target.hp=0.01
	Ra3Expansion.shoot(plane,target)
	var payload=battle.projectiles_root.get_child(0)
	Ra3Expansion.tick_shot(payload,0.04)
	var hits:=get_tree().get_nodes_in_group("ra3_gunship_bullet_hits")
	check(hits.size()==1,"lethal machine gun shot still emits ordinary DamageFX")
	var hit=hits[0];hit.set_process(false)
	hit.age=0.05;hit._sample()
	check(not hit.rows[0].sprite.visible and hit.rows[1].sprite.visible,"spark InitialDelay 4 frames, immediate flash")
	hit.age=0.2;hit._sample()
	check(hit.rows[0].sprite.visible and not hit.rows[1].sprite.visible,"native flash expires at 4 frames, spark lives 8 after delay")
	check(is_equal_approx(float(hit.rows[0].sprite.material.get_shader_parameter("frame")),2.0),"64-cell bullet atlas advances native frame after initial delay")
	check(hit.rows[0].texture.get_width()>=256,"original bullet atlas retained at native resolution")
	check((hit.rows[0].sprite.scale*hit.rows[0].texture.get_size()).x<=15.01,"8-column atlas does not enlarge native 8..10 unit spark eight times")
	check(Resolution.side(500,2)==1024,"2x camera receives >=1000 render pixels instead of fixed384")
	check(Resolution.side(10000,4)==1536,"extreme zoom has bounded texture allocation")
	check(Resolution.side(INF,1,16)*Resolution.side(INF,1,16)*16<=Resolution.PIXEL_BUDGET,"16 simultaneous impacts obey shared pixel budget")
	# Remove the unrelated YR target-death animation before capturing the cannon FX.
	for fx in battle.effects_root.get_children():fx.free()
	battle.camera.position=hit.position;battle.camera.zoom=Iso.cam_zoom(4)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var veteran=load("res://scripts/units/ra3_gunship_bullet_hit.gd").spawn(battle,hit.position+Vector2(50,0),Vector2.RIGHT,true)
	veteran.set_process(false);veteran.age=0.16;veteran._sample()
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join("native-bullet-hits.png"))
	veteran.free()
	var effect=Impact.spawn(battle,Vector2(1800,1500),false);effect.set_process(false)
	var flash_peak := 0.0
	for row in effect.particles:
		if str(row.data.attrs.get("ParticleTexture","")).to_lower() == "fxlenzflarehdr01":
			var hdr: Image = row.material.get_shader_parameter("particle_map").get_image()
			for y in hdr.get_height():
				for x in hdr.get_width():
					var pixel := hdr.get_pixel(x,y)
					flash_peak = maxf(flash_peak, maxf(pixel.r,maxf(pixel.g,pixel.b)))
			break
	check(is_equal_approx(flash_peak, 2.736328125), "cannon flash uses unclipped retail HDR samples", flash_peak)
	effect.age=0.5
	battle.camera.position=effect.position;battle.camera.zoom=Iso.cam_zoom(1)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	effect._sample()
	var bounds: float=effect.draw_size
	var one: int=effect.viewport.size.x
	check(is_equal_approx(Resolution.pixel_density(effect),1),"Iso compensation gives one screen pixel per draw unit at zoom1",Resolution.pixel_density(effect))
	battle.camera.zoom=Iso.cam_zoom(2);battle.camera.force_update_scroll();effect._sample()
	check(is_equal_approx(Resolution.pixel_density(effect),2),"camera zoom included in native render density",Resolution.pixel_density(effect))
	check(effect.viewport.size.x>=one and effect.viewport.size.x>=mini(1536,ceili(bounds*2)),"actual impact allocation tracks screen footprint",effect.viewport.size)
	check(is_equal_approx(effect.draw_size,bounds),"clarity change does not enlarge world-space shockwave or damage")
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in 6:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join("impact-zoom2.png"))
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	check(get_tree().get_nodes_in_group("ra3_gunship_bullet_hits").is_empty(),"save restore clears new cosmetic bullet hits")
	check(get_tree().get_nodes_in_group("ra3_gunship_impacts").is_empty(),"save restore releases resized impact viewport")
	screen.free();await get_tree().process_frame
