extends "res://tests/expedition_regression.gd"
const Relics=preload("res://scripts/expedition/relics.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	check_formation_relics()
	check_catalog_and_shop()
	await check_reward_flow()
	await check_combat_relics()
	await check_ultimate_relics()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION RELICS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_formation_relics() -> void:
	new_ready("美国",26)
	var run:Dictionary=Expedition.state.duplicate(true)
	for rank in 3:
		check(Market.relic_pool(run).any(func(item):return item.id=="capture_manual"),"manual offered before rank III")
		Relics.grant(run,"capture_manual")
		check(Relics.level(run,"capture_manual")==rank+1,"manual gains one rank")
	check(not Market.relic_pool(run).any(func(item):return item.id=="capture_manual"),"rank III leaves the pool")
	for stage in [15,16,20,21,26]:
		run.stage=stage
		var pool:=Market.relic_pool(run)
		for id:String in ["formation_warrant","joint_roster"]:
			var eligible:bool=stage >= (16 if id=="formation_warrant" else 21)
			check(pool.any(func(item):return item.id==id)==eligible and Expedition.item_valid(run,{"kind":"relic","id":id})==eligible,"formation relic pool and claim gate %s at %d"%[id,stage])
	var ids:Array=["E1","GGI","MTNK","FV","SREF","MGTK","CLEG","SNIPE","SHK","HTNK","HTK","TTNK","BORIS"]
	run.survivors=[];run.reinforcements=[];run.special_squads=[];run.active_roster=[]
	for id:String in ids:Army.add_unit(run,id,1)
	run.shop=[{"kind":"relic","id":"formation_warrant","price":180,"sold":false,"locked":false}]
	check(Expedition.commit(run) and Expedition.formation_slots().size()==11,"full final-chapter baseline has eleven slots")
	check(Expedition.buy(0) and Expedition.formation_slots().size()==12 and Expedition.move_formation("TTNK",11),"purchase unlocks a usable twelfth slot")
	run=Expedition.state.duplicate(true);run.phase="reward";run.reward_round="initial"
	run.offers=[{"kind":"relic","id":"joint_roster"}]
	check(Expedition.commit(run) and Expedition.choose(0,"",Expedition.reward_token()),"reward grants the second formation relic")
	check(Expedition.formation_slots().size()==13 and Expedition.move_formation("BORIS",12),"stacked relics unlock a thirteenth slot")
	check(Expedition.load_run() and Expedition.formation_slots().slice(11)==["TTNK","BORIS"],"both additional slots survive disk reload")
	check(Expedition.launch(0) and BattleRequest.combat_context.expedition.active_roster==ids,"all thirteen types enter the battle context")
	var arrivals:=preload("res://scripts/expedition/reinforcement_plan.gd").build(Expedition.state)
	check(arrivals.any(func(r):return r.id=="TTNK") and arrivals.any(func(r):return r.id=="BORIS"),"extra types are scheduled to arrive")
	new_ready("美国",26)
	check(Expedition.formation_slots().size()==11,"new expedition returns to its base capacity")

func check_catalog_and_shop() -> void:
	new_ready("美国",30)
	for id:String in ["bridge_station","silent_radio","field_dispatch","chrono_decree","alert_array","chrono_anchor","joint_roster","formation_warrant"]:
		check(Relics.ITEMS.has(id),"persistent catalog includes "+id)
	var next:Dictionary=Expedition.state.duplicate(true)
	var original_buffs:Dictionary=next.buffs.duplicate(true)
	var original_profile:Dictionary=next.frozen.duplicate(true)
	for id:String in Relics.ITEMS:
		check(not Market.title({"kind":"relic","id":id}).is_empty() and Market.description({"kind":"relic","id":id}).length()>40,"clear title and description "+id)
		next.shop=[{"kind":"relic","id":id,"price":Relics.ITEMS[id].price,"sold":false,"locked":false}]
		var before:int=next.supplies
		check(Expedition.commit(next) and Expedition.buy(0),"real shop purchase "+id)
		check(Relics.owned(Expedition.state,id) and Expedition.state.supplies==before-int(Relics.ITEMS[id].price),"purchase grants once at listed price "+id)
		for tier in range(2,int(Relics.ITEMS[id].get("max_level",1))+1):
			next=Expedition.state.duplicate(true);next.shop[0].sold=false
			check(Expedition.commit(next) and Expedition.buy(0) and Relics.level(Expedition.state,id)==tier,"stackable purchase reaches level %d %s"%[tier,id])
		next=Expedition.state.duplicate(true);next.shop[0].sold=false;Expedition.commit(next)
		check(not Expedition.buy(0) and Expedition.state.supplies==next.supplies,"stale duplicate cannot spend "+id)
	check(Expedition.load_run() and Expedition.state.relics.size()==Relics.ITEMS.size(),"all relics persist in run save")
	check(Expedition.state.buffs==original_buffs and Expedition.state.frozen==original_profile,"relics do not replace equipment or modify outside snapshot")
	check(Market.relic_pool(Expedition.state).is_empty(),"owned collection exhausted without duplicate rewards")
	next=Expedition.state.duplicate(true);next.relics.unknown_relic=true
	check(not Expedition.valid(next),"reject unknown relic save")
	next.relics.erase("unknown_relic");next.relics.field_manual=3
	check(not Expedition.valid(next),"reject non-boolean relic save")
	for country in ["美国","苏俄"]:
		new_ready(country,16)
		next=Expedition.state.duplicate(true)
		for candidate:Dictionary in Market.relic_pool(next):
			var spec:Dictionary=Relics.ITEMS[candidate.id]
			if not spec.has("units"):continue
			var matches:=false
			for id:String in next.licenses:
				if id in spec.units:matches=true
			check(matches,country+" exclusive pool matches licenses "+candidate.id)
		for roll in 24:
			next.seed=roll
			var shop:=Market.shop(next,roll)
			check(shop==Market.shop(next,roll),country+" deterministic relic shop "+str(roll))
			check(shop[5].kind=="relic",country+" dedicated relic candidate "+str(roll))
			var seen:Array=[]
			for item:Dictionary in shop:
				if item.kind!="relic":continue
				check(item.id not in seen,country+" no duplicate relic in shop "+str(roll));seen.append(item.id)
			next.shop=shop;next.shop[5].locked=true
			var locked:=Market.shop(next,roll+1)
			var count:=0
			for item:Dictionary in locked:
				if item.kind=="relic" and item.id==shop[5].id:count+=1
			check(count==1 and locked[5].id==shop[5].id,country+" locked relic retained once "+str(roll))
			next.shop=[]
		for at_stage in [1,15,16,21]:
			next.stage=at_stage;next.shop=[];next.relics={}
			var ultimates:=Market.ultimate_pool(Market.relic_pool(next))
			check(ultimates.is_empty() if at_stage<16 else not ultimates.is_empty(),country+" ultimate stage gate "+str(at_stage))
			check(Expedition.item_valid(next,{"kind":"relic","id":"bastion_heart"})==(at_stage>=16),country+" actual claim stage gate "+str(at_stage))
			if at_stage<16:continue
			check(Relics.ITEMS[Market.shop(next,0)[5].id].family=="究极构筑",country+" new late camp prioritizes ultimate relic")
			for roll in 24:
				next.seed=roll
				var rewards:=Market.rewards(next)
				check(not Market.ultimate_pool(rewards).is_empty(),country+" late boss guarantees suitable ultimate candidate "+str(at_stage)+"/"+str(roll))
			for item:Dictionary in ultimates:next.relics[item.id]=true
			check(Market.ultimate_pool(Market.relic_pool(next)).is_empty() and not Market.rewards(next).is_empty(),country+" ultimate collection exhausted falls back normally")
	for balance in [0,9,10,399,400,10000]:
		check(Relics.victory_supplies({"relics":{"reserve_bond":true,"supply_ledger":true},"supplies":balance})==25+mini(40,int(balance/10)),"interest floor and cap "+str(balance))
	new_ready("美国")
	next=Expedition.state.duplicate(true);next.relics.bargain_map=true;Expedition.commit(next)
	for expected in [0,5,10,15,15]:
		var balance:int=Expedition.state.supplies
		check(Expedition.refresh_price()==expected and Expedition.refresh_shop() and Expedition.state.supplies==balance-expected,"real discounted refresh "+str(expected))
	next=Expedition.state.duplicate(true);next.free_refresh=1;Expedition.commit(next)
	check(Expedition.refresh_price()==0 and Expedition.refresh_shop(),"free token remains free with discount")

func check_reward_flow() -> void:
	new_ready("美国",5)
	var next:Dictionary=Expedition.state.duplicate(true)
	next.relics={"supply_ledger":true,"reserve_bond":true,"choice_compass":true};next.supplies=399
	Expedition.commit(next)
	check(Expedition.launch(0),"launch relic reward battle")
	if not instantiate_battle():await finish();return
	check(Rules.context().relics==next.relics,"launch freezes owned relics")
	satisfy_objective(screen.expedition_runtime.tasks)
	check(Expedition.state.phase=="reward" and Expedition.state.supplies==399+380+25+39,"raised boss settlement uses pre-reward interest once")
	check(not Expedition.settle(battle,true),"settlement replay cannot repeat relic income")
	check(Expedition.state.offers.size()==4,"compass expands actual main reward")
	var relic_index:=-1
	for index in Expedition.state.offers.size():
		if Expedition.state.offers[index].kind=="relic":relic_index=index
	check(relic_index>=0,"boss reward guarantees relic candidate")
	var token:=Expedition.reward_token()
	var choice:Dictionary=Expedition.state.offers[maxi(0,relic_index)]
	check(Expedition.choose(maxi(0,relic_index),"",token),"claim relic through actual reward flow")
	check(Relics.owned(Expedition.state,choice.id) and Expedition.state.offers.size()==4 and Expedition.state.reward_round=="buff","claim persists relic then generates four bonus choices")
	var saved:Dictionary=Expedition.state.duplicate(true)
	check(Expedition.load_run() and Expedition.state==saved,"four choices persist without reroll")
	check(not Expedition.choose(0,"",token) and Expedition.state==saved,"stale click cannot claim second reward")
	check(Expedition.choose(0,"",Expedition.reward_token()) and Expedition.state.phase=="event","bonus reward leads to post-battle event")
	check(Expedition.resolve_event(0,Expedition.event_token()) and Expedition.state.phase=="ready","event completes before next camp")
	await finish()
	new_ready("美国",2)
	next=Expedition.state.duplicate(true);next.phase="reward";next.reward_round="main"
	next.offers=[{"kind":"relic","id":"choice_compass"},{"kind":"supplies","id":"bonus","amount":100},{"kind":"relic","id":"field_manual"}]
	Expedition.commit(next)
	check(Expedition.state.offers.size()==3 and Expedition.choose(0,"",Expedition.reward_token()),"acquire compass from existing three-choice reward")
	check(Expedition.state.offers.size()==4 and Expedition.state.reward_round=="buff","new compass immediately expands next reward round only")
	for mode in ["defeat","retreat"]:
		new_ready("美国",2)
		next=Expedition.state.duplicate(true);next.relics={"supply_ledger":true,"reserve_bond":true};next.supplies=500;Expedition.commit(next)
		Expedition.launch(0)
		if not instantiate_battle():await finish();return
		if mode=="defeat":check(Expedition.settle(battle,false) and Expedition.state.supplies==500,"defeat grants no relic income")
		else:check(Expedition.retreat(battle) and Expedition.state.supplies==420,"retreat only charges retreat cost")
		await finish()

func actor(id:String,side:String="ally"):
	var unit=battle.spawn_unit(id,side,battle.player_start()+Vector2(350,350))
	unit.special={};unit.hp=unit.max_hp*0.25;unit.velocity=Vector2.ZERO;unit.attack_target=null
	return unit

func equip(ids:Array) -> void:
	Rules.context().relics={};Rules.context().buffs={};Rules.context().traits={};Rules.context().trait_buffs={}
	for id:String in ids:Rules.context().relics[id]=true

func time_at(now:float) -> void:
	battle.allied_state.expedition_task.elapsed=now

func hit(gun,target,expected:float,title:String) -> void:
	check(is_equal_approx(Rules.impact(target,gun,100,"bullet"),expected),title)

func check_combat_relics() -> void:
	new_ready("美国",16);Expedition.launch(0)
	if not instantiate_battle():await finish();return
	var target=actor("MTNK","enemy");target.hp=target.max_hp
	var soldier=actor("E1")
	equip(["sandbag_standard","shield_capacitor"]);time_at(10)
	Rules.tick_unit(soldier,3,false)
	check(not soldier.special.has("expedition_shield"),"sandbags require deployed stance")
	soldier._deployed=true;Rules.tick_unit(soldier,1,false)
	check(is_equal_approx(soldier.special.expedition_shield,soldier.max_hp*0.12),"deployment grants twelve percent shield")
	hit(soldier,target,120,"shield and capacitor combo")
	hit(soldier,target,100,"capacitor cooldown blocks repeat")
	soldier.special.expedition_shield=0;Rules.tick_unit(soldier,1,false)
	check(soldier.special.expedition_shield==0,"sandbag shield cannot instantly refill")
	time_at(25);Rules.tick_unit(soldier,1,false)
	check(soldier.special.expedition_shield>0,"sandbag shield recharges after cooldown")
	var guardian=actor("GGI");equip(["guardian_sight"])
	hit(guardian,target,100,"guardian requires deployment")
	guardian._deployed=true;hit(guardian,target,130,"guardian anti-vehicle stance")
	check(is_equal_approx(guardian.special.expedition_shield,guardian.max_hp*0.08),"guardian gets shield on valid target")
	var infantry=actor("E2","enemy");hit(guardian,infantry,100,"guardian excludes infantry targets")
	var tank=actor("MTNK");equip(["drive_flywheel"])
	tank.velocity=Vector2(40,0);Rules.tick_unit(tank,2,false)
	var hp:float=tank.hp
	hit(tank,target,135,"moving grizzly empowered shot")
	check(is_equal_approx(tank.hp-hp,tank.max_hp*0.05),"grizzly heals on charge")
	hit(tank,target,100,"grizzly charge cooldown")
	time_at(40);hit(tank,target,100,"expired movement window gives no charge")
	var rhino=actor("HTNK");equip(["rhino_drum","barrage_counter"])
	for index in 6:
		time_at(50+index)
		hit(rhino,target,100+8*mini(5,index+1)+(35 if (index+1)%3==0 else 0),"rhino barrage combo hit "+str(index))
		hit(rhino,target,100+8*mini(5,index+1),"same-tick splash cannot add combo counts "+str(index))
	time_at(61);hit(rhino,target,108,"five-second idle resets combo")
	var tesla=actor("SHK");equip(["tesla_coil"])
	for index in 3:
		time_at(70+index);hit(tesla,target,160 if index==2 else 100,"tesla three-hit sequence "+str(index))
	check(is_equal_approx(tesla.special.expedition_shield,tesla.max_hp*0.05),"tesla discharge shield")
	var prism=actor("SREF");equip(["prism_lens"]);time_at(80)
	hit(prism,target,100,"prism first hit applies mark")
	hit(soldier,target,120,"other unit benefits from prism mark")
	time_at(84);hit(soldier,target,100,"prism mark expires at four seconds")
	var chopper=actor("SCHP");equip(["rotor_workshop"]);chopper._deployed=true;time_at(90)
	hp=chopper.hp;Rules.tick_unit(chopper,3,false)
	check(is_equal_approx(chopper.hp-hp,chopper.max_hp*0.04) and chopper.special.expedition_shield>0,"deployed helicopter repairs and shields")
	hp=chopper.hp;Rules.tick_unit(chopper,1,false)
	check(chopper.hp==hp,"workshop five-second cooldown")
	time_at(95);chopper._deployed=false;Rules.tick_unit(chopper,1,false)
	check(chopper.hp==hp,"workshop stops when undeployed")
	var commando=actor("GHOST");equip(["commando_dogtag"]);time_at(100);target.hp=target.max_hp*0.30
	hit(commando,target,125,"commando executes low-health target")
	hp=commando.hp;target._die(commando)
	check(is_equal_approx(commando.hp-hp,commando.max_hp*0.08),"real unit death triggers commando heal")
	target=actor("MTNK","enemy");target.hp=target.max_hp
	hp=commando.hp;Rules.defeated(battle,target,commando)
	check(commando.hp==hp,"commando kill heal cooldown")
	time_at(104);target.side="neutral";Rules.defeated(battle,target,commando)
	check(commando.hp==hp,"neutral units cannot farm kill healing");target.side="enemy"
	equip(["redline_core"]);soldier.hp=soldier.max_hp*0.2
	check(is_equal_approx(Rules.defend(soldier,100),85),"redline low-health reduction")
	hp=soldier.hp;hit(soldier,target,100,"redline does not add damage")
	check(is_equal_approx(soldier.hp-hp,soldier.max_hp*0.03),"redline hit recovery")
	hp=soldier.hp;hit(soldier,target,100,"redline repeat hit")
	check(soldier.hp==hp,"redline recovery cooldown")
	Rules.context().buffs={"last_stand":3,"emergency_position":3}
	check(is_equal_approx(Rules.defend(soldier,100),65),"combined defense still caps at thirty-five percent")
	var plane=actor("ORCA");equip(["sortie_seal"]);time_at(110)
	plane.logistics.ammo_max=4;plane.logistics.ammo=4;plane.special.expedition_ammo=3
	hp=plane.hp;Rules.tick_unit(plane,1,false)
	check(is_equal_approx(plane.hp-hp,plane.max_hp*0.10),"normal full reload repairs plane")
	hit(plane,target,140,"reloaded plane empowered shot");hit(plane,target,100,"sortie shot consumed once")
	hp=plane.hp;Rules.tick_unit(plane,1,false)
	check(plane.hp==hp and not plane.special.expedition_relic_sortie,"staying full ammo grants nothing")
	equip(["rhino_drum"]);time_at(120);hit(rhino,target,108,"new rhino sequence before snapshot")
	rhino.special.relic_snapshot_probe=true
	check(Expedition.checkpoint(battle),"checkpoint captures relic battle context and combo")
	await finish()

	check(Expedition.load_run() and Expedition.prepare_battle(),"resume relic snapshot")
	if not instantiate_battle():await finish();return
	var restored=null
	for unit in battle.units:
		if unit.special.get("relic_snapshot_probe",false):restored=unit;break
	check(restored!=null and int(restored.special.get("expedition_relic_count_rhino",0))==1 and Rules.context().relics.get("rhino_drum",false),"restored relic ownership and hit counters")
	if restored!=null:
		target=actor("MTNK","enemy");time_at(121);hit(restored,target,116,"combo continues across battle save")
		var entries:Array=[];Rules.append_status(restored,entries)
		var found:=false
		for entry:Dictionary in entries:
			if entry.id=="expedition_relic_rhino_drum":found=entry.text.contains("5 秒")
		check(found,"unit HUD explains applicable relic")
		restored.special.expansion_temporary=true;hit(restored,target,100,"temporary actors excluded")
		restored.special.erase("expansion_temporary");restored.side="enemy";target.side="ally";hit(restored,target,100,"enemies excluded")
		restored.side="ally";target.side="enemy"
		check(is_equal_approx(Rules.impact(target,restored,100,"radiation"),100),"indirect radiation excluded")
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":1})
		hit(restored,target,100,"ordinary skirmish has no relic effect")
	await finish()

func ultimate_trait(key:String) -> void:
	Rules.context().trait_buffs={key:9}
	Rules.context().traits={key:5}

func check_ultimate_relics() -> void:
	new_ready("美国",16);Expedition.launch(0)
	if not instantiate_battle():await finish();return
	var target=actor("MTNK","enemy");target.hp=target.max_hp
	var soldier=actor("E1");equip(["bastion_heart"]);time_at(10)
	Rules.tick_unit(soldier,3,false)
	check(not soldier.special.has("expedition_shield"),"ultimate bastion requires deployment")
	soldier._deployed=true;Rules.tick_unit(soldier,1,false)
	check(is_equal_approx(soldier.special.get("expedition_shield",0),soldier.max_hp*0.15),"ultimate bastion generates its own shield")
	Rules.absorb(soldier,soldier.max_hp*0.10)
	hit(soldier,target,130,"actual shield absorption becomes counterfire energy")
	hit(soldier,target,100,"bastion energy consumed once")
	var hp:float=soldier.hp
	soldier.receive_hit(1,"bullet",{},target)
	check(soldier.hp==hp and float(soldier.special.get("expedition_ultimate_bastion",0))>0,"real damage pipeline records absorbed damage without HP loss")
	soldier.special.expedition_shield=soldier.max_hp;Rules.absorb(soldier,soldier.max_hp)
	check(is_equal_approx(soldier.special.expedition_ultimate_bastion,soldier.max_hp*0.40),"bastion stored energy cap")
	ultimate_trait("fortify");hit(soldier,target,253,"bastion full counterfire adds to ninth-layer base")
	check(is_equal_approx(soldier.special.expedition_shield,soldier.max_hp*0.10),"ninth-layer fortify replenishes shield after full discharge")
	var tank=actor("MTNK");equip(["grizzly_engine"]);time_at(30)
	Rules.tick_unit(tank,2,false)
	check(not tank.special.has("expedition_ultimate_grizzly"),"ultimate grizzly requires movement")
	tank.velocity=Vector2(40,0);Rules.tick_unit(tank,2,false)
	hit(tank,target,125,"grizzly first pursuit round");hit(tank,target,100,"same-tick splash does not consume another pursuit round")
	time_at(30.25);hit(tank,target,125,"grizzly second pursuit round")
	tank.special.expedition_mobile_cd=999.0;tank.special.expedition_relic_cd_drive=999.0
	ultimate_trait("vehicle");hp=tank.hp;time_at(30.5);hit(tank,target,145,"grizzly third pursuit round combines ninth-layer moving opener")
	check(tank.special.expedition_ultimate_grizzly==0 and tank.special.expedition_vehicle_rounds==3 and is_equal_approx(tank.hp-hp,tank.max_hp*0.08),"grizzly completed salvo reloads ninth-layer volley and heals")
	check(not tank.special.has("expedition_mobile_cd") and not tank.special.has("expedition_relic_cd_drive"),"grizzly completed salvo resets movement build cooldowns")
	Rules.tick_unit(tank,1,false);check(tank.special.expedition_ultimate_grizzly==0,"grizzly loader cooldown")
	time_at(40);Rules.tick_unit(tank,1,false);check(tank.special.expedition_ultimate_grizzly==3,"grizzly movement reload loop")
	var rhino=actor("HTNK");equip(["rhino_siege"]);time_at(50)
	hit(rhino,target,100,"siege requires stationary posture");Rules.tick_unit(rhino,3,false)
	for index in 3:
		time_at(50+index);hit(rhino,target,140 if index==2 else 100,"siege three-hit activation "+str(index))
		hit(rhino,target,140 if index==2 else 100,"siege same-tick counter protection "+str(index))
	check(is_equal_approx(Rules.impact(soldier,target,100,"bullet"),80),"siege suppresses actual enemy outgoing direct damage")
	rhino.velocity=Vector2(40,0);Rules.tick_unit(rhino,1,false);hit(rhino,target,100,"movement ends siege window")
	check(rhino.special.expedition_ultimate_siege_count==0,"movement also clears siege charge")
	rhino.velocity=Vector2.ZERO;Rules.tick_unit(rhino,3,false);ultimate_trait("artillery")
	rhino.special.expedition_milestone_artillery_shot=999.0
	for index in 3:
		time_at(60+index);Rules.impact(target,rhino,100,"bullet")
	check(not rhino.special.has("expedition_milestone_artillery_shot"),"siege activation resets ninth-layer artillery burst")
	var prism=actor("SREF");equip(["prism_matrix"]);time_at(80)
	target=actor("MTNK","enemy");target.hp=target.max_hp
	hit(prism,target,100,"prism opens resonance mark")
	hit(soldier,target,100,"first donor contributes without adding raw damage")
	hit(soldier,target,100,"same type cannot double charge resonance")
	check(target.special.expedition_ultimate_prism_donors.size()==1,"prism requires distinct donor types")
	var guardian=actor("GGI");hit(guardian,target,100,"second resonance donor");hit(tank,target,100,"third resonance donor")
	hit(prism,target,220,"prism cashes three donor types into empowered main gun")
	hit(prism,target,100,"resonance energy consumed once")
	hit(soldier,target,100,"resonance starts next cycle");time_at(86);hit(guardian,target,100,"expired resonance cannot accept donor")
	check(target.special.expedition_ultimate_prism_donors.is_empty(),"expired resonance clears donors")
	hit(prism,target,100,"prism reopens expired mark")
	for donor in [soldier,guardian,tank]:Rules.impact(target,donor,100,"bullet")
	ultimate_trait("energy");Rules.impact(target,prism,100,"bullet")
	check(target.special.get("expedition_overload_until",0)==90.0,"ninth-layer prism discharge leaves overload")
	var plane=actor("ORCA");equip(["sky_cycle"]);time_at(100)
	plane.logistics.ammo_max=4;plane.logistics.ammo=4;plane.special.expedition_ammo=3;Rules.tick_unit(plane,1,false)
	target=actor("MTNK","enemy");target.hp=target.max_hp
	hit(plane,target,135,"sky first reload strike");hit(plane,target,100,"sky same-tick protection")
	time_at(100.25);hit(plane,target,135,"sky second strike")
	ultimate_trait("air");hp=plane.hp;time_at(100.5);Rules.impact(target,plane,100,"bullet")
	check(plane.special.expedition_ultimate_sky==0 and is_equal_approx(plane.special.expedition_shield,plane.max_hp*0.25) and is_equal_approx(plane.hp-hp,plane.max_hp*0.10),"sky third strike shields and heals ninth-layer aircraft")
	hit(soldier,target,125,"ground troops exploit sky beacon")
	Rules.tick_unit(plane,1,false);check(plane.special.expedition_ultimate_sky==0,"full ammunition cannot repeatedly load ultimate strikes")
	time_at(106.5);hit(soldier,target,100,"sky beacon expires")
	var commando=actor("GHOST");equip(["zero_warrant"]);time_at(120)
	target=actor("MTNK","enemy");target.hp=target.max_hp*0.59
	hit(commando,target,150,"ultimate execution threshold below sixty percent")
	target.hp=target.max_hp*0.60;hit(commando,target,100,"execution sixty percent boundary")
	hp=commando.hp;target._die(commando)
	check(is_equal_approx(commando.hp-hp,commando.max_hp*0.10) and is_equal_approx(commando.special.expedition_shield,commando.max_hp*0.15),"actual kill primes assault and restores commando")
	target=actor("MTNK","enemy");target.hp=target.max_hp
	hit(commando,target,150,"kill primes opening shot against full-health target");hit(commando,target,100,"primed assault consumed once")
	Rules.defeated(battle,target,commando);check(commando.special.expedition_ultimate_execution_until==0,"same-tick kill cannot repeatedly prime assault")
	time_at(121);Rules.defeated(battle,target,commando);time_at(129);hit(commando,target,100,"primed assault expires after eight seconds")
	for unit in [soldier,tank,rhino,prism,plane,commando]:unit.special.ultimate_save_probe=true
	equip(["bastion_heart","grizzly_engine","rhino_siege","prism_matrix","sky_cycle","zero_warrant"])
	check(Expedition.checkpoint(battle),"ultimate counters and windows checkpoint")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"ultimate checkpoint prepares reload")
	if not instantiate_battle():await finish();return
	var restored:=0
	for unit in battle.units:
		if not unit.special.get("ultimate_save_probe",false):continue
		restored+=1
		if unit.unit_id=="MTNK":check(unit.special.get("expedition_ultimate_grizzly",0)==3,"ultimate magazine restored")
		if unit.unit_id=="HTNK":check(unit.special.get("expedition_ultimate_siege_until",0)==68.0,"ultimate siege window restored")
		if unit.unit_id=="GHOST":
			var entries:Array=[];Rules.append_status(unit,entries)
			var explained:=false
			for entry:Dictionary in entries:
				if entry.id=="expedition_relic_zero_warrant":explained=entry.text.contains("60%") and entry.text.contains("8 秒")
			check(explained,"ultimate HUD explains scope trigger and duration")
	check(restored==6,"all ultimate actors survive save restore")
	var ordinary=actor("MTNK");target=actor("MTNK","enemy");target.hp=target.max_hp
	ordinary.special.expedition_ultimate_grizzly=3;ordinary.special.expansion_temporary=true
	hit(ordinary,target,100,"temporary units cannot consume ultimate relic")
	ordinary.special.erase("expansion_temporary")
	check(is_equal_approx(Rules.impact(target,ordinary,100,"radiation"),100),"indirect damage cannot consume ultimate magazine")
	check(ordinary.special.expedition_ultimate_grizzly==3,"excluded hit preserves ultimate magazine")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":1});hit(ordinary,target,100,"ordinary skirmish ignores ultimate relics")
	await finish()
