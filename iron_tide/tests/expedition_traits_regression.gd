extends "res://tests/expedition_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	check_stacks()
	await check_rewards()
	await check_effects()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION TRAITS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_stacks() -> void:
	new_ready("美国",16)
	var next:Dictionary=Expedition.state.duplicate(true)
	check(Army.counts(next).is_empty(),"starting units do not generate trait stacks")
	check(Army.trait_audience("infantry",next).contains(Army.training_name("E1")),"buff audience names owned infantry")
	check(Army.trait_audience("energy",next).split("\n")[1].contains("暂无"),"unowned energy beneficiaries clearly explained")
	next.emblems={"E1":"energy"}
	check("energy" not in Army.tags("E1",next),"manual tags cannot change buff applicability")
	next.licenses.append("SREF")
	check(Army.trait_audience("energy",next).split("\n")[1].contains(Army.training_name("SREF")),"newly licensed matching unit automatically appears as beneficiary")
	for key:String in Army.TRAITS:
		for count in 10:
			check(Army.trait_level(key,count)==([0,1,2,3,3,3,4,4,4,5][count]),"threshold "+key+":"+str(count))
		for draw in 12:Expedition.grant(next,{"kind":"trait_buff","id":key})
		check(next.trait_buffs[key]==9,"repeated acquisition capped at nine "+key)
	check(next.buffs==Expedition.state.buffs,"traits do not consume equipment slots")
	check(Expedition.commit(next) and Expedition.load_run() and Expedition.state.trait_buffs==next.trait_buffs,"stacks survive disk reload")
	var invalid:Dictionary=next.duplicate(true);invalid.trait_buffs.infantry=10
	check(not Expedition.valid(invalid),"invalid stack count rejected")
	invalid.trait_buffs.infantry=1.5
	check(not Expedition.valid(invalid),"fractional stack rejected")
	check(Market.trait_pool(next).is_empty(),"max stacks removed from offer pool")
	next.trait_buffs={};next.tracked_traits=["infantry","vehicle"]
	for count in 9:
		next.trait_buffs.infantry=count
		var offers:=Market.bonus_rewards(next)
		check(offers==Market.bonus_rewards(next),"deterministic bonus draw "+str(count))
		check(offers[0].kind=="trait_buff" and offers[0].id=="infantry","tracked direction stays obtainable "+str(count))
		var identities:Array=[]
		for item:Dictionary in offers:identities.append(str(item.kind)+":"+str(item.id))
		check(identities.size()==3 and identities[0]!=identities[1] and identities[0]!=identities[2] and identities[1]!=identities[2],"three distinct choices "+str(count))
	check(Army.counts(next).infantry==8,"active unit count does not change acquired stacks")

func check_rewards() -> void:
	new_ready("美国")
	check(Expedition.launch(0),"reward flow real launch")
	if not instantiate_battle():await finish();return
	satisfy_objective(screen.expedition_runtime.tasks)
	check(Expedition.state.phase=="reward" and Expedition.state.reward_round=="main","victory starts original reward")
	var token:=Expedition.reward_token()
	var original:Dictionary=Expedition.state.duplicate(true)
	check(Expedition.load_run() and Expedition.state==original,"original reward persisted without reroll")
	var replacement:String="" if Expedition.state.buffs.is_empty() else str(Expedition.state.buffs.keys()[0])
	check(Expedition.choose(0,replacement,token),"claim original reward")
	check(Expedition.state.phase=="reward" and Expedition.state.reward_round=="buff","extra buff round remains")
	var bonus:Dictionary=Expedition.state.duplicate(true)
	check(not Expedition.choose(0,replacement,token) and Expedition.state==bonus,"stale double click cannot consume bonus")
	check(not Expedition.launch(0),"cannot skip pending bonus reward")
	check(Expedition.load_run() and Expedition.state==bonus,"bonus choices and round survive reload")
	var selected:Dictionary=bonus.offers[0]
	check(selected.kind=="trait_buff","extra round provides tracked trait")
	token=Expedition.reward_token()
	check(Expedition.choose(0,replacement,token) and Expedition.state.phase=="event","second choice opens post-battle event")
	check(Expedition.state.trait_buffs[selected.id]==1,"bonus grants one stack")
	check(not Expedition.choose(0,replacement,token),"claimed bonus cannot be repeated")
	check(Expedition.resolve_event(0,Expedition.event_token()) and Expedition.state.phase=="ready","post-battle event opens camp")
	await finish()
	var next:Dictionary=Expedition.state.duplicate(true)
	next.trait_buffs[selected.id]=8
	next.shop=[{"kind":"trait_buff","id":selected.id,"price":80,"sold":false,"locked":false}]
	next.supplies=500
	check(Expedition.commit(next) and Expedition.buy(0),"shop can buy ninth trait stack")
	check(Expedition.state.trait_buffs[selected.id]==9 and Expedition.state.supplies==420,"ninth stack charges once")
	check(not Expedition.buy(0),"shop duplicate purchase rejected")
	next=Expedition.state.duplicate(true);next.shop[0].sold=false;Expedition.commit(next)
	check(not Expedition.buy(0) and Expedition.state.supplies==420,"stale full-stack shop item charges nothing")

