extends Node

func _ready() -> void:
	get_tree().current_scene = null
	run.call_deferred()

func run() -> void:
	if not OS.get_user_data_dir().contains("it-gatling-161318"):
		get_tree().quit(2)
		return
	if not BattleSaves.load_into_scene("quick").ok:
		get_tree().quit(2)
		return
	while get_tree().current_scene == null: await get_tree().process_frame
	var world = get_tree().current_scene.battle
	var guns: Array = []
	for actor in world.units + world.buildings:
		if (actor is Unit and actor.unit_id == "YTNK") or (actor is Building and actor.building_id == "YAGGUN"): guns.append(actor)
	print("SAVED_GUNS ", guns.size(), " camera ",world.camera.position," mission ", world.mission.get("id"))
	AudioServer.add_bus()
	var bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"GatlingCapture")
	var capture := AudioEffectCapture.new()
	capture.buffer_length=20
	AudioServer.add_bus_effect(bus,capture)
	var cannon = guns.filter(func(a):return a is Building and a.is_operational())[0]
	var victim := ForceFirePoint.new()
	victim.global_position = cannon.position + Vector2(80,0)
	cannon.special[ForceFire.KEY]=victim
	cannon.attack_target=victim
	world.camera.position=cannon.position
	get_tree().paused=false
	world.paused=false
	var start := Time.get_ticks_msec()
	var tracked = cannon
	var attached := false
	var next_log := 0
	while Time.get_ticks_msec()-start < 15000:
		await get_tree().process_frame
		if Time.get_ticks_msec()-start >= next_log:
			next_log += 1000
			var p=cannon.get_node_or_null("GatlingReport")
			print("STATE ",world.camera.position," target ",cannon.attack_target==victim," cd ",cannon._cd," player ",[p.playing,p.report,p.remaining,p.releasing] if p!=null else [])
		for actor in guns:
			if not is_instance_valid(actor): continue
			var sound = actor.get_node_or_null("GatlingReport")
			if sound != null and sound.bus != "GatlingCapture" and (tracked == null or actor == tracked):
				tracked = actor
				attached = true
				world.camera.position = actor.position
				sound.bus="GatlingCapture"
				print("TRACK ",Time.get_ticks_msec()-start," ",actor.position," ",sound.report)
	var audio := capture.get_buffer(capture.get_frames_available())
	var file := FileAccess.open(OS.get_environment("IRON_CAPTURE"),FileAccess.WRITE)
	file.store_buffer(audio.to_byte_array())
	print("CAPTURE ",audio.size()," rate ",AudioServer.get_mix_rate()," dropped ",capture.get_discarded_frames())
	get_tree().quit(0 if attached else 1)
