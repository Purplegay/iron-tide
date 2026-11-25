extends "res://tests/allied_abilities_regression.gd"
const Soviet=preload("res://scripts/units/ra3_soviet.gd")
const Tower=preload("res://scripts/buildings/ra3_reaper_emplacement.gd")

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	battle.water_rects=[];battle.path_service.set_water([])
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var start:=Vector2(1550,1450)
	const ALERT="EVA_OURBASEISUNDERATTACK"
	for distance in [45.0,299.0]:
		Ra2Sfx._eva_last.erase(ALERT)
		var unit=actor("R3REAPER","ally",start)
		var point:Vector2=start+Vector2(distance,0)
		battle.select_unit(unit,false);battle._emit_selection()
		check(Soviet.use(unit,point),"normal leap order accepted "+str(distance))
		if not unit.special.has("walker_jump"):continue
		var flight:float=unit.special.walker_jump.flight
		var shooter=unit
		var tower
		var model=unit._ra3_model
		var render:=model!=null
		if render:model.set_process(false)
		battle.camera.position=(start+point)*0.5+RA2Art.art_dir(Vector2(0,-36))
		battle.camera.zoom=Iso.cam_zoom(1.6)
		battle.camera.reset_smoothing();battle.camera.force_update_scroll()
		var preflight_model=model
		if preflight_model==null:
			preflight_model=preload("res://scripts/units/ra3_expansion_model.gd").new()
			preflight_model.actor=unit;unit.add_child(preflight_model);preflight_model._build();preflight_model.set_process(false)
		preflight_model._sample(0)
		check(preflight_model.clip_name=="JMPA","takeoff clip starts immediately on Q")
		Soviet.tick(unit,0.55)
		check(unit.position.is_equal_approx(start) and is_zero_approx(unit.special.walker_height),"feet stay grounded until takeoff clip finishes")
		if not render:preflight_model.free()
		if render:
			model._sample(0)
			check(model.clip_name=="JMPA","takeoff pose remains active before liftoff")
		var peak:=0.0
		var age:=0.55
		var image_index:=0
		var had_takeoff:=true
		var had_air:=false
		var checked_skeleton:=false
		var last_x:=start.x
		while age<Soviet.Leap.TAKEOFF_SECONDS+flight+0.9:
			var dt:=1.0/24.0
			age+=dt
			if tower==null:
				Soviet.tick(unit,dt)
				if unit.is_queued_for_deletion():
					tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET" and b.position.distance_to(point)<0.01)[0]
					shooter=Tower.mount(tower)
					model=shooter._ra3_model
					if render:model.set_process(false)
				else:
					if age<0.62:check(unit.special.walker_height>0 and unit.position.x>start.x,"airborne by 0.6s")
					peak=maxf(peak,float(unit.special.walker_height))
					if unit.position.x<last_x-0.001:check(false,"ground track monotonic")
					last_x=unit.position.x
			else:Tower.tick(tower,dt)
			if render:
				for fx in get_tree().get_nodes_in_group("reaper_particles"):
					if battle.is_ancestor_of(fx) and not fx.is_queued_for_deletion():fx._process(dt)
				model._sample(dt);model.sync_pose();model.ground_shadow.refresh()
				model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
				shooter.queue_redraw()
				had_takeoff=had_takeoff or model.clip_name=="JMPA"
				had_air=had_air or model.clip_name=="JMPB"
				if model.clip_name=="JMPB" and not checked_skeleton:
					var bone_id:=24 # First independently parented leg pivot in the retail rig.
					var v:=Vector3.ZERO
					for c in model.clips.JMPB.channels:
						if int(c.bone)!=bone_id:continue
						match str(c.type):
							"XTranslation":v.x=c.frames[0]
							"YTranslation":v.z=-float(c.frames[0])
							"ZTranslation":v.y=c.frames[0]
					var expected:Vector3=model.rests[bone_id]*v
					check(model.rig.get_bone_pose_position(bone_id).distance_to(expected)<0.1,"airborne leg translation follows its bind axes")
					checked_skeleton=true
				if distance>200 and OS.get_environment("IRON_TIDE_CAPTURE_JUMP")=="1":
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var center:Vector2=battle.get_global_transform_with_canvas()*battle.camera.position
					var path:=output_dir.path_join("jump-%03d.png"%image_index)
					var img:Image=stage.get_texture().get_image()
					img.get_region(Rect2i(Vector2i(center)-Vector2i(350,300),Vector2i(700,550))).save_png(path)
					image_index+=1
		check(tower!=null and tower.position.distance_to(point)<0.01,"lands at ordered point")
		check(peak>90.0 and peak<160.0,"native control heights produce projected peak "+str(peak))
		check(flight>distance/450.0,"duration accounts for vertical travel")
		if render:
			check(had_takeoff and had_air and model.clip_name=="AIDB","takeoff then airborne loop then deployed pose")
			check(is_instance_valid(model.landing_legs) and model.landing_legs.joints.size()==9,"separate retail legs object animates")
		check(battle.selected_building==tower and shooter.selected,"solo selection transfers to deployed building and visible rig")
		if render:
			# Pixel picking reads the deployed viewport after the GPU has drawn it.
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		check(battle._pick_building_at(tower.art_center(),"ally")==tower,"turret can be picked at visible body")
		check(not Ra2Sfx._eva_last.has(ALERT),"deployment does not queue base attack EVA")
		var hp_before:float=tower.hp
		tower.receive_hit(10)
		check(tower.hp<hp_before and not Ra2Sfx._eva_last.has(ALERT),"damaged Reaper emplacement does not queue base attack EVA")
		var yard=battle._place_building("NACNST","ally",start+Vector2(-400,0),true)
		yard.receive_hit(10)
		check(Ra2Sfx._eva_last.has(ALERT),"ordinary construction yard still queues base attack EVA")
		exercise_attack_orders(tower)
		Tower.tick(tower,14)
		if render:
			model._sample(0)
			check(model.landing_legs==null,"temporary legs removed")
		start+=Vector2(0,280)
	var legacy=actor("R3REAPER","ally",start)
	var old_jump:=Soviet.Leap.create(start,start+Vector2(100,0))
	old_jump.erase("takeoff_seconds");old_jump.age=2.8
	legacy.special.walker_jump=old_jump
	Soviet.tick(legacy,0.1)
	check(legacy.position==start and is_zero_approx(legacy.special.walker_height),"old in-progress save keeps its previous launch clock")
	Soviet.tick(legacy,0.2)
	check(legacy.position.x>start.x and legacy.special.walker_height>0,"legacy jump continues without snapping to end")
	exercise_group_landings()
	screen.free()
	await get_tree().process_frame

