extends "res://tests/ra3_future_presentation_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	# Frozen world, real lethal hit, then real engine callbacks for debris.
	battle.process_mode=Node.PROCESS_MODE_ALWAYS
	battle.set_process(false);battle.set_physics_process(false);battle.paused=false
	battle.camera.position=Vector2(1800,1800);battle.camera.zoom=Iso.cam_zoom(2)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var tank=actor("R3FUTURE","enemy",Vector2(1800,1800))
	tank.receive_hit(tank.max_hp*100)
	var wrecks=get_tree().get_nodes_in_group("ra3_wrecks")
	check(wrecks.size()==1,"actual lethal damage creates exactly one native wreck")
	var wreck= wrecks[0]
	# Deterministic cosmetic seed for before/after visual evidence, not combat RNG.
	var rng:=RandomNumberGenerator.new();rng.seed=12345
	for part: Dictionary in wreck.parts:
		var piece: Dictionary={"name":part.name,"center":[part.start.x,part.start.y,part.start.z]}
		var motion:=Ra3Wreck.sample_motion(Ra3Wreck.dynamics.future,piece,Vector3.ZERO,rng)
		for key in motion:part[key]=motion[key]
	wreck.age=0.0;wreck._process(0)
	await capture(stage,"future-death-start")
	await get_tree().create_timer(2.6).timeout
	check(not is_instance_valid(tank),"dead original actor cannot cover the fragments")
	check(wreck.age>=2.6,"fragment movement advances through actual engine callbacks")
	var separated:=0
	var distances: Array=[]
	for part: Dictionary in wreck.parts:
		var moved:=Vector2(part.node.position.x-part.start.x,part.node.position.z-part.start.z).length()
		var size_: Vector3=part.bounds.size
		var width:=maxf(size_.x,size_.z)
		if moved>width:separated+=1
		distances.append({"bone":part.name,"displacement":moved,"piece_width":width})
	check(separated>=5,"majority of future fragments leave their assembled footprint",distances)
	await capture(stage,"future-death-scattered")
	await capture(wreck.viewport,"future-fragments-only")
	wreck.set_process(false)
	var part: Dictionary=wreck.parts[0]
	wreck.age=float(part.flight_time);wreck._process(0)
	var landing: Vector3=part.node.position
	wreck.age+=0.25;wreck._process(0)
	check(Vector2(part.node.position.x-landing.x,part.node.position.z-landing.z).length()>0.2,"horizontal inertia does not stop instantly on ground contact")
	screen.free();await get_tree().process_frame
