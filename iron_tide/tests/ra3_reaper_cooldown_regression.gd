extends "res://tests/allied_abilities_regression.gd"
const Indicator=preload("res://scripts/ui/attack_cooldown_indicator.gd")
const Soviet=preload("res://scripts/units/ra3_soviet.gd")
const Emplacement=preload("res://scripts/buildings/ra3_reaper_emplacement.gd")

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	# Preserve the old split-talent battle snapshot while exercising the new W input.
	BattleRequest.combat_context.native_training_version=3
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.water_rects=[];battle.path_service.set_water([])
	var gun=actor("R3REAPER","ally",Vector2(1550,1450))
	var target=actor("MTNK","enemy",gun.position+Vector2(110,0))
	gun.hull_angle=0;gun.turret_angle=0
	gun.attack_target=target;gun.attack_ordered=true;gun.set_fire_stance("defend")
	check(Indicator.state(gun).is_empty(),"unselected ready Reaper has no rings")
	gun.set_selected(true)
	var ready:Array=Indicator.state(gun).mounts
	check(ready.map(func(s):return s.key)==["rocket","grenade1","grenade3","grenade2"] and ready.all(func(s):return s.left==0),"four ready mounts keep fixed positions")
	# Side-on target only lies inside the front and one side grenade arc.
	target.position=gun.position+Vector2.from_angle(PI/3)*110
	gun.turret_angle=PI/3
	check(gun._try_fire_ready(),"off-axis attack fires")
	Soviet.tick(gun,0.05)
	var first:Array=Indicator.state(gun).mounts
	check(is_equal_approx(first[0].fraction,0.5) and is_equal_approx(first[1].fraction,0.75),"rocket and grenade fractions follow 0.1s and 0.2s respectively")
	check(first[3].left>0 and first[2].left==0,"gun outside its arc remains ready")
	gun.set_selected(false)
	check(Indicator.state(gun).mounts.size()==4,"cooling unselected Reaper retains slot layout")
	for i in 9:
		Soviet.tick(gun,0.1);gun._try_fire_ready()
	var after:Array=Indicator.state(gun).mounts
	check(is_equal_approx(after[0].left,8.0) and after[0].fraction==1.0,"tenth rocket starts full eight-second reload")
	check(after[1].left>1.5 and after[1].left<2.5 and is_equal_approx(after[1].fraction,after[1].left/2.5),"grenade reload continues during rocket burst")
	gun._grant_veteran(3,false)
	Soviet.tick(gun,0.1)
	check(is_equal_approx(Indicator.state(gun).mounts[0].fraction,7.9/8.0),"promotion does not alter fraction of a running reload")
	var ordinary=actor("MTNK","ally",gun.position+Vector2(0,220))
	ordinary.set_selected(true);ordinary._cd_timer=0.4
	check(Indicator.state(ordinary).left==0.4 and not Indicator.state(ordinary).has("mounts"),"ordinary vehicles retain one indicator")
	var landing:Vector2=gun.position+Vector2(60,0)
	Soviet.use(gun,landing)
	Soviet.tick(gun,Soviet.Leap.TAKEOFF_SECONDS+float(gun.special.walker_jump.flight)+0.01)
	var tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")[0]
	tower._think=99;tower.attack_target=null;tower._buildup_play=-1
	check(EntityDescription.REAPER_CD_GUIDE in EntityDescription.text(tower.data) and EntityDescription.REAPER_CD_GUIDE in EntityDescription.text(GameData.get_unit("R3REAPER")),"both forms explain the four ring positions")
	var before:float=Indicator.state(tower).mounts[0].left
	check(before>0 and before<7.9,"deployment transfers live magazine timers")
	Emplacement.tick(tower,0.2)
	check(is_equal_approx(Indicator.state(tower).mounts[0].left,before-0.2),"deployed rocket ring advances even without firing again")
	tower._cd=777 # Generic building timer must not affect these rings.
	check(is_equal_approx(Indicator.state(tower).mounts[0].fraction,(before-0.2)/8),"deployed fraction ignores generic building timer")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var state_before:Dictionary=Indicator.state(tower)
	var saved=codec.capture(battle);codec.restore(battle,saved)
	tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")[0]
	check(Indicator.state(tower)==state_before,"all four rings survive a deployed mid-reload save")
	tower._think=99;tower.attack_target=null;Emplacement.tick(tower,9)
	check(Indicator.state(tower).is_empty(),"ready unselected turret hides rings")
	tower.set_selected(true)
	var pilot=Emplacement.mount(tower)
	var plane=actor("JUMPJET","enemy",tower.position+Vector2(110,0));plane.logistics.air_lift=1
	BattleRequest.combat_context.unit_talents={}
	tower.attack_target=plane
	Emplacement.tick(tower,0.01)
	check(Indicator.state(tower).mounts.slice(1).all(func(s):return s.left==0),"without split talent AA engagement leaves all three grenades ready")
	var rocket:Dictionary=pilot.special.soviet_mounts.rocket
	check(is_equal_approx(rocket.duration,0.1/1.2),"heroic shot uses actual faster interval")
	rocket.erase("duration");rocket.left=0.05/1.2
	check(is_equal_approx(Indicator.state(tower).mounts[0].fraction,0.5),"legacy save without duration resolves heroic shot interval")
	rocket.used=0;rocket.left=4.0/1.2
	check(is_equal_approx(Indicator.state(tower).mounts[0].fraction,0.5),"legacy save distinguishes a reload from a shot interval")
	exercise_other_weapons()
	exercise_fire_control()
	await exercise_split()
	await check_idle_barrels()
	await exercise_talent_damage()
	exercise_focus_clock()
	exercise_aa_cover()
	screen.free();await get_tree().process_frame

