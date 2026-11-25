extends "res://tests/allied_abilities_regression.gd"
const Model=preload("res://scripts/units/ra3_expansion_model.gd")
const FX=preload("res://scripts/units/ra3_tank_fx.gd")

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var start:=Vector2(1540,1450)
	battle.camera.position=start;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var rigs:Array=[]
	for i in 3:
		var tank=actor("R3TESLA","ally",start+Vector2(i*28,12))
		var model=tank._ra3_model
		if model==null:
			model=Model.new();model.actor=tank;tank.add_child(model);model._build()
		model.set_process(false);rigs.append(model)
	var moving:=sample_motion(rigs,60)
	var stationary:=sample_motion(rigs,0)
	print("TESLA_FX 60 frames / 3 units: moving ",moving," stationary ",stationary)
	check(moving.created>0 and stationary.created==0,"movement owns dust, stopped tanks stop emitting")
	check(moving.peak_particles<400,"three moving tanks have a bounded live particle count")
	screen.free();await get_tree().process_frame

func sample_motion(rigs:Array,speed:float) -> Dictionary:
	var peak:=0
	var created:=0
	var begin:=Time.get_ticks_usec()
	for frame in 60:
		for model in rigs:
			model.actor.velocity=Vector2.RIGHT*speed
			model.actor.position+=model.actor.velocity/30
			var before:int=battle.effects_root.get_child_count()
			model.tank_pose._attachments(model,1.0/30.0,"R3TESLA")
			created+=battle.effects_root.get_child_count()-before
		var count:=0
		for fx in battle.effects_root.get_children():
			if fx is FX:
				fx._process(1.0/30.0)
				count+=fx.rows.size()
				if fx.is_queued_for_deletion():fx.free()
		peak=maxi(peak,count)
	var elapsed:=Time.get_ticks_usec()-begin
	for fx in battle.effects_root.get_children():
		if fx is FX:fx.free()
	return {"created":created,"peak_particles":peak,"cpu_ms":elapsed/1000.0}
