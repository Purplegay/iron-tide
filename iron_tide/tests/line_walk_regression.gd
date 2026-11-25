extends Node
var checks := []
var failed := 0
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failed += 1
func _ready() -> void:
	var old = preload("res://tests/line_walk_reference.gd").new()
	var current = PathService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 734112
	var query_a := PackedVector2Array()
	var query_b := PackedVector2Array()
	for dims in [Vector2i(1,1),Vector2i(1,31),Vector2i(31,1),Vector2i(17,23),Vector2i(96,96)]:
		for scale in [1.0,40.0,55.5]:
			old.cols=dims.x;old.rows=dims.y;old.cell=scale
			current.cols=dims.x;current.rows=dims.y;current.cell=scale
			var grid := PackedFloat32Array()
			grid.resize(dims.x*dims.y);grid.fill(1.0)
			for i in 1600:
				var a: Vector2 = Vector2(rng.randf_range(-2,dims.x+2),rng.randf_range(-2,dims.y+2))*scale
				var b: Vector2 = Vector2(rng.randf_range(-2,dims.x+2),rng.randf_range(-2,dims.y+2))*scale
				match i%8:
					0: b=a
					1: b.x=a.x
					2: b.y=a.y
					3: a=a.snapped(Vector2.ONE*scale);b=b.snapped(Vector2.ONE*scale)
					4: b=a+Vector2.ONE*scale*rng.randi_range(-10,10)
				if i%3==0: grid[rng.randi_range(0,grid.size()-1)]=-1.0 if i%6==0 else 1.0
				check(current.line_walkable(a,b,grid)==old.line_walkable(a,b,grid),str([dims,scale,i]))
				if dims==Vector2i(96,96) and scale==40.0:query_a.append(a);query_b.append(b)
	# Independently specified corner and live-grid cases, including reverse travel.
	current.cols=2;current.rows=2;current.cell=40.0
	var corner:=PackedFloat32Array([1,-1,1,1])
	check(not current.line_walkable(Vector2(20,20),Vector2(60,60),corner),"corner blocks")
	check(not current.line_walkable(Vector2(60,60),Vector2(20,20),corner),"reverse corner blocks")
	corner[1]=1
	check(current.line_walkable(Vector2(20,20),Vector2(60,60),corner),"live reopening")
	corner[0]=-1
	check(not current.line_walkable(Vector2(20,20),Vector2(20,20),corner),"blocked origin even zero length")
	old.cols=96;old.rows=96;old.cell=40.0
	current.cols=96;current.rows=96;current.cell=40.0
	var metrics := {}
	for blocked in [false,true]:
		var grid:=PackedFloat32Array();grid.resize(96*96);grid.fill(1.0)
		if blocked:
			for i in grid.size():
				if i%11==0:grid[i]=-1
		var before:=[];var after:=[]
		for round in 7:
			for order in [0,1] if round%2==0 else [1,0]:
				var obj=old if order==0 else current
				var start:=Time.get_ticks_usec()
				for repeat in 8:
					for i in query_a.size(): obj.line_walkable(query_a[i],query_b[i],grid)
				var elapsed:=Time.get_ticks_usec()-start
				if order==0:before.append(elapsed)
				else:after.append(elapsed)
		before.sort();after.sort()
		metrics["blocked" if blocked else "open"]={"before_us":before[3],"after_us":after[3],"queries":query_a.size()*8}
	old.free();current.free()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics}))
	get_tree().quit(0 if failed==0 else 1)
