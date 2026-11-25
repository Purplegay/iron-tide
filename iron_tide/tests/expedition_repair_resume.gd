extends Node

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	assert(Expedition.load_run())
	print("REPAIR_FIXTURE stage=", Expedition.state.stage, " phase=", Expedition.state.phase, " checkpoint=", Expedition.state.has("checkpoint"))
	assert("repair_auto" not in Expedition.state.frozen.technologies)
	assert(MetaProgress.technology_active("repair_auto"))
	if Expedition.state.phase == "battle":
		assert(Expedition.prepare_battle())
	else:
		assert(Expedition.launch(0))
	var screen = preload("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world = screen.battle
	var hud = screen.hud
	var button: Button = hud.building_action_buttons.repair_all
	await get_tree().process_frame
	if world.paused: hud._toggle_pause()
	assert(button.text == "维修待命" and not button.disabled)
	for i in 2:
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = button.get_global_rect().get_center()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			get_viewport().push_input(click, true)
		if button.text == "自动抢修": break
	assert(button.text == "自动抢修" and world.allied_state.area_repair == 2)
	var building = world._place_building("GAPOWR", "ally", Vector2(1700,1400), true)
	building._buildup_play = -1
	building.hp -= 40
	world._tick_area_repair()
	assert(building.repairing)
	print("EXPEDITION_REPAIR_RESUME_PASS")
	get_tree().quit()
