extends "res://tests/ground_control_regression.gd"
const Bridges = preload("res://scripts/world/bridge_damage.gd")
const Native = preload("res://scripts/world/native_maps.gd")
var span: Rect2
var section: Rect2
var axis: Vector2
var adjacent: Array

func exercise(mode: String) -> void:
	for layout in ["yr_crctbrd","river_delta"]:
		for horizontal in ([true,false] if Native.has(layout) else [true]):
			prefix = mode+"/"+layout+"/horizontal="+str(horizontal)+": "
			BattleRequest.configure_skirmish(mode,{"map_layout":layout,"opening":"mcv","fog_of_war":false})
			screen = load("res://scenes/battle.tscn").instantiate()
			add_child(screen)
			screen.process_mode = Node.PROCESS_MODE_DISABLED
			battle = screen.battle
			check(choose_section(horizontal),prefix+"fixture has central water section and intact neighbors")
			if not section.has_area(): await finish(); continue
			local_collapse()
			snapshot_roundtrip()
			repair_and_splash()
			legacy_roundtrip()
			await finish()

func choose_section(horizontal: bool) -> bool:
	section = Rect2()
	axis = Vector2.RIGHT if horizontal else Vector2.DOWN
	for candidate: Rect2 in Bridges.spans(battle):
		var parts: Array = Bridges.sections(battle,candidate)
		if parts.size()<5: continue
		if horizontal != (parts[0].size.x<=parts[0].size.y): continue
		for index in range(2,parts.size()-2):
			var wet := true
			for offset in [-1,0,1]:
				var point: Vector2 = parts[index+offset].get_center()
				if Native.has(battle.map_layout()):
					var cell := Vector2i((point/55.0).floor())
					wet = wet and int(Native.data(battle.map_layout()).bridge_base.get(cell,0))==2
				else: wet = wet and battle.path_service.in_naval_water(point)
			if not wet: continue
			span = candidate; section = parts[index]
			adjacent = [parts[index-1],parts[index+1]]
			check(is_equal_approx(section.size.dot(axis),55.0),prefix+"destructible section is one cell long")
			check(is_equal_approx(section.size.dot(Vector2(axis.y,axis.x)),span.size.dot(Vector2(axis.y,axis.x))),prefix+"section crosses full bridge width")
			return true
	return false

func actor(id: String, side: String, point: Vector2, marker: String):
	var unit = battle.spawn_unit(id,"ally",point)
	if side != "ally": AlliedAbilities.change_side(unit,side)
	activate(unit)
	unit.special.section_test = marker
	return unit

func local_collapse() -> void:
	var center := section.get_center()
	var across := Vector2(-axis.y,axis.x)
	var tank = actor("MTNK","ally",center,"hit_tank")
	var infantry = actor("E1","enemy",center+across*20,"hit_infantry")
	var left = actor("MTNK","ally",adjacent[0].get_center(),"neighbor_left")
	var right = actor("E1","enemy",adjacent[1].get_center(),"neighbor_right")
	var air = actor("ZEP","ally",center,"air")
	var amphibious = actor("LCRF","ally",center,"amphibious")
	Bridges.hit(battle,center+across*20,100.0)
	check(is_equal_approx(Bridges.health(battle,section),Bridges.strength()-100),prefix+"same cross-section shares health across bridge lanes")
	for neighbor: Rect2 in adjacent:
		check(is_equal_approx(Bridges.health(battle,neighbor),Bridges.strength()),prefix+"damage does not spread to adjacent section")
	Bridges.hit(battle,adjacent[0].get_center(),25.0)
	var old_epoch: int = battle.path_service.epoch
	Bridges.hit(battle,center,Bridges.strength())
	check(tank._dead and infantry._dead,prefix+"only unsupported units on collapsed section die on both sides")
	check(not left._dead and not right._dead,prefix+"units on immediately adjacent sections survive")
	check(not air._dead and not amphibious._dead,prefix+"aircraft and amphibious unit survive collapse")
	check(battle.path_service.is_blocked(center) and not battle.path_service.bridge_at(center).has_area(),prefix+"only hit section is removed from land pathing")
	check(battle.path_service.epoch>old_epoch,prefix+"collapse invalidates cached routes")
	for neighbor: Rect2 in adjacent:
		check(not battle.path_service.is_blocked(neighbor.get_center()) and battle.path_service.bridge_at(neighbor.get_center()).has_area(),prefix+"neighbor remains walkable bridge")
	check(is_equal_approx(Bridges.health(battle,adjacent[0]),Bridges.strength()-25),prefix+"neighbor keeps its own earlier damage")
	check(battle.path_service.broken_bridge_decks==[section],prefix+"one local gap reaches navigation and drawing")
	check(battle.ground.broken_bridges==[section],prefix+"native covering does not erase whole bridge")
	var route: PackedVector2Array = battle.path_service.find_path(adjacent[0].get_center(),adjacent[1].get_center(),false)
	var clear := true
	for index in range(1,route.size()):
		var steps := maxi(1,ceili(route[index-1].distance_to(route[index])/10.0))
		for step in range(steps+1):
			if section.has_point(route[index-1].lerp(route[index],float(step)/steps)): clear = false
	check(clear,prefix+"new path cannot route through destroyed section",route.size())
	var site: Dictionary = battle.build_spot_ok(adjacent[1].get_center(),GameData.get_building("GAPOWR"),true)
	check(not site.ok and str(site.reason).contains("桥面"),prefix+"surviving bridge stays non-buildable")

