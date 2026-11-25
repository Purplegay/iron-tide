extends "res://tests/allied_abilities_regression.gd"

const Flight = preload("res://scripts/units/ra3_gunship_flight.gd")

func fly(unit, seconds: float) -> Dictionary:
	var minimum:=INF;var maximum:=0.0;var turn:=0.0;var aligned:=true;var bounded:=true
	var trace: Array=[];var inside:=true
	for i in int(seconds*60):
		var before: float=unit.hull_angle
		unit._physics_process(1.0/60.0)
		inside=inside and Rect2(Vector2.ZERO,Vector2.ONE*battle.map_size).has_point(unit.position)
		minimum=minf(minimum,unit.velocity.length());maximum=maxf(maximum,unit.velocity.length())
		turn+=angle_difference(before,unit.hull_angle)
		bounded=bounded and absf(angle_difference(before,unit.hull_angle))<=unit.flight.turn_rate/60.0+0.0001
		if unit.velocity.length()>1.0:aligned=aligned and absf(angle_difference(unit.velocity.angle(),unit.hull_angle))<0.01
		for shot in battle.projectiles_root.get_children():
			if not shot.is_queued_for_deletion():shot._physics_process(1.0/60.0)
			if shot.is_queued_for_deletion():shot.free()
		if i%60==0:trace.append([unit.position.x,unit.position.y,unit.velocity.length()])
	return {"minimum":minimum,"maximum":maximum,"turn":turn,"aligned":aligned,"bounded":bounded,"inside":inside,"trace":trace}

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for n in battle.units+battle.buildings:n.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var unit=actor("R3HARBINGER","ally",Vector2(1800,1800))
	unit.logistics.air_lift=1.0;unit.fire_stance="none";unit._think_timer=100000.0
	await get_tree().physics_frame
	fly(unit,2.0)
	var idle:=fly(unit,40.0)
	check(idle.minimum>140 and idle.maximum<145,"idle maintains native 80 percent circling speed",idle)
	check(absf(idle.turn)>TAU and idle.aligned and idle.bounded,"idle completes full circles with bounded tangent flight")
	check(absf(unit.position.distance_to(unit.special[Flight.CENTER])-435.0)<20.0,"native 290 radius consumes shared 1.5 world scale")
	var target=actor("MTNK","enemy",Vector2(2200,2000));target.hp=100000;target.max_hp=100000
	unit.fire_stance="defend"
	battle.select_unit(unit,false);battle.force_attack(target);unit._think_timer=100000.0
	fly(unit,15)
	var attack:=fly(unit,35)
	check(attack.minimum>140 and absf(attack.turn)>TAU and attack.bounded,"attack circles continuously instead of braking to hover")
	check(target.hp<100000 and unit.position.distance_to(target.position)<unit.attack_range,"circling preserves real cannon range and damage")
	check(Ra3Expansion.use(unit,Vector2.INF),"switch to autocannon while circling")
	var hp_before: float=target.hp
	var gun:=fly(unit,12)
	check(gun.minimum>140 and gun.aligned and target.hp<hp_before,"weapon switch keeps flying and autocannon fires on orbit")
	target.hp=0.0
	var dead:=fly(unit,3)
	check(unit.special[Flight.MODE]=="idle" and dead.minimum>140,"dead target returns gunship to holding circle without a stop")
	var stop_speed: float=unit.velocity.length()
	unit.order_stop();unit.fire_stance="none";unit._think_timer=100000.0
	check(is_equal_approx(unit.velocity.length(),stop_speed),"stop command preserves airborne velocity")
	var stopped:=fly(unit,5)
	check(stopped.minimum>140 and unit.attack_target==null,"stop cancels attack while continuing local orbit")
	unit.order_move(Vector2(1100,2800));unit.fire_stance="none"
	var move:=fly(unit,35)
	check(not unit.has_move_order and unit.position.distance_to(Vector2(1100,2800))<460,"move joins holding circle around requested destination")
	check(move.minimum>140 and move.maximum<=180.01 and move.bounded and move.aligned,"move turns continuously without hover or sideways sliding")
	var center: Vector2=unit.special[Flight.CENTER]
	var position_: Vector2=unit.position
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var save=codec.capture(battle);codec.restore(battle,save)
	unit=battle.units.filter(func(u):return u.unit_id=="R3HARBINGER")[0]
	activate(unit,false)
	check((unit.special[Flight.CENTER] as Vector2).is_equal_approx(center) and unit.position.is_equal_approx(position_),"save restore retains orbit center and actual position")
	var restored:=fly(unit,3)
	check(restored.minimum>140 and restored.bounded,"loaded gunship resumes continuous flight")
	unit.order_move(Vector2(20,20));unit.fire_stance="none"
	var edge:=fly(unit,60)
	check(edge.inside and not unit.has_move_order and edge.minimum>140,"edge destination fits holding circle within map without stopping")
	var report:=FileAccess.open(output_dir.path_join("flight-traces.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"idle":idle,"attack":attack,"gun":gun,"move":move,"edge":edge},"  "));report.close()
	screen.free();await get_tree().process_frame
