extends "res://tests/base_recovery_regression.gd"

var army: Array = []
var shots := 0
var firers := {}
var target

func count_projectile(node: Node) -> void:
	if node is Projectile and node.shooter() in army:
		if shots == 0: print("GGI missile=", node.ra2_image, " trail=", node.Visual.kind(node), " cooldown=", army[0].cooldown)
		shots += 1
		firers[node.shooter().get_instance_id()] = true

func sample(label: String, frames: int) -> void:
	var times := PackedFloat64Array()
	var previous := shots
	var initial_hp: float = target.hp
	for i in frames:
		var tick := Time.get_ticks_usec()
		await get_tree().process_frame
		times.append((Time.get_ticks_usec() - tick) / 1000.0)
	times.sort()
	print("GGI ", label, " median=", times[frames / 2], " p95=", times[ceili(frames * 0.95) - 1], " max=", times[-1], " shots=", shots - previous, " damage=", initial_hp - target.hp)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	start(MatchRules.EXTENDED)
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	var center: Vector2 = battle.player_start() + Vector2(220, 100)
	battle.camera.position = center
	for i in 64:
		var unit = battle.spawn_unit("GGI", "ally", center + Vector2((i % 8 - 4) * 17, (floori(i / 8.0) - 4) * 17))
		army.append(unit)
		battle.select_unit(unit, true)
	battle._emit_selection()
	battle.use_ability_selected(UnitSkillLayout.index(army[0], 2))
	check(army.all(func(unit): return unit.is_deployed()), "all guardians deployed")
	for unit in army: unit.fire_stance = "none"
	target = battle.spawn_unit("HTNK", "enemy", center + Vector2(225, 0))
	target.max_hp = 1000000.0
	target.hp = target.max_hp
	target.special.gm_stationary = true
	get_tree().node_added.connect(count_projectile)
	await sample("idle_selected", 90)
	for unit in army: unit.order_target(target, false, false)
	await sample("volley_selected", 180)
	var hp_after: float = target.hp
	battle.clear_selection()
	battle._emit_selection()
	await sample("volley_unselected", 180)
	check(target.hp < hp_after and hp_after < target.max_hp, "missiles hit before and after deselection")
	check(firers.size() == army.size(), "each guardian launched a missile", firers.size())
	var original_facing: float = army[0].hull_angle
	var previous_hp: float = target.hp
	target.global_position = center + Vector2(0, 225)
	await sample("target_relocated", 180)
	check(absf(angle_difference(original_facing, army[0].hull_angle)) > 0.5, "deployed launchers turn with the target")
	check(army.all(func(unit): return unit.is_deployed() and unit.aim_dir.dot(unit.global_position.direction_to(target.global_position)) > 0.98), "all deployed launchers track the new bearing")
	check(target.hp < previous_hp, "new bearing still delivers hits")
	await finish()
	print("GGI checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
