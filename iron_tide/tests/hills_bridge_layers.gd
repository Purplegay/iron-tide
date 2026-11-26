extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("HILLS ",ok," ",label)
	if not ok: failures+=1

func _ready() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":"yr_hills","opening":"mcv","fog_of_war":false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world = screen.battle
	var deck = world.ground.overpass
	check(deck.road.size()==93 and deck.ends.size()==18,"三座木桥的三格宽桥面和六端引道")
	var tank = world.spawn_unit("MTNK","ally",Vector2(73.5,64.5)*55)
	for pair in [[Vector2(73.5,64.5),Vector2.DOWN,22],[Vector2(76.5,54.5),Vector2.RIGHT,5],[Vector2(67.5,97.5),Vector2.RIGHT,4]]:
		tank.position=pair[0]*55
		for step in int(pair[2])+1:
			var before: Vector2=tank.position
			tank.position+=pair[1]*55
			deck.record_move(tank,before)
			if step<int(pair[2]):
				check(tank.special.has("hollywood_on_deck") and deck.pick_deck(tank.position+tank.bridge_contact_offset()).distance_to(tank.position)<0.1,"桥面移动和点选 %s" % tank.position)
		check(not tank.special.has("hollywood_on_deck"),"从另一端下桥")
	var street := Vector2(69.5,75.5)*55
	tank.position=street
	world.select_unit(tank,false)
	world._issue_order(Vector2(77.5,75.5)*55)
	var under := false
	for tick in 1800:
		await get_tree().physics_frame
		if tank.occluded_by_bridge and not tank.special.has("hollywood_on_deck"): under=true
		if not tank.has_move_order: break
	check(under and tank.position.distance_to(Vector2(77.5,75.5)*55)<18,"坦克沿地面横穿桥底")
	tank.position=Vector2(73.5,62.5)*55
	var goal := Vector2(73.5,75.5)*55
	world._issue_order(goal+deck.RISE)
	for tick in 2400:
		await get_tree().physics_frame
		if not tank.has_move_order: break
	check(tank.position.distance_to(goal)<18 and tank.special.has("hollywood_on_deck") and tank.z_index>deck.z_index,"坦克从桥头开上长桥")
	var lower = world.spawn_unit("MTNK","ally",goal)
	var damage = preload("res://scripts/world/bridge_damage.gd")
	var section: Rect2 = damage.section_at(world,goal)
	damage.damage_section(world,section,damage.strength())
	check(tank._dead and not lower._dead,"桥面坍塌时桥下车辆存活")
	check(not deck.pick_deck(goal+deck.RISE).is_finite(),"断口不能点选")
	for span: Rect2 in damage.spans(world):
		if span.encloses(section): damage.reset_health(world,span)
	damage.restore(world)
	check(deck.pick_deck(goal+deck.RISE).distance_to(goal)<1,"修复后恢复桥面")
	get_tree().quit(int(failures>0))
