extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("AUTO_HARVEST checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func tick(unit, seconds: float) -> void:
	for i in roundi(seconds * 10.0): unit._physics_process(0.1)

func exercise(mode: String) -> void:
	start(mode)
	GM.god_mode = false
	var ore := ResourceNode.new()
	ore.position = Vector2(1500, 1500)
	battle.add_child(ore)
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1200, 1500))
	miner.process_mode = Node.PROCESS_MODE_ALWAYS
	miner.set_physics_process(false)
	await get_tree().physics_frame
	miner.order_stop()
	var destination := Vector2(1550, 1500)
	var requests: int = battle.path_service.stats_requests
	miner._steer_field_to(destination)
	check(miner._path_pts.size() >= 2 and miner._steer_dir(destination) != Vector2.ZERO and battle.path_service.stats_requests == requests, prefix + "mining route steers without a full map field")
	miner._path_pts.clear()
	miner._steer_dir(destination)
	check(miner.path_field != null and battle.path_service.stats_requests == requests + 1, prefix + "missing route requests the fallback field")
	miner._steer_dir(destination)
	check(battle.path_service.stats_requests == requests + 1, prefix + "subsequent steering reuses the field")
	miner.order_stop()
	var start_at: Vector2 = miner.position
	check(miner.ability_at(0).id == "miner_auto_harvest" and miner.ability_info(0).active, prefix + "native Q defaults enabled in both rules modes")
	tick(miner, 9.0)
	check(miner.harvest_state == "idle" and miner.position == start_at, prefix + "stopped miner waits rather than immediately restarting")
	tick(miner, 1.2)
	check(miner.harvest_state == "to_node" and miner.resource_node == ore, prefix + "idle timeout enters real harvest state with claimed ore")
	check(ore.claim_owner() == miner, prefix + "automatic order uses real ore reservation")
	miner.order_stop()
	check(ore.claim_owner() == null, prefix + "stop releases ore reservation")
	miner.use_ability(0)
	tick(miner, 20.0)
	check(miner.harvest_state == "idle" and miner.auto_harvest_idle == 0.0, prefix + "disabled toggle keeps idle miner stopped")
	miner.order_harvest(ore)
	check(not miner.auto_harvest_enabled and miner.harvest_state == "to_node", prefix + "manual mining remains available while automatic recovery is disabled")
	miner.use_ability(0)
	miner.harvest_state = "unloading"
	miner.cargo = 10.0
	miner.use_ability(0)
	check(miner.harvest_state == "unloading" and miner.cargo == 10.0, prefix + "toggle does not cancel unloading or discard cargo")
	miner.use_ability(0)
	miner.order_stop()
	tick(miner, 10.2)
	check(miner.harvest_state == "to_base", prefix + "idle miner with cargo returns to refinery before finding new ore")
	miner.cargo = 0.0
	miner.order_move(Vector2(1800, 1500))
	miner.move_speed = 0.0
	tick(miner, 20.0)
	check(miner.has_move_order and miner.auto_harvest_idle == 0.0 and miner.harvest_state == "idle", prefix + "long manual move is not stolen by recovery")
	miner.position = miner.move_target
	miner._clear_field()
	miner._physics_process(0.1)
	check(not miner.has_move_order and miner.harvest_state == "idle", prefix + "manual move arrival starts idle waiting")
	miner.order_guard()
	tick(miner, 20.0)
	check(miner.hold_position and miner.harvest_state == "idle" and miner.auto_harvest_idle == 0.0, prefix + "guard stays at its assigned position")
	miner.order_stop()
	miner.auto_harvest_idle = 8.0
	miner._stun_timer = 2.0
	miner._physics_process(0.1)
	check(miner.auto_harvest_idle == 0.0 and not miner.ability_ready(0), prefix + "stun suspends idle clock and skill")
	miner._stun_timer = 0.0
	var peer = battle.spawn_unit("CMIN", "ally", Vector2(1100, 1500))
	miner.embarked_in = peer
	miner.auto_harvest_idle = 8.0
	miner._physics_process(0.1)
	check(miner.auto_harvest_idle == 0.0 and not miner.ability_ready(0), prefix + "transported miners never start collecting")
	miner.embarked_in = null
	miner.repairing = true
	miner.auto_harvest_idle = 8.0
	miner._physics_process(0.1)
	check(miner.auto_harvest_idle == 0.0, prefix + "repair resets idle recovery clock")
	miner.order_stop()
	ore.amount = 0.0
	tick(miner, 20.0)
	check(miner.harvest_state == "idle" and miner.resource_node == null, prefix + "no ore retries without creating invalid targets")
	ore.amount = ore.max_amount
	tick(miner, 10.2)
	check(miner.resource_node == ore, prefix + "ore regeneration makes later idle retry succeed")
	miner.order_stop()
	var refinery = miner._pick_home_base()
	refinery.under_construction = true
	tick(miner, 10.2)
	check(miner.harvest_state == "idle", prefix + "no operational refinery keeps automatic recovery waiting")
	refinery.under_construction = false
	# Real skill button and hotkey, including a mixed selection.
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	battle.select_unit(miner, false)
	battle._emit_selection()
	await get_tree().process_frame
	var hud = screen.hud
	check(hud.ability_panel.visible and hud._ability_btns[2].tooltip_text.contains("[E]"), prefix + "HUD exposes native toggle with E hint")
	hud._ability_btns[2].pressed.emit()
	hud._update_ability_live()
	check(not miner.auto_harvest_enabled and hud._ability_btns[2].get_meta("name_label").text == "自动采矿：关", prefix + "button toggles off and refreshes state label")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	get_viewport().push_input(key, true)
	check(miner.auto_harvest_enabled, prefix + "E uses real HUD skill handler")
	var tank = battle.spawn_unit("MTNK", "ally", Vector2(1000, 1500))
	var ability := Ability.new()
	ability.setup({"id": "test_heal", "effect": "heal"})
	tank.skills = [ability]
	battle.select_unit(peer, true)
	battle.select_unit(tank, true)
	check(battle.use_ability_selected(0) == 2 and not miner.auto_harvest_enabled and not peer.auto_harvest_enabled and ability.cd_left == 0.0, prefix + "mixed group toggles miners without casting unrelated skills")
	miner.auto_harvest_enabled = true
	miner.auto_harvest_idle = 4.0
	check(BattleSaves.save_slot(battle, "slot1").ok, prefix + "save accepts new toggle and elapsed clock")
	# Emulate the previous schema/content fingerprint, not a permissive generic version bypass.
	var envelope: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(BattleSaves.slot_path("slot1")).slice(48))
	var snapshot: Dictionary = bytes_to_var(envelope.payload)
	for record in snapshot.records:
		if record.kind == "unit":
			record.fields.erase("auto_harvest_enabled")
			record.fields.erase("auto_harvest_idle")
			record.fields.skills = record.fields.skills.filter(func(ref): return snapshot.records[ref["@ref"]].fields.id != "miner_auto_harvest")
	envelope.payload = var_to_bytes(snapshot)
	envelope.hash = BattleSaves.digest(envelope.payload)
	envelope.content = BattleSaves.pre_auto_harvest_hash()
	var file := FileAccess.open(BattleSaves.slot_path("slot2"), FileAccess.WRITE)
	file.store_buffer(BattleSaves.pack_file(envelope))
	file.close()
	if DisplayServer.get_name() != "headless":
		battle.select_unit(miner, false)
		battle._emit_selection()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-toggle.png"))
	await finish()
	for slot in ["slot1", "slot2"]:
		check(BattleSaves.prepare_load(slot).ok, prefix + slot + " current/previous save schema loads")
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		var miners: Array = battle.units.filter(func(u): return u.is_harvester)
		check(miners[0].auto_harvest_enabled and miners[0].auto_harvest_idle == (4.0 if slot == "slot1" else 0.0), prefix + slot + " idle timer restored or legacy default supplied")
		check(miners[1].auto_harvest_enabled == (slot == "slot2"), prefix + slot + " disabled preference survives in new saves")
		check(miners[0].ability_at(0).id == "miner_auto_harvest" and miners[1].ability_at(0).id == "miner_auto_harvest", prefix + slot + " skill restored once for each miner")
		get_tree().paused = false
		await finish()
