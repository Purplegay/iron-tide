extends Node
const Training = preload("res://scripts/rules/skill_training.gd")
const Soviet = preload("res://scripts/units/soviet_specials.gd")
const Riot = preload("res://scripts/units/ra3_riot.gd")
const Transition = preload("res://scripts/world/construction_transition.gd")
var checks: Array = []
var failed := 0
var battle

func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:
		failed += 1
		print("FAIL ",label)

func spawn(id: String, point := Vector2(1200,1200), side := "ally") -> Unit:
	var actor: Unit
	if is_instance_valid(battle): actor=battle.spawn_unit(id,side,point)
	else:
		actor=Unit.new();actor.side=side;add_child(actor)
		actor.setup(GameData.get_unit(id),side,point)
	actor.process_mode=Node.PROCESS_MODE_ALWAYS
	actor.set_process(false);actor.set_physics_process(false)
	return actor

func text_of(node: Node) -> String:
	if node.is_queued_for_deletion(): return ""
	var text := str(node.text) if node is Label or node is Button else ""
	for child in node.get_children(): text += "\n" + text_of(child)
	return text

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") or OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty():
		get_tree().quit(2);return
	call_deferred("run")

func run() -> void:
	var m:=MetaProgress
	m.reset_save();m.currency.credits=10000000
	BattleRequest.reset()
	var excluded: Array=["ENGINEER","SENGINEER","GHOST","TANY","CCOMAND","SPY","SHK","SQD","MTNK","SNIPE","FV","ORCA","BEAG","DRON","MGTK","TNKD","JUMPJET","CMIN","R3HARBINGER"]
	for id in excluded:
		m.unit_levels[id]={"skill":7}
		var cash:=m.balance("credits")
		check(m.skill_training_benefits(id).is_empty() and not m.buy_unit_upgrade(id,"skill") and m.balance("credits")==cash,"cancelled upgrade hidden and cannot charge "+id)
	m.save();m.load_save()
	for id in excluded: check(m.unit_level(id,"skill")==0,"retired paid rank removed after refund "+id)
	for id in Training.PROFILES:
		check(m.skill_training_benefits(id).is_empty() and not m.can_buy_unit_upgrade(id,"skill"),"retired purchase hidden "+id)
	# Every generic card is exercised through the actual unit cast/passive consumer.
	for card in GameData.skills:
		if card.has("allowed_units") or card.id=="ap_deploy":continue
		var id: String="CMIN" if card.effect=="passive_harvest" else "GGI"
		m.unlock_skill(card.id);m.academy.get_or_add("levels",{})[card.id]=2
		m.unit_loadouts[id]={"active":[card.id if card.type=="active" else ""],"passive":card.id if card.type=="passive" else ""}
		var baseline: Array=[]
		for rank in [0,20]:
			m.unit_levels[id]={"skill":rank};BattleRequest.freeze_combat_context()
			var actor:=spawn(id)
			var actual: Array=[]
			if card.type=="active":
				var slot:=UnitSkillLayout.find(actor,card.id)
				actor.hp=actor.max_hp*0.1
				var foe:=spawn("E2",actor.position+Vector2.ONE,"enemy")
				check(slot>=0 and actor.use_ability(slot),"real card cast "+card.id+str(rank))
				actual=[actor.ability_at(slot).cd_left,actor.hp,foe._stun_timer,actor.buff_value("attack"),actor.buff_value("defense"),actor.buff_value("speed")]
				foe.free()
			else:actual=[actor.bonuses.attack_bonus,actor.bonuses.defense_bonus,actor.move_speed,actor.sight,actor.harvest_rate,actor._regen_frac]
			if rank==0:baseline=actual
			else:check(actual==baseline,"actual card effects independent "+card.id)
			actor.free()
	m.unit_loadouts={}
	grant_native_max()
	BattleRequest.freeze_combat_context()
	for id in ["E1","GGI"]:
		var actor:=spawn(id)
		var base:float=actor.bonuses.defense_bonus
		actor._deployed=true;actor._recompute_bonuses()
		check(is_equal_approx(actor.bonuses.defense_bonus,base*float(actor.data.deploy_defense_mult)*2.2),"deployed defense consumer "+id)
		actor._deployed=false;actor._recompute_bonuses()
		check(is_equal_approx(actor.bonuses.defense_bonus,base),"standing defense unchanged "+id)
		actor.free()
	var chopper:=spawn("SCHP")
	for rank in 4:
		BattleRequest.combat_context.unit_talents.SCHP.native_siege_range=rank
		check(is_equal_approx(chopper.deployed_weapon().range,float(chopper.data.deployed_weapon.range)+(rank+1)*0.5*55),"deployed range capped +2 cells "+str(rank))
		check(chopper.weapon.range==chopper.data.weapon.range,"flight range unchanged")
	chopper.free()
	for id in ["BORIS","IVAN","CIVAN","AMCV","SMCV"]:
		var actor:=spawn(id)
		if id=="BORIS":
			for rank in [0,2]:
				actor.veteran_level=rank;actor.special.airstrike_wing=[]
				Soviet.advance_sortie_reload(actor,0)
				check(is_equal_approx(actor.special.airstrike_cd,(100.0 if rank==0 else 50.0)/15),"Boris recharge no longer trained "+str(rank))
		elif id in ["IVAN","CIVAN"]:
			var target:=spawn("MTNK",actor.position+Vector2(30,0),"enemy")
			Soviet.shoot(actor,target,actor.weapon)
			check(is_equal_approx(target.special.ivan_bomb.left,15),"real planted fuse floor "+id)
			target.free()
		else:
			actor.special.mcv_repack_left=3.0;Transition.tick(actor,0.5)
			check(is_equal_approx(actor.special.mcv_repack_left,2.0),"MCV fold animation clock "+id)
		actor.free()
	var ivan:=spawn("IVAN")
	for rank in 4:
		BattleRequest.combat_context.unit_talents.IVAN.native_fuse=rank
		check(is_equal_approx(Training.fuse(ivan,30),30.0-3.75*(rank+1)),"Ivan gradual fuse and hard floor "+str(rank))
	ivan.free()
	var grizzly:=spawn("MTNK")
	var smoke:=UnitSkillLayout.find(grizzly,"ap_smoke")
	check(smoke>=0 and grizzly.use_ability(smoke),"stock Q casts after redesign")
	check(is_equal_approx(grizzly.buff_value("defense"),float(GameData.get_skill("ap_smoke").value)),"stock Q is not trained by retained cancelled rank")
	grizzly.free()
	var night:=spawn("SHAD")
	night.logistics.air_lift=0;night.flight.altitude(1,0.1)
	check(is_equal_approx(night.logistics.air_lift,night.flight.climb/night.flight.height*0.1),"Nighthawk actual lift speed")
	night.free()
	var future:=spawn("R3FUTURE")
	check(Riot.begin(future,future.position+Vector2(40,0)) and is_equal_approx(future.special.ra3_riot_cd,Riot.cooldown()/2.0),"Future actual riot cooldown")
	future.free()
	var timing_actor:=spawn("R3FUTURE")
	BattleRequest.combat_context.native_training_version=3
	for rank in [0,1,8,16,19,20,99]:
		timing_actor.skill_power=1+0.06*rank
		var duration:=15.0*(1.0-minf(rank,20)*0.025)
		check(is_equal_approx(Training.projected(15,"down",timing_actor.skill_power),duration),"conservative preview "+str(rank))
		Riot.begin(timing_actor,timing_actor.position+Vector2(40,0))
		check(is_equal_approx(timing_actor.special.ra3_riot_cd,duration),"real cooldown floor and progression "+str(rank))
	timing_actor.skill_power=2.2
	BattleRequest.combat_context.native_training_version=1
	Riot.begin(timing_actor,timing_actor.position+Vector2(40,0))
	check(is_equal_approx(timing_actor.special.ra3_riot_cd,15/2.2),"v1 native battle preserves old cooldown")
	BattleRequest.combat_context.native_training_version=4
	timing_actor.free()
	var dog:=spawn("DOG")
	m.unit_talents.DOG.native_attack_cd=0
	check(is_equal_approx(Training.scale(dog),2.2),"ongoing battle keeps frozen talent rank")
	dog.free()
	m.set_effect_enabled("talent","native_deploy_def","GGI",false);BattleRequest.freeze_combat_context()
	var disabled:=spawn("GGI")
	check(Training.scale(disabled)==1,"disabled talent has no effect")
	disabled.free();m.set_effect_enabled("talent","native_deploy_def","GGI",true)
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui);ui._unit_sel="DRON";ui._rebuild_unit_detail()
	check(not text_of(ui.unit_detail).contains("技能强化   Lv."),"real UI hides cancelled upgrade")
	ui._unit_sel="SCHP";ui._rebuild_unit_detail()
	check(text_of(ui.unit_detail).contains("攻城校准") and text_of(ui.unit_detail).contains("3 级"),"real UI shows new native range talent")
	ui.free()
	var cash:=m.balance("credits")
	check(not m.buy_unit_upgrade("DOG","skill") and m.balance("credits")==cash,"retired purchase never charges")
	BattleRequest.configure_skirmish(MatchRules.RA2,{});BattleRequest.freeze_combat_context()
	var classic:=spawn("GGI")
	check(Training.scale(classic)==1,"RA2 mode has no native progression")
	classic.free()
	await world_cases()
	var audit: Array=[]
	for id in GameData.unit_index:audit.append({"unit":id,"benefits":m.skill_training_benefits(id)})
	await get_tree().process_frame
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"unit_audit":audit}))
	print("SKILL_TRAINING checks=",checks.size()," failed=",failed)
	get_tree().quit(failed)

