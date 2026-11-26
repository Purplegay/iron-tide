extends "res://tests/command_voice_regression.gd"

func expect_sample(stem: String, label: String) -> void:
	var player = Ra2Sfx._eva_player
	var path := "res://assets/ra2/eva/" + stem + ".wav"
	check(player.playing and player.stream != null and player.stream.resource_path == path, label + " " + stem)

func exercise_garrison(world, prefix: String, infantry: String) -> void:
	const Civil = preload("res://scripts/units/civilian_orders.gd")
	var house = preload("res://scripts/world/civilian_sites.gd").create(world, "CAHSE01", world.player_start())
	var first = world.spawn_unit(infantry, "ally", house.position)
	var last = world.spawn_unit(infantry, "ally", house.position)
	Civil.enter(first, house)
	Civil.enter(last, house)
	Ra2Sfx.stop_all()
	Civil.withdraw(house, first)
	check(first.embarked_in == null and last.embarked_in == house and house.side == "ally" and not Ra2Sfx._eva_player.playing, prefix + " partial withdrawal stays silent")
	# Put every exit outside the map for one failed withdrawal.
	var original_position: Vector2 = house.position
	house.position = Vector2(-1000, -1000)
	Civil.withdraw(house, last)
	check(last.embarked_in == house and house.side == "ally" and not Ra2Sfx._eva_player.playing, prefix + " blocked last occupant stays silent")
	house.position = original_position
	Civil.withdraw(house, last)
	check(last.embarked_in == null and house.side == "neutral", prefix + " last occupant releases the house")
	expect_sample(prefix + "108", prefix + " last occupant announces abandonment")
	Civil.enter(first, house)
	Civil.enter(last, house)
	world.select_building(house)
	await reset()
	var before := Ra2Sfx.a_eva_plays
	world.deploy_selected()
	check(first.embarked_in == null and last.embarked_in == null and house.side == "neutral", prefix + " deploy command clears both occupants")
	expect_sample(prefix + "108", prefix + " group evacuation announces abandonment")
	check(Ra2Sfx.a_eva_plays == before + 1 and Ra2Sfx._eva_queue.is_empty(), prefix + " one announcement for the whole group")
	check(await peak() > 0.001, prefix + " evacuation recording reaches the mixer")
	Ra2Sfx.stop_all()
	Civil.evacuate(house)
	check(not Ra2Sfx._eva_player.playing, prefix + " empty house stays silent")
	var enemy = world.spawn_unit(infantry, "enemy", house.position)
	Civil.enter(enemy, house)
	check(enemy.embarked_in == house, prefix + " enemy occupies the house")
	Civil.evacuate(house)
	check(enemy.embarked_in == null and house.side == "neutral" and not Ra2Sfx._eva_player.playing, prefix + " enemy evacuation stays silent")

func exercise_advisor(country: String, prefix: String, opponent: String) -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"country":country, "enemy_base":opponent, "starting_funds":12000})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	var power: String = world.roster_id("GAPOWR")
	var mine: String = world.roster_id("GAREFN")
	var enemy_power: String = world.roster_id("GAPOWR", "enemy")
	var infantry: String = "E2" if country == "苏俄" else "E1"
	var barracks = world.buildings.filter(func(b):return b.side=="ally" and b.data.tags.has("barracks"))[0]
	await reset()
	screen.hud._start_build(power)
	expect_sample(prefix+"052",country+" orders construction")
	check(await peak() > 0.001, country+" advisor reaches audio mixer")
	Ra2Sfx.stop_all()
	world.structure_right_click(power)
	expect_sample(prefix+"056",country+" holds construction")
	Ra2Sfx.stop_all()
	world.request_structure(power)
	expect_sample(prefix+"052",country+" resumes construction")
	Ra2Sfx.stop_all()
	world.structure_right_click(power)
	world.structure_right_click(power)
	expect_sample(prefix+"056",country+" hold remains audible before cancel")
	check(Ra2Sfx._eva_queue.size()==1 and Ra2Sfx._eva_queue[0].file==prefix+"051.wav", country+" cancel follows hold")
	Ra2Sfx._eva_player.stop()
	Ra2Sfx._process(0)
	expect_sample(prefix+"051",country+" plays queued cancel")
	Ra2Sfx.stop_all()
	world.request_structure(power)
	world._tick_structure_queue(120)
	check(world.struct_ready.has(power) and Ra2Sfx._eva_queue.size()==1 and Ra2Sfx._eva_queue[0].file==prefix+"048.wav",country+" paid building ready")
	Ra2Sfx.stop_all()
	barracks.enqueue(infantry)
	expect_sample(prefix+"066",country+" barracks training")
	Ra2Sfx.stop_all()
	barracks.production_right_click(infantry)
	expect_sample(prefix+"056",country+" holds training")
	Ra2Sfx.stop_all()
	barracks.resume_production(infantry)
	expect_sample(prefix+"066",country+" resumes training")
	Ra2Sfx.stop_all()
	barracks._process(120)
	expect_sample(prefix+"062",country+" unit ready")
	var refinery = world.buildings.filter(func(b):return b.side=="ally" and b.building_id==mine)[0]
	refinery.hp -= 25
	Ra2Sfx.stop_all()
	world.apply_building_action("repair",refinery)
	expect_sample(prefix+"057",country+" repair")
	Ra2Sfx.stop_all()
	world.apply_building_action("sell",refinery)
	expect_sample(prefix+"058",country+" sell")
	Ra2Sfx.stop_all()
	world.request_structure(enemy_power,"enemy")
	check(not Ra2Sfx._eva_player.playing and Ra2Sfx._eva_queue.is_empty(),country+" enemy construction silent")
	var foreign_plant = world._place_building(enemy_power,"enemy",Vector2(1550,1250),true)
	AlliedAbilities.change_side(foreign_plant,"ally")
	foreign_plant.hp -= 25
	Ra2Sfx.stop_all()
	world.apply_building_action("repair",foreign_plant)
	expect_sample(prefix+"057",country+" captured building retains player advisor")
	await exercise_garrison(world, prefix, infantry)
	screen.free()
	await get_tree().process_frame

func _ready() -> void:
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0,capture)
	await get_tree().process_frame
	await exercise_advisor("苏俄","csof","allied")
	await exercise_advisor("美国","ceva","soviet")
	var report := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed,"driver":AudioServer.get_driver_name()},"  "))
	report.close()
	get_tree().quit(0 if failed==0 else 1)
