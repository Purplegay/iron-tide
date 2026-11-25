extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.water_rects=[];battle.path_service.set_water([])
	var base=battle._place_building("GACNST","ally",Vector2(1400,1400),true)
	var factory=battle._place_building("GAWEAP","ally",Vector2(1700,1400),true)
	var airfield=battle._place_building("GAAIRC","ally",Vector2(1400,1800),true)
	for b in [base,factory,airfield]:b._buildup_play=-1.0
	check("矿石" in Ra3Clearance.start_reason(base),"T2 requires a completed refinery")
	var refinery=battle._place_building("GAREFN","ally",Vector2(1200,1700),true);refinery._buildup_play=-1.0
	check(Ra3Clearance.start(base),"start object-level T2 upgrade")
	check(not Ra3Clearance.start(base),"duplicate upgrade rejected")
	battle.funds=0.0;Ra3Clearance.tick(base,15)
	check(Ra3Clearance.state(base).elapsed==0.0,"no free upgrade while broke")
	battle.funds=1500.0;Ra3Clearance.tick(base,15)
	check(Ra3Clearance.level(factory)==2 and is_zero_approx(battle.funds),"T2 pays exact cost and projects to factory")
	check(not factory.can_queue("R3MIRAGE"),"T2 cannot unlock Mirage")
	check(Ra3Clearance.start(base),"T3 starts after T2")
	var panel=preload("res://scripts/ui/ra3_clearance_panel.gd").new()
	screen.add_child(panel);panel.setup(base)
	var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
	panel.purchase.gui_input.emit(right)
	check(Ra3Clearance.state(base).paused,"clearance panel routes right click into pause")
	panel._process(0);panel.purchase.pressed.emit()
	check(not Ra3Clearance.state(base).paused,"clearance panel resumes through purchase button")
	panel.free()
	battle.funds=3000.0;Ra3Clearance.tick(base,20)
	Ra3Clearance.right_click(base);Ra3Clearance.tick(base,40)
	check(is_equal_approx(Ra3Clearance.state(base).elapsed,20),"right click pauses paid progress")
	Ra3Clearance.right_click(base)
	check(is_equal_approx(battle.funds,3000),"second right click refunds paid cost")
	check(Ra3Clearance.start(base),"cancelled upgrade restarts")
	Ra3Clearance.tick(base,60)
	check(Ra3Clearance.level(factory)==3 and factory.can_queue("R3MIRAGE"),"Mirage uses T3 without RA2 laboratory")
	check(not factory.can_queue("R3FUTURE"),"Future additionally requires Defense Bureau adapter")
	var lab=battle._place_building("GATECH","ally",Vector2(1800,1800),true);lab._buildup_play=-1.0
	check(factory.can_queue("R3FUTURE") and airfield.can_queue("R3HARBINGER"),"existing lab satisfies both new units' bureau requirement")
	check(factory.can_queue("MGTK"),"RA2 Mirage still uses ordinary building technology")
	factory.position=Vector2(2800,1400)
	check(not factory.can_queue("R3FUTURE") and factory.can_queue("MGTK"),"outside projection blocks RA3 only")
	factory.position=Vector2(1700,1400)
	var saved=base.special.duplicate(true)
	base.special.clear()
	check(Ra3Clearance.level(factory)==1,"no global tier leak")
	base.special=saved
	check(Ra3Clearance.level(factory)==3,"serializable state restores exact tier")
	var future=actor("R3FUTURE","ally",Vector2(2100,2000))
	var gunship=actor("R3HARBINGER","ally",Vector2(2200,2100))
	check(future.hp==3000 and is_equal_approx(future.move_speed,67.5),"Future native health and source speed")
	check(gunship.hp==5000 and is_equal_approx(gunship.flight.max_speed(),180),"Harbinger native health and source speed")
	check(gunship.is_air and gunship.logistics.ammo_max==0 and not gunship.flight.landable,"gunship independent airborne magazine, no RA2 runway rearm")
	check(UnitSkillLayout.primary_id(future.unit_id)==Ra3Expansion.BEAM,"Future native active occupies Q")
	check(gunship.use_ability(UnitSkillLayout.index(gunship,0)),"real gunship Q toggles weapon")
	check(is_equal_approx(gunship.attack_range,450) and is_equal_approx(gunship.weapon.cooldown,0.1),"autocannon range and cadence consumed")
	check(gunship.use_ability(UnitSkillLayout.index(gunship,0)) and is_equal_approx(gunship.attack_range,600),"Q returns to collider cannons")
	check(is_equal_approx(gunship.min_range,75),"collider minimum range restored after mode switch")
	check(future._vet_value==2500 and gunship._vet_value==3000,"native recruit experience awards differ from prices")
	future.credit_kill(22500,"enemy")
	check(future.veteran_level==3 and is_equal_approx(future.max_hp,3750),"native Future progression reaches three ranks with native health multiplier")
	check(is_equal_approx(future.move_speed,67.5),"promotion never inherits Yuri movement boost")
	future._grant_veteran(0,false)
	check(not Ra3Expansion.use(future,Vector2(-10,-10)),"out of map riot beam rejected")
	check(Ra3Expansion.use(future,future.position+Vector2(180,0)),"ground-targeted riot beam accepted")
	check(not Ra3Expansion.use(future,future.position),"active beam cannot be retriggered")
	Ra3Expansion.tick(future,1.0)
	check(battle.projectiles_root.get_child_count()==1,"beam starts after minimum unpack delay")
	for shot in battle.projectiles_root.get_children():shot.free()
	Ra3Expansion.tick(future,2.0)
	check(not future.special.has("ra3_riot_point") and is_equal_approx(float(future.special.ra3_riot_cd),12),"pack stage ends while cooldown remains")
	var target=actor("MTNK","enemy",Vector2(2200,2000))
	gunship.position=target.position+Vector2(0,300)
	gunship.hull_angle=0.0;gunship.logistics.air_lift=1.0
	gunship.attack_target=target;gunship.attack_ordered=true;gunship.turret_angle=-PI/2.0;gunship.aim_dir=Vector2.UP
	var mounts=preload("res://scripts/units/ra3_gunship_mounts.gd")
	mounts.tick(gunship,2.0)
	for key in ["side","rear"]:
		mounts.states(gunship)[key].used=11;mounts.states(gunship)[key].remaining=0.0
	check(gunship._try_fire_ready(),"native gunship fires through actual weapon readiness path")
	check(battle.projectiles_root.get_child_count()==2 and gunship.special.ra3_clip==0 and is_equal_approx(gunship._cd_timer,4.0),"twelfth collider volley emits two shells then accounts for reload")
	var friendly=actor("MTNK","ally",target.position)
	var friendly_hp: float=friendly.hp
	for shell in battle.projectiles_root.get_children():
		shell.target_point=target.position
		Ra3Expansion.tick_shot(shell,2.0)
	check(friendly.hp<friendly_hp,"native collider warhead includes allied splash targets")
	for shot in battle.projectiles_root.get_children():shot.free()
	var before: float=target.hp
	future._fire_shot(target)
	var neutron=battle.projectiles_root.get_child(0)
	for i in 150:
		if neutron.splinters.get("neutron_stage","node")=="node":break
		Ra3Expansion.tick_shot(neutron,1.0/15.0)
	Ra3Expansion.tick_shot(neutron,0.25)
	check(target.hp<before,"neutron node damages an actual target")
	var snapshot=preload("res://scripts/save/battle_snapshot.gd").new().capture(battle)
	check(not snapshot.is_empty(),"clearance and active projectile fit existing snapshot schema")
	if DisplayServer.get_name()!="headless":
		for unit in [future,gunship]:
			check(unit._ra3_model!=null,"original native model attached: "+unit.unit_id)
			unit._ra3_model.set_process(false)
			unit._ra3_model._sample()
			unit._ra3_model.sync_pose(true)
			unit._ra3_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			for i in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image=unit._ra3_model.viewport.get_texture().get_image()
			var pixels:=0
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x,y).a>0.5:pixels+=1
			check(pixels>100,"native mesh produces opaque pixels: "+unit.unit_id,pixels)
			image.save_png(OS.get_environment("IRON_TIDE_REPORT_DIR")+"/"+unit.unit_id+".png")
			if unit.unit_id=="R3FUTURE":await check_future_selection(unit)
			var wreck=Ra3Wreck.spawn(unit)
			check(wreck!=null and wreck.parts.size()>1,"original collapse rig creates multiple bodies: "+unit.unit_id)
			wreck.free()
		check(neutron.has_node("NativeFx"),"live neutron payload attaches original effect mesh")
		var fx=neutron.get_node("NativeFx")
		fx.set_process(false);fx.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		for i in 3:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image=fx.viewport.get_texture().get_image()
		check(image.get_used_rect().get_area()>0,"native projectile shader produces visible pixels")
		image.save_png(OS.get_environment("IRON_TIDE_REPORT_DIR")+"/neutron.png")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	codec.restore(battle,snapshot)
	var restored_factory=battle.buildings.filter(func(b):return b.building_id=="GAWEAP")[0]
	check(Ra3Clearance.level(restored_factory)==3 and restored_factory.can_queue("R3FUTURE"),"real snapshot restore retains projected clearance and factory gating")
	check(battle.projectiles_root.get_child_count()==1,"active neutron node survives real snapshot restore")
	var restored_shot=battle.projectiles_root.get_child(0)
	var elapsed: float=restored_shot.splinters.age
	Ra3Expansion.tick_shot(restored_shot,0.25)
	check(is_equal_approx(float(restored_shot.splinters.age),elapsed+0.25),"restored projectile resumes its simulation clock")
	var restored_base=battle.buildings.filter(func(b):return b.building_id=="GACNST")[0]
	battle.paused=false
	var reason=preload("res://scripts/world/construction_repack.gd").check(battle,restored_base)
	check(preload("res://scripts/world/construction_repack.gd").execute(battle,restored_base),"upgraded base can repack through real command",reason)
	if not reason.ok:screen.free();return
	var mcv=battle.units.filter(func(u):return u.unit_id=="AMCV")[0]
	check(int(Ra3Clearance.state(mcv).tier)==3 and Ra3Clearance.level(restored_factory)==1,"packed MCV keeps tier but does not project it")
	screen.free()
	await get_tree().process_frame

