extends "res://tests/leizhu_safety_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(760,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(760,400);viewport.add_child(demo);demo.show_hero("TTNK")
	const Demo=preload("res://scripts/ui/leizhu_safety_demo.gd")
	for rank in [4,5]:
		demo.talent.select(1);demo._select_talent();demo.levels.select(rank);demo.restart();demo.playing=false
		check(demo.levels.item_count==6 and demo.caption.text.contains(Defense.DEFENSE[rank]) and demo.duration()==Demo.duration(rank),"full chain preview and real description "+str(rank))
		var hashes:Array=[]
		var clipped:Array=[];var times:Array=[]
		for part in (4 if rank==4 else 2):
			for at:float in [.1,.99,1.,1.99,2.,2.49,2.5,3.99,4.,4.99,5.,5.9]:times.append(part*(6 if rank==4 else 9)+at)
		if rank==5:times.append_array([5.99,6.,8.9,14.99,15.,17.9])
		for time in times:
			demo.elapsed=time;demo.refresh_preview();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image();check(not picture.is_empty(),"safety GPU frame "+str(rank)+" at "+str(time))
			for entry in demo.drawn_text:
				var font:=ThemeDB.fallback_font;var size:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
				var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
				if entry.position.x+offset_x<0 or entry.position.x+offset_x+size.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data());if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=(3 if rank==4 else 5),"distinct safety phases render "+str(rank))
		check(clipped.is_empty(),"safety preview text remains inside stage: "+str(clipped))
	check(Demo.sample(4,1).hero_hp==96 and Demo.sample(4,1).ally_hp==20,"diversion demo shows eighty damage to ally and four to hero")
	check(Demo.sample(5,1).hero_hp==1 and Demo.sample(5,1).shield==40 and Demo.sample(5,3.99).stopped and not Demo.sample(5,4).stopped and Demo.sample(5,4).hero_hp==20 and Demo.sample(5,6).dead,"shutdown demo retains full interval, subsequent shield loss and final death")
	check(Demo.sample(4,7).hero_hp==80 and Demo.sample(4,7).ally_hp==100,"direct twenty damage to hero does not receive transfer discount")
	check(Demo.sample(4,13).hero_hp==96 and Demo.sample(4,13).shield==0,"transferred electric damage does not generate recovery")
	check(not Demo.sample(4,19).active and Demo.sample(4,19).ally_hp==0 and Demo.sample(4,19).hero_hp==100,"frozen protector cannot divert lethal friendly damage")
	check(Demo.sample(5,.99).power==100 and Demo.sample(5,.99).court and Demo.sample(5,1).power==0 and not Demo.sample(5,1).court and not Demo.sample(5,1).active,"shutdown simultaneously stops power and diversion and clears court")
	check(Demo.sample(5,2.5).ally_hp==90 and Demo.sample(5,2.5).shield==20,"ally takes full hit while shutdown prevents diversion")
	check(Demo.sample(5,4).power==100 and Demo.sample(5,4).active and not Demo.sample(5,4).court,"surviving shutdown restores power and diversion without recreating court")
	check(Demo.sample(5,5).ally_hp==82 and is_equal_approx(Demo.sample(5,5).shield,19.6),"restored diversion protects ally and consumes actual transferred fraction from emergency shield")
	check(Demo.sample(5,11).dead and not Demo.sample(5,11).stopped and Demo.sample(5,13).hero_hp==0 and Demo.sample(5,13).power==0,"shield-breaking damage during shutdown prevents delayed recovery and power restoration")
	viewport.free()
	var hero=defense_hero(5);health(hero);hero.selected=true
	var ally=target("HTNK","ally",hero.position+Vector2(80,0));health(ally)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	hero.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(Safety.protected(hero)==ally and not get_viewport().get_texture().get_image().is_empty(),"native selected hero protection tether renders")
	var enemy=target();hit(hero,2000,enemy);hero.queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(Safety.entries(hero).any(func(row):return row.text.contains("停堆应急盾")) and not get_viewport().get_texture().get_image().is_empty(),"native shutdown countdown and emergency shield render with inspectable state")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
