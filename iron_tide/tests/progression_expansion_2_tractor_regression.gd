extends "res://tests/progression_expansion_2_armor_regression.gd"
const Tractor=preload("res://scripts/units/expansion_2_tractor.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		for id in ["V3","DRED","SCHP"]:await ranked(level,id)
	await boundaries();await movement();await retreat()
	for id in ["V3","DRED","SCHP"]:await saved_states(id)
	await classic()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_TRACTOR ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_tractor(level:int) -> void:
	start(MatchRules.EXTENDED);battle.fog=null
	BattleRequest.combat_context.card_ranks[Tractor.CARD]=level
	for id in ["V3","DRED","SCHP"]:BattleRequest.combat_context.loadouts[id]={"active":[Tractor.CARD],"passive":""}

func actor(id:String,side:String,at:Vector2) -> Unit:
	var unit:Unit=super.actor(id,side,at)
	unit.process_mode=Node.PROCESS_MODE_ALWAYS;unit.set_process(false);unit.set_physics_process(false)
	return unit

func deploy(unit) -> void:
	unit.logistics.air_lift=0
	check(unit.set_deployed(true,false),"real helicopter deployment begins")
	unit.logistics.SiegeChopper.tick(unit,unit.logistics.SiegeChopper.duration()+.01)
	check(unit._deployed and not unit.special.has("siege_progress"),"real deployment animation completes before artillery")

func cast_tractor(unit) -> bool:
	return unit.use_ability(UnitSkillLayout.find(unit,Tractor.CARD))

func shoot(unit,target):
	check(normal_shot(unit,target),"real ordinary shot "+unit.unit_id)
	return missiles(unit)[0] if unit.unit_id=="SCHP" and not missiles(unit).is_empty() else unit.special.get("raising_missile_0")

func land(shot) -> void:
	if shot is Projectile:
		for i in 600:
			if shot._detonated:return
			shot._physics_process(1.0/60)
		check(false,"ordinary cannon arc arrives within ten seconds")
	else:impact(shot)

func payload(shot) -> Dictionary:
	return shot.splinters.get(Tractor.PAYLOAD,{}) if shot is Projectile else shot.special.flight.get(Tractor.PAYLOAD,{})

func ranked(level:int,id:String) -> void:
	setup_tractor(level)
	var launcher:=actor(id,"ally",Vector2(650,1250));var target:=structure(Vector2(1300,1250))
	if id=="SCHP":deploy(launcher)
	launcher._cd_timer=1.75;launcher.has_move_order=true;launcher.move_target=Vector2(500,1500)
	check(cast_tractor(launcher),"real W arms "+id+str(level))
	check(launcher.ability_at(UnitSkillLayout.find(launcher,Tractor.CARD)).cd_left==[40,37,34,30][level],"rank cooldown")
	check(launcher._cd_timer==1.75 and launcher.has_move_order and launcher.move_target==Vector2(500,1500),"arming preserves normal reload and player order")
	check(not Tractor.entries(launcher).is_empty(),"armed status visible")
	var shot=shoot(launcher,target)
	if shot==null:await finish();return
	var packet:=payload(shot).duplicate(true)
	check(not packet.is_empty() and not launcher.special[Tractor.KEY].has(Tractor.ARM),"one real projectile consumes pending qualification")
	if packet.is_empty():await finish();return
	var native_damage:float=shot.base_damage if shot is Projectile else shot.special.flight.damage
	check(is_equal_approx(packet.weapon.damage,native_damage*[.35,.45,.55,.7][level]) and packet.radius==[110,123.75,137.5,165][level],"payload scales actual ordinary shell or rocket attack "+id+str(level))
	if id=="DRED":
		launcher._update_burst(float(launcher._active_weapon().burst_delay)+.000001)
		var second=launcher.special.get("raising_missile_1")
		check(second!=null and payload(second).is_empty(),"Dreadnought second native missile remains unmodified")
	var hp:float=target.hp
	land(shot)
	check(target.hp<hp,"original native blast damage retained")
	check(battle.allied_state.get(Tractor.FIELDS,[]).size()==1,"actual ground impact creates exactly one field")
	var field:Dictionary=battle.allied_state[Tractor.FIELDS][0]
	check(field.left==2.0 and field.radius==packet.radius,"field lifetime and radius follow rank")
	var ally:=actor("E1","ally",field.point+Vector2(0,70));var air:=actor("JUMPJET","enemy",field.point+Vector2(0,-70));air.logistics.air_lift=1
	var far:=actor("E1","enemy",field.point+Vector2(0,field.radius+30))
	launcher.hp=0;launcher.bonuses.attack_bonus=10
	hp=target.hp
	Cards.world_tick(battle,1.99)
	check(target.hp==hp and battle.has_node("ExpansionFields"),"field persists independently of launcher and does not blast early")
	if DisplayServer.get_name()!="headless" and level==0:
		battle.camera.position=field.point
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(battle.has_node("ExpansionFields"),"GPU actual traction ring "+id)
	Cards.world_tick(battle,.010001)
	var expected:=Ra2Damage.quantize(CombatMath.full_damage(packet.weapon,target.armor,packet.bonus,null,target.ra2_armor,0,target))
	check(is_equal_approx(hp-target.hp,expected),"single final explosion uses launch snapshot "+id+str(level),[hp-target.hp,expected])
	check(ally.hp==ally.max_hp and air.hp==air.max_hp and far.hp==far.max_hp,"final blast excludes friendly air and outside")
	check(not battle.allied_state.has(Tractor.FIELDS),"expired field removed")
	hp=target.hp;Cards.world_tick(battle,3)
	check(target.hp==hp,"field cannot repeat final explosion")
	await finish()

func boundaries() -> void:
	setup_tractor(3)
	var unit:=actor("V3","ally",Vector2(700,1200));var target:=structure(Vector2(1350,1200))
	check(cast_tractor(unit),"boundary W arms")
	Second.tick(unit,5.99);check(not Tractor.entries(unit).is_empty(),"qualification lives before six seconds")
	Second.tick(unit,.010001);check(Tractor.entries(unit).is_empty(),"qualification expires without refund at six seconds")
	var shot=shoot(unit,target);check(payload(shot).is_empty(),"expired qualification cannot transfer to a rocket")
	AlliedAbilities.consume(shot)
	unit.ability_at(UnitSkillLayout.find(unit,Tractor.CARD)).cd_left=0;ready_launcher(unit)
	check(cast_tractor(unit),"interception case arms")
	shot=shoot(unit,target)
	shot.receive_hit(999999,"flak",{},target)
	check(not AlliedAbilities.alive(shot) and battle.allied_state.get(Tractor.FIELDS,[]).is_empty(),"shot destroyed on rack does not create a pit or refund")
	check(not unit.special[Tractor.KEY].has(Tractor.ARM),"interception cannot restore pending qualification")
	unit.ability_at(UnitSkillLayout.find(unit,Tractor.CARD)).cd_left=0;ready_launcher(unit)
	check(cast_tractor(unit),"airborne interception case arms")
	shot=shoot(unit,target);leave_rack(shot)
	check(shot.special.flight.phase!="rack" and not payload(shot).is_empty(),"real native launch carries payload after leaving rack")
	shot.receive_hit(999999,"flak",{},target)
	check(not AlliedAbilities.alive(shot) and battle.allied_state.get(Tractor.FIELDS,[]).is_empty() and not unit.special[Tractor.KEY].has(Tractor.ARM),"airborne interception neither lands a pit nor restores qualification")
	var chopper:=actor("SCHP","ally",Vector2(500,1500))
	check(not cast_tractor(chopper),"flying helicopter cannot arm artillery payload")
	deploy(chopper);check(cast_tractor(chopper),"deployed helicopter can arm")
	check(Tractor.take(chopper,100,{"expansion_extra":true}).is_empty() and not Tractor.entries(chopper).is_empty(),"extra attack cannot consume qualification")
	check(chopper.set_deployed(false,false) and Tractor.entries(chopper).is_empty(),"folding instantly clears pending payload")
	var other:=actor("SCHP","ally",Vector2(800,1550));deploy(other)
	check(cast_tractor(other),"new helicopter arms before in-flight folding")
	var shell=shoot(other,target)
	check(other.set_deployed(false,false),"fold deployed cannon after actual shot")
	land(shell)
	check(battle.allied_state.get(Tractor.FIELDS,[]).size()==1,"folding after launch does not cancel in-flight payload")
	check(preload("res://scripts/units/auto_w.gd").supported(Tractor.CARD),"explicit automatic tractor policy")
	await finish()

func field_at(point:Vector2) -> Dictionary:
	var launcher:=actor("V3","ally",point+Vector2(-500,-200))
	check(cast_tractor(launcher),"field fixture obtains payload through actual W")
	var packet:=Tractor.take(launcher,200,launcher.bonuses)
	Tractor.landed(battle,point,packet)
	return battle.allied_state[Tractor.FIELDS].back()

func movement() -> void:
	setup_tractor(3)
	var center:=Vector2(1250,1350)
	var field:=field_at(center)
	var unit:=actor("E1","enemy",center+Vector2(100,0))
	unit.has_move_order=true;unit.move_target=center+Vector2(400,0);unit.attack_ordered=true
	var start_at:Vector2=unit.position
	await get_tree().physics_frame
	Tractor.world_tick(battle,.5)
	check(is_equal_approx(start_at.distance_to(unit.position),16.5),"real body moves exactly 0.6 cells per second",[start_at,unit.position])
	check(unit.has_move_order and unit.move_target==center+Vector2(400,0) and unit.attack_ordered,"pull preserves outward player order")
	var overlap:=field_at(center+Vector2(0,30));overlap.left=1.5
	var previous_hp:float=unit.hp
	var per_blast:=Ra2Damage.quantize(CombatMath.full_damage(field.weapon,unit.armor,field.bonus,null,unit.ra2_armor,0,unit))
	Tractor.world_tick(battle,1.5)
	check(is_equal_approx(start_at.distance_to(unit.position),66),"overlapping fields do not double speed and full duration caps at 1.2 cells",[start_at,unit.position])
	check(not battle.allied_state.has(Tractor.FIELDS) and is_equal_approx(previous_hp-unit.hp,2*per_blast),"overlapping pits both finish independently",[previous_hp-unit.hp,2*per_blast])
	field=field_at(center);unit.position=center+Vector2(3,0)
	Tractor.world_tick(battle,.5);check(unit.position.is_equal_approx(center),"pull stops at center without oscillation")
	battle.allied_state.erase(Tractor.FIELDS)
	# Native solid wall body and pathing, no teleport through the wall.
	var wall=battle._place_building("GAWALL","enemy",center+Vector2(35,150),true)
	wall.process_mode=Node.PROCESS_MODE_ALWAYS;wall.set_process(false);wall.set_physics_process(false)
	battle._refresh_pathing();field_at(center+Vector2(0,150));unit.position=center+Vector2(70,150)
	await get_tree().physics_frame
	var wall_hp:float=unit.hp
	Tractor.world_tick(battle,2)
	check(unit.position.x>center.x+35,"traction does not pull through native wall")
	check(unit.hp<wall_hp,"wall blocks displacement but does not grant immunity to in-radius terminal blast")
	# A shore is forbidden even when no physics collider covers it.
	var water:=Rect2(center+Vector2(-50,270),Vector2(80,100))
	battle.water_rects=[water];battle.path_service.water_rects=[water];battle._refresh_pathing()
	field_at(center+Vector2(0,320));unit.position=center+Vector2(60,320)
	Tractor.world_tick(battle,2)
	check(not battle.in_water_world(unit.position) and unit.position.x>=water.end.x,"traction cannot drag land infantry across shore")
	# Deployment and explicit displacement immunity resist movement but not the blast.
	battle.water_rects.clear();battle.path_service.water_rects.clear();battle._refresh_pathing()
	field_at(center);unit.position=center+Vector2(90,0);unit.special.displacement_immune=true
	var hp:float=unit.hp;Tractor.world_tick(battle,2)
	check(unit.position==center+Vector2(90,0) and unit.hp<hp,"displacement immunity prevents pull but keeps final damage")
	unit.special.erase("displacement_immune");unit.set_deployed(true,false)
	field_at(center);hp=unit.hp;Tractor.world_tick(battle,2)
	check(unit.position==center+Vector2(90,0) and unit.hp<hp,"deployed infantry anchored but final blast still applies")
	await finish()

func retreat() -> void:
	setup_tractor(3)
	var center:=Vector2(1200,1500)
	field_at(center)
	var unit:=actor("E1","enemy",center+Vector2(150,0))
	unit.set_fire_stance("none");unit.order_move(center+Vector2(600,0))
	await get_tree().physics_frame
	var hp:float=unit.hp
	for i in 30:
		unit._physics_process(1.0/15)
		Tractor.world_tick(battle,1.0/15)
	check(unit.position.distance_to(center)>165 and unit.hp==hp,"real normal outward movement escapes pit and avoids terminal blast",unit.position)
	await finish()

func saved_states(id:String) -> void:
	setup_tractor(2)
	var launcher:=actor(id,"ally",Vector2(700,1200));var target:=structure(Vector2(1350,1200))
	if id=="SCHP":deploy(launcher)
	check(cast_tractor(launcher),"save pending W")
	Second.tick(launcher,2.5)
	var codec=BattleSaves.Snapshot.new();var snap=codec.capture(battle)
	codec.restore(battle,snap)
	launcher=battle.units.filter(func(u):return u.unit_id==id)[0]
	check(is_equal_approx(launcher.special[Tractor.KEY][Tractor.ARM],3.5),"pending qualification remaining time survives restore")
	target=battle.buildings.filter(func(b):return b.side=="enemy" and b.position==Vector2(1350,1200))[0]
	var shot=shoot(launcher,target)
	var path=output_dir.path_join("tractor-flight-"+id+".bin")
	FileAccess.open(path,FileAccess.WRITE).store_var(codec.capture(battle))
	codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var())
	shot=battle.projectiles_root.get_children().filter(func(p):return p is Projectile)[0] if id=="SCHP" else battle.units.filter(func(u):return u.unit_id==("DMISL" if id=="DRED" else "V3ROCKET"))[0]
	check(not payload(shot).is_empty(),"armed real rocket survives binary flight restore")
	land(shot);Cards.world_tick(battle,.75)
	var field:Dictionary=battle.allied_state[Tractor.FIELDS][0]
	check(is_equal_approx(field.left,1.25),"field countdown before save")
	FileAccess.open(path,FileAccess.WRITE).store_var(codec.capture(battle))
	codec.restore(battle,FileAccess.open(path,FileAccess.READ).get_var())
	field=battle.allied_state[Tractor.FIELDS][0]
	check(is_equal_approx(field.left,1.25) and codec.error.is_empty(),"field owner payload and remaining time restore without reset")
	Cards.world_tick(battle,1.25)
	check(not battle.allied_state.has(Tractor.FIELDS),"restored pit expires once")
	await finish()

func classic() -> void:
	start(MatchRules.RA2)
	var unit:=actor("V3","ally",Vector2(700,1200))
	var ab:=Ability.new();ab.setup(GameData.get_skill(Tractor.CARD),3);unit.skills.append(ab)
	check(not unit.use_ability(unit.skills.size()-1),"forced expansion W rejected in classic mode")
	await finish()
