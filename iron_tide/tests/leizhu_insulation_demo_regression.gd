extends "res://tests/leizhu_insulation_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://scripts/ui/hero_talent_demo.gd").new();demo.size=Vector2(700,400);viewport.add_child(demo);demo.show_hero("TTNK")
	demo.talent.select(1);demo._select_talent();demo.levels.select(3);demo.restart();demo.playing=false
	check(demo.levels.item_count==6 and demo.caption.text.contains(Defense.DEFENSE[3]) and demo.duration()==12,"insulation preview uses actual third-node description and full timeline")
	var hashes:Array=[]
	for time in [.1,1.1,2.1,4.1,6.9,7.1,9.1,11.1]:
		demo.elapsed=time;demo.refresh_preview();await get_tree().process_frame;await RenderingServer.frame_post_draw
		var picture:=viewport.get_texture().get_image();check(not picture.is_empty(),"insulation GPU frame at "+str(time))
		var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data());if not hashes.has(digest):hashes.append(digest)
	check(hashes.size()>=5,"distinct acquisition, frozen movement, boundary crossing and recovery frames")
	const Demo=preload("res://scripts/ui/leizhu_insulation_demo.gd")
	check(Demo.sample(6.9).frozen and not Demo.sample(7).frozen and Demo.sample(4).distance-Demo.sample(3).distance==12 and Demo.sample(9).distance-Demo.sample(8).distance==24,"demo preserves incoming beam until range exit and uses exactly half displacement while frozen")
	viewport.free()
	var hero=mover();var chrono=freeze(hero);hero.order_move(hero.position+Vector2(200,0))
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll();await get_tree().physics_frame
	var origin:Vector2=hero.position
	for i in 15:hero._physics_process(1.0/Engine.physics_ticks_per_second);AlliedAbilities.channel(chrono,1.0/Engine.physics_ticks_per_second)
	hero.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(hero.position!=origin and AlliedAbilities.frozen(hero) and hero.material is ShaderMaterial and not get_viewport().get_texture().get_image().is_empty(),"real moving hero retains native frozen shader and incoming channel")
	check(preload("res://scripts/ui/battle_effect_details.gd").describe(hero).contains("绝缘缓行允许50%移速"),"live details describe movement exception without calling it immunity")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
