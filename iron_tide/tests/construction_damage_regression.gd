extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	GM.god_mode = false
	GM.one_shot_kill = false
	GM.infinite_funds = false
	GM.no_build_time = false
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		for owner in ["ally", "enemy"]:
			exercise_construction(owner)
			exercise_buildup(owner)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	print("CONSTRUCTION DAMAGE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func fixture(owner: String):
	var site = battle._place_building("GAPOWR", owner, Vector2(1500,1500), true)
	site._buildup_play = -1.0
	site.under_construction = true
	site.build_total = 10.0
	site.build_elapsed = 0.0
	site.build_cost = 0.0
	site.hp = site.max_hp * 0.15
	return site

func exercise_construction(owner: String) -> void:
	var site = fixture(owner)
	var shooter = battle.spawn_unit("MTNK", "enemy" if owner == "ally" else "ally", Vector2(1300,1500))
	shooter.attack_ordered = true
	if battle.fog != null: battle.fog.rebuild()
	check(shooter._weapon_target_valid(site), prefix + owner + ": unfinished building is a valid weapon target")
	var before: float = site.hp
	site.receive_hit(20.0)
	var lost: float = before - site.hp
	check(lost > 0.0, prefix + owner + ": unfinished building takes damage")
	var damaged: float = site.hp
	site._process(0.0)
	check(is_equal_approx(site.hp, damaged), prefix + owner + ": zero construction progress cannot restore damage")
	site._process(1.0)
	var expected: float = site.max_hp * (0.15 + 0.85 * site.build_elapsed / site.build_total) - lost
	check(is_equal_approx(site.hp, expected), prefix + owner + ": paid progress adds only new structural health")
	site.build_cost = 1000.0
	if owner == "ally": battle.funds = 0.0
	else: battle.enemy_funds = 0.0
	var elapsed: float = site.build_elapsed
	damaged = site.hp
	site._process(1.0)
	check(site.build_elapsed == elapsed and is_equal_approx(site.hp, damaged), prefix + owner + ": funds stall cannot heal construction damage")
	site.build_cost = 0.0
	site._process(100.0)
	check(not site.under_construction and is_equal_approx(site.hp, site.max_hp - lost), prefix + owner + ": completion retains damage instead of refilling health")
	var doomed = fixture(owner)
	doomed.receive_hit(999999.0)
	check(doomed.is_dead() and doomed.hp == 0.0, prefix + owner + ": lethal hit destroys unfinished building immediately")
	doomed._process(100.0)
	check(doomed.is_dead() and doomed.hp == 0.0 and doomed.under_construction, prefix + owner + ": dead construction cannot progress or resurrect")
	var intact = fixture(owner)
	intact._process(100.0)
	check(not intact.under_construction and is_equal_approx(intact.hp,intact.max_hp), prefix + owner + ": undamaged construction still completes at full health")

func exercise_buildup(owner: String) -> void:
	var site = battle._place_building("GAPOWR", owner, Vector2(1800,1500), true)
	site._buildup_play = 0.0
	site.receive_hit(20.0)
	var damaged: float = site.hp
	check(damaged < site.max_hp, prefix + owner + ": placement animation takes damage")
	site._process(GameData.ra2_buildup_seconds() + 1.0)
	check(is_equal_approx(site.hp, damaged), prefix + owner + ": finishing placement animation retains damage")
	site._buildup_play = 0.0
	site.receive_hit(999999.0)
	check(site.is_dead() and site.hp == 0.0, prefix + owner + ": placement animation can be destroyed")
