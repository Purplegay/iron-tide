extends "res://tests/progression_expansion_2_aircraft_regression.gd"
const Editor=preload("res://scripts/admin/progression_editor.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	var model=GameData.progression_tuning
	check(model.records.size()>120,"catalog includes ordinary/hero skills and configured unit talents",model.records.size())
	for key:String in model.records:check(model.validate(key,model.values(key)).is_empty(),"original values are valid "+key)
	var editor:=Editor.new();editor.embedded=true;add_child(editor)
	await description_shortcuts(editor)
	var key:="skill/ps_burning_payload"
	editor.select_key(key)
	editor.inputs["values/hits/3"].value=4
	await get_tree().process_frame
	check(GameData.get_skill("ps_burning_payload").values.hits[3]==2,"typing stays in draft until explicit apply")
	editor.find_child("ApplyTuning",true,false).pressed.emit()
	check(GameData.get_skill("ps_burning_payload").values.hits[3]==4 and model.patches.get(key,{}).get("values/hits/3")==4,"real Apply button updates selected rank only",[editor.status.text,editor.drafts[key]])
	check(MetaProgress.Academy.skill_description(GameData.get_skill("ps_burning_payload"),3).contains("累计4次"),"live description follows edited count")
	check(not model.apply(key,{"values/hits/3":1.5}).is_empty() and not model.apply(key,{"values/hits/3":0}).is_empty(),"fractional or zero positive hit threshold is rejected")
	check(not model.apply(key,{"values/damage/3":NAN}).is_empty() and not model.apply(key,{"id":2}).is_empty(),"nonfinite and structural edits rejected")
	check(GameData.get_skill("ps_burning_payload").values.hits[3]==4,"invalid transaction leaves previous config intact")
	editor.select_key("talent/JUMPJET/hover_sighting");editor.inputs["values/damage/3"].value=.33
	editor.select_key(key);check(editor.inputs["values/hits/3"].value==4,"navigation preserves drafts")
	editor.select_key("talent/JUMPJET/hover_sighting");editor.apply_current()
	check(is_equal_approx(MetaProgress.talent_options("JUMPJET").hover_sighting.values.damage[3],.33),"talent editor writes actual gameplay definition")
	check(MetaProgress.talent_options("JUMPJET").hover_sighting.ranks[2].value==33 and not editor.inputs.has("base"),"talent rank labels follow gameplay values without editable display-only duplicates")
	editor.save_applied()
	check(FileAccess.file_exists(model.STORE),"Save button creates local override file")
	model.patches.clear();model.loaded=false;GameData.reload()
	check(GameData.get_skill("ps_burning_payload").values.hits[3]==4 and is_equal_approx(MetaProgress.talent_options("JUMPJET").hover_sighting.values.damage[3],.33),"fresh disk load restores skill and talent edits")
	check(model.save().is_empty() and FileAccess.file_exists(model.STORE+".bak"),"repeated save safely replaces file with backup")
	var saved_bytes:=FileAccess.get_file_as_bytes(model.STORE)
	var temporary:=ProjectSettings.globalize_path(model.STORE+".tmp")
	DirAccess.make_dir_absolute(temporary)
	check(not model.save().is_empty() and FileAccess.get_file_as_bytes(model.STORE)==saved_bytes,"failed temporary write preserves last saved configuration")
	DirAccess.remove_absolute(temporary)
	editor.reset_current();check(is_equal_approx(MetaProgress.talent_options("JUMPJET").hover_sighting.values.damage[3],.2),"reset restores shipped talent values")
	editor.select_key(key);editor.reset_current();model.save()
	model.loaded=false;GameData.reload();check(GameData.get_skill("ps_burning_payload").values.hits[3]==2,"reset persists across reload")
	editor.search.text="燃烧挂载";editor.refresh_list();check(editor.listed.has(key) and editor.listed.has("mechanic/ps_burning_payload"),"Chinese search exposes card and its fixed mechanics")
	editor.search.text="no-such-card-xyz";editor.refresh_list();check(editor.selected.is_empty() and editor.inputs.is_empty(),"empty results cannot mutate previous selection")
	editor.free()
	await live_cooldown()
	await live_range()
	await live_count()
	await live_talent()
	await live_passive()
	var console=preload("res://scripts/admin/gm_console.gd").new();console.embed_mode=true;add_child(console)
	console.find_child("OpenProgressionEditor",true,false).pressed.emit()
	check(console.has_node("ProgressionEditor"),"GM button opens in-game editor")
	console.find_child("OpenProgressionEditor",true,false).pressed.emit()
	check(console.get_children().filter(func(node):return node.name=="ProgressionEditor").size()==1,"reopening does not duplicate editor")
	if DisplayServer.get_name()!="headless":
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var opened=console.get_node("ProgressionEditor")
		check(opened.selector.size.x>=285 and opened.form.size.x>=485 and opened.size.x<=get_viewport().get_visible_rect().size.x,"editor list and numeric form fit viewport",[opened.selector.size,opened.form.size,opened.size])
	console.free();await get_tree().process_frame
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func description_shortcuts(editor) -> void:
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size=Vector2(1280,720)
	var model=GameData.progression_tuning
	var unchanged:Dictionary=model.patches.duplicate(true)
	for key:String in model.records:
		editor.select_key(key)
		var valid:=true
		for related:String in editor.shown:
			for target:Dictionary in editor.parameter_targets(related):
				valid=valid and editor.inputs.has(target.input)
		check(valid,"description targets exist in selected form "+key)
	editor.select_key("skill/ap_escort_water")
	for frame in 6:await get_tree().process_frame
	var targets:Array=editor.parameter_targets(editor.selected)
	check(targets.any(func(target):return target.input=="values/relay_duration/0") and not targets.any(func(target):return target.input=="values/relay_duration/3"),"ranked shortcut points to initial level, not each upgrade")
	check(editor.detail.get_parsed_text().contains("余波护盾持续秒数 · Lv.0"),"description shows named initial-level shortcut")
	editor.inputs["values/defense/3"].value=.41
	editor.detail.meta_clicked.emit("values/relay_duration/0")
	await get_tree().process_frame
	var spin:SpinBox=editor.inputs["values/relay_duration/0"]
	check(spin.get_line_edit().has_focus() and spin.get_line_edit().has_selection(),"clicking description focuses and selects target numeric value")
	check(editor.scroll.scroll_vertical>0 and editor.scroll.get_global_rect().encloses(spin.get_global_rect()),"description click scrolls distant initial-level input into view",[editor.scroll.scroll_vertical,spin.get_global_rect(),editor.scroll.get_global_rect()])
	check(editor.drafts[editor.selected]["values/defense/3"]==.41 and model.patches==unchanged,"jump preserves draft without applying or resetting values")
	editor.drafts.erase(editor.selected)
	editor.select_key("skill/ap_furnace_bastion")
	for frame in 6:await get_tree().process_frame
	var fixed_path:="mechanic/ap_furnace_bastion|values/shield_seconds"
	check(editor.inputs.has(fixed_path),"associated fixed mechanism has exact target")
	if editor.inputs.has(fixed_path):
		editor.detail.meta_clicked.emit(fixed_path)
		check(editor.inputs[fixed_path].get_line_edit().has_focus(),"fixed mechanism link focuses its own field")
	editor.select_key("talent/JUMPJET/hover_sighting")
	editor.detail.meta_clicked.emit("values/damage/0")
	check(editor.inputs["values/damage/0"].get_line_edit().has_focus(),"talent shortcut focuses initial level")
	editor.select_key("hero/TANY/command")
	editor.detail.meta_clicked.emit("values/split_damage")
	check(editor.inputs["values/split_damage"].get_line_edit().has_focus(),"hero ability retains its actual unlock-level field")
	var focus:Control=get_viewport().gui_get_focus_owner()
	editor.detail.meta_clicked.emit("missing/field")
	check(get_viewport().gui_get_focus_owner()==focus,"unknown metadata cannot focus a different field")

func live_cooldown() -> void:
	prepare_aircraft(3,Aircraft.BURN,false)
	var ship:=make("DEST","ally",Vector2(1100,1100));var ab:=ability(ship,"ap_escort_water");ab.cd_left=12;ab.active_left=2
	var model=GameData.progression_tuning
	check(model.apply("skill/ap_escort_water",{"cooldown_by_rank/3":7,"values/defense/3":.4}).is_empty(),"apply live cooldown and defense")
	check(ab.cooldown==7 and ab.cd_left==12 and ab.active_left==2,"existing ability updates without resetting remaining cooldown or effect timer",[ab.cooldown,ab.cd_left])
	ab.cd_left=0;check(ship.use_ability(ship.skills.find(ab)),"real skill casts after edit")
	check(is_equal_approx(preload("res://scripts/units/expansion_2_naval.gd").guard(ship),.4) and ab.cd_left>0 and ab.cd_left<=7,"real cast consumes new defense and cooldown")
	model.apply("skill/ap_escort_water",{})
	await finish()

func live_count() -> void:
	prepare_aircraft(3,Aircraft.BURN,false)
	var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	var model=GameData.progression_tuning
	model.apply("skill/ps_burning_payload",{"values/hits/3":1,"values/damage/3":.4})
	air_shot(plane,target);fly_missiles(plane)
	check(battle.allied_state.get(Aircraft.FIELDS,[]).size()==1,"edited count changes actual ordinary missile trigger")
	if battle.allied_state.has(Aircraft.FIELDS):check(is_equal_approx(battle.allied_state[Aircraft.FIELDS][0].weapon.damage,plane._active_weapon().damage*.2),"actual damage snapshot consumes edited coefficient")
	model.apply("skill/ps_burning_payload",{})
	await finish()

func live_range() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1100))
	var near:=make("HYD","ally",Vector2(1140,1100));var far:=make("AEGIS","ally",Vector2(1240,1100))
	var third:=make("DRED","ally",Vector2(1250,1100))
	check(Naval.companions(ship)==[near],"original two-cell range excludes distant ships")
	var model=GameData.progression_tuning
	model.apply("skill/ap_escort_water",{"values/radius/3":3,"values/targets/3":3,"values/duration/3":6})
	check(Naval.companions(ship)==[near,far,third],"edited radius and recipient count change real selection")
	var ab:=ability(ship,"ap_escort_water");ship.use_ability(ship.skills.find(ab))
	check(Naval.state(far).water_guards[0].left==6,"edited duration stored on actual protected ship")
	model.apply("skill/ap_escort_water",{})
	check(Naval.state(far).water_guards[0].left==6 and Naval.companions(ship)==[near],"reset affects next casts while active cast keeps its duration snapshot")
	await finish()