func exercise_talent_damage() -> void:
	var gun=actor("R3REAPER","ally",Vector2(960,1950))
	var main=actor("MTNK","enemy",gun.position+Vector2(140,0))
	var nearby=actor("MTNK","enemy",main.position)
	var other=actor("MTNK","enemy",gun.position+Vector2(0,140))
	gun.attack_target=main
	gun.attack_ordered=true
	gun.turret_angle=0
	gun.hull_angle=0
	for t in [main,nearby,other]:t.hp=100000
	for rank in 4:
		for key in [&"reaper_heat_fx",&"reaper_split_fx"]:
			if main.has_meta(key):main.get_meta(key).free()
		BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_fire_control":rank,"reaper_split_fire":rank}}
		gun.special.erase("reaper_focus")
		gun.special.erase("reaper_heat")
		var first=talent_round(gun,main,"grenade1")
		var hp:float=main.hp
		Soviet.advance(first,2.0)
		var base:float=hp-main.hp
		check(not main.has_meta(&"reaper_heat_fx"),"opening hit has no Heat feedback")
		check(base>0 and not first.splinters.has("focus_multiplier"),"first hit establishes focus without bonus")
		var time_limit:float=[0.0,5.0,3.5,2.0][rank]
		var focus:float=[1.0,1.05,1.07,1.10][rank]
		if rank>0:
			for mount in ["rocket","grenade2","grenade3"]:
				check(not talent_round(gun,main,mount).splinters.has("focus_multiplier"),"all opening salvo rounds are unboosted")
			Soviet.Split.advance_focus(gun,time_limit-0.01)
			check(not talent_round(gun,main,"rocket").splinters.has("focus_multiplier"),"no bonus just before threshold")
			Soviet.Split.advance_focus(gun,0.01)
		var diverted=talent_round(gun,other,"grenade2")
		check(diverted.splinters.get("split_boosted",false)==(rank>0),"split upgrade recorded on launch")
		var split:float=[1.0,1.1,1.35,1.5][rank]
		check(is_equal_approx(diverted.splinters.amount,15.0*split) and not diverted.splinters.has("focus_multiplier"),"only diverted side gun has split damage rank "+str(rank))
		hp=other.hp
		Soviet.advance(diverted,2.0)
		check(absf(hp-other.hp-base*split)<0.01,"split grenade impact uses rank multiplier")
		check(other.has_meta(&"reaper_split_fx")== (rank>0) and not main.has_meta(&"reaper_split_fx"),"damaging upgraded side shell alone shows Split")
		if rank>0:
			var marker=other.get_meta(&"reaper_split_fx")
			Soviet.advance(talent_round(gun,other,"grenade2"),2.0)
			check(other.get_meta(&"reaper_split_fx")==marker,"a second split hit refreshes the same marker")
			marker.free()
			other.special.iron_left=1.0
			Soviet.advance(talent_round(gun,other,"grenade2"),2.0)
			other.special.erase("iron_left")
			check(not other.has_meta(&"reaper_split_fx"),"immune victims do not show Split")
		for i in 2:
			var repeat=talent_round(gun,main,"grenade1")
			var near_hp:float=nearby.hp
			hp=main.hp
			Soviet.advance(repeat,2.0)
			check(absf(hp-main.hp-base*focus)<0.01 and absf(near_hp-nearby.hp-base)<0.01,"same gun refreshes a single bonus only on the focused victim at rank "+str(rank))
		check(main.has_meta(&"reaper_heat_fx")== (rank>0) and not nearby.has_meta(&"reaper_heat_fx") and not other.has_meta(&"reaper_heat_fx"),"Heat only appears on victim actually taking boosted focus damage")
		if rank>0:
			main.get_meta(&"reaper_heat_fx").free()
			main.special.iron_left=1.0
			Soviet.advance(talent_round(gun,main,"grenade1"),2.0)
			main.special.erase("iron_left")
			check(not main.has_meta(&"reaper_heat_fx"),"immune target cannot show Heat")
			Soviet.Split.advance_focus(gun,time_limit+0.01)
			check(talent_round(gun,main,"grenade1").splinters.has("focus_multiplier"),"uninterrupted engagement stays charged through reload")
			main.position+=Vector2(600,0)
			Soviet.Split.advance_focus(gun,0.1)
			main.position-=Vector2(600,0)
			check(talent_round(gun,main,"grenade1").splinters.has("focus_multiplier"),"returning to a hot target retains Heat")
			var linger:float=[0,6,7,7][rank]
			gun.order_stop()
			gun.attack_target=other
			Soviet.Split.advance_focus(gun,linger-0.2)
			var second=actor("R3REAPER","ally",gun.position+Vector2(0,12))
			second.attack_target=other
			var before_foreign:float=main.hp
			Soviet.advance(talent_round(second,main,"grenade2"),2.0)
			check(absf(before_foreign-main.hp-base*split)<0.01,"another Reaper cannot borrow the owner's Heat")
			hp=main.hp
			var spill_hp:float=nearby.hp
			Soviet.advance(talent_round(gun,main,"grenade2"),2.0)
			check(absf(hp-main.hp-base*split*focus)<0.01 and absf(spill_hp-nearby.hp-base*split)<0.01,"designated hot victim receives both multipliers, bystander only Split")
			check(main.has_meta(&"reaper_heat_fx") and main.has_meta(&"reaper_split_fx"),"double proc renders both hit markers")
			Soviet.Split.advance_focus(gun,linger-0.1)
			check(gun.special.reaper_heat.has(main),"damaging split hit refreshes the full target window")
			var inflight=talent_round(gun,main,"grenade2")
			Soviet.Split.advance_focus(gun,0.1)
			hp=main.hp
			Soviet.advance(inflight,2.0)
			check(not gun.special.get("reaper_heat",{}).has(main) and absf(hp-main.hp-base*split)<0.01,"a shell arriving at expiry gets only Split and cannot refresh Heat")
			gun.attack_target=other
			check(not talent_round(gun,other,"rocket").splinters.has("focus_multiplier"),"new primary starts unbuffed")
			gun.attack_target=main
			gun.attack_ordered=true

	for rank in range(1,4):
		var interval:float=[0,5,3.5,2][rank]
		var lifetime:float=[0,6,7,7][rank]
		var cap:int=[0,2,2,4][rank]
		var bonus:float=[0,0.05,0.07,0.10][rank]
		var split:float=[0,1.10,1.35,1.50][rank]
		gun.special.erase("reaper_heat")
		gun.special.erase("reaper_focus")
		BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_fire_control":rank,"reaper_split_fire":rank}}
		gun.attack_target=main
		talent_round(gun,main,"grenade1")
		for stack in range(1,cap+1):
			for frame in roundi(interval*60):Soviet.Split.advance_focus(gun,1.0/60.0)
			var primary=talent_round(gun,main,"rocket")
			check(primary.splinters.get("focus_stacks",0)==stack and is_equal_approx(primary.splinters.get("focus_multiplier",1.0),1+stack*bonus),"sustained fire reaches rank %d stack %d at its boundary"%[rank,stack])
		var base:float=0.0
		var other_gun=actor("R3REAPER","enemy",gun.position+Vector2(0,25))
		other_gun.attack_target=main
		var hp:float=main.hp
		Soviet.advance(talent_round(other_gun,main,"grenade1"),2.0)
		base=hp-main.hp
		gun.attack_target=other
		hp=main.hp
		Soviet.advance(talent_round(gun,main,"grenade2"),2.0)
		check(base>0 and absf(hp-main.hp-base*split*(1+cap*bonus))<0.01,"split damage multiplies the additive full-stack bonus")
		var layers:=Soviet.Split.heat_layers(gun,main)
		check(layers.size()==cap and layers.all(func(left):return is_equal_approx(left,lifetime)),"split refreshes all existing layers without creating another")
		gun.attack_target=main
		talent_round(gun,main,"grenade1")
		Soviet.Split.advance_focus(gun,interval*cap*3)
		check(Soviet.Split.heat_layers(gun,main).size()==cap,"long simulation step respects the cap")
		Soviet.Split.advance_focus(gun,lifetime-interval*(cap-1))
		check(Soviet.Split.heat_layers(gun,main).size()==(2 if rank==2 else cap-1),"rank two stays at two while ranks one and three lose their oldest layer between gains")

	if DisplayServer.get_name()!="headless":
		# Isolate the two labels on one fully heated victim.
		gun.position=Vector2(740,1510)
		main.position=gun.position+Vector2(140,0)
		other.position=gun.position+Vector2(0,140)
		gun.special.erase("reaper_heat")
		gun.special.erase("reaper_focus")
		nearby.position=main.position+Vector2(0,180)
		battle.camera.position=main.position
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		for i in 2:await get_tree().process_frame
		gun.attack_target=main
		Soviet.advance(talent_round(gun,main,"grenade1"),2.0)
		Soviet.Split.advance_focus(gun,8.0)
		Soviet.advance(talent_round(gun,main,"grenade1"),2.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center:Vector2=main.get_global_transform_with_canvas().origin
		var img:Image=stage.get_texture().get_image()
		img.get_region(Rect2i(Vector2i(center)-Vector2i(155,128),Vector2i(310,220))).save_png(output_dir.path_join("heat-impact.png"))

		gun.attack_target=other
		Soviet.advance(talent_round(gun,main,"grenade2"),2.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().get_region(Rect2i(Vector2i(center)-Vector2i(155,128),Vector2i(310,220))).save_png(output_dir.path_join("split-heat-impact.png"))
		gun.attack_target=main
		battle.camera.position=other.position
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		Soviet.advance(talent_round(gun,other,"grenade2"),2.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		center=other.get_global_transform_with_canvas().origin
		stage.get_texture().get_image().get_region(Rect2i(Vector2i(center)-Vector2i(155,128),Vector2i(310,220))).save_png(output_dir.path_join("split-impact.png"))

func exercise_focus_clock() -> void:
	BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_fire_control":3}}
	var walker=actor("R3REAPER","ally",Vector2(1800,1950))
	var tower=battle._place_building("R3REAPERTURRET","ally",Vector2(1800,2130),true)
	tower._buildup_play=-1
	for owner in [walker,tower]:
		var gun=walker if owner==walker else Emplacement.mount(tower)
		var enemy=actor("MTNK","enemy",owner.position+Vector2(140,0))
		gun.hull_angle=0.0
		gun.turret_angle=0.0
		if owner==tower:Emplacement.order(tower,enemy)
		else:
			gun.attack_ordered=true
			gun.attack_target=enemy
		gun.special.reaper_focus={"target":enemy,"remaining":1.0} # Pre-warm-up save.
		var first_frame:=-1
		var first_boost:=-1
		var premature:=false
		for frame in 240:
			var shots=battle.projectiles_root
			var before:int=shots.get_child_count()
			if owner==tower:tower._process(1.0/60.0)
			else:walker._physics_process(1.0/60.0)
			for j in range(before,shots.get_child_count()):
				var shot=shots.get_child(j)
				if first_frame<0:first_frame=frame
				if shot.splinters.has("focus_multiplier"):
					if first_boost<0:first_boost=frame
					if frame-first_frame<120:premature=true
		check(first_frame>=0 and first_boost>=first_frame+120 and not premature,"real firing clock warms up for two seconds across the opening salvos: "+str(owner==tower),[first_frame,first_boost])

	# Save the deployed owner's two independent timers plus a shell already in flight.
	var old_target=tower.attack_target
	Soviet.Split.advance_focus(tower,4.0)
	var alternate=actor("MTNK","enemy",tower.position+Vector2(0,140))
	alternate.hp=10000
	var tower_gun=Emplacement.mount(tower)
	BattleRequest.combat_context.unit_talents.R3REAPER.reaper_split_fire=3
	tower.attack_target=alternate
	tower_gun.attack_target=alternate
	Soviet.Split.advance_focus(tower,1.0)
	tower.special.reaper_heat[alternate]=2.0 # Legacy one-layer save.
	var saved_layers:Array=tower.special.reaper_heat[old_target].duplicate()
	var shell=talent_round(tower_gun,old_target,"grenade2")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle)
	codec.restore(battle,snapshot)
	var restored=battle.projectiles_root.get_children().filter(func(p):return p is Projectile and p.splinters.get("heat_owner") is Building)
	check(not restored.is_empty(),"deployed split shell retains heat owner across save")
	if not restored.is_empty():
		shell=restored.back()
		var owner=shell.splinters.heat_owner
		var victim=shell.target
		var heat:Dictionary=owner.special.reaper_heat
		check(heat.size()==2 and heat[victim]==saved_layers and Soviet.Split.heat_layers(owner,owner.attack_target)==[2.0],"two targets retain independent remaining times on load")
		Soviet.advance(shell,2.0)
		check(heat[victim].size()==saved_layers.size() and saved_layers.size()>1 and heat[victim].all(func(left):return is_equal_approx(left,7.0)) and heat[owner.attack_target]==[2.0],"in-flight split hit refreshes only its restored victim")

func talent_round(gun,target,mount:String):
	gun.special.soviet_mounts={}
	Soviet.volley(gun,target,mount,2,0.2,2.5,15.0,450.0)
	var shot=battle.projectiles_root.get_child(-1)
	shot.target_point=target.position
	return shot

func exercise_other_weapons() -> void:
	var fort=actor("BFRT","ally",Vector2(1850,1450))
	fort.set_selected(true)
	for id in ["GGI","E1","SNIPE","GGI","E1"]:
		var person=actor(id,"ally",fort.position+Vector2(9,0))
		check(person.logistics.request_board(fort),"board for weapon rings "+id)
		person.logistics.tick(0.1)
	var rings:Array=Indicator.state(fort).mounts
	check(rings.size()==6 and rings[0].key=="hull","full fortress shows hull and five weapons")
	check(Indicator.mount_offset(2,6)==Vector2(28,0) and Indicator.mount_offset(3,6)==Vector2(0,14) and Indicator.mount_offset(5,6)==Vector2(28,14),"six rings use two rows of three")
	var passenger=fort.logistics.passengers[0]
	passenger._cd_timer=0.27
	check(Indicator.state(fort).mounts[1].left==0.27 and Indicator.state(fort).mounts[2].left==0,"independent passenger timers")
	check(rings[1].color!=rings[2].color and rings[1].color==rings[4].color,"weapon color follows gun, not seat")
	var ship=actor("R3HARBINGER","ally",fort.position+Vector2(85,0))
	ship.set_selected(true)
	check(Indicator.state(ship).mounts.map(func(r):return r.key)==["side","rear"] and not ship.special.has("ra3_mounts"),"only collider guns are shown without initializing combat state")
	var guns:Dictionary=Indicator.Gunship.states(ship)
	guns.side.remaining=0.4;guns.side.duration=0.8
	var side:Dictionary=Indicator.state(ship).mounts[0]
	check(is_equal_approx(side.fraction,0.5) and Indicator.state(ship).mounts[1].left==0,"gunship independently reloading side gun")
	check(Ra3Expansion.use(ship,ship.position),"switch to front weapon")
	var front:Dictionary=Indicator.state(ship)
	check(not front.has("mounts") and front.key=="front" and front.color!=side.color,"machine gun mode shows only the nose gun")
	ship.set_selected(false)
	check(Indicator.state(ship).is_empty(),"hidden side gun cooldown does not reveal ready unselected nose gun")
	Indicator.Gunship.tick(ship,0.1)
	check(Ra3Expansion.use(ship,ship.position),"switch back to collider guns")
	var restored:Array=Indicator.state(ship).mounts
	check(restored.size()==2 and restored[0].key=="side" and is_equal_approx(restored[0].left,0.3),"returning shows the actual remaining side gun cooldown")
	var carrier=actor("CARRIER","ally",Vector2(2100,1600))
	carrier.set_selected(true)
	var berths:Array=Indicator.state(carrier).mounts
	check(berths.size()==carrier.logistics.squadron.size() and berths[0].key=="deck0","carrier has individual air groups and no phantom hull gun")
	var bunker=battle._place_building("NABNKR","ally",Vector2(2250,1680),true)
	bunker._buildup_play=-1;bunker.set_selected(true)
	for i in 2:
		var soldier=actor("E2","ally",bunker.position+Vector2(9,0))
		Indicator.Garrison.enter(soldier,bunker)
		soldier._cd_timer=0.25*i
	var garrison:Dictionary=Indicator.state(bunker)
	check(garrison.has("mounts") and garrison.mounts.size()==2 and garrison.mounts[0].left==0.0 and garrison.mounts[1].left==0.25,"occupied bunker reads both independent infantry weapons")

	var ifv=actor("FV","ally",Vector2(1950,1750))
	ifv.set_selected(true)
	var missile_color:Color=Indicator.state(ifv).color
	var engineer=actor("ENGINEER","ally",ifv.position+Vector2(8,0))
	check(engineer.logistics.request_board(ifv),"engineer enters IFV")
	engineer.logistics.tick(0.1)
	var support:=Indicator.state(ifv)
	check(support.has("color") and support.color!=missile_color and not support.has("mounts"),"IFV switches weapon color on a single shared mount")

func exercise_fire_control() -> void:
	# The isolated profile may already own this research from its purchase test.
	BattleRequest.combat_context.unit_talents={}
	var pos:=Vector2(1750,2200)
	var target=actor("MTNK","enemy",pos+Vector2.from_angle(deg_to_rad(143))*140)
	var walker=actor("R3REAPER","ally",pos)
	walker.hull_angle=0;walker.turret_angle=pos.angle_to_point(target.position)
	walker.attack_target=target;walker.attack_ordered=true
	walker._physics_process(1.0/60)
	check(is_zero_approx(walker.hull_angle) and walker.special.soviet_mounts.size()==2,"unresearched rear-quarter shot uses one grenade and rocket")
	BattleRequest.combat_context.unit_talents["R3REAPER"]="reaper_fire_control"
	check(not BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","enemy"),"talent applies only to player Reapers")
	check_actual_salvos(walker,target)
	var initial:Vector2=walker.position
	walker._physics_process(1.0/60)
	check(walker.hull_angle>0 and walker.hull_angle<=deg_to_rad(3.01),"mobile body turns at its native rate")
	for i in 70:walker._physics_process(1.0/60)
	check(walker.position==initial and walker.special.soviet_mounts.size()==4,"stationary mobile Reaper gains overlapping front and side fire")
	var tower=battle._place_building("R3REAPERTURRET","ally",pos+Vector2(0,95),true)
	tower._buildup_play=-1;tower._think=99
	var gun=Emplacement.mount(tower)
	gun.hull_angle=0
	check(Emplacement.order(tower,target),"deployed turret receives focus order")
	check_actual_salvos(gun,target)
	var anchor:Vector2=tower.position
	Emplacement.tick(tower,1.0/60)
	check(absf(gun.hull_angle)>0 and absf(gun.hull_angle)<=deg_to_rad(3.01),"deployed body turns gradually")
	for i in 100:Emplacement.tick(tower,1.0/60)
	check(tower.position==anchor and tower.special.soviet_mounts.size()==4 and is_equal_approx(tower.special.walker_heading,gun.hull_angle),"deployed body gains all reachable mounts in place and records facing")
	target.position=tower.position+Vector2(120,0)
	for i in 100:Emplacement.tick(tower,1.0/60)
	check(absf(angle_difference(gun.hull_angle,0.0))<0.001,"deployed facing follows a moving ground target")
	var plane=actor("JUMPJET","enemy",tower.position+Vector2(0,120))
	plane.logistics.air_lift=1.0
	Emplacement.order(tower,plane)
	gun.special.erase("soviet_mounts")
	for i in 12:Emplacement.tick(tower,1.0/60)
	check(absf(gun.hull_angle)<0.001 and gun.special.soviet_mounts.keys()==["rocket"],"air engagement only uses rockets")
	walker.order_move(walker.position+Vector2(-150,0))
	walker.attack_target=target
	var heading:float=walker.hull_angle
	Soviet.align_reaper(walker,0.5)
	check(is_equal_approx(heading,walker.hull_angle),"move order keeps steering priority")

# Count newly emitted projectiles in one firing pass. Mount timer keys alone
# would also include guns fired at an earlier bearing.
func check_actual_salvos(gun,target) -> void:
	var before_target:Vector2=target.position
	var before_heading:float=gun.hull_angle
	var before_turret:float=gun.turret_angle
	var before_mounts:Dictionary=gun.special.get("soviet_mounts",{}).duplicate(true)
	gun.attack_target=target
	gun.hull_angle=0
	for spec in [[143,140,["rocket","grenade2"]],[1,140,["rocket","grenade1","grenade2"]],[-1,140,["rocket","grenade1","grenade3"]],[0,30,["rocket","grenade1","grenade2","grenade3"]],[0,29,[]],[0,337.5,["rocket","grenade1","grenade2","grenade3"]],[0,338,[]]]:
		gun.turret_angle=deg_to_rad(spec[0])
		target.position=gun.position+Vector2.from_angle(gun.turret_angle)*float(spec[1])
		gun.special.soviet_mounts={}
		var host=battle.projectiles_root
		var first:int=host.get_child_count()
		Soviet.fire(gun)
		var rounds: Array=[]
		for i in range(first,host.get_child_count()):
			rounds.append(host.get_child(i).splinters.soviet_round)
		check(rounds==spec[2],"actual rounds at bearing/range "+str(spec.slice(0,2)),rounds)
	target.position=before_target
	gun.hull_angle=before_heading
	gun.turret_angle=before_turret
	gun.special.soviet_mounts=before_mounts

func exercise_split() -> void:
	BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_fire_control":3,"reaper_split_fire":1}}
	var origin:=Vector2(1850,1550)
	var walker=actor("R3REAPER","ally",origin)
	var tower=battle._place_building("R3REAPERTURRET","ally",origin+Vector2(0,180),true)
	tower._buildup_play=-1
	var main=actor("MTNK","enemy",origin)
	var other=actor("MTNK","enemy",origin)
	get_tree().paused=false
	battle.paused=false
	battle.process_mode=Node.PROCESS_MODE_ALWAYS
	battle.set_process(false);battle.set_physics_process(false)
	for child in battle.get_children():
		if child.process_mode==Node.PROCESS_MODE_INHERIT:child.process_mode=Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode=Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	get_window().focus_entered.emit()
	for gun in [walker,Emplacement.mount(tower)]:
		main.position=gun.position+Vector2(150,0)
		other.position=gun.position+Vector2.from_angle(deg_to_rad(-65))*150
		gun.hull_angle=0
		gun.turret_angle=0
		if gun==walker:battle.select_unit(walker,false)
		else:battle.select_building(tower)
		battle._emit_selection()
		gun.attack_target=null
		await key(KEY_W)
		check(battle.command_mode.is_empty(),"E before the first target cannot pre-arm split fire")
		gun.attack_target=main
		gun.attack_ordered=false
		if gun!=walker:
			tower.attack_target=main
			Emplacement.tick(tower,0.0)
		screen.hud._update_ability_live()
		var button:Button=screen.hud._ability_btns[1] if gun==walker else screen.hud._reaper_split_btn
		await key(KEY_W)
		check(button.disabled and battle.command_mode.is_empty() and not Soviet.Split.engaged(gun),"auto-acquired primary cannot enable or arm E")
		battle.force_attack(main)
		if gun!=walker:Emplacement.tick(tower,0.0)
		screen.hud._update_ability_live()
		check(not button.disabled and Soviet.Split.engaged(gun),"explicit attack order unlocks E for selected form")
		battle.camera.position=gun.position
		battle.camera.reset_smoothing();battle.camera.force_update_scroll()
		await key(KEY_W)
		check(battle.command_mode==Soviet.Split.ID and battle.split_gunner==gun,"E arms split fire for selected form")
		check(Soviet.ReaperFlight.Pose.definitions.grenade_mounts.all(func(m):return Soviet.Split.covers(gun,main,m)),"all three grenades can already hit the primary when E opens")
		Soviet.align_reaper(gun,1.0)
		check(is_zero_approx(gun.hull_angle),"preview holds its bearings with both talents")
		battle.move_order_overlay.queue_redraw()
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join("split-"+str(gun==walker)+".png"))
		battle._issue_command_at(main.art_center())
		check(battle.command_mode==Soviet.Split.ID and not gun.special.has("split_enemy"),"invalid click keeps preview")
		var pixel:Vector2=battle.get_canvas_transform()*other.art_center()
		var pointer:=InputEventMouseMotion.new()
		pointer.position=pixel;pointer.global_position=pixel
		stage.push_input(pointer,true)
		await get_tree().process_frame
		check(battle.world_input_enabled() and not battle._pointer_over_ui(),"second target is a live battlefield click")
		await mouse_button(pixel,true)
		await mouse_button(pixel,false)
		check(battle.command_mode.is_empty() and gun.special.get("split_enemy")==other and gun.attack_target==main,"second hostile accepted without replacing primary")
		gun.special.soviet_mounts={}
		var first:int=battle.projectiles_root.get_child_count()
		Soviet.fire(gun)
		var actual:Dictionary={}
		for i in range(first,battle.projectiles_root.get_child_count()):
			var shot=battle.projectiles_root.get_child(i)
			actual[shot.splinters.soviet_round]=shot.target
			check(shot.splinters.get("split_boosted",false)==is_same(shot.target,other),"only side gun assigned by E launches a Split-marked round")
		check(actual=={"rocket":main,"grenade1":main,"grenade2":main,"grenade3":other},"each real projectile uses its designated target")
		check(not Soviet.fire(gun),"second target does not bypass reload")
		gun.special.erase("split_side_index")
		gun.special.split_mount=1
		check(Soviet.Split.secondary(gun)==other and gun.special.split_side_index==2 and not gun.special.has("split_mount"),"legacy side assignment continues engaging the same enemy")
		var timers:Dictionary=gun.special.soviet_mounts.duplicate(true)
		other.position=gun.position+Vector2.from_angle(deg_to_rad(65))*150
		check(Soviet.Split.secondary(gun)==null and not gun.special.has("split_side_index"),"assigned gun relinquishes a target outside its arc")
		await key(KEY_W)
		battle._issue_command_at(other.art_center())
		check(gun.special.get("split_side_index")==1 and gun.special.soviet_mounts==timers,"opposite side can be selected without resetting any magazine")
		Soviet.tick(gun,0.21)
		first=battle.projectiles_root.get_child_count()
		Soviet.fire(gun)
		actual.clear()
		for i in range(first,battle.projectiles_root.get_child_count()):
			var shot=battle.projectiles_root.get_child(i)
			actual[shot.splinters.soviet_round]=shot.target
			check(shot.splinters.get("split_boosted",false)==is_same(shot.target,other),"only side gun assigned by E launches a Split-marked round")
		check(actual=={"rocket":main,"grenade1":main,"grenade2":other,"grenade3":main},"opposite sector diverts only its side gun")
		other.position=gun.position+Vector2(210,0)
		check(Soviet.Split.secondary(gun)==other and gun.special.split_side_index==1,"overlapping sectors retain a single assigned gun")
		var before_reorder:Dictionary=gun.special.soviet_mounts.duplicate(true)
		battle.force_attack(main)
		check(gun.attack_target==main and not gun.special.has("split_enemy") and not gun.special.has("split_side_index") and before_reorder==gun.special.soviet_mounts,"reissuing the same focus order immediately releases the side gun and preserves magazines")
		await key(KEY_W)
		battle._issue_command_at(other.art_center())
		check(gun.special.get("split_enemy")==other,"E can designate another target after the new order")
		check_split_warmup(gun,tower,main,other)
		other.position=gun.position+Vector2(500,0)
		check(Soviet.Split.secondary(gun)==null and not gun.special.has("split_enemy") and not gun.special.has("split_focus") and not Soviet.Split.heat_layers(gun,other).is_empty(),"out-of-range secondary releases its gun and unfinished charge, keeping earned layers")
		battle.stop_selected()
		gun.attack_target=main
		if gun!=walker:tower.attack_target=main;Emplacement.tick(tower,0.0)
		screen.hud._update_ability_live()
		check(button.disabled and not Soviet.Split.engaged(gun),"stopping then reacquiring cannot reuse the previous explicit order")

func check_split_warmup(gun,tower,main,other) -> void:
	var deployed:bool=gun.get_parent()==tower
	var first_side:=-1
	var first_layer:=-1
	var peak:=0
	var combo:=false
	var inflight:Array=[]
	check(Soviet.Split.heat_layers(gun,other).is_empty() and not gun.special.has("split_focus"),"E designates a cold target without precharging it")
	main.hp=100000;other.hp=100000
	for frame in 660:
		var host=battle.projectiles_root
		var before:int=host.get_child_count()
		if deployed:tower._process(1.0/60)
		else:gun._physics_process(1.0/60)
		for j in range(before,host.get_child_count()):
			var shot=host.get_child(j)
			if shot is Projectile and is_same(shot.target,other):
				inflight.append(shot)
				if first_side<0:first_side=frame
		for j in range(inflight.size()-1,-1,-1):
			var shot=inflight[j]
			var hp:float=other.hp
			Soviet.advance(shot,1.0/60)
			if other.hp<hp and other.has_meta(&"reaper_heat_fx") and other.has_meta(&"reaper_split_fx"):combo=true
			if shot.is_queued_for_deletion():inflight.remove_at(j)
		var layers:=Soviet.Split.heat_layers(gun,other).size()
		if first_layer<0 and layers>0:first_layer=frame
		peak=maxi(peak,layers)
	check(first_side>=0 and first_layer==first_side+120,"cold E target warms after two seconds from its own first shot",[deployed,first_side,first_layer])
	check(peak==4 and combo and gun.attack_target==main and not Soviet.Split.heat_layers(gun,main).is_empty(),"E side gun builds four layers and displays Split plus Heat while primary keeps firing",[deployed,peak,combo])

func check_idle_barrels() -> void:
	var center:=Vector2(1920,1760)
	var walker=actor("R3REAPER","ally",center)
	var tower=battle._place_building("R3REAPERTURRET","ally",center+Vector2(0,200),true)
	for gun in [walker,Emplacement.mount(tower)]:
		var model=gun._ra3_model
		if model==null:continue
		gun.attack_target=null
		gun.hull_angle=Iso.eff_angle()+PI/2-0.12
		gun.set_selected(true)
		model.set_process(false)
		for i in 60:model._sample(1.0/30)
		model.sync_pose()
		for pair in [["B_Turret_02","B_FX_01",1],["B_Turret_04","B_FX_03",-1]]:
			var pivot:Vector3=model.rig.get_bone_global_pose(model.rig.find_bone(pair[0])).origin
			var muzzle:Vector3=model.rig.get_bone_global_pose(model.rig.find_bone(pair[1])).origin
			check((muzzle.z-pivot.z)*pair[2]>5,"idle side muzzle extends outward from its own socket "+pair[0],[pivot,muzzle])
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		model.viewport.get_texture().get_image().save_png(output_dir.path_join("front-"+("walker" if gun==walker else "tower")+".png"))

		var target=actor("MTNK","enemy",gun.global_position+Vector2.from_angle(gun.hull_angle)*140)
		var left:int=model.rig.find_bone("B_Turret_04")
		var right:int=model.rig.find_bone("B_Turret_02")
		gun.attack_target=target
		if gun==walker:gun.velocity=Vector2(25,0)
		var initial:Quaternion=model.rig.get_bone_pose_rotation(left)
		model._sample(0)
		check(initial.angle_to(model.rig.get_bone_pose_rotation(left))<0.001,"acquiring while moving or deployed keeps barrel pose")
		var largest:=0.0
		for i in 30:
			var before:Quaternion=model.rig.get_bone_pose_rotation(left)
			model._sample(1.0/30)
			largest=maxf(largest,before.angle_to(model.rig.get_bone_pose_rotation(left)))
		check(largest<=deg_to_rad(3.05) and absf(float(model.reaper_pose.offsets[left]))>deg_to_rad(89.9),"grenades track at XML speed while moving or deployed",largest)
		await check_front_guns(model,gun,[left,right],"walker" if gun==walker else "tower")
		target.position=gun.global_position+Vector2.from_angle(gun.hull_angle+deg_to_rad(140))*140
		var prior:float=model.reaper_pose.offsets[left]
		for i in 20:model._sample(1.0/30)
		check(is_equal_approx(prior,model.reaper_pose.offsets[left]) and absf(float(model.reaper_pose.offsets[right])-prior)>0.1,"out-of-sector side holds while the opposite side tracks")
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		model.viewport.get_texture().get_image().save_png(output_dir.path_join("tracking-"+("walker" if gun==walker else "tower")+".png"))
		gun.attack_target=null
		gun.velocity=Vector2.ZERO
		model._sample(1.0/30)
		check(absf(float(model.reaper_pose.offsets[left])-prior)<=deg_to_rad(3.01),"losing target returns smoothly")

func capture_model(model) -> Image:
	model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return model.viewport.get_texture().get_image()

# Compare real rendered pixels with each barrel individually omitted at the same pose.
func check_front_guns(model,gun,bones:Array,form:String) -> void:
	var heading:float=gun.hull_angle
	for angle in [0,22,-22]:
		gun.hull_angle=Iso.eff_angle()+PI/2+deg_to_rad(angle)
		model.sync_pose()
		var full:Image=await capture_model(model)
		full.save_png(output_dir.path_join("aim-front-%s-%d.png"%[form,angle]))
		for bone:int in bones:
			var original:Vector3=model.rig.get_bone_pose_scale(bone)
			model.rig.set_bone_pose_scale(bone,Vector3.ONE*0.001)
			model.rig.force_update_all_bone_transforms()
			var hidden:Image=await capture_model(model)
			model.rig.set_bone_pose_scale(bone,original)
			model.rig.force_update_all_bone_transforms()
			var pixels:=0
			for y in full.get_height():
				for x in full.get_width():
					var a:=full.get_pixel(x,y)
					var b:=hidden.get_pixel(x,y)
					if maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))>0.08:pixels+=1
			check(pixels>=full.get_width()*full.get_height()*0.0008,"front-facing gun visible %s %d %d"%[form,angle,bone],pixels)
	gun.hull_angle=heading
	model.sync_pose()

