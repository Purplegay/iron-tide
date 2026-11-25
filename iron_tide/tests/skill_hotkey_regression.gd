extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: check_pool()
	for id in ["ap_smoke", "ap_marker", "ps_hollow_point"]: MetaProgress.unlock_skill(id)
	MetaProgress.unit_loadouts["E1"] = {"active": ["ap_smoke", "ap_bayonet", "ap_marker"], "passive": "ps_hollow_point"}
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	var soldier = battle.spawn_unit("E1", "ally", Vector2(1600, 1600))
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await exercise_additional_input(mode, soldier, null, null)
	screen.free()
	await get_tree().process_frame

func check_pool() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {})
	var meta = load("res://scenes/meta.tscn").instantiate()
	stage.add_child(meta)
	meta.tab_units_btn.pressed.emit()
	check(meta.refit_roster.has("DRON") and meta.refit_roster.has("R3APOC") and meta.refit_roster.has("TANY") and meta.refit_roster.has("R3HARBINGER"), "refit includes real restricted/extension products after RA2")
	check(not ["soviet_terror", "soviet_tank", "empire_mecha", "swarm_behemoth", "V3ROCKET", "HORNET"].any(func(id): return meta.refit_roster.has(id)), "no prototype, scenario or spawned refits")
	var roster_copy: Array = meta.refit_roster.duplicate()
	check(meta.unit_list.get_child_count() == roster_copy.size() and meta._faction_ids == ["", "allied", "soviet"], "refit UI matches playable faction roster")
	MetaProgress.unlocked_skills.assign(["ap_flank"])
	MetaProgress.unit_loadouts.MTNK = {"active": ["ap_overdrive"], "passive":"ps_armor_plating"}
	check(MetaProgress.unit_effective_loadout("MTNK") == {"active":[""], "passive":""} and UnitSkillLayout.primary_id("MTNK") == "ap_smoke", "old free W/passive gated but native Q retained")
	meta.pool_tab.pressed.emit()
	var cost := MetaProgress.skill_draw_cost()
	var cur := MetaProgress.skill_draw_currency()
	MetaProgress.currency[cur] = 0
	meta._refresh()
	check(meta.pool_body.visible and meta.pool_body.find_child("DrawSkill",true,false).disabled and MetaProgress.draw_skill().is_empty(), "visible pool rejects unaffordable draws")
	var candidates := MetaProgress.skill_draw_candidates()
	var generic:=candidates.filter(func(s):return s.get("allowed_units",[]).is_empty())
	check(candidates.size()==13 and generic.map(func(s):return s.id)==["ap_smoke","ap_overdrive","ap_focus_fire","ps_armor_plating","ps_hollow_point"],"all qualities combined retain exactly five universal cards")
	for id in preload("res://scripts/ui/faction_card_gallery.gd").card_ids():
		check(candidates.has(GameData.get_skill(id)),"specific card remains drawable "+id)
	var group_picker=meta.pool_body.get_node("TrainingGroup")
	check(group_picker.selected==0 and meta.pool_body.get_node("TrainingCard").item_count==5,"training defaults to the five universal cards")
	group_picker.item_selected.emit(1)
	check(meta.pool_body.get_node("TrainingCard").item_count==8,"dedicated training lists all eight specific cards")
	meta.pool_body.get_node("TrainingGroup").item_selected.emit(2)
	check(meta.pool_body.get_node("TrainingCard").get_item_metadata(0)=="ap_flank" and not candidates.has(GameData.get_skill("ap_flank")),"retired owned card accessible separately from draw pool")
	MetaProgress.currency[cur] = cost * (candidates.size()+1)
	MetaProgress.save()
	var previous := MetaProgress.balance(cur)
	var tmp := MetaProgress.SAVE_PATH + ".tmp"
	check(DirAccess.make_dir_absolute(tmp) == OK, "isolated failed-save fixture")
	check(MetaProgress.draw_skill().is_empty() and MetaProgress.balance(cur) == previous and MetaProgress.unlocked_skills == ["ap_flank"], "failed save leaves wallet and collection intact")
	DirAccess.remove_absolute(tmp)
	meta._refresh()
	meta.pool_body.find_child("DrawSkill",true,false).pressed.emit()
	check(MetaProgress.balance(cur) == previous-cost and MetaProgress.unlocked_skills.size() in [1,2] and not meta.pool_result.is_empty(), "pool button pays once and shows reward")
	MetaProgress.load_save()
	check(MetaProgress.unlocked_skills.has("ap_flank") and MetaProgress.unlocked_skills.size() in [1,2] and MetaProgress.balance(cur)==previous-cost,"old and new cards restored with paid balance")
	for card in candidates: MetaProgress.unlock_skill(card.id)
	var shards_before := int(MetaProgress.academy.get("card_shards",0))
	var full_balance := MetaProgress.balance(cur)
	check(MetaProgress.unlocked_skills.size()==candidates.size()+1 and not meta.pool_body.find_child("DrawSkill",true,false).disabled and not MetaProgress.draw_skill().is_empty() and MetaProgress.balance(cur)==full_balance-cost and int(MetaProgress.academy.card_shards)>=shards_before+2, "full pool turns duplicates into shards")
	check(MetaProgress.unit_effective_loadout("MTNK") == {"active":["ap_overdrive"], "passive":"ps_armor_plating"}, "once drawn previously configured W and passive work")
	meta.free()

