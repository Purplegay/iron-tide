extends "res://tests/base_recovery_regression.gd"
const Academy=preload("res://scripts/rules/academy.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")

func marked(control:Node) -> bool:
	var dot=control.get_node_or_null("UpgradeDot")
	return dot!=null and dot.visible

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	MetaProgress.reset_save()
	MetaProgress.unlocked_skills.assign(["ap_smoke","ps_armor_plating"])
	MetaProgress.academy.levels={"ap_smoke":3,"ps_armor_plating":0}
	MetaProgress.currency.cores=Academy.card_upgrade_cost("ps_armor_plating",0)
	var ui=load("res://scenes/meta.tscn").instantiate();ui.initial_page="pool";add_child(ui);ui.set_process(false)
	ui.training_group=Scope.group(GameData.get_skill("ap_smoke"));ui.selected_card="ap_smoke";ui._refresh_pool()
	check(marked(ui.pool_tab) and not marked(ui.pool_body.get_node("TrainingUpgrade")),"top dot can represent another affordable card while selected card is maxed")
	check(ui.pool_tab.tooltip_text.contains("1 张") and ui.pool_tab.tooltip_text.contains("复合装甲板") and ui.pool_tab.tooltip_text.contains("战略核心"),"tab explains exact count reason and affected card")
	var cards:=MetaProgress.skill_draw_candidates()
	for card:Dictionary in cards:
		var entry=ui.pool_body.find_child("PoolCard_"+str(card.id),true,false)
		var owned:=MetaProgress.skill_unlocked(card.id)
		var rank:=Academy.card_rank(MetaProgress,card.id) if owned else 0
		check(entry!=null and entry.tooltip_text.contains(Academy.skill_description(card,rank)) and entry.tooltip_text.contains("当前 Lv." if owned else "预览 Lv.0"),"every active and passive has authoritative level effect tooltip "+str(card.id))
		var style:StyleBoxFlat=entry.get_theme_stylebox("hover")
		check(style.border_color==Color.WHITE and style.border_width_left==1 and entry.get_theme_color("font_hover_color")==Scope.rarity_color(card),"white hover border preserves rarity text "+str(card.id))
	var armor=ui.pool_body.find_child("PoolCard_ps_armor_plating",true,false)
	var smoke=ui.pool_body.find_child("PoolCard_ap_smoke",true,false)
	check(marked(armor) and not marked(smoke),"list marks affordable upgrade but not maxed skill")
	var tooltip=armor._make_custom_tooltip(armor.tooltip_text)
	var label:Label=tooltip.get_child(0)
	check(label.text==armor.tooltip_text and label.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and label.custom_minimum_size.x==400,"effect tooltip has bounded width and wraps long text")
	tooltip.free()
	await get_tree().process_frame;await get_tree().process_frame
	ui.pool_scroll.ensure_control_visible(armor)
	await get_tree().process_frame;await get_tree().process_frame
	var event:=InputEventMouseMotion.new()
	event.position=armor.get_global_rect().get_center();event.global_position=event.position
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	check(armor.is_hovered() and armor.get_draw_mode()==BaseButton.DRAW_HOVER,"real viewport pointer enters skill and activates hover style")
	var before:=MetaProgress.to_dict().duplicate(true)
	armor.pressed.emit()
	check(ui.selected_card=="ps_armor_plating" and ui.training_group==Scope.group(GameData.get_skill("ps_armor_plating")),"clicking entry navigates to its training group and selected card")
	check(ui.pool_body.get_node("TrainingDescription").text==Academy.skill_description(GameData.get_skill("ps_armor_plating"),0) and before==MetaProgress.to_dict(),"selection shows corresponding effect without spending or changing progression")
	ui.pool_body.get_node("TrainingUpgrade").pressed.emit()
	armor=ui.pool_body.find_child("PoolCard_ps_armor_plating",true,false)
	check(Academy.card_rank(MetaProgress,"ps_armor_plating")==1 and armor.tooltip_text.contains("当前 Lv.1") and armor.tooltip_text.contains(Academy.skill_description(GameData.get_skill("ps_armor_plating"),1)),"real purchase refreshes tooltip to upgraded level effect")
	check(not marked(armor) and not marked(ui.pool_tab) and ui.pool_tab.tooltip_text.contains("当前没有"),"spending exact upgrade cost clears list and tab reminders and explanation")
	var locked=ui.pool_body.find_child("PoolCard_ap_escort_water",true,false)
	locked.pressed.emit()
	check(ui.selected_card=="ap_escort_water" and not MetaProgress.skill_unlocked("ap_escort_water"),"unowned card can be inspected without unlocking it")
	ui.free();await get_tree().process_frame
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
