extends "res://tests/base_recovery_regression.gd"

func next_frame() -> void:
	var frame := Engine.get_process_frames()
	while frame == Engine.get_process_frames(): await get_tree().process_frame

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var rows := [{"country":"美国","team":1},{"country":"美国","team":2},{"country":"苏俄","team":1},{"country":"美国","team":2}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":"yr_crctbrd","fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	battle.paused = false
	get_tree().paused = false
	var units := []
	var home: Vector2 = battle.player_start()
	var player = battle.spawn_unit("MTNK","ally",home)
	for i in 168:
		var u = battle.spawn_unit("MTNK",["enemy","ai2","ai3"][i%3],home+Vector2(i%16,i/16)*26)
		u.order_stop()
		units.append(u)
	await next_frame()
	var grid = battle.neighborhood
	var origin:Vector2=player.global_position
	var remote:=origin+Vector2(1400,1000)
	player.global_position=remote
	check(grid.nearby(remote,25).has(player) and not grid.nearby(origin,25).has(player),"Teleport updates combat neighborhood before another actor scans")
	player.global_position=origin
	check(grid.nearby(origin,25).count(player)==1,"Returning unit registered once")
	var dispatch = battle.ai_dispatch
	battle.frame_pacing.tier = 0
	for u in units: u.ai_order("guard")
	var waiting: Dictionary = battle.allied_state[dispatch.WAITING]
	check(dispatch.admitted.size()==128 and waiting.size()==40,"128 distinct AI units shared by three computer houses")
	check(units.slice(0,128).all(func(u):return u.hold_position) and not units[128].hold_position,"overflow waits for the next render")
	var old_target: Vector2 = home + Vector2(400,20)
	var new_target: Vector2 = home + Vector2(490,40)
	units[128].ai_order("move",old_target)
	units[128].ai_order("move",new_target)
	check(waiting.keys()[0]==units[128] and waiting[units[128]].order.point==new_target and waiting.size()==40,"newest intent keeps original FIFO position")
	player.order_move(new_target)
	check(player.has_move_order and not dispatch.admitted.has(player),"player moves immediately despite full AI budget")
	var traveler = units.back()
	traveler.order_stop()
	traveler.order_move(old_target)
	check(traveler.special.has("ai_route_goal") and not traveler.ai_path_allowed(),"AI route waits rather than reporting an unreachable destination")
	var casualty=units[130]
	casualty.hp=0.0
	battle.frame_pacing.tier = 3
	await next_frame()
	units[0].ai_order("guard")
	check(dispatch.limit==16 and not dispatch.admitted.has(units[0]) and dispatch.admitted.has(units[128]),"old waiters beat a fresh repeat at the new lower limit")
	dispatch.pump(battle)
	check(dispatch.admitted.size()==16 and units[128].has_move_order and units[129].hold_position and not waiting.has(casualty),"admission executes surviving waiters")
	var pending: int = waiting.size()
	var codec = BattleSaves.Snapshot.new()
	var snapshot = codec.capture(battle)
	check(codec.error.is_empty() and BattleSaves.validate(snapshot).is_empty(),"pending commands serialize with ordinary actor references")
	codec.restore(battle,snapshot)
	waiting = battle.allied_state[dispatch.WAITING]
	check(waiting.size()==pending,"restore preserves pending seats and intent")
	var settlers := []
	for u in waiting:
		if waiting[u].get("order",{}).get("kind")=="guard": settlers.append(u)
	battle.paused=true
	await next_frame()
	dispatch.pump(battle)
	check(waiting.size()==pending,"pause does not drain commands")
	battle.paused=false
	get_tree().paused=false
	for tier in [2,1,0]:
		battle.frame_pacing.tier=tier
		await next_frame()
		dispatch.pump(battle)
		for u in battle.units:
			if u.special.has("ai_route_goal") and u.has_move_order: u._steer_dir(u.move_target)
		check(dispatch.limit==dispatch.LIMITS[tier] and dispatch.admitted.size()<=dispatch.limit,"recovery budget "+str(dispatch.LIMITS[tier]))
	check(waiting.is_empty() and settlers.all(func(u):return u.hold_position),"save and resume drains every pending guard")
	check(battle.units.all(func(u):return not u.special.has("ai_route_goal")),"deferred path consumed after a seat opens")
	await next_frame()
	battle.frame_pacing.tier=3
	for i in 16:settlers[i].ai_order("guard")
	var scanner=settlers[16]
	check(not dispatch.allow_scan(battle,scanner) and waiting[scanner].has("scan"),"saturated AI scan queued once")
	check(dispatch.allow_scan(battle,battle.units.filter(func(u):return u.side=="ally")[0]),"player acquisition bypasses saturated AI queue")
	await next_frame()
	dispatch.pump(battle)
	check(scanner._scan_grant_until>=Engine.get_physics_frames() and scanner._think_timer==0 and not waiting.has(scanner),"reservation wakes normal scanner and clears queue")
	await check_combat_weight()
	check_idle_scan()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)