func exercise_attack_orders(tower) -> void:
	var desired=actor("MTNK","enemy",tower.position+Vector2(185,10))
	var nearer=actor("MTNK","enemy",tower.position+Vector2(60,0))
	var beyond=actor("MTNK","enemy",tower.position+Vector2(550,0))
	check(battle.command_cursor.resolve(desired.art_center())=="attack","selected turret shows attack cursor")
	battle._issue_order(desired.art_center())
	check(tower.attack_target==desired,"right-click assigns chosen hostile, not nearer distractor")
	var previous:Array=battle.projectiles_root.get_children()
	Tower.mount(tower).special.erase("soviet_mounts")
	tower._think=0;Tower.tick(tower,0.05)
	check(tower.attack_target==desired and Tower.mount(tower).attack_target==desired,"auto scan and weapon mount retain manual target")
	var incoming=battle.projectiles_root.get_children().filter(func(n):return not previous.has(n) and n is Projectile and n.target==desired)
	var hp:float=desired.hp
	for shot in incoming:shot._physics_process(2.0)
	check(not incoming.is_empty() and desired.hp<hp,"ordered ground enemy takes damage from private mount")
	check(battle.command_cursor.resolve(beyond.art_center())=="blocked","out-of-range target is blocked")
	battle._issue_order(beyond.art_center())
	check(tower.attack_target==desired,"invalid order preserves current target")
	var b=battle._place_building("NAHAND","enemy",tower.position+Vector2(90,100),true)
	screen.hud.cmd_buttons.attack.pressed.emit()
	check(battle.command_mode=="attack","deployed building attack button arms A command")
	battle._issue_command_at(b.art_center())
	check(tower.attack_target==b,"attack command accepts hostile building")
	battle.stop_selected()
	check(tower.attack_target==null,"S releases target")
	for node in [desired,nearer,beyond]:
		battle.units.erase(node);node.free()
	battle.buildings.erase(b);b.free()


