extends "res://tests/base_recovery_regression.gd"
const NativeOre = preload("res://scripts/world/native_ore.gd")
const Economy = preload("res://scripts/world/economy_cycle.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	await check_global_mining()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for nation in ["美国", "苏俄"]:
			await exercise(mode, nation)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func check_global_mining() -> void:
	const MAP := "yr_crctbrd"
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"map_layout":MAP,"country":"美国","enemy_country":"苏俄","fog_of_war":true})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var nodes:=get_tree().get_nodes_in_group("resource_nodes")
	for node in nodes: node.amount=0
	for side in ["ally","enemy"]:
		var miner=battle.units.filter(func(u):return u.side==side and u.is_harvester)[0]
		var far_patch=null
		for node in nodes:
			var offset:Vector2i=(NativeOre.cell_at(node.position)-NativeOre.cell_at(miner.position)).abs()
			if maxi(offset.x,offset.y)<=int(NativeOre.rules(MAP).far_scan):continue
			if not battle.position_explored_by(side,node.position) and miner._ore_reachable(node):
				far_patch=node
				break
		check(far_patch!=null,side+" has a reachable unexplored ore tile beyond the native scan radius")
		if far_patch==null:continue
		far_patch.amount=8
		check(miner._native_ore_target(true)==null,side+" finishing a local patch does not take a distant detour with a partial load")
		miner.harvest_state="to_node"
		miner.resource_node=null
		miner.process_mode=Node.PROCESS_MODE_ALWAYS
		var departure: Vector2 = miner.position
		for tick in 300:
			await get_tree().physics_frame
			if miner.resource_node==far_patch and miner.position.distance_to(departure)>55:break
		check(miner.position.distance_to(departure)>55,side+" miner sets out for undiscovered ore on a real movement tick")
		miner.process_mode=Node.PROCESS_MODE_DISABLED
		check(miner.resource_node==far_patch and not battle.position_explored_by(side,far_patch.position),side+" automatic trip finds the distant tile without revealing it")
		far_patch.amount=0
	await finish()

func exercise(mode: String, nation: String) -> void:
	var id := "yr_ice_age" if nation=="美国" else "yr_isleland"
	prefix = mode + " " + nation + " "
	BattleRequest.configure_skirmish(mode, {"map_layout":id,"country":nation,"fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	for building in battle.buildings: building._buildup_play = -1
	var miners: Array = battle.units.filter(func(u):return u.side=="ally" and u.is_harvester)
	var miner = miners[0]
	var cap := 20 if nation == "美国" else 40
	check(miner.cargo_cap == cap and is_equal_approx(miner.harvest_rate,1), prefix+"native vehicle capacity and collection rate")
	var rules := NativeOre.rules(id)
	check(rules.grows == (id!="yr_ice_age") and rules.spreads and battle.get_node("NativeOreDrills").get_child_count()==rules.drills.size(),prefix+"map growth and ore drills")
	var nodes := get_tree().get_nodes_in_group("resource_nodes")
	check(nodes.all(func(n):return n.max_amount==12 and n.density_frame()==int(n.amount)-1 and not n.is_processing() and n._ore_texture!=null),prefix+"overlay density, theater art and zero linear refill")
	var funds_before: float = battle.funds
	var peak := 0.0
	for vehicle in miners:
		vehicle.process_mode = Node.PROCESS_MODE_ALWAYS
	for tick in 10800:
		await get_tree().physics_frame
		peak = maxf(peak, miner.cargo)
		if battle.funds>funds_before and peak>=cap: break
	check(peak==cap and battle.funds>funds_before,prefix+"starting miners autonomously gather across cells and deposit", [peak, battle.funds-funds_before,miner.harvest_state,str(miner.position),str(miner.home_base),miner._dock_locked,miner._dock_phase,miner.chrono_return_blocked])
	for vehicle in miners: vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	var patch = nodes[0]
	for n in nodes: n.amount=0
	patch.amount=4
	patch.resource_kind="gems"
	miner.cargo=0
	miner.cargo_gems=0
	miner.global_position=patch.position
	miner.resource_node=patch
	miner.harvest_state="harvesting"
	for i in 4:
		miner.special.erase("ore_bale_wait")
		miner._collect_native_bale(1.0,true)
	check(patch.is_empty() and miner.cargo==3 and miner.cargo_value()==150 and miner.harvest_state=="to_base", prefix+"last frame clears, gems pay 50, partial cargo returns")
	Economy.tick(battle, 10)
	check(nodes.all(func(n):return n.is_empty()),prefix+"cleared field stays empty without a seed")
	Economy.tick(battle, 14)
	var lived := get_tree().get_nodes_in_group("resource_nodes").filter(func(n):return not n.is_empty())
	check(not lived.is_empty() and lived.all(func(n):return n.resource_kind=="ore" and n.amount==4 and rules.drills.any(func(d):return (Vector2(NativeOre.cell_at(n.position))-Vector2(d[0],d[1])).abs().length_squared()<=8)),prefix+"only drill neighborhoods reseed")
	var snapshot = BattleSaves.Snapshot.new().capture(battle)
	check(BattleSaves.validate(snapshot).is_empty(), prefix+"native mineral state saves")
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	check(battle.get_node("NativeOreDrills").get_child_count()==rules.drills.size() and is_equal_approx(battle.allied_state.ore_drill_elapsed,24-ceilf(1.0/.003)/15), prefix+"restored drill clock and rigs")
	# Compatible pre-fix battles stored CMIN cargo in credits in extended mode.
	var legacy_miner = battle.units.filter(func(u):return u.side=="ally" and u.is_harvester)[0]
	battle.allied_state.erase("native_ore_version")
	legacy_miner.cargo = 125.0 if mode==MatchRules.EXTENDED and nation=="美国" else 5.0
	legacy_miner.cargo_gems = 0
	legacy_miner.harvest_rate = 22.0 if mode==MatchRules.EXTENDED else 0.88
	var legacy_snapshot = BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle, legacy_snapshot)
	var restored_miner = battle.units.filter(func(u):return u.side=="ally" and u.is_harvester)[0]
	check(restored_miner.cargo==5 and restored_miner.cargo_value()==125 and restored_miner.cargo_cap==cap and is_equal_approx(restored_miner.harvest_rate,1), prefix+"legacy load converted once")
	get_tree().paused=false
	await finish()