func check_combat_weight() -> void:
	var dispatch = battle.ai_dispatch
	var waiting: Dictionary = battle.allied_state[dispatch.WAITING]
	var troops := []
	var player
	for actor in battle.units:
		if actor.unit_id != "MTNK" or not battle.actor_alive(actor): continue
		if actor.side == "enemy": troops.append(actor)
		elif actor.side == "ally": player = actor
	assert(troops.size() >= 56 and is_instance_valid(player))
	battle.frame_pacing.tier = 3
	await next_frame()
	for i in range(40,56): troops[i].ai_order("guard")
	# The twenty ordinary orders are older than every frontline order.
	for i in 40: troops[i].ai_order("guard")
	for i in range(20,40):
		if i % 2 == 0: battle.reveal_attack(troops[i], player)
		else: battle.reveal_attack(player, troops[i])
	battle.reveal_attack(troops[0], troops[1])
	check(not dispatch._in_combat(troops[0]) and not dispatch._in_combat(troops[1]), "friendly interaction does not mark combat")
	await next_frame()
	dispatch.pump(battle)
	check(dispatch.admitted.size() == 16 and troops.slice(0,4).all(func(u): return dispatch.admitted.has(u)) and troops.slice(20,32).all(func(u): return dispatch.admitted.has(u)), "under pressure twelve frontline and four oldest rear orders execute")
	await next_frame()
	dispatch.pump(battle)
	check(dispatch.admitted.size() == 16 and troops.slice(32,40).all(func(u): return dispatch.admitted.has(u)) and troops.slice(4,12).all(func(u): return dispatch.admitted.has(u)), "eight remaining frontline orders release eight seats to ordinary orders")
	await next_frame()
	dispatch.pump(battle)
	check(waiting.is_empty() and troops.slice(12,20).all(func(u): return dispatch.admitted.has(u)), "remaining rear units all receive their command")
	for i in 8: troops[i].ai_order("guard")
	for i in range(20,40): troops[i].ai_order("guard")
	await next_frame()
	dispatch.pump(battle)
	check(dispatch.admitted.size() == 16 and troops.slice(20,36).all(func(u): return dispatch.admitted.has(u)), "frontline borrows every seat when ordinary queue is empty")
	troops[20]._anim += dispatch.COMBAT_WINDOW
	check(not dispatch._in_combat(troops[20]), "combat priority expires on the battle clock")

func check_idle_scan() -> void:
	var enemy = battle.units.filter(func(u): return u.side == "enemy" and u.unit_id == "MTNK" and battle.actor_alive(u))[0]
	var player = battle.units.filter(func(u): return u.side == "ally" and u.unit_id == "MTNK" and battle.actor_alive(u))[0]
	for unit in [enemy, player]:
		unit.order_stop()
		unit.fire_stance = "return"
		unit._return_timer = 0.0
		unit._think_timer = 0.0
		unit._physics_process(1.0 / 15.0)
	check(is_equal_approx(enemy._think_timer, 2.0 * Unit.TARGET_REFRESH), "large battle quiet AI defers its next scan")
	check(is_equal_approx(player._think_timer, Unit.TARGET_REFRESH), "player idle acquisition keeps normal cadence")
	enemy.receive_hit(1.0, "bullet", {}, player)
	check(enemy._return_timer > 0.0 and enemy._think_timer == 0.0, "being hit immediately wakes the quiet AI scanner")