func exercise_group_landings() -> void:
	var goal:=Vector2(2000,1600)
	# Isolate the drop zone from random map obstacles and the earlier solo jumps.
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if battle.is_ancestor_of(obstacle) and obstacle.position.distance_to(goal)<850:obstacle.free()
	battle._refresh_pathing()
	var previous:Array=battle.buildings.duplicate()
	var walkers:Array=[]
	var sites:Array[Vector2]=[]
	var poly:=Building.placement_poly(GameData.get_building("R3REAPERTURRET"))
	for y in [-60,0,60]:
		var walker=actor("R3REAPER","ally",goal+Vector2(-175,y))
		walkers.append(walker)
		check(AlliedAbilities.use(walker,"allied_soviet_r3reaper",null,goal),"group Q accepts shared target")
		if not walker.special.has("walker_jump"):return
		var point:Vector2=walker.special.walker_jump.end
		for prior in sites:
			check(not Placement.polys_overlap(poly,prior,poly,point),"jump reservations have separate footprints")
		sites.append(point)
	check(sites[0]==goal,"first walker keeps original order")
	var target=actor("MTNK","enemy",sites[1])
	Soviet.tick(walkers[1],5)
	check(not AlliedAbilities.alive(target),"second impact crushes at its corrected destination")
	for i in [2,0]:Soviet.tick(walkers[i],5)
	for site in sites:
		check(battle.buildings.any(func(b):return b.building_id=="R3REAPERTURRET" and b.position.is_equal_approx(site)),"out-of-order touchdowns preserve assigned sites")
	var follower=actor("R3REAPER","ally",goal+Vector2(160,0))
	check(Soviet.use(follower,goal),"click on deployed Reaper chooses adjacent site")
	if not follower.special.has("walker_jump"):return
	var reserved:Vector2=follower.special.walker_jump.end
	check(not sites.has(reserved),"later order leaves all three emplacements in place")
	battle.water_rects.append(Rect2(reserved-Vector2.ONE*5,Vector2.ONE*10))
	Soviet.tick(follower,5)
	var towers:=0
	for b in battle.buildings:
		if previous.has(b) or b.building_id!="R3REAPERTURRET":continue
		towers+=1
		check(not b.position.is_equal_approx(reserved),"newly obstructed landing is corrected on contact")
	check(towers==4,"follower deploys alongside group despite late obstruction")

	var distant_goal:=goal+Vector2(510,0)
	var leader=actor("R3REAPER","ally",goal+Vector2(15,160))
	var rear=actor("R3REAPER","ally",goal+Vector2(20,190))
	check(Soviet.use(leader,distant_goal) and leader.special.get("walker_approach")==distant_goal,"leader reserves distant site while approaching")
	check(Soviet.use(rear,distant_goal) and rear.special.has("walker_approach") and rear.special.walker_approach!=distant_goal,"second approaching walker reserves a different site")
	leader.order_stop()
	check(Soviet.use(rear,distant_goal) and rear.special.get("walker_approach")==distant_goal,"stopping releases distant reservation for retargeting")
