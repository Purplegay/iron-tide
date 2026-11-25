extends "res://tests/base_recovery_regression.gd"
const Heal = preload("res://scripts/ui/healing_indicator.gd")
const Rank = preload("res://scripts/ui/veterancy_indicator.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		battle.fog = null
		for side in ["ally", "enemy", "ai2"]:
			var unit: Unit = battle.spawn_unit("MTNK", side, Vector2(1200,1200))
			unit.order_stop()
			unit.fire_stance = "none"
			unit._physics_process(0.01)
			check(not unit.has_meta(Heal.PULSE) and not unit.has_meta(Rank.PROMOTION), prefix+side+" idle update does not create visual timers")
			check(unit.has_meta("auto_w_think") == (side == "ally" and mode == MatchRules.EXTENDED), prefix+side+" only extended player has Auto W think timer")
			unit.special.auto_w_hit_left = 0.15
			unit._physics_process(0.1)
			check(is_equal_approx(unit.special.auto_w_hit_left,0.05), prefix+side+" newly attached hit state ticks immediately")
			unit._physics_process(0.1)
			check(unit.special.auto_w_hit_left == 0.0, prefix+side+" hit state clamps at zero")
			unit.veteran_level = 1
			unit.set_meta(Heal.PULSE,0.15)
			unit.set_meta(Rank.PROMOTION,0.15)
			unit._physics_process(0.1)
			check(is_equal_approx(float(unit.get_meta(Heal.PULSE,0.0)),0.05), prefix+side+" newly attached healing timer ticks immediately")
			check(is_equal_approx(float(unit.get_meta(Rank.PROMOTION,0.0)),0.05), prefix+side+" newly attached promotion timer ticks immediately")
			unit._physics_process(0.1)
			check(not unit.has_meta(Heal.PULSE) and not unit.has_meta(Rank.PROMOTION), prefix+side+" both visual timers expire")
			for state in ["hidden","cargo","dead"]:
				unit.set_meta(Heal.PULSE,1.0)
				unit.set_meta(Rank.PROMOTION,1.0)
				if state == "hidden": unit.hide()
				elif state == "cargo": unit.embarked_in = unit
				else: unit._dead = true
				unit._physics_process(0.01)
				check(not unit.has_meta(Heal.PULSE) and not unit.has_meta(Rank.PROMOTION), prefix+side+" "+state+" clears visuals at original update point")
				unit.show(); unit.embarked_in = null; unit._dead = false
			for initial in [-0.1,0.0,0.05,0.2]:
				for key in ["blackout","reveal","chrono_left"]: unit.special[key]=initial
				AlliedAbilities.tick_actor(unit,0.1)
				for key in ["blackout","reveal","chrono_left"]:
					check(unit.special[key]==maxf(0.0,initial-0.1),prefix+side+" status timer boundary "+key+"/"+str(initial))
			battle.units.erase(unit)
			unit.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)
