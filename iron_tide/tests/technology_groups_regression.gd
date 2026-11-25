extends "res://tests/technology_progression_regression.gd"
const Tech=preload("res://scripts/rules/production_technology.gd")
const TreeView=preload("res://scripts/ui/technology_tree.gd")

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	output=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save();GM.unlock_production_tech=false
	MetaProgress.currency.cores=10000
	var ui=TreeView.new();add_child(ui)
	check(ui.cards.size()==7 and ui.cards.has("superweapon_damage_1") and ui.cards.has("joint_ra2_production") and not ui.cards.has("structure_queue_2") and not ui.cards.has("unit_queue_5"),"only one card per numeric chain; joint production and unrelated features retained")
	check(not MetaProgress.set_technology_group_level("structure_queue",1),"cannot activate an unpurchased tier")
	for id:String in ["structure_queue", "unit_queue_1"]:
		var tiers:Array=Tech.UPGRADE_GROUPS[id]
		var caps:Array=[1,9,18,27] if id=="structure_queue" else [9,27,36,49,64,81]
		for level in tiers.size():
			var price:int=MetaProgress.technology_definition(tiers[level]).cost
			MetaProgress.currency.cores=price-1;ui.refresh()
			check(ui.cards[id].button.disabled and ui.cards[id].status.text.contains("还差 1"),id+" shortage at tier "+str(level+1))
			MetaProgress.currency.cores=10000;ui.refresh()
			check(ui.cards[id].desc.text.contains("%d 项"%caps[level]) and ui.cards[id].desc.text.contains("→ %d 项"%caps[level+1]),id+" current and next capacity "+str(level))
			ui.cards[id].button.pressed.emit()
			check(MetaProgress.technology_owned(tiers[level]) and MetaProgress.balance("cores")==10000-price,id+" button purchases exactly next tier at existing price "+str(level+1))
			check(ui.cards[id].title.text.contains("Lv.%d / %d"%[level+1,tiers.size()]),id+" title advances without creating another card")
		check(ui.cards[id].button.disabled and ui.cards[id].button.text.contains("已满级"),id+" full chain disables upgrade")
		var before:float=MetaProgress.balance("cores")
		ui.cards[id].button.pressed.emit()
		check(MetaProgress.balance("cores")==before,id+" repeated full level click cannot charge again")
	MetaProgress.save();var purchases:Array=MetaProgress.unlocked_technologies.duplicate()
	var count:int=MetaProgress.researched_count()
	MetaProgress.set_effect_enabled("tech","structure_queue_2","",false)
	MetaProgress.set_effect_enabled("tech","unit_queue_3","",false)
	var before_flags:Dictionary=MetaProgress.disabled_effects.duplicate(true)
	MetaProgress.save();MetaProgress.load_save();ui.refresh()
	check(MetaProgress.unlocked_technologies==purchases and MetaProgress.disabled_effects==before_flags,"loading legacy per-tier ownership and switches is lossless")
	check(ui.cards.structure_queue.levels.get_selected_id()==1 and ui.cards.unit_queue_1.levels.get_selected_id()==2,"group selector reflects legacy effective level without rewriting switches")
	check(MetaProgress.researched_count()==count,"grouping retains each paid research for cosmetic progress")
	var old=begin_battle(MatchRules.EXTENDED)
	check(old.battle.production_technology.structure_capacity("ally")==9 and old.battle.production_technology.unit_capacity("ally")==36,"new battle consumes legacy effective chain")
	ui.cards.structure_queue.levels.item_selected.emit(3)
	ui.cards.unit_queue_1.levels.item_selected.emit(5)
	check(MetaProgress.technology_active("structure_queue_3") and MetaProgress.technology_active("unit_queue_5"),"selectors enable all prerequisites in one saved update")
	check(old.battle.production_technology.structure_capacity("ally")==9 and old.battle.production_technology.unit_capacity("ally")==36,"changing UI level does not mutate existing battle snapshot")
	old.free()
	var latest=begin_battle(MatchRules.EXTENDED)
	check(latest.battle.production_technology.structure_capacity("ally")==27 and latest.battle.production_technology.unit_capacity("ally")==81,"new battle receives selected max levels")
	latest.free()
	var disk:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	var flags:Dictionary=MetaProgress.disabled_effects.duplicate(true)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	ui.cards.structure_queue.levels.item_selected.emit(0)
	check(MetaProgress.disabled_effects==flags and FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==disk and ui.result_label.text.contains("未保存"),"failed grouped switch rolls back every tier and retains saved bytes")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	ui.cards.structure_queue.levels.item_selected.emit(0)
	ui.cards.unit_queue_1.levels.item_selected.emit(1)
	MetaProgress.load_save();ui.refresh()
	check(ui.cards.structure_queue.levels.get_selected_id()==0 and ui.cards.unit_queue_1.levels.get_selected_id()==1 and MetaProgress.unlocked_technologies==purchases,"off and lower-level choice persist without losing purchased higher tiers")
	latest=begin_battle(MatchRules.EXTENDED)
	check(latest.battle.production_technology.structure_capacity("ally")==1 and latest.battle.production_technology.unit_capacity("ally")==27,"new match consumes off and lower-level selections")
	latest.free()
	latest=begin_battle(MatchRules.RA2)
	check(latest.battle.production_technology.structure_capacity("ally")==1 and latest.battle.production_technology.unit_capacity("ally")==9,"RA2 still excludes progression")
	latest.free()
	check(not MetaProgress.set_technology_group_level("repair_all",1) and not MetaProgress.set_technology_group_level("structure_queue",4) and not MetaProgress.set_technology_group_level("structure_queue",-1),"invalid groups and level bounds rejected")
	ui.free();await get_tree().process_frame
	var page=load("res://scenes/technology.tscn").instantiate();add_child(page)
	await frames()
	check(page.technology_tree.cards.size()==7 and page.technology_body.visible,"real technology page uses grouped cards")
	for dimensions in [Vector2i(1280,720),Vector2i(1600,900)]:
		get_window().size=dimensions;await frames()
		for id:String in page.technology_tree.cards:
			var card:Dictionary=page.technology_tree.cards[id]
			page.technology_body.ensure_control_visible(card.button);await frames()
			check(card.button.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(card.button.get_global_rect()),"real page button reachable "+id+str(dimensions))
	page.free();await get_tree().process_frame

	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
