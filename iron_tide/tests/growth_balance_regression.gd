extends "res://tests/base_recovery_regression.gd"
const Academy = preload("res://scripts/rules/academy.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	MetaProgress.current_tier = "t4"
	MetaProgress.upgrade_levels = {"atk":20,"hp":20,"income":1,"cap":1}
	MetaProgress.unit_levels = {"MTNK":{"atk":20,"def":20}}
	MetaProgress.academy.hero_builds = {"MTNK":20}
	MetaProgress.academy.hero_training = {"MTNK":{"firepower":150,"health":167}}
	var totals := MetaProgress.stat_bonuses()
	check(is_equal_approx(totals.attack_bonus,1.2375) and is_equal_approx(totals.hp_bonus,1.2875),"max tier plus paid logistics quarter only their added value")
	check(is_equal_approx(totals.income_bonus,1.08) and is_equal_approx(MetaProgress.cap_hours(),16.5),"idle income and storage retain their original rates")
	var training := MetaProgress.unit_stat_bonus("MTNK")
	check(is_equal_approx(training.attack_bonus,1.15) and is_equal_approx(training.defense_bonus,1.125),"unit firepower and armor quartered")
	check(Academy.training_percent("firepower",1)==0.5 and Academy.training_percent("health",1)==0.75,"fractional first hero level")
	for difficulty in 6:
		BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"difficulty":difficulty,"map_size":2400})
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED
		battle=screen.battle
		check(screen.hud.mode_label.text.ends_with("AI "+GameData.DIFFICULTY_NAMES[difficulty]),"visible difficulty "+str(difficulty))
		var enemy = battle.spawn_unit("MTNK","enemy",Vector2(900,900))
		var atk:float=[1.0,1.0,1.0,1.0,1.15*1.09,1.3*1.24][difficulty]
		check(is_equal_approx(enemy._base_atk,atk),"enemy attack preserved at difficulty "+str(difficulty))
		if difficulty>=4:
			var ranks: Array = [20,12] if difficulty==4 else [40,32]
			check(screen.hud.mode_label.tooltip_text.contains("%d 级" % ranks[0]) and screen.hud.mode_label.tooltip_text.contains("%d 级" % ranks[1]),"both AI ranks visible")
		if difficulty==5:
			var soldier=battle.spawn_unit("MTNK","ally",Vector2(1300,1200))
			var hp:float=soldier._base_max_hp
			check(is_equal_approx(soldier._base_atk,1.2375*1.15),"new ordinary unit receives both new bonuses once")
			battle.allied_state.get_or_add("named_heroes",{}).erase("MTNK")
			Academy.promote(MetaProgress,battle,"MTNK",soldier)
			check(is_equal_approx(soldier._base_atk,1.2375*1.15*1.75) and is_equal_approx(soldier._base_max_hp,hp*2.25),"full hero attack and life use new rates once")
			BattleRequest.combat_context.erase("hero_training_scale")
			BattleRequest.combat_context.bonuses.attack_bonus=1.95
			BattleRequest.combat_context.unit_bonus.MTNK.attack_bonus=1.6
			var old=battle.spawn_unit("MTNK","ally",Vector2(1400,1200))
			battle.allied_state.named_heroes.erase("MTNK")
			Academy.promote(MetaProgress,battle,"MTNK",old)
			check(is_equal_approx(old._base_atk,1.95*1.6*4.0),"new hero in legacy context uses original frozen bonus and training")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
