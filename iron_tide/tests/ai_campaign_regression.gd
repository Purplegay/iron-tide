extends "res://tests/base_recovery_regression.gd"
const Tactics = preload("res://scripts/world/skirmish_tactics.gd")
const Campaign = preload("res://scripts/world/skirmish_campaign.gd")
const Counter = preload("res://scripts/units/ai_counterfire.gd")
const Operations = preload("res://scripts/world/skirmish_operations.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	check(is_equal_approx(Tactics.PROCUREMENT.GHOST,0.35*0.25) and is_equal_approx(Tactics.PROCUREMENT.IVAN,0.35*0.25),"SEAL and Ivan lose 75 percent of their current weights")
	check(is_equal_approx(Tactics.PROCUREMENT.APOC,1.5*1.3) and is_equal_approx(Tactics.PROCUREMENT.SREF,1.5*1.3),"Apocalypse and Prism weights increase 30 percent")
	for id in ["ENGINEER","SENGINEER","SPY","CMIN","AMCV"]:
		check(not Tactics.combat_product(GameData.get_unit(id)),id+" excluded from generic combat procurement")
	for id in ["GHOST","IVAN","MTNK","APOC","SREF","V3"]:
		check(Tactics.combat_product(GameData.get_unit(id)),id+" remains a combat candidate")
	for multiple in [false,true]: await exercise(multiple)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("CAMPAIGN checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise(multiple: bool) -> void:
	var config={"map_layout":"yr_crctbrd","opening":"prebuilt","map_size":2400,"enemy_country":"美国","difficulty":2,"fog_of_war":false}
	if multiple: config.houses=[{"country":"美国","team":1},{"country":"美国","team":2,"difficulty":2},{"country":"苏俄","team":1}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false
	clear_units()
	var ai = battle.house_controllers.enemy if multiple else battle.skirmish_ai
	var state: Dictionary=ai.ai_state
	var home: Vector2=ai.base_center
	var miners=[battle.spawn_unit("CMIN","enemy",home+Vector2(50,50)),battle.spawn_unit("CMIN","enemy",home+Vector2(100,50))]
	var engineer=battle.spawn_unit("ENGINEER","enemy",home+Vector2(150,50))
	for i in 28:
		var unit=battle.spawn_unit("MTNK","enemy",home+Vector2((i%8)*40,(i/8)*40+160))
		ai.unit_produced(unit)
	check(battle.ai_living_count("enemy")==31 and Campaign.wave(ai).is_empty(),"31 living never triggers the initial campaign")
	var last=battle.spawn_unit("MTNK","enemy",home+Vector2(280,280))
	ai.unit_produced(last)
	if multiple:
		ai._form_wave(state)
		while state.has("attack_dispatch"): ai.dispatch_attacker(state)
	else: ai._launch_attack()
	var guards=battle.units.filter(func(u):return u.side=="enemy" and u.special.get(Campaign.ROLE)=="guard")
	var attack=battle.units.filter(func(u):return u.side=="enemy" and u.special.get(Campaign.ROLE)=="attack")
	check(state.get("campaign_started",false) and guards.size()==10 and attack.size()==19,"32 total deploys 19 fighters and keeps ten plus three support units",[guards.size(),attack.size()])
	check(attack.all(func(u):return u.has_move_order and u.attack_move),"initial attackers receive real attack-move orders")
	check(guards.all(func(u):return not u.attack_move) and not engineer.special.has(Campaign.ROLE) and not miners[0].special.has(Campaign.ROLE),"guards and economic units stay home")
	guards[0]._dead=true
	guards[0].hp=0
	battle.invalidate_ai_population()
	var replacement=battle.spawn_unit("MTNK","enemy",home)
	ai.unit_produced(replacement)
	check(replacement.special.get(Campaign.ROLE)=="guard" and Campaign.guards(ai)==10,"lost home guard is replaced before further offensive reinforcements")
	var extra=[]
	for i in 10:
		var unit=battle.spawn_unit("MTNK","enemy",home+Vector2(i*20,0))
		ai.unit_produced(unit)
		extra.append(unit)
	check(extra.filter(func(u):return u.special.get(Campaign.ROLE)=="attack").size()==10 and extra.filter(func(u):return u.special.get(Campaign.ROLE)=="guard").size()==0,"next ten fighters all reinforce offense after ten guards")
	var idle_raider=extra[0]
	idle_raider.order_stop()
	idle_raider.special.brutal_idle=8.0
	state.erase("brutal_alarm")
	ai.Brutal.tick(ai,2.1)
	check(not idle_raider.has_move_order and state.get("campaign_due",false),"brutal idle recovery requests a new offensive wave instead of recalling raider")
	state.brutal_alarm={"life":20.0,"point":home+Vector2(500,0),"air":false}
	ai.Brutal.tick(ai,2.1)
	check(not idle_raider.special.has("brutal_relief_at"),"brutal base alarm leaves offensive role to the campaign")
	state.erase("brutal_alarm")
	var codec=BattleSaves.Snapshot.new()
	var saved:Dictionary=codec.capture(battle)
	check(BattleSaves.validate(saved).is_empty(),"campaign roles and alternation are valid save data")
	codec.restore(battle,saved)
	ai=battle.house_controllers.enemy if multiple else battle.skirmish_ai
	check(ai.ai_state.get("campaign_started",false) and Campaign.guards(ai)==10,"save restore retains campaign and ten guards")
	ai.ai_state.campaign_next_attack=false # Legacy alternating saves must no longer accumulate guards.
	var next=battle.spawn_unit("MTNK","enemy",home)
	ai.unit_produced(next)
	check(next.special.get(Campaign.ROLE)=="attack","legacy guard alternation is ignored after restore")
	while battle.ai_living_count("enemy")<64:
		var u=battle.spawn_unit("MTNK","enemy",home)
		if u==null: break
	check(battle.ai_living_count("enemy")==64 and battle.spawn_unit("MTNK","enemy",home)==null,"64 per-house cap remains absolute")
	reserve_rebalance(ai)
	clear_units()
	counterfire(ai)
	var plane=battle.spawn_unit("ORCA","enemy",home)
	var boat=battle.spawn_unit("DEST","enemy",home)
	plane.special[Campaign.ROLE]="guard"
	boat.special[Campaign.ROLE]="guard"
	var close=battle.spawn_unit("MTNK","ally",home+Vector2(30,30))
	var faraway=battle.spawn_unit("MTNK","ally",home+Vector2(2000,2000))
	check(Campaign.eligible(ai,plane) and Campaign.eligible(ai,boat),"armed planes and ships participate in reinforcement role assignment")
	check(Campaign.defensive_contacts(ai,plane,[close,faraway])==[close] and Campaign.defensive_contacts(ai,boat,[close,faraway])==[close],"reserved air and naval forces only pick nearby threats")
	plane.special[Campaign.ROLE]="attack"
	check(Campaign.defensive_contacts(ai,plane,[close,faraway]).size()==2,"offensive aircraft retain their normal distant sortie targets")
	await finish()

func reserve_rebalance(ai) -> void:
	clear_units()
	ai.ai_state.campaign_started=true
	ai.ai_state.erase("brutal_alarm")
	var defenders:Array=[]
	for i in 20:
		var unit=battle.spawn_unit("MTNK","enemy",ai.base_center+Vector2(i*20,0))
		unit.order_stop()
		unit.special[Campaign.ROLE]="guard" if i<18 else "attack"
		defenders.append(unit)
	for i in 20:
		var reinforcement=battle.spawn_unit("MTNK","enemy",ai.base_center+Vector2(i*20,160))
		reinforcement.special[Campaign.ROLE]="attack"
	var target=battle.spawn_unit("HTNK","ally",ai.base_center+Vector2(300,100))
	defenders[17].attack_target=target
	ai.ai_state.brutal_alarm={"life":20.0}
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==18,"active base alarm preserves reserves")
	ai.ai_state.brutal_alarm={"life":20.0,"base":true}
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==18,"explicit building alarm preserves reserves")
	for offset in [Vector2.ZERO,Vector2(Tactics.BASE_DEFENSE_RADIUS,0)]:
		ai.ai_state.brutal_alarm={"life":20.0,"base":false,"point":ai.base_center+offset}
		Campaign.rebalance(ai)
		check(Campaign.guards(ai)==18,"field combat inside or at home defense radius preserves reserves")
	ai.ai_state.brutal_alarm={"life":20.0,"base":false}
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==18,"field alarm with missing position conservatively preserves reserves")
	ai.ai_state.brutal_alarm={"life":20.0,"base":false,"point":ai.base_center+Vector2(2400,0)}
	defenders[16].special.ai_dispatch_pending=true
	defenders[15].special.brutal_relief_at=ai.base_center+Vector2(1000,1000)
	defenders[16].special.brutal_relief_at=ai.base_center+Vector2(2400,0)
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==10,"remote field alarm permits surplus home guards to reinforce")
	check(defenders[16].special[Campaign.ROLE]=="guard","assigned relief guard is not diverted")
	check(defenders[15].special[Campaign.ROLE]=="attack" and not defenders[15].special.has("brutal_relief_at"),"stale idle relief marker cannot permanently lock a surplus guard")
	ai.ai_state.erase("brutal_alarm")
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==10,"reserve target remains ten even with forty fighters")
	check(defenders[17].special[Campaign.ROLE]=="guard" and defenders[17].attack_target==target,"engaged guard keeps its role and target")
	check(defenders[0].special[Campaign.ROLE]=="guard","nearest home defenders are retained")
	for i in range(6,20): defenders[i]._dead=true;defenders[i].hp=0
	Campaign.rebalance(ai)
	check(Campaign.guards(ai)==6,"six surviving home guards are never drained")