func exercise_additional_input(mode: String, soldier, _peer, _tank) -> void:
	var hud = screen.hud
	var prefix := mode + ": "
	hud.select_prod_tab("naval")
	battle.clear_selection()
	battle._emit_selection()
	var distant = battle.spawn_unit("MTNK", "ally", Vector2(3000, 3000))
	var enemy = battle.spawn_unit("MTNK", "enemy", soldier.position)
	var miner = battle.spawn_unit("HARV", "ally", soldier.position)
	var engineer = battle.spawn_unit("ENGINEER", "ally", soldier.position)
	var ferry = battle.spawn_unit("LCRF", "ally", soldier.position)
	var passenger = battle.spawn_unit("E1", "ally", soldier.position)
	passenger.set_stowed(ferry)
	var carrier = battle.spawn_unit("CARRIER", "ally", distant.position)
	var fighter = battle.spawn_unit("HORNET", "ally", distant.position)
	fighter.logistics.carrier_owner = carrier
	get_window().focus_entered.emit()
	distant.order_move(Vector2(2850, 2900))
	var destination:Vector2=distant.move_target
	await key(KEY_F2)
	check([soldier,distant,carrier].all(func(u):return battle.selected_units.has(u)),prefix+"F2 selects armed units across the map, including the carrier")
	check([enemy,miner,engineer,ferry,passenger,fighter].all(func(u):return not battle.selected_units.has(u)),prefix+"army selection excludes enemy, economy, noncombatants, passengers and carrier aircraft")
	check(distant.has_move_order and distant.move_target==destination and battle.command_mode.is_empty(),prefix+"F2 preserves orders")
	battle.clear_selection()
	battle._emit_selection()
	battle.select_unit(distant, false)
	battle._emit_selection()
	hud.cmd_buttons.exclude.pressed.emit()
	battle.select_unit(soldier, true)
	await key(KEY_F4)
	for code in [KEY_F2, KEY_P]:
		await key(code)
		check(battle.selected_units.has(carrier) and not battle.selected_units.has(soldier) and not battle.selected_units.has(distant), prefix+"army skips marked units")
	await key(KEY_F3)
	check(battle.selected_units.size()==2 and battle.selected_units.has(distant) and battle.selected_units.has(soldier), prefix+"F3 recalls both marked units")
	await key(KEY_F4)
	await key(KEY_F2)
	check(battle.selected_units.has(distant) and battle.selected_units.has(soldier), prefix+"restore selection eligibility")
	battle.clear_selection()
	battle._emit_selection()
	var money: float = battle.funds
	for code in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_B, KEY_Z, KEY_V, KEY_F1, KEY_F8]:
		await key(code)
		check(hud.prod_tab == "naval" and battle.struct_queue.is_empty() and battle.funds == money,
			prefix + OS.get_keycode_string(code) + " cannot switch production tab or purchase")
	for id in hud.deck_tabs_btns:
		check(hud.deck_tabs_btns[id].text == hud._tab_label(id), prefix + id + " tab has no keyboard hint")
	hud.deck_tabs_btns["building"].pressed.emit()
	check(hud.prod_tab == "building", prefix + "mouse tab action remains available")
	hud.select_prod_tab("infantry")
	for code in [KEY_F1, KEY_F8]:
		await key(code)
		await key(code, true)
	check(battle.struct_queue.is_empty(), prefix + "function keys cannot order structures")
	for building in battle.buildings:
		if is_instance_valid(building) and building.side == "ally":
			check(building.production.is_empty(), prefix + building.building_id + " function keys cannot order units")
	battle.select_unit(soldier, false)
	battle._emit_selection()
	get_window().focus_entered.emit()
	check(hud._ability_btns.size() == 3, prefix + "three fixed active buttons plus passive")
	for i in 3:
		check(hud._ability_btns[i].tooltip_text.contains("[" + ["Q", "W", "E"][i] + "]"), prefix + "stable key tooltip")
	await key(KEY_E)
	check(soldier.is_deployed(), prefix + "E deploys GI")
	await key(KEY_E)
	check(not soldier.is_deployed(), prefix + "E undeploys GI")
	if mode == MatchRules.RA2:
		check(UnitSkillLayout.index(soldier, 0) == -1 and UnitSkillLayout.index(soldier, 1) == -1 and soldier.passive.is_empty(), prefix + "RA2 excludes extension Q W passive without shifting E")
	else:
		var q: Ability = soldier.ability_at(UnitSkillLayout.index(soldier, 0))
		var w: Ability = soldier.ability_at(UnitSkillLayout.index(soldier, 1))
		check(q.id == "ap_bayonet" and w.id == "ap_smoke", prefix + "innate Q and migrated first custom W")
		check(UnitSkillLayout.find(soldier, "ap_marker") < 0, prefix + "old extra active not installed")
		await key(KEY_Q)
		check(q.cd_left > 0 and q.active_left > 0 and soldier._ability_mult("attack_buff") > 1.0 and w.cd_left == 0, prefix + "Q actual buff only")
		var cd: float = q.cd_left
		await key(KEY_Q)
		check(q.cd_left == cd, prefix + "cooldown rejects recast")
		await key(KEY_W)
		check(w.cd_left > 0 and soldier._ability_mult("defense_buff") > 1.0, prefix + "W actual equipped buff")
		q.cd_left = 0
		w.cd_left = 0
		for code in [KEY_R, KEY_Z, KEY_V]:
			await key(code)
			await key(code, true)
		check(q.cd_left == 0 and w.cd_left == 0 and not soldier.is_deployed(), prefix + "removed keys cannot cast")
		var edit := LineEdit.new()
		hud.ability_box.add_child(edit)
		edit.grab_focus()
		await key(KEY_Q)
		check(q.cd_left == 0, prefix + "text input suppresses cast")
		edit.release_focus()
		edit.free()
		q.radius = 120
		await key(KEY_Q)
		check(battle.cast_slot == UnitSkillLayout.index(soldier, 0) and q.cd_left == 0, prefix + "mapped Q arms aim")
		await key(KEY_Q)
		check(battle.cast_slot == -1, prefix + "second mapped key cancels aim")
		q.radius = 0
		await key(KEY_Q, true)
		check(q.cd_left > 0, prefix + "Shift Q alias")
		q.cd_left = 0
		for modifier in ["ctrl_pressed", "alt_pressed", "meta_pressed", "echo"]:
			var event := InputEventKey.new()
			event.keycode = KEY_Q
			event.pressed = true
			event.set(modifier, true)
			stage.push_input(event, true)
			await get_tree().process_frame
			check(q.cd_left == 0, prefix + modifier + " does not cast")
		var peer = battle.spawn_unit("E1", "ally", Vector2(1650, 1600))
		peer.process_mode = Node.PROCESS_MODE_DISABLED
		peer.skills.reverse()
		var tank = battle.spawn_unit("MTNK", "ally", Vector2(1700, 1600))
		tank.process_mode = Node.PROCESS_MODE_DISABLED
		battle.select_unit(peer, true)
		battle.select_unit(tank, true)
		await key(KEY_Q)
		check(peer.ability_at(UnitSkillLayout.index(peer, 0)).cd_left > 0 and tank.ability_at(UnitSkillLayout.index(tank, 0)).cd_left == 0, prefix + "mixed group matches ID across reordered arrays")
		check(MetaProgress.unit_loadouts.E1.active.size() == 3, prefix + "legacy stored selection not overwritten on read")
	await check_layouts(mode)

