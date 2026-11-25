extends "res://tests/allied_abilities_regression.gd"

const Riot=preload("res://scripts/units/ra3_riot.gd")

func clear_shots() -> void:
	for shot in battle.projectiles_root.get_children():shot.free()
	for fx in get_tree().get_nodes_in_group("ra3_future_beams"):fx.free()

func beam(source, point: Vector2):
	var shot=Ra3Expansion.make_shot(source,null,point,"riot")
	shot.set_physics_process(false)
	shot.splinters.origin=source.position;shot.splinters.muzzles=[source.position,source.position]
	return shot

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing();battle.paused=false
	var unit=actor("R3FUTURE","ally",Vector2(1100,1200))
	unit.fire_stance="none"
	var goal:=Vector2(1800,1200)
	check(Ra3Expansion.use(unit,goal),"out-of-range Q accepts a reachable approach")
	check(unit.special.has("ra3_riot_approach") and not unit.special.has("ra3_riot_point") and float(unit.special.get("ra3_riot_cd",0))==0,"approach does not unpack or consume cooldown")
	unit.order_stop()
	check(not unit.special.has("ra3_riot_approach") and float(unit.special.get("ra3_riot_cd",0))==0,"S cancels queued approach without cooldown")
	check(Ra3Expansion.use(unit,goal),"Q can be reissued after cancellation")
	for i in 1000:
		unit._physics_process(1.0/60.0)
		if unit.special.has("ra3_riot_point"):break
	check(unit.special.has("ra3_riot_point") and unit.position.distance_to(goal)<=375.0,"real movement enters 250 native units before casting",{"position":str(unit.position),"special":str(unit.special)})
	check(float(unit.special.get("ra3_riot_cd",0))>14.9,"cooldown starts at actual unpack rather than distant click")
	unit.special.clear();unit.order_stop();clear_shots()
	unit.position=Vector2(1100,1200)
	check(Ra3Expansion.use(unit,goal),"second distant order accepted")
	# Model an invalid partial approach ending outside range (FAIL_WITH_INVALID_APPROACH).
	unit.has_move_order=false;Ra3Expansion.tick(unit,0.01)
	check(not unit.special.has("ra3_riot_approach") and not unit.special.has("ra3_riot_point") and float(unit.special.get("ra3_riot_cd",0))==0,"invalid approach cannot empty-fire or consume cooldown")
	check(not Ra3Expansion.use(unit,Vector2.INF) and not Ra3Expansion.use(unit,Vector2(-10,100)),"nonfinite and outside-map targets rejected")
	battle.water_rects=[Rect2(1500,400,1400,2400)];battle.path_service.set_water(battle.water_rects);battle._refresh_pathing()
	check(not Ra3Expansion.use(unit,Vector2(2200,1200)) and float(unit.special.get("ra3_riot_cd",0))==0,"ground tank rejects water approach with no reachable firing position")
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing()
	unit.special.clear();unit.position=Vector2(1200,1200)
	check(Ra3Expansion.use(unit,unit.position+Vector2(375,0)) and unit.special.has("ra3_riot_point"),"exact StartAbilityRange boundary starts unpack")
	unit.special.clear();unit.order_stop();clear_shots()
	# Keep a native vehicle's collision disc on both complete rays but away from tips.
	var victim=actor("R3FUTURE","enemy",Vector2(1230,1200));victim.hp=100000;victim.max_hp=100000
	var armor:=float(Ra3Expansion.rules.objects.R3FUTURE.armor.EXPLOSIVE)
	var totals: Array=[]
	for step in [1.0/120.0,1.0/60.0,1.0/15.0,0.4]:
		victim.hp=100000
		var shot=beam(unit,Vector2(1500,1200))
		for i in ceili(1.2/step):Ra3Expansion.tick_shot(shot,step)
		totals.append(100000-victim.hp)
		check(is_equal_approx(100000-victim.hp,15.0*2*25*0.3*armor),"15 native logic pulses per laser are independent of render step "+str(step),100000-victim.hp)
		check(int(shot.splinters.riot_next)==15 and int(shot.splinters.riot_tip)==15,"all line and delayed tip events drain once "+str(step))
		clear_shots()
	# Tip-only fixture beyond the first line capsule, still inside radius 5.
	victim.position=Vector2(1470,1170);victim.radius=0.0;victim.hp=100000
	var first=beam(unit,Vector2(1500,1200));Ra3Expansion.tick_shot(first,0.001)
	var immediate: float=100000-victim.hp
	check(is_equal_approx(immediate,25*0.3*armor),"first endpoint receives line damage only before 0.1-second nugget delay",immediate)
	Ra3Expansion.tick_shot(first,0.098)
	check(is_equal_approx(100000-victim.hp,immediate),"endpoint damage is not applied before its delay")
	Ra3Expansion.tick_shot(first,0.002)
	check(is_equal_approx(100000-victim.hp,immediate+50*0.3*armor),"50 endpoint damage arrives separately at 0.1 seconds",100000-victim.hp)
	clear_shots()
	# Collision geometry: graze a footprint, miss its center. Friendly/air excluded.
	var building=battle._place_building("GAPOWR","enemy",Vector2(1500,1500),true)
	building._buildup_play=-1;building.hp=100000;building.max_hp=100000
	var polygon: PackedVector2Array=building.footprint_poly()
	var edge: Vector2=(polygon[0]+polygon[1])*0.5+building.position
	check(Riot.point_distance(building,edge)<0.001,"endpoint collision uses building footprint boundary")
	check(Riot.line_distance(building,edge-Vector2(10,0),edge+Vector2(10,0))<0.001,"line collision intersects building footprint without requiring center hit")
	var footprint_shot=beam(unit,edge)
	Riot.damage(footprint_shot,building,Riot.rules.nuggets.LineDamageNugget)
	var native_building_damage:=25.0*0.3
	var profile: Dictionary=Ra3Expansion.rules.target_profiles.profiles[Ra3Expansion.rules.target_profiles.mapping["GAPOWR"]]
	var expected_building:=native_building_damage*float(profile.multipliers.EXPLOSIVE)*float(building.data.hp)/float(profile.hp)*0.5
	check(is_equal_approx(100000-building.hp,expected_building),"building damage applies requested half damage once after native scalar and cross-generation HP mapping")
	clear_shots()
	var friend=actor("MTNK","ally",unit.position+Vector2(30,0));var air=actor("JUMPJET","enemy",unit.position+Vector2(30,0))
	var filter_shot=beam(unit,Vector2(1500,1200))
	check(not Riot.eligible(filter_shot,friend) and not Riot.eligible(filter_shot,air),"native ENEMIES NEUTRALS and AIRBORNE exclusion retained")
	victim.special.submerged=true
	check(not Riot.eligible(filter_shot,victim),"submerged targets excluded")
	victim.special.erase("submerged");clear_shots()
	# Actual save/restore must retain pulse cursors, avoiding replay on reload.
	victim.position=Vector2(1230,1200);victim.radius=26;victim.hp=100000
	var saved=beam(unit,Vector2(1500,1200));Ra3Expansion.tick_shot(saved,0.45)
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	var restored=battle.projectiles_root.get_child(0)
	var restored_victim=battle.units.filter(func(u):return u.unit_id=="R3FUTURE" and u.side=="enemy")[0]
	Ra3Expansion.tick_shot(restored,0.75)
	check(is_equal_approx(100000-restored_victim.hp,15.0*2*25*0.3*armor),"snapshot restore resumes beam cursors without replaying damage",100000-restored_victim.hp)
	clear_shots()
	var source=battle.units.filter(func(u):return u.unit_id=="R3FUTURE" and u.side=="ally")[0]
	var legacy=beam(source,Vector2(1500,1200))
	legacy.splinters.age=0.45;legacy.splinters.riot_next=14;legacy.splinters.riot_tip=11;legacy.splinters.erase("riot_hz")
	Ra3Expansion.tick_shot(legacy,0.001)
	check(legacy.splinters.riot_hz==15 and legacy.splinters.riot_next==7 and legacy.splinters.riot_tip==6,"legacy 30Hz beam cursors migrate by event time, without replay")
	clear_shots()
	source.special.clear();source.position=Vector2(1100,1200);source.order_stop()
	check(Ra3Expansion.use(source,goal),"approach can be saved before skill starts")
	codec=preload("res://scripts/save/battle_snapshot.gd").new()
	snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	source=battle.units.filter(func(u):return u.unit_id=="R3FUTURE" and u.side=="ally")[0]
	check(source.special.has("ra3_riot_approach") and float(source.special.get("ra3_riot_cd",0))==0,"snapshot preserves pending location without consuming cooldown")
	source.order_move(source.position+Vector2(0,150))
	check(not source.special.has("ra3_riot_approach"),"new movement supersedes a restored Q approach")
	screen.free();await get_tree().process_frame
