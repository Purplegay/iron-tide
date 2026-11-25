extends "res://tests/base_recovery_regression.gd"
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")
const Academy=preload("res://scripts/rules/academy.gd")

func marked(control:Node) -> bool:
	if control==null:return false
	var dot=control.get_node_or_null("UpgradeDot")
	return dot!=null and dot.visible

func funds(cores:int) -> void:
	MetaProgress.currency.cores=cores;Events.meta_changed.emit()

func fill_equipment() -> void:
	# Keep upgrade-only cases independent from empty-slot alerts.
	var auto=preload("res://scripts/rules/auto_skill_loadout.gd")
	MetaProgress.unit_loadouts.merge(auto.plan(MetaProgress,auto.roster()).changes,true)
	for id:String in Academy.HEROES:
		var row:=preload("res://scripts/rules/hero_loadouts.gd").effective(MetaProgress,id)
		for card:Dictionary in MetaProgress.owned_skills():
			if not UnitSkillLayout.compatible(id,card.id,true):continue
			if card.type=="active" and row.active[0]=="" and UnitSkillLayout.equippable(id,card.id,true):row.active=[card.id]
			elif card.type=="passive" and row.passive=="":row.passive=card.id
		MetaProgress.academy.hero_loadouts[id]=row

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	MetaProgress.reset_save();MetaProgress.unlocked_skills.clear()
	MetaProgress.academy.hero_builds={"ORCA":0}
	MetaProgress.currency.cores=1000
	MetaProgress.currency.credits=0
	var ui=load("res://scenes/meta.tscn").instantiate();ui.initial_page="heroes";add_child(ui)
	ui.heroes.selected="ORCA";ui.heroes.refresh()
	check(not marked(ui.heroes.escort) and not marked(ui.hero_tab) and not marked(ui.pool_tab),"locked hero and unowned skills have no upgrade dots")
	MetaProgress.academy.hero_builds.ORCA=5
	var cost:=Academy.hero_talent_cost("escort",0,"ORCA")
	funds(cost-1)
	check(not marked(ui.heroes.escort) and not marked(ui.heroes.hero_buttons.ORCA),"one core short hides hero action and selector dots")
	funds(cost)
	check(marked(ui.heroes.escort) and marked(ui.heroes.survival) and marked(ui.heroes.hero_buttons.ORCA) and marked(ui.hero_tab),"exact balance lights hero actions selector and tab")
	var dot=ui.heroes.escort.get_node("UpgradeDot")
	check(dot.mouse_filter==Control.MOUSE_FILTER_IGNORE,"dot cannot intercept upgrade clicks")
	var saved:Dictionary=MetaProgress.to_dict().duplicate(true)
	for i in 3:ui.heroes.refresh()
	check(ui.heroes.escort.get_node("UpgradeDot")==dot and MetaProgress.to_dict()==saved,"refresh reuses indicator without progression writes")
	ui.heroes.escort.pressed.emit()
	check(MetaProgress.academy.hero_escort_ranks.ORCA==1 and MetaProgress.balance("cores")==0,"real hero talent purchase consumes exact cost")
	check(not marked(ui.heroes.escort) and not marked(ui.hero_tab),"purchase refresh removes now-unaffordable dots immediately")
	MetaProgress.academy.hero_escort_ranks.ORCA=5;MetaProgress.academy.hero_survival_ranks={"ORCA":5}
	funds(100000)
	check(not marked(ui.heroes.escort) and not marked(ui.heroes.survival) and not marked(ui.hero_tab),"fully trained hero never shows talent upgrade dots")
	const CARD="ap_smoke"
	ui._set_page("pool");ui.training_group="通用";ui.selected_card=CARD;ui._refresh_pool()
	check(not marked(ui.pool_body.get_node("TrainingUpgrade")),"unowned card acquisition is not an upgrade alert")
	MetaProgress.unlocked_skills.append(CARD)
	fill_equipment()
	cost=Academy.card_upgrade_cost(CARD,0);funds(cost-1)
	check(not marked(ui.pool_body.get_node("TrainingUpgrade")) and not marked(ui.pool_tab),"insufficient card upgrade cost hides action and tab")
	funds(cost)
	check(marked(ui.pool_body.get_node("TrainingUpgrade")) and marked(ui.pool_tab),"owned card exact balance lights action and skill tab")
	var picker:OptionButton=ui.pool_body.get_node("TrainingCard")
	check(picker.get_item_text(picker.selected).contains("可升级"),"skill selector identifies affordable card")
	ui.pool_body.get_node("TrainingUpgrade").pressed.emit()
	check(Academy.card_rank(MetaProgress,CARD)==1 and not marked(ui.pool_tab) and not marked(ui.pool_body.get_node("TrainingUpgrade")),"real card purchase updates all markers immediately")
	MetaProgress.academy.levels[CARD]=3;funds(100000)
	check(not marked(ui.pool_tab) and not marked(ui.pool_body.get_node("TrainingUpgrade")),"maxed card has no dot even with abundant currency")
	var hero_card:String=preload("res://scripts/rules/hero_contract_pool.gd").for_hero("ORCA").cards[0]
	MetaProgress.unlocked_skills.append(hero_card)
	fill_equipment()
	cost=Academy.card_upgrade_cost(hero_card,0);funds(cost)
	ui._set_page("heroes");ui.heroes.selected="ORCA";ui.heroes.refresh()
	var reward:Button=ui.heroes.expansion_contract.find_child("Upgrade_"+hero_card,true,false)
	check(marked(reward) and marked(ui.heroes.hero_buttons.ORCA) and marked(ui.hero_tab) and not marked(ui.pool_tab) and not ui.pool_tab.tooltip_text.contains(str(GameData.get_skill(hero_card).name)),"hero reward marks only hero controls and stays out of the pool tooltip")
	reward.pressed.emit()
	check(Academy.card_rank(MetaProgress,hero_card)==1 and not marked(ui.hero_tab) and not marked(ui.pool_tab),"hero reward purchase refreshes aggregate indicators")
	MetaProgress.academy.levels[hero_card]=3
	MetaProgress.unit_talents={"E1":{"native_deploy_def":0}}
	MetaProgress.talent_slots={"E1":1};MetaProgress.owned_talent_points=1
	cost=MetaProgress.talent_upgrade_cost("E1","native_deploy_def")
	ui._set_page("units");ui._unit_sel="E1";ui._rebuild_unit_detail();funds(cost-1)
	check(not marked(ui.unit_detail.find_child("UpgradeTalent_native_deploy_def",true,false)) and not marked(ui.tab_units_btn),"unit talent insufficient balance hides indicators")
	funds(cost)
	var talent_button:Button=ui.unit_detail.find_child("UpgradeTalent_native_deploy_def",true,false)
	check(marked(talent_button) and marked(ui.tab_units_btn),"unit talent exact balance lights upgrade and unit tab")
	talent_button.pressed.emit()
	check(MetaProgress.talent_rank("E1","native_deploy_def",MetaProgress.unit_talents)==1 and not marked(ui.tab_units_btn),"actual unit talent upgrade removes unaffordable aggregate dot")
	MetaProgress.unit_talents.E1.native_deploy_def=MetaProgress.talent_options("E1").native_deploy_def.ranks.size();funds(100000)
	check(not Upgrade.talent("E1","native_deploy_def") and marked(ui.tab_units_btn),"maxed talent has no upgrade but other affordable unlocks keep tab lit")
	MetaProgress.unit_talents={};MetaProgress.talent_slots={};MetaProgress.owned_talent_points=0
	ui._unit_sel="JUMPJET"
	var offer:=MetaProgress.talent_unlock_quote("JUMPJET","hover_sighting")
	check(not offer.is_empty() and offer.cost==80,"screenshot hover talent unlock costs 80 cores")
	funds(int(offer.cost)-1)
	check(not marked(ui.unit_detail.find_child("Talent_hover_sighting",true,false)) and not marked(ui.unit_list.find_child("ViewUnit_JUMPJET",true,false)),"one core short hides unlock button and unit row")
	funds(int(offer.cost))
	var unlock:Button=ui.unit_detail.find_child("Talent_hover_sighting",true,false)
	check(marked(unlock) and marked(ui.unit_list.find_child("ViewUnit_JUMPJET",true,false)) and marked(ui.tab_units_btn),"affordable unowned talent marks button row and top tab")
	saved=MetaProgress.to_dict().duplicate(true)
	for i in 3:Upgrade.any_unit_talent();ui._refresh()
	check(MetaProgress.to_dict()==saved,"unlock indicators never spend points slots or currency")
	unlock=ui.unit_detail.find_child("Talent_hover_sighting",true,false)
	unlock.pressed.emit()
	check(MetaProgress.selected_talents("JUMPJET",MetaProgress.unit_talents).has("hover_sighting") and MetaProgress.balance("cores")==0,"real unlock purchases talent at exact price")
	check(not marked(ui.tab_units_btn) and not marked(ui.unit_list.find_child("ViewUnit_JUMPJET",true,false)),"unlock spending immediately clears unaffordable row and tab")
	MetaProgress.unit_talents={};MetaProgress.talent_slots={"JUMPJET":1};MetaProgress.owned_talent_points=1;funds(0)
	check(MetaProgress.talent_unlock_quote("JUMPJET","hover_sighting").cost==0 and marked(ui.unit_detail.find_child("Talent_hover_sighting",true,false)) and marked(ui.tab_units_btn),"prepaid slot and point show free unlock at zero currency")
	ui.unit_detail.find_child("Talent_hover_sighting",true,false).pressed.emit()
	check(MetaProgress.unassigned_talent_points()==0 and not marked(ui.tab_units_btn),"free unlock consumes existing point and clears indicators")
	check(not Upgrade.talent_unlock("JUMPJET","hover_sighting") and not Upgrade.talent_unlock("invalid","invalid"),"owned and invalid talents never show unlock dots")
	ui._set_page("heroes");ui.heroes.selected="ORCA"
	MetaProgress.academy.hero_training={}
	MetaProgress.currency.credits=Academy.hero_training_cost(0)-1;Events.meta_changed.emit()
	check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health) and not marked(ui.hero_tab),"training one credit short has no button or tab dots")
	MetaProgress.currency.credits=Academy.hero_training_cost(0);Events.meta_changed.emit()
	check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health) and not marked(ui.heroes.hero_buttons.ORCA) and not marked(ui.hero_tab) and not ui.heroes.firepower.disabled,"affordable credit training remains clickable without button roster or tab dots")
	ui.heroes.firepower.pressed.emit()
	check(Academy.training_rank(MetaProgress.academy.hero_training,"ORCA","firepower")==1 and MetaProgress.balance("credits")==0,"real training button spends exact credits")
	check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health) and not marked(ui.hero_tab),"training purchase refreshes all indicators immediately")
	MetaProgress.currency.credits=1000000
	for hero_id:String in Academy.HEROES:
		MetaProgress.academy.hero_builds[hero_id]=0;ui.heroes.selected=hero_id;Events.meta_changed.emit()
		check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health),"locked hero cannot train "+hero_id)
		MetaProgress.academy.hero_builds[hero_id]=Academy.hero_requirement(hero_id);Events.meta_changed.emit()
		check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health) and not marked(ui.heroes.hero_buttons[hero_id]) and not marked(ui.hero_tab) and not ui.heroes.health.disabled,"all heroes suppress credit training dots while allowing training "+hero_id)
		MetaProgress.academy.get_or_add("hero_training",{})[hero_id]={"firepower":Academy.training_cap("firepower"),"health":Academy.training_cap("health")};Events.meta_changed.emit()
		check(not marked(ui.heroes.firepower) and not marked(ui.heroes.health),"maxed hero training hides buttons "+hero_id)
	check(not marked(ui.hero_tab),"all training maxed with no affordable talents or cards clears hero tab")
	MetaProgress.reset_save();MetaProgress.currency.cores=0;MetaProgress.unlocked_skills.clear()
	var legend_id:=""
	for card:Dictionary in MetaProgress.skill_draw_candidates():
		if card.rarity=="legend":
			if legend_id.is_empty():legend_id=str(card.id)
			else:MetaProgress.unlocked_skills.append(str(card.id));MetaProgress.academy.get_or_add("levels",{})[card.id]=3
	check(not legend_id.is_empty(),"legend test uses current exchange candidate")
	ui.training_group=preload("res://scripts/rules/skill_scope.gd").group(GameData.get_skill(legend_id))
	ui.selected_card=legend_id;ui._set_page("pool")
	MetaProgress.academy.card_shards=Academy.EXCHANGE.legend-1;Events.meta_changed.emit()
	check(not Upgrade.legend_unlock(legend_id) and not marked(ui.pool_tab) and not marked(ui.pool_body.get_node("TrainingUpgrade")),"one shard short hides legend unlock dots")
	MetaProgress.academy.card_shards=Academy.EXCHANGE.legend;Events.meta_changed.emit()
	check(Upgrade.legend_unlock(legend_id) and marked(ui.pool_tab) and marked(ui.pool_body.get_node("TrainingGroup")) and marked(ui.pool_body.get_node("TrainingUpgrade")),"exact shards mark legend action category switch and skill tab")
	check(marked(ui.pool_body.find_child("PoolCard_"+legend_id,true,false)) and ui.pool_tab.tooltip_text.contains("兑换碎片足够解锁"),"legend entry and tab explain acquisition alert")
	var legend_picker:OptionButton=ui.pool_body.get_node("TrainingCard")
	check(legend_picker.get_item_text(legend_picker.selected).contains("可解锁"),"legend selector identifies unlockable card")
	saved=MetaProgress.to_dict().duplicate(true)
	for i in 3:Upgrade.any_card();Upgrade.legend_unlock(legend_id)
	check(saved==MetaProgress.to_dict(),"legend queries do not spend shards or grant cards")
	ui.pool_body.get_node("TrainingUpgrade").pressed.emit()
	check(MetaProgress.skill_unlocked(legend_id) and MetaProgress.academy.card_shards==0,"real legend exchange grants card and consumes exact shards")
	check(not marked(ui.pool_tab) and not marked(ui.pool_body.get_node("TrainingGroup")) and not marked(ui.pool_body.get_node("TrainingUpgrade")),"exchange clears acquisition dots with no affordable upgrades")
	MetaProgress.academy.card_shards=1000;Events.meta_changed.emit()
	check(not marked(ui.pool_tab) and not Upgrade.legend_unlock(legend_id) and not Upgrade.legend_unlock("invalid"),"owned legends and nonlegend exchange opportunities do not produce legend alerts")
	ui.free();await get_tree().process_frame
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