func set_stacks(key:String,count:int) -> void:
	Rules.context().trait_buffs={key:count}
	Rules.context().traits=Army.levels({"trait_buffs":{key:count}})
	Rules.context().buffs={}

func actor(id:String):
	var unit=battle.spawn_unit(id,"ally",battle.player_start()+Vector2(350,350))
	unit.hp=unit.max_hp*0.25
	unit.special={}
	unit.velocity=Vector2.ZERO
	unit.attack_target=null
	return unit

func hit_target():
	var target=battle.spawn_unit("MTNK","enemy",battle.player_start()+Vector2(700,350))
	target.special={};target.hp=target.max_hp
	return target

func check_effects() -> void:
	new_ready("美国",16)
	var next:Dictionary=Expedition.state.duplicate(true)
	for key:String in Army.TRAITS:next.trait_buffs[key]=9
	Expedition.commit(next);Expedition.launch(0)
	if not instantiate_battle():await finish();return
	var any_unit=battle.spawn_unit("E1","ally",battle.player_start()+Vector2(320,350))
	var statuses:Array=[];Rules.append_status(any_unit,statuses)
	var status_found:=false
	for status:Dictionary in statuses:
		if status.id=="expedition_trait_infantry":status_found=status.stacks==9 and status.limit==9 and "6 层追加" in status.text and "9 层追加" in status.text
	check(status_found,"HUD displays nine stacks and cumulative milestones")
	for count in [5,6,8,9]:
		for key:String in Army.TRAITS:
			set_stacks(key,count)
			var id:String={"infantry":"E1","vehicle":"MTNK","air":"ORCA","naval":"DEST","fortify":"GGI","mobile":"MTNK","support":"E1","energy":"SREF","artillery":"HTNK","special":"GHOST"}[key]
			var unit=actor(id)
			var target=hit_target()
			var before:float=unit.hp
			var now:float=Rules.clock(unit)
			var prefix:=key+" stack "+str(count)
			match key:
				"infantry","support":
					Rules.tick_unit(unit,1,true)
					check(is_equal_approx(unit.hp-before,unit.max_hp*(0.02 if count>=6 else 0.01 if key=="support" else 0)),prefix+" medical threshold")
					Rules.defend(unit,1)
					var expected:=0.15 if key=="infantry" else 0.10
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(expected if count>=9 else 0)),prefix+" defensive threshold")
				"vehicle","fortify":
					unit.special.expedition_first_shield=true
					Rules.tick_unit(unit,5,false)
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.10 if count>=6 else 0)),prefix+" stationary shield")
					unit.special.expedition_moving=2.0
					var base:float=100.0 if key=="vehicle" else 115.0+3*(count-3)
					var extra:=35.0 if key=="vehicle" else 40.0
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),base+(extra if count>=9 else 0)),prefix+" special shot")
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),base),prefix+" shot cooldown")
				"air":
					unit.logistics.ammo_max=4;unit.logistics.ammo=4;unit.special.expedition_ammo=3
					Rules.tick_unit(unit,1,false)
					check(is_equal_approx(unit.hp-before,unit.max_hp*(0.15 if count>=6 else 0)),prefix+" reload repair")
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.20 if count>=9 else 0.05)),prefix+" reload shield")
					before=unit.hp;Rules.tick_unit(unit,1,false)
					check(is_equal_approx(unit.hp,before),prefix+" full magazine cannot repeat reload reward")
				"naval":
					unit.attack_target=target
					Rules.tick_unit(unit,1,false)
					check(is_equal_approx(unit.hp-before,unit.max_hp*(0.005 if count>=6 else 0)),prefix+" combat repair")
					Rules.defend(unit,1)
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.20 if count>=9 else 0)),prefix+" water-tight shield")
				"mobile":
					unit.velocity=Vector2(40,0);Rules.tick_unit(unit,2,false)
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.15 if count>=9 else 0)),prefix+" moving shield")
					unit.special.expedition_distance=180
					Rules.impact(target,unit,100,"bullet")
					check(is_equal_approx(unit.hp-before,unit.max_hp*(0.05 if count>=6 else 0)),prefix+" march shot heal")
					before=unit.hp;Rules.impact(target,unit,100,"bullet")
					check(is_equal_approx(unit.hp,before),prefix+" march heal cooldown")
				"energy":
					target.special.expedition_mark_type="E1";target.special.expedition_mark_time=now
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),(180 if count>=9 else 140)+3*(count-3)),prefix+" overload damage")
					check(is_equal_approx(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.08 if count>=6 else 0)),prefix+" charged shield")
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),115+3*(count-3)+(15 if count>=9 else 0)),prefix+" overload cooldown")
				"artillery":
					target.special.expedition_first_mark=now-3
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),145+3*(count-3)+(20 if count>=6 else 0)+(50 if count>=9 else 0)),prefix+" barrage milestones")
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),125+3*(count-3)+(20 if count>=6 else 0)),prefix+" marked shot cooldown with exposed target")
				"special":
					target.special.expedition_objective="probe";target.hp=target.max_hp*0.25
					check(is_equal_approx(Rules.impact(target,unit,100,"bullet"),(170 if count>=9 else 130)+3*(count-3)),prefix+" execution bonus")
					check(is_equal_approx(unit.hp-before,unit.max_hp*(0.05 if count>=6 else 0)),prefix+" objective hit heal")
					before=unit.hp;Rules.impact(target,unit,100,"bullet")
					check(is_equal_approx(unit.hp,before),prefix+" heal cooldown")
			if key in ["infantry","support","naval"]:
				unit.special.expedition_shield=0.0;Rules.defend(unit,1)
				check(is_zero_approx(float(unit.special.expedition_shield)),prefix+" shield cooldown")
			unit.queue_free();target.queue_free()
		await get_tree().process_frame
	check_layer_consumers()
	await preload("res://tests/expedition_opening_traits_cases.gd").run(self)
	check_build_loops()
	check_real_consumers()
	await check_restore_and_scope()
	await finish()

