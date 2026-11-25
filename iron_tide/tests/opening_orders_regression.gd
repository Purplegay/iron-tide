extends Node
const Plans = preload("res://scripts/rules/opening_order_plans.gd")
var failed:=0
func check(ok:bool,what:String):
	if not ok:failed+=1;push_error(what)
func _ready():
	if not OS.get_user_data_dir().contains("OpeningOrdersValidation"):get_tree().quit(2);return
	if "--cold" in OS.get_cmdline_user_args():
		var book := Plans.current({})
		check(book.selected==1 and book.plans[1].name=="合成军" and book.plans[1].orders==["HTNK","E1","E1"],"cold persisted reordered book")
		print("OPENING_COLD failures=",failed)
		get_tree().quit(int(failed>0));return
	MetaProgress.reset_save();MetaProgress.grant("cores",120)
	var tree=preload("res://scripts/ui/technology_tree.gd").new();add_child(tree)
	var card:Dictionary=tree.cards.production_recipes
	card.button.pressed.emit();card.button.pressed.emit()
	check(MetaProgress.technology_active("production_recipes_2"),"tier two")
	check(Expedition.start("美国", "", 772) and Expedition.choose(0), "start expedition before configuring orders")
	card.button.get_parent().get_node("OpeningOrders").pressed.emit()
	var editor=tree.get_child(-1)
	var old=preload("res://scripts/rules/opening_order_plans.gd").selected_orders({"opening_orders":{"allied":["E1"],"soviet":["HTNK"]}})
	check(old==["E1","HTNK"],"legacy mixed orders")
	editor._new_plan()
	check(editor.plan_name.text=="2" and editor.book.plans[0].name=="1","numbered plans")
	editor.plan_name.text="合成军"
	editor.plan_name.text_changed.emit("合成军")
	var found:=false
	for tile in editor.catalog.get_children():
		if tile.get_child(0).data.id=="E1":
			check(tile.get_child(0).cameo_texture!=null,"portrait")
			tile.get_child(1).pressed.emit();tile.get_child(1).pressed.emit();found=true;break
	check(found and editor.orders.get_child_count()==1 and editor.orders.get_child(0).get_child(1).text.ends_with("×2"),"ordered list")
	editor.faction="soviet"
	editor.refresh()
	for tile in editor.catalog.get_children():
		if tile.get_child(0).data.id=="HTNK":tile.get_child(1).pressed.emit();break
	check(editor.orders.get_child_count()==2,"single mixed plan")
	editor.book.plans[1].orders.append("E1")
	editor.refresh_orders()
	check(editor.orders.get_child_count()==3,"separate non-adjacent orders")
	editor.orders.get_child(2).get_child(1).pressed.emit()
	check(editor.book.plans[1].orders==["E1","E1","HTNK"],"remove from displayed group")
	editor.reorder.button_pressed=true
	editor.orders.get_child(0).get_child(1).pressed.emit()
	check(editor.orders.get_child(0).get_child(1).button_pressed,"selected group highlighted")
	editor.orders.get_child(1).get_child(1).pressed.emit()
	check(editor.book.plans[1].orders==["HTNK","E1","E1"],"move repeated group to last position")
	editor.orders.get_child(1).get_child(1).pressed.emit()
	editor.orders.get_child(0).get_child(1).pressed.emit()
	check(editor.book.plans[1].orders==["E1","E1","HTNK"],"move repeated group to first position")
	editor.orders.get_child(0).get_child(1).pressed.emit()
	editor.orders.get_child(0).get_child(1).pressed.emit()
	check(editor.move_from==-1 and editor.book.plans[1].orders.size()==3,"clicking selected group cancels move")
	editor.orders.get_child(0).get_child(1).pressed.emit()
	editor._select_plan(0)
	check(editor.move_from==-1 and not editor.reorder.button_pressed and editor.book.plans[0].orders.is_empty(),"switching plans discards selection")
	editor._select_plan(1)
	editor.reorder.button_pressed=true
	editor.book.plans[1].orders.append("E1")
	editor.refresh_orders()
	editor.orders.get_child(2).get_child(1).pressed.emit()
	editor.orders.get_child(1).get_child(1).pressed.emit()
	check(editor.orders.get_child_count()==2 and editor.book.plans[1].orders==["E1","E1","E1","HTNK"],"neighbors merge after move")
	editor.reorder.button_pressed=false
	editor.orders.get_child(0).get_child(1).pressed.emit()
	editor.reorder.button_pressed=true
	editor.orders.get_child(1).get_child(1).pressed.emit()
	editor.orders.get_child(0).get_child(1).pressed.emit()
	editor._save()
	MetaProgress.save() # Ordinary progress still holds the pre-edit profile.
	MetaProgress.load_save()
	check(Plans.current(MetaProgress.academy).plans[1].name=="合成军" and Plans.current(MetaProgress.academy).selected==1,"named active plan reloaded")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"starting_funds":50000})
	var screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED
	var world=screen.battle
	check(world.allied_state.get("opening_orders_pending",[])==["HTNK","E1","E1"],"opening snapshot uses reordered plan")
	var barracks=world._place_building("GAPILE","ally",Vector2(1540,1480),true)
	for factory in world.buildings:
		if factory.side=="ally" and "E1" in factory.buildable:factory.under_construction=true
	world._process(1.0)
	check(world.allied_state.get("opening_orders_pending",[])==["HTNK","E1","E1"],"wait for factory")
	barracks.under_construction=false
	barracks._buildup_play=-1
	world._process(1.1)
	world._process(1.1)
	var queued:=0
	for b in world.buildings:
		if b.side=="ally":queued+=b.production.count("E1")
	check(queued==2 and world.allied_state.get("opening_orders_pending",[])==["HTNK"],"barracks finished independently")
	BattleRequest.combat_context.expedition={"licenses":["E1","HTNK"],"condition":"funds","buffs":{},"catalog":["E1","HTNK"]}
	screen.hud._set_topbar_visible(true)
	var toggle: Button = screen.hud._opening_orders_button
	check(toggle.is_visible_in_tree() and toggle.text.contains("关闭"),"ESC top bar action")
	screen.hud.select_prod_tab("vehicle")
	var deck: Button = screen.hud._deck_orders_button
	check(deck.is_visible_in_tree() and deck.text.contains("合成军"), "active plan on vehicle deck")
	screen.hud._recipe_button.pressed.emit()
	var panel: Button = screen.hud._recipe_window.plan_button
	check(panel.is_visible_in_tree() and panel.text == deck.text, "active plan in recipe window")
	panel.pressed.emit()
	check(deck.text.contains("恢复"), "recipe pause reflected on deck")
	var plant=world._place_building("NAWEAP","ally",Vector2(1750,1500),true)
	plant._buildup_play=-1
	world._process(1.1)
	check(toggle.text.contains("恢复") and plant.production.is_empty() and world.allied_state.opening_orders_pending==["HTNK"],"pending order held")
	check(barracks.production.count("E1")==2,"existing queue retained")
	deck.pressed.emit()
	world._process(1.1)
	screen.hud._refresh_top()
	check(panel.disabled and panel.text.contains("已全部排入队列") and deck.text == panel.text, "completed plan stays visible")
	check(not toggle.visible,"completed orders hide action")
	check(plant.production.count("HTNK")==1 and not world.allied_state.has("opening_orders_pending"),"Soviet factory receives expedition order")
	panel.pressed.emit()
	check(not world.allied_state.has("opening_orders_pending"), "completed orders cannot be imported again")
	BattleRequest.combat_context.opening_orders = []
	screen.hud._refresh_top()
	check(not panel.disabled and panel.text.contains("载入"), "empty battle offers saved plan")
	panel.pressed.emit()
	check(world.allied_state.get("opening_orders_pending", []) == ["HTNK","E1","E1"], "import exact saved sequence")
	screen.free()
	check(Expedition.state.frozen.get("opening_orders", []).is_empty(), "departure snapshot has no orders")
	check(Expedition.launch(0), "launch expedition stage after editing plan")
	check(BattleRequest.combat_context.get("opening_plan_name", "") == "合成军" and BattleRequest.combat_context.get("opening_orders", []) == ["HTNK","E1","E1"], "stage takes current plan")
	print("OPENING_ORDERS failures=",failed)
	get_tree().quit(int(failed>0))
