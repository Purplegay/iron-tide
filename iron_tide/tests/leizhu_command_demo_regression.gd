extends "res://tests/leizhu_command_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://scripts/ui/hero_talent_demo.gd").new();demo.size=Vector2(700,400);viewport.add_child(demo);demo.show_hero("TTNK")
	const Demo=preload("res://scripts/ui/leizhu_command_demo.gd")
	for rank in range(1,4):
		demo.talent.select(0);demo._select_talent();demo.levels.select(rank);demo.restart();demo.playing=false
		check(demo.levels.item_count==6 and demo.caption.text.contains(Command.COMMAND[rank]) and demo.duration()==12,"correct implemented rank description and timeline "+str(rank))
		var hashes:Array=[]
		for t in [.1,1.1,2.1,3.1,3.5,4.1,6.1,8.1,9.1,11.1]:
			demo.elapsed=t;demo.refresh_preview();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			check(not picture.is_empty(),"GPU renders level "+str(rank)+" phase "+str(t))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data());if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=3,"distinct preparation, trigger and expiry frames "+str(rank))
	check(Demo.sample(1,1.1).shield==10 and Demo.sample(1,3.1).shield==20 and Demo.sample(1,9.1).shield==0,"demo shows exact half-shield transfer and six-second expiry")
	check(Demo.sample(2,2.1).detected and not Demo.sample(2,8.1).detected,"demo reveal only while inside scan range")
	check(Demo.sample(3,3.1).locked and not Demo.sample(3,4.1).locked and not Demo.sample(3,7.1).locked and Demo.sample(3,11.1).locked,"demo depicts one-second lock and shared eight-second interval")
	viewport.free()
	var hero=command_hero(3);var victim=target();give_shield(victim,20)
	for i in 3:fire(hero,victim)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	hero.queue_redraw();victim.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(Command.controlled(victim) and hero.special[L.KEY].has("stolen") and not get_viewport().get_texture().get_image().is_empty(),"live shield ring and enemy movement lock render without errors")
	check(not Command.entries(hero).is_empty() and not Command.entries(victim).is_empty(),"live hero and victim status entries are populated")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