func check_layouts(mode: String) -> void:
	var hud = screen.hud
	for row in [["GGI", "ggi_guard", "ggi_deploy"], ["SPY", "allied_infiltrate", "allied_disguise"], ["ENGINEER", "allied_engineer", ""], ["FV", "ap_overdrive", "allied_unload"], ["AMCV", "ap_repair_field", "allied_special"], ["SHAD", "ap_overdrive", "allied_special"], ["ORCA", "ap_overdrive", "allied_special"], ["MGTK", "ap_focus_fire", "allied_mirage"], ["CMIN", "ap_repair_field", "miner_auto_harvest"], ["CCOMAND", "allied_c4", "allied_chrono"], ["PTROOP", "allied_c4", "allied_release"], ["MTNK", "ap_smoke", ""]]:
		var unit = battle.spawn_unit(row[0], "ally", Vector2(1400, 1500))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		var innate: String = "" if row[1] == "allied_c4" or mode == MatchRules.RA2 and row[1].begins_with("ap_") else row[1]
		check(str(UnitSkillLayout.info(unit, 0).get("id", "")) == innate, mode + row[0] + " fixed Q")
		check(str(UnitSkillLayout.info(unit, 2).get("id", "")) == row[2], mode + row[0] + " fixed E")
		battle.select_unit(unit, false)
		battle._emit_selection()
		check(hud._ability_btns.size() == 3 and hud._ability_btns[2].disabled == (row[2] == ""), mode + row[0] + " E placeholder readiness")
		if row[0] in ["FV", "SHAD"]:
			# Real boarding and unload tick, with space isolated from other fixtures.
			unit.position = Vector2(2500, 2300)
			battle.water_rects = []
			battle.path_service.set_water([])
			var passenger = battle.spawn_unit("E1", "ally", unit.position + Vector2(24, 0))
			passenger.process_mode = Node.PROCESS_MODE_DISABLED
			check(passenger.logistics.request_board(unit), mode + row[0] + " boarding accepted")
			# SHAD descends using original height/climb, rather than the old 2s fixture.
			var landing_ticks := int(ceil(unit.flight.height / unit.flight.climb * 10.0)) + 20
			for tick in landing_ticks:
				unit.logistics.tick(0.1)
				passenger.logistics.tick(0.1)
				if passenger.embarked_in == unit: break
			check(passenger.embarked_in == unit, mode + row[0] + " passenger actually embarked")
			await key(KEY_E)
			check(unit.logistics.unloading, mode + row[0] + " E dispatches original unload")
			for tick in 20:
				unit.logistics.tick(0.1)
				if passenger.embarked_in == null: break
			check(passenger.embarked_in == null and passenger.visible, mode + row[0] + " E passenger emerges")
			passenger.position = Vector2(2700, 2300)
			unit.position = Vector2(2800, 2300)
		if row[0] == "GGI":
			await key(KEY_Q)
			await key(KEY_E)
			check(unit.hold_position and unit.is_deployed(), mode + " independent Q guard and E deploy")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-fixed-slots.png"))
	if mode == MatchRules.EXTENDED:
		await check_editor()

