extends Node

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CampaignPreferenceTest"):
		get_tree().quit(2)
		return
	var menu = preload("res://scenes/campaign_command.tscn").instantiate()
	add_child(menu)
	var writing := "--write" in OS.get_cmdline_user_args()
	menu.choose_faction("soviet" if writing else "allied")
	if writing:
		assert(not menu.carry and menu.difficulty == 1)
		for btn in menu.page.find_children("*","Button",true,false):
			if btn.text == "带入我的养成":
				btn.pressed.emit()
				break
	var level: OptionButton = menu.page.find_children("*","OptionButton",true,false)[0]
	if writing:
		level.select(2)
		level.item_selected.emit(2)
	assert(menu.carry and menu.difficulty == 2 and level.selected == 2)
	print("CAMPAIGN_PREF_PASS ",writing)
	get_tree().quit()
