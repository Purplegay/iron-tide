extends Node
var checks:=0
var failed:=0
func _ready() -> void:
	var old=load("res://tests/path_bound_reference.gd").new()
	var current=load("res://scripts/world/path_service.gd").new()
	var rng:=RandomNumberGenerator.new();rng.seed=811
	var inputs:Array=[]
	for size in [1,3,12,30]:
		old.cols=size;old.rows=size;current.cols=size;current.rows=size
		for layout in 8:
			var grid:=PackedFloat32Array();var zones:=PackedInt32Array();grid.resize(size*size);zones.resize(size*size)
			for index in grid.size():grid[index]=-1.0 if rng.randf()<0.75 else 0.0;zones[index]=rng.randi_range(1,3)
			for sample in 40:
				var point:=Vector2i(rng.randi_range(-size,size*2),rng.randi_range(-size,size*2))
				for radius in [-1,0,1,4,12]:
					for zone in [0,1,2,3]:
						checks+=1
						if old._nearest_walkable(point,grid,zones,zone,radius)!=current._nearest_walkable(point,grid,zones,zone,radius):failed+=1
				inputs.append([size,point,grid,zones])
	var timings:Array=[]
	for batch in 8:
		var row:Dictionary={}
		for version in ([old,current] if batch%2==0 else [current,old]):
			var begin:=Time.get_ticks_usec();var sum:=Vector2i.ZERO
			for repeat in 2:
				for input in inputs:
					version.cols=input[0];version.rows=input[0]
					sum+=version._nearest_walkable(input[1],input[2],input[3],2,12)
			row["old_us" if version==old else "new_us"]=Time.get_ticks_usec()-begin
			row["old_sum" if version==old else "new_sum"]=str(sum)
		timings.append(row)
	old.free();current.free()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timing":timings},"  "))
	print("PATH_BOUND checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