func check_layer_consumers() -> void:
	var original:Dictionary=Expedition.state.duplicate(true)
	for key:String in Army.TRAITS:
		var id:String={"infantry":"E1","vehicle":"MTNK","air":"ORCA","naval":"DEST","special":"GHOST","fortify":"GGI","mobile":"MTNK","support":"E1","energy":"SREF","artillery":"HTNK"}[key]
		set_stacks(key,0)
		var baseline=actor(id)
		var base_hp:float=baseline.max_hp
		var base_speed:float=baseline.move_speed
		baseline.queue_free()
		var previous:=-1.0
		for count in range(1,10):
			set_stacks(key,count)
			var unit=actor(id)
			var actual:=0.0
			var expected:=0.0
			if key in ["infantry","vehicle","air","naval","special"]:
				actual=unit.max_hp/base_hp-1.0
				if key in ["infantry","vehicle"]:expected=[0.10,0.20,0.30,0.35,0.40,0.45,0.50,0.55,0.60][count-1]
				elif key in ["air","naval"]:expected=[0.10,0.20,0.25,0.28,0.31,0.34,0.37,0.40,0.43][count-1]
				else:expected=[0.10,0.15,0.20,0.23,0.26,0.29,0.32,0.35,0.38][count-1]
			elif key=="mobile":
				actual=unit.move_speed/base_speed-1.0
				expected=[0.08,0.12,0.15,0.16,0.17,0.18,0.19,0.20,0.21][count-1]
			elif key=="support":
				Expedition.state.trait_buffs={"support":count}
				actual=Expedition.recovery("E1")-0.25
				expected=[0.10,0.15,0.20,0.22,0.24,0.26,0.28,0.30,0.32][count-1]
			elif key=="fortify":
				unit.special.expedition_still=2.0
				actual=1.0-Rules.defend(unit,100)/100.0
				expected=[0.08,0.12,0.15,0.16,0.17,0.18,0.19,0.20,0.21][count-1]
			else:
				var target=hit_target();target.hp=target.max_hp*0.5
				actual=Rules.impact(target,unit,100,"bullet")/100.0-1.0
				expected=[0.08,0.12,0.15,0.18,0.21,0.24,0.27,0.30,0.33][count-1]
				target.queue_free()
			check(is_equal_approx(actual,expected),key+" real layer benefit "+str(count))
			check(actual>previous,key+" every layer increases actual benefit "+str(count))
			previous=actual;unit.queue_free()
	Expedition.state=original

