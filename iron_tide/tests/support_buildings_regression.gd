extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for owner in ["ally", "enemy"]:
			start(mode)
			prefix += owner + ": "
			GM.god_mode = false
			GM.one_shot_kill = false
			GM.infinite_funds = false
			for b in battle.buildings: b.free()
			battle.buildings.clear()
			battle.power_low = false
			battle.enemy_power.low = false
			prism(owner)
			await finish()
		start(mode)
		GM.god_mode = false
		GM.one_shot_kill = false
		GM.infinite_funds = false
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle.power_low = false
		battle.enemy_power.low = false
		intelligence()
		await finish()
		start(mode)
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle.power_low = false
		battle.enemy_power.low = false
		chrono()
		await finish()
		start(mode)
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		battle.power_low = false
		battle.enemy_power.low = false
		storm()
		await finish()
		start(mode)
		for b in battle.buildings: b.free()
		battle.buildings.clear()
		walls()
		for data in GameData.units + GameData.buildings:
			check(EntityDescription.text(data).length() >= 10, prefix + "description " + str(data.id))
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	print("SUPPORT_BUILDINGS checks=", checks.size(), " failed=", failed)
	Ra2Sfx.stop_all()
	Music.stop()
	Music.player.stream = null
	await get_tree().process_frame
	# Mixer shutdown follows wall time, not this suite's fixed simulation FPS.
	OS.delay_msec(150)
	await get_tree().process_frame
	get_tree().quit(0 if failed == 0 else 1)

func add(id: String, side: String, point: Vector2):
	var b = battle._place_building(id, side, point, true)
	b._buildup_play = -1.0
	b._cd = 0.0
	return b

func prism(owner: String) -> void:
	var main = add("ATESLA", owner, Vector2(1000, 1000))
	var opposite := "enemy" if owner == "ally" else "ally"
	var target = battle.spawn_unit("MTNK", opposite, Vector2(1400, 1000))
	var helper = add("ATESLA", owner, Vector2(650, 1000))
	check(helper.position.distance_to(target.position) > helper._prism_support_range, prefix + "fixture supporter cannot directly reach enemy")
	check(is_equal_approx(main._prism_support_chain(target), 2.5), prefix + "one support adds 150 percent toward firing tower")
	check(is_equal_approx(helper._prism_offline, 3.0), prefix + "YR raw support delay 45 ticks")
	check(helper._prism_aim.distance_to(main.position) < 150.0, prefix + "support beam ends at firing tower")
	check(main._prism_support_chain(target) == 1.0, prefix + "same supporter cannot fire twice while recovering")
	helper._prism_offline = 0.0
	helper._cd = 1.0
	check(main._prism_support_chain(target) == 1.0, prefix + "busy weapon cannot supply energy")
	helper._cd = 0.0
	for i in 10: add("ATESLA", owner, Vector2(800, 800) + Vector2(i * 5, 0))
	check(is_equal_approx(main._prism_support_chain(target), 13.0), prefix + "support caps at eight")
	for b in battle.buildings: b._prism_offline = 0
	if owner == "ally": battle.power_low = true
	else: battle.enemy_power.low = true
	check(main._prism_support_chain(target) == 1.0, prefix + "low power prevents support")

func intelligence() -> void:
	var sat = add("GASPYSAT", "ally", Vector2(300, 300))
	var gap = add("GAGAP", "enemy", Vector2(1800, 1800))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(1750, 1750))
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	check(battle.fog.is_visible_at("ally", Vector2(2100, 300)), prefix + "satellite reveals remote map")
	check(not battle.fog.is_visible_at("ally", target.position) and not battle.fog.is_explored_at("ally", target.position), prefix + "gap reshrouds satellite intelligence")
	check(not target.visible, prefix + "gap hides actual enemy actor")
	var scout = battle.spawn_unit("MTNK", "ally", Vector2(1700, 1700))
	battle.fog.rebuild()
	check(battle.fog.is_visible_at("ally", target.position) and target.visible, prefix + "nearby real scouting penetrates gap")
	scout.position = Vector2(300, 300)
	gap.under_construction = true
	battle.fog.rebuild()
	check(battle.fog.is_visible_at("ally", target.position), prefix + "unfinished gap cannot hide targets")
	gap.under_construction = false
	battle.enemy_power.low = true
	battle.fog.rebuild()
	check(battle.fog.is_visible_at("ally", target.position), prefix + "enemy power loss disables gap")
	battle.power_low = true
	battle.fog.rebuild()
	check(not battle.fog.is_visible_at("ally", Vector2(2100, 300)), prefix + "satellite power loss restores normal fog")
	check(battle.fog.is_explored_at("ally", Vector2(2100, 300)), prefix + "lost satellite retains terrain exploration")
	sat.under_construction = true
	battle.power_low = false
	battle.fog.rebuild()
	check(not battle.fog.is_visible_at("ally", Vector2(2100, 300)), prefix + "unfinished satellite cannot reveal map")

