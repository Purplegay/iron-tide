extends Node
const TimerProbe=preload("res://timer.gd")
var out:String
var result={}
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	out=OS.get_environment("IRON_OUT")
	if DisplayServer.get_name()!="headless" or not OS.get_user_data_dir().contains("CodexIronTideValidation") or out.is_empty():
		get_tree().quit(2)
		return
	get_tree().current_scene=null
	run.call_deferred()
func run():
	var maps=["yr_isleland","yr_ice_age"]
	for game in 2:
		seed(713+game)
		var rows=[]
		for i in 6: rows.append({"country":"美国" if (i+game)%2==0 else "苏俄","team":1 if i%2==0 else 2,"difficulty":6})
		rows[0].erase("difficulty")
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":maps[game],"difficulty":6,"starting_funds":12000,"fog_of_war":true})
		var screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		var world=screen.battle
		# Test-only autopilot for the player's seat: all six sides use real AI production.
		world.allied_state.house_ai.ally={"center":world.player_start(),"think":0.5,"attack":20.0}
		var pilot=preload("res://scripts/world/house_ai.gd").new()
		pilot.house_id="ally"
		pilot.homes={}
		for side in world.allied_state.house_ai: pilot.homes[side]=world.allied_state.house_ai[side].center
		pilot.setup(world,6,world.roster_faction("ally"),world.player_start())
		pilot.rally=pilot.base_center.move_toward(Vector2.ONE*world.map_size*0.5,180.0)
		world.house_controllers.ally=pilot
		world.add_child(pilot)
		for ai in world.house_controllers.values(): ai._rng.seed=713+game*17+str(ai.house_id).hash()
		world.paused=false
		get_tree().paused=false
		BattleClock.set_speed(3)
		var begin=Time.get_ticks_usec()
		var last=begin
		var next_report=30.0
		var next_save=300.0
		var samples=[]
		var windows=[]
		var peak_units=0
		TimerProbe.costs.clear()
		TimerProbe.calls.clear()
		print("START ",game," ",maps[game]," houses=",world.house_controllers.keys())
		while not world.ended and world.fog.sight_clock<1800 and Time.get_ticks_usec()-begin<1000000000:
			await get_tree().process_frame
			var now=Time.get_ticks_usec()
			samples.append((now-last)/1000.0)
			last=now
			if world.fog.sight_clock>=next_report:
				samples.sort()
				var counts={}
				for u in world.units:
					if world.actor_alive(u):counts[u.side]=int(counts.get(u.side,0))+1
				peak_units=maxi(peak_units,world.units.size())
				var win={"sim":world.fog.sight_clock,"wall":(now-begin)/1000000.0,"p95":samples[ceili(samples.size()*.95)-1],"max":samples.back(),"units":world.units.size(),"buildings":world.buildings.size(),"counts":counts,"costs":TimerProbe.costs.duplicate(),"calls":TimerProbe.calls.duplicate(),"paths":world.path_service.stats_paths,"hz":Engine.physics_ticks_per_second}
				windows.append(win)
				print("WINDOW ",game," sim=",roundi(win.sim)," wall=",roundi(win.wall)," p95=",win.p95," units=",win.units," counts=",counts)
				FileAccess.open(out.path_join("progress.json"),FileAccess.WRITE).store_string(JSON.stringify({"game":game,"windows":windows}))
				samples.clear()
				TimerProbe.costs.clear()
				TimerProbe.calls.clear()
				next_report+=30
				if world.fog.sight_clock>=next_save and not world.ended:
					var saved=BattleSaves.save_slot(world,"quick")
					if saved.ok: DirAccess.copy_absolute(ProjectSettings.globalize_path(BattleSaves.slot_path("quick")),out.path_join("game%d_%d.itsave"%[game,int(next_save)]))
					print("CHECKPOINT ",game," ",next_save," ",saved)
					next_save+=300
					last=Time.get_ticks_usec()
					TimerProbe.costs.clear()
					TimerProbe.calls.clear()
		result[str(game)]={"map":maps[game],"ended":world.ended,"sim":world.fog.sight_clock,"wall":(Time.get_ticks_usec()-begin)/1000000.0,"peak_units":peak_units,"windows":windows}
		FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
		print("END ",game," ended=",world.ended," sim=",world.fog.sight_clock)
		screen.free()
		await get_tree().process_frame
		get_tree().paused=false
	get_tree().quit()
