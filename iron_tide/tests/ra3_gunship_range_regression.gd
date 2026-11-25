extends "res://tests/allied_abilities_regression.gd"

const Impact=preload("res://scripts/units/ra3_gunship_impact.gd")

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	seed(633640)
	var reversed_ok:=true
	var negative_ok:=true
	var ordinary_ok:=true
	var samples: Array[float]=[]
	for i in 64:
		reversed_ok=reversed_ok and is_equal_approx(Impact.range_value({"attrs":{"Low":0.75,"High":0.1}}),0.1)
		negative_ok=negative_ok and is_equal_approx(Impact.range_value({"attrs":{"Low":-1,"High":-3}}),-3)
		var value: float=Impact.range_value({"attrs":{"Low":-7,"High":7}})
		ordinary_ok=ordinary_ok and value>=-7 and value<=7
		samples.append(value)
	check(reversed_ok,"Uprising ClientRandomVariable returns High for reversed positive bounds")
	check(negative_ok,"reversed negative bounds also return High without sorting")
	check(ordinary_ok and samples.min()!=samples.max(),"ordered bounds retain variation within source interval")
	check(is_equal_approx(Impact.range_value({"attrs":{"Low":-0.05,"High":-0.05}}),-0.05),"constant negative size rate preserved")
	check(is_equal_approx(Impact.range_value({},1),1),"missing optional field retains caller default")
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	if DisplayServer.get_name()=="headless":screen.free();return
	var point:=Vector2(1800,1600)
	actor("MTNK","enemy",point)
	battle._place_building("GAPOWR","ally",point+Vector2(180,60),true)
	battle.camera.position=point;battle.camera.zoom=Iso.cam_zoom(1.5)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var measurements: Array=[]
	for heroic in [false,true]:
		seed(48120)
		var effect=Impact.spawn(battle,point,heroic);effect.set_process(false)
		var waves: Array=[]
		for row in effect.particles:
			if str(row.data.attrs.id).ends_with("SW"):waves.append(row)
		check(waves.size()==5,"five original shockwaves retained, heroic="+str(heroic))
		var rates_ok:=true
		for row in waves:
			rates_ok=rates_ok and (row.rate as Vector3).is_equal_approx(Vector3(-0.05,0.1,0.1))
		check(rates_ok,"real ordinary/heroic FX emitter uses original 0.1 radial growth, heroic="+str(heroic))
		for time in [0.1,0.5,1.1]:
			effect.age=time;effect._sample()
			var scales: Array=[]
			var bounded:=true
			for row in waves:
				if not row.node.visible:continue
				var size_: Vector3=row.node.scale
				# Native update adds rate then damps rate by .95: radial scale < .1/(1-.95)=2.
				bounded=bounded and size_.y<2.001 and size_.z<2.001
				scales.append([size_.x,size_.y,size_.z])
			check(bounded,"rendered radial scale below native asymptote at "+str(time)+" heroic="+str(heroic),scales)
			measurements.append({"heroic":heroic,"age":time,"draw_size":effect.draw_size,"wave_scales":scales})
			stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			for i in 3:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png(output_dir.path_join(("heroic" if heroic else "normal")+"-"+str(time)+".png"))
		effect.free()
	var report:=FileAccess.open(output_dir.path_join("footprints.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements,"\t"));report.close()
	# The shared sampler also consumes a reversed negative fire SizeRate.
	for id in ["R3FUTURE","R3HARBINGER"]:
		var unit=actor(id,"ally",point+Vector2(-220,0))
		unit.hp=unit.max_hp*0.2
		var model=unit._ra3_model;model.set_process(false)
		model.damage_state.tick(0.1)
		var flames: Array=model.damage_state.rows.filter(func(r):return not r.smoke)
		check(not flames.is_empty() and flames.all(func(r):return is_equal_approx(float(r.rate),-0.15)),id+" damaged fire consumes native reversed negative rate")
	screen.free();await get_tree().process_frame
