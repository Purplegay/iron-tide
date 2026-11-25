extends "res://tests/ground_control_regression.gd"
const Native = preload("res://scripts/world/native_maps.gd")

func exercise(mode: String) -> void:
	var previous_hz := Engine.physics_ticks_per_second
	for hz in [15,60]:
		Engine.physics_ticks_per_second=hz
		for house in ["ally","enemy"]:
			await exercise_column(mode,house,hz)
	Engine.physics_ticks_per_second=previous_hz

func exercise_column(mode: String, house: String, hz: int = 60, speed: float = 1.0) -> void:
	BattleRequest.configure_skirmish(mode, {"map_layout":"yr_crctbrd","opening":"mcv","fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	# The battle installs its 15 Hz policy in ready; variants override it afterwards.
	Engine.physics_ticks_per_second = hz
	BattleClock.set_speed(speed)
	var left := Vector2(113.5,57.5)*Native.CELL
	var right := Vector2(123.5,57.5)*Native.CELL
	var actors := []
	for i in 24:
		var actor = battle.spawn_unit("HTNK",house,(left+Vector2(-60*(i/3), (i%3-1)*48) if i<12 else right+Vector2(60*((i-12)/3),(i%3-1)*48)))
		activate(actor)
		actors.append(actor)
		var goal: Vector2 = (right+Vector2(65*(i/3),(i%3-1)*52)) if i<12 else (left+Vector2(-65*((i-12)/3),(i%3-1)*52))
		if house=="enemy": actor.ai_order("move",goal)
		else: actor.order_move(goal)
	for lane in 3:
		var parked = battle.spawn_unit("HTNK",house,Vector2(117.5,57.5)*Native.CELL+Vector2(0,(lane-1)*48))
		activate(parked)
		actors.append(parked)
	await get_tree().physics_frame
	var elapsed := 0
	var stayed_local := true
	var tick_seconds := Engine.time_scale / float(Engine.physics_ticks_per_second)
	for tick in ceili(60.0/tick_seconds):
		await get_tree().physics_frame
		elapsed=tick+1
		for actor in actors:
			actor._physics_process(tick_seconds)
			if absf(actor.position.y-left.y)>250: stayed_local=false
		if actors.all(func(u):return not u.has_move_order): break
	var reached := 0
	for i in 24:
		if (actors[i].position.x>right.x-65 if i<12 else actors[i].position.x<left.x+65): reached+=1
		check(actors[i]._domain_ok(actors[i].position),mode+house+" tank stays on dry terrain "+str(i))
	check(reached==24,mode+house+" all twenty-four tanks clear parked bridge traffic",reached)
	check(stayed_local,mode+house+" no map-wide detour around parked allies")
	metrics.append({"mode":mode,"house":house,"seconds":elapsed*tick_seconds,"physics_hz":Engine.physics_ticks_per_second,"reached":reached,"positions":actors.map(func(u):return [u.position,u.move_target,u._path_pts,u._drive_turning])})
	await finish()
