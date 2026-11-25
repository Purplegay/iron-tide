extends "res://tests/allied_abilities_regression.gd"

func clear_shots() -> void:
	for shot in battle.projectiles_root.get_children():shot.free()

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group):node.free()
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var tank=actor("R3MIRAGE","ally",Vector2(1600,1600))
	var target=actor("R3FUTURE","enemy",Vector2(1440,1600))
	target.max_hp=100000;target.hp=100000
	await get_tree().physics_frame
	check(tank._weapon_uses_hull(),"RA3 Mirage fixed hardpoint uses hull without RA2 tag")
	for rank in [0,3]:
		tank._grant_veteran(rank,false)
		for angle in [180.0,90.0,10.1,10.0,9.9,-10.1,-9.9]:
			target.position=tank.position+Vector2.RIGHT*160
			tank.hull_angle=deg_to_rad(angle);tank.turret_angle=0.0
			tank.attack_target=target;tank.attack_ordered=true;tank._cd_timer=0
			var expected:bool=absf(angle)<=10
			var fired:bool=tank._try_fire_ready()
			check(fired==expected,"rank%d actual firing gate at %.1f degrees"%[rank,angle])
			check(battle.projectiles_root.get_child_count()==(1 if expected else 0),"rank%d no premature beam payload at %.1f"%[rank,angle])
			clear_shots()
	for ordered in [true,false]:
		for hz in [15,60,120]:
			tank.order_stop();tank.hull_angle=0;tank.turret_angle=0;tank._cd_timer=0;tank._think_timer=0
			tank.fire_stance="defend";tank.attack_target=target if ordered else null;tank.attack_ordered=ordered
			target.position=tank.position+Vector2.LEFT*160
			var origin:Vector2=tank.position
			var elapsed:=0.0;var premature:=false;var largest_step:=0.0
			for tick in hz*2:
				var before:float=tank.hull_angle
				tank._physics_process(1.0/hz);elapsed+=1.0/hz
				largest_step=maxf(largest_step,absf(angle_difference(before,tank.hull_angle)))
				if battle.projectiles_root.get_child_count()>0:
					premature=absf(angle_difference(tank.hull_angle,PI))>deg_to_rad(10.0)+0.000001
					break
			var label:="%s %dHz"%["ordered" if ordered else "automatic",hz]
			check(battle.projectiles_root.get_child_count()==1 and not premature,label+" turns hull before firing at rear target")
			check(elapsed>=170.0/180.0 and elapsed<=170.0/180.0+1.0/hz+0.001,label+" native turn-rate adapter determines first shot",elapsed)
			check(largest_step<=deg_to_rad(180.0)/hz+0.000001,label+" no instant hull snap")
			check(tank.position.is_equal_approx(origin),label+" pivots in place")
			clear_shots()
	# Moving with the nose pointing away must not aim with a virtual turret.
	target.position=tank.position+Vector2.LEFT*160
	tank.hull_angle=0;tank._cd_timer=0;tank.order_move(tank.position+Vector2.RIGHT*300)
	tank.attack_target=target;tank._physics_process(1.0/60.0)
	check(battle.projectiles_root.get_child_count()==0,"move order cannot fire backward through a virtual turret")
	tank.order_stop();tank.attack_target=target;tank.attack_ordered=true;tank.hull_angle=PI/2;tank._cd_timer=0
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	for unit in battle.units:
		unit.process_mode=Node.PROCESS_MODE_ALWAYS;unit.set_process(false);unit.set_physics_process(false)
		if unit.unit_id=="R3MIRAGE":tank=unit
	await get_tree().physics_frame
	tank._physics_process(1.0/60.0)
	check(battle.projectiles_root.get_child_count()==0 and tank.hull_angle>PI/2 and tank.hull_angle<PI,"mid-turn save resumes hull rotation without firing early")
	var other=actor("MTNK","ally",Vector2(2000,2000))
	var enemy=actor("MTNK","enemy",Vector2(2160,2000))
	other.hull_angle=PI;other.turret_angle=0
	check(not other._weapon_uses_hull() and other._weapon_aligned(enemy),"RA2 turret tank keeps independent turret aiming")
	other.turret_angle=deg_to_rad(5)
	check(not other._weapon_aligned(enemy),"RA2 existing two-degree turret tolerance is unchanged")
	screen.free();await get_tree().process_frame
