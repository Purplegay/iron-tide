extends "res://tests/leizhu_base_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(650,360);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=load("res://scripts/ui/hero_talent_demo.gd").new();demo.size=Vector2(650,360);viewport.add_child(demo)
	demo.show_hero("TTNK")
	for track in 2:
		demo.talent.select(track);demo._select_talent();demo.playing=false
		check(demo.levels.item_count==6 and demo.caption.text.contains("高压标定" if track==0 else L.BASE_TEXT[track]),"baseline demo uses actual hero trait text "+str(track))
		check(demo.duration()==(6.0 if track==0 else 24.0),"demo has full mark or shield trigger timeline")
		var hashes:Array=[]
		var samples:Array=[.1,1.1,2.5,3.1,5.5] if track==0 else [.1,3.9,4.1,9.9,10.1,21.9,22.1,23.9]
		for time in samples:
			demo.elapsed=time;demo.refresh_preview()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			check(not picture.is_empty(),"GPU renders hero baseline "+str(track)+" at "+str(time))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data())
			if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=3,"hero baseline timeline changes across actual phases")
	viewport.free()
	var hero=setup_hero();var victim=target()
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	for elapsed in [0.0,4.0,6.0,12.0]:
		L.tick(hero,elapsed);hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live shield/status renders "+str(elapsed))
	fire(hero,victim)
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(hero.special[L.KEY].marks.has(victim) and not L.entries(hero).is_empty(),"real combat mark appears in live status entry")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
