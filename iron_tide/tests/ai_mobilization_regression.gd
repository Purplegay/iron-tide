extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for multiplayer in [false,true]:
		await exercise(multiplayer)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)

func exercise(multiple: bool) -> void:
	var config := {"map_layout":"yr_crctbrd","opening":"prebuilt","enemy_country":"美国","difficulty":2,"fog_of_war":false}
	if multiple:
		config.houses = [{"country":"美国","team":1},{"country":"美国","team":2,"difficulty":2},{"country":"苏俄","team":1}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	battle.paused = false
	get_tree().paused = false
	var ai = battle.house_controllers.enemy if multiple else battle.skirmish_ai
	var state: Dictionary = ai.ai_state
	var factory = battle.buildings.filter(func(b): return b.side=="enemy" and b.building_id=="GAPILE")[0]
	var normal: float = factory.production_work_rate("E1")
	var construction: float = factory.construction_work_rate()
	var soldiers := []
	var home: Vector2 = ai.base_center
	while battle.ai_living_count("enemy") < 63:
		var u = battle.spawn_unit("E1","enemy",home+Vector2(soldiers.size()%8,soldiers.size()/8)*30)
		soldiers.append(u)
	check(factory.enqueue("E1") and not state.has("full_sortie_due"),"queued 64th unit does not mobilize")
	factory._process(120)
	check(battle.ai_living_count("enemy")==64 and state.get("full_sortie_due",false),"actual 64th unit calls for attack")
	for soldier in soldiers:
		soldier.order_stop()
		soldier.special.ai_assembly_retry = true
	state.brutal_alarm = {"point":home,"life":12.0}
	ai._army.clear()
	ai._attack_t = 100
	ai._train_t = 100
	if multiple:
		state.think = 0
		state.ops_left = 100
		state.attack = 100
		state.defending = true
	ai._process(0.1)
	if multiple:
		check(state.has("attack_dispatch"),"full house forms offensive without reaching assembly")
		while state.has("attack_dispatch"): ai.dispatch_attacker(state)
	check(soldiers.filter(func(u):return u.has_move_order and u.attack_move and u.move_target.distance_to(ai.objective()) < u.position.distance_to(ai.objective())).size()>40,"main force advances toward enemy without waiting for rally or attack clock")
	var marcher = soldiers.filter(func(u):return u.has_move_order and u.attack_move).back()
	var start_pos: Vector2 = marcher.position
	marcher.process_mode = Node.PROCESS_MODE_ALWAYS
	marcher.set_process(false)
	marcher.set_physics_process(false)
	for tick in 180:
		await get_tree().physics_frame
		marcher._physics_process(1.0/60)
		if marcher.position.distance_to(start_pos)>50: break
	check(marcher.position.distance_to(start_pos)>50, "outgoing infantry physically leaves its waiting position",marcher.position)
	for living in range(63,31,-1):
		var casualty = soldiers.pop_back()
		casualty.receive_hit(1000000)
		if living==33: check(is_equal_approx(factory.production_work_rate("E1"),normal),"no boost before half strength")
	check(battle.ai_living_count("enemy")==32 and is_equal_approx(factory.production_work_rate("E1"),normal*1.15),"half-strength hard AI trains fifteen percent faster")
	check(is_equal_approx(factory.construction_work_rate(),construction) and is_equal_approx(battle.ai_unit_build_factor("ally"),1.0),"structures and player production unaffected")
	if multiple: check(is_equal_approx(battle.ai_unit_build_factor("ai2"),battle.ai_build_factor("ai2")),"other house is independent")
	var codec = BattleSaves.Snapshot.new()
	var saved: Dictionary = codec.capture(battle)
	check(BattleSaves.validate(saved).is_empty(),"replenishment snapshot validates")
	codec.restore(battle,saved)
	check(is_equal_approx(battle.ai_unit_build_factor("enemy"),battle.ai_build_factor("enemy")*1.15),"same reinforcement bonus survives restore")
	while battle.ai_living_count("enemy") < 64:
		var u = battle.spawn_unit("E1","enemy",home)
		if u==null: break
	check(battle.ai_living_count("enemy")==64 and is_equal_approx(battle.ai_unit_build_factor("enemy"),battle.ai_build_factor("enemy")),"return to 64 ends boost")
	var after: Array = battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="E1" and battle.actor_alive(u))
	for i in 32: after[i].receive_hit(1000000)
	check(is_equal_approx(battle.ai_unit_build_factor("enemy"),battle.ai_build_factor("enemy")*1.15),"second cycle grants the same non-stacking bonus")
	await finish()
