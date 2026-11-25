extends "res://tests/base_recovery_regression.gd"
const Tasks=preload("res://scripts/expedition/objectives.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.expedition={"buffs":{},"traits":{},"trait_buffs":{},"condition":"","relics":{}}
	Expedition.state={"country":"美国"}
	var tasks=Tasks.new();battle.add_child(tasks);tasks.world=battle
	tasks.state={"kind":"rescue","stage":11,"outcome":0,"elapsed":0.0,"progress":0,"phase":0,"points":[Vector2(1400,1400),Vector2(1800,1800),Vector2(2100,1400)],"rescued":[],"targets":[],"waves":0,"next_wave":9999.0}
	battle.allied_state.expedition_task=tasks.state
	var soldier=battle.spawn_unit("E1","ally",Vector2(1400,1400))
	tasks.tick(10.0)
	check(is_equal_approx(tasks.rescue_progress(0),0.5),"rescue bar half filled after ten seconds")
	check(tasks.visible_points()==[0,2],"both unfinished rescue sites shown")
	if DisplayServer.get_name()!="headless":
		battle.camera.position=Vector2(1600,1400);battle.camera.zoom=Iso.cam_zoom(1.5)
		tasks.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("rescue-half-progress.png"))
	tasks.tick(11.0)
	check(tasks.state.rescue0==20.0 and tasks.state.rescued==[0],"rescue completes and clamps seconds")
	check(tasks.visible_points()==[2],"completed world marker removed")
	check(tasks.minimap_markers().size()==1 and tasks.minimap_markers()[0].key=="point2","completed minimap marker removed")
	check(tasks.state.progress==1,"overall rescued total remains one of two")
	var count:int=battle.units.size();tasks.tick(1.0)
	check(battle.units.size()==count,"completed rescue never repeats its unit reward")
	var codec:=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"capture completed and pending rescue")
	var file:=FileAccess.open(output_dir.path_join("rescue-progress.bin"),FileAccess.WRITE);file.store_var(saved);file.close()
	file=FileAccess.open(output_dir.path_join("rescue-progress.bin"),FileAccess.READ);saved=file.get_var(false);file.close()
	codec.restore(battle,saved)
	var restored=Tasks.new();battle.add_child(restored)
	check(restored.setup(battle,true),"restore rescue objective from disk checkpoint")
	check(restored.visible_points()==[2] and restored.minimap_markers().size()==1,"restored completed marker stays hidden")
	check(restored.rescue_progress(0)==1.0 and restored.rescue_progress(2)==0.0,"restored progress preserves individual sites")
	restored.state.kind="capture"
	restored.state.progress=0.0
	var point:Vector2=restored.state.points[1]
	battle.spawn_unit("E1","ally",point)
	restored.tick(33.0)
	check(restored.visible_points()==[1] and restored.state.progress==33.0,"frontline capture reaches screenshot's 33/60")
	battle.spawn_unit("E1","enemy",point)
	restored.tick(2.0)
	check(restored.state.progress==33.0,"contested capture keeps earned progress")
	if DisplayServer.get_name()!="headless":
		tasks.hide()
		battle.camera.position=point
		restored.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		var center:Vector2=restored.get_global_transform_with_canvas()*point
		var stretch:=get_viewport().get_stretch_transform()
		var filled:=Vector2i(stretch*(center+Vector2(0,-38)))
		var empty:=Vector2i(stretch*(center+Vector2(16,-38)))
		var bar_rect:=Rect2i(stretch*Rect2(center-Vector2(104,84),Vector2(208,86)))
		image.get_region(bar_rect).save_png(output_dir.path_join("frontline-33-of-60.png"))
		check(image.get_pixelv(filled).g>0.65 and image.get_pixelv(empty).g<0.4,"rendered 55 percent bar has filled and empty sections")
	var alert=preload("res://scripts/expedition/red_alert.gd")
	battle.allied_state[alert.KEY]={"charge":1,"left":0.0,"threat":0.0}
	get_tree().paused=false
	battle.paused=false
	check(alert.activate(battle) and alert.state(battle).left==30.0,"Red Alert starts with thirty seconds")
	alert.tick(battle,29.0)
	check(alert.production(battle,"ally")==2.0 and alert.state(battle).left==1.0,"boost lasts through second 29")
	alert.tick(battle,1.0)
	check(not alert.active(battle) and alert.production(battle,"ally")==1.0,"boost ends at thirty seconds")
	alert.state(battle).left=150
	alert.setup(battle,{},true)
	check(alert.state(battle).left==30.0,"old active checkpoint capped at thirty")
	tasks.free();restored.free()
	await finish()
	print("RESCUE PROGRESS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
