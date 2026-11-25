extends "res://tests/allied_abilities_regression.gd"
const Soviet = preload("res://scripts/units/ra3_soviet.gd")

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:
		BattleRequest.configure_skirmish(mode,{})
		check(GameData.ra2_prereq_ok("NANRCT",["NACNST","NARADR"]) and not GameData.ra2_prereq_ok("NANRCT",["NACNST","NATECH"]), "classic reactor requires radar instead of lab")
		for id in Soviet.LABELS:check(not GameData.unit_in_production_catalog(id),"classic roster excludes "+id)
		return
	setup_logistics_scene(mode,"苏俄")
	battle.water_rects=[];battle.path_service.set_water([])
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.power_low=false;battle.funds=30000
	screen.hud.select_prod_tab("vehicle")
	for id in Soviet.LABELS:
		var locked: Button = screen.hud._prod_buttons.get(id)
		check(is_instance_valid(locked) and locked.disabled and screen.hud._catalog_block_reason(id).contains("战车工厂"),"locked card explains its required factory "+id)
	check(not screen.hud._prod_buttons.has("soviet_tesla"),"legacy Soviet prototype stays outside the deck")
	var plant=battle._place_building("NAWEAP","ally",Vector2(1400,1700),true)
	plant._process(10.0)
	battle.select_building(plant)
	battle._emit_selection()
	screen.hud.select_prod_tab("vehicle")
	for pair in [["R3TESLA","反应堆"],["R3APOC","苏联作战实验室"],["R3REAPER","反应堆"]]:
		check(screen.hud._prod_buttons[pair[0]].disabled and screen.hud._catalog_block_reason(pair[0]).contains(pair[1]),"missing tech label "+pair[1])
		check(not plant.enqueue(pair[0]),"factory alone cannot enqueue "+pair[0])
	var guide:Dictionary=preload("res://scripts/ui/unlock_guidance.gd").new(battle).describe("R3REAPER")
	check("反应堆" in str(guide.detail) and not ("R3SUPERREACTOR" in str(guide.detail)),"reactor has the requested name in unlock details")
	check(preload("res://scripts/admin/gm_unit_tools.gd").spawn_count(battle,{"id":"R3TESLA","side":"enemy","count":1})==1,"GM can spawn Tesla without reactor")
	battle._place_building("NAPOWR","ally",Vector2(1150,2000),true)
	check(not plant.can_queue("R3REAPER") and not plant.can_queue("R3TESLA"),"ordinary Soviet power plant cannot replace reactor")
	if not battle.owned_building_ids().has("NACNST"):
		battle._place_building("NACNST","ally",Vector2(800,2100),true)
	var radar=battle._place_building("NARADR","ally",Vector2(1400,2150),true)
	screen.hud.select_prod_tab("building")
	radar.under_construction=true
	check(GameData.ra2_missing_prereqs("NANRCT",battle.owned_building_ids())==["NARADR"] and screen.hud._catalog_block_reason("NANRCT").contains("雷达"),"reactor card names the unfinished radar")
	battle.request_structure("NANRCT")
	check(battle.structure_jobs("building","ally").is_empty(),"unfinished radar cannot start reactor")
	radar.under_construction=false
	check(not battle.owned_building_ids().has("NATECH") and GameData.ra2_prereq_ok("NANRCT",battle.owned_building_ids()),"completed radar unlocks reactor without lab")
	battle.request_structure("NANRCT")
	battle._tick_structure_queue(240.0)
	check(battle.struct_ready.get("NANRCT",0)==1 and not plant.can_queue("R3TESLA") and not plant.can_queue("R3REAPER"),"paid reactor is ready but does not unlock tanks before placement")
	var lab=battle._place_building("NATECH","ally",Vector2(1100,1800),true)
	lab.under_construction=true
	check(not plant.can_queue("R3APOC"),"unfinished lab cannot unlock Apocalypse")
	lab.under_construction=false
	check(plant.can_queue("R3APOC") and not plant.can_queue("R3REAPER"),"lab unlocks only Apocalypse")
	var reactor=battle.deliver_ready_structure("NANRCT","ally",Vector2(850,1900))
	check(is_instance_valid(reactor) and reactor.building_id=="NANRCT","real Soviet nuclear reactor delivered")
	if not is_instance_valid(reactor):screen.free();return
	screen.hud.select_prod_tab("vehicle")
	if DisplayServer.get_name() != "headless":
		var last: Button = screen.hud._prod_buttons.get("R3REAPER")
		if is_instance_valid(last):
			await get_tree().process_frame
			screen.hud._prod_scroll.ensure_control_visible(last)
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join("soviet-ra3-production.png"))
	var tanks=[]
	for id in Soviet.LABELS:
		check(preload("res://scripts/admin/gm_unit_tools.gd").target_ids().has(id),"GM roster "+id)
		var before:float=battle.funds
		var card:Button=screen.hud._prod_buttons.get(id)
		check(is_instance_valid(card) and not card.disabled,"correct tech enables card "+id)
		if not is_instance_valid(card) or card.disabled:continue
		card.pressed.emit()
		check(plant.production==[id],"actual factory order "+id)
		plant._process(120.0)
		var found=battle.units.filter(func(u):return u.unit_id==id and u.side=="ally")
		check(found.size()==1,"factory produces "+id)
		if found.is_empty():continue
		var u=found[0];activate(u);u.set_fire_stance("defend");u.position=Vector2(1450+tanks.size()*110,1450)
		check(is_equal_approx(before-battle.funds,float(u.data.cost)),"native cost "+id)
		check(u.skills.any(func(a):return a.id==UnitSkillLayout.primary_id(id)),"unit skill "+id)
		check(not GameData.ra2_sound_files(Ra2Sfx.voice_id(u.data,"select")).is_empty() and ResourceLoader.exists(GameData.ra2_cameo_path(id)),"voice and icon "+id)
		u._grant_veteran(3,false);check(u.veterancy_status().rank==3,"heroic rank "+id);u._grant_veteran(0,false)
		tanks.append(u)
	reactor._die()
	check(not plant.can_queue("R3REAPER") and not plant.can_queue("R3TESLA"),"losing reactor locks new orders again")
	if tanks.size()!=3:screen.free();return
	battle.camera.position=Vector2(1540,1450);battle.camera.zoom=Iso.cam_zoom(1.6);battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	if DisplayServer.get_name()!="headless":
		for u in tanks:check(u._ra3_model!=null and u._ra3_model.rig.get_bone_count()>0,"native skinned model "+u.unit_id)
		for i in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join("soviet-three.png"))
	var enemy=actor("MTNK","enemy",Vector2(1500,1450));enemy.hp=10000;enemy.max_hp=10000
	if DisplayServer.get_name()!="headless":await exercise_reaper_art(tanks[2],enemy)
	for u in tanks:
		enemy.position=u.position+Vector2(100,0);u.attack_target=enemy;u.attack_ordered=true;u.turret_angle=0
		var hp:float=enemy.hp
		check(u._try_fire_ready(),"primary shot "+u.unit_id)
		for shot in battle.projectiles_root.get_children():
			if shot is Projectile and shot.splinters.has("soviet_round"):shot._physics_process(1)
		check(enemy.hp<hp,"damage "+u.unit_id)
	var tesla=tanks[0];enemy.position=tesla.position+Vector2(40,0)
	check(tesla.use_ability(UnitSkillLayout.find(tesla,UnitSkillLayout.primary_id(tesla.unit_id))),"short circuit toggle");Soviet.tick(tesla,0.1)
	check(tesla._deployed and enemy._stun_timer>1,"short circuit immobilizes tank and stuns vehicle")
	var apoc=tanks[1];check(apoc.use_ability(UnitSkillLayout.find(apoc,UnitSkillLayout.primary_id(apoc.unit_id))),"harpoon toggle")
	enemy.position=apoc.position+Vector2(160,0);apoc.attack_target=enemy;apoc.attack_ordered=true;apoc.turret_angle=0
	check(apoc._try_fire_ready() and apoc.special.has("harpoon_target"),"harpoon acquires vehicle")
	var reaper=tanks[2];var point:Vector2=reaper.position+Vector2(80,0)
	check(AlliedAbilities.use(reaper,UnitSkillLayout.primary_id(reaper.unit_id),null,point),"Reaper accepts legal deployment")
	Soviet.tick(reaper,Soviet.Leap.TAKEOFF_SECONDS+0.1);check(reaper.special.has("walker_jump"),"jump in flight")
	for id in Soviet.LABELS:plant.buildable.erase(id) # Factory menu from a pre-port save.
	reaper.special.soviet_mounts={}
	reaper._grant_veteran(3,false)
	Soviet.volley(reaper,enemy,"rocket",10,0.1,8.0,7,375)
	var flying=battle.projectiles_root.get_children().back()
	Soviet.advance(flying,flying.splinters.duration*0.3)
	var saved_age:float=flying.splinters.age
	reaper._grant_veteran(0,false)
	var codec=preload("res://scripts/save/battle_snapshot.gd").new();var state=codec.capture(battle);codec.restore(battle,state)
	var restored=battle.projectiles_root.get_children().filter(func(n):return n is Projectile and n.splinters.get("reaper_heroic",false) and not n.is_queued_for_deletion())
	check(restored.size()==1 and is_equal_approx(restored[0].splinters.age,saved_age),"in-flight heroic round keeps launch rank and age through save")
	if restored.size()==1:Soviet.advance(restored[0],2.0)
	plant=battle.buildings.filter(func(b):return b.building_id=="NAWEAP")[0]
	for id in Soviet.LABELS:check(plant.buildable.has(id),"pre-port factory restored with "+id)
	check(not plant.can_queue("R3TESLA") and not plant.can_queue("R3REAPER"),"restored factory respects absent reactor for both products")
	reaper=battle.units.filter(func(u):return u.unit_id=="R3REAPER")[0]
	Soviet.tick(reaper,1.0)
	var towers=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")
	check(towers.size()==1 and towers[0].max_hp==900 and towers[0].position.distance_to(point)<0.01,"save restores jump then lands at 900 HP building")
	check(reaper.is_queued_for_deletion() and not battle.units.has(reaper),"mobile unit replaced permanently")
	if towers.size()==1:
		var tower=towers[0]
		var air=actor("JUMPJET","enemy",point+Vector2(110,0))
		air.logistics.air_lift=1;air.max_hp=10000;air.hp=10000
		var below=actor("MTNK","enemy",air.position);var ground_hp:float=below.hp
		tower._think=5;tower.attack_target=air
		tower.special.erase("soviet_mounts")
		preload("res://scripts/buildings/ra3_reaper_emplacement.gd").tick(tower,0.1)
		var rockets=battle.projectiles_root.get_children().filter(func(n):return n is Projectile and n.splinters.get("soviet_round","")=="rocket" and not n.is_queued_for_deletion())
		check(rockets.size()>0,"deployed turret fires AA rocket")
		for shot in rockets:shot._physics_process(2.0)
		check(air.hp<10000 and below.hp==ground_hp,"deployed AA round hits aircraft above ground vehicle")
		var again=preload("res://scripts/save/battle_snapshot.gd").new()
		var saved=again.capture(battle);again.restore(battle,saved)
		tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")[0]
		var gun=preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(tower)
		check(not battle.units.has(gun) and not gun.is_in_group("combatants") and tower.special.get("walker_deployed",false),"restored building has a private mount and no second combatant")
		if DisplayServer.get_name()!="headless":
			var old:=get_tree().get_nodes_in_group("ra3_wrecks").size()
			tower._die()
			check(get_tree().get_nodes_in_group("ra3_wrecks").size()==old+1,"deployed building uses turret COL")
	if DisplayServer.get_name()!="headless":
		for id in Soviet.LABELS:
			var victim=actor(id,"enemy",Vector2(1700,1500))
			var before=get_tree().get_nodes_in_group("ra3_wrecks").size()
			victim.receive_hit(999999)
			var wrecks=get_tree().get_nodes_in_group("ra3_wrecks")
			check(wrecks.size()==before+1 and wrecks[-1].parts.size()>1,"native COL fragments "+id)
	screen.free();await get_tree().process_frame

