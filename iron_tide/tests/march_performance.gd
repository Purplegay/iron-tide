extends Node
## Controlled march/render workload. Use an isolated profile and desktop.
## Compare snapshots with identical content; never compare directly to a different save.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	var requested := OS.get_environment("IRON_MARCH_COUNT")
	var count := 60 if requested.is_empty() else clampi(int(requested),20,60)
	seed(12345)
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":4000,"starting_funds":12000,"enemy_base":"allied","fog_of_war":true})
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world=screen.battle
	for i in count:
		var unit=world.spawn_unit("E1","ally",Vector2(1300+(i%10)*32,1300+(i/10)*32))
		unit.set_meta("march",true)
	for i in 20:world.spawn_unit("E2","enemy",Vector2(2900+(i%10)*32,2900+(i/10)*32))
	await get_tree().process_frame
	await get_tree().process_frame
	print("ACTORS ",world.units.size()," ",world.buildings.size())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world.paused=false
	get_tree().paused=false
	world.clear_selection()
	if world.skirmish_ai != null:world.skirmish_ai.set_process(false)
	for u in world.units:u.set_fire_stance("none")
	for u in world.units:
		if u.side=="ally" and not u.is_harvester and not u.is_air and not u.is_naval and u.has_meta("march"):
			u.set_deployed(false,false)
			world.select_unit(u,true)
	world.center_on_selection()
	print("SELECTED ",world.selected_units.size())
	for i in 45:await get_tree().process_frame
	var samples:Array=[]
	var origin:=Vector2(1300,1300)
	for leg in 4:
		world._command_move(origin+Vector2(500 if leg%2==0 else 0,100 if leg<2 else -100))
		for frame in 180:
			var t:=Time.get_ticks_usec()
			await get_tree().process_frame
			var row:Dictionary={}
			row.frame_ms=(Time.get_ticks_usec()-t)/1000.0
			row.moving=world.selected_units.filter(func(u):return is_instance_valid(u) and u.velocity.length_squared()>16.0).size()
			row.leg=leg
			row.frame=frame
			samples.append(row)
	var f:=FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("samples.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(samples))
	get_tree().quit()
