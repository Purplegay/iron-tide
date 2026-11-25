extends "res://tests/allied_abilities_regression.gd"
const Soviet = preload("res://scripts/units/ra3_soviet.gd")
const Beam = preload("res://scripts/units/ra3_tank_beam.gd")

func exercise_mode(mode: String) -> void:
	if mode != MatchRules.EXTENDED: return
	setup_logistics_scene(mode, "苏俄")
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var point: Vector2 = Vector2(2100, 1500)
	battle.camera.global_position = point
	battle.camera.force_update_scroll()
	battle.effects_root.process_mode = Node.PROCESS_MODE_ALWAYS
	var tank = actor("R3APOC", "ally", point)
	var target = battle._place_building("GAPOWR", "enemy", point + Vector2(70,0), true)
	target._process(GameData.ra2_buildup_seconds()+0.1)
	target.hp = 100000
	target.max_hp = target.hp
	tank.hull_angle = tank.position.angle_to_point(target.position)
	tank.turret_angle = tank.hull_angle
	Soviet.use(tank, tank.position)
	for frame in 15: await get_tree().process_frame
	check(battle.get_viewport_rect().has_point(battle.get_global_transform_with_canvas()*target.position),"grinder target is on screen")
	await sample("idle",tank,60,false)
	tank.attack_ordered = true
	tank.attack_target = target
	check(Soviet.fire(tank),"building hooked")
	Beam.spawn(tank,target,true)
	await sample("grind",tank,150,true)
	check(target.hp < 99950 and tank.special.get("crush_contact",0)>1,"sustained grinder pulses hit building")
	tank.special.erase("harpoon_target")
	await sample("release",tank,60,false)
	var victim = actor("HTNK","enemy",point+Vector2(135,0))
	tank.attack_target = victim
	tank.hull_angle = tank.position.angle_to_point(victim.position)
	tank.turret_angle = tank.hull_angle
	check(Soviet.fire(tank),"vehicle hooked")
	Beam.spawn(tank,victim,true)
	await sample("pull_and_crush",tank,200,true)
	check(not AlliedAbilities.alive(victim),"vehicle pulled and crushed")
	if DisplayServer.get_name() != "headless":
		await check_spark_pixels(point)
	screen.free()
	await get_tree().process_frame

func sample(label:String,tank,frames:int,attack:bool) -> void:
	var times:Array[float]=[]
	var peak_nodes:=0
	var nodes_before:=get_tree().get_node_count()
	for i in frames:
		var begin:=Time.get_ticks_usec()
		if attack:Soviet.tick(tank,1.0/60)
		await get_tree().process_frame
		times.append((Time.get_ticks_usec()-begin)/1000.0)
		peak_nodes=maxi(peak_nodes,get_tree().get_node_count()-nodes_before)
	if label == "grind": check(peak_nodes < 1000,"continuous cutting stays below prior particle-node spike",peak_nodes)
	times.sort()
	print("GRIND_PROFILE ",label," median/p95/max ms ",[times[frames/2],times[int(frames*.95)],times[-1]]," extra_nodes ",peak_nodes)


func check_spark_pixels(point: Vector2) -> void:
	var fx = preload("res://scripts/units/ra3_apocalypse_grind.gd").new()
	var data = preload("res://scripts/units/ra3_tank_fx.gd").bank.particles.Sov_Apoc_TB_Grind
	fx.setup(battle,point,0,data,preload("res://assets/ra3/soviet/tank_fx/FXWhiteTest3.png"))
	fx.set_process(false)
	var view := SubViewport.new()
	view.world_2d = World2D.new()
	view.size = Vector2i(480,480)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	fx.reparent(view,false)
	fx.position = Vector2(240,280)
	fx.visible = true
	fx.material.set_shader_parameter("age",8.5)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var lit := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r > 0.08: lit += 1
	check(lit > 30,"batched spark trails produce visible pixels",lit)
	fx._process(2.0)
	check(fx.is_queued_for_deletion(),"last spark expires")
	view.free()