func skill_options(node: Node, found: Array) -> void:
	if node is OptionButton and node.has_meta("ids"): found.append(node)
	for child in node.get_children(): skill_options(child, found)

func check_editor() -> void:
	var meta = load("res://scenes/meta.tscn").instantiate()
	stage.add_child(meta)
	meta.set_process(false)
	meta._unit_sel = "MTNK"
	meta._set_page("units")
	meta._refresh()
	var options: Array = []
	skill_options(meta.unit_detail, options)
	check(options.size() == 2 and MetaProgress.unit_slot_counts() == {"active": 1, "passive": 1}, "editor only offers W and one passive")
	if options.size() == 2:
		var ids: Array = options[0].get_meta("ids")
		check(not ids.has("ap_smoke") and not ids.has("ap_deploy") and ids.has("ap_marker"), "editor excludes intrinsic Q and E deployment")
		options[0].item_selected.emit(ids.find("ap_marker"))
		check(MetaProgress.unit_effective_loadout("MTNK").active == ["ap_marker"], "real option callback equips W")
		MetaProgress.load_save()
		check(MetaProgress.unit_effective_loadout("MTNK").active == ["ap_marker"], "W persisted through real save read")
		var passive_ids: Array = options[1].get_meta("ids")
		check(passive_ids.has("ps_hollow_point"), "passive editor offers unlocked passive")
		options[1].item_selected.emit(passive_ids.find("ps_hollow_point"))
		MetaProgress.load_save()
		check(MetaProgress.unit_effective_loadout("MTNK").passive == "ps_hollow_point", "passive option persists")
		BattleRequest.freeze_combat_context()
		BattleRequest.combat_context.card_ranks={"ap_marker":2,"ps_hollow_point":3}
		var spawned = battle.spawn_unit("MTNK", "ally", Vector2(2400, 1800))
		spawned.process_mode = Node.PROCESS_MODE_DISABLED
		battle.select_unit(spawned,false)
		battle._emit_selection()
		check(screen.hud._ability_btns[1].tooltip_text.contains("Lv.2") and screen.hud._ability_btns[1].tooltip_text.contains("65%"),"W tooltip uses frozen rank and effect")
		check(spawned.passive_desc().contains("Lv.3") and spawned.passive_desc().contains("14.5%"),"passive tooltip uses frozen rank and effect")
		check(UnitSkillLayout.info(spawned, 0).id == "ap_smoke" and UnitSkillLayout.info(spawned, 1).id == "ap_marker" and spawned.passive.id == "ps_hollow_point", "new unit consumes edited W and passive while Q stays fixed")
	for pair in [["HTK","ps_barrage"],["R3MIRAGE","ap_decoy"]]:
		meta._unit_sel=pair[0]
		MetaProgress.unlock_skill(pair[1])
		meta._rebuild_unit_detail()
		options.clear()
		skill_options(meta.unit_detail,options)
		var picker:OptionButton=options[1 if pair[1]=="ps_barrage" else 0]
		var ix:int=picker.get_meta("ids").find(pair[1])
		check(ix>0 and picker.get_item_text(ix).begins_with("专属 · ") and picker.get_item_icon(ix)!=null,"exclusive card highlighted in list "+pair[1])
		picker.item_selected.emit(ix)
		options.clear()
		skill_options(meta.unit_detail,options)
		picker=options[1 if pair[1]=="ps_barrage" else 0]
		check(picker.text.begins_with("专属 · ") and picker.get_theme_color("font_color")==UiKit.COL_GOLD,"equipped exclusive remains highlighted "+pair[1])
		for i in picker.item_count:
			var id:String=picker.get_meta("ids")[i]
			if GameData.get_skill(id).get("allowed_units",[]).is_empty():
				check(picker.get_item_icon(i)==null and not picker.get_item_text(i).contains("专属"),"general and empty options stay neutral")
	meta._unit_sel="R3REAPER"
	meta._rebuild_unit_detail()
	var snapshot:=MetaProgress.to_dict().duplicate(true)
	var level:=MetaProgress.Academy.card_rank(MetaProgress,"ps_limiter")
	meta.unit_detail.find_child("Demo_ps_limiter",true,false).pressed.emit()
	var demo=meta.get_node("FactionCardDemos")
	check(demo.IDS[demo.selected]=="ps_limiter" and demo.rank==level and demo.actor_view.unit_id=="R3REAPER","refit opens current Reaper card and rank")
	demo.levels.item_selected.emit(3)
	check(demo.stage.preview_rank==3 and demo.stage.playing,"refit demo supports rank change")
	for button:Button in demo.find_children("*","Button",true,false):
		if button.text=="返回单位改造":button.pressed.emit()
	await get_tree().process_frame
	check(not meta.has_node("FactionCardDemos") and meta._page=="units" and meta._unit_sel=="R3REAPER" and MetaProgress.to_dict()==snapshot,"return preserves refit and profile")
	meta.exclusive_filter.button_pressed=true
	for row in meta.unit_list.get_children():
		check(meta.exclusive_cards_by_unit.has(row.get_meta("refit_unit")),"only compatible units and defenses in filtered roster")
	meta.unit_filter_opt.select(meta._faction_ids.find("soviet"))
	meta.unit_filter_opt.item_selected.emit(meta.unit_filter_opt.selected)
	check(meta.unit_list.get_children().any(func(row):return row.get_meta("refit_unit")=="NAFLAK") and not meta.unit_list.get_children().any(func(row):return row.get_meta("refit_unit")=="R3MIRAGE"),"exclusive and faction filters combine")
	meta._unit_sel="R3APOC"
	MetaProgress.unlocked_skills.erase("ap_twin")
	meta._rebuild_unit_detail()
	var train:Button=meta.unit_detail.find_child("Train_ap_twin",true,false)
	check(train.text=="去卡池获取" and meta.unit_detail.find_child("Growth_ap_twin",true,false).get_child_count()==4,"undrawn compatible card still offers growth and acquisition")
	train.pressed.emit()
	check(meta.pool_body.visible and meta.training_group=="专属" and meta.selected_card=="ap_twin","acquisition opens matching card")
	MetaProgress.unlock_skill("ap_twin")
	MetaProgress.academy.get_or_add("levels",{})["ap_twin"]=0
	MetaProgress.currency.cores=19
	meta._set_page("units")
	meta._refresh()
	train=meta.unit_detail.find_child("Train_ap_twin",true,false)
	check(train.disabled and train.text.contains("还差 41"),"core deficit is visible")
	if DisplayServer.get_name()!="headless":
		# The isolated battle camera and its HUD remain alive during editor checks.
		var menu_layer:=CanvasLayer.new()
		menu_layer.layer=128
		stage.add_child(menu_layer)
		meta.reparent(menu_layer,false)
		await get_tree().process_frame
		await get_tree().process_frame
		var chart=meta.unit_detail.find_child("Growth_ap_twin",true,false)
		meta.unit_detail.get_parent().ensure_control_visible(chart)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join("exclusive-training.png"))
	MetaProgress.currency.cores=450
	meta._refresh()
	for rank in 3:
		train=meta.unit_detail.find_child("Train_ap_twin",true,false)
		train.pressed.emit()
		check(meta._page=="units" and MetaProgress.Academy.card_rank(MetaProgress,"ap_twin")==rank+1,"inline upgrade on unit page "+str(rank+1))
	train=meta.unit_detail.find_child("Train_ap_twin",true,false)
	check(train.disabled and train.text=="已满级" and MetaProgress.balance("cores")==0,"all three upgrade costs and max rank")
	check(not MetaProgress.set_unit_skill("MTNK", "active", 1, "ap_marker"), "removed active slot rejected")
	check(not MetaProgress.set_unit_skill("MTNK", "active", 0, "ap_smoke"), "cannot equip duplicate intrinsic Q")
	check(not MetaProgress.set_unit_skill("MTNK", "active", 0, "ps_armor_plating"), "passive cannot enter W")
	check(not MetaProgress.set_unit_skill("MTNK", "passive", 0, "ap_marker"), "active cannot enter passive")
	check(not MetaProgress.set_unit_skill("MTNK", "active", 0, "ap_deploy"), "deployment not equippable as W")
	meta.free()
