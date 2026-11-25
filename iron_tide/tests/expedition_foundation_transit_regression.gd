extends "res://tests/ground_control_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	await exercise(MatchRules.EXTENDED)
	var file:=FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)

func exercise(mode:String) -> void:
	start(mode)
	for building in battle.buildings:building.free()
	battle.buildings.clear();battle._refresh_pathing()
	BattleRequest.rules_mode=MatchRules.EXTENDED
	BattleRequest.combat_context["expedition"]={"buffs":{}}
	var center:=Vector2(1100,1050)
	var factory=battle._place_building("GAWEAP","ally",center,true)
	factory._buildup_play=-1;factory.process_mode=Node.PROCESS_MODE_ALWAYS;factory.set_process(false)
	battle._refresh_pathing()
	var bounds:Rect2=Placement.aabb(factory.footprint_poly(),center)
	var mover=battle.spawn_unit("MTNK","ally",Vector2(bounds.position.x-120,center.y))
	activate(mover)
	mover.order_move(Vector2(bounds.end.x+180,center.y))
	check(mover._path_pts.size()==2 and not battle.path_service.is_blocked(mover.move_target),"ally order routes directly across foundation to a parkable destination",[mover._path_pts,preload("res://scripts/expedition/foundation_transit.gd").enabled(mover),preload("res://scripts/expedition/foundation_transit.gd").crosses(mover,battle,mover.move_target,[]),preload("res://scripts/expedition/foundation_transit.gd").parkable(mover,battle,mover.move_target,mover.ARRIVE_EPS)])
	# Automatic mining has no foundation collision exception: its route must detour.
	var miner=battle.spawn_unit("HARV","ally",Vector2(bounds.position.x-120,center.y))
	var mining_goal:=Vector2(bounds.end.x+180,center.y)
	miner.has_move_order=false
	var mining_route:PackedVector2Array=battle.path_for_unit(miner,mining_goal)
	check(mining_route.size()>2,"automatic miner routes around allied foundation",mining_route)
	var mining_clear:=mining_route.size()>1
	for index in range(1,mining_route.size()):
		if Geometry2D.segment_intersects_segment(mining_route[index-1],mining_route[index],Vector2(center.x,bounds.position.y),Vector2(center.x,bounds.end.y))!=null:mining_clear=false
	check(mining_clear,"automatic mining route never cuts through factory",mining_route)
	miner.has_move_order=true
	check(battle.path_for_unit(miner,mining_goal).size()==2,"manual miner move retains expedition foundation transit")
	miner.free()
	var entered:=false
	for frame in 900:
		mover._physics_process(1.0/60.0)
		await get_tree().physics_frame
		if Geometry2D.is_point_in_polygon(mover.position-center,factory.footprint_poly()):
			entered=true
			break
	check(entered,"vehicle actually traverses allied foundation",mover.position)
	mover.order_stop()
	for frame in 2:
		mover._physics_process(1.0/60.0)
		await get_tree().physics_frame
	check(not Geometry2D.is_point_in_polygon(mover.position-center,factory.footprint_poly()),"stop inside friendly foundation settles actor outside",mover.position)
	check(mover.collision_mask==7 and mover.get_collision_exceptions().is_empty(),"normal collision policy restored after stop")
	var transit=preload("res://scripts/expedition/foundation_transit.gd")
	mover.position=Vector2(bounds.position.x-120,center.y)
	mover.order_move(Vector2(bounds.end.x+180,center.y))
	var goal:Vector2=mover.move_target
	for frame in 900:
		mover._physics_process(1.0/60.0)
		await get_tree().physics_frame
		if not mover.has_move_order:break
	check(mover.position.distance_to(goal)<=mover.ARRIVE_EPS+1 and transit.parkable(mover,battle,mover.position,0),"crossing completes outside foundation",mover.position)
	check(not mover.special.has(transit.ANCHOR),"completed crossing removes safety anchor")
	mover.order_move(center)
	check(transit.parkable(mover,battle,mover.move_target,mover.ARRIVE_EPS),"clicking inside allied building resolves to exterior destination",mover.move_target)
	mover.order_stop()
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2}
	factory.side="ai2"
	mover.position=Vector2(bounds.end.x+180,center.y)
	check(transit.crosses(mover,battle,Vector2(bounds.position.x-120,center.y),[]),"allied house building allows transit",[BattleRequest.friendly("ally","ai2"),transit.parkable(mover,battle,Vector2(bounds.position.x-120,center.y),mover.ARRIVE_EPS),battle.path_service.line_walkable(mover.position,Vector2(bounds.position.x-120,center.y),battle.path_service.passages.terrain),factory.side,factory.position,bounds])
	var context:Dictionary=BattleRequest.combat_context.duplicate(true)
	BattleRequest.combat_context.erase("expedition")
	check(not transit.enabled(mover),"ordinary matches do not enable foundation transit")
	BattleRequest.combat_context=context
	var infantry=battle.spawn_unit("E1","ally",Vector2(bounds.position.x-120,center.y))
	activate(infantry)
	infantry.order_move(Vector2(bounds.end.x+180,center.y))
	var infantry_entered:=false
	for frame in 900:
		infantry._physics_process(1.0/60.0)
		await get_tree().physics_frame
		if Geometry2D.is_point_in_polygon(infantry.position-center,factory.footprint_poly()):infantry_entered=true;break
	check(infantry_entered,"infantry actually crosses friendly foundation")
	infantry.order_guard()
	check(transit.parkable(infantry,battle,infantry.position,0) and infantry.hold_position,"guard inside foundation settles outside immediately")
	check(infantry.get_collision_exceptions().is_empty(),"infantry transit removes temporary collisions")
	battle.units.erase(infantry);infantry.free()
	mover.position=Vector2(bounds.position.x-120,center.y)
	factory.side="enemy";battle._refresh_pathing()
	mover.order_move(Vector2(bounds.end.x+180,center.y))
	check(not preload("res://scripts/expedition/foundation_transit.gd").crosses(mover,battle,mover.move_target,[]),"enemy foundation does not receive transit exception",mover._path_pts)
	for frame in 180:
		mover._physics_process(1.0/60.0)
		await get_tree().physics_frame
	check(not Geometry2D.is_point_in_polygon(mover.position-center,factory.footprint_poly()),"enemy foundation remains solid",mover.position)
	battle.units.erase(mover);mover.free()
	battle.buildings.erase(factory);factory.free();battle._refresh_pathing()
	await finish()