func live_talent() -> void:
	setup(3);BattleRequest.combat_context.unit_talents.JUMPJET={"hover_sighting":3}
	var gun:=make("JUMPJET","ally",Vector2(1100,1100))
	var model=GameData.progression_tuning
	model.apply("talent/JUMPJET/hover_sighting",{"values/damage/3":.33})
	X.tick(gun,2)
	var packet:Dictionary={};preload("res://scripts/units/expansion_2_air.gd").shot(gun,packet)
	check(is_equal_approx(packet.get("expansion_hover_damage",0),.33),"existing unit consumes edited talent on next shot")
	model.apply("talent/JUMPJET/hover_sighting",{})
	await finish()

func live_passive() -> void:
	setup(0)
	BattleRequest.combat_context.loadouts.E1={"active":[],"passive":"ps_hollow_point"}
	var tank:=make("E1","ally",Vector2(1100,1100))
	check(tank.passive.get("id")=="ps_hollow_point","passive fixture uses eligible infantry")
	var original:float=tank.bonuses.attack_bonus
	var model=GameData.progression_tuning
	model.apply("skill/ps_hollow_point",{"value":.3})
	var changed:float=tank.bonuses.attack_bonus
	check(changed>original,"editing ordinary passive updates existing unit bonuses")
	model.apply("skill/ps_hollow_point",{"value":.3})
	check(is_equal_approx(tank.bonuses.attack_bonus,changed),"repeat apply does not compound passive bonuses")
	model.apply("skill/ps_hollow_point",{})
	check(is_equal_approx(tank.bonuses.attack_bonus,original),"reset restores existing unit passive bonus")
	await finish()