func clear_units() -> void:
	for u in battle.units: u.free()
	battle.units.clear()
	battle.invalidate_ai_population()

func counterfire(ai) -> void:
	var u=battle.spawn_unit("MTNK","enemy",Vector2(1000,1000))
	var attacker=battle.spawn_unit("HTNK","ally",Vector2(1070,1000))
	var primary=battle.spawn_unit("HTNK","ally",Vector2(1200,1000))
	u.attack_target=primary
	u.attack_ordered=true
	u.has_move_order=true
	u.move_target=Vector2(1500,1000)
	u.velocity=Vector2(25,0)
	u.receive_hit(1,"bullet",{},attacker)
	u._process_combat(0.016)
	check(u.attack_target==attacker and u.velocity==Vector2.ZERO and u.has_move_order and u.move_target==Vector2(1500,1000),"hit AI stops locally and answers shooter without discarding route")
	attacker.position=Vector2(2200,1000)
	check(not Counter.update(u) and u.attack_target==primary and u.attack_ordered,"out-of-range attacker does not drag AI away; original target resumes")
	var player=battle.spawn_unit("MTNK","ally",Vector2(1050,1050))
	player.receive_hit(1,"bullet",{},u)
	player.attack_target=primary
	check(not Counter.update(player) and player.attack_target==primary,"player orders are not affected")
	u._return_timer=6
	u.special.retaliation_target=player
	u._refresh_target()
	check(u.attack_target==player,"counterfire takes priority over current explicit AI focus")
	u.order_stop()
	check(not u.special.has(Counter.RESUME) and u.attack_target==null,"fresh stop discards saved counterfire focus")
	var near=battle._place_building("GAPOWR","ally",Vector2(1120,1000),true)
	var far=battle._place_building("GAWEAT","ally",Vector2(2200,1800),true)
	for site in [near,far]: site._buildup_play=-1
	check(Operations.preferred(ai,u,[far,near])==near,"nearby building beats distant strategic objective")
	check(Tactics.attack_position(ai,[u]).distance_to(near.position)<1,"campaign chooses nearby visible building rather than distant base")
	ai._unit_pool.assign(["ENGINEER"])
	check(Tactics.production(ai).is_empty(),"combat production cannot buy an engineer even if it is the only affordable candidate")