func exercise_aa_cover() -> void:
	var origin:=Vector2(2450,2050)
	var walker=actor("R3REAPER","ally",origin)
	var tower=battle._place_building("R3REAPERTURRET","ally",origin+Vector2(0,200),true)
	tower._buildup_play=-1
	var plane=actor("JUMPJET","enemy",origin)
	plane.logistics.air_lift=30.0
	var ground=actor("MTNK","enemy",origin)
	var manual=actor("MTNK","enemy",origin)
	var nearby_building=battle._place_building("GAPOWR","enemy",origin+Vector2(80,0),true)
	for gun in [walker,Emplacement.mount(tower)]:
		gun.hull_angle=0
		gun.turret_angle=0
		plane.position=gun.position+Vector2(170,0)
		ground.position=gun.position+Vector2(140,0)
		manual.position=gun.position+Vector2(-50,110)
		nearby_building.position=gun.position+Vector2(80,0)
		gun.attack_target=plane
		gun.attack_ordered=true
		tower.attack_target=plane
		tower.special.reaper_ordered_target=plane
		BattleRequest.combat_context.unit_talents={}
		check(cover_volley(gun)=={"rocket":plane},"without split talent only the AA rocket fires")
		BattleRequest.combat_context.unit_talents={"R3REAPER":{"reaper_split_fire":0}}
		var expected:={"rocket":plane,"grenade1":ground,"grenade2":manual,"grenade3":ground}
		check(cover_volley(gun)==expected,"rank zero picks the closest unit inside each native sector and skips a closer building")
		gun.special.split_primary=plane
		gun.special.split_enemy=ground
		gun.special.split_side_index=1
		expected.grenade2=ground
		check(cover_volley(gun)==expected,"E reserves its barrel while the other two continue firing and rockets retain air target")
		check(not Soviet.fire(gun),"simultaneous AA and ground cover still respect every magazine")
		Soviet.Split.clear(gun)
		ground.position=gun.position+Vector2(900,0)
		var remaining:=cover_volley(gun)
		check(remaining.get("rocket")==plane and not remaining.values().has(ground),"cached targets leaving the grenade range cannot be fired on")

func cover_volley(gun) -> Dictionary:
	gun.special.soviet_mounts={}
	var start:int=battle.projectiles_root.get_child_count()
	Soviet.fire(gun)
	var targets:Dictionary={}
	for i in range(start,battle.projectiles_root.get_child_count()):
		var shot=battle.projectiles_root.get_child(i)
		targets[shot.splinters.soviet_round]=shot.target
	return targets
