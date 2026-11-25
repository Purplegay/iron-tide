extends Node

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	var phase := OS.get_environment("IRON_TIDE_REPAIR_PHASE")
	if phase == "enable":
		MetaProgress.reset_save()
		MetaProgress.grant("cores", 160)
		var research = preload("res://scripts/ui/technology_tree.gd").new()
		add_child(research)
		for i in 2: research.cards.repair_all.button.pressed.emit()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"starting_funds":50000})
	var screen = preload("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world = screen.battle
	assert(world.production_technology.is_unlocked("repair_auto", "ally"))
	var mode := int(world.allied_state.get("area_repair", 0))
	assert(mode == (2 if phase == "disable" else 0))
	if phase in ["enable", "disable"]:
		world.repair_all_buildings()
		assert(int(world.allied_state.get("area_repair", 0)) == (2 if phase == "enable" else 0))
		assert(DisplayPreferences.save_error == OK)
	print("REPAIR_PREFERENCE_PASS ", phase)
	get_tree().quit()
