extends "res://tests/leizhu_defense_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(700,400);viewport.add_child(demo);demo.show_hero("TTNK")
	const Demo=preload("res://scripts/ui/leizhu_defense_demo.gd")
	for rank in [1,2]:
		demo.talent.select(1);demo._select_talent();demo.levels.select(rank);demo.restart();demo.playing=false
		check(demo.levels.item_count==6 and demo.caption.text.contains(Defense.DEFENSE[rank]) and demo.duration()==Demo.duration(rank),"actual defensive node description and complete timeline "+str(rank))
		var hashes:Array=[]
		var clipped:Array=[];var times:Array=[]
		if rank==1:
			for part in 3:
				for at:float in [.1,.99,1.,1.49,1.5,2.99,3.,4.99,5.,5.39,5.4,32.99,33.,34.99,35.,35.9]:times.append(part*36+at)
		else:
			for part in 5:
				for at:float in [.1,.99,1.,2.99,3.,6.99,7.,7.9]:times.append(part*8+at)
		for time in times:
			demo.elapsed=time;demo.refresh_preview();await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image();check(not picture.is_empty(),"defense GPU frame "+str(rank)+" at "+str(time))
			for entry in demo.drawn_text:
				var font:=ThemeDB.fallback_font;var size:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
				var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
				if entry.position.x+offset_x<0 or entry.position.x+offset_x+size.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data());if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=4,"distinct damage, trigger, active and expiry phases "+str(rank))
		check(clipped.is_empty(),"defense preview text remains inside stage: "+str(clipped))
	check(Demo.sample(1,2.9).parasite and not Demo.sample(1,3).parasite and Demo.sample(1,3).hp==80 and Demo.sample(1,3).cooldown==30 and Demo.sample(1,33).cooldown==0,"parasite demo retains damage and shows full thirty-second cooldown")
	check(Demo.sample(2,1).hp==80 and Demo.sample(2,1).shield==4 and Demo.sample(2,3).hp==64 and Demo.sample(2,3).shield==4 and Demo.sample(2,7).shield==0,"recovery demo shows old shield absorption then new shield and full expiry")
	for base:float in [36.,72.]:
		check(Demo.sample(1,base+3).parasite and Demo.sample(1,base+3).controlled and Demo.sample(1,base+3).left==0 and Demo.sample(1,base+3).cooldown==0,"ready purge waits without consuming cooldown during control: "+str(base))
		check(not Demo.sample(1,base+5).parasite and Demo.sample(1,base+5).flash and Demo.sample(1,base+5).cooldown==30 and Demo.sample(1,base+35).cooldown==0,"control release purges immediately and starts a full thirty-second interval: "+str(base))
	check(Demo.sample(2,9).hp==96 and Demo.sample(2,9).shield==0,"transferred electric share produces no recovery shield")
	check(Demo.sample(2,17).hp==80 and Demo.sample(2,17).shield==0 and Demo.sample(2,33).shield==0,"self and extra electric damage cannot create recovery shield")
	check(Demo.sample(2,24.99).hp==20 and Demo.sample(2,25).dead and Demo.sample(2,25).shield==0,"fatal electric damage is not rescued by recovery")
	viewport.free()
	var hero=defense_hero(2);var attacker=target("SHK","enemy",hero.position+Vector2(120,0))
	hero.receive_hit(40,"tesla",{},attacker);infest(hero);Defense.tick(hero,2)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll();hero.queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(hero.special[L.KEY].has("purge_flash") and hero.special[L.KEY].has("recycled") and not get_viewport().get_texture().get_image().is_empty(),"native purge pulse and independent recovery shield render together")
	check(Defense.entries(hero).size()==2,"live cooldown and shield statuses are both inspectable")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
