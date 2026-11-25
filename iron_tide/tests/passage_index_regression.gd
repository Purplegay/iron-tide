extends "res://tests/base_recovery_regression.gd"
const Current = preload("res://scripts/world/vehicle_passages.gd")
const Reference = preload("res://tests/vehicle_passages_reference.gd")
var timing := {}
var routed := 0
var denied := 0

func rectangle(passage, center: Vector2, size: Vector2) -> void:
	var half := size * 0.5
	passage.add_shape(center, PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]),half.length(),40.0)

func populate(passage, ground: PackedFloat32Array, width: float, crowded: bool) -> void:
	passage.reset(ground)
	rectangle(passage,Vector2(1200,1000-width*0.5-75),Vector2(120,150))
	rectangle(passage,Vector2(1200,1000+width*0.5+75),Vector2(120,150))
	if crowded:
		for y in 16:
			for x in 16:
				rectangle(passage,Vector2(2300+x*120,2300+y*120),Vector2(80,80))

func compare(current, prior, service, from: Vector2, to: Vector2, radius: float, blockers: Array) -> void:
	var expected: PackedVector2Array = prior.route(service,from,to,radius,blockers)
	var actual: PackedVector2Array = current.route(service,from,to,radius,blockers)
	check(actual == expected,"exact passage path, order and collision",[from,to,radius,expected,actual] if actual!=expected else null)
	if actual.size()>2: routed+=1
	if actual.is_empty(): denied+=1
	var travel := from.direction_to(to)
	var candidates: Array[int] = current._gate_candidates(from,to,travel)
	var last := -1
	for index in candidates:
		check(index>last,"candidate insertion order")
		last=index
	for index in prior.gates.size():
		var gate:Dictionary=prior.gates[index]
		if gate.width<=radius*2:continue
		var axis:Vector2=gate.axis
		var along:=travel.dot(axis)
		if absf(along)<0.6:continue
		if along<0:axis=-axis
		var entry:Vector2=(gate.a if along>0 else gate.b)-axis*(radius+20)
		var end:Vector2=(gate.b if along>0 else gate.a)+axis*(radius+20)
		if (entry-from).dot(axis)>=0 and (to-end).dot(axis)>=0:
			check(index in candidates,"all original eligible gates retained")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var current:=Current.new()
	var prior:=Reference.new()
	var service:=PathService.new()
	service.map_size=4800;service.cols=120;service.rows=120
	service.cost.resize(14400);service.cost.fill(-1.0)
	var ground:=PackedFloat32Array();ground.resize(14400);ground.fill(1.0)
	var rng:=RandomNumberGenerator.new();rng.seed=20261118
	for crowded in [false,true]:
		for width in [26.0,38.0,52.0,92.0]:
			populate(current,ground,width,crowded);populate(prior,ground,width,crowded)
			for radius in [0.0,12.0,19.0,26.0]:
				for reverse in [false,true]:
					for offset in [-35.0,-20.0,0.0,20.0,35.0]:
						var from:=Vector2(900,1000+offset);var to:=Vector2(1500,1000+offset)
						compare(current,prior,service,to if reverse else from,from if reverse else to,radius,[])
						compare(current,prior,service,to if reverse else from,from if reverse else to,radius,[{"position":Vector2(1200,1000),"radius":30.0}])
			for i in 50:
				var from:=Vector2(rng.randf_range(1,4799),rng.randf_range(1,4799))
				var to:=Vector2(rng.randf_range(1,4799),rng.randf_range(1,4799))
				compare(current,prior,service,from,to,12.0,[])
			# Add geometry after the index has already been queried, then query again.
			for passage in [current,prior]:rectangle(passage,Vector2(1200,1000),Vector2(12,12))
			compare(current,prior,service,Vector2(900,1020),Vector2(1500,1020),12.0,[])
	check(routed>0 and denied>0,"exercise successful detours and rejections",[routed,denied])
	populate(current,ground,52,true);populate(prior,ground,52,true)
	var before:Array=[];var after:Array=[]
	for batch in 20:
		for passage in ([prior,current] if batch%2==0 else [current,prior]):
			var started:=Time.get_ticks_usec()
			for repeat in 100:
				passage.route(service,Vector2(900,1020),Vector2(1500,1020),12.0,[])
			(before if passage==prior else after).append((Time.get_ticks_usec()-started)/1000.0)
	before.sort();after.sort()
	timing={"old_ms":before[9],"new_ms":after[9],"routes_per_batch":100,"gates":prior.gates.size(),"routed":routed,"denied":denied}
	service.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timing":timing}))
	get_tree().quit(0 if failed==0 else 1)
