extends "res://tests/base_recovery_regression.gd"
const Relief = preload("res://scripts/world/air_relief.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for multiple in [false,true]:
			var config={"map_size":2400,"enemy_base":"soviet","fog_of_war":false}
			if multiple: config.merge({"houses":[{"country":"美国","team":1},{"country":"苏俄","team":2},{"country":"苏俄","team":1}],"map_layout":"yr_crctbrd"})
			BattleRequest.configure_skirmish(mode,config)
			screen=load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode=Node.PROCESS_MODE_DISABLED
			battle=screen.battle
			for group in ["obstacles","resource_nodes"]:
				for node in get_tree().get_nodes_in_group(group): node.free()
			for unit in battle.units: unit.free()
			battle.units.clear()
			battle.water_rects.clear()
			battle.path_service.water_rects.clear()
			prefix=mode+" multi="+str(multiple)+": "
			await exercise("ai2" if multiple else "enemy")
			await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("AIR RELIEF checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise(owner: String) -> void:
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle.path_service.native_map_id=""
	battle.path_service.bridge_decks.clear()
	battle._refresh_pathing()
	var enemy: String = "enemy" if owner=="ai2" else "ally"
	var victim=battle.spawn_unit("ZEP",owner,Vector2(1200,1200))
	victim.logistics.air_lift=1.0
	var attacker=battle.spawn_unit("FV",enemy,Vector2(1300,1200))
	var state:Dictionary=battle.ai_decisions(owner)
	var ai={"battle":battle,"house_id":owner,"ai_state":state}
	var helpers:Array=[]
	for i in 7: helpers.append(battle.spawn_unit("HTNK",owner,Vector2(1100,1100+i*36)))
	var miner=battle.spawn_unit("HARV",owner,Vector2(1180,1200))
	var player=battle.spawn_unit("HTNK","ally",Vector2(1180,1180))
	var busy=battle.spawn_unit("HTNK",owner,Vector2(1180,1230))
	var other=battle.spawn_unit("E1",enemy,Vector2(1500,1400))
	busy.attack_target=other
	var distant=battle.spawn_unit("HTNK",owner,Vector2(2200,2200))
	victim.receive_hit(1,"bullet",{},attacker)
	check(state.get(Relief.ALERTS,{}).has(victim),prefix+"real aircraft damage creates own-house distress call")
	Relief.tick(ai,0.01)
	var sent: Array=helpers.filter(func(u):return u.special.has(Relief.ASSIGNMENT))
	check(sent.size()==4,prefix+"bounded nearest four responders",[sent.size(),Relief.eligible(battle,helpers[0],victim,attacker),helpers[0].attack_domain_valid(attacker),battle.path_service.zone_at(helpers[0].position),battle.path_service.zone_at(attacker.position),BattleRequest.house_teams])
	check(sent.all(func(u):return u.attack_target==attacker and u.attack_ordered),prefix+"ground escorts attack the actual anti-air attacker")
	check(not miner.special.has(Relief.ASSIGNMENT) and not player.special.has(Relief.ASSIGNMENT),prefix+"miners and player orders are untouched")
	check(busy.attack_target==other and not busy.special.has(Relief.ASSIGNMENT) and not distant.special.has(Relief.ASSIGNMENT),prefix+"engaged and distant units are not pulled away")
	var first=sent[0] if not sent.is_empty() else helpers[0]
	battle.ai_dispatch.submit(battle,first,{"kind":"rally","point":Vector2(300,300)})
	check(first.attack_target==attacker,prefix+"assembly cannot immediately overwrite relief")
	var before:Vector2=first.move_target
	for i in 20:
		Relief.alert(victim,attacker)
		Relief.tick(ai,0.01)
	check(helpers.filter(func(u):return u.special.has(Relief.ASSIGNMENT)).size()==4 and first.move_target==before,prefix+"rapid hits merge without extra responders or repeated commands")
	var codec=BattleSaves.Snapshot.new()
	var snapshot=codec.capture(battle)
	check(codec.error.is_empty() and BattleSaves.validate(snapshot).is_empty(),prefix+"alerts and assignments use save-compatible actor references",[codec.error,BattleSaves.validate(snapshot)])
	attacker.special.echo_cloaked=true
	Relief.tick(ai,1.0)
	check(not state.has(Relief.ALERTS) and Relief.assignment(battle,first).is_empty(),prefix+"hidden attacker clears tracking and mission")
	attacker.special.erase("echo_cloaked")
	for unit in helpers:
		unit.special.erase(Relief.ASSIGNMENT)
		unit.order_stop()
	var air_attacker=battle.spawn_unit("JUMPJET",enemy,Vector2(1280,1200))
	air_attacker.logistics.air_lift=1.0
	var aa=battle.spawn_unit("HTK",owner,Vector2(1120,1200))
	victim.receive_hit(1,"bullet",{},air_attacker)
	Relief.tick(ai,1.0)
	check(aa.attack_target==air_attacker and aa.special.has(Relief.ASSIGNMENT),prefix+"air attacker summons anti-air responder")
	check(helpers.all(func(u):return not u.special.has(Relief.ASSIGNMENT)),prefix+"ground-only guns never receive anti-air chase orders")
	var plane=battle.spawn_unit("ORCA",owner,Vector2(1170,1200))
	plane.logistics.air_state="returning"
	plane.logistics.ammo=0
	check(not Relief.eligible(battle,plane,victim,attacker),prefix+"empty returning aircraft continues rearming")
	plane.logistics.air_state="parked"
	plane.logistics.ammo=plane.logistics.ammo_max
	check(Relief.eligible(battle,plane,victim,attacker),prefix+"fully armed aircraft may join ground relief")
	victim._anim+=7
	Relief.tick(ai,1.0)
	check(not state.has(Relief.ALERTS),prefix+"stale alerts expire without new hits")
	aa._anim+=7
	check(Relief.assignment(battle,aa).is_empty(),prefix+"short lease ends and ordinary AI regains control")
	aa.order_stop()
	battle.ai_dispatch._apply(battle,aa,{"kind":"attack","target":air_attacker,"air_relief":true})
	check(aa.attack_target==null,prefix+"expired relief command is discarded even after waiting in dispatcher")
	var n:int=state.get(Relief.ALERTS,{}).size()
	Relief.alert(player,attacker)
	Relief.alert(victim,busy)
	check(state.get(Relief.ALERTS,{}).size()==n,prefix+"ground/player victims and friendly fire do not call AI help")
	for id in ["SHAD","SCHP","ORCA"]:
		var flyer=battle.spawn_unit(id,owner,Vector2(1200,1250))
		flyer.logistics.air_lift=1.0
		flyer.receive_hit(1,"bullet",{},attacker)
		check(state.get(Relief.ALERTS,{}).has(flyer),prefix+id+" actual damage calls for relief")
	plane.logistics.air_lift=0.0
	plane.receive_hit(1,"bullet",{},attacker)
	check(state.get(Relief.ALERTS,{}).has(plane),prefix+"landed aircraft can also request protection")
	for i in 10:
		var flyer=battle.spawn_unit("ZEP",owner,Vector2(1400,1400+i*20))
		flyer.logistics.air_lift=1.0
		Relief.alert(flyer,attacker)
	check(state.get(Relief.ALERTS,{}).size()==Relief.MAX_ALERTS,prefix+"distress queue stays bounded under mass air damage")
	var times:Array=[]
	for i in 100:
		var begin=Time.get_ticks_usec()
		Relief.tick(ai,1.0)
		times.append((Time.get_ticks_usec()-begin)/1000.0)
	times.sort()
	checks.append({"name":prefix+"bounded relief pass timing ms","passed":true,"p95":times[94],"max":times.back()})
	var serialized=codec.capture(battle)
	codec.restore(battle,serialized)
	var restored:Dictionary=battle.ai_decisions(owner)
	check(restored.get(Relief.ALERTS,{}).size()==Relief.MAX_ALERTS,prefix+"restored call queue retains actor identities")
	var record_count:=0
	for unit in battle.units:
		if not Relief.assignment(battle,unit).is_empty(): record_count+=1
	check(record_count>0 and record_count<=Relief.MAX_RESPONDERS,prefix+"restored helper leases remain valid and bounded",record_count)
	await get_tree().process_frame