func snapshot_roundtrip() -> void:
	var codec = BattleSaves.Snapshot.new()
	var saved: Dictionary = codec.capture(battle)
	check(codec.error.is_empty(),prefix+"section state serializes",codec.error)
	codec.restore(battle,bytes_to_var(var_to_bytes(saved)))
	check(battle.path_service.broken_bridge_decks==[section] and Bridges.health(battle,section)==0,prefix+"roundtrip restores same local gap")
	check(is_equal_approx(Bridges.health(battle,adjacent[0]),Bridges.strength()-25) and Bridges.health(battle,adjacent[1])==Bridges.strength(),prefix+"roundtrip preserves independent neighboring health")
	var survivors := 0
	for unit in battle.units:
		if str(unit.special.get("section_test","")).begins_with("neighbor_") and battle.actor_alive(unit): survivors+=1
	check(survivors==2,prefix+"roundtrip preserves both adjacent units")

func repair_and_splash() -> void:
	if not Native.has(battle.map_layout()):
		for hut in battle.buildings:
			if hut.special.get("bridge_span")==span:
				check(not hut.special.bridge_repaired,prefix+"partially broken bridge exposes engineer repair")
				preload("res://scripts/world/civilian_sites.gd").repair(hut)
				break
	else:
		Bridges.reset_health(battle,span)
		Bridges.restore(battle)
	check(battle.path_service.broken_bridge_decks.is_empty() and not battle.path_service.is_blocked(section.get_center()),prefix+"repair restores local gap and route")
	for part: Rect2 in Bridges.sections(battle,span):
		check(Bridges.health(battle,part)==Bridges.strength(),prefix+"repair clears section damage")
	Bridges.blast(battle,section.get_center(),100.0,"",5.0)
	check(is_equal_approx(Bridges.health(battle,section),Bridges.strength()-100),prefix+"one explosion damages a section once, not per lane tile")
	for neighbor: Rect2 in adjacent:
		check(Bridges.health(battle,neighbor)==Bridges.strength(),prefix+"small explosion leaves neighboring sections untouched")
	Bridges.blast(battle,section.get_center(),4000.0,"",75.0)
	check(Bridges.health(battle,section)==0 and Bridges.health(battle,adjacent[0])==0 and Bridges.health(battle,adjacent[1])==0,prefix+"larger explosion destroys only the three covered sections")
	check(battle.path_service.broken_bridge_decks.size()==3,prefix+"blast coverage produces three gaps rather than whole bridge")
	for part: Rect2 in Bridges.sections(battle,span):
		if part==section or adjacent.has(part): continue
		check(Bridges.health(battle,part)==Bridges.strength(),prefix+"section outside explosion remains intact")

func legacy_roundtrip() -> void:
	Bridges.reset_health(battle,span)
	battle.allied_state[Bridges.LEGACY_KEY] = {span:700.0}
	Bridges.restore(battle)
	var converted: bool = not battle.allied_state.has(Bridges.LEGACY_KEY)
	for part: Rect2 in Bridges.sections(battle,span): converted = converted and Bridges.health(battle,part)==700.0
	check(converted,prefix+"legacy whole-bridge health converts once without data loss")
	Bridges.reset_health(battle,span)
	battle.allied_state[Bridges.LEGACY_KEY] = {span:0.0}
	if not Native.has(battle.map_layout()): battle.allied_state.repaired_bridges.erase(span)
	Bridges.restore(battle)
	var parts: Array = Bridges.sections(battle,span)
	var middle: Rect2 = parts[parts.size()/2]
	check(battle.path_service.broken_bridge_decks==[middle] and battle.ground.broken_bridges==[middle],prefix+"legacy whole bridge becomes exactly one central gap in pathing and rendering")
	for part: Rect2 in parts:
		check(Bridges.health(battle,part)==(0.0 if part==middle else Bridges.strength()),prefix+"legacy bridge keeps only central damage")
	# A prior release already expanded legacy zero health into every section.
	battle.allied_state.erase(Bridges.VERSION_KEY)
	for part: Rect2 in parts: battle.allied_state[Bridges.KEY][part] = 0.0
	Bridges.restore(battle)
	check(battle.path_service.broken_bridge_decks==[middle],prefix+"previously converted unversioned save also reduces to central gap")
	var state: Dictionary = battle.allied_state[Bridges.KEY].duplicate(true)
	Bridges.restore(battle)
	check(battle.allied_state[Bridges.KEY]==state and battle.allied_state[Bridges.VERSION_KEY]==Bridges.VERSION,prefix+"migration is marked and idempotent")
	# Subsequent legitimate attacks may destroy more than one section; never heal them on load.
	for part: Rect2 in parts: Bridges.hit(battle,part.get_center(),Bridges.strength())
	Bridges.restore(battle)
	check(parts.all(func(part):return Bridges.health(battle,part)==0.0),prefix+"new version preserves deliberately destroyed neighboring sections")
	var snapshot: Dictionary = BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	battle.paused=false;get_tree().paused=false
	check(parts.all(func(part):return Bridges.health(battle,part)==0.0),prefix+"save reload does not repeat legacy repair on new destruction")
