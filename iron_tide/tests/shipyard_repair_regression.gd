extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for id in ["GAYARD", "NAYARD"]:
			await service(mode, id)
	var out := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks": checks, "failed": failed}))
	out.close()
	get_tree().quit(0 if failed == 0 else 1)

func service(mode: String, id: String) -> void:
	start(mode)
	prefix += id + " "
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle.water_rects = [Rect2(850, 300, 1350, 1800)]
	battle.path_service.set_water(battle.water_rects)
	var yard = battle._place_building(id, "ally", Vector2(1100,1100), true)
	yard._buildup_play = -1
	var plant = battle._place_building("GAPOWR", "ally", Vector2(600,1100), true)
	plant._buildup_play = -1
	battle._update_power()
	if id == "GAYARD" and mode == MatchRules.EXTENDED:
		yard.data = yard.data.duplicate(true)
		yard.data.tags.erase("repair")
		yard._is_repair = false
		var codec := preload("res://scripts/save/battle_snapshot.gd").new()
		var snapshot := codec.capture(battle)
		codec.restore(battle, snapshot)
		yard = battle.buildings[0]
		battle.paused = false
		get_tree().paused = false
	battle._refresh_pathing()
	var ship = battle.spawn_unit("DEST" if id == "GAYARD" else "HYD", "ally", Vector2(1680,1100))
	ship.process_mode = Node.PROCESS_MODE_ALWAYS
	ship.set_physics_process(false)
	yard.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	battle.select_unit(ship,false)
	var click: Vector2 = RepairDock.pad(yard)
	check(not ship.can_repair_at(yard), prefix + "undamaged ship does not request service")
	ship.hp -= 16
	var initial_hp: float = ship.hp
	check(yard.is_repair_depot() and battle.command_cursor.resolve(click) == "repair", prefix + "yard berth offers repair cursor", [yard.side,yard.is_repair_depot(),yard.is_operational(),ship.can_repair_at(yard),battle.command_cursor.resolve(click),yard._buildup_play,battle.ended,battle.power_low,yard.data.tags,GameData.get_building(id).tags])
	battle._issue_order(click)
	check(ship.repairing and ship.repair_depot == yard, prefix + "right click orders ship into friendly dock")
	battle.funds = 100
	yard._process_repair(1)
	check(ship.hp == initial_hp and battle.funds == 100, prefix + "no healing or charge on the approach")
	battle.funds = 0
	for i in 1800:
		ship._physics_process(1.0/60.0)
		yard._process_repair(1.0/60.0)
		if ship.position.distance_to(click) <= 2: break
	check(ship.position.distance_to(click) <= 6 and ship.hp == initial_hp, prefix + "physically docked and waits for funds", [ship.position,click,ship.special.get("repair_entry")])
	var squid = battle.spawn_unit("SQD","enemy",ship.position + Vector2.RIGHT*30)
	squid._fire_shot(ship)
	check(squid.embarked_in==ship,prefix+"squid attached to damaged ship alongside")
	yard._process_repair(1.0)
	check(squid.embarked_in==ship and ship.hp==initial_hp,prefix+"unpaid repair cannot evict squid")
	battle.funds = 100
	yard._process_repair(1.0)
	check(squid.embarked_in==null and squid._stun_timer==10 and battle.on_water(squid.position) and squid.position.distance_to(ship.position)>=squid.radius+ship.radius,prefix+"paid repair ejects squid into adjacent open water")
	for i in 1200:
		ship._physics_process(1.0/60.0)
		yard._process_repair(1.0/60.0)
		if ship.hp == ship.max_hp and not ship.repairing and not ship.special.has("repair_exit_point") and ship.position.distance_to(click) > 130: break
	check(ship.hp == ship.max_hp and is_equal_approx(100.0 - battle.funds,16.0 * float(ship.data.cost) * yard.REPAIR_PERCENT / ship.max_hp), prefix + "pays for exactly the missing HP")
	check(not ship.repairing and ship.position.distance_to(click) > 130 and battle.on_water(ship.position), prefix + "fully repaired ship exits to water")
	if battle.fog != null:
		battle.fog.free()
		battle.fog=null
	var victim=battle.spawn_unit("DRED","ally",Vector2(1600,1850))
	var gripper=battle.spawn_unit("SQD","enemy",victim.position+Vector2.RIGHT*30)
	gripper._fire_shot(victim)
	var transport=battle.spawn_unit("SAPC","ally",Vector2(700,1850))
	var rules=preload("res://scripts/units/soviet_specials.gd")
	check(not rules.squid_target(transport),prefix+"amphibious transport on land cannot be grabbed")
	transport.position=Vector2(1900,1850)
	check(rules.squid_target(transport),prefix+"same transport becomes a grab target in water")
	var origin:Vector2=victim.position
	var destination:=Vector2(1650,600)
	var moved:bool=preload("res://scripts/world/chronoshift.gd").move(yard,destination,origin)
	check(moved and victim.position==destination and gripper.embarked_in==null and gripper.position.distance_to(origin)<=60 and gripper._stun_timer==10,prefix+"chronoshift leaves squid in water at origin")
	await finish()
