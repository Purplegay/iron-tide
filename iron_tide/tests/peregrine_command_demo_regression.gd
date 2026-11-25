extends "res://tests/peregrine_command_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	const Reload=preload("res://scripts/ui/peregrine_reload_demo.gd")
	const Sensor=preload("res://scripts/ui/peregrine_sensor_demo.gd")
	const Formation=preload("res://scripts/ui/peregrine_formation_demo.gd")
	const Split=preload("res://scripts/ui/peregrine_split_demo.gd")
	check(Split.sample(.99).ammo==1 and Split.sample(1).ammo==0 and not Split.sample(1).ready,"ordinary last round consumes magazine and once-per-full-cycle qualification")
	check(not Split.sample(1.99).warning and Split.sample(2).warning and Split.sample(2.49).warning and Split.sample(2.5).blast,"submunition warning begins on hit and waits half a second")
	check(Split.sample(4).ammo==1 and Split.sample(5).ammo==0 and not Split.sample(6).warning and not Split.sample(6).ready,"partial refill followed by another hit cannot split again")
	check(Split.sample(22.99).ammo==2 and Split.sample(23).ammo==0 and not Split.sample(23).ready,"W spends two real rounds and consumes the final-round qualification")
	check(not Split.sample(24).warning and not Split.sample(24.5).blast and not Split.sample(28).warning,"W impacts and next partial-reload hit never create submunition previews")
	for base:float in [0.,22.]:
		check(Split.sample(base+18.99).ammo==4 and not Split.sample(base+18.99).ready and Split.sample(base+19).ammo==5 and Split.sample(base+19).ready and Split.sample(base+19).cycle==1,"only actual five-round refill starts a new split cycle: "+str(base))
	check(not Sensor.sample(0,1.99).reveal and Sensor.sample(0,2).reveal and Sensor.sample(0,4.99).reveal and not Sensor.sample(0,5).reveal,"fixed impact reveal lasts three full seconds")
	check(Sensor.sample(0,4).offset>32 and Sensor.sample(0,4).reveal,"target moves beyond one-cell circle while original impact remains revealed")
	check(Sensor.sample(0,8.99).ammo==3 and Sensor.sample(0,9).ammo==4,"baseline reload is eight seconds from consumption")
	for part in 3:
		check(Sensor.sample(2,part*6+1).ammo==Sensor.sample(2,part*6+5).ammo and Sensor.sample(2,part*6+4).shots==4,"AA four one-second shots preserve magazine in case "+str(part))
		check(Sensor.sample(2,part*6+1).first==Sensor.sample(2,part*6+5).first and Sensor.sample(2,part*6+1).last==Sensor.sample(2,part*6+5).last,"AA first/last qualification does not change in case "+str(part))
	check(not Sensor.sample(3,0).visible and Sensor.sample(3,2).visible and not Sensor.sample(3,4).visible and Sensor.sample(3,5).visible and not Sensor.sample(3,8).visible,"ground scan covers approach, obstruction, recovery and departure")
	check(not Sensor.sample(3,2).sub_visible and not Sensor.sample(3,5).sub_visible,"nearby submarine remains excluded when ground target is visible")
	check(Formation.sample(1.99).ally_speed==1.15 and Formation.sample(2).wreck and Formation.sample(2).ally_speed==1 and Formation.sample(7.99).wreck,"formation is suspended throughout grounded wreck repair")
	check(not Formation.sample(8).wreck and Formation.sample(8).repair==5 and Formation.sample(8).ally_speed==1.15,"five seconds engineer repair restores global bonus")
	check(is_equal_approx(Formation.sample(13).speed,1.2) and is_equal_approx(Formation.sample(25).speed,1.35) and is_equal_approx(Formation.sample(37).speed,1.45),"empty bonus alone, with formation and with another buff is additive")
	for base:float in [12.,24.,36.]:
		check(Formation.sample(base+3.99).empty and not Formation.sample(base+4).empty,"empty-speed buff expires after three seconds in case "+str(base))
		check(is_equal_approx((Formation.sample(base+2.5).distance-Formation.sample(base+2).distance)/10,Formation.sample(base+2).speed),"drawn route distance follows actual displayed speed in case "+str(base))
	check(Formation.sample(20.99).ammo==0 and Formation.sample(21).ammo==1 and Formation.sample(29).ammo==1 and Formation.sample(33).ammo==2,"baseline and command-four reloading retain eight/four-second cadence")
	check(Reload.sample(0,true).ammo==5,"mount starts with all five rounds")
	check(Reload.sample(1,true).ammo==4 and Reload.sample(7.999,true).ammo==4,"fifth round is spent and cannot return before seven seconds")
	check(Reload.sample(8,true).ammo==5 and Reload.sample(8,true).full,"seventh elapsed second restores fifth round without airport")
	check(Reload.sample(2,true).reveal and not Reload.sample(5,true).reveal,"mount retains cumulative three-second fixed impact reveal")
	var viewport:=SubViewport.new();viewport.size=Vector2i(650,360)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(650,360);viewport.add_child(demo)
	demo.show_hero("ORCA");demo.talent.select(0);demo._select_talent();demo.playing=false
	for rank in 6:
		demo.levels.select(rank);demo.refresh_caption()
		check(demo.caption.text.contains(Cmd.COMMAND[rank]) and demo.caption.text.contains(str(8-rank)+" 秒/发"),"correct cumulative command description "+str(rank))
		var hashes:Array=[]
		var clipped:Array=[]
		var samples:Array=[.1,1.05,1.4,2.1,2.3,2.7,3.3,4.4,5.3]
		if rank==1:
			check(demo.duration()==10,"mount timeline includes seven-second refill and completed state")
			samples.append_array([7.99,8.0,9.9])
		if rank in [0,2,3]:
			check(demo.duration()==Sensor.duration(rank),"sensor preview uses complete timeline "+str(rank))
			if rank==0:samples.append_array([1.99,2.,4.99,5.,8.99,9.,9.9])
			elif rank==2:
				for part in 3:
					for at:float in [.99,1.,2.,3.,4.,5.9]:samples.append(part*6+at)
			else:samples.append_array([1.22,1.24,3.99,4.,4.99,5.,6.76,6.78,11.9])
		if rank==4:
			check(demo.duration()==Formation.LENGTH,"formation timeline includes independent repair and additive speed examples")
			for part in 4:
				for at:float in [.99,1.,1.99,2.,3.,3.99,4.,4.99,5.,7.99,8.,8.99,9.,11.9]:samples.append(part*12+at)
		if rank==5:
			check(demo.duration()==Split.LENGTH,"split preview contains ordinary and W full-cycle timelines")
			for base:float in [0.,22.]:
				for at:float in [.99,1.,1.99,2.,2.49,2.5,3.,3.99,4.,4.99,5.,6.,7.,10.,13.,16.,18.99,19.,21.9]:samples.append(base+at)
		for time in samples:
			demo.elapsed=time;demo.refresh_preview()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			var picture:=viewport.get_texture().get_image()
			if rank in [0,2,3,4,5]:
				var offset_x:=maxf(0,(demo.stage.size.x-540)*.5)
				for entry in demo.drawn_text:
					var font:=ThemeDB.fallback_font
					var size:=font.get_string_size(entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
					if entry.position.x+offset_x<0 or entry.position.x+offset_x+size.x>demo.stage.size.x or entry.position.y-font.get_ascent(14)<0 or entry.position.y+font.get_descent(14)>demo.stage.size.y:clipped.append(entry.text)
			check(not picture.is_empty(),"GPU command level "+str(rank)+" at "+str(time))
			var digest:=hash(picture.get_region(Rect2i(demo.stage.get_global_rect())).get_data())
			if not hashes.has(digest):hashes.append(digest)
		check(hashes.size()>=(2 if rank==2 else 3),"level-specific animation changes meaningful phases "+str(rank))
		if rank in [0,2,3,4,5]:check(clipped.is_empty(),"command preview text stays inside visible stage: "+str(clipped))
	viewport.free()
	var hero=command_hero(5);var target=victim("HTNK",hero.position+Vector2(150,0))
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	for i in 5:normal_shot(hero,target)
	check(battle.allied_state.get(Cmd.BOMBS,[]).size()==2,"real split warning exists before rendering")
	for delta in [.0,.2,.2,.11]:
		Cmd.world_tick(battle,delta);battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(not get_viewport().get_texture().get_image().is_empty(),"live submunition warning/explosion renders "+str(delta))
	var air=victim("ORCA",hero.position+Vector2(150,0));air.logistics.air_lift=1
	battle.select_unit(hero,false);battle.force_attack(air);hero._refresh_weapon_derived();hero._cd_timer=0;hero.hull_angle=0;hero.turret_angle=0
	check(hero._try_fire_ready() and hero.logistics.ammo==0,"actual empty-magazine AA weapon fires during GPU run")
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(not get_viewport().get_texture().get_image().is_empty(),"actual AA shot renders")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