func chrono() -> void:
	var building = add("GACSPH", "ally", Vector2(300, 300))
	building._sw_charge = building.sw_recharge()
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1000, 1000))
	var infantry = battle.spawn_unit("E1", "ally", Vector2(1010, 1030))
	var enemy = battle.spawn_unit("MTNK", "enemy", Vector2(1040, 1040))
	battle.selected_units.clear()
	battle.arm_superweapon(building)
	battle._issue_command_at(Vector2(1000, 1000))
	check(battle._chrono_source_point == Vector2(1000, 1000) and building.sw_ready(), prefix + "first click chooses area without consuming charge or unit selection")
	battle._issue_command_at(Vector2(-100, -100))
	check(building.sw_ready() and tank.position == Vector2(1000, 1000), prefix + "outside-map landing retains charge")
	battle._issue_command_at(Vector2(1800, 800))
	check(tank.position == Vector2(1800, 800) and not building.sw_ready(), prefix + "second click transfers vehicle and spends charge")
	check(infantry._dead and enemy.position == Vector2(1840, 840), prefix + "ordinary infantry dies and hostile vehicle is transported")
	check(tank._stun_timer == 4.0 and not tank.has_move_order, prefix + "transfer stops old orders and adds source delay")
	check(battle.command_mode.is_empty() and not battle._chrono_source_point.is_finite(), prefix + "successful transfer clears targeting")
	building._sw_charge = building.sw_recharge()
	battle.arm_superweapon(building)
	battle._issue_command_at(tank.position)
	battle.arm_command("")
	check(building.sw_ready() and not battle._chrono_source_point.is_finite(), prefix + "cancel clears source without spending charge")

func storm() -> void:
	var source = add("GAWEAT", "ally", Vector2(300, 300))
	var target = add("GAPOWR", "enemy", Vector2(1600, 1600))
	var friend = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var far = battle.spawn_unit("MTNK", "enemy", Vector2(2200, 2200))
	var hp: float = target.hp
	var friend_hp: float = friend.hp
	var far_hp: float = far.hp
	var expected := Ra2Damage.target_damage(250, "IonWH", target, 0)
	source._storm_damage(target.position, 0)
	check(is_equal_approx(hp - target.hp, Ra2Damage.quantize(CombatMath.with_defense(expected, target.bonuses))), prefix + "lightning damages buildings using IonWH and defense", {"expected_before_defense": expected, "actual": hp - target.hp})
	check(friend.hp < friend_hp, prefix + "lightning includes friendly fire")
	check(far.hp == far_hp, prefix + "lightning respects warhead radius")
	var before: int = battle.effects_root.get_child_count()
	source._play_storm_bolt(Vector2(1200, 1200))
	check(battle.effects_root.get_child_count() == before + 3, prefix + "original cloud bolt impact are all instantiated")
	source._sw_charge = source.sw_recharge()
	check(source.fire_superweapon(Vector2(1200, 1200)), prefix + "ready weather controller starts superweapon")
	check(source._storm_active and is_equal_approx(source._storm_delay, 250.0 / 15.0), prefix + "source deferment retained")
	battle.power_low = true
	LightningStorm.tick(battle, 1.0)
	check(source._storm_active and source._storm_delay < 250.0 / 15.0, prefix + "fired storm survives loss of power")
	for image in ["WCCLOUD1", "WCCLOUD2", "WCCLOUD3", "EXPLOLB"]:
		check(ResourceLoader.exists("res://assets/ra2/fx/" + image + ".png"), prefix + "imported original animation " + image)

func walls() -> void:
	# Walls do not extend build range. The fixture needs a real BaseNormal source.
	add("GACNST", "ally", Vector2(1040, 800))
	var endpoint = add("GAWALL", "ally", Vector2(1080, 1000))
	var start_wall = add("GAWALL", "ally", Vector2(1000, 1000))
	var placement: Dictionary = battle.build_spot_ok(Vector2(1040, 1000), GameData.get_building("GAWALL"), true)
	check(placement.ok, prefix + "wall fixture has legitimate construction range", placement)
	var before: float = battle.funds
	check(WallArt.bridge(battle, start_wall) == 1, prefix + "wall fills one straight gap")
	check(battle.funds == before - 100, prefix + "extra wall segment is paid once")
	check(WallArt.mask_at(Vector2(1040, 1000), "GAWALL", "ally", battle.buildings) == 5, prefix + "automatic wall has both connection bits")
	check(WallArt.bridge(battle, start_wall) == 0 and battle.funds == before - 100, prefix + "repeated bridge cannot overlap or charge twice")
	endpoint.position = Vector2(1200, 1000)
	var next = add("GAWALL", "ally", Vector2(1120, 1000))
	battle.funds = 99
	check(WallArt.bridge(battle, next) == 0 and battle.funds == 99, prefix + "insufficient funds cannot create free wall")
