extends "res://tests/boris_radio_regression.gd"

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	const Air=preload("res://scripts/ui/boris_air_support_demo.gd")
	const Rifle=preload("res://scripts/ui/boris_rifle_demo.gd")
	check(not Rifle.sample(1,2.99).suppressed and Rifle.sample(1,3).suppressed and not Rifle.sample(1,4).suppressed,"third hit produces exactly one second of suppression")
	check(not is_equal_approx(Rifle.sample(1,3).offset,Rifle.sample(1,3.9).offset),"suppressed tank changes its rendered position")
	check(Rifle.sample(1,3.49).hp==100 and Rifle.sample(1,3.5).hp==90 and Rifle.sample(1,3.5).suppressed,"previously fired shell lands during suppression")
	check(not Rifle.sample(1,7).suppressed and Rifle.sample(1,7).cooldown==4 and Rifle.sample(1,11).suppressed,"second triple is blocked by shared interval and third triple can suppress again")
	check(Rifle.sample(4,.99).charges==0 and Rifle.sample(4,1).charges==3 and Rifle.sample(4,1.5).charges==3,"Boris attaches mark but his second hit does not consume it")
	check(Rifle.sample(4,2).charges==2 and Rifle.sample(4,3).charges==1 and Rifle.sample(4,4).charges==0,"three allied hits consume three charges one by one")
	check(Rifle.sample(4,11.99).charges==3 and Rifle.sample(4,12).charges==0,"unused focus charges expire four seconds after attachment")
	check(not Rifle.sample(4,16).visible and Rifle.sample(4,16).marked and Rifle.sample(4,19.5).visible and not Rifle.sample(4,19.5).marked,"mark cannot reveal fog-hidden target and expires before target reappears")
	check(Air.sample(2,1.99).tokens.count(true)==0 and Air.sample(2,2).tokens.count(true)==4,"relay appears only at actual impact")
	check(Air.sample(2,3).tokens.count(true)==3 and not Air.sample(2,3).tokens[0],"first soldier consumes exactly one next-reload token")
	check(Air.sample(2,6.99).tokens.count(true)==3 and Air.sample(2,7).tokens.count(true)==0,"unused relay tokens expire after five real seconds")
	check(Air.sample(2,11).tokens.count(true)==0 and Air.sample(2,16).tokens.count(true)==0,"missed impact never grants relay")
	check(Air.sample(2,22.5).second and not Air.sample(2,22.5).tokens[0] and Air.sample(2,25).tokens.count(true)==0,"second same-wing impact cannot restore consumed token or extend expiry")
	check(Air.sample(3,1).main==4 and Air.sample(3,5.99).occupied,"native main wing remains occupied through departure")
	check(not Air.sample(3,6).occupied and is_equal_approx(Air.sample(3,6).cooldown,Air.recharge()),"last main exit starts complete native reload")
	check(not Air.sample(3,6+Air.recharge()-.01).ready and Air.sample(3,6+Air.recharge()+.01).ready,"next main wing must wait full reload")
	check(Air.sample(5,1).main==4 and Air.sample(5,1).secondary==2,"elite dual-target allocation is four plus two")
	check(Air.sample(5,6.1).main==0 and Air.sample(5,6.1).secondary==2 and Air.sample(5,6.1).occupied and is_equal_approx(Air.sample(5,6.1).cooldown,Air.recharge()),"secondary wing alone keeps reload suspended")
	check(not Air.sample(5,8).occupied and is_equal_approx(Air.sample(5,8).cooldown,Air.recharge()),"last secondary exit starts one shared reload")
	var no_secondary:=10+Air.recharge()
	check(Air.sample(5,no_secondary+1).main==4 and Air.sample(5,no_secondary+1).secondary==0,"no legal secondary produces only original four aircraft")
	check(not Air.sample(5,no_secondary*2+1.99).retarget and Air.sample(5,no_secondary*2+2).retarget and Air.sample(5,no_secondary*2+2).secondary==2,"invalid secondary redirects both extras together")
	check(Air.sample(5,no_secondary*3+2).aborted and Air.sample(5,no_secondary*3+2).main==4 and Air.sample(5,no_secondary*3+2).secondary==2,"no replacement sends two extras outbound without increasing primary allocation")
	check(Air.sample(5,no_secondary*3+5).secondary==0 and Air.sample(5,no_secondary*3+5).main==4 and Air.sample(5,no_secondary*3+5).occupied,"early secondary abort still waits for remaining primary aircraft")
	check(not Air.sample(5,no_secondary*3+6).occupied and is_equal_approx(Air.sample(5,no_secondary*3+6).cooldown,Air.recharge()),"aborted-secondary scenario starts full reload only after last main exit")
	var viewport:=SubViewport.new();viewport.size=Vector2i(600,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(600,360);viewport.add_child(demo)
	demo.show_hero("BORIS")
	for track in 2:
		demo.talent.select(track);demo._select_talent()
		check(demo.levels.item_count==6,"both Boris paths expose all six implemented levels")
		for rank in demo.levels.item_count:
			demo.levels.select(rank);demo.refresh_caption();demo.playing=false
			var hashes:Array=[]
			var clipped:Array=[]
			var times:Array=[.1,1.2,2.2,3.2,4.6,5.4]
			if track==0 and rank in [1,4]:
				check(demo.duration()==Rifle.duration(rank),"rifle timeline contains cooldown and exclusion scenarios")
				if rank==1:times.append_array([2.49,2.5,2.99,3.,3.49,3.5,3.99,4.,6.99,7.,10.99,11.,11.99,12.,13.9])
				else:
					for part in 3:
						for at:float in [.99,1.,1.49,1.5,1.99,2.,2.99,3.,3.99,4.,4.5,4.99,5.,5.5,6.,6.9]:times.append(part*7+at)
			if track==0 and rank in [2,3,5]:
				check(is_equal_approx(demo.duration(),Air.duration(rank)),"air-support playback includes full expiration/recharge "+str(rank))
				if rank==2:times.append_array([6.99,7.,9.,11.,16.,18.,22.5,25.,26.9])
				else:times.append_array([5.99,6.01,7.99,8.,8+Air.recharge()+.01,demo.duration()-.01])
				if rank==5:times.append_array([no_secondary+1,no_secondary+6,no_secondary+6+Air.recharge()+.01])
				if rank==5:
					for part in [2,3]:
						for at:float in [1.,1.99,2.,2.5,3.,4.,4.5,4.99,5.,5.99,6.,7.99,8.,8+Air.recharge()+.01]:times.append(part*no_secondary+at)
			for clock in times:
				demo.elapsed=clock;demo.refresh_preview()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				var image:=viewport.get_texture().get_image()
				if track==0 and rank in [1,4,5]:
					var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
					for entry in demo.drawn_text:
						var font:=ThemeDB.fallback_font
						var bounds:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
						if entry.position.x+offset_x<0 or entry.position.x+offset_x+bounds.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
				check(not image.is_empty(),"GPU Boris command "+str(track)+" level "+str(rank)+" time "+str(clock))
				var stage_image:=image.get_region(Rect2i(demo.stage.get_global_rect()))
				var digest:=hash(stage_image.get_data())
				if not hashes.has(digest):hashes.append(digest)
			check(hashes.size()>=(1 if track==0 and rank==0 else 2) and demo.caption.text.begins_with("Lv.%d"%rank),"selected timeline draws correct explanatory state")
			if track==0 and rank in [1,4,5]:check(clipped.is_empty(),"Boris new branch labels stay inside the clipped stage: "+str(clipped))
	viewport.queue_free()
	var hero=radio_hero(5,5)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var soldier=battle.spawn_unit("E2","ally",hero.position+Vector2(35,0));Radio.started(hero)
	var main=building(hero.position+Vector2(150,0));var jets:=dispatch(hero,main)
	jets[0].position=main.position-Vector2(20,0);Soviet.fly_mig(jets[0],.01);jets[0].position=jets[0].special.strike_run.origin;Soviet.fly_mig(jets[0],.01)
	battle.queue_redraw();soldier.queue_redraw()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(battle.allied_state.get(Radio.PICKUPS,[]).size()==1 and soldier.special.has(Radio.SHIELD) and not get_viewport().get_texture().get_image().is_empty(),"live supply and recipient shield draw in the real battlefield")
	var source=robust_enemy("E2",hero.position+Vector2(90,0));hero.receive_hit(100000,"bullet",{},source)
	var elapsed:=0.0
	for delta in [.1,1.3,.11]:
		elapsed+=delta;Radio.world_tick(battle,delta);battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not battle.allied_state.has(Radio.EVENTS) if elapsed>=1.5 else battle.allied_state.get(Radio.EVENTS,[]).size()==1,"real last-order warning persists until timed impact")
	await finish()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
