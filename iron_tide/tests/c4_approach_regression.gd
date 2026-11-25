extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GM.god_mode = false
	GM.one_shot_kill = false
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		if battle.fog != null:
			battle.fog.free()
			battle.fog = null
		for bid in ["GAPOWR", "GAWEAP", "GAREFN", "GADEPT", "GAAIRC", "GACNST"]:
			var target = battle._place_building(bid, "enemy", Vector2(2107, 2109), true)
			target.process_mode = Node.PROCESS_MODE_ALWAYS
			target.set_process(false)
			target.set_physics_process(false)
			target._buildup_play = -1.0
			for id in ["GHOST", "TANY"]:
				for direction in 8:
					var unit = battle.spawn_unit(id, "ally", target.position + Vector2.RIGHT.rotated(direction * TAU / 8.0) * 400.0)
					unit.process_mode = Node.PROCESS_MODE_ALWAYS
					unit.set_process(false)
					unit.set_physics_process(false)
					unit.order_stop()
					battle.select_unit(unit, false)
					battle.force_attack(target)
					await get_tree().physics_frame
					for tick in 1800:
						unit._physics_process(1.0 / 60.0)
						if target.special.has("c4_left"): break
					var planted: bool = target.special.has("c4_left")
					check(planted, prefix + id + " " + bid + " approach " + str(direction) + " enters and plants", {
						"position":str(unit.position), "destination":str(AlliedAbilities.approach(unit, target)),
						"stage":unit.special.get("c4_stage", "none"), "path_index":unit._path_i,
						"last_waypoint":str(unit._path_pts[-1]) if not unit._path_pts.is_empty() else "none"})
					if planted:
						check(Geometry2D.is_point_in_polygon(unit.position - target.position, target.footprint_poly()), prefix + id + " charge requires actual foundation entry")
						for tick in 600:
							unit._physics_process(1.0 / 60.0)
							if not unit.special.has("action"): break
						check(not Geometry2D.is_point_in_polygon(unit.position - target.position, target.footprint_poly()) and not unit.special.has("action"), prefix + id + " exits after planting")
						check(unit.get_collision_exceptions().is_empty(), prefix + id + " restores collisions after entry and exit")
					unit.process_mode = Node.PROCESS_MODE_ALWAYS
					unit.set_process(false)
					unit.set_physics_process(false)
					unit.order_stop()
					battle.clear_selection()
					battle.units.erase(unit)
					unit.free()
					target.special.erase("c4_left")
					target.special.erase("c4_owner")
					preload("res://scripts/units/temporal_visual.gd").sync(target)
			battle.buildings.erase(target)
			target.free()
			battle._refresh_pathing()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	print("C4_APPROACH checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
