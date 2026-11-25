extends "res://tests/hotspot_round_regression.gd"

func real_bench(old:Callable,current:Callable,inputs:Array) -> Array:
	var batches:Array=[]
	for batch in 8:
		var row:Dictionary={}
		for before in ([true,false] if batch%2==0 else [false,true]):
			var method:Callable=old if before else current
			var total:=0.0
			var start:=Time.get_ticks_usec()
			for repeat in 100:
				for input in inputs:total+=float(method.call(input))
			row["original_us" if before else "candidate_us"]=Time.get_ticks_usec()-start
			row["original_sum" if before else "candidate_sum"]=total
		check(row.original_sum==row.candidate_sum,"saved benchmark equal answers")
		batches.append(row)
	return batches

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	var save:=OS.get_environment("IRON_HOTSPOT_SAVE")
	if output.is_empty() or save.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	check(DirAccess.copy_absolute(save,ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))==OK,"copy frozen input")
	check(BattleSaves.prepare_load("slot1").ok,"real save validation")
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	var world:Battle=screen.battle
	world.paused=true
	check(world.units.size()==269 and world.buildings.size()==199,"exact slot1 population")
	var first:=0;var second:=0
	var inputs:Array=world.units.duplicate()
	var ai_inputs:Array=[]
	var flag_inputs:Array=[]
	var hull_inputs:Array=[]
	var old_queue:=Ref4.new();var new_queue:=Dispatch.new()
	var a:=Battle.new();var b:=Battle.new()
	retained.append_array([a,b])
	a.allied_state=world.allied_state.duplicate(true);b.allied_state=world.allied_state.duplicate(true)
	for actor:Unit in inputs:
		if actor.special.has("progression_v1"):first+=1
		if actor.special.has("progression_v2"):second+=1
		compare(Ref1.speed,Progress.speed,actor,"saved progression speed")
		compare(Ref2.speed_factor,Expedition.speed_factor,actor,"saved expedition speed")
		check(Ref3.source(actor)==AlliedAbilities.source(actor),"saved capabilities")
		for key in ["Teleporter","DetectDisguise","ImmuneToPsionics","OpenTopped"]:
			check(Ref3.flag(actor,key)==AlliedAbilities.flag(actor,key),"saved capability flags")
			flag_inputs.append([actor,key])
		if BattleRequest.is_ai_house(actor.side):
			ai_inputs.append(actor)
			check(old_queue._entry(a,actor)==new_queue._entry(b,actor),"saved AI entries")
		var old:=Ref5.new();retained.append(old)
		for key in ["unit_id","special","_deployed","is_air","is_naval","is_harvester","data","weapon"]:old.set(key,actor.get(key))
		old._mv_cache=actor._mv_cache.duplicate()
		check(old._weapon_uses_hull()==actor._weapon_uses_hull(),"saved hull result")
		check(old._mv_cache==actor._mv_cache,"saved hull cache effects")
		hull_inputs.append([old,actor])
	var rounds:Array=[]
	rounds.append({"round":1,"timings":real_bench(Ref1.speed,Progress.speed,inputs)})
	rounds.append({"round":2,"timings":real_bench(Ref2.speed_factor,Expedition.speed_factor,inputs)})
	rounds.append({"round":3,"timings":real_bench(func(pair):return Ref3.flag(pair[0],pair[1]),func(pair):return AlliedAbilities.flag(pair[0],pair[1]),flag_inputs)})
	rounds.append({"round":4,"timings":real_bench(func(actor):return old_queue._entry(a,actor).size(),func(actor):return new_queue._entry(b,actor).size(),ai_inputs)})
	rounds.append({"round":5,"timings":real_bench(func(pair):return pair[0]._weapon_uses_hull(),func(pair):return pair[1]._weapon_uses_hull(),hull_inputs)})
	var population:Dictionary={"units":inputs.size(),"buildings":world.buildings.size(),"ai_units":ai_inputs.size(),"progression_v1":first,"progression_v2":second}
	for actor in retained:actor.free()
	screen.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"check_count":check_count,"failed":failed,"failures":failures,"population":population,"rounds":rounds}))
	print("SAVED_HOTSPOTS_RESULT ",check_count," checks ",failed," failed ",population)
	get_tree().quit(0 if failed==0 else 1)
