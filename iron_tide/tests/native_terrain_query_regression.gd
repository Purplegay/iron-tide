extends Node
const Maps=preload("res://scripts/world/native_maps.gd")
var count:=0
var failed:=0
var failures:Array=[]
var timings:Array=[]

# Frozen original query, including live bridge precedence and map bounds.
func original(service:PathService,point:Vector2) -> int:
	var cell:=Vector2i((point/Maps.CELL).floor())
	if service.bridge_flags.has(cell):return int(service.bridge_flags[cell])
	return Maps.flags(service.native_map_id,point)

func check(ok:bool,label:String) -> void:
	count+=1
	if not ok:
		failed+=1
		if failures.size()<20:failures.append(label)

func compare(service:PathService,point:Vector2) -> void:
	check(original(service,point)==service.native_flags(point),"%s/%s"%[service.native_map_id,point])

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	var service:=PathService.new()
	for id in Maps.IDS:
		service.native_map_id=id
		var row:=Maps.data(id)
		var side:int=int(row.side)
		for y in side:
			for x in side:
				var point:=Vector2(x,y)*Maps.CELL
				compare(service,point)
				compare(service,point+Vector2.ONE*(Maps.CELL-.001))
		for x in [-55.0,-.001,0.0,.001,54.999,55.0,55.001,side*55.0-.001,side*55.0,side*55.0+.001]:
			for y in [-55.0,-.001,0.0,54.999,55.0,55.001,side*55.0-.001,side*55.0,side*55.0+.001]:compare(service,Vector2(x,y))
		var bridge:=Vector2i(2,2)
		var point:Vector2=(Vector2(bridge)+Vector2.ONE*.5)*Maps.CELL
		for flag in [0,1,2,3,4]:
			service.set_bridge_damage({bridge:flag,Vector2i(-1,-1):flag},[])
			compare(service,point);compare(service,Vector2(-1,-1))
			service.bridge_flags[bridge]=3-flag
			compare(service,point)
			service.bridge_flags.erase(bridge);compare(service,point)
		service.set_bridge_damage({},[])
		compare(service,point)
		# The map row remains shared: even a replaced mask is observed immediately.
		var before:PackedByteArray=row.mask
		var changed:=before.duplicate();changed[side*2+2]=4
		row.mask=changed;compare(service,point)
		row.mask=before;compare(service,point)
	# Revisit every map to catch same-sized and different-sized map switches.
	for id in Maps.IDS:
		service.native_map_id=id;compare(service,Vector2(110,110))
	service.native_map_id="yr_isleland"
	var points:Array[Vector2]=[]
	for i in 400:points.append(Vector2((i*13)%100,(i*37)%100)*55.0+Vector2(13,27))
	for batch in 8:
		var row:Dictionary={}
		for old in ([true,false] if batch%2==0 else [false,true]):
			var start:=Time.get_ticks_usec()
			var checksum:=0
			for repeat in 100:
				for point in points:checksum+=original(service,point) if old else service.native_flags(point)
			row["original_us" if old else "candidate_us"]=Time.get_ticks_usec()-start
			row["original_sum" if old else "candidate_sum"]=checksum
		check(row.original_sum==row.candidate_sum,"benchmark same answers")
		timings.append(row)
	service.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"check_count":count,"failed":failed,"failures":failures,"timings":timings}))
	print("TERRAIN_QUERY_RESULT ",count," checks, ",failed," failed ",failures)
	get_tree().quit(0 if failed==0 else 1)
