extends "res://tests/base_recovery_regression.gd"
const Field=preload("res://scripts/expedition/field_operations.gd")
const Tasks=preload("res://scripts/expedition/objectives.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Tactics=preload("res://scripts/expedition/elite_tactics.gd")

func check_story_pacing() -> void:
	var catalog:Dictionary=Field.Stories.PEOPLE
	var total:=0
	var lines:={}
	for id:String in catalog:
		var profile:Dictionary=catalog[id]
		check(profile.chapters.size()==8,"eight oral histories for "+id)
		var titles:={}
		for chapter:Dictionary in profile.chapters.values():
			check(not chapter.title.is_empty() and not titles.has(chapter.title),"distinct chapter title for "+id)
			titles[chapter.title]=true
			check(chapter.lines.size()==2,"two transmissions in "+chapter.title)
			total+=1
			for line:String in chapter.lines:
				check(line.length()>=38 and not lines.has(line),"unique authored transmission "+chapter.title)
				lines[line]=true
	check(catalog.size()>=13 and total==8*catalog.size(),"complete commander anthology")
	var archive:={}
	var previous_archive:=MetaProgress.contact_archive
	MetaProgress.contact_archive=archive
	var heard:=0
	for run_index in ceili(float(total)/Field.Stories.CHAPTERS_PER_RUN):
		var run_id:="run%d"%run_index
		var history:Array=[]
		var this_run:=0
		for stage in range(1,26):
			for person:Dictionary in history:
				if person.stage!=stage:continue
				var key:=Field.Stories.available_chapter(person.id,run_id,stage,archive)
				if key.is_empty():continue
				archive.get_or_add(person.id,{})[key]={"stage":stage,"run":run_id}
				heard+=1
				this_run+=1
				check(Field.Stories.available_chapter(person.id,run_id,stage,archive).is_empty(),"reload cannot advance an appearance twice")
			var contract:=Field.contract(stage,781+run_index,history)
			if contract.stage>0:
				check(not history.any(func(p):return p.stage==contract.stage),"contracts reserve separate support appearances")
				history.append(contract)
		check(this_run==mini(Field.Stories.CHAPTERS_PER_RUN,total-run_index*Field.Stories.CHAPTERS_PER_RUN),"successful support runs keep the intended reading pace "+run_id)
	check(heard==total,"all authored chapters reachable")
	MetaProgress.contact_archive=previous_archive

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	check(Field.support_stage(3)==6 and Field.support_stage(5)==7,"support avoids boss stage")
	check(Field.support_stage(24)==0,"no promised reinforcement after chapter 25")
	check_story_pacing()
	var run:Dictionary={"seed":7,"stage":8,"history":[],"active_roster":["E1"],"field_contacts":[{"id":"lin","name":"林岚","stage":8,"country":"美国"}]}
	var routes:=Campaign.routes(run)
	check(routes.size()==2 and routes[1].enemy_count>=2 and routes[1].support_contacts.size()==1,"earned contact enables two hostile houses plus independent ally")
	check(routes[1].get("front_bonus",0)==60,"second hostile grants visible multi-front bonus")
	check(routes[1].size>=3200,"multi-house map scales for bases")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","enemy_country":"苏俄","map_layout":routes[1].map,"opponents":2,"houses":[{"country":"美国","team":1},{"country":"苏俄","team":2,"difficulty":2},{"country":"苏俄","team":2,"difficulty":2},{"country":"美国","team":1,"difficulty":1}]})
	check(BattleRequest.house_teams.size()==4 and BattleRequest.friendly("ally","ai3") and BattleRequest.friendly("enemy","ai2"),"two enemies and a separate allied AI share diplomacy teams")
	var contacts:Array=run.field_contacts.duplicate(true)
	check(contacts==run.field_contacts,"campaign contact profile is save-safe plain data")
	start(MatchRules.EXTENDED)
	var field=Field.new();battle.add_child(field);field.set_process(false)
	field.world=battle
	field.transmission.connect(screen.hud.show_field_transmission)
	var contact:=Field.contract(8,7)
	field.data={"objectives":[{"id":"field0","kind":"contact","position":Vector2(1700,1650),"progress":0.0,"done":false,"person":contact,"reward":35}],"supplies":0,"contacts":[]}
	battle.allied_state.expedition_field_ops=field.data
	var objective=Tasks.new();battle.add_child(objective);objective.set_process(false);objective.world=battle
	objective.state={"kind":"capture","stage":7,"elapsed":0.0,"progress":0.0,"phase":0,"outcome":0,"points":[Vector2.ZERO,Vector2(1700,1700),Vector2(2500,2500)],"targets":[],"arrived":[],"waves":0,"next_wave":45.0}
	objective.field_ops=field
	var minimap=screen.hud.minimap
	minimap.objectives=objective
	var marks:Array=minimap.objective_marks()
	check(marks.size()==2 and marks[0].key=="point1" and marks[0].color==Color("#ffda59"),"active main objective is gold")
	check(marks.size()==2 and marks[1].key=="field0" and marks[1].color==UiKit.COL_SIDE_MISSION,"active optional objective is blue")
	check(minimap._get_tooltip(marks[1].local).contains("支线 · "+field.title(field.data.objectives[0])),"optional marker tooltip identifies side mission")
	field.data.objectives[0].progress=19.0
	check(field.countdown_text(field.data.objectives[0])=="剩余 1 秒 · 95%","world objective countdown uses remaining seconds and percent")
	var escort=battle.spawn_unit("E1","ally",Vector2(1700,1650))
	if DisplayServer.get_name()!="headless":
		battle.camera.position=Vector2(1700,1650);battle.camera.zoom=Iso.cam_zoom(1.5)
		field.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("field-countdown.png"))
	field.tick(1.0)
	check(minimap.objective_marks()[1].color==UiKit.COL_SIDE_MISSION,"completed optional objective keeps the side mission color")
	check(field.data.contacts.size()==1 and field.data.supplies==35,"field contact rescue yields unique character and bounty")
	check(field.data.contacts[0].name==contact.name and field.data.contacts[0].stage==contact.stage,"contact story and bound chapter persist")
	var radio=screen.hud.field_radio
	var rescue_text := Field.Stories.rescue_line(contact)
	var turns := rescue_text.split("\n", false)
	radio._playback.pause() # The test advances reading time explicitly across layout frames.
	check(is_instance_valid(radio) and radio.visible and radio.speaker.text==contact.name and radio.body.text==turns[0],"rescue opens first speaker turn on the real HUD")
	MetaProgress.load_save()
	check(MetaProgress.contact_transcripts[contact.id].rescue==[rescue_text] and MetaProgress.contact_transcripts[contact.id].rescued,"exact full rescue transmission survives disk reload")
	if is_instance_valid(radio):
		check(screen.hud.minimap.radio_contact_id==contact.id,"rescue radio portrait matches the contact")
		var face:TextureRect=minimap._radio_portrait
		var frame:ReferenceRect=minimap._radio_frame
		check(face.visible and face.texture==minimap.Contacts.portrait(contact.id) and not minimap._camera_layer.visible,"radio replaces radar and its camera outline")
		check(face.get_global_rect()==minimap.get_global_rect() and frame.get_global_rect()==face.get_global_rect().grow(-2),"portrait fills the whole radar with the pulse inside its edges")
		var destination:Vector2 = Vector2.ONE * battle.map_size * 0.65
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = minimap._world_to_minimap() * destination
		battle.center_on(destination)
		var expected_camera:Vector2 = battle.camera.position
		battle.center_on(Vector2.ZERO)
		var before_click:Vector2 = battle.camera.position
		minimap._gui_input(press)
		check(not before_click.is_equal_approx(expected_camera) and battle.camera.position.is_equal_approx(expected_camera) and minimap._dragging,"clicking the radio portrait navigates to the projected map point")
		var motion := InputEventMouseMotion.new()
		motion.position = minimap._world_to_minimap() * (destination * 0.6)
		minimap._gui_input(motion)
		check(not battle.camera.position.is_equal_approx(expected_camera) and face.visible,"dragging across the portrait pans while the speaker remains visible")
		press.pressed = false
		minimap._gui_input(press)
		check(not minimap._dragging,"releasing on the portrait ends navigation")
		var crop:Vector2=face.material.get_shader_parameter("crop")
		check(is_equal_approx(crop.x,1.0) and crop.y<1 and float(face.material.get_shader_parameter("lift"))>0,"wide radar crops the source portrait with headroom")
		minimap._process(minimap.RADIO_PULSE_SECONDS*0.5*Engine.time_scale)
		check(frame.modulate.a<0.4 and face.modulate.a==1.0,"frame dims while the portrait stays steady")
		minimap._process(minimap.RADIO_PULSE_SECONDS*0.5*Engine.time_scale)
		check(frame.modulate.a>0.99,"frame brightens again")
		check(radio.mouse_filter==Control.MOUSE_FILTER_IGNORE and radio.body.mouse_filter==Control.MOUSE_FILTER_IGNORE,"radio leaves battlefield input available")
		# Container layout is deferred when the first transmission creates the radio dock.
		for layout_pass in 2:await get_tree().process_frame
		check(radio.get_global_rect().position.y>=screen.hud._topbar.get_global_rect().end.y and radio.get_global_rect().end.x<=screen.hud.production_toggle.get_global_rect().position.x,"radio clears top bar and production dock")
	field.complete(field.data.objectives[0]);check(field.data.contacts.size()==1 and field.data.supplies==35 and field.data.get("kits",0)==1,"checkpoint retry cannot claim same contact or repair kit twice")
	check(radio.waiting.size()==turns.size()-1,"completed rescue cannot enqueue the same speech again",radio.waiting)
	var next_message:String=Field.Stories.PEOPLE.lin.chapters.visor.lines[0]
	screen.hud.show_field_transmission(Field.Stories.PEOPLE.lin.name,next_message,"lin")
	check(minimap.radio_contact_id==contact.id,"queued speaker does not replace the current face")
	check(radio.body.visible_ratio==1.0,"the first message is fully revealed on arrival")
	var reading_time:=maxf(8.0,radio.body.text.length()/5.0)
	radio._playback.custom_step(reading_time-0.25)
	check(radio.visible and radio.modulate.a==1.0 and minimap.radio_contact_id==contact.id,"first message and portrait remain for the full reading interval")
	radio._playback.custom_step(1.0)
	for turn in turns.slice(1):
		var separator := turn.find("：")
		check(radio.body.text==turn.substr(separator+1) and radio.speaker.text==turn.left(separator),"rescue conversation plays each authored turn in order")
		radio._playback.custom_step(maxf(8.0,radio.body.text.length()/5.0)+1.0)
	check(minimap.radio_contact_id=="lin" and radio.speaker.text==Field.Stories.PEOPLE.lin.name and minimap._radio_portrait.texture==minimap.Contacts.portrait("lin"),"next message changes speaker and radar face together")
	check(radio.body.text==next_message and radio.body.visible_ratio==1.0,"queued paragraph appears in full immediately")
	radio._playback.pause()
	for i in 3:await get_tree().process_frame
	check(radio.body.get_line_count()>1 and radio.body.get_visible_line_count()==radio.body.get_line_count() and radio.get_global_rect().encloses(radio.body.get_global_rect()),"all wrapped lines fit inside the radio panel")
	radio._playback.custom_step(8.0)
	check(radio.visible and radio.modulate.a==1.0 and minimap.radio_contact_id=="lin","long paragraphs receive extra reading time")
	radio._playback.custom_step(next_message.length()/5.0)
	check(minimap.radio_contact_id.is_empty() and not radio.visible and not minimap._radio_portrait.visible and minimap._camera_layer.visible,"last message restores the tactical map and camera outline")
	check(field.summary().contains("✓ 救援"),"completed optional task has checkmark")
	var cache_field=Field.new();battle.add_child(cache_field);cache_field.set_process(false);cache_field.world=battle
	cache_field.data={"objectives":[{"id":"field1","kind":"cache","position":Vector2(1800,1650),"progress":20.0,"done":false,"reward":50}],"supplies":0,"contacts":[]}
	var base_reward:=Campaign.victory_supplies(8)
	battle.allied_state.expedition_field_ops=cache_field.data
	cache_field.complete(cache_field.data.objectives[0])
	cache_field.complete(cache_field.data.objectives[0])
	check(cache_field.data.supplies==50 and cache_field.data.get("kits",0)==1 and base_reward==220,"optional cache grants supplies and one kit once")
	check(Tactics.select_for(7,32)==Tactics.select_for(7,32),"multi-enemy elite seed remains deterministic")
	check(objective.visible_points()==[1] and objective.point_title(1).begins_with("前线据点"),"single objective never presents as target two")
	objective.state.kind="research";objective.state.labs=[20.0,0.0]
	check(objective.point_title(0).contains("实验室 1") and objective.point_title(2).contains("实验室 2"),"research sites use independent names, not indices")
	BattleRequest.combat_context.expedition={"task":"research","stage":8,"buffs":{},"traits":{},"trait_buffs":{},"condition":"","relics":{}}
	objective.state.next_wave=99999.0;objective.state.labs=[0.0,0.0]
	objective.state.points=[Vector2(1700,1650),Vector2(2200,2200),Vector2(2200,1650)]
	objective.tick(45.0)
	check(objective.state.labs==[45.0,0.0] and objective.state.progress==45.0,"first laboratory captured independently")
	escort.position=Vector2(2200,1650)
	objective.tick(44.0)
	check(objective.state.labs==[45.0,44.0] and objective.state.progress==89.0,"second laboratory accumulates without losing first")
	check(objective.summary().contains("1号 45/45") and objective.minimap_markers()[0].status=="done","completed laboratory has explicit status")
	check(objective.summary().contains("✓ 实验室 1"),"completed laboratory checked")
	var codec:=BattleSaves.Snapshot.new()
	var saved:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"field objective checkpoint captures real battle")
	var file:=FileAccess.open(output_dir.path_join("field-checkpoint.bin"),FileAccess.WRITE);file.store_var(saved);file.close()
	file=FileAccess.open(output_dir.path_join("field-checkpoint.bin"),FileAccess.READ);saved=file.get_var(false);file.close()
	codec.restore(battle,saved)
	check(codec.error.is_empty() and battle.allied_state.expedition_field_ops.supplies==50,"checkpoint restores completed cache bounty")
	var restored=Field.new();battle.add_child(restored);restored.setup(battle,true)
	restored.complete(restored.data.objectives[0])
	check(restored.data.supplies==50,"checkpoint does not repeat optional reward")
	var restored_tasks=Tasks.new();battle.add_child(restored_tasks)
	battle.allied_state.expedition_task=objective.state.duplicate(true)
	check(restored_tasks.setup(battle,true) and restored_tasks.state.labs==[45.0,44.0],"laboratory per-site progress restores")
	restored.queue_free();restored_tasks.queue_free()
	objective.queue_free();cache_field.queue_free();field.queue_free()
	await get_tree().process_frame
	await finish()
	FileAccess.open(output_dir.path_join("field-operations.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("FIELD OPS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
