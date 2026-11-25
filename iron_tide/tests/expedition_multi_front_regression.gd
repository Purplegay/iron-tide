extends "res://tests/base_recovery_regression.gd"
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Field=preload("res://scripts/expedition/field_operations.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	check(Expedition.start("美国","",7),"start isolated expedition")
	var run:Dictionary=Expedition.state.duplicate(true)
	run.stage=8;run.phase="ready";run.routes=Campaign.routes(run)
	check(run.routes[0].enemy_count==1 and run.routes[1].enemy_count==2,"one enemy or two enemy routes are optional")
	run.stage=17;run.routes=Campaign.routes(run)
	check(run.routes[1].enemy_count==2,"ordinary late stage caps the challenge at two enemies")
	run.stage=19;run.routes=Campaign.routes(run)
	check(run.routes[0].enemy_count==1 and run.routes[1].enemy_count==3,"later route permits three hostile houses")
	for stage:int in [26,27,28,29,30]:
		run.stage=stage;run.routes=Campaign.routes(run)
		check(run.routes.all(func(route):return route.enemy_count==1 and route.support_contacts.is_empty()),"no added enemies or allies in brutal three stage "+str(stage))
	run.stage=8;run.phase="ready";run.field_contacts=[Field.contract(6,int(run.seed))]
	# Contract stage 8 is saved from a successful rescue two battles earlier.
	run.field_contacts[0].stage=8
	run.routes=Campaign.routes(run)
	check(Expedition.commit(run),"earned character contract saves")
	var loaded:=Expedition.read_file(Expedition.FILE)
	check(loaded.field_contacts[0].name==run.field_contacts[0].name,"character story survives disk save")
	check(Expedition.launch(1),"launch multi-front expedition with earned ally")
	check(BattleRequest.house_teams.size()==4 and BattleRequest.friendly("ally","ai3") and not BattleRequest.friendly("ally","ai2"),"launch has two real enemies and one real allied house")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	check(battle!=null,"real expedition battle loads")
	if battle==null:get_tree().quit(1);return
	check(battle.house_controllers.size()==3,"all three computer houses have independent AI")
	var deployed=screen.expedition_runtime.field_ops
	var site:Vector2=deployed.data.objectives[0].position
	check(deployed.safe_rescue_spawn(site),"opening rescue site clears hostile formations")
	for building in battle.buildings:
		if building.is_hq and not BattleRequest.friendly("ally",building.side):
			check(building.position.distance_to(site)>=1300,"rescue is outside each hostile starting base")
			check(not deployed.safe_rescue_spawn(building.position+Vector2(475,0)),"reject near-HQ opening seen in stage eleven")
	var ally:Dictionary=run.field_contacts[0]
	var offered:Dictionary=deployed.data.objectives[0].person
	check(deployed.data.get("met_contacts", []) == [ally.id], "only the allied commander who actually reported for duty counts as met")
	MetaProgress.load_save()
	check(MetaProgress.contact_transcripts[offered.id].promise.has(Field.Stories.mission_text(offered).promise),"rescue offer is recorded at mission setup")
	var radio=screen.hud.field_radio
	var minimap=screen.hud.minimap
	var bases:Array=deployed.support_bases()
	check(bases.size()==1 and bases[0].contact_id==ally.id and bases[0].title.contains(Field.Stories.PEOPLE[ally.id].base),"returning commander has a named base")
	var markers:Array=minimap.objective_marks()
	check(markers.any(func(m):return m.status=="base" and m.contact_id==ally.id and m.title==bases[0].title),"minimap base marker belongs to the returning ally")
	check(minimap._get_tooltip(Vector2.ZERO).contains(ally.name),"transmitting radar identifies the speaker")
	check(markers.any(func(m):return m.key=="field0" and m.get("contact_id","")==deployed.data.objectives[0].person.id),"active rescue maps to its own portrait")
	check(minimap.radio_contact_id==ally.id,"radar shows the speaking commander")
	var key:String=MetaProgress.contact_archive[ally.id].keys().back()
	var chapter:Dictionary=Field.Stories.PEOPLE[ally.id].chapters[key]
	check(is_instance_valid(radio) and radio.body.text==chapter.lines[0] and radio.speaker.text==ally.name,"actual allied house starts its personal chapter")
	MetaProgress.load_save()
	check(MetaProgress.contact_archive[ally.id][key].run==run.id,"chapter archived on disk at arrival")
	check(MetaProgress.contact_archive[ally.id][key].lines==chapter.lines,"arrival chapter retains both paragraphs verbatim")
	check(battle.ai_decisions("ai3").get("preferred_recruit")==Field.Stories.PEOPLE[ally.id].unit and not battle.ai_decisions("ai2").has("preferred_recruit"),"only returning ally uses its signature recruitment preference")
	check(screen.hud.mode_label.tooltip_text.contains(ally.name.get_slice(" · ",0)),"allied commander appears in battle roster")
	check(Expedition.checkpoint(battle),"capture allied greeting in checkpoint")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reopen saved expedition with ally")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	check(not is_instance_valid(screen.hud.field_radio) and battle.allied_state.expedition_field_ops.greeted.get("ai3",false),"restoring greeted ally does not replay opening transmission")
	var ops=screen.expedition_runtime.field_ops
	check(ops.support_bases().size()==1 and screen.hud.minimap.radio_contact_id.is_empty(),"base label returns on load while radio is idle")
	var idle_radar=screen.hud.minimap
	check(idle_radar.objective_marks().any(func(m):return m.status=="base" and m.contact_id==ally.id and idle_radar._get_tooltip(m.local).contains(bases[0].title)),"idle radar shows the allied base tooltip")
	ops.tick(17)
	check(not is_instance_valid(screen.hud.field_radio),"remaining paragraph waits after load")
	ops.tick(1)
	check(screen.hud.field_radio.body.text==chapter.lines[1] and not ops.data.has("story_followups"),"second paragraph resumes and is consumed once")
	check(screen.hud.minimap.radio_contact_id==ally.id,"resumed transmission restores speaker portrait")
	ops.data.greeted.clear()
	ops.greet_from_support()
	MetaProgress.load_save()
	check(MetaProgress.contact_transcripts[ally.id].arrival==[Field.Stories.PEOPLE[ally.id].arrival] and MetaProgress.contact_archive[ally.id].size()==1,"non-chapter support greeting persisted without consuming another chapter")
	for side:String in ["enemy","ai2","ai3"]:
		check(battle.buildings.any(func(building):return building.side==side and building.is_hq),"independent headquarters "+side)
	check(battle.allied_state.has("expedition_field_ops") and battle.allied_state.expedition_field_ops.objectives.size()==1,"real battle creates optional battlefield objectives")
	check(battle.allied_state.expedition_task.progress==0,"new main task begins at zero")
	var field:Dictionary=battle.allied_state.expedition_field_ops
	check(field.objectives[0].person.has("bio") and field.objectives[0].person.stage>8,"rescue has biography and future chapter")
	var actual_field=Field.new();battle.add_child(actual_field);actual_field.setup(battle,true)
	check(actual_field.valid_site(field.objectives[0].position,[]),"rescue has a valid site")
	# Older checkpoints can contain a second objective.
	var first_position:Vector2=field.objectives[0].position
	field.objectives.append({"id":"field1","kind":"cache","position":first_position,"progress":13.0,"done":false,"failed":false,"reward":50})
	actual_field.repair_overlapping_sites()
	check(field.objectives[1].position.distance_to(first_position)>=Field.POINT_GAP and field.objectives[1].progress==13.0,"legacy overlap repaired without resetting progress")
	check(not actual_field.valid_site(battle.player_start(),[]),"pathfinding fallback to home is rejected")
	check(battle.units.any(func(unit):return unit.special.get("expedition_contact","")=="field0"),"named rescue target exists as actual battlefield NPC")
	var npc=null
	for unit in battle.units:
		if unit.special.get("expedition_contact","")=="field0":npc=unit;break
	if npc!=null:
		check(npc.side=="ally" and BattleRequest.friendly("ally",npc.side),"rescued engineer or civilian is friendly")
		AlliedAbilities.change_side(npc,"neutral")
		Field.repair_npc_sides(battle)
		check(npc.side=="ally" and npc.is_in_group("allies") and not npc.is_in_group("enemies"),"legacy neutral mission NPC repaired with targeting groups")
		npc.hp=0;npc._dead=true
	actual_field.tick(1.0)
	check(field.objectives[0].get("failed",false) and field.contacts.is_empty(),"dead contact cancels promised support")
	actual_field.complete(field.objectives[0])
	check(field.contacts.is_empty(),"failed rescue cannot grant character")
	actual_field.free()
	for node in screen.find_children("*","Node",true,false):
		if node.get_script()!=load("res://scripts/expedition/runtime.gd"):continue
		node.refresh_status()
		check(not node.hud_details.visible and node.side_status.is_visible_in_tree() and node.side_status.text.contains("救援：失败"),"failed rescue stays readable in compact HUD")
		check(node.side_status.get_theme_color("font_color")==Color.LIGHT_SKY_BLUE and node.status.get_theme_color("font_color")==UiKit.COL_GOLD and not node.status.text.contains("支线"),"compact HUD separates light-blue side missions from gold main objective")
		check(node.hud_detail_status.get_theme_color("font_color")==UiKit.COL_SIDE_MISSION,"expanded side mission HUD uses light blue")
		field.objectives[1].done=true
		node.hud_details.show();node.refresh_status()
		check(node.hud_detail_status.text.contains("✓ "),"real HUD shows completion checkmark")
		if DisplayServer.get_name()!="headless":
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("friendly-npc-side-tasks.png"))
	var before:=int(Expedition.state.supplies)
	field.supplies=35;field.contacts=[Field.contract(8,7)]
	check(Expedition.settle(battle,true),"multi-front victory settles")
	var report:Dictionary=Expedition.state.battle_reports[-1]
	check(report.reward_breakdown["多线作战"]==60 and report.reward_breakdown["战场支线与实验室"]==35,"multi-front and rescue rewards are explicit")
	check(Expedition.state.field_contacts.size()==2,"new rescue contract persisted independently")
	check(int(Expedition.state.supplies)>=before+95,"multi-front optional rewards paid")
	check(not Expedition.settle(battle,true),"repeated victory cannot duplicate contacts or rewards")
	await finish()
	check(Expedition.start("苏俄","",19) and Expedition.choose(0),"open another expedition camp")
	MetaProgress.load_save()
	var camp=load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	var history_tab=camp.body.find_children("*","Button",true,false).filter(func(b):return b.text=="藏品与记录")
	check(history_tab.size()==1,"history tab exists in a new expedition")
	if not history_tab.is_empty():history_tab[0].pressed.emit()
	var entries:Array=camp.body.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with(ally.name))
	check(entries.size()==1,"new camp retains previous commander's archive")
	if entries.size()==1:
		entries[0].button_pressed=true
		check(camp.body.find_children("*","Label",true,false).any(func(l):return l.is_visible_in_tree() and l.text.contains(chapter.lines[1])),"camp archive reveals the chapter transcript")
	camp.free()
	FileAccess.open(output_dir.path_join("multi-front.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("MULTI FRONT checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
