extends RefCounted
const Escape=preload("res://scripts/units/base_escape.gd")

static func run(t,mode:String) -> void:
	for building in t.battle.buildings:building.free()
	t.battle.buildings.clear();t.battle._refresh_pathing()
	var center:=Vector2(1100,1050)
	var building=t.battle._place_building("GAWEAP","ally",center,true)
	building._buildup_play=-1;building.process_mode=Node.PROCESS_MODE_ALWAYS;building.set_process(false)
	t.battle._refresh_pathing()
	var bounds:Rect2=Placement.aabb(building.footprint_poly(),center)
	var mover=t.battle.spawn_unit("MTNK","ally",Vector2(bounds.position.x+10,center.y))
	t.activate(mover)
	mover.order_move(Vector2(bounds.end.x+180,center.y))
	await t.get_tree().physics_frame
	# Real stuck detection selects the escape route, rather than turning collision off globally.
	for tick in 3:mover._tick_path_stuck(1.0)
	t.check(Escape.active(mover),mode+" trapped player activates base escape")
	var edge_points:=0
	for point:Vector2 in mover._path_pts:
		if not bounds.has_point(point):edge_points+=1
	t.check(edge_points>2 and mover._path_pts[-1]==mover.move_target,mode+" weighted route uses foundation edge and reaches actual destination")
	var structure_hp:float=building.hp
	var progress:Array=[]
	var goal:Vector2=mover.move_target
	for frame in 1200:
		mover._physics_process(1.0/60.0)
		await t.get_tree().physics_frame
		if frame%180==0:progress.append([frame,mover.position,mover._path_i,mover._path_pts,mover.velocity,mover._drive_turning])
		if mover.position.distance_to(goal)<mover.ARRIVE_EPS:break
	t.check(mover.position.distance_to(goal)<mover.ARRIVE_EPS and building.hp==structure_hp,mode+" actual trapped vehicle leaves friendly base and reaches destination without damaging it",progress)
	t.check(mover.collision_mask==7 and mover.get_collision_exceptions().is_empty(),mode+" escape keeps layers and removes temporary exceptions every movement")
	mover.order_stop()
	t.check(not Escape.active(mover),mode+" stopping restores normal collision policy")
	# Same geometry under hostile ownership cannot become a pass-through route.
	building.side="enemy"
	t.battle._refresh_pathing()
	mover.position=Vector2(bounds.position.x+10,center.y);mover.order_move(Vector2(bounds.end.x+180,center.y))
	t.check(not Escape.try_route(mover) and not Escape.active(mover),mode+" hostile foundation remains impassable after capture")
	building.side="ally";t.battle._refresh_pathing()
	mover.side="enemy"
	t.check(not Escape.try_route(mover),mode+" congestion fallback does not alter AI movement")
	mover.side="ally"
	# Player vehicle crowds receive temporary unit exceptions only during an active escape.
	mover.position=Vector2(bounds.position.x+10,center.y);mover.order_move(Vector2(bounds.end.x+180,center.y))
	t.check(Escape.try_route(mover),mode+" rebuild fallback after new order")
	var blocker=t.battle.spawn_unit("MTNK","ally",mover.position+Vector2(30,0));t.activate(blocker)
	t.check(mover._local_traffic.friendly_unit_pair(mover,blocker),mode+" own vehicles share collision only during congestion escape")
	blocker.side="enemy"
	t.check(not mover._local_traffic.friendly_unit_pair(mover,blocker),mode+" enemy vehicles still collide during escape")
	mover.order_stop();blocker.side="ally"
	t.check(not mover._local_traffic.friendly_unit_pair(mover,blocker),mode+" ordinary own-vehicle collision resumes after order ends")
	for unit in [mover,blocker]:t.battle.units.erase(unit);unit.free()
	t.battle.buildings.erase(building);building.free();t.battle._refresh_pathing()
