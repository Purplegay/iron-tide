extends Node
func _ready() -> void:
	get_tree().current_scene=null;call_deferred("run")
func run() -> void:
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))
	if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(3);return
	while get_tree().current_scene==null:await get_tree().process_frame
	var screen=get_tree().current_scene;screen.process_mode=Node.PROCESS_MODE_DISABLED
	var world=screen.battle
	var current=world.path_service;var old=load("res://tests/path_bound_reference.gd").new();old.cols=current.cols;old.rows=current.rows
	var inputs:Array=[];var checks:=0;var failed:=0
	for unit in world.units:
		var grid:PackedFloat32Array=current.water_cost if unit.is_naval else current.cost
		var zones:PackedInt32Array=current.water_zone if unit.is_naval else current.ground_zone
		for point in [unit.position,unit.move_target]:
			var cell:Vector2i=current._cell_of(point)
			for radius in [1,5,12]:
				var expected:Vector2i=old._nearest_walkable(cell,grid,zones,0,radius)
				checks+=1
				if expected!=current._nearest_walkable(cell,grid,zones,0,radius):failed+=1
				inputs.append([cell,grid,zones,radius])
	var timing:Array=[]
	for batch in 8:
		var row:Dictionary={}
		for method in ([old,current] if batch%2==0 else [current,old]):
			var begin:=Time.get_ticks_usec()
			for repeat in 10:
				for input in inputs:method._nearest_walkable(input[0],input[1],input[2],0,input[3])
			row["old_us" if method==old else "new_us"]=Time.get_ticks_usec()-begin
		timing.append(row)
	old.free()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timing":timing,"units":world.units.size(),"buildings":world.buildings.size()},"  "))
	print("PATH_BOUND_SAVED checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
