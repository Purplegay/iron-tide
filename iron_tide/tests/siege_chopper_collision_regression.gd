extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		for side in ["ally", "enemy"]:
			await exercise_layers(side)
		await finish()
	var save := OS.get_environment("IRON_SAVE")
	if not save.is_empty(): await exercise_saved_order(save)
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)

func activate_body(unit: Unit) -> void:
	unit.process_mode = Node.PROCESS_MODE_ALWAYS
	unit.set_process(false)
	unit.set_physics_process(false)

func exercise_layers(side: String) -> void:
	var label := prefix + side + ": "
	var center := Vector2(1200,1200)
	var chopper: Unit = battle.spawn_unit("SCHP",side,center)
	var flyer: Unit = battle.spawn_unit("SCHP",side,center-Vector2(90,0))
	var tank: Unit = battle.spawn_unit("MTNK",side,center-Vector2(90,0))
	for unit in [chopper,flyer,tank]: activate_body(unit)
	chopper.logistics.air_lift = 1.0
	flyer.logistics.air_lift = 1.0
	await get_tree().physics_frame
	check(flyer.test_move(flyer.global_transform,Vector2(180,0)),label+"aircraft still collide with airborne aircraft")
	check(not tank.test_move(tank.global_transform,Vector2(180,0)),label+"tank passes below airborne aircraft")
	check(chopper.set_deployed(true,false),label+"deployment starts")
	chopper.logistics.tick(0.01)
	check(chopper.collision_layer==8 and chopper.collision_mask==8,label+"descent remains airborne before ground threshold")
	chopper.logistics.tick(15.0)
	chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
	check(chopper._deployed and chopper.logistics.air_lift==0.0 and chopper.logistics.can_start_volley(),label+"deployed artillery is ready on ground")
	check(chopper.collision_layer==1 and chopper.collision_mask==7,label+"deployed artillery occupies ground layer")
	await get_tree().physics_frame
	check(not flyer.test_move(flyer.global_transform,Vector2(180,0)),label+"aircraft flies over deployed artillery")
	check(tank.test_move(tank.global_transform,Vector2(180,0)),label+"ground vehicle still collides with deployed artillery")
	check(chopper.set_deployed(false,false),label+"folding starts")
	chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
	check(chopper.collision_layer==1 and chopper.logistics.air_lift==0.0,label+"folding stays on ground until liftoff")
	chopper.logistics.tick(15.0)
	check(chopper.collision_layer==8 and chopper.collision_mask==8 and chopper.logistics.air_lift==1.0,label+"takeoff restores air collision")
	await get_tree().physics_frame
	check(flyer.test_move(flyer.global_transform,Vector2(180,0)),label+"air collision resumes after takeoff")
	check(not tank.test_move(tank.global_transform,Vector2(180,0)),label+"ground path opens after takeoff")
	# Restore a stale physical snapshot while preserving the actual deployed state.
	chopper.set_deployed(true,false)
	chopper.logistics.tick(15.0)
	chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
	chopper.collision_layer=8
	chopper.collision_mask=8
	var snapshot: Dictionary = BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	var restored: Unit
	for unit in battle.units:
		if unit.unit_id=="SCHP" and unit.side==side and unit.position.is_equal_approx(center): restored=unit
	check(restored!=null and restored.collision_layer==1 and restored.collision_mask==7,label+"restore corrects stale air layer before first tick")
	for unit in battle.units.duplicate():
		battle.units.erase(unit)
		unit.free()
	await get_tree().physics_frame

func exercise_saved_order(source: String) -> void:
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	check(DirAccess.copy_absolute(source,BattleSaves.slot_path("slot1"))==OK,"user save copied into isolated profile")
	var result := BattleSaves.prepare_load("slot1")
	check(result.ok,"user slot1 passes real save validation",result.get("message"))
	if not result.ok: return
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	get_tree().paused=false
	check(battle.selected_units.size()==1,"saved selected aircraft restored")
	if battle.selected_units.size()!=1:
		await finish()
		return
	var flyer: Unit = battle.selected_units[0]
	var goal: Vector2 = flyer.move_target
	var start_position: Vector2 = flyer.position
	check(flyer.unit_id=="SCHP" and flyer.has_move_order and flyer.logistics.air_lift==1.0,"saved aircraft retains airborne movement order")
	var deployed := 0
	var wrong_layers := 0
	for unit in battle.units:
		activate_body(unit)
		if unit.unit_id=="SCHP" and unit._deployed and unit.logistics.air_lift==0.0:
			deployed+=1
			if unit.collision_layer!=1 or unit.collision_mask!=7: wrong_layers+=1
	check(deployed>0 and wrong_layers==0,"all saved grounded choppers restored to ground layer",{"deployed":deployed,"wrong_layers":wrong_layers})
	await get_tree().physics_frame
	check(not flyer.test_move(flyer.global_transform,flyer.velocity/60.0),"saved first movement step is unobstructed")
	flyer.fire_stance="none"
	for tick in 600:
		await get_tree().physics_frame
		flyer._physics_process(1.0/60.0)
		if not flyer.has_move_order: break
	check(not flyer.has_move_order and flyer.position.distance_to(goal)<=6.0,"saved aircraft reaches original destination through real flight and physics",{"start":str(start_position),"goal":str(goal),"end":str(flyer.position)})
	await finish()
