extends "res://tests/peregrine_base_regression.gd"

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(650,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=load("res://scripts/ui/hero_talent_demo.gd").new();demo.size=Vector2(650,360);viewport.add_child(demo)
	demo.show_hero("ORCA")
	for track in 2:
		demo.talent.select(track);demo._select_talent();demo.playing=false
		demo.levels.select(0);demo.refresh_caption()
		check(demo.levels.item_count==6 and demo.caption.text.contains("航拍落点" if track==0 else "离场余速"),"Peregrine correct baseline caption "+str(track))
		var hashes:Array=[]
		for time in [.1,1.2,2.4,3.5,4.7,5.5]:
			demo.elapsed=time;demo.refresh_preview()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			check(not image.is_empty(),"GPU renders Peregrine "+str(track)+" at "+str(time))
			var digest:=hash(image.get_region(Rect2i(demo.stage.get_global_rect())).get_data())
			if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=3,"baseline timeline changes distinct phases "+str(track))
	viewport.queue_free()
	var hero=setup_hero()
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	hero.selected=true
	for rounds in [4,0,2]:
		hero.logistics.ammo=rounds;hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty() and hero.logistics.air_lift==1,"real hovering hero draws at ammo "+str(rounds))
	await finish()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
