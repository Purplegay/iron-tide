extends "res://tests/allied_abilities_regression.gd"
const Soviet=preload("res://scripts/units/ra3_soviet.gd")
const Model=preload("res://scripts/units/ra3_expansion_model.gd")
const Beam=preload("res://scripts/units/ra3_tank_beam.gd")
const FX=preload("res://scripts/units/ra3_tank_fx.gd")

func rig(unit):
	var model=Model.new()
	model.actor=unit;unit.add_child(model);model._build();model.set_process(false)
	unit._ra3_model=model
	return model

func make_beam(unit,enemy,tractor:bool):
	var beam=Beam.new()
	beam.battle=battle;beam.source=weakref(unit);beam.target=weakref(enemy)
	beam.harpoon=tractor;beam.muzzle_name="FX_HARPOON" if tractor else "FX_WEAPON_01"
	battle.effects_root.add_child(beam);beam.build();beam.set_process(false)
	return beam

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var tank=actor("R3APOC","ally",Vector2(1500,1500))
	var enemy=actor("MTNK","enemy",tank.position+Vector2(100,0))
	enemy.hp=10000;enemy.max_hp=10000
	tank.attack_target=enemy;tank.attack_ordered=true;tank.hull_angle=0.0;tank.turret_angle=0.0
	var model=rig(tank) if tank._ra3_model==null else tank._ra3_model
	var left:int=model.rig.find_bone("B_BARREL01")
	var right:int=model.rig.find_bone("B_BARREL02")
	check(left>=0 and right>=0 and model.bone_world("FX_MUZZLEFLASH01")!=model.bone_world("FX_MUZZLEFLASH02"),"two distinct barrels and muzzles")
	for i in 2:
		check(Soviet.fire(tank),"fires barrel "+str(i+1))
		var shot=battle.projectiles_root.get_children().back()
		check(shot.splinters.heroic_shell==false and shot.position.distance_to(model.bone_world("FX_MUZZLEFLASH%02d"%(i+1)))<0.1,"shot launches at recorded muzzle")
		Soviet.tick(tank,0.1);model._sample(0.1)
		var b=left if i==0 else right
		check(model.rig.get_bone_pose_position(b).x<model.rests[b].origin.x-1,"firing barrel actually retracts")
		if i==0:check(is_equal_approx(model.rig.get_bone_pose_position(right).x,model.rests[right].origin.x),"unfired barrel stays at rest")
		Soviet.advance(shot,1.0);Soviet.tick(tank,0.21)
	tank._grant_veteran(3,false);Soviet.tick(tank,2.1)
	check(Soviet.fire(tank),"heroic volley")
	var heroic=battle.projectiles_root.get_children().back()
	check(heroic.splinters.heroic_shell and heroic.splinters.radius>0,"heroic hit type latched on launch")
	check(FX.bank.cannon.impacts==["FX_TankImpactMed","FX_DreadnoughtV4Explosion_Vet"],"terrain and heroic death lists")
	enemy.hull_angle=0.0
	check(FX.impact_id(enemy,PI,false)=="FX_SovietTankHit" and FX.impact_id(enemy,0,false)=="FX_SovietTankHitCrit" and FX.impact_id(enemy,PI/2,false)=="FX_SovietTankHitCritS","front rear flank damage FX")
	check(Soviet.use(tank,tank.position),"open harpoon")
	Soviet.tick(tank,1);model._sample(1)
	check(model.clip_name=="DOOROPEN" and is_equal_approx(tank.special.door_phase,0.3),"door advances on native timeline")
	Soviet.use(tank,tank.position);Soviet.tick(tank,0.5);model._sample(0.5)
	check(model.clip_name=="DOOROPEN" and is_equal_approx(tank.special.door_phase,0.15),"reverses from current door frame")
	Soviet.use(tank,tank.position);tank.attack_target=enemy;tank.special.harpoon_target=enemy
	var tractor=make_beam(tank,enemy,true);tractor._process(0)
	check(tractor.layers.size()==3 and tractor.layers[0].line.width==12 and tractor.layers[2].line.width==18,"three XML tractor layers")
	tank.special.erase("harpoon_target");tractor._process(0)
	check(tractor.is_queued_for_deletion(),"released target removes beam")
	var tesla=actor("R3TESLA","ally",tank.position+Vector2(0,40))
	var coil=rig(tesla) if tesla._ra3_model==null else tesla._ra3_model
	var zap=make_beam(tesla,enemy,false)
	zap._process(0.1)
	check(zap.layers.size()==4 and zap.layers[0].waves.size()==2 and zap.layers[0].line.points.size()>33 and zap.layers[0].line.material==Beam.LIGHTNING_MATERIAL,"four textured target streaks sample native noise sets")
	check(FX.impact_id(enemy,0,true)=="FX_TeslaHit" and coil.bone_world("FX_WEAPON_01")!=coil.bone_world("FX_WEAPON_02"),"distinct coil hardpoints and target FX")
	for layer in zap.layers:
		zap.age=layer.start+layer.duration*0.1
		zap._process(0)
		var strip:Line2D=layer.line
		check(strip.texture.get_height()>strip.texture.get_width() and strip.points[0].is_zero_approx() and strip.points[-1].distance_to(Iso.dir(zap.end_point-zap.position))<0.01,"vertical retail texture reaches both coil and target endpoints")
	if DisplayServer.get_name()!="headless":
		await check_lightning_strip(zap.layers[0].line)
	var defense=battle._place_building("TESLA","ally",tesla.position+Vector2(50,0),true)
	defense._process(GameData.ra2_buildup_seconds()+0.05)
	var charge=preload("res://scripts/units/tesla_support.gd")
	check(charge.accepts(tesla,defense),"normal coil support order accepts the tank")
	charge.tick(tesla,defense,0.1);tesla._cd_timer=0.0;charge.tick(tesla,defense,0.1)
	check(tesla.special.tesla_link_barrel==1 and defense.special.tesla_chargers.count(tesla)==1,"support pulses alternate coils without duplicate charges")
	var link=make_beam(tesla,defense,false);link.coil_link=true;link._process(0.1)
	check(link.end_point.distance_to(charge.tip(defense))<0.01,"support arc tracks Tesla coil tip")
	Soviet.use(tesla,tesla.position);coil._sample(0.04)
	check(not coil.tank_pose.rings.is_empty() and coil.tank_pose.rings[0].node.mesh!=null,"EMP emits original lightning ring")
	tesla.set_selected(true)
	var recorder=preload("res://scripts/ui/unit_selection_outline.gd")
	recorder.begin(tesla);coil.capture_body_outline(1.0);recorder.end(tesla)
	var mask_camera:Camera3D=coil.body_mask.get_camera_3d()
	var mask:int=mask_camera.cull_mask
	check(coil.body_mask.world_3d==coil.viewport.find_world_3d() and coil.body_mask.size==coil.viewport.size and mask_camera.transform==coil.camera.transform,"selection camera shares pose, frame and world")
	check((coil.parts.TESLATANK.layers & mask)!=0 and (coil.parts.TREADSSTOP.layers & mask)!=0,"hull and treads appear in selection mask")
	check((coil.tank_pose.rings[0].node.layers & mask)==0 and (coil.parts.FX_LIGHTNINGCHARGE.layers & mask)==0 and (coil.tank_pose.rings[0].node.layers & coil.camera.cull_mask)!=0,"EMP ring and discharge are rendered only in the normal view")
	check(tesla.get_node("SelectionOutline").get_child(0).texture==coil.body_mask.get_texture(),"outline consumes the body-only texture")
	tesla.set_selected(false)
	check(coil.body_mask==null,"deselection releases additional viewport")
	var pos:Vector2=tesla.position
	var target=actor("HTNK","enemy",pos+Vector2(35,0))
	var gm=actor("R3APOC","enemy",pos+Vector2(0,45));gm.special.gm_stationary=true
	var friend=actor("HTNK","ally",pos+Vector2(35,15))
	var soldier=actor("E2","enemy",pos+Vector2(40,0))
	var far=actor("HTNK","enemy",pos+Vector2(130,0))
	Soviet.tick(tesla,0.02)
	check(target.has_buff("tesla_emp") and gm.has_buff("tesla_emp") and target._stun_timer>1,"both YR and RA3 affected vehicles get EMP feedback")
	check(target.buff_entries().any(func(b):return b.kind=="tesla_emp" and b.text=="电磁瘫痪"),"affected vehicle exposes the timed EMP status in HUD")
	check(not friend.has_buff("tesla_emp") and not far.has_buff("tesla_emp") and not soldier.has_buff("tesla_emp"),"no feedback on unaffected units")
	Soviet.tick(tesla,1.0)
	check(target.buffs.filter(func(b):return b.kind=="tesla_emp").size()==1,"repeated pulses refresh a single status")
	target._physics_process(1.11);gm._physics_process(1.11)
	check(not target.has_buff("tesla_emp") and not gm.has_buff("tesla_emp") and gm._stun_timer==0,"EMP status expires on both live vehicles and stationary GM targets")

	Soviet.use(tesla,tesla.position);coil._sample(1.0)
	check(coil.tank_pose.rings.is_empty(),"EMP rings expire when disabled")
	for tested in [model,coil]:
		tested.actor.hp=tested.actor.max_hp*0.1;tested._sample(0.03)
		check(not tested.tank_pose.skins.is_empty() and tested.tank_pose.skins[0].material.get_shader_parameter("diffuse_map")==tested.tank_pose.skins[0].damaged,"retail damaged skin "+tested.actor.unit_id)
		tested.actor.hp=tested.actor.max_hp;tested._sample(0.03)
		check(tested.tank_pose.skins[0].material.get_shader_parameter("diffuse_map")==tested.tank_pose.skins[0].normal,"repair restores skin "+tested.actor.unit_id)
	battle.camera.position=enemy.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	for id in FX.bank.effects:
		if id==FX.bank.tesla:continue
		var before:int=battle.effects_root.get_child_count()
		FX.emit_entries(battle,enemy.position,FX.Particle.child(FX.bank.effects[id],"NuggetList").children,0.0)
		var spawned=battle.effects_root.get_children().slice(before)
		check(spawned.any(func(f):return not f.is_queued_for_deletion()),"live effects from "+id)
		if id==FX.bank.cannon.fire or id==FX.bank.cannon.hero_fire:
			check(spawned.any(func(f):return "flashes" in f and f.flashes.size()==2 and f.texture!=null),"crossed textured muzzle quads "+id)
	var shader_names:=preload("res://shaders/ra3_tank_particle_distort.gdshader").get_shader_uniform_list().map(func(u):return u.name)
	check(shader_names.has("displacement") and shader_names.has("detail_map"),"material reflects original distortion inputs")
	exercise_emplacement_damage()
	var expected:float=tank.special.door_phase
	var ages:Array=tank.special.barrel_age.duplicate()
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var saved=codec.capture(battle);codec.restore(battle,saved)
	tank=battle.units.filter(func(u):return u.unit_id=="R3APOC")[0]
	check(is_equal_approx(tank.special.door_phase,expected) and tank.special.barrel_age==ages,"mid-transition door and independent recoil survive save")
	screen.free();await get_tree().process_frame

