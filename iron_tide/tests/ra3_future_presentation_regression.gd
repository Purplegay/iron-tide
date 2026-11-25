extends "res://tests/allied_abilities_regression.gd"

const State=preload("res://scripts/units/ra3_future_state.gd")

func changed_pixels(a: Image, b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			if a.get_pixel(x,y)!=b.get_pixel(x,y):count+=1
	return count

func capture(viewport: SubViewport, label: String) -> Image:
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	for i in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();image.save_png(output_dir.path_join(label+".png"));return image

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var factory=battle._place_building("GAWEAP","ally",Vector2(1300,1300),true);factory._buildup_play=-1.0
	var unit=battle.spawn_unit("R3FUTURE","ally",Vector2(1600,1600),factory);activate(unit)
	var target=actor("MTNK","enemy",Vector2(1860,1600));target.hp=100000;target.max_hp=100000
	var peer=actor("MTNK","enemy",Vector2(1880,1600))
	var model=unit._ra3_model
	check(float(unit.special.ra3_just_built)==2.5,"producer sets native 2.5-second JUST_BUILT")
	model.set_process(false);model._sample();model.sync_pose()
	check(model.clip_name=="XMOVA","actual factory output chooses XMOVA")
	await capture(model.viewport,"future-just-built")
	Ra3Expansion.tick(unit,2.5);model._sample()
	check(model.clip_name!="XMOVA","factory intro ends without looping forever")
	unit.fire_stance="defend";unit.attack_target=target;unit.attack_ordered=true;unit._cd_timer=0.0
	unit.hull_angle=0;unit.turret_angle=0;unit.aim_dir=Vector2.RIGHT
	check(not unit._try_fire_ready() and is_equal_approx(float(unit.special.ra3_pre_left),0.1),"real weapon entry starts PER_TARGET preattack before firing")
	model._sample()
	check(model.clip_name=="ATKG" and model.future_charge[0].visible and model.future_charge[1].visible,"PREATTACK_A drives body clip and both charge draw modules")
	Ra3Expansion.tick(unit,0.05);check(not unit._try_fire_ready(),"0.05 seconds cannot skip the 0.1-second preparation")
	Ra3Expansion.tick(unit,0.05);check(unit._try_fire_ready(),"native preattack boundary permits first shot")
	model._sample();check(model.clip_name in ["ATKE","ATKF"],"shot selects the original barrel-specific ONCE animation")
	check(model.fire_lights[0].visible,"normal shot emits source FX_Allied_FutureTank_Fire light")
	unit.special.ra3_attack_age=0.5;model._sample()
	check(not model.fire_lights[0].visible,"three-frame muzzle light does not persist through charge animation")
	var first_frame: float=model.future_charge[0].frame
	var second_frame: float=model.future_charge[1].frame
	check(not is_equal_approx(first_frame,second_frame),"opposite charge modules use 4-second forward versus 1-second reverse playback")
	check(model.future_charge[0].parts.size()==3 and model.future_charge[1].parts.size()==3,"complete charge includes cylinder, sphere and flare meshes")
	var low_opacity_visible:=false
	for charge in model.future_charge:
		for i in charge.parts.size():
			var opacity: float=charge.materials[i].get_shader_parameter("opacity")
			if charge.parts[i].visible and opacity>0 and opacity<0.5:low_opacity_visible=true
	check(low_opacity_visible,"fractional native visibility curves remain visible below the old boolean threshold")
	await capture(model.viewport,"future-charging")
	unit.special.ra3_attack_age=4.9;model._sample()
	check(model.clip_name in ["ATKE","ATKF"],"151-frame ONCE attack persists beyond old half-second cutoff")
	unit.special.ra3_attack_age=5.01;model._sample();check(not model.future_charge[0].visible,"full attack ends and charge draw is hidden")
	unit._cd_timer=0;unit.attack_target=peer
	check(not unit._try_fire_ready(),"new target requires another PER_TARGET charge")
	unit.order_stop();Ra3Expansion.tick(unit,0.01)
	check(not unit.special.has("ra3_pre_target"),"stop cancels stale preattack target")
	for shot in battle.projectiles_root.get_children():shot.free()
	screen.hud.process_mode=Node.PROCESS_MODE_ALWAYS;screen.hud.set_process(false)
	battle.select_unit(unit,false);battle._emit_selection();await get_tree().process_frame
	var hud=screen.hud;var q:=UnitSkillLayout.index(unit,0)
	check(battle.request_ability(q)==-1,"real Q entry arms ground targeting")
	model._sample();check(model.clip_name=="BATB" and not model.future_reverse,"targeting starts BATB forward")
	model.clip_time=0.2;unit.velocity=Vector2(40,0);model._sample()
	check(model.clip_name=="BATB" and is_equal_approx(model.clip_time,0.2),"moving during Q targeting preserves unpack progress")
	unit.velocity=Vector2.ZERO;model._sample()
	check(model.clip_name=="BATB" and is_equal_approx(model.clip_time,0.2),"stopping during Q targeting does not skip unpack")
	model.clip_time=0.4;model._sample();var pose: Transform3D=model.rig.get_bone_global_pose(3)
	await capture(model.viewport,"future-q-unpack")
	battle.cancel_cast();model._sample()
	check(model.clip_name=="BATB" and model.future_reverse,"right cancel starts reverse BATB")
	check(pose.is_equal_approx(model.rig.get_bone_global_pose(3)),"partial unpack reverses from current frame without a pose jump")
	unit.velocity=Vector2(40,0);model._sample()
	check(model.future_reverse and model.clip_name=="BATB","movement during packing preserves reverse transition")
	unit.velocity=Vector2.ZERO;model._sample()
	model.clip_time=1.0;model._sample();check(model.clip_name=="AIDA","reverse finishes in selected idle")
	check(unit.ability_ready(q) and float(unit.ability_info(q).cd_left)==0,"cancel targeting consumes no cooldown")
	battle.request_ability(q);Ra3Expansion.tick(unit,0.7);model._sample();model.clip_time=1.0;model._sample()
	check(model.clip_name=="ATKD","armed laser holds native MANUAL last frame")
	check(Ra3Expansion.use(unit,target.position),"ground position starts Q through native ability handler")
	battle.cast_slot=-1;hud._update_ability_live()
	check(not unit.ability_ready(q) and hud._ability_btns[0].disabled,"cooldown authority disables real skill button")
	check(hud._ability_btns[0].get_meta("cd").text=="15s","actual HUD displays fifteen seconds after cast")
	check(battle.request_ability(q)==0 and not Ra3Expansion.use(unit,target.position),"keyboard and direct handler both reject recast")
	Ra3Expansion.tick(unit,0.49);check(battle.projectiles_root.get_child_count()==0,"selected preparation still honors 0.5-second minimum unpack")
	Ra3Expansion.tick(unit,0.01);check(battle.projectiles_root.get_child_count()==1,"beam fires after selection-adjusted unpack")
	var beam=battle.projectiles_root.get_child(0)
	check(beam.splinters.muzzles.size()==2 and beam.splinters.muzzles[0].distance_to(beam.splinters.muzzles[1])>1,"two original FX_WEAPON bones are distinct beam origins")
	var visual=get_tree().get_nodes_in_group("ra3_future_beams")[0];visual.set_process(false)
	Ra3Expansion.tick_shot(beam,0.25);visual._process(0.25)
	check(visual.beams.size()==2 and visual.glows.size()>=4,"both scrolling beams emit start and endpoint glows")
	check(str(visual.beams[0].material.get_shader_parameter("second").resource_path).ends_with("FXAlienLaser.png"),"LaserDraw consumes native second texture")
	battle.camera.position=Vector2(1750,1600);battle.camera.zoom=Iso.cam_zoom(1.5);battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	await capture(stage,"future-q-beams")
	# Isolate the two polygons so HUD/units/endpoint flares cannot satisfy this test.
	var beam_view:=SubViewport.new();beam_view.size=stage.size;beam_view.transparent_bg=true
	beam_view.world_2d=World2D.new();add_child(beam_view);beam_view.canvas_transform=stage.get_canvas_transform()
	for line in visual.beams:line.reparent(beam_view,false)
	var lit: Image=await capture(beam_view,"future-q-lines-only")
	for line in visual.beams:line.visible=false
	var unlit: Image=await capture(beam_view,"future-q-without-lines")
	check(changed_pixels(lit,unlit)>100,"dual beams contribute real pixels, independently of endpoint glows")
	for line in visual.beams:
		line.visible=true;line.material.set_shader_parameter("age",0.6)
	var scrolled: Image=await capture(beam_view,"future-q-scrolled")
	check(changed_pixels(lit,scrolled)>100,"native second texture scroll changes real beam pixels")
	for line in visual.beams:line.reparent(visual,false)
	beam_view.free()
	Ra3Expansion.tick(unit,2.0);model._sample();hud._update_ability_live()
	check(model.clip_name=="BATB" and model.future_reverse,"pack completion exits through reverse BATB")
	check(hud._ability_btns[0].get_meta("cd").text=="13s","cooldown stays visible after beam and pack complete")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new();var saved=codec.capture(battle)
	check(not saved.is_empty(),"new attack and ability state uses existing snapshot contract")
	codec.restore(battle,saved)
	unit=battle.units.filter(func(u):return u.unit_id=="R3FUTURE")[0];activate(unit)
	q=UnitSkillLayout.index(unit,0)
	check(not unit.ability_ready(q) and is_equal_approx(float(unit.ability_info(q).cd_left),12.5),"actual save restore preserves Q cooldown")
	check(get_tree().get_nodes_in_group("ra3_future_beams").is_empty(),"restore removes previous timeline beam visuals")
	var restored_shot=battle.projectiles_root.get_child(0)
	Ra3Expansion.tick_shot(restored_shot,0.01)
	check(get_tree().get_nodes_in_group("ra3_future_beams").size()==1,"saved active beam recreates one renderer on its existing timeline")
	Ra3Expansion.tick(unit,12.5);check(unit.ability_ready(q),"ability becomes ready at native cooldown endpoint")
	for shot in battle.projectiles_root.get_children():shot.free()
	unit._fire_shot(target if is_instance_valid(target) else battle.units.filter(func(u):return u.side=="enemy")[0])
	var shot=battle.projectiles_root.get_child(0);Ra3Expansion.tick_shot(shot,0.01)
	for i in 150:
		if shot.splinters.get("neutron_stage","node")=="node":break
		Ra3Expansion.tick_shot(shot,1.0/15.0)
	var fx=shot.get_node("NativeFx");fx.set_process(false)
	check(fx.rows.size()==14,"neutron node includes ten initial shells, glow, lights and delayed expansion")
	for seconds in [0.2,1.2,1.8,2.4]:
		fx.age=seconds;fx._sample()
		var image: Image=await capture(fx.viewport,"neutron-"+str(seconds))
		check(image.get_used_rect().get_area()>0,"native sphere and aura render at "+str(seconds))
		await capture(stage,"neutron-battle-"+str(seconds))
	var delayed=fx.rows.filter(func(r):return str(r.data.attrs.id).contains("Hit_XP"))[0]
	check(is_equal_approx(float(delayed.delay),35.0/30.0) and is_equal_approx(float(delayed.life),40.0/30.0),"visual delay and life come from particle XML rather than six-second damage lifetime")
	check(delayed.node.parts.size()==2,"expanded neutron effect includes native aura and sphere")
	fx.age=3.0;fx._sample();check(fx.rows.all(func(r):return not r.node.visible),"visual ends on source lifetime while damage node may remain alive")
	check(not fx.visible and not fx.is_processing() and fx.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"expired visual stops rendering while six-second damage node remains valid")
	var heroic=Ra3Expansion.make_shot(unit,null,unit.position+Vector2(200,0),"neutron")
	heroic.splinters.heroic=true;Ra3Expansion.tick_shot(heroic,0.01)
	for i in 150:
		if heroic.splinters.get("neutron_stage","node")=="node":break
		Ra3Expansion.tick_shot(heroic,1.0/15.0)
	var hero_fx=heroic.get_node("NativeFx");hero_fx.set_process(false);hero_fx.age=1.8;hero_fx._sample()
	check(hero_fx.rows.size()==14 and hero_fx.rows.all(func(r):return str(r.data.attrs.id).to_lower().ends_with("vet")),"heroic neutron resolves all native variants with case-insensitive SAGE asset IDs")
	var hero_image: Image=await capture(hero_fx.viewport,"neutron-heroic")
	check(hero_image.get_used_rect().get_area()>0,"heroic native aura and sphere render")
	var hero_beam=Ra3Expansion.make_shot(unit,null,unit.position+Vector2(200,0),"riot")
	hero_beam.splinters.heroic=true;hero_beam.splinters.origin=unit.position
	hero_beam.splinters.muzzles=Ra3Expansion.riot_muzzles(unit)
	preload("res://scripts/units/ra3_future_beam.gd").spawn(hero_beam)
	var hero_visual=get_tree().get_nodes_in_group("ra3_future_beams")[-1];hero_visual.set_process(false)
	check(hero_visual.beams[0].material.get_shader_parameter("emissive")==Vector3(9,1.5,1.5),"heroic LaserDraw uses original red emissive vector")
	unit.free();hero_beam.target=null;hero_visual._process(0.2)
	check(hero_visual.beams[0].visible,"beam retains its source point when shooter or target disappears")
	screen.free();await get_tree().process_frame
