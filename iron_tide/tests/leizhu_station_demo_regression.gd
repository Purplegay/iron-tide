extends "res://tests/leizhu_station_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://scripts/ui/hero_talent_demo.gd").new();demo.size=Vector2(700,400);viewport.add_child(demo);demo.show_hero("TTNK")
	const Demo=preload("res://scripts/ui/leizhu_station_demo.gd")
	for rank in [4,5]:
		demo.talent.select(0);demo._select_talent();demo.levels.select(rank);demo.restart();demo.playing=false
		check(demo.levels.item_count==6 and demo.caption.text.contains(Command.COMMAND[rank]) and demo.duration()==(16 if rank==4 else 12),"full node text and full trigger timeline "+str(rank))
		var hashes:Array=[]
		for time in ([.1,2.9,3.1,3.5,6.1,14.9,15.1] if rank==4 else [.1,2.1,5.9,6.1,8.1,10.1]):
			demo.elapsed=time;demo.refresh_preview();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			check(not picture.is_empty(),"render command "+str(rank)+" at "+str(time))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data());if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=4,"distinct trigger, active, unavailable and recovery stages "+str(rank))
	check(not Demo.sample(4,2.9).fired and Demo.sample(4,3.1).flash and not Demo.sample(4,14.9).ready and Demo.sample(4,15).ready,"ground demo waits three seconds and respects twelve-second trigger interval")
	check(Demo.sample(5,2.1).total==150 and not Demo.sample(5,2.1).low and Demo.sample(5,5.9).extra==100,"power demo continues supplying after it covers baseline deficit")
	check(Demo.sample(5,6.1).low and Demo.sample(5,6.1).extra==100,"power demo preserves insufficient power")
	check(Demo.sample(5,8.1).extra==0 and Demo.sample(5,8.1).total==300 and Demo.sample(5,10.1).low,"power demo exits on natural power recovery and departure")
	viewport.free()
	var hero=command_hero(5);power_setup(hero)
	# Clear fixture building blockers for a separate native ground-arc render.
	hero.position=Vector2(2100,2100);var targets:=line_targets(hero);L.tick(hero,3);fire(hero,targets[0])
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	hero.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(hero.special[L.KEY].pierce_flash.points.size()==2 and not get_viewport().get_texture().get_image().is_empty(),"native ground-arc world geometry renders")
	hero.position=battle.buildings[0].position+Vector2(200,0);battle._update_power();screen.hud._refresh_top()
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll();hero.queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(hero.special[L.KEY].power_active and screen.hud.power_sub.text.contains("英雄供电 +100") and not get_viewport().get_texture().get_image().is_empty(),"live generator ring and power HUD render")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
