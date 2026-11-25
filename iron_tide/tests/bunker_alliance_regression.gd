extends "res://tests/base_recovery_regression.gd"
const Garrison = preload("res://scripts/units/civilian_orders.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for indexed in [false, true]:
			for setup in [["NABNKR", "ally", "ai2", "enemy"], ["NABNKR", "ai2", "ally", "enemy"], ["NABNKR", "enemy", "ai3", "ally"], ["CAHSE01", "ally", "ai2", "enemy"]]:
				start(mode)
				BattleRequest.house_teams = {"ally":1, "ai2":1, "enemy":2, "ai3":2}
				for b in battle.buildings: b.free()
				battle.buildings.clear()
				battle._refresh_pathing()
				prefix = mode + "/" + str(indexed) + "/" + setup[0] + "/" + setup[1] + ": "
				exercise(setup, indexed)
				await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	print("BUNKER ALLIANCE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func make_unit(owner: String, point: Vector2):
	var u = battle.spawn_unit("E2", "ally", point)
	if owner != "ally": AlliedAbilities.change_side(u, owner)
	return u

func shoot(crew) -> void:
	crew._cd_timer = 0.0
	crew._think_timer = 0.0
	Garrison.tick(crew, 0.1)

func exercise(setup: Array, indexed: bool) -> void:
	var point := Vector2(1200,1200)
	var bunker = preload("res://scripts/world/civilian_sites.gd").create(battle, setup[0], point) if setup[0] == "CAHSE01" else battle._place_building(setup[0], setup[1], point, true)
	bunker._buildup_play = -1.0
	var crew = make_unit(setup[1], point)
	crew.set_fire_stance("free")
	Garrison.enter(crew, bunker)
	check(crew.embarked_in == bunker, prefix + "real garrison entry")
	var friend = make_unit(setup[2], point + Vector2(100,0))
	var foe = make_unit(setup[3], point + Vector2(200,0))
	var same = make_unit(setup[1], point + Vector2(0,100))
	var neutral = make_unit("neutral", point + Vector2(0,-100))
	var post = battle._place_building("NAPOWR", setup[2], point + Vector2(0,200), true)
	post._buildup_play = -1.0
	if indexed:
		while battle.units.size() < 96: make_unit(setup[1], Vector2(100,100))
	check((battle.units.size() >= 96) == indexed, prefix + "intended acquisition branch")
	check(not Garrison.visible_enemy(bunker, friend), prefix + "allied house rejected")
	check(not Garrison.visible_enemy(bunker, same) and not Garrison.visible_enemy(bunker, neutral), prefix + "same owner and neutral rejected")
	check(Garrison.visible_enemy(bunker, foe), prefix + "hostile house accepted")
	check(not Garrison.order_block_reason(bunker,friend).is_empty() and not Garrison.order_block_reason(bunker,post).is_empty(), prefix + "ordinary manual orders reject allied unit and building")
	shoot(crew)
	check(friend.hp == friend.max_hp and same.hp == same.max_hp and neutral.hp == neutral.max_hp, prefix + "automatic fire leaves friendly health intact")
	check(crew.attack_target == foe and foe.hp < foe.max_hp, prefix + "automatic fire damages farther enemy")
	bunker.attack_target = post
	shoot(crew)
	check(bunker.attack_target == null and post.hp == post.max_hp, prefix + "stale allied building target cleared without damage")
	bunker.attack_target = foe
	AlliedAbilities.change_side(foe, setup[2])
	var health: float = foe.hp
	shoot(crew)
	check(bunker.attack_target == null and foe.hp == health and friend.hp == friend.max_hp, prefix + "captured target ceases fire immediately")
	# Team changes must be read live, without cached allegiance.
	BattleRequest.house_teams[setup[2]] = 3
	shoot(crew)
	check(friend.hp < friend.max_hp, prefix + "formerly allied house can become hostile")