func capture_future(model, label: String) -> Image:
	model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	for i in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image=model.viewport.get_texture().get_image()
	image.save_png(output_dir.path_join(label+".png"))
	return image

func check_future_selection(unit) -> void:
	var model=unit._ra3_model
	unit.special.ra3_fire_anim=0.0;unit.velocity=Vector2.ZERO
	unit.special.ra3_attack_age=100.0 # Selection fixture must leave the full ONCE attack animation.
	battle.clear_selection();model._sample()
	check(model.clip_name=="BIDA","unselected Future uses SDK bored pose")
	var resting: Transform3D=model.rig.get_bone_global_pose(3)
	var bored: Image=await capture_future(model,"future-unselected")
	battle.select_unit(unit,false);model._sample()
	check(model.clip_name=="BATA" and model.clip_time==0.0,"real selection starts SDK bored-to-attention transition")
	model.clip_time=0.5;model._sample()
	check(not resting.is_equal_approx(model.rig.get_bone_global_pose(3)),"selection transition actually moves native gun articulation")
	var middle: Image=await capture_future(model,"future-selecting")
	check(bored.get_data()!=middle.get_data(),"selected transition changes rendered mesh pixels")
	model.clip_time=1.0;model._sample()
	check(model.clip_name=="AIDA","31-frame BATA completes at its native 30 FPS endpoint")
	await capture_future(model,"future-selected")
	battle.clear_selection();model._sample()
	check(model.clip_name=="ABTA","real deselection starts SDK attention-to-bored transition")
	model.clip_time=0.75;model._sample()
	await capture_future(model,"future-deselecting")
	model.clip_time=1.5;model._sample()
	check(model.clip_name=="BIDA" and resting.is_equal_approx(model.rig.get_bone_global_pose(3)),"46-frame ABTA finishes without looping and restores native rest pose")
	battle.select_unit(unit,false);model._sample();model.clip_time=0.25;model._sample()
	battle.clear_selection();model._sample()
	check(model.clip_name=="ABTA","deselection can interrupt bored-to-attention as SDK script specifies")
	battle.select_unit(unit,false);model._sample()
	check(model.clip_name=="BATA","quick reselect starts valid attention transition")
	unit.velocity=Vector2(5,0);model._sample()
	check(model.clip_name=="MOVA" and model.selection_transition.is_empty(),"movement interrupts selection transition without freezing the model")
	unit.velocity=Vector2.ZERO;battle.clear_selection();model._sample();model.clip_time=1.5;model._sample()