func exercise_emplacement_damage() -> void:
	const Tower=preload("res://scripts/buildings/ra3_reaper_emplacement.gd")
	var tower=battle._place_building("R3REAPERTURRET","ally",Vector2(2150,1500),true)
	tower.receive_hit(tower.max_hp*0.33,"cannon",{},null,"RA3_EXPANSION")
	var gun=Tower.mount(tower)
	Tower.tick(tower,0.0)
	var model=rig(gun) if gun._ra3_model==null else gun._ra3_model
	battle.camera.position=tower.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	model._sample(0.033)
	check(model.tank_pose.hull_damage==0,"67 percent is above native two-thirds threshold")
	tower.receive_hit(tower.max_hp*0.01,"cannon",{},null,"RA3_EXPANSION")
	Tower.tick(tower,0.0)
	var before:int=battle.effects_root.get_child_count()
	model._sample(0.033)
	var pose=model.tank_pose
	var socket:Vector2=model.bone_world("B_TURRET_04")
	check(pose.hull_damage==1 and pose.attachment_clocks.size()==1 and pose.attachment_clocks.has("B_Turret_04VehicleDamageSmoke"),"deployed 66 percent starts left turret smoke only")
	check(battle.effects_root.get_children().slice(before).any(func(e):return e.position.distance_to(socket)<0.05 and not e.is_queued_for_deletion()),"smoke spawns at actual animated turret bone")
	tower.receive_hit(tower.max_hp*0.33,"cannon",{},null,"RA3_EXPANSION")
	Tower.tick(tower,0.0);model._sample(0.033)
	check(pose.hull_damage==2 and pose.attachment_clocks.size()==3 and pose.attachment_clocks.has("B_Turret_04VehicleDamageFire") and pose.attachment_clocks.has("B_Turret_04VehicleDamageFire02"),"deployed 33 percent adds both native fires")
	check(not pose.skins.is_empty() and pose.skins.all(func(row):return row.material.get_shader_parameter("diffuse_map").resource_path.ends_with("/SUHeavyWalkerVehicle_D.png")),"deployed turret uses retail damaged skin")
	tower.hp=tower.max_hp
	Tower.tick(tower,0.0);model._sample(0.033)
	check(pose.hull_damage==0 and pose.attachment_clocks.is_empty() and pose.skins.all(func(row):return row.material.get_shader_parameter("diffuse_map")==row.normal),"restored tower stops emitting and returns to normal skin")

# Sample the actual combat material. A sideways strip only lights the middle
# of this span, even though its Line2D geometry reaches both ends.
func check_lightning_strip(source:Line2D) -> void:
	var view:=SubViewport.new()
	view.world_2d=World2D.new()
	view.size=Vector2i(320,48)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var strip:=source.duplicate() as Line2D
	strip.position=Vector2.ZERO;strip.visible=true;strip.default_color=Color.WHITE
	strip.width=24;strip.points=PackedVector2Array([Vector2(8,24),Vector2(312,24)])
	view.add_child(strip)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:=view.get_texture().get_image()
	var lit:=0
	for x in range(12,310,8):
		for y in range(12,36):
			var c:=img.get_pixel(x,y)
			if c.b>0.10:
				lit+=1;break
	check(lit>=34,"native longitudinal bolt texture lights at least 34 of 38 columns",lit)
	img.save_png(output_dir.path_join("lightning-strip.png"))
	view.free()
