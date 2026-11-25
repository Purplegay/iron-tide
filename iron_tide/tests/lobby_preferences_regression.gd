extends Node

const Preferences = preload("res://scripts/ui/lobby_preferences.gd")
const EXPECTED := {"rules_mode": "ra2", "opening": "mcv", "victory_condition": "annihilation",
	"map_size": 2400, "map_layout": "strait", "starting_funds": 50000, "enemy_base": "soviet", "difficulty": 4,
	"country": "英国", "enemy_country": "伊拉克", "fog_of_war": false}
var checks: Array = []
var failed := 0
var output := ""

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok:
		failed += 1
		print("FAIL ", label)

func open_lobby():
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	get_tree().root.add_child(lobby)
	return lobby

func choose(control: OptionButton, index: int) -> void:
	control.select(index)
	control.item_selected.emit(index)

func choose_color(lobby, id: String) -> void:
	var picker: OptionButton = lobby._color_opt
	for i in picker.item_count:
		if picker.get_item_metadata(i) == id:
			choose(picker, i)
			return
	check(false, "missing palette entry " + id)

func check_choice(lobby, country: String, color: String, context: String) -> void:
	var picker: OptionButton = lobby._color_opt
	check(lobby._country_opt.get_item_text(lobby._country_opt.selected) == country and picker.get_item_metadata(picker.selected) == color and HouseColor.player_id == color, context)

