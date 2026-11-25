extends Node
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out = OS.get_environment("IRON_OUT")
	var file = OS.get_environment("IRON_SAVE")
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") or file.is_empty(): get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(file,ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))
	get_tree().current_scene=null
	seed(12345)
	var loaded=BattleSaves.load_into_scene("slot1")
	print("LOAD ",file," ",loaded)
	if not loaded.ok:get_tree().quit(3);return
	await get_tree().process_frame
	await get_tree().process_frame
	var world=get_tree().current_scene.battle
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var report={"memory_load":memory_sample(),"units":world.units.size(),"buildings":world.buildings.size(),"layout":world.map_layout(),"difficulty":world.skirmish_difficulty,"roster":{},"phases":{}}
	var squad=[]
	var variant=OS.get_environment("IRON_VARIANT")
	var flyers={}
	for u in world.units:
		report.roster[u.unit_id]=report.roster.get(u.unit_id,0)+1
		if u.is_air or u.unit_id=="JUMPJET":
			flyers[u.unit_id]=1+flyers.get(u.unit_id,0)
			if variant=="no_air_sim":u.set_physics_process(false)
			if variant=="no_air_art":
				u.visibility_layer=0
				for child in u.find_children("*","CanvasItem",true,false):child.visibility_layer=0
		if u.side=="ally" and not u.is_harvester and not u.is_air and not u.is_naval and not u._deployed and u.embarked_in==null:squad.append(u)
	print("AIR ",flyers)
	print("WORLD ",report," playersquad ",squad.size())
	BattleClock.set_speed(1);world.paused=false;get_tree().paused=false
	var warmup=world.fog.sight_clock+4
	while world.fog.sight_clock<warmup:await get_tree().process_frame
	for phase in ["battle","selection","move"]:
		var paths_before=world.path_service.stats_paths
		squad=squad.filter(func(u):return is_instance_valid(u) and not u._dead)
		if phase=="selection":
			world.clear_selection()
			for u in squad:world.select_unit(u,true)
			if not squad.is_empty():world.center_on_selection()
		if phase=="move" and not squad.is_empty():world._command_move(squad[0].position + Vector2(420,70))
		var samples=[];var shots=0;var elapsed=world.fog.sight_clock;var phys=Engine.get_physics_frames();var wall=Time.get_ticks_msec()
		while world.fog.sight_clock-elapsed < 15:
			var begin=Time.get_ticks_usec()
			await get_tree().process_frame
			samples.append((Time.get_ticks_usec()-begin)/1000.0)
			shots=maxi(shots,world.projectiles_root.get_child_count())
		samples.sort()
		report.phases[phase]={"wall_s":(Time.get_ticks_msec()-wall)/1000.0,"sim_s":world.fog.sight_clock-elapsed,"physics_steps":Engine.get_physics_frames()-phys,"hz":Engine.physics_ticks_per_second,"frames":samples.size(),"paths":world.path_service.stats_paths-paths_before,"p50":samples[samples.size()/2],"p95":samples[ceili(samples.size()*0.95)-1],"p99":samples[ceili(samples.size()*0.99)-1],"max":samples[-1],"shots":shots,"selected":world.selected_units.size(),"memory":memory_sample()}
		print("PHASE ",phase," ",report.phases[phase])
	get_tree().current_scene.free()
	await get_tree().process_frame
	report.memory_after_exit=memory_sample()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	get_tree().quit()

func memory_sample() -> Dictionary:
	return {"static_mb":OS.get_static_memory_usage()/1048576.0,"peak_mb":OS.get_static_memory_peak_usage()/1048576.0,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"art_cpu_images":art_memory(),"detail_cache_mb":preload("res://scripts/core/shp_detail.gd")._bytes/1048576.0,"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}

func art_memory() -> Array:
	var rows=[]
	for id in RA2Art._cache:
		var art:Dictionary=RA2Art._cache[id]
		var img:Image=art.get("img")
		if img!=null:rows.append([id,img.get_width()*img.get_height()*4/1048576.0])
	rows.sort_custom(func(a,b):return a[1]>b[1])
	return rows