func build_time(value:float) -> void:
	battle.allied_state.expedition_task.elapsed=value

func check_build_loops() -> void:
	set_stacks("infantry",9);build_time(100)
	var infantry=actor("E1");infantry.hp=infantry.max_hp
	for pulse in 12:Rules.tick_unit(infantry,5,true)
	check(is_equal_approx(infantry.special.get("expedition_shield",0),infantry.max_hp*0.20),"infantry overflow healing builds shield capped at twenty percent")
	Rules.context().relics={"shield_capacitor":true}
	check(is_equal_approx(Rules.impact(hit_target(),infantry,100,"bullet"),120),"infantry overheal shield powers shield relic")
	Rules.context().relics={}
	set_stacks("vehicle",9);build_time(120)
	var tank=actor("MTNK");Rules.tick_unit(tank,4,false)
	tank.velocity=Vector2(40,0);Rules.tick_unit(tank,2,false)
	var target=hit_target()
	check(tank.special.get("expedition_vehicle_rounds",0)==3,"vehicle stationary preparation loads three rounds")
	check(is_equal_approx(Rules.impact(target,tank,100,"bullet"),135),"vehicle movement consumes first charged round and opener")
	check(is_equal_approx(Rules.impact(target,tank,100,"bullet"),100) and tank.special.expedition_vehicle_rounds==2,"same-tick splash cannot exhaust loaded rounds")
	for shot in 2:
		build_time(120.25+shot*0.25)
		check(is_equal_approx(Rules.impact(target,tank,100,"bullet"),115),"vehicle follow-up charge "+str(shot))
	build_time(121);check(is_equal_approx(Rules.impact(target,tank,100,"bullet"),100),"vehicle charge exhausted")
	build_time(141);tank.velocity=Vector2.ZERO;Rules.tick_unit(tank,4,false)
	tank.special.trait_build_save_probe=true
	check(tank.special.expedition_vehicle_rounds==3,"vehicle repositions and reloads after cooldown")
	set_stacks("air",9);build_time(150)
	var plane=actor("ORCA");plane.logistics.ammo_max=4;plane.logistics.ammo=4;plane.special.expedition_ammo=3
	Rules.context().relics={"sortie_seal":true};Rules.tick_unit(plane,1,false)
	check(is_equal_approx(Rules.impact(hit_target(),plane,100,"bullet"),180),"air reload combines base opener, salvo and sortie relic")
	Rules.context().relics={}
	for shot in 2:
		build_time(150.25+shot*0.25);check(is_equal_approx(Rules.impact(hit_target(),plane,100,"bullet"),120),"air follow-up salvo "+str(shot))
	build_time(151);check(is_equal_approx(Rules.impact(hit_target(),plane,100,"bullet"),100),"air must reload to regain salvo")
	set_stacks("naval",9);build_time(160)
	var ship=actor("DEST");Rules.defend(ship,1)
	var health:float=ship.hp
	check(is_equal_approx(Rules.impact(hit_target(),ship,100,"bullet"),120) and is_equal_approx(ship.hp-health,ship.max_hp*0.02),"naval low-health shield enables repairing counterfire")
	check(is_equal_approx(Rules.impact(hit_target(),ship,100,"bullet"),100),"naval counterfire cooldown")
	set_stacks("fortify",9)
	var defender=actor("GGI");defender.special.expedition_shield=defender.max_hp*0.10;defender.special.expedition_still=5.0
	for hit in 3:
		build_time(170+hit);Rules.defend(defender,1);Rules.defend(defender,1)
	check(defender.special.get("expedition_counter_charges",0)==3,"fortify charges at most once per second")
	check(is_equal_approx(Rules.impact(hit_target(),defender,100,"bullet"),233) and defender.special.expedition_counter_charges==0,"fortify converts shielded pressure into charged counterattack")
	check(is_equal_approx(Rules.impact(hit_target(),defender,100,"bullet"),133),"fortify burst cooldown")
	set_stacks("mobile",9);build_time(180)
	var scout=actor("MTNK");scout.special.expedition_distance=110.0
	check(is_equal_approx(Rules.impact(hit_target(),scout,100,"bullet"),143),"mobile ninth layer activates after two cells")
	scout.special.expedition_distance=110.0;build_time(183.9)
	check(is_equal_approx(Rules.impact(hit_target(),scout,100,"bullet"),100),"mobile burst waits four seconds")
	build_time(184);check(is_equal_approx(Rules.impact(hit_target(),scout,100,"bullet"),143),"mobile move-hit-heal loop repeats after four seconds")
	set_stacks("support",9);build_time(190)
	var supported=actor("E1");supported.hp=supported.max_hp*0.91;Rules.tick_unit(supported,5,true)
	check(is_equal_approx(Rules.impact(hit_target(),supported,100,"bullet"),115),"support turns high-health medical pulse into attack window")
	build_time(195);check(is_equal_approx(Rules.impact(hit_target(),supported,100,"bullet"),100),"support attack window expires")
	supported.hp=supported.max_hp*0.5;Rules.tick_unit(supported,5,true)
	check(is_equal_approx(Rules.impact(hit_target(),supported,100,"bullet"),100),"support injured units heal without attack window")
	set_stacks("energy",9);build_time(200)
	var prism=actor("SREF");target=hit_target();target.special.expedition_mark_type="E1";target.special.expedition_mark_time=200.0
	check(is_equal_approx(Rules.impact(target,prism,100,"bullet"),198),"energy mixed-unit attack triggers overload")
	check(is_equal_approx(Rules.impact(target,supported,100,"bullet"),115),"energy overload benefits other unit types")
	build_time(204);check(is_equal_approx(Rules.impact(target,supported,100,"bullet"),100),"energy overload mark expires")
	set_stacks("artillery",9);build_time(210)
	var artillery=actor("HTNK");target=hit_target();target.special.expedition_first_mark=207.0
	Rules.impact(target,artillery,100,"bullet")
	check(is_equal_approx(Rules.impact(supported,target,100,"bullet"),80),"artillery marked strike suppresses enemy direct damage")
	check(is_equal_approx(Rules.impact(supported,target,100,"radiation"),100),"suppression does not change excluded indirect damage")
	build_time(214);check(is_equal_approx(Rules.impact(supported,target,100,"bullet"),100),"artillery suppression expires")
	set_stacks("special",9);build_time(220)
	var commando=actor("GHOST");target=hit_target();target.hp=target.max_hp*0.2
	check(is_equal_approx(Rules.impact(target,commando,100,"bullet"),140),"special execution applies to wounded enemy outside objectives")
	check(is_equal_approx(Rules.impact(target,commando,100,"bullet"),100),"special execution starts cooldown")
	target._die(commando);target=hit_target();target.hp=target.max_hp*0.2
	health=commando.hp
	check(is_equal_approx(Rules.impact(target,commando,100,"bullet"),140) and commando.hp>health,"actual kill refreshes execution and healing for next target")