func world_cases() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":4000,"country":"美国","fog_of_war":false})
	grant_native_max()
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	battle.water_rects=[];battle.path_service.set_water([])
	var chrono:=spawn("CLEG",Vector2(2000,2000))
	check(AlliedAbilities.teleport(chrono,Vector2(2220,2000)),"chrono real teleport accepted")
	var rules:Dictionary=GameData.allied_capabilities.general
	var expected:float=maxf(float(rules.ChronoMinimumDelay),4.0*256/float(rules.ChronoDistanceFactor))/15/2.0
	check(is_equal_approx(chrono.special.get("chrono_left",-1),expected),"chrono actual recovery reduced")
	for id in ["LCRF","SAPC","SHAD"]:
		var transport:=spawn(id,Vector2(2000,2500))
		var passenger:=spawn("E1",transport.position)
		transport.logistics.passengers.append(passenger);passenger.set_stowed(transport)
		transport.logistics.air_lift=0;transport.logistics.unloading=true
		transport.logistics.tick(0.01)
		check(passenger.embarked_in==null and is_equal_approx(transport.logistics.unload_timer,0.35),"actual unload interval "+id)
	var deso:=spawn("DESO",Vector2(2600,2600))
	Soviet.add_radiation(battle,deso.position,3,500,"ally",deso)
	check(is_equal_approx(battle.allied_state.rad_sites[-1].training_damage,1.12),"radiation site records emitter factor")
	# Actual weapon timers and range decisions, not just factor helper tests.
	for id in ["DOG","SOV_DOG"]:
		var dog:=spawn(id,Vector2(2600,2200))
		var enemy:=spawn("E2",dog.position+Vector2(20,0),"enemy")
		dog.attack_target=enemy;dog.attack_ordered=true;dog.hull_angle=0;dog.turret_angle=0
		check(dog._try_fire_ready() and is_equal_approx(dog._cd_timer,float(dog.weapon.cooldown)/2.0),"real dog attack cooldown "+id)
	var tesla:=spawn("R3TESLA",Vector2(2800,1800))
	tesla.special.soviet_mode=true
	var close:=spawn("MTNK",tesla.position+Vector2(150,0),"enemy")
	var far:=spawn("MTNK",tesla.position+Vector2(170,0),"enemy")
	preload("res://scripts/units/ra3_soviet.gd").tick(tesla,0.01)
	check(close._stun_timer>1 and far._stun_timer==0,"actual trained EMP radius includes 150 excludes 170")
	var mirage:=spawn("R3MIRAGE",Vector2(3200,2400))
	mirage.special.ra3_field=true
	var covered:=spawn("MTNK",mirage.position+Vector2(500,0))
	var uncovered:=spawn("MTNK",mirage.position+Vector2(590,0))
	check(Ra3Mirage.field_conceals(covered,"enemy") and not Ra3Mirage.field_conceals(uncovered,"enemy"),"actual cloak radius expands to 577.5")
	var apoc:=spawn("R3APOC",Vector2(2800,2800))
	var victim:=spawn("MTNK",apoc.position+Vector2(200,0),"enemy")
	apoc.special.soviet_mode=true;apoc.special.harpoon_target=victim
	apoc.attack_target=victim;apoc.attack_ordered=true;apoc.turret_angle=0;apoc.hull_angle=0
	await get_tree().physics_frame
	var before:=victim.position
	preload("res://scripts/units/ra3_soviet.gd").tick(apoc,0.1)
	check(is_equal_approx(victim.position.distance_to(before),13.2),"actual harpoon pulls 132 pixels per second")
	# Landing attack covers the enlarged radius, retaining the original crush core.
	var reaper:=spawn("R3REAPER",Vector2(3000,3200))
	var landing:=Vector2(3100,3200)
	var splash:=spawn("MTNK",landing+Vector2(150,0),"enemy")
	var outside:=spawn("MTNK",landing+Vector2(180,0),"enemy")
	var splash_hp:=splash.hp
	var outside_hp:=outside.hp
	reaper.special.walker_jump=preload("res://scripts/units/ra3_soviet.gd").Leap.create(reaper.position,landing)
	preload("res://scripts/units/ra3_soviet.gd").tick(reaper,10)
	check(splash.hp<splash_hp and outside.hp==outside_hp,"actual leap damages inside 165 pixel radius only")
	# Compare real splitting damage against an untrained shot; raw RA2 damage reads weapon.damage.
	var prism:=spawn("SREF",Vector2(2800,800))
	var main:=spawn("HTNK",Vector2(2900,800),"enemy")
	var secondary:=spawn("HTNK",Vector2(3000,800),"enemy")
	var damage_samples: Array=[]
	for power in [1.0,2.2]:
		BattleRequest.combat_context.unit_talents.SREF={} if power==1.0 else {"native_prism":3}
		secondary.hp=secondary.max_hp
		var shot:=Projectile.new()
		shot.setup(prism.position,main,prism.weapon,float(prism.weapon.damage),prism.bonuses,"ally",prism)
		battle.projectiles_root.add_child(shot)
		shot.target_point=main.position
		shot._spawn_splinters()
		damage_samples.append(secondary.max_hp-secondary.hp)
		shot.queue_free()
	check(damage_samples[0]>0 and is_equal_approx(damage_samples[1],damage_samples[0]*2.2),"real prism child damage consumes training exactly once")
	for id in ["AMCV","SMCV"]:
		var mcv:=spawn(id,Vector2(1500,3000))
		var yard=battle._place_building("GACNST" if id=="AMCV" else "NACNST","ally",Vector2(1500,3000),true)
		Transition.deploying(yard,mcv,mcv.position)
		yard._buildup_play=0.0;yard._process(0.1)
		check(is_equal_approx(yard._buildup_play,0.20),"real yard unfolding animation clock "+id)
		battle.buildings.erase(yard);yard.free()
	var snapshot=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	check(BattleRequest.combat_context.get("native_training_version")==4,"native rules marker survives actual battle snapshot")
	check(is_equal_approx(battle.allied_state.rad_sites[-1].training_damage,1.12),"radiation factor survives actual battle snapshot")
	screen.free();battle=null

func grant_native_max() -> void:
	for id in Training.PROFILES:
		var talent:=Training.talent_id(id)
		if not talent.is_empty():MetaProgress.unit_talents[id]={talent:3}
