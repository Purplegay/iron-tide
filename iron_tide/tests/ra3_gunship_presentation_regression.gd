extends "res://tests/allied_abilities_regression.gd"

const Impact=preload("res://scripts/units/ra3_gunship_impact.gd")

func capture(viewport: SubViewport, label: String) -> Image:
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	for i in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	image.save_png(output_dir.path_join(label+".png"))
	return image

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var plane=actor("R3HARBINGER","ally",Vector2(1600,1600))
	plane.logistics.air_lift=1.0;plane.hull_angle=0;plane.turret_angle=0
	var target=actor("MTNK","enemy",Vector2(1900,1600))
	if DisplayServer.get_name()=="headless":screen.free();return
	var model=plane._ra3_model;model.set_process(false);model._sample();model.sync_pose()
	check(model.parts.size()==8,"all eight original SKN subobjects imported, including emitter meshes")
	check(model.clip_name=="" and model.parts.SKINGUNS.visible and model.parts.CYLINDER01.visible and not model.parts.SKINMACHINEGUN.visible,"XML cannon state hides machine gun and does not call unreferenced DEPLOY")
	check(not model.parts.FXMUZZLE_FR.visible and not model.parts.FXMUZZLE_BR.visible,"no permanent muzzle flash while idle")
	check(is_equal_approx(float(model.gunship_yaw[14]),PI/2.0),"collider turret rests at source natural side angle 270 degrees")
	var cannon: Image=await capture(model.viewport,"cannon-idle")
	check(Ra3Expansion.use(plane,Vector2.INF),"Q switches through actual ability entry")
	model._sample()
	check(not model.parts.SKINGUNS.visible and not model.parts.CYLINDER01.visible and model.parts.SKINMACHINEGUN.visible,"XML machine gun state hides both collider gun subobjects")
	var machine: Image=await capture(model.viewport,"machine-idle")
	check(cannon.get_data()!=machine.get_data(),"weapon modes produce different rendered geometry")
	Ra3Expansion.use(plane,Vector2.INF);plane.attack_target=target
	Ra3Expansion.shoot(plane,target);model._sample()
	preload("res://scripts/units/ra3_gunship_aim.gd").tick(plane,0.25)
	model._sample(0.25)
	check(is_equal_approx(float(model.gunship_yaw[14]),PI/4.0) and float(model.gunship_pitch[15])>0.0,"official collider uses explicit combat deflection and native pitch")
	check(model.fire_lights[0].visible and model.fire_lights[1].visible,"native FireFX lights are attached to both cannon launch bones")
	check(model.parts.FXMUZZLE_FR.visible and model.parts.FXMUZZLE_BR.visible and not model.parts.FXMUZZLEFRONT.visible,"two collider muzzles flash only on real fire")
	await capture(model.viewport,"cannon-fire")
	var shell=battle.projectiles_root.get_child(0)
	Ra3Expansion.tick_shot(shell,0.05)
	check(shell.has_node("NativeFx"),"cannon attaches original projectile mesh")
	var fx=shell.get_node("NativeFx");fx.set_process(false)
	check(int(fx.fx_material.get_shader_parameter("kind"))==1,"projectile consumes proton collider mask shader")
	await capture(fx.viewport,"cannon-projectile")
	var hp: float=target.hp
	shell.target_point=target.position;Ra3Expansion.tick_shot(shell,2.0);shell.free()
	var effects=get_tree().get_nodes_in_group("ra3_gunship_impacts")
	check(effects.size()==1 and is_instance_valid(effects[0]),"impact outlives the destroyed projectile")
	check(target.hp<hp,"presentation integration preserves real damage path")
	var effect=effects[0];effect.set_process(false)
	check(effect.particles.size()==43,"FXList consumes six fragment meshes, flash, six cores, distortion and five shockwaves",effect.particles.size())
	var names: Array=[]
	for p in effect.particles:if not names.has(p.data.attrs.id):names.append(p.data.attrs.id)
	check(names.size()==10,"all ten ordinary impact particle systems attached",names)
	var previous: Image
	for time in [0.1,0.5,1.1]:
		effect.age=time;effect._sample()
		var image: Image=await capture(effect.viewport,"impact-"+str(time))
		battle.camera.position=target.position;battle.camera.zoom=Iso.cam_zoom(1.0)
		battle.camera.reset_smoothing();battle.camera.force_update_scroll()
		await capture(stage,"impact-battle-"+str(time))
		check(image.get_used_rect().get_area()>0,"native impact visible at "+str(time))
		var used:=image.get_used_rect()
		check(used.position.x>0 and used.position.y>0 and used.end.x<image.get_width() and used.end.y<image.get_height(),"expanding impact fits viewport without edge clipping")
		if previous!=null:check(previous.get_data()!=image.get_data(),"impact expands and erodes rather than static texture")
		previous=image
	var erosion=effect.particles[0].material.get_shader_parameter("opacity")
	check(float(erosion)<1.0,"native particle opacity drives scrolling erosion mask",erosion)
	check(is_equal_approx(effect.distortion.rotation,Iso.eff_angle()) and is_equal_approx(effect.distortion.scale.y/effect.distortion.scale.x,Iso.inv_k()),"refraction sprite compensates the isometric battlefield instead of double-projecting")
	effect._process(5)
	check(effect.is_queued_for_deletion(),"expired impact queues its complete subtree for cleanup")
	for i in 2:await get_tree().process_frame
	check(not is_instance_valid(effect),"expired impact releases viewport and particles")
	var heroic=Impact.spawn(battle,target.position,true)
	check(heroic.effect_id.ends_with("Vet"),"heroic impact selects original veteran FXList")
	heroic.age=0.3;heroic._sample();await capture(heroic.viewport,"heroic-impact")
	check(str(heroic.particles[0].data.attrs.Drawable).to_lower().ends_with("v"),"heroic impact uses veteran geometry/materials")
	Ra3Expansion.tick(plane,0.11);model._sample()
	check(not model.parts.FXMUZZLE_FR.visible,"collider muzzle flash clears before reload finishes")
	Ra3Expansion.use(plane,Vector2.INF);Ra3Expansion.shoot(plane,target);model._sample()
	check(model.parts.FXMUZZLEFRONT.visible and not model.parts.FXMUZZLE_FR.visible,"rapid toggle/fire cannot leave old weapon muzzle visible")
	await capture(model.viewport,"machine-fire")
	check(get_tree().get_nodes_in_group("ra3_gunship_tracers").size()==1,"autocannon spawns original moving tracer independently of instant damage")
	var tracer=get_tree().get_nodes_in_group("ra3_gunship_tracers")[0]
	check(tracer.texture.resource_path.ends_with("FXTracer.png") and tracer.streaks.size() in [1,2,3],"tracer texture and accumulated native per-frame density consumed")
	Ra3Expansion.use(plane,Vector2.INF);model._sample()
	check(not model.parts.FXMUZZLE_FR.visible and not model.parts.FXMUZZLEFRONT.visible,"switching weapons alone never triggers a phantom muzzle flash")
	plane.velocity=Vector2(144,0)
	for i in 20:
		plane.position+=Vector2(4.8,0);model._update_contrails(1.0/30.0)
	check(model.contrails.size()<=17 and model.contrails.size()>=15,"two native wing contrails retain fifteen RA3 frames")
	check(model.contrails[-1].right.distance_to(model.contrails[-1].left)>1.0,"contrails attach to distinct FXCon_R and FXCon_L bones")
	plane.velocity=Vector2.ZERO;model._update_contrails(0.6)
	check(model.contrails.is_empty(),"contrails expire instead of leaving permanent lines")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	check(get_tree().get_nodes_in_group("ra3_gunship_impacts").is_empty(),"save restore removes cosmetic effects from previous timeline")
	check(get_tree().get_nodes_in_group("ra3_gunship_tracers").is_empty(),"save restore clears old tracer nodes")
	screen.free();await get_tree().process_frame
