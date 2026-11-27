extends "res://tests/allied_abilities_regression.gd"
const Indicator = preload("res://scripts/ui/garrison_indicator.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Orders = preload("res://scripts/units/civilian_orders.gd")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	var home := Vector2(1500, 2100)
	var house: Building = Sites.create(battle, "CAHSE01", home)
	if battle.fog != null: battle.fog._reveal("ally", home, 300.0)
	await get_tree().process_frame
	var capacity := Orders.slots(house)
	var expected := Vector2i(0, capacity)
	check(capacity == 5 and Indicator.preview(house) == Vector2i.ZERO, mode + ": idle neutral house has no pips")
	battle.command_cursor.sample_pointer(house.art_center())
	check(battle.hover_entity == house and Indicator.preview(house) == expected, mode + ": pointer on neutral house previews five empty seats")
	var members: Array[Unit] = []
	for i in capacity:
		var soldier: Unit = actor("E1", "ally", home - Vector2(120, i * 16))
		Orders.enter(soldier, house)
		members.append(soldier)
		check(soldier.embarked_in == house and Indicator.preview(house) == Vector2i(i + 1, capacity), mode + ": real entry updates pips " + str(i + 1))
	check(house.side == "ally", mode + ": first entry claims the neutral building")
	battle._set_hover(null)
	battle.select_building(house)
	check(Indicator.preview(house) == Vector2i(capacity, capacity), mode + ": selection alone shows full garrison")
	Orders.withdraw(house, members[0])
	check(members[0].embarked_in == null and Indicator.preview(house) == Vector2i(capacity - 1, capacity), mode + ": real withdrawal frees one pip")
	var stale: Array = house.special.occupants
	stale.append(members[0])
	check(Indicator.preview(house) == Vector2i(capacity - 1, capacity) and stale.has(members[0]), mode + ": stale entries are ignored without mutating gameplay")
	stale.erase(members[0])
	battle._set_hover(house)
	BattleRequest.house_teams = {"ally": 1, "test_team": 1}
	house.side = "test_team"
	check(Indicator.preview(house) == Vector2i(capacity - 1, capacity), mode + ": teammates may inspect garrisons")
	house.side = "enemy"
	check(Indicator.preview(house) == Vector2i.ZERO, mode + ": hovered enemy does not disclose garrison strength")
	house.side = "ally"
	BattleRequest.house_teams.clear()
	house.under_construction = true
	check(Indicator.preview(house) == Vector2i.ZERO, mode + ": unfinished building has no pips")
	house.under_construction = false
	house.hide()
	check(Indicator.preview(house) == Vector2i.ZERO, mode + ": hidden building has no pips")
	house.show()
	Orders.evacuate(house)
	check(Indicator.preview(house) == expected, mode + ": evacuating all troops clears all filled pips")
	var bunker: Building = battle._place_building("NABNKR", "ally", home + Vector2(500, 0), true)
	battle._set_hover(bunker)
	check(Indicator.preview(bunker) == Vector2i(0, 5), mode + ": native infantry bunker shows its five slots")
	for row in [["NATBNK", 1], ["YAPOWR", 5]]:
		var site: Building = battle._place_building(row[0], "ally", home + Vector2(650, row[1] * 50), true)
		battle._set_hover(site)
		check(is_instance_valid(site) and Indicator.preview(site) == Vector2i(0, row[1]), mode + ": exact capacity for " + row[0])
	var repair: Building = Sites.create(battle, "CABHUT", home + Vector2(900, 0))
	battle._set_hover(repair)
	check(Indicator.preview(repair) == Vector2i.ZERO, mode + ": non-garrison building has no pips")
	house.hp = 0.0
	check(Indicator.preview(house) == Vector2i.ZERO, mode + ": destroyed building has no pips")
	check(Indicator.EMPTY.get_size() == Vector2(7, 14) and Indicator.OCCUPIED.get_size() == Vector2(6, 13), mode + ": original SHP frames loaded as textures")
	battle._set_hover(bunker)
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	screen.free()
	await get_tree().process_frame
