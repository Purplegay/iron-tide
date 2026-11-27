extends Node

var failed := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print("DISK ", ok, " ", label)

func _ready() -> void:
	var isolated := OS.get_environment("IRON_TIDE_DISK_TEST_USER").replace("\\", "/").to_lower()
	if isolated.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolated + "/"):
		push_error("Use an isolated APPDATA for this test.")
		get_tree().quit(2)
		return
	call_deferred("run")

func run() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "starting_funds": 20000, "fog_of_war": false})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_power = false
	var plant = world._place_building("NANRCT", "ally", Vector2(1800, 1600), true)
	var defense = world._place_building("TESLA", "ally", Vector2(2100, 1600), true)
	var factory = world._place_building("NAWEAP", "ally", Vector2(2100, 1900), true)
	var refinery = world._place_building("NAREFN", "ally", Vector2(1800, 1900), true)
	var disc = world.spawn_unit("DISK", "enemy", Vector2(1860, 1600))
	await get_tree().process_frame
	# The frozen scene does not advance the placement animation of instant buildings.
	defense._buildup_play = -1.0
	world._update_power()
	check(world.power_stats().produced > 0 and defense.is_operational() and is_equal_approx(world.power_build_factor(), 1.0), "基地原本供电充足")
	var plant_hp: float = plant.hp
	var warnings: Array[String] = []
	Events.battle_message.connect(func(text: String, _color: Color):
		if text.begins_with("镭射幽浮正在吸取电力"): warnings.append(text))
	disc.order_target(plant, false, false)
	check(disc._active_weapon().name == "DiskDrain", "核电站走汲取武器")
	disc._fire_shot(plant, true)
	world._update_power()
	check(plant.hp == plant_hp and world.side_power_blackout("ally"), "实际开火造成断电而不扣核电站血量")
	check(not defense.is_operational(), "依赖电力的磁暴线圈停工")
	check(is_equal_approx(world.power_build_factor(), world.POWER_MIN_LOW_SPEED), "电厂账面富余时生产仍按断电减速")
	check(world.power_stats().produced == 0 and "基地断电" in world.hud.power_sub.text, "实际 HUD 显示断电、有效供电为零")
	world.allied_state.blackout_ally = 10.0
	disc._fire_shot(plant, true)
	check(world.allied_state.blackout_ally == 10.0, "吸电不缩短更长的既有停电")
	check(warnings.size() == 1, "断电事件只在首次吸电时提示，不重复刷屏")
	world.allied_state.blackout_ally = 0.01
	world._process(0.02)
	check(not world.side_power_blackout("ally") and defense.is_operational() and is_equal_approx(world.power_build_factor(), 1.0), "停电自然结束后生产及防御恢复")
	check(world.power_stats().produced > 0 and not "基地断电" in world.hud.power_sub.text, "实际 HUD 清除断电提示")
	var factory_hp: float = factory.hp
	disc.order_target(factory, false, false)
	check(disc._active_weapon().name == "DiskLaser", "普通车厂走主激光")
	disc._fire_shot(factory, true)
	check(factory.hp < factory_hp and not world.side_power_blackout("ally"), "主激光实际扣车厂血量但不切断电网")
	var funds: float = world.funds_for("ally")
	var enemy_funds: float = world.funds_for("enemy")
	var refinery_hp: float = refinery.hp
	disc.order_target(refinery, false, false)
	check(disc._active_weapon().name == "DiskDrain", "苏军采矿场走汲取武器")
	disc._fire_shot(refinery, true)
	check(world.funds_for("ally") == funds - 50 and world.funds_for("enemy") == enemy_funds + 50, "实际开火从玩家转给敌方 50 资金")
	check(refinery.hp == refinery_hp and not world.side_power_blackout("ally"), "采矿场不掉血也不断电")
	check(world.hud._logs.back().node.text == "敌方镭射幽浮从我方采矿场偷走 50 资金。", "实际 HUD 日志显示偷款缘由和金额")
	world.funds = 12.0
	GM.infinite_funds = true
	disc._fire_shot(refinery, true)
	GM.infinite_funds = false
	check(world.funds_for("ally") == 0 and world.funds_for("enemy") == enemy_funds + 62, "免费购买开关不使偷款凭空造钱，余额不足只偷实有数")
	var last_log = world.hud._logs.back().node
	disc._fire_shot(refinery, true)
	check(world.funds_for("enemy") == enemy_funds + 62 and world.hud._logs.back().node == last_log, "空余额不转账也不追加提示")
	var enemy_refinery = world._place_building("NAREFN", "enemy", Vector2(1800, 2200), true)
	var friendly_disc = world.spawn_unit("DISK", "ally", Vector2(1860, 2200))
	friendly_disc.order_target(enemy_refinery, false, false)
	friendly_disc._fire_shot(enemy_refinery, true)
	check(world.funds_for("ally") == 50 and world.funds_for("enemy") == enemy_funds + 12 and world.hud._logs.back().node.text == "镭射幽浮从敌方采矿场偷到 50 资金。", "玩家幽浮偷款反向转账并显示收入")
	Ra2Sfx.stop_all()
	Music.stop()
	Music.player.stream = null
	print("DISK checks=", checks, " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