func _ready() -> void:
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("CodexIronTideValidation/"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	BattleRequest.reset()
	if "--lobby-cold" in OS.get_cmdline_user_args():
		var cold = open_lobby()
		check(cold._selection_preferences() == EXPECTED, "cold process restores all UI preferences")
		check_choice(cold, "英国", "purple", "cold map restores last country and its colour")
		choose(cold._country_opt, 0)
		check_choice(cold, "美国", "red", "second country survives cold start")
		choose(cold._country_opt, 4)
		choose(cold._layout_opt, 1)
		check_choice(cold, "英国", "green", "second map survives cold start")
		choose(cold._layout_opt, 2)
		choose(cold._map_opt, 2)
		check_choice(cold, "苏俄", "orange", "same layout at another size restores its country")
		choose(cold._map_opt, 0)
		check_choice(cold, "英国", "purple", "return to original map before launch")
		check(BattleRequest.skirmish_config.is_empty() and BattleRequest.rules_mode == MatchRules.EXTENDED, "cold restore does not configure an active match")
		FileAccess.open(output.path_join("cold-result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed}))
		get_tree().quit(failed)
		return
	check(not FileAccess.file_exists(Preferences.PATH), "fresh isolated user profile")
	var lobby = open_lobby()
	check(lobby._selection_preferences() == Preferences.DEFAULTS, "first-run defaults preserved")
	check(Preferences.DEFAULTS.starting_funds == 10000 and GameData.skirmish_default_config().starting_funds == 10000, "lobby and mission default to original RA2 10000 credits")
	check(lobby._funds_opt.get_item_text(lobby._funds_opt.selected) == "10000", "fresh lobby selects 10000 credits")
	check(not FileAccess.file_exists(Preferences.PATH), "opening lobby does not write preferences")
	for legacy in ["allied", "soviet", "swarm"]:
		var expected_country: String = {"allied":"美国", "soviet":"苏俄", "swarm":"虫群巢穴"}[legacy]
		var old := ConfigFile.new()
		old.set_value("lobby", "enemy_base", legacy)
		old.save(Preferences.PATH)
		check(Preferences.read().enemy_country == expected_country, "legacy opponent migrates " + legacy)
	check(Preferences.normalize({"rules_mode":"ra2", "enemy_base":"swarm"}).enemy_country == "美国", "legacy RA2 swarm falls back to USA")
	check(Preferences.normalize({"enemy_country":"伊拉克", "enemy_base":"allied"}).enemy_base == "soviet", "country overrides stale cached faction")
	# Every available field saves immediately, even without starting a battle.
	for key in lobby._preference_controls():
		var control: OptionButton = lobby._preference_controls()[key]
		for index in control.item_count:
			if control.is_item_disabled(index): continue
			choose(control, index)
			check(Preferences.read() == lobby._selection_preferences(), "immediate persistence: %s/%d" % [key, index])
	for enabled in [false, true]:
		lobby._fog_check.button_pressed = enabled
		check(Preferences.read().fog_of_war == enabled, "fog toggle persists " + str(enabled))
	choose(lobby._mode_opt, 0)
	choose(lobby._funds_opt, 0)
	choose(lobby._opening_opt, 1)
	check(lobby._funds_opt.selected == 1 and Preferences.read().starting_funds == 8000, "MCV raises low funds before saving")
	choose(lobby._mode_opt, 1)
	check(lobby._opening_opt.selected == 0 and Preferences.read().opening == "prebuilt", "extension clears unsupported MCV before saving")
	choose(lobby._enemy_opt, Preferences.OPTIONS.enemy_country.find("虫群巢穴"))
	choose(lobby._mode_opt, 0)
	check(lobby._enemy_opt.selected == 0 and Preferences.read().enemy_base == "allied", "RA2 clears unsupported enemy before saving")
	# Restore never mutates a loaded match or permanent technology.
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"marker": 71})
	var before_match := BattleRequest.skirmish_config.duplicate(true)
	var before_tech := MetaProgress.unlocked_technologies.duplicate()
	var selected: Dictionary = lobby._selection_preferences()
	lobby.free()
	lobby = open_lobby()
	check(lobby._selection_preferences() == selected, "returning to lobby restores selections")
	check(BattleRequest.skirmish_config == before_match and MetaProgress.unlocked_technologies == before_tech, "restore leaves match snapshot and progression untouched")
	# Invalid or removed values fall back per-field; valid old fields survive.
	var config := ConfigFile.new()
	config.set_value("lobby", "country", "法国")
	config.set_value("lobby", "map_size", 9999)
	config.set_value("lobby", "difficulty", "2")
	config.set_value("lobby", "fog_of_war", 0)
	config.set_value("lobby", "unknown_future_key", "ignored")
	config.save(Preferences.PATH)
	lobby.free()
	lobby = open_lobby()
	var fallback := Preferences.DEFAULTS.duplicate()
	fallback.country = "法国"
	check(lobby._selection_preferences() == fallback, "missing, invalid and wrong-type fields safely fall back; valid fields survive")
	var legacy_color := HouseColor.player_id
	choose(lobby._layout_opt, 1)
	choose(lobby._country_opt, 2)
	choose_color(lobby, "orange")
	choose(lobby._layout_opt, 0)
	check_choice(lobby, "法国", legacy_color, "old profile keeps last map, country and global colour on first switch")
	# A failed save leaves the prior file intact and warns in the real UI.
	var original := FileAccess.get_file_as_bytes(Preferences.PATH)
	check(DirAccess.make_dir_absolute(Preferences.PATH + ".tmp") == OK, "create isolated write-failure fixture")
	choose(lobby._map_opt, 0)
	check(lobby._preferences_status.visible, "save failure is visible to player")
	check(FileAccess.get_file_as_bytes(Preferences.PATH) == original, "save failure preserves previous file")
	DirAccess.remove_absolute(Preferences.PATH + ".tmp")
	choose(lobby._map_opt, 2)
	check(not lobby._preferences_status.visible and Preferences.read().map_size == 4000, "next selection retries and clears warning")
	# Leave a complete non-default setup, then restart the actual executable.
	choose(lobby._mode_opt, 0)
	choose(lobby._opening_opt, 1)
	choose(lobby._victory_opt, 1)
	choose(lobby._map_opt, 0)
	choose(lobby._funds_opt, Preferences.OPTIONS.starting_funds.find(50000))
	choose(lobby._layout_opt, 2)
	choose(lobby._diff_opt, 4)
	choose(lobby._enemy_opt, Preferences.OPTIONS.enemy_country.find("伊拉克"))
	choose(lobby._country_opt, 4)
	lobby._fog_check.button_pressed = false
	choose_color(lobby, "purple")
	choose(lobby._country_opt, 0)
	choose_color(lobby, "red")
	choose(lobby._country_opt, 4)
	check_choice(lobby, "英国", "purple", "switching countries restores their separate colours")
	choose(lobby._layout_opt, 1)
	choose(lobby._country_opt, 4)
	choose_color(lobby, "green")
	choose(lobby._layout_opt, 2)
	check_choice(lobby, "英国", "purple", "identical country on another layout has its own colour")
	choose(lobby._map_opt, 2)
	choose(lobby._country_opt, 5)
	choose_color(lobby, "orange")
	choose(lobby._map_opt, 0)
	check_choice(lobby, "英国", "purple", "map size restores independent country and palette ID")
	check(Preferences.read() == EXPECTED, "complete non-default setup saved")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("lobby-remembered.png"))
	lobby.free()
	var child_output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/lobby_preferences_regression.tscn", "--", "--lobby-cold"], child_output, true)
	check(code == 0, "cold executable restores settings")
	var cold_result = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("cold-result.json")))
	check(cold_result != null and cold_result.failed == 0, "cold process completed assertions")
	# Use the actual start handler and inspect the consumed request.
	lobby = open_lobby()
	get_tree().current_scene = lobby
	lobby._start_skirmish()
	check(BattleRequest.rules_mode == EXPECTED.rules_mode, "start consumes remembered mode")
	for key in EXPECTED:
		if key != "rules_mode":
			check(BattleRequest.skirmish_config.get(key) == EXPECTED[key], "start consumes remembered " + key)
	await get_tree().scene_changed
	var world = get_tree().current_scene.battle
	check(world._countries.enemy == "Arabs" and world.skirmish_enemy_base == "soviet" and world.skirmish_ai._unit_pool.has("DESO") and not world.skirmish_ai._unit_pool.has("TTNK"), "actual remembered Iraqi opponent spawns with its own AI roster")
	var allies: Array = world.units.filter(func(u): return u.side == "ally")
	check(world.map_layout() == "strait" and not allies.is_empty() and allies.all(func(u): return u._col == Color(HouseColor.hex_of("purple"))), "actual units spawn in saved colour on saved map")
	get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	await exercise_starting_funds()
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed, "cold_output": child_output}, "  "))
	get_tree().quit(failed)

func exercise_starting_funds() -> void:
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for amount in [10000, 20000, 30000, 50000]:
			BattleRequest.configure_skirmish(mode, {"map_size":2400, "starting_funds":amount, "difficulty":0})
			var scene = load("res://scenes/battle.tscn").instantiate()
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(scene)
			check(scene.battle.mission.starting_funds == amount and is_equal_approx(scene.battle.funds, amount), mode + ": actual starting balance " + str(amount))
			check(is_equal_approx(scene.battle.enemy_funds, amount), mode + ": easy opponent keeps same starting balance " + str(amount))
			scene.free()
			await get_tree().process_frame
		BattleRequest.configure_skirmish(mode, {"opening":"mcv"})
		check(GameData.make_skirmish_mission(BattleRequest.skirmish_config).starting_funds == 10000, mode + ": omitted funds use 10000 including MCV start")
