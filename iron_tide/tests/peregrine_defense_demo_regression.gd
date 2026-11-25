extends "res://tests/peregrine_service_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	const Reload=preload("res://scripts/ui/peregrine_reload_demo.gd")
	const Cycle=preload("res://scripts/ui/peregrine_cycle_defense_demo.gd")
	const Maintenance=preload("res://scripts/ui/peregrine_maintenance_demo.gd")
	const Crash=preload("res://scripts/ui/peregrine_crash_demo.gd")
	check(Maintenance.sample(1.5).lift==10 and Maintenance.sample(1.99).shield==0 and Maintenance.sample(2).shield==20,"maintenance descent takes a full second before ground shield")
	check(Maintenance.sample(5).hp==50 and Maintenance.sample(6).hp==52,"maintenance first waits three seconds then heals two percent per second")
	check(Maintenance.sample(6).shield==10 and Maintenance.sample(6).quiet==0 and Maintenance.sample(8.99).hp==52,"shield-only damage restarts the entire quiet window without losing health")
	check(Maintenance.sample(10).hp==54 and Maintenance.sample(10).shield==0 and Maintenance.sample(12).shield==0 and Maintenance.sample(12).cooldown==20,"takeoff clears shield and repeat landing cannot reset original cooldown")
	check(Maintenance.sample(14.99).hp==54 and Maintenance.sample(16).hp==56,"unshielded repeated maintenance still heals after a new three-second wait")
	check(Maintenance.sample(32.99).shield==0 and Maintenance.sample(33).shield==20 and Maintenance.sample(33).cooldown==30,"new landing only grants a fresh shield after original thirty-second interval")
	check(Maintenance.sample(7.99).ammo==2 and Maintenance.sample(8).ammo==3 and Maintenance.sample(16).ammo==4,"airborne reload cadence continues through maintenance and takeoff")
	for case_id in 5:
		check(Crash.sample(1,case_id).hp==1000 and Crash.sample(1.5,case_id).max_hp==1000 and Crash.sample(2,case_id).hp==(800 if case_id==2 else 1000) and Crash.sample(2,case_id).left==180,"immediate tenfold transition durability preserves damage at landing: "+str(case_id))
	check(Crash.sample(6.99,1).wreck and Crash.sample(6.99,1).repair>4.9 and Crash.sample(7,1).repaired and Crash.sample(7,1).ammo==0,"early engineer requires five seconds and restores normal full life with zero ammo")
	check(Crash.sample(15,1).ammo==1 and Crash.sample(39,1).ammo==4,"early recovered aircraft resumes normal eight-second reload instead of staying visually empty")
	check(Crash.sample(4,2).hp==800 and Crash.sample(6,2).dead and Crash.sample(187,2).dead and Crash.sample(187,2).completions==0,"damaged wreck can be destroyed and never automatically revives")
	check(Crash.sample(181,3).left==1 and Crash.sample(181,3).repair==0 and Crash.sample(181.5,3).repair==.5,"late engineer begins at grounded second 179 without resetting automatic clock")
	check(Crash.sample(182,3).repaired and Crash.sample(182,3).cancelled and Crash.sample(187,3).completions==1,"late engineer is canceled by automatic recovery and cannot recover twice")
	check(Crash.sample(181.99,4).repair>4.9 and Crash.sample(182,4).completions==1 and Crash.sample(187,4).completions==1,"overlapping five-second and automatic completion shows exactly one restoration")
	check(Crash.sample(181.99,0).wreck and Crash.sample(182,0).hp==100 and Crash.sample(182,0).max_hp==100 and Crash.sample(182,0).ammo==0,"automatic full 180 seconds returns normal cap, full health and zero ammo")
	check(Cycle.sample(1,1.99).ready and not Cycle.sample(1,2).ready and Cycle.sample(1,2).deflect and Cycle.sample(1,2).hp==100,"first eligible missile consumes decoy at one-cell contact without damage")
	check(Cycle.sample(1,4.99).hp==100 and Cycle.sample(1,5).hp==90 and not Cycle.sample(1,5).ready,"same-cycle second guided missile hits without renewed decoy")
	for part in [1,2,3,4]:
		check(Cycle.sample(1,part*8+2).hp==90 and Cycle.sample(1,part*8+2).ready and not Cycle.sample(1,part*8+2).deflect,"excluded incoming damage preserves decoy: "+str(part))
		check(Cycle.sample(1,part*8+4).deflect and not Cycle.sample(1,part*8+4).ready and Cycle.sample(1,part*8+5).hp==90,"next eligible missile can use retained decoy: "+str(part))
	check(Cycle.sample(3,1).steady and not Cycle.sample(3,1).ready and not Cycle.sample(3,3).steady,"first EMP creates exactly two seconds of steady firing lock")
	check(Cycle.sample(3,2).distance>Cycle.sample(3,1).distance,"steady state allows actual preview movement")
	check(Cycle.sample(3,4).stunned and Cycle.sample(3,7.99).stunned and not Cycle.sample(3,8).stunned and Cycle.sample(3,4).distance==Cycle.sample(3,7.99).distance,"second stun runs four seconds and stops the preview movement")
	check(Cycle.sample(3,9).ammo==3 and not Cycle.sample(3,16.99).ready and Cycle.sample(3,17).ammo==4 and Cycle.sample(3,17).ready,"real eight-second complete refill restores resistance")
	check(Cycle.sample(3,18).steady and not Cycle.sample(3,18).ready and not Cycle.sample(3,20).steady,"new full cycle grants one more resistance with its own two-second lock")
	check(Reload.sample(8.999,false).hp==60 and Reload.sample(8.999,false).ammo==3,"signature cannot heal before full eight-second refill")
	check(Reload.sample(9,false).hp==65 and Reload.sample(9,false).ammo==4,"valid impact heals exactly on full reload")
	check(not Reload.sample(19,false).hit and Reload.sample(19,false).hp==60 and Reload.sample(19,false).ammo==4,"empty-ground shot refills without healing")
	check(Reload.sample(29,false).ammo==3 and Reload.sample(29,false).hp==60,"two-shot cycle partial reload does not heal")
	check(Reload.sample(36.999,false).hp==60 and Reload.sample(37,false).hp==65 and Reload.sample(37,false).ammo==4,"second replenished round finally heals once")
	check(Reload.sample(39,false).hp==65,"remaining full cannot repeat healing")
	var viewport:=SubViewport.new();viewport.size=Vector2i(650,360);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(650,360);viewport.add_child(demo)
	demo.show_hero("ORCA");demo.talent.select(1);demo._select_talent();demo.playing=false
	for rank in 6:
		demo.levels.select(rank);demo.refresh_caption()
		check(demo.caption.text.contains(D.DEFENSE[rank]),"correct unique defense caption "+str(rank))
		var hashes:Array=[]
		var clipped:Array=[]
		var samples:Array=[.1,1.1,1.9,2.1,2.4,3.2,3.8,4.2,5.2]
		if rank==0:samples.append_array([7.99,8.,12.,13.,15.99,16.,21.,24.,25.,27.99,28.,36.,37.,39.99,40.,47.9])
		if rank==1:
			for part in 5:
				for at:float in [.99,1.,1.99,2.,2.34,2.35,3.,3.99,4.,4.34,4.35,4.99,5.,7.9]:samples.append(part*8+at)
		if rank==3:samples.append_array([.99,1.,2.99,3.,3.99,4.,7.99,8.,8.99,9.,16.99,17.,17.99,18.,19.99,20.,21.9])
		if rank==2:samples.append_array([8.99,9.0,10.,12.,18.99,19.,20.,22.,28.99,29.,36.99,37.,39.9])
		if rank==4:samples.append_array([1.99,2.,4.99,5.,5.99,6.,8.99,9.,9.99,10.,10.5,11.,11.99,12.,14.99,15.,16.,30.99,31.,31.5,32.,32.99,33.,33.9])
		if rank==5:samples.append_array([.99,1.,1.5,1.99,2.,3.99,4.,5.99,6.,6.99,7.,14.99,15.,39.,90.,176.99,177.,180.99,181.,181.5,181.99,182.,182.5,185.99,186.,187.9])
		check(is_equal_approx(demo.duration(),Crash.LENGTH if rank==5 else Maintenance.LENGTH if rank==4 else 40 if rank==2 else 48 if rank==0 else Cycle.duration(rank)),"timeline retains real durations "+str(rank))
		for time in samples:
			demo.elapsed=time;demo.refresh_preview()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			if rank in [1,3,4,5]:
				var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
				for entry in demo.drawn_text:
					var font:=ThemeDB.fallback_font
					var size:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
					if entry.position.x+offset_x<0 or entry.position.x+offset_x+size.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
			check(not picture.is_empty(),"GPU defense level "+str(rank)+" at "+str(time))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data())
			if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=3,"defense timeline has distinct phases "+str(rank))
		if rank in [1,3,4,5]:check(clipped.is_empty(),"defense text stays inside stage: "+str(clipped))
	viewport.free()
	var hero=defense_hero(3)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var shot=missile(hero);advance(shot,2)
	check(shot.splinters.get("peregrine_deflected",false),"actual IFV missile diverted during GPU run")
	for elapsed in [0.,.15,.25]:
		P.tick(hero,elapsed);hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live decoy drawing and removal "+str(elapsed))
	hero.stun(4)
	for elapsed in [0.,1.,1.01]:
		P.tick(hero,elapsed);hero.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live steady drawing and removal "+str(elapsed))
	check(not D.silent(hero) and not hero.special[P.KEY].has("decoy_flash"),"live temporary visual states clear at their durations")
	await finish()
	hero=service_hero(4);place_service(hero)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	check(hero.deploy(),"live maintenance enters through real deploy command")
	for elapsed in [.5,.5,3.1,7.0]:
		P.tick(hero,elapsed);hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live maintenance altitude, shield and status render "+str(elapsed))
	check(hero.logistics.air_lift==0 and not hero.special[P.KEY].has("maintenance_shield"),"live shield expires while grounded maintenance remains")
	await finish()
	hero=service_hero();make_wreck(hero)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	for elapsed in [.5,.5,90.0,89.9,.1]:
		P.tick(hero,elapsed);hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live vulnerable crash, wreck timer and recovery render "+str(elapsed))
	check(not hero.special.has("hero_wreck") and preload("res://scripts/ui/revival_indicator.gd").state(hero).is_empty(),"live repair countdown clears after recovery")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
