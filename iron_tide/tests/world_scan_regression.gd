extends "res://tests/base_recovery_regression.gd"
const Reference = preload("res://tests/world_scan_reference.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		battle.fog = null
		check_concealment()
		check_airports()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)

func check_concealment() -> void:
	var mirage: Unit = battle.spawn_unit("MGTK", "enemy", Vector2(1023,1023))
	mirage.order_stop()
	var infantry: Unit = battle.spawn_unit("E1", "ally", Vector2(1400,1400))
	var detector: Unit = battle.spawn_unit("DOG", "ally", Vector2(2200,2200))
	var transport: Unit = battle.spawn_unit("BFRT", "ally", Vector2(1800,1800))
	for distance in [0.0, 54.99, 55.0, 55.01, 255.0, 700.0]:
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			# Repeated cross-cell teleports must be reflected immediately, without a tick.
			infantry.position = mirage.position + direction * distance
			for state in ["normal","enemy","embarked","dead","moving","revealed"]:
				infantry.side = "enemy" if state == "enemy" else "ally"
				infantry.embarked_in = transport if state == "embarked" else null
				infantry.hp = 0.0 if state == "dead" else infantry.max_hp
				mirage.velocity = Vector2.RIGHT * 20 if state == "moving" else Vector2.ZERO
				mirage.special.reveal = 1.0 if state == "revealed" else 0.0
				if state == "normal": check(AlliedAbilities.concealed(mirage,"ally") == (distance > 55.0),prefix+"contact exposure inclusive 55px boundary")
				for observer in ["ally","enemy"]:
					check(AlliedAbilities.concealed(mirage,observer) == Reference.concealed(mirage,observer),prefix+"local contact equals original global scan",{"distance":distance,"direction":direction,"state":state,"observer":observer})
	mirage.velocity = Vector2.ZERO; mirage.special.erase("reveal")
	infantry.position = Vector2(2000,2000); infantry.hp = infantry.max_hp; infantry.embarked_in = null
	for distance in [55.0,100.0,detector.sight,detector.sight+1.0]:
		detector.position = mirage.position + Vector2(distance,0)
		check(AlliedAbilities.concealed(mirage,"ally") == Reference.concealed(mirage,"ally"),prefix+"detectors retain original sight range")
	for actor in [mirage,infantry,detector,transport]:
		battle.units.erase(actor); actor.free()

func check_members(airport) -> void:
	var expected: Array = []
	for actor in battle.units:
		if is_instance_valid(actor) and actor.logistics.home == airport: expected.append(actor)
	var actual := UnitLogistics.home_members(airport)
	check(actual.size() == expected.size() and expected.all(func(actor): return actual.has(actor)),prefix+"airport membership equals original world scan")

func check_airports() -> void:
	var base: Building = battle._place_building("GAAIRC","ally",Vector2(1000,1300),true,true)
	var alternate: Building = battle._place_building("GAAIRC","ally",Vector2(1700,1300),true,true)
	for airport in [base,alternate]: airport._buildup_play = -1.0; airport.under_construction = false
	var planes: Array = []
	for id in ["ORCA","BEAG","ORCA","BEAG"]:
		var actor: Unit = battle.spawn_unit(id,"ally",base.position)
		actor.logistics.assign_producer(base)
		check(actor.logistics.home == base and actor.logistics.dock_slot == planes.size(),prefix+"distinct real airport reservations")
		planes.append(actor)
		check_members(base)
		check(actor.logistics.return_slot(base) == Reference.return_slot(actor,base),prefix+"slot assignment equals original full scan")
	var visitor: Unit = battle.spawn_unit("ORCA","ally",Vector2(600,1300))
	for state in ["full","dead","queued","transferred","cleared"]:
		var other: Unit = planes[1]
		if state == "dead": other.hp = 0.0
		if state == "queued": other.hp = other.max_hp; other.queue_free()
		if state == "transferred": other.logistics.home = alternate
		if state == "cleared": other.logistics.home = null
		for airport in [base,alternate]:
			check_members(airport)
			check(visitor.logistics.return_slot(airport) == Reference.return_slot(visitor,airport),prefix+"live reservation state equals original: "+state)
	# Removing/reinserting a node must neither retain stale entries nor duplicate them.
	var moved: Unit = planes[2]
	var parent := moved.get_parent()
	parent.remove_child(moved)
	check(not UnitLogistics.home_members(base).has(moved),prefix+"exit removes airport member")
	parent.add_child(moved)
	check_members(base)
	moved.logistics.home = base; moved.logistics.home = base
	check_members(base)
	# The exact original set of overhead collision exceptions, including preexisting exceptions.
	visitor.logistics.home = base; visitor.logistics.air_lift = 1.0
	for actor in planes:
		actor.logistics.air_lift = 0.0
	visitor.add_collision_exception_with(planes[0])
	var expected: Array = []
	for other in battle.units:
		if is_instance_valid(other) and other != visitor and other.is_air and other.logistics.home == base and other.logistics.air_lift <= 0.1 and not visitor.get_collision_exceptions().has(other): expected.append(other)
	var actual: Array = []
	for other in UnitLogistics.home_members(base):
		if is_instance_valid(other) and other != visitor and other.is_air and other.logistics.home == base and other.logistics.air_lift <= 0.1 and not visitor.get_collision_exceptions().has(other): actual.append(other)
	check(actual.size()==expected.size() and expected.all(func(actor):return actual.has(actor)),prefix+"same overhead exception set")
	visitor.remove_collision_exception_with(planes[0])
	# Roundtrip the real explicit save schema; derived metadata must rebuild from home refs.
	var snapshotter := Snapshot.new()
	var saved := snapshotter.capture(battle)
	check(snapshotter.error.is_empty(),prefix+"capture explicit schema",snapshotter.error)
	snapshotter.restore(battle,saved)
	check(snapshotter.error.is_empty(),prefix+"restore explicit schema",snapshotter.error)
	for airport in battle.buildings:
		if airport.building_id == "GAAIRC":
			check_members(airport)
			for actor in UnitLogistics.home_members(airport):
				check(actor.logistics.return_slot(airport)==Reference.return_slot(actor,airport),prefix+"restored reservations equal original")
