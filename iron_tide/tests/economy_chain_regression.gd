extends "res://tests/base_recovery_regression.gd"

const Economy = preload("res://scripts/world/economy_cycle.gd")
const Repack = preload("res://scripts/world/construction_repack.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Events.unit_died.connect(func(_node): deaths += 1)
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for side in ["ally", "enemy"]:
			await economy(mode, side)
		await growth(mode)
		await repack(mode)
	await delivery_training()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("ECONOMY_CHAIN checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func add_building(id: String, side: String, pos: Vector2):
	var b = battle._place_building(id, side, pos, true)
	b._buildup_play = -1.0
	return b

func delivery_training() -> void:
	var old_levels := MetaProgress.upgrade_levels.duplicate()
	var old_money := MetaProgress.currency.duplicate()
	MetaProgress.upgrade_levels.erase("ore_delivery")
	MetaProgress.currency.credits = 10000000.0
	for level in range(21):
		if level > 0:
			var before := MetaProgress.balance("credits")
			var price := MetaProgress.upgrade_cost("ore_delivery")
			check(MetaProgress.buy_upgrade("ore_delivery") and MetaProgress.balance("credits") == before - price,
				"delivery training purchase %d" % level)
		check(is_equal_approx(MetaProgress.stat_bonuses().ore_delivery_bonus, 1.0 + level * 0.005), "delivery multiplier level %d" % level)
	check(not MetaProgress.buy_upgrade("ore_delivery"), "delivery training stops at level twenty")
	for mode in [MatchRules.EXTENDED, MatchRules.RA2]:
		MetaProgress.upgrade_levels.ore_delivery = 20
		start(mode)
		MetaProgress.upgrade_levels.ore_delivery = 0 # The ongoing battle retains its opening level.
		battle.skirmish_ai.difficulty = 2
		for id in ["CMIN", "HARV"]:
			var miner = battle.spawn_unit(id, "ally", Vector2(900, 900))
			miner.cargo = miner.cargo_cap
			var raw: float = miner.cargo_value()
			var money: float = battle.funds
			miner._unload_cargo(miner.cargo * 0.25)
			miner._unload_cargo(miner.cargo)
			var trained := 1.1 if mode == MatchRules.EXTENDED else 1.0
			check(is_equal_approx(battle.funds - money, raw * trained), mode + " partial and full deliveries " + id)
		var purifier = add_building("GAOREP", "ally", Vector2(1100, 1050))
		battle.power_low = false
		var miner = battle.spawn_unit("CMIN", "ally", Vector2(900, 950))
		miner.cargo = miner.cargo_cap
		miner.cargo_gems = miner.cargo * 0.5
		var raw: float = miner.cargo_value()
		var money: float = battle.funds
		miner._unload_cargo(miner.cargo)
		check(is_equal_approx(battle.funds - money, raw * 1.25 * (1.1 if mode == MatchRules.EXTENDED else 1.0)), mode + " purifier stacks once on mixed ore")
		purifier.hp = 0
		var enemy = battle.spawn_unit("HARV", "enemy", Vector2(1500, 1500))
		enemy.cargo = enemy.cargo_cap
		money = battle.enemy_funds
		raw = enemy.cargo_value()
		enemy._unload_cargo(enemy.cargo)
		check(is_equal_approx(battle.enemy_funds - money, 2.0 * raw), mode + " hard AI gets only its own ore multiplier")
		BattleRequest.combat_context.bonuses.erase("ore_delivery_bonus")
		miner.cargo = miner.cargo_cap
		raw = miner.cargo_value()
		money = battle.funds
		miner._unload_cargo(miner.cargo)
		check(is_equal_approx(battle.funds - money, raw), mode + " legacy battle bonus defaults to one")
		await finish()
	MetaProgress.upgrade_levels = old_levels
	MetaProgress.currency = old_money
	MetaProgress.save()

func economy(mode: String, side: String) -> void:
	start(mode)
	prefix += side + ": "
	battle.power_low = false
	battle.enemy_power.low = false
	var refinery = add_building("GAREFN", side, Vector2(1000, 1000))
	var miner = battle.spawn_unit("CMIN", side, Vector2(1700, 1500))
	miner.cargo = miner.cargo_cap
	check(is_equal_approx(miner.cargo_value(), 500.0), prefix + "full ordinary ore cargo pays 500 before bonuses")
	miner.cargo_gems = miner.cargo
	check(is_equal_approx(miner.cargo_value(), 1000.0 if mode == MatchRules.RA2 else 500.0), prefix + "full gem cargo follows explicit mode valuation")
	miner.cargo = 10.0
	miner.cargo_gems = 5.0
	miner.home_base = refinery
	miner._home_tick = 100.0
	miner.harvest_state = "to_base"
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	miner.set_process(false)
	miner.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var origin: Vector2 = miner.global_position
	var money: float = battle.funds_for(side)
	var effects_before: int = battle.effects_root.get_child_count()
	miner._process_harvester(0.4)
	check(miner.global_position == origin and miner.chrono_return_elapsed > 0 and not miner._back_in, prefix + "loaded CMIN charges before returning, never reverses across map")
	var landing: Vector2 = miner._dock_stage()
	var blocker = battle.spawn_unit("MTNK", side, landing)
	miner._process_harvester(2.0)
	check(miner.global_position == origin and miner.chrono_return_blocked and miner.cargo == 10.0, prefix + "occupied landing retains load and waits")
	check(battle.funds_for(side) == money, prefix + "waiting never pays remotely")
	check(battle.effects_root.get_child_count() == effects_before, prefix + "charge and blocked arrival never play successful warp effects")
	battle.units.erase(blocker)
	blocker.free()
	battle.paused = true
	miner._process_harvester(2.0)
	check(miner.global_position == origin, prefix + "paused return does not teleport")
	battle.paused = false
	miner._process_harvester(0.1)
	check(miner.global_position.is_equal_approx(landing) and miner._last_water_pos == landing, prefix + "clear landing teleports to refinery approach")
	check(miner.cargo == 10.0 and battle.funds_for(side) == money and miner.harvest_state == "to_base", prefix + "teleport is not unloading or credit")
	await verify_warp_fx(mode, side, origin, landing, effects_before)
	miner._hull_prev = miner._dock_out.angle()
	miner._process_harvester(0.1)
	check(miner._dock_phase == 1 and miner._back_in, prefix + "only short final docking phase reverses")
	# A blocked return cannot remain charged after a player overrides the destination.
	miner.global_position = origin
	miner._unlock_dock()
	miner._process_harvester(0.4)
	miner.has_move_order = true
	miner.move_target = origin
	miner._process_harvester(0.1)
	check(miner.chrono_return_elapsed == 0.0 and not miner.chrono_return_blocked, prefix + "manual movement clears teleport charge")
	miner.has_move_order = false
	miner.global_position = origin
	miner.cargo = 0.0
	miner._unlock_dock()
	miner._lock_dock()
	check(not Economy.chrono_return(miner, 3.0) and miner.global_position == origin, prefix + "empty miner cannot teleport home")
	miner.cargo = 10.0
	miner.cargo_gems = 5.0
	var purifier = add_building("GAOREP", side, Vector2(1600, 950))
	check(not purifier.is_refinery() and not purifier.buildable.has("CMIN"), prefix + "purifier neither unloads nor manufactures miners")
	check(not GameData.RA2_TOKEN_IDS.PROC.has("GAOREP"), prefix + "purifier does not satisfy refinery prerequisite")
	check(is_equal_approx(Economy.income_factor(battle, side), 1.25), prefix + "operational purifier adds 25 percent")
	var other := "enemy" if side == "ally" else "ally"
	check(Economy.income_factor(battle, other) == 1.0, prefix + "purifier never benefits opposing owner")
	var raw: float = miner.cargo_value()
	miner._unload_cargo(4.0)
	check(is_equal_approx(battle.funds_for(side) - money, raw * 0.4 * 1.25), prefix + "mixed partial load receives purifier exactly once")
	check(miner.cargo == 6.0 and miner.cargo_gems == 3.0, prefix + "bonus does not multiply physical cargo")
	if side == "ally": battle.power_low = true
	else: battle.enemy_power.low = true
	check(Economy.income_factor(battle, side) == 1.0, prefix + "power outage disables purifier immediately")
	money = battle.funds_for(side)
	miner._unload_cargo(6.0)
	check(is_equal_approx(battle.funds_for(side) - money, raw * 0.6), prefix + "remaining unload uses current power state")
	if side == "ally": battle.power_low = false
	else: battle.enemy_power.low = false
	purifier.under_construction = true
	check(Economy.income_factor(battle, side) == 1.0, prefix + "unfinished purifier grants no bonus")
	purifier.under_construction = false
	purifier._prism_offline = 3.0
	check(Economy.income_factor(battle, side) == 1.0, prefix + "disrupted purifier grants no bonus")
	purifier._prism_offline = 0.0
	purifier.hp = 0.0
	check(Economy.income_factor(battle, side) == 1.0, prefix + "zero health purifier grants no bonus")
	purifier.hp = purifier.max_hp
	if side == "ally":
		battle.select_building(purifier)
		battle._emit_selection()
		check(screen.hud._refinery_btn == null and screen.hud.economy_status_label.text.contains("25%"), prefix + "purifier UI exposes bonus without miner button")
		await capture(mode + "-purifier", purifier.global_position)
		battle.select_unit(miner, false)
		battle._emit_selection()
		check(screen.hud.economy_status_bar != null and screen.hud.economy_status_label.text.contains("精炼"), prefix + "miner contextual status shows effective bonus")
		miner.harvest_state = "unloading"
		screen.hud._refresh_selection_live()
		check(screen.hud.economy_status_label.text.contains("正在卸矿"), prefix + "activity refreshes live without reselecting")
		await capture(mode + "-miner", miner.global_position)
		# Headless capture returns immediately; let the rebuilt containers settle.
		await get_tree().process_frame
		await get_tree().process_frame
		var status_rect: Rect2 = screen.hud.economy_status_label.get_global_rect()
		check(status_rect.end.y <= screen.hud._command_box.get_global_rect().position.y, prefix + "miner status is visible above commands without scrolling")
	# Loss of the destination drops its charge and looks for another refinery.
	refinery.hp = 0.0
	miner.cargo = 5.0
	miner.harvest_state = "to_base"
	miner._process_harvester(0.2)
	check(miner.home_base != refinery and miner.home_base != purifier and miner.cargo == 5.0, prefix + "destroyed refinery reroutes without losing cargo or choosing purifier")
	await finish()

func make_ore(pos: Vector2, amount: float, kind := "ore"):
	var node = preload("res://scripts/world/resource_node.gd").new()
	node.position = pos
	node.max_amount = 120.0
	node.amount = amount
	node.radius = 18.0
	node.resource_kind = kind
	battle.add_child(node)
	return node

func growth(mode: String) -> void:
	start(mode)
	var ore = make_ore(Vector2(1100, 1100), 60.0)
	var empty = make_ore(Vector2(1500, 1100), 0.0)
	var gems = make_ore(Vector2(1100, 1500), 0.0, "gems")
	ore._process(10.0)
	check(ore.amount == (84.0 if mode == MatchRules.EXTENDED else 60.0), prefix + "only extension mode retains linear refill")
	if mode == MatchRules.EXTENDED:
		Economy.tick(battle, 600.0)
		check(battle.ore_growth_elapsed == 0.0, prefix + "extension mode has no discrete expansion")
		await finish()
		return
	Economy.tick(battle, 299.0)
	check(ore.amount == 60.0, prefix + "RA2 ore waits for five-minute cycle")
	battle.paused = true
	Economy.tick(battle, 1000.0)
	check(battle.ore_growth_elapsed == 299.0, prefix + "pause does not accumulate growth time")
	battle.paused = false
	Economy.tick(battle, 1.0)
	check(is_equal_approx(ore.amount, 67.2), prefix + "living ore grows six percent of capacity per cycle")
	check(empty.amount == 0.0 and gems.amount == 0.0, prefix + "isolated depleted ore and gems never refill spontaneously")
	ore.amount = 120.0
	# Block first three neighbors with water, a unit and a building. Only north survives.
	battle.water_rects.append(Rect2(ore.position + Vector2(25, -25), Vector2(42, 50)))
	battle.path_service.set_water(battle.water_rects)
	var blocker = battle.spawn_unit("MTNK", "ally", ore.position + Vector2.DOWN * 46.0)
	var wall = add_building("GAWALL", "ally", ore.position + Vector2.LEFT * 46.0)
	var before: int = get_tree().get_nodes_in_group("resource_nodes").size()
	Economy.tick(battle, 300.0)
	var cells := get_tree().get_nodes_in_group("resource_nodes")
	check(cells.size() == before + 1, prefix + "one legal neighbor grows within spread budget")
	var child = cells.back()
	check(child.position.is_equal_approx(ore.position + Vector2.UP * 46.0) and child.amount == 10.0 and child.density_frame() == 0, prefix + "new ore starts at one density frame and avoids blocked neighbors", {"position": str(child.position), "source": str(ore.position), "amount": child.amount, "frame": child.density_frame()})
	child.extract(10.0)
	Economy.tick(battle, 300.0)
	check(get_tree().get_nodes_in_group("resource_nodes").size() == cells.size() and child.amount == 10.0 and not child.depleted, prefix + "neighbor reseeds existing empty cell without duplicate collision body")
	check(gems.amount == 0.0, prefix + "gem field remains finite across growth cycles")
	battle.ended = true
	var elapsed: float = battle.ore_growth_elapsed
	Economy.tick(battle, 300.0)
	check(battle.ore_growth_elapsed == elapsed, prefix + "finished matches do not grow ore")
	battle.ended = false
	blocker.hp = 0
	wall.hp = 0
	await finish()

func repack(mode: String) -> void:
	start(mode)
	var hq = battle._player_hq()
	# Original starting area can contain neighboring structures; its own footprint is ignored.
	check(Repack.check(battle, hq).ok, prefix + "completed construction yard can fold at its center", Repack.check(battle, hq))
	battle.select_building(hq)
	battle._emit_selection()
	check(screen.hud.cmd_buttons.has("deploy") and not screen.hud.cmd_buttons.deploy.disabled and screen.hud.cmd_buttons.deploy.text.contains("收起"), prefix + "construction yard has explicit cameo action")
	await capture(mode + "-repack", hq.global_position)
	if DisplayServer.get_name() != "headless":
		var previous := get_window().size
		get_window().size = Vector2i(1280, 720)
		await capture(mode + "-repack-1280", hq.global_position)
		var button: Button = screen.hud.cmd_buttons.deploy
		check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(button.get_global_rect()), prefix + "repack action remains inside 1280x720 viewport")
		get_window().size = previous
	battle.skirmish = false
	check(not Repack.check(battle, hq).ok, prefix + "campaign cannot fold last required HQ")
	battle.skirmish = true
	var blocker = battle.spawn_unit("MTNK", "ally", hq.global_position)
	check(not Repack.check(battle, hq).ok, prefix + "occupied MCV exit refuses conversion before mutation")
	battle.units.erase(blocker)
	blocker.free()
	hq.hp = hq.max_hp * 0.4
	battle.struct_queue.append({"id": "GAPOWR", "cost": 800.0, "time": 20.0, "elapsed": 5.0, "paid": 200.0})
	battle.struct_queue.append({"id": "GAPILL", "cost": 500.0, "time": 10.0, "elapsed": 2.0, "paid": 100.0})
	var jobs: Array = battle.struct_queue.duplicate(true)
	var money: float = battle.funds
	var death_count := deaths
	battle.deploy_selected()
	check(battle.selected_units.size() == 1 and battle.selected_units[0].unit_id == "AMCV", prefix + "D action transfers selection to new MCV")
	if battle.selected_units.is_empty():
		await finish()
		return
	var mcv = battle.selected_units[0]
	check(is_equal_approx(mcv.hp / mcv.max_hp, 0.4), prefix + "repack preserves health fraction")
	check(battle.funds == money and deaths == death_count and battle.struct_queue == jobs, prefix + "repack retains both paid queues without refund or death event")
	battle._tick_structure_queue(3.0)
	check(battle.struct_queue == jobs and battle.funds == money, prefix + "no HQ pauses both queues without charging")
	battle._check_end()
	check(not battle.ended and battle.has_surviving_assets("ally"), prefix + "MCV keeps player in match")
	check(not battle.construction_deploy_check(mcv).ok, prefix + "fold animation blocks immediate redeploy")
	mcv._physics_process(GameData.ra2_buildup_seconds())
	# Flush old StaticBody before checking deployment in the same location.
	await get_tree().process_frame
	check(battle.construction_deploy_check(mcv).ok and mcv.deploy(), prefix + "MCV can unfold again on cleared foundation")
	var restored = battle._player_hq()
	check(restored != null and is_equal_approx(restored.hp / restored.max_hp, 0.4), prefix + "round-trip preserves health")
	if restored != null: restored._buildup_play = -1.0
	battle._update_power()
	battle._tick_structure_queue(1.0)
	check(battle.struct_queue[0].elapsed > 5.0 and battle.struct_queue[1].elapsed > 2.0, prefix + "both categories resume from preserved progress")
	check(is_equal_approx(money - battle.funds, battle.struct_queue[0].paid + battle.struct_queue[1].paid - 300.0), prefix + "resumption charges new work only")
	await finish()

func verify_warp_fx(mode: String, side: String, origin: Vector2, landing: Vector2, before: int) -> void:
	var effects: Array = battle.effects_root.get_children().slice(before)
	check(effects.size() == 2, prefix + "successful teleport emits exactly two unit warp animations")
	if effects.size() != 2:
		return
	for i in 2:
		var effect = effects[i]
		var image := "WARPOUT"
		var pos := origin if i == 0 else landing
		check(effect.anim.image == image and effect.global_position == pos, prefix + image + " plays at its own endpoint")
		check(effect.anim.cell.x <= 68 and effect.anim.cell.y <= 52 and effect.anim.sound.is_empty(), prefix + image + " uses small original art without superweapon sound")
		check(effect.z_index == DepthLayers.GROUND_OBJ + 1 and effect.tint.a == 0.5 and not effect.bright, prefix + image + " is translucent ground art")
		check(effect.visible == battle.position_visible_to("ally", pos), prefix + image + " obeys visibility on its creation frame")
		effect.set_process(false)
		var initial_age: float = effect._age
		battle.paused = true
		effect._process(0.5)
		check(effect._age == initial_age, prefix + image + " pauses with simulation")
		battle.paused = false
		effect._process(0.2)
		check(effect.frame == 3 and not effect.is_queued_for_deletion(), prefix + image + " advances original frames with bounded presentation timing")
	if side == "ally":
		battle.fog.rebuild()
		for effect in effects: effect._process(0.0)
		await capture(mode + "-chrono-arrival", landing)
		# A scout permits an observable departure ring after the miner leaves.
		var scout = battle.spawn_unit("E1", "ally", origin + Vector2(0, 70))
		battle.fog.rebuild()
		for effect in effects: effect._process(0.0)
		await capture(mode + "-chrono-departure", origin)
		battle.units.erase(scout)
		scout.free()
	# Explicitly clear observer visibility to prove hidden rings do not leak
	# through explored terrain, then reveal only one endpoint.
	var saved: PackedByteArray = battle.fog.visible_cells.ally.duplicate()
	var hidden: PackedByteArray = saved.duplicate()
	hidden.fill(0)
	battle.fog.visible_cells.ally = hidden
	for effect in effects:
		effect._process(0.0)
		check(not effect.visible, prefix + "lost sight hides existing warp ring immediately")
	battle.fog._reveal("ally", landing, 80.0)
	for effect in effects: effect._process(0.0)
	check(not effects[0].visible and effects[1].visible, prefix + "departure and arrival visibility are independent")
	battle.fog.visible_cells.ally = saved
	for effect in effects:
		effect._process(2.0)
		check(effect.is_queued_for_deletion(), prefix + "completed warp animation frees itself")
	await get_tree().process_frame

func capture(label: String, pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless": return
	battle.camera.position = pos
	screen.hud._refresh_selection_live()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
