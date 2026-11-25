extends "res://tests/special_mechanics_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for soviet in [false, true]:
			arena(mode)
			captured_technology(soviet, mode)
			await finish()
	arena(MatchRules.RA2)
	await attack_audio()
	await finish()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func captured_technology(soviet: bool, mode: String) -> void:
	battle._countries.ally = "Russians" if soviet else "Americans"
	var tank_id := "MTNK" if soviet else "HTNK"
	var secret := "CCOMAND" if soviet else "CIVAN"
	var power_id := "GAPOWR" if soviet else "NAPOWR"
	var native_hq = add("NACNST" if soviet else "GACNST", "ally", AIM)
	var barracks = add("NAHAND" if soviet else "GAPILE", "ally", AIM + Vector2(300, 0))
	var factory = add("GAWEAP" if soviet else "NAWEAP", "enemy", AIM + Vector2(0, 250))
	var hq = add("GACNST" if soviet else "NACNST", "enemy", AIM + Vector2(-300, 0))
	var hud = screen.hud
	hud.select_prod_tab("vehicle")
	check(not hud._unit_catalog().has(tank_id), "opposing vehicle hidden before capture")
	AlliedAbilities.change_side(factory, "ally")
	check(hud._unit_catalog().has(tank_id) and hud._producer_for(tank_id) == factory, "captured factory appears in vehicle routing")
	check(factory.enqueue(tank_id), "captured factory accepts basic tank", factory.queue_block_reason(tank_id))
	battle.power_low = false
	factory._process(100)
	check(battle.units.any(func(u): return u.unit_id == tank_id and u.side == "ally"), "opposing tank delivered")
	AlliedAbilities.change_side(factory, "enemy")
	check(not hud._unit_catalog().has(tank_id), "recaptured factory removes product")
	hud.select_prod_tab("building")
	check(not hud._building_catalog().has(power_id), "foreign construction roster starts hidden")
	AlliedAbilities.change_side(hq, "ally")
	check(hud._building_catalog().has(power_id), "captured construction yard adds power plant")
	native_hq._die()
	battle.request_structure(power_id)
	check(battle.struct_queue.any(func(job): return job.id == power_id), "captured yard accepts building order")
	battle._tick_structure_queue(1.0)
	check(not battle.struct_queue.is_empty() and battle.struct_queue[0].elapsed > 0.0, "captured yard works as only remaining yard")
	if mode == MatchRules.RA2:
		check(not battle.country_block_reason("GTGCAN").is_empty(), "French-only cannon stays country locked")
	hud.select_prod_tab("infantry")
	check(not barracks.can_queue(secret) and not hud._unit_catalog().has(secret), "foreign secret infantry needs infiltration")
	var lab = add("GATECH" if soviet else "NATECH", "enemy", AIM + Vector2(0, -350))
	var spy_unit = spawn("SPY", "ally", lab.position + Vector2.RIGHT * 65)
	AlliedAbilities.resolve_infiltration(spy_unit, lab)
	if mode==MatchRules.EXTENDED:
		check(not barracks.can_queue(secret), "new extension infiltration cannot bypass battle objective")
		add("NATECH" if soviet else "GATECH","ally",AIM+Vector2(400,-350))
		var card:String=GameData.FieldCommission.PRODUCTS[secret]
		# Fixture for captured-producer routing; objective events are tested separately.
		battle.allied_state.field_commissions={"ally":{card:{"count":GameData.FieldCommission.goal(card),"unlocked":true}}}
	check(hud._unit_catalog().has(secret) and hud._unit_state(secret).ok and barracks.enqueue(secret), "stolen tech unlocks native barracks and card", barracks.queue_block_reason(secret))
	check(not barracks.can_queue("PTROOP"), "other stolen technology stays locked")
	var saved := Snapshot.new().capture(battle)
	Snapshot.new().restore(battle, saved)
	var restored = battle.buildings.filter(func(b): return b.side == "ally" and b.building_id in ["GAPILE", "NAHAND"])[0]
	check(restored.production.has(secret) and restored.unit_prereqs_ok(secret), "stolen-tech order remains eligible after restore")
	hud.select_prod_tab("building")
	check(hud._building_catalog().has(power_id) and hud._unit_catalog().has(secret), "captured yard and stolen roster survive restore")

func attack_audio() -> void:
	for id in ["GHOST", "TANY", "FV", "BORIS", "SCHP", "BPLN", "E1"]:
		var u = spawn(id, "ally", AIM)
		var foe = spawn("E2", "enemy", AIM + Vector2.RIGHT * 50)
		if id == "FV":
			var passenger = spawn("E1", "ally", AIM)
			passenger.logistics.request_board(u)
			passenger.logistics.tick(1.0)
		if id == "SCHP": u._deployed = true
		for rank in [0, 2]:
			if rank == 2: u._grant_veteran(2, false)
			var w: Dictionary = u._weapon_for_target(foe)
			var report := str(w.get("report", ""))
			var files := GameData.ra2_sound_files(report)
			check(not files.is_empty() and files.all(func(f): return Ra2Sfx._stream(f) != null), id + " all report samples resolve at rank " + str(rank), [w.get("ra2_weapon_id"), report])
			check(Ra2Sfx.play_weapon(w, AIM), id + " fires through combat audio entry")
			await get_tree().process_frame
