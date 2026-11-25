extends Node

var checks: Array = []
var failed := 0
var output := ""

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok:
		failed += 1
		print("FAIL ", label)

func frames() -> void:
	for i in 4: await get_tree().process_frame

func picture(name: String) -> void:
	await frames()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await frames()

func begin_battle(mode: String):
	BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000})
	var scene = load("res://scenes/battle.tscn").instantiate()
	add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GM.unlock_production_tech = false
	MetaProgress.reset_save()
	check(MetaProgress.unassigned_talent_points()==0 and not MetaProgress.redeem_talent_point() and not MetaProgress.set_unit_talent("R3REAPER","reaper_fire_control"),"new profile has no free points or unpaid allocation")
	var legacy:Dictionary=MetaProgress.to_dict().duplicate(true)
	legacy.erase("owned_talent_points")
	legacy.erase("talent_slots")
	legacy.erase("unit_talents")
	legacy.unlocked_technologies=["reaper_fire_control"]
	legacy.currency.credits=7
	var migration:=FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE)
	migration.store_string(JSON.stringify(legacy));migration.close()
	MetaProgress.load_save();MetaProgress.load_save()
	check(MetaProgress.balance("credits")==1207 and not MetaProgress.unlocked_technologies.has("reaper_fire_control") and MetaProgress.unit_talents.get("R3REAPER")=="reaper_fire_control","paid technology migrates and refunds exactly once")
	check(MetaProgress.owned_talent_points==1 and MetaProgress.unassigned_talent_points()==0,"grandfather only allocated legacy points")
	check(MetaProgress.talent_capacity("R3REAPER")==1 and MetaProgress.talent_capacity("MTNK")==0,"legacy migration grants only occupied slots on their original type")
	MetaProgress.grant("cores",120)
	check(MetaProgress.buy_talent_slot("R3REAPER",2),"old profile can purchase its second slot")
	check(MetaProgress.redeem_talent_point() and MetaProgress.balance("cores")==0 and MetaProgress.balance("credits")==1207 and MetaProgress.talent_points("R3REAPER")==1 and MetaProgress.set_unit_talent("R3REAPER","reaper_split_fire"),"legacy talent leaves room for split fire")
	MetaProgress.load_save()
	check(MetaProgress.talent_points("R3REAPER")==0 and MetaProgress.selected_talents("R3REAPER",MetaProgress.unit_talents).size()==2,"both talents survive reload")
	check(not MetaProgress.set_unit_talent("R3REAPER","reaper_split_fire",false) and not MetaProgress.set_unit_talent("R3REAPER",""),"neither refund nor clearing all allocations is accepted")
	MetaProgress.load_save()
	check(MetaProgress.redeemed_points_in_use()==2 and MetaProgress.unassigned_talent_points()==0,"legacy allocations remain permanent after reload")
	check(not MetaProgress.set_unit_talent("MTNK","reaper_fire_control"),"only Reaper can allocate its personal talent")
	check(not MetaProgress.upgrade_talent("R3REAPER","reaper_split_fire",0),"rank zero has the base ability but cannot upgrade without cores")
	MetaProgress.grant("cores",800)
	for talent in ["reaper_split_fire","reaper_fire_control"]:
		for rank in range(1,4):
			var prev := MetaProgress.balance("cores")
			check(MetaProgress.upgrade_talent("R3REAPER",talent,rank-1) and MetaProgress.balance("cores")==prev-[40,120,240][rank-1],"upgrade consumes escalating cores at rank "+str(rank))
			MetaProgress.load_save()
			check(MetaProgress.talent_rank("R3REAPER",talent,MetaProgress.unit_talents)==rank and MetaProgress.unassigned_talent_points()==0,"rank persists without an additional slot")
		check(not MetaProgress.upgrade_talent("R3REAPER",talent,3),"maximum rank prevents another purchase")
	BattleRequest.freeze_combat_context()
	check(BattleRequest.talent_upgrade("R3REAPER","reaper_split_fire","ally").damage==1.5 and BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control","ally").charge_seconds==2.0 and MetaProgress.redeemed_points_in_use()==2,"two max talents occupy two slots and two permanent points")
	BattleRequest.combat_context={"technologies":["reaper_fire_control"]}
	check(BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","ally") and not BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","enemy"),"old match uses its saved technology, only for the owner")
	BattleRequest.combat_context={"technologies":[]}
	check(not BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","ally"),"old unresearched match ignores newly selected talent")
	BattleRequest.combat_context={}
	MetaProgress.reset_save()
	# An old progression file has no technology field. Keep unrelated progress.
	var old: Dictionary = MetaProgress.to_dict().duplicate(true)
	old.erase("unlocked_technologies")
	old.currency.cores = 39.0
	old.stats.legacy_marker = 17
	var file := FileAccess.open(MetaProgress.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	MetaProgress.unlocked_technologies.assign(["structure_queue"])
	MetaProgress.load_save()
	check(MetaProgress.unlocked_technologies.is_empty() and MetaProgress.stats.legacy_marker == 17 and MetaProgress.balance("cores") == 39.0, "old meta migrates with locked technology and unchanged currency/stats")
	check(not MetaProgress.research_technology("unknown") and not MetaProgress.research_technology("structure_queue") and MetaProgress.balance("cores") == 39.0, "invalid and unaffordable research cannot spend")
	# Keep this driver alive while real menu callbacks change current_scene.
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await frames()
	var menu = get_tree().current_scene
	var entry: Button
	for button in menu.find_children("*", "Button", true, false):
		if button.text == "科技树": entry = button
	check(entry != null, "main menu exposes technology entry")
	if entry != null: await click(entry)
	check(get_tree().current_scene.scene_file_path == "res://scenes/technology.tscn", "actual main menu click opens technology screen")
	var screen = get_tree().current_scene
	var tree = screen.technology_tree
	check(screen._page == "technology" and screen.technology_body.visible, "direct entry selects technology tab")
	check(tree.cards.structure_queue.button.disabled and "还差 1" in tree.cards.structure_queue.status.text, "unaffordable card shows exact currency shortage")
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = size
		await picture("technology-locked-" + str(size.x))
		var viewport := get_viewport().get_visible_rect()
		for id in tree.cards:
			screen.technology_body.ensure_control_visible(tree.cards[id].button)
			await frames()
			check(tree.cards[id].button.is_visible_in_tree() and viewport.encloses(tree.cards[id].button.get_global_rect()), "research card visible at " + str(size.x) + ": " + id)
		check(viewport.encloses(screen.tab_technology_btn.get_global_rect()), "technology tab fits at " + str(size.x))
	await click(screen.tab_logi_btn)
	check(screen.logistics_body.visible and not screen.technology_body.visible, "existing logistics tab still opens")
	await click(screen.tab_technology_btn)
	check(screen.technology_body.visible, "garrison tab returns to technology tree")
	MetaProgress.grant("cores", 1.0)
	check(not tree.cards.structure_queue.button.disabled, "currency update enables affordable research")
	screen.technology_body.ensure_control_visible(tree.cards.structure_queue.button)
	await frames()
	await click(tree.cards.structure_queue.button)
	check(MetaProgress.technology_owned("structure_queue") and MetaProgress.balance("cores") == 0.0, "real research click unlocks once and charges configured cost")
	tree.cards.structure_queue.button.pressed.emit()
	check(MetaProgress.unlocked_technologies.count("structure_queue") == 1 and MetaProgress.balance("cores") == 0.0, "repeat callback cannot buy owned technology again")
	check(tree.cards.structure_queue.button.disabled and "Lv.1 / 3" in tree.cards.structure_queue.title.text and "升级至 Lv.2" in tree.cards.structure_queue.button.text, "grouped card retains purchased tier and shows unaffordable next upgrade")
	await picture("technology-unlocked")
	MetaProgress.unlocked_technologies.clear()
	MetaProgress.currency.cores = 9999.0
	MetaProgress.load_save()
	check(MetaProgress.technology_owned("structure_queue") and MetaProgress.balance("cores") == 0.0 and MetaProgress.stats.legacy_marker == 17, "reload restores unlock and exact balance without losing old stats")
	get_tree().current_scene = null
	screen.free()
	var battle_screen = begin_battle(MatchRules.EXTENDED)
	var battle = battle_screen.battle
	check(battle.structure_reservations_enabled() and not battle.structure_reservations_enabled("enemy"), "new extension match receives only player's permanent technology")
	check(not battle.production_technology.is_unlocked("refinery_miner", "ally"), "unowned miner technology remains locked without debug override")
	var saved := BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, "battle snapshots current technology state")
	MetaProgress.grant("cores", 40.0)
	MetaProgress.save()
	var before := FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	var temporary := MetaProgress.SAVE_PATH + ".tmp"
	check(DirAccess.make_dir_absolute(temporary) == OK, "isolated fixture blocks temporary save path")
	check(not MetaProgress.buy_talent_slot("R3REAPER",1) and MetaProgress.talent_capacity("R3REAPER")==0 and MetaProgress.balance("cores")==40,"failed slot purchase rolls back capacity and exact balance")
	check(not MetaProgress.redeem_talent_point() and MetaProgress.owned_talent_points==0 and MetaProgress.balance("cores")==40,"failed redemption saves neither debit nor point")
	check(not MetaProgress.set_effect_enabled("tech","structure_queue","",false) and MetaProgress.effect_enabled("tech","structure_queue"),"failed switch save restores previous active choice")
	check(not MetaProgress.research_technology("refinery_miner") and not MetaProgress.technology_owned("refinery_miner") and MetaProgress.balance("cores") == 40.0, "failed disk write rolls back research and currency")
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH) == before, "failed purchase preserves original save bytes")
	DirAccess.remove_absolute(temporary)
	check(MetaProgress.research_technology("refinery_miner"), "research succeeds after storage recovers")
	check(not battle.production_technology.is_unlocked("refinery_miner", "ally"), "mid-match progression change does not alter frozen match rules")
	var loaded := BattleSaves.read_slot("slot1")
	check(loaded.ok, "old battle file remains valid after permanent purchase")
	if loaded.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle, loaded.snapshot)
		check(not battle.production_technology.is_unlocked("refinery_miner", "ally") and MetaProgress.technology_owned("refinery_miner"), "restoring old battle neither gains new tech nor rolls back permanent unlock")
	check(not battle.can_repair_all() and battle_screen.hud.building_action_buttons.repair_all.disabled, "unresearched mass repair is locked")
	MetaProgress.grant("cores", 40)
	get_tree().paused = false
	var match_tech = battle.production_technology
	battle_screen.free()
	get_tree().change_scene_to_file("res://scenes/technology.tscn")
	await frames()
	screen = get_tree().current_scene
	tree = screen.technology_tree
	screen.technology_body.ensure_control_visible(tree.cards.repair_all.button)
	await frames()
	await click(tree.cards.repair_all.button)
	check(MetaProgress.technology_owned("repair_all") and MetaProgress.balance("cores") == 0, "buy mass repair from technology tree for 40 cores")
	check(not match_tech.is_unlocked("repair_all","ally"), "previous match retains locked mass repair")
	MetaProgress.grant("cores",280)
	check(not MetaProgress.research_technology("bunker_optics_3"),"tier III requires prior optics research")
	for id in ["bunker_optics_1","bunker_optics_2","bunker_optics_3"]:
		screen.technology_body.ensure_control_visible(tree.cards[id].button)
		await frames()
		await click(tree.cards[id].button)
		check(MetaProgress.technology_owned(id),"technology tree buys "+id)
	var tier_switch:CheckButton=tree.cards.bunker_optics_1.toggle
	screen.technology_body.ensure_control_visible(tier_switch)
	await frames()
	await click(tier_switch)
	BattleRequest.freeze_combat_context()
	check(not MetaProgress.technology_active("bunker_optics_3") and MetaProgress.technology_owned("bunker_optics_3") and not BattleRequest.combat_context.technologies.has("bunker_optics_2"),"disabling prerequisite retains purchases and suspends dependent effects")
	await click(tier_switch)
	check(MetaProgress.technology_active("bunker_optics_3") and not BattleRequest.combat_context.technologies.has("bunker_optics_3"),"reactivation respects previously frozen battle")
	await picture("soviet-bunker-optics")
	check(match_tech.bunker_level("ally")==0 and MetaProgress.balance("cores")==0,"saved match retains old optics and research costs exactly 280 cores")
	check(not tree.cards.has("reaper_fire_control"),"fire control is no longer a technology card")
	MetaProgress.grant("cores",80)
	await click(screen.shop_tab)
	check(screen.shop_body.visible,"garrison shop tab opens")
	for i in 2:
		await click(screen.shop_body.find_child("RedeemTalentPoint",true,false))
		check(MetaProgress.balance("cores")==40*(1-i) and MetaProgress.unassigned_talent_points()==i+1,"shop purchases one unassigned point at configured price")
	check(screen.shop_body.find_child("RedeemTalentPoint",true,false).disabled,"unaffordable exchange disabled")
	MetaProgress.load_save()
	check(MetaProgress.owned_talent_points==2 and MetaProgress.unit_talents.is_empty(),"redeemed points survive reload before choosing any unit")
	await click(screen.tab_units_btn)
	var select_reaper:Button
	for row in screen.unit_list.get_children():
		for label in row.find_children("*","Label",true,false):
			if label.text==GameData.get_unit("R3REAPER").name:
				select_reaper=row.find_children("*","Button",true,false)[0]
	check(select_reaper!=null,"Reaper is selectable in unit modification")
	var saw_unfeatured:=false
	for row in screen.unit_list.get_children():
		var talents:=MetaProgress.talent_options(row.get_meta("refit_unit"))
		if talents.is_empty(): saw_unfeatured=true
		else: check(not saw_unfeatured,"all units with personal talents precede ordinary units")
	if select_reaper!=null:
		screen.unit_list.get_parent().ensure_control_visible(select_reaper)
		await frames()
		await click(select_reaper)
		var menus:=0
		for option:OptionButton in screen.unit_detail.find_children("*","OptionButton",true,false):
			if not option.has_meta("ids"):continue
			var ids:Array=option.get_meta("ids")
			var previous:int=option.selected
			var popup:=option.get_popup()
			option.show_popup()
			await frames()
			var matched:=popup.visible and popup.get_item_tooltip(0)=="此槽位不装配技能。"
			for item in range(1,ids.size()):
				var skill:=GameData.get_skill(ids[item])
				matched=matched and not str(skill.desc).is_empty() and popup.get_item_tooltip(item)=="%s\n%s"%[skill.name,skill.desc]
			popup.hide()
			check(matched and option.selected==previous,"opened skill choices have individual descriptions without changing equipment")
			menus+=1
		check(menus==2,"both active and passive skill lists expose hover descriptions")
		check(MetaProgress.unassigned_talent_points()==2 and MetaProgress.talent_capacity("R3REAPER")==0 and not MetaProgress.set_unit_talent("R3REAPER","reaper_fire_control"),"wallet points alone cannot unlock a talent")
		check(not MetaProgress.buy_talent_slot("MTNK",1) and not MetaProgress.buy_talent_slot("R3REAPER",2),"insufficient funds and skipping first slot are rejected")
		MetaProgress.grant("cores",120)
		screen._unit_sel="R3APOC"
		for slots in [0,1]:
			if slots==1:
				MetaProgress.talent_slots["R3APOC"]=1
				MetaProgress.save()
				MetaProgress.load_save()
			screen._rebuild_unit_detail()
			check(screen.unit_detail.find_child("OpenTalentSlot",true,false)==null,"unreleased talents hide slot purchase at capacity %d"%slots)
			check(not MetaProgress.buy_talent_slot("R3APOC",slots+1) and MetaProgress.balance("cores")==120 and MetaProgress.talent_capacity("R3APOC")==slots,"unreleased talents reject slot purchase without debit or loss of saved capacity")
		screen._unit_sel="R3REAPER"
		screen._rebuild_unit_detail()
		for slot in [1,2]:
			var open_slot=screen.unit_detail.find_child("OpenTalentSlot",true,false)
			check(open_slot!=null,"next slot shown in selected unit details")
			if open_slot==null:break
			screen.unit_detail.get_parent().ensure_control_visible(open_slot)
			await frames()
			await click(open_slot)
			check(MetaProgress.talent_capacity("R3REAPER")==slot and MetaProgress.balance("cores")== (80 if slot==1 else 0),"slot charges its exact tier price")
			check(not MetaProgress.buy_talent_slot("R3REAPER",slot),"stale purchase cannot charge twice")
			if slot==1:
				check(MetaProgress.set_unit_talent("R3REAPER","reaper_fire_control") and not MetaProgress.set_unit_talent("R3REAPER","reaper_split_fire"),"one paid slot allows only one allocation even with sufficient cores")
		MetaProgress.load_save()
		check(MetaProgress.talent_capacity("R3REAPER")==2 and MetaProgress.unassigned_talent_points()==1 and MetaProgress.talent_capacity("MTNK")==0,"purchased slots persist separately from points and other unit types")
		check(not MetaProgress.buy_talent_slot("R3REAPER",3) and screen.unit_detail.find_child("OpenTalentSlot",true,false)==null,"two-slot ceiling hides further purchases")
		var passive_before:=MetaProgress.unit_loadout("R3REAPER")
		check(screen.unit_detail.find_child("Talent_reaper_fire_control",true,false)==null,"permanently allocated talent has no point button")
		var choice=screen.unit_detail.find_child("Talent_reaper_split_fire",true,false)
		check(choice!=null,"second talent offers permanent allocation")
		if choice!=null:
			screen.unit_detail.get_parent().ensure_control_visible(choice)
			await frames()
			await click(choice)
		check(MetaProgress.unassigned_talent_points()==0 and screen.unit_detail.find_child("Talent_reaper_split_fire",true,false)==null,"allocating through UI spends the point permanently")
		check(MetaProgress.set_unit_talent("R3REAPER","reaper_split_fire") and MetaProgress.redeemed_points_in_use()==2,"repeat allocation does not consume another point")
		check(MetaProgress.unit_loadout("R3REAPER")==passive_before and MetaProgress.balance("cores")==0,"talent never consumes a skill slot or currency")
		MetaProgress.grant("cores",40)
		await frames()
		var rank_button=screen.unit_detail.find_child("UpgradeTalent_reaper_fire_control",true,false)
		check(rank_button!=null and not rank_button.disabled,"full talent slots still allow rank upgrades with sufficient cores")
		if rank_button!=null:
			screen.unit_detail.get_parent().ensure_control_visible(rank_button)
			await frames()
			await click(rank_button)
		check(MetaProgress.talent_rank("R3REAPER","reaper_fire_control",MetaProgress.unit_talents)==1 and MetaProgress.unassigned_talent_points()==0,"upgrade button spends cores")
		MetaProgress.grant("credits",80)
		check(MetaProgress.buy_unit_upgrade("R3REAPER","atk"),"purchase unit attack level for switch test")
		await frames()
		for id in ["reaper_fire_control","atk"]:
			var toggle=screen.unit_detail.find_child("Enable_"+id,true,false)
			check(toggle!=null and toggle.button_pressed,"purchased effect has enabled switch "+id)
			if toggle!=null:
				screen.unit_detail.get_parent().ensure_control_visible(toggle)
				await frames()
				await click(toggle)
		MetaProgress.load_save()
		BattleRequest.freeze_combat_context()
		check(not BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","ally") and MetaProgress.unassigned_talent_points()==0 and MetaProgress.redeemed_points_in_use()==2 and BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control","ally").is_empty(),"disabled talent persists without refund")
		check(MetaProgress.unit_level("R3REAPER","atk")==1 and BattleRequest.unit_bonus("R3REAPER").attack_bonus==1.0,"disabled enhancement keeps level and contributes no damage bonus")
		check(MetaProgress.set_effect_enabled("track","atk","R3REAPER",true) and MetaProgress.set_effect_enabled("talent","reaper_fire_control","R3REAPER",true),"both switches reactivate without another purchase")
		check(BattleRequest.unit_bonus("R3REAPER").attack_bonus==1.0 and is_equal_approx(MetaProgress.unit_stat_bonus("R3REAPER").attack_bonus,1.0075),"active match keeps its original damage multiplier")
	check(MetaProgress.set_effect_enabled("tech","refinery_miner","",false),"disable owned refinery technology")
	BattleRequest.freeze_combat_context()
	GM.unlock_production_tech=true
	var probe=preload("res://scripts/rules/production_technology.gd").new()
	check(not probe.is_unlocked("refinery_miner","ally"),"explicit off takes precedence over default debug grant in new match")
	GM.unlock_production_tech=false
	MetaProgress.set_effect_enabled("tech","refinery_miner","",true)
	get_tree().current_scene=null
	screen.free()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		battle_screen = begin_battle(mode)
		battle = battle_screen.battle
		check(BattleRequest.has_unit_talent("R3REAPER","reaper_fire_control","ally")== (mode==MatchRules.EXTENDED),mode+" Reaper fire control follows match rules")
		var bulk: Button = battle_screen.hud.building_action_buttons.repair_all
		check(battle.can_repair_all() == (mode == MatchRules.EXTENDED) and bulk.visible == (mode == MatchRules.EXTENDED) and bulk.disabled == (mode == MatchRules.RA2), mode + " mass repair sidebar follows research and rules")
		var bunker = battle._place_building("NABNKR","ally",Vector2(1100,1500),true)
		var other = battle._place_building("NABNKR","enemy",Vector2(1450,1500),true)
		var garrison = preload("res://scripts/units/civilian_orders.gd")
		check(is_equal_approx(garrison.bunker_range(bunker)/55.0,8.5) == (mode==MatchRules.EXTENDED) and garrison.bunker_range(other)/55.0 < 8.0,mode+" permanent range applies only to researched ally and extension mode")
		bunker._buildup_play=-1
		var gunner=battle.spawn_unit("E2","ally",bunker.position+Vector2(30,0))
		garrison.enter(gunner,bunker)
		var target=battle.spawn_unit("HTNK","enemy",bunker.position+Vector2(8.25*55,0))
		if battle.fog!=null: battle.fog.rebuild()
		check(gunner.embarked_in==bunker and is_equal_approx(float(garrison.weapon(gunner).range),garrison.bunker_range(bunker)),mode+" garrison fires using same researched range")
		check(garrison.order_block_reason(bunker,target).is_empty()==(mode==MatchRules.EXTENDED), mode+" 8.25-cell target only inside upgraded bunker range")
		check(battle.structure_reservations_enabled() == (mode == MatchRules.EXTENDED), mode + " reservation progression mode isolation")
		check(battle.production_technology.is_unlocked("refinery_miner", "ally") == (mode == MatchRules.EXTENDED), mode + " miner progression mode isolation")
		battle_screen.free()
	var child_output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/technology_progression_cold.tscn"], child_output, true)
	check(code == 0, "fresh process reloads permanent technology and applies mode boundaries")
	check_unit_reservations()
	file = FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "cold_output": child_output}, "  "))
	file.close()
	print("TECHNOLOGY checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func check_unit_reservations() -> void:
	var caps:=[9,27,36,49,64,81]
	MetaProgress.grant("cores",1240)
	var balance_before:=MetaProgress.balance("cores")
	check(not MetaProgress.research_technology("unit_queue_5"),"unit queue tiers require earlier research")
	for level in caps.size():
		var scene=begin_battle(MatchRules.EXTENDED)
		var world=scene.battle
		var factory=world._place_building("GAPILE","ally",Vector2(1100,1300),true)
		factory._buildup_play=-1
		var enemy=world._place_building("GAPILE","enemy",Vector2(1450,1300),true)
		var refinery=world._place_building("GAREFN","ally",Vector2(1100,1500),true)
		var limit:int=caps[level]
		var all_accepted:=true
		for i in limit:
			all_accepted=factory.enqueue("E1" if i%2==0 else "DOG") and all_accepted
		check(all_accepted and factory.production.size()==limit and not factory.enqueue("E1"),"factory accepts exactly %d including active order"%limit)
		check(enemy.queue_capacity()==9 and refinery.queue_capacity()==1,"unit queue research isolated from enemy and refinery")
		if level==5:
			var id_list:Array=factory.production.duplicate()
			var slot:=BattleSaves.save_slot(world,"slot1")
			var loaded:=BattleSaves.read_slot("slot1")
			check(slot.ok and loaded.ok,"81 mixed orders save to disk")
			if loaded.ok:
				preload("res://scripts/save/battle_snapshot.gd").new().restore(world,loaded.snapshot)
				var restored:=false
				for producer in world.buildings:
					if producer.production==id_list and producer.queue_capacity()==81:restored=true
				check(restored,"restoring match preserves 81 mixed orders and research cap")
				get_tree().paused=false
		if level<5:
			var price:=40<<level
			check(MetaProgress.research_technology("unit_queue_%d"%(level+1)) and MetaProgress.balance("cores")==balance_before-price,"tier %d costs %d cores"%[level+1,price])
			balance_before-=price
			check(factory.queue_capacity()==limit,"buying research does not change running match")
		scene.free()
	MetaProgress.load_save()
	MetaProgress.set_effect_enabled("tech","unit_queue_3","",false)
	var next=begin_battle(MatchRules.EXTENDED)
	check(next.battle.production_technology.unit_capacity("ally")==36 and MetaProgress.technology_owned("unit_queue_5"),"disabling tier III uses tier II while preserving later purchases")
	next.free()
	MetaProgress.set_effect_enabled("tech","unit_queue_3","",true)
	next=begin_battle(MatchRules.RA2)
	check(next.battle.production_technology.unit_capacity("ally")==9,"classic match retains nine after full research")
	next.free()
