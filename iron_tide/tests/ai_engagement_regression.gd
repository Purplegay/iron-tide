extends "res://tests/base_recovery_regression.gd"
const Engagement = preload("res://scripts/units/ai_engagement.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	GM.god_mode=false
	GM.one_shot_kill=false
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for advance in [false,true]: await exercise_air_contact(mode,advance)
		await exercise_air_retaliation(mode)
		await exercise_ground_and_dispatch(mode)
		for id in ["E1","HTNK","APOC","JUMPJET","SCHP"]: await exercise_mobile_roster(mode,id)
		await exercise_saved_pursuit(mode)
	await exercise_gunship()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("AI_ENGAGEMENT checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func arena(mode: String) -> void:
	start(mode)
	battle.paused=false
	get_tree().paused=false
	if battle.fog!=null:battle.fog.free();battle.fog=null

func actor(id: String,side: String,point: Vector2) -> Unit:
	var unit:Unit=battle.spawn_unit(id,side,point)
	unit.process_mode=Node.PROCESS_MODE_ALWAYS
	unit.set_process(false);unit.set_physics_process(false)
	unit.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	unit.order_stop()
	unit.logistics.air_lift=1.0
	return unit

func step(unit: Unit,ticks: int) -> void:
	for tick in ticks:
		await get_tree().physics_frame
		unit._physics_process(1.0/15.0)

func shots(unit: Unit) -> int:
	return battle.projectiles_root.get_children().filter(func(p):return p is Projectile and p.shooter()==unit).size()

func exercise_air_contact(mode: String,advance: bool) -> void:
	arena(mode)
	var origin:=Vector2(1000,1000)
	var bomber:=actor("ZEP","enemy",origin)
	var target:=actor("FV","ally",origin+Vector2(330,0))
	var goal:=origin+Vector2(0,600)
	if advance:bomber.order_move(goal,true)
	bomber._refresh_target()
	check(bomber.attack_target==target,prefix+"Kirov acquires visible target")
	check(Engagement.busy(bomber) and not battle.skirmish_ai.wave_candidates(true).has(bomber),prefix+"closing Kirov retains combat assignment")
	await step(bomber,450)
	check(bomber.position.x>origin.x+200 and shots(bomber)>0,prefix+"automatic Kirov closes and releases real bombs "+str(advance),{"position":bomber.position,"shots":shots(bomber)})
	if advance:
		check(bomber.has_move_order and bomber.attack_move and bomber.move_target==goal,prefix+"engagement preserves attack-move destination")
		target.hp=0
		bomber._refresh_target()
		await step(bomber,60)
		check(bomber.position.y>origin.y+10 and bomber.move_target==goal,prefix+"target death resumes attack-move")
	await finish()

func exercise_air_retaliation(mode: String) -> void:
	arena(mode)
	var origin:=Vector2(1000,1000)
	var bomber:=actor("ZEP","enemy",origin)
	var target:=actor("FV","ally",origin+Vector2(330,0))
	var goal:=origin+Vector2(0,600)
	bomber.order_move(goal)
	bomber.receive_hit(1,"bullet",{},target)
	bomber._refresh_target()
	check(bomber._can_pursue_attacker(target,bomber.attack_range),prefix+"moving AI air can retaliate within sight")
	await step(bomber,75)
	check(bomber.position.x>origin.x+50 and absf(bomber.position.y-origin.y)<5,prefix+"hit diverts aircraft toward attacker")
	check(bomber.has_move_order and bomber.move_target==goal and not bomber.attack_ordered,prefix+"diversion leaves original route intact")
	bomber._return_timer=0
	bomber._refresh_target()
	await step(bomber,75)
	check(bomber.position.y>origin.y+30 and bomber.move_target==goal,prefix+"expired hit resumes ordinary move")
	bomber.receive_hit(1,"bullet",{},target)
	target.position=origin+Vector2(1800,0)
	check(not bomber._can_pursue_attacker(target,bomber.attack_range),prefix+"distant attacker cannot extend pursuit")
	target.position=origin+Vector2(330,0)
	bomber.hold_position=true
	check(not bomber._can_pursue_attacker(target,bomber.attack_range) and not Engagement.air_pursuit(bomber,target),prefix+"hold position prevents AI pursuit")
	bomber.hold_position=false;bomber.fire_stance="none"
	check(not bomber._can_pursue_attacker(target,bomber.attack_range),prefix+"hold fire prevents pursuit")
	bomber.fire_stance="free"
	target.hp=0
	check(not bomber._can_pursue_attacker(target,bomber.attack_range),prefix+"dead attacker cannot be pursued")
	target.hp=target.max_hp;target.side="enemy"
	check(not bomber._can_pursue_attacker(target,bomber.attack_range),prefix+"friendly attacker cannot be pursued")
	target.side="ally"
	var air:=actor("ZEP","ally",origin+Vector2(330,0))
	bomber.special.retaliation_target=air
	check(not bomber._can_pursue_attacker(air,bomber.attack_range),prefix+"Kirov never pursues an unattackable air target")
	var player:=actor("ZEP","ally",origin+Vector2(0,200))
	player.order_move(goal)
	player.receive_hit(1,"bullet",{},bomber)
	check(not player._can_pursue_attacker(bomber,player.attack_range) and not Engagement.air_pursuit(player,bomber),prefix+"player move order remains protected")
	await finish()

func exercise_ground_and_dispatch(mode: String) -> void:
	arena(mode)
	var origin:=Vector2(1000,1000)
	var tank:=actor("MTNK","enemy",origin)
	var target:=actor("FV","ally",origin+Vector2(200,0))
	tank._refresh_target()
	target.position=origin+Vector2(330,0)
	check(tank.attack_target==target and not Engagement.busy(tank),prefix+"distant passive target is not active combat")
	check(battle.skirmish_ai.wave_candidates(true).has(tank),prefix+"passive target does not starve wave dispatch")
	tank.receive_hit(1,"bullet",{},target)
	tank._refresh_target()
	check(tank._can_pursue_attacker(target,tank.attack_range) and Engagement.busy(tank),prefix+"idle AI tank retaliates farther within sight")
	await step(tank,60)
	check(tank.position.x>origin.x+50 and shots(tank)>0,prefix+"AI tank closes and fires",{"position":tank.position,"shots":shots(tank)})
	# Repeated hits must retain the initial origin, not move the chase boundary.
	var anchor:Vector2=tank.special.retaliation_origin
	tank.position=origin+Vector2(100,0)
	tank.receive_hit(1,"bullet",{},target)
	target.position=anchor+Vector2(maxf(tank.sight,tank.attack_range+110)+120,0)
	check(tank.special.retaliation_origin==anchor and not tank._can_pursue_attacker(target,tank.attack_range),prefix+"repeated hits retain fixed pursuit boundary")
	tank.order_move(origin+Vector2(0,500))
	tank.position=origin
	target.position=origin+Vector2(330,0)
	tank.receive_hit(1,"bullet",{},target)
	tank._refresh_target()
	await step(tank,30)
	check(tank.position.x>origin.x+10 and tank.special.has(Engagement.RESUME),prefix+"moving ground AI diverts and retains return destination")
	tank._return_timer=0
	tank._process_combat(1.0/15.0)
	check(tank.has_move_order and tank.move_target==origin+Vector2(0,500) and not tank.special.has(Engagement.RESUME),prefix+"ground pursuit expiry restores original route")
	await finish()

func exercise_mobile_roster(mode: String,id: String) -> void:
	arena(mode)
	var origin:=Vector2(1000,1000)
	var unit:=actor(id,"enemy",origin)
	var target:=actor("FV","ally",origin+Vector2(unit.attack_range+35,0))
	var goal:=origin+Vector2(0,600)
	unit.order_move(goal,true)
	unit.receive_hit(1,"bullet",{},target)
	unit._refresh_target()
	check(unit.attack_target==target and unit._can_pursue_attacker(target,unit.attack_range),prefix+id+" moving AI acquires attacker")
	await step(unit,60)
	check(unit.position.x>origin.x+10 and (shots(unit)>0 or target.hp<target.max_hp),prefix+id+" closes and shoots",{"position":unit.position,"shots":shots(unit),"target_hp":target.hp})
	target.hp=0
	unit._process_combat(1.0/15.0)
	check(unit.has_move_order and unit.move_target==goal and unit.attack_move,prefix+id+" target death preserves original advance")
	unit.order_stop()
	check(not unit.special.has(Engagement.RESUME) and not unit.has_move_order,prefix+id+" new stop discards diversion")
	await finish()

func exercise_saved_pursuit(mode: String) -> void:
	arena(mode)
	var origin:=Vector2(1000,1000)
	var tank:=actor("MTNK","enemy",origin)
	var target:=actor("FV","ally",origin+Vector2(330,0))
	var goal:=origin+Vector2(0,500)
	tank.order_move(goal,true)
	tank.receive_hit(1,"bullet",{},target)
	tank._refresh_target()
	await step(tank,15)
	check(tank.special.has(Engagement.RESUME),prefix+"save starts during active diversion")
	var saved:Dictionary=BattleSaves.save_slot(battle,"slot3")
	check(saved.ok,prefix+"pursuit state serializes through real save",saved)
	await finish()
	if not saved.ok:return
	var ready:Dictionary=BattleSaves.prepare_load("slot3")
	check(ready.ok,prefix+"pursuit save validates before load")
	if not ready.ok:return
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false;get_tree().paused=false
	var restored:Unit=null
	for unit in battle.units:
		if unit.side=="enemy" and unit.unit_id=="MTNK":restored=unit;break
	check(restored!=null and restored.special.has(Engagement.RESUME),prefix+"load retains pending original route")
	if restored!=null:
		restored._return_timer=0
		restored._process_combat(1.0/15.0)
		check(restored.has_move_order and restored.attack_move and restored.move_target==goal and not restored.special.has(Engagement.RESUME),prefix+"loaded diversion resumes original advance on expiry")
	await finish()

func exercise_gunship() -> void:
	arena(MatchRules.EXTENDED)
	var unit:=actor("R3HARBINGER","enemy",Vector2(1000,1000))
	var target:=actor("FV","ally",Vector2(1150,1000))
	var goal:=Vector2(1000,2000)
	unit.order_move(goal)
	unit.receive_hit(1,"bullet",{},target)
	unit._refresh_target()
	unit._process_combat(1.0/15.0)
	check(unit.special.get("ra3_flight_mode")=="attack" and unit.move_target==goal,prefix+"gunship hit diverts orbit without replacing move destination")
	unit._return_timer=0
	unit._process_combat(1.0/15.0)
	check(unit.special.get("ra3_flight_mode")=="move",prefix+"gunship hit expiry resumes route")
	await finish()
