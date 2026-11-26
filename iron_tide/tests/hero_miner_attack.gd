extends "res://tests/commando_hero_regression.gd"

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	boot("BORIS")
	var miner = battle.spawn_unit("HARV", "ally", Vector2(850, 900))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(930, 900))
	check(preload("res://scripts/units/convoy_heroes.gd").promote(miner, battle, MetaProgress), "promoted miner")
	battle.selected_units.assign([miner])
	var point: Vector2 = target.art_center()
	var ore := ResourceNode.new()
	ore.position = point
	battle.add_child(ore)
	check(battle._pick_enemy_at(point) == target and battle._pick_node_at(point, "resource_nodes") == ore, "enemy and ore share click")
	check(battle.command_cursor.resolve(point) == "attack", "attack cursor over ore")
	check(ForceFire.reason(battle, miner, target).is_empty(), "force fire available")
	battle._issue_order(point)
	check(miner.attack_ordered and miner.attack_target == target, "right-click locks enemy")
	var before: float = target.hp
	for step in 180:
		miner._physics_process(1.0 / 60.0)
		for shot in battle.projectiles_root.get_children():
			if shot is Projectile and not shot.is_queued_for_deletion():
				shot._physics_process(1.0 / 60.0)
		if target.hp < before: break
	check(target.hp < before, "ordinary weapon damages tank", [before, target.hp])
	ore.position = miner.position + Vector2(0, 160)
	battle._issue_order(ore.position)
	check(miner.resource_node == ore and not miner.attack_ordered, "bare ore accepts harvest order")
	print(JSON.stringify(checks))
	get_tree().quit(0 if failed == 0 else 1)