func exercise_reaper_art(unit,enemy) -> void:
	var model=unit._ra3_model
	model.set_process(false)
	unit.attack_target=null
	unit.set_selected(false);model._sample(0.0)
	var idle=await sample_pose_image(model,"idle")
	unit.set_selected(true);model._sample(0.03)
	check(model.clip_name=="BATA","selection plays BATA")
	model._sample(0.3)
	var opening=await sample_pose_image(model,"opening")
	check(idle.get_data()!=opening.get_data(),"selection changes rendered skeleton")
	model._sample(10.0)
	check(model.clip_name in ["AIDA","AIFA"],"selection settles into alert idle")
	unit.set_selected(false);model._sample(0.03)
	check(model.clip_name=="ABTA","deselection plays ABTA")
	model._sample(0.3)
	await sample_pose_image(model,"closing")
	unit.set_selected(true);model._sample(0.03)
	check(model.clip_name=="BATA","rapid reselection reverses transition")
	unit.set_selected(false);model._sample(0.03);model._sample(10.0)
	check(model.clip_name in ["BIDA","BIFA","BIFB","BIFC"],"deselection settles into bored idle")
	model.set_process(true)
	enemy.position=unit.position+Vector2(150,0)
	for rank in [0,3]:
		unit._grant_veteran(rank,false)
		unit.special.soviet_mounts={}
		for key in ["rocket","grenade1"]:
			check(Soviet.volley(unit,enemy,key,3,0.2,2.5,10,400),"art volley "+key+str(rank))
			if key=="grenade1":check(unit.special.soviet_muzzle=="B_FX_02","front grenade uses front launcher")
			var shot=battle.projectiles_root.get_children().back()
			shot.set_physics_process(false)
			Soviet.advance(shot,shot.splinters.duration*0.35)
			var visual=shot.get_node_or_null("ReaperRound")
			var expected:="EXSOVIETGRENADE" if key=="grenade1" else ("EXSOVIETROCKET_VET" if rank==3 else "EXSOVIETROCKET")
			check(visual!=null and visual.model_id==expected,"in-flight object "+expected)
			if visual==null:continue
			var first:Quaternion=visual.pivots[-1].quaternion
			Soviet.advance(shot,shot.splinters.duration*0.25)
			if key=="grenade1":check(first.angle_to(visual.pivots[-1].quaternion)>0.01,"grenade rotates in flight")
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels:Image=visual.viewport.get_texture().get_image()
			check(pixels.get_used_rect().has_area(),"native round renders pixels "+expected)
			pixels.save_png(output_dir.path_join(expected+".png"))
			Soviet.advance(shot,2.0)
			check(shot.is_queued_for_deletion(),"round removed on impact")
			await get_tree().process_frame
	unit.special.soviet_mounts={}
	unit._cd_timer=0.0
	unit._grant_veteran(0,false)

func sample_pose_image(model,phase:String) -> Image:
	model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame:Image=model.viewport.get_texture().get_image()
	frame.save_png(output_dir.path_join("reaper-"+phase+".png"))
	return frame