func check_real_consumers() -> void:
	set_stacks("infantry",9)
	var soldier=actor("E1")
	var enemy=hit_target()
	var health:float=soldier.hp
	soldier.receive_hit(1,"bullet",{},enemy)
	check(is_equal_approx(soldier.hp,health) and soldier.special.get("expedition_shield",0)>0 and soldier.special.expedition_shield<soldier.max_hp*0.15,"real damage pipeline consumes milestone shield before HP")
	screen.expedition_runtime.tick(5)
	check(soldier.hp>health,"real runtime tick consumes trait healing")
	set_stacks("vehicle",8)
	var tank=actor("MTNK");tank.special.expedition_moving=2.0
	var plain=hit_target();var boosted=hit_target()
	var base_hp:float=plain.hp
	plain.receive_hit(10,"bullet",{},tank)
	var base_damage:float=base_hp-plain.hp
	set_stacks("vehicle",9)
	base_hp=boosted.hp
	boosted.receive_hit(10,"bullet",{},tank)
	check(base_hp-boosted.hp>base_damage,"real damage pipeline applies ninth-layer shot")

func check_restore_and_scope() -> void:
	set_stacks("energy",9)
	Rules.context().emblems={"E1":"energy"}
	var ordinary=actor("E1")
	var energy=actor("SREF")
	check(is_equal_approx(Rules.impact(hit_target(),ordinary,100,"bullet"),100),"ordinary infantry does not gain energy buff from manual metadata")
	check(is_equal_approx(Rules.impact(hit_target(),energy,100,"bullet"),133) and energy.special.get("expedition_shield",0)>0,"energy unit automatically consumes buff damage and shield")
	set_stacks("infantry",9)
	var soldier=actor("E1")
	Rules.defend(soldier,1)
	var cooldown:float=soldier.special.expedition_milestone_infantry
	var shield:float=soldier.special.expedition_shield
	soldier.special.trait_regression_marker=true
	check(Expedition.checkpoint(battle),"milestone timers and shield checkpoint")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"milestone battle reload")
	if not instantiate_battle():return
	var restored=null
	for unit in battle.units:
		if unit.special.get("trait_regression_marker",false):restored=unit;break
	var build_restored:=false
	var opening_restored:=false
	for unit in battle.units:
		if unit.special.get("trait_build_save_probe",false):build_restored=int(unit.special.get("expedition_vehicle_rounds",0))==3 and unit.special.get("expedition_milestone_vehicle",0)>0
		if unit.special.get("opening_save_probe",false):opening_restored=unit.special.get("expedition_milestone_infantry_dressing",0)==906.0
	check(opening_restored,"third-layer kill cooldown survives real checkpoint restore")
	check(build_restored,"terminal build charge and recharge timer survive checkpoint")
	check(restored!=null,"milestone unit restored")
	if restored==null:return
	check(is_equal_approx(restored.special.expedition_milestone_infantry,cooldown) and is_equal_approx(restored.special.expedition_shield,shield),"cooldown and remaining shield survive restore")
	restored.special.expedition_shield=0.0
	Rules.defend(restored,1)
	check(is_zero_approx(float(restored.special.expedition_shield)),"reload does not refresh used shield cooldown")
	battle.allied_state.expedition_task.elapsed=cooldown
	Rules.defend(restored,1)
	check(is_equal_approx(float(restored.special.expedition_shield),restored.max_hp*0.15),"shield becomes available after saved cooldown expires")
	restored.special.expedition_shield=0.0
	var enemy=hit_target();enemy.hp=enemy.max_hp*0.2
	Rules.defend(enemy,1);Rules.tick_unit(enemy,5,true)
	check(not enemy.special.has("expedition_shield") and is_equal_approx(enemy.hp,enemy.max_hp*0.2),"enemy never receives trait heal or shield")
	restored.special.expansion_temporary=true
	var before:float=restored.hp
	Rules.tick_unit(restored,5,true);Rules.defend(restored,1)
	check(is_equal_approx(restored.hp,before) and is_zero_approx(float(restored.special.expedition_shield)),"temporary unit excluded")
	restored.special.erase("expansion_temporary")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":1})
	Rules.tick_unit(restored,5,true)
	check(not Rules.active() and is_equal_approx(restored.hp,before) and is_equal_approx(Rules.impact(enemy,restored,100,"bullet"),100),"ordinary skirmish unaffected")
