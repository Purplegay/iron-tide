extends Node
## A separate engine process: no runtime Object IDs or autoload state from the writer.
var failed := 0
var checks: Array = []

func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "name": label})
	if not ok:
		failed += 1
		print("FAIL ", label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	# Keep this verifier outside current_scene so it survives the real menu load route.
	get_tree().current_scene = null
	for slot in ["slot1", "slot2", "slot3"]:
		var result: Dictionary = BattleSaves.load_into_scene(slot)
		check(result.ok, slot + " cold read and schema validation")
		if not result.ok: continue
		await get_tree().process_frame
		await get_tree().process_frame
		var screen = get_tree().current_scene
		var world = screen.battle
		check(world.paused and get_tree().paused and not world.match_id.is_empty(), slot + " cold scene starts paused with match identity")
		check(screen.hud._load_pause_hint.is_visible_in_tree(), slot + " cold load shows battlefield resume hint")
		if slot != "slot3":
			check(world.funds == 4321.25 and world.enemy_funds == 876.5 and world.projectiles_root.get_child_count() == 1, slot + " cold economy and projectile restored")
			check(world.control_groups["1"].size() == 2 and world.control_groups["1"][0].hp == 123.0, slot + " cold cross-object references restored")
			if slot == "slot2":
				var before := MetaProgress.currency.duplicate(true)
				var award: Dictionary = MetaProgress.apply_battle_result({"match_id": world.match_id, "win": true})
				check(award.get("already_settled", false) and before == MetaProgress.currency, "cold process cannot re-award a completed saved match")
		else:
			check(world.wave_index == 1 and world.wave_timer == 9.5, "cold campaign wave restored")
			var match_id: String = world.match_id
			screen.hud._open_saves()
			var panel = screen.hud.save_panel
			panel.request_action("suspend", "quick")
			panel.confirmation.hide()
			panel._confirm()
			await get_tree().process_frame
			await get_tree().process_frame
			check(get_tree().current_scene.get_script().resource_path == "res://scripts/screens/hud_main_menu.gd" and not get_tree().paused, "save and return reaches usable main menu")
			check(not MetaProgress.settled_matches.has(match_id), "suspending does not settle or award the unfinished match")
			check(BattleSaves.load_into_scene("quick").ok, "suspended quick save loads through actual scene route")
			await get_tree().process_frame
			await get_tree().process_frame
			screen = get_tree().current_scene
			check(screen.battle.match_id == match_id and screen.battle.wave_timer == 9.5 and get_tree().paused, "suspended match resumes with same identity and progress")
			check(screen.hud._load_pause_hint.is_visible_in_tree(), "quick save shows battlefield resume hint")
		get_tree().paused = false
		get_tree().current_scene = null
		screen.free()
		await get_tree().process_frame
	var path := OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("cold-result.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	file.close()
	print("COLD_SAVE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
