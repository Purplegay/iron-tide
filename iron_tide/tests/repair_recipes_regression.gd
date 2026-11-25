extends Node
func _ready():
	await get_tree().process_frame
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or OS.get_environment("IRON_TIDE_RECIPE_TEST") != OS.get_user_data_dir():
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	MetaProgress.grant("cores",160)
	var tree = load("res://scripts/ui/technology_tree.gd").new()
	add_child(tree)
	for id in ["repair_all","repair_all"]: tree.cards[id].button.pressed.emit()
	assert(MetaProgress.technology_active("repair_auto"))
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"starting_funds":50000})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var w = screen.battle
	var hud = screen.hud
	assert(w.can_repair_all())
	var a = w._place_building("GAPILE","ally",Vector2(1500,1400),true)
	var b = w._place_building("GAPOWR","ally",Vector2(1700,1400),true)
	a._buildup_play = -1
	b._buildup_play = -1
	a.hp -= 35
	b.hp -= 40
	assert(w.apply_building_action("repair",b))
	w.repair_all_buildings()
	assert(a.repairing and w.allied_state.area_repair == 1)
	w.repair_all_buildings()
	assert(w.allied_state.area_repair == 2)
	w.repair_all_buildings()
	assert(not a.repairing and b.repairing)
	a.hp = a.max_hp
	b.hp = b.max_hp
	b.set_repairing(false)
	w.repair_all_buildings()
	assert(w.allied_state.area_repair == 2)
	a.hp -= 35
	w._tick_area_repair()
	assert(a.repairing and a.special.area_repair)
	w.select_building(a)
	hud.select_prod_tab("infantry")
	hud._factories.remember(a,"infantry")
	hud._refresh_production()
	assert(not hud._recipe_button.visible)
	tree.cards["production_recipes"].button.pressed.emit()
	assert(hud._recipe_button.visible)
	hud._recipe_button.pressed.emit()
	var panel = hud.get_child(-1)
	panel.title_edit.text = "巡逻组"
	panel._append("E1")
	assert(not panel.exclusive)
	var first_yard = w._place_building("GAWEAP","ally",Vector2(2400,1400),true)
	var second_yard = w._place_building("GAWEAP","ally",Vector2(2600,1400),true)
	first_yard._buildup_play = -1
	second_yard._buildup_play = -1
	hud.deck_tabs_btns.vehicle.pressed.emit()
	assert(panel.category == "vehicle" and hud.prod_tab == "vehicle" and panel.draft.is_empty())
	pick_factory(panel, first_yard)
	panel.title_edit.text = "一厂坦克"
	panel._append("MTNK")
	pick_factory(panel, second_yard)
	assert(panel.draft.is_empty() and hud._factories.current() == second_yard)
	panel._append("MTNK")
	panel._order()
	assert(second_yard.production == ["MTNK"] and first_yard.production.is_empty())
	pick_factory(panel, first_yard)
	assert(panel.title_edit.text == "一厂坦克" and panel.draft == ["MTNK"])
	hud.deck_tabs_btns.infantry.pressed.emit()
	assert(panel.factory == a and panel.title_edit.text == "巡逻组" and panel.draft == ["E1"])
	panel._append("E1")
	panel._save()
	var money = w.funds
	panel._order()
	assert(a.production == ["E1","E1"] and w.funds == money)
	assert(a.order_recipe(["MTNK"]).contains("已排入 0 项") and a.production.size() == 2)
	assert(a.order_recipe(["MTNK","E1"]).contains("跳过 1 项") and a.production == ["E1","E1","E1"])
	assert(a.enqueue_many("E1",5)==5)
	panel._order()
	assert(panel.message.text.contains("跳过 1 项") and a.production.size()==9)
	panel.free()
	var second = w._place_building("GAPILE","ally",Vector2(1900,1400),true)
	var other = w._place_building("NAHAND","ally",Vector2(2100,1400),true)
	panel = open_recipe(hud, second)
	assert(panel.title_edit.text == "巡逻组")
	panel._on_choice(0)
	panel.title_edit.text = "单兵"
	panel._append("E1")
	panel._save()
	panel.free()
	panel = open_recipe(hud, other)
	assert(panel.choices.item_count == 1 and panel.title_edit.text == "")
	panel.title_edit.text = "巡逻组"
	panel._append("E2")
	panel._save()
	panel.free()
	panel = open_recipe(hud, a)
	assert(panel.title_edit.text == "巡逻组" and panel.draft == ["E1","E1"])
	panel.free()
	panel = open_recipe(hud, second)
	assert(panel.title_edit.text == "单兵")
	MetaProgress.recipe_defaults.clear()
	MetaProgress.production_recipes.clear()
	MetaProgress.load_save()
	assert(MetaProgress.production_recipes[panel.bucket]["巡逻组"] == ["E1","E1"])
	assert(MetaProgress.recipe_defaults[panel.default_key] == "单兵")
	panel.queue_free()
	var codec = load("res://scripts/save/battle_snapshot.gd").new()
	var snap = codec.capture(w)
	assert(codec.error.is_empty())
	var codec2 = load("res://scripts/save/battle_snapshot.gd").new()
	codec2.restore(w,bytes_to_var(var_to_bytes(snap)))
	assert(w.allied_state.area_repair == 2)
	var restored = false
	for obj in w.buildings:
		if obj.production.size()==9:
			assert(obj.special.recipe_selection.infantry == "巡逻组")
			restored = obj.repairing and obj.special.get("area_repair",false)
	assert(restored)
	hud._toggle_pause()
	w.repair_all_buildings()
	assert(w.allied_state.get("area_repair",0)==0)
	for obj in w.buildings:
		if obj.production.size()==9:
			w.repair_all_buildings()
			assert(obj.repairing and w.allied_state.area_repair==1)
			obj.hp = obj.max_hp
			obj._process_building_repair(1.0)
			w._tick_area_repair()
			assert(w.allied_state.get("area_repair",0)==0)
			w.production_technology.unlocked.ally.erase("repair_auto")
			obj.hp -= 40
			w.repair_all_buildings()
			assert(obj.repairing and w.allied_state.get("area_repair",0)==0)
	BattleRequest.configure_skirmish(MatchRules.RA2,{})
	hud._refresh_production()
	assert(not w.can_repair_all() and not hud._recipe_button.visible)
	print("TECH_OPS_PASS")
	get_tree().quit()

func pick_factory(panel, factory):
	panel.hud._factories.buttons[factory.get_instance_id()].button.pressed.emit()
	assert(panel.factory == factory)

func open_recipe(hud, factory):
	hud._factories.remember(factory, "infantry")
	hud._recipe_button.pressed.emit()
	return hud.get_child(-1)
