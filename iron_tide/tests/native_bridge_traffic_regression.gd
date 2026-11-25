extends "res://tests/ground_control_regression.gd"

const Native = preload("res://scripts/world/native_maps.gd")

func exercise(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_layout":"yr_crctbrd","opening":"mcv","fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var edge := Vector2(117.5, 59.0) * Native.CELL
	check(not battle.path_service.is_blocked(edge + Vector2.UP * 2), mode+" last two pixels on the deck are walkable")
	check(battle.path_service.is_blocked(edge + Vector2.DOWN * 2), mode+" river outside the deck stays blocked")
	var left := Vector2(113.5, 57.3) * Native.CELL
	var right := Vector2(122.5, 57.3) * Native.CELL
	var actors := []
	for i in 3:
		var spawn: Vector2 = left + Vector2(-32*i, 35*i)
		var unit = battle.spawn_unit(["MTNK","E1","HTNK"][i],"ally",spawn)
		activate(unit)
		actors.append(unit)
	for goal: Vector2 in [right,left]:
		for i in actors.size(): actors[i].order_move(goal + Vector2(0,35*i))
		for tick in 1100:
			await get_tree().physics_frame
			for unit in actors: unit._physics_process(1.0/60)
			if actors.all(func(u): return not u.has_move_order): break
		for i in actors.size():
			check(actors[i].position.distance_to(goal+Vector2(0,35*i))<30,mode+" column reaches opposite bank "+actors[i].unit_id,actors[i].position)
	var stranded = actors[0]
	stranded.position = edge + Vector2.DOWN * 8
	stranded.order_move(left)
	for tick in 650:
		await get_tree().physics_frame
		stranded._physics_process(1.0/60)
		if not stranded.has_move_order: break
	check(stranded.position.distance_to(left)<30,mode+" tank pushed off deck recovers and completes existing order",stranded.position)
	var center := Vector2(117.5,57.5) * Native.CELL
	var near_bank := Vector2(117.5,59.5) * Native.CELL
	var far_bank := Vector2(117.5,55.5) * Native.CELL
	var navy = battle.spawn_unit("DRED","ally",near_bank)
	activate(navy)
	check(navy.is_naval and not navy.is_amphibious and not navy._domain_ok(center),mode+" dreadnought cannot enter low deck")
	check(navy._domain_ok(near_bank) and navy._domain_ok(far_bank),mode+" open water on either side remains navigable")
	navy.order_move(far_bank)
	var touched_deck := false
	for i in 240:
		await get_tree().physics_frame
		navy._physics_process(1.0/60)
		if Native.data("yr_crctbrd").low_bridge_cells.has(Vector2i((navy.position / Native.CELL).floor())): touched_deck = true
	check(not touched_deck,mode+" issued naval move never enters low bridge")
	navy.position = center
	battle.spawn_unit("DEST","ally",center)
	var codec = BattleSaves.Snapshot.new()
	var save = codec.capture(battle)
	codec.restore(battle, save)
	var recovered := []
	for unit in battle.units:
		if unit.unit_id in ["DRED","DEST"]:
			recovered.append(unit)
			check(unit._domain_ok(unit.position) and unit.position.distance_to(center) < 5*Native.CELL,mode+" old ship on bridge returns to nearby open water")
	check(recovered.size() == 2 and recovered[0].position.distance_to(recovered[1].position) >= recovered[0].radius + recovered[1].radius,mode+" restored hulls have separate positions")
	await finish()
