extends "res://tests/base_recovery_regression.gd"

const Warmup = preload("res://scripts/world/combat_media_warmup.gd")
const Cloak = preload("res://scripts/units/ra3_cloak_visual.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	start(MatchRules.EXTENDED)
	var unit = battle.spawn_unit("SREF", "ally", Vector2(1200,1200))
	var hp_before: float = unit.hp
	var funds_before: float = battle.funds
	seed(1849)
	var expected_random := randi()
	seed(1849)
	var warmup = Warmup.install(battle)
	check(randi() == expected_random, "warming media does not consume gameplay RNG")
	check(unit.hp == hp_before and battle.funds == funds_before, "warming media does not change health or funds")
	check(warmup.jobs.is_empty() and warmup.held.size() > 0, "initial media including dependent impact audio drains before combat")
	check(warmup.weapons.has(unit._active_weapon().ra2_weapon_id), "current prism weapon is warmed")
	var held_before: int = warmup.held.size()
	warmup.scan()
	check(warmup.jobs.is_empty() and warmup.held.size() == held_before, "same roster is deduplicated")
	var grenade = battle.spawn_unit("GGI", "ally", Vector2(1240,1200))
	warmup.scan()
	check(warmup.types.has("GGI"), "newly produced type is discovered")
	for i in 180:
		warmup._process(0.05)
		if warmup.jobs.is_empty() and warmup.loading.is_empty(): break
		await get_tree().process_frame
	check(warmup.jobs.is_empty() and warmup.loading.is_empty(), "background request completes without blocking future jobs")
	check(not get_tree().has_group(Ra3Mirage.SOURCE_GROUP), "test roster has no broadcasting field")
	Cloak.tick(grenade,0.1)
	check(not grenade.has_meta(Cloak.STATE) and Cloak.opacity(grenade) == 1.0, "ordinary armies allocate no cloak cache")
	grenade.set_meta(Cloak.STATE,{"covered":true,"phase":1.0,"check_left":0.2})
	Cloak.tick(grenade,0.1)
	check(not grenade.has_meta(Cloak.STATE) and Cloak.opacity(grenade) == 1.0, "last field removal clears stale transparency")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)
