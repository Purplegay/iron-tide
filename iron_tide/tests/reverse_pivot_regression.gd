extends "res://tests/electric_cards_regression.gd"
const Talents=preload("res://scripts/units/yr_unit_talents.gd")

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	if mode==MatchRules.RA2:
		var stock=make("MTNK","ally",Vector2(1300,1300))
		check(not Talents.reverse_ready(stock),"classic does not gain reverse talent")
		clear_units();await finish();return
	BattleRequest.combat_context.get_or_add("unit_talents",{}).MTNK={Talents.REVERSE:3}
	var origin:=Vector2(1400,1400)
	for direction in 8:
		var tank=make("MTNK","ally",origin)
		tank.hull_angle=0;tank.turret_angle=0;tank.hp=tank.max_hp*0.5
		var route:=Vector2.from_angle(direction*PI/4)
		var destination:Vector2=origin+route*90
		check(Talents.start_reverse(tank,destination),"accepts direction "+str(direction))
		var observed_turn:=false
		var correct_motion:=true
		var bounded_turn:=true
		var turn_heals:=false
		for frame in 600:
			if not tank.special.has(Talents.REVERSE):break
			var before:Vector2=tank.position
			var angle:float=tank.hull_angle
			tank._physics_process(1.0/60.0)
			bounded_turn=bounded_turn and absf(angle_difference(angle,tank.hull_angle))<=deg_to_rad(float(tank._mv("rot",0)))/60+0.0001
			var moved:Vector2=tank.position-before
			if moved.length()>0.001:
				correct_motion=correct_motion and moved.normalized().dot(-Vector2.from_angle(tank.hull_angle))>0.999 and moved.normalized().dot(route)>0.999
			elif absf(angle_difference(tank.hull_angle,(-route).angle()))>0.001:
				observed_turn=true
				turn_heals=turn_heals or tank.special.has("reverse_heal_left")
		check(tank.position.distance_to(destination)<0.1 and not tank.special.has(Talents.REVERSE),"reaches requested point "+str(direction))
		check(correct_motion and bounded_turn,"native turn rate and rearward-only translation "+str(direction))
		check(not turn_heals and (observed_turn or direction==4),"pivot grants no heal "+str(direction))
		clear_units()
	var tank=make("MTNK","ally",origin);tank.hull_angle=0
	check(is_equal_approx(Talents.reverse_end(tank,origin+Vector2(500,500)).distance_to(origin),3*Talents.CELL),"diagonal endpoint clamps to three cells")
	check(not Talents.start_reverse(tank,origin) and not Talents.start_reverse(tank,Vector2.INF),"zero and nonfinite targets rejected")
	check(Talents.start_reverse(tank,origin+Vector2(90,0)),"front order accepted")
	tank._physics_process(0.01);tank.order_stop()
	check(not tank.special.has(Talents.REVERSE) and not tank.special.has("reverse_heal_left"),"stop during pivot cancels without healing")
	check(not Talents.start_reverse(tank,origin+Vector2(90,0)),"stop preserves cooldown")
	for frame in 480:tank._physics_process(1.0/60)
	check(Talents.start_reverse(tank,origin+Vector2(0,90)),"reverse ready after eight seconds")
	for frame in 600:
		if not tank.special.has(Talents.REVERSE):break
		tank._physics_process(1.0/60)
	check(tank.position.distance_to(origin+Vector2(0,90))<0.1,"available reverse reaches new destination")
	for frame in 480:tank._physics_process(1.0/60)
	tank.position=origin;tank.hull_angle=0
	var wall=battle._place_building("NAWALL","enemy",origin+Vector2(70,0),true)
	battle._refresh_pathing()
	check(not Talents.start_reverse(tank,origin+Vector2(140,0)),"front route cannot cross wall")
	battle.buildings.erase(wall);wall.free();battle._refresh_pathing()
	clear_units()
	tank=make("MTNK","ally",origin);tank.hull_angle=0
	var enemy=make("HTNK","enemy",origin+Vector2(0,-90))
	tank.attack_target=enemy;tank.attack_ordered=true;tank.turret_angle=-PI/2
	Talents.start_reverse(tank,origin+Vector2(90,0));tank._physics_process(0.02)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var instance:int=codec.ids[tank]
	check(codec.error.is_empty(),"pivot save captured")
	codec.restore(battle,snapshot);battle.paused=false;get_tree().paused=false
	tank=codec.objects[instance]
	tank.process_mode=Node.PROCESS_MODE_ALWAYS
	tank.set_process(false);tank.set_physics_process(false)
	var fired:=false
	for frame in 600:
		if not tank.special.has(Talents.REVERSE):break
		tank._physics_process(1.0/60)
		fired=fired or tank._cd_timer>0
	check(tank.position.distance_to(origin+Vector2(90,0))<0.1,"saved pivot resumes and finishes requested route")
	check(fired and absf(angle_difference(tank.hull_angle,tank.turret_angle))>0.3,"turret keeps firing independently of reversing hull")
	clear_units()
	await finish()
