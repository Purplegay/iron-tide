extends Node
const Fog=preload("res://scripts/world/fog_of_war.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label})
	if not ok: failed+=1;print("FAIL ",label)
func _ready():
	run.call_deferred()
func run():
	var random:=RandomNumberGenerator.new();random.seed=713
	var batch=Fog.SightBatch.new();batch.width=128
	var old:=Image.create(128,128,false,Image.FORMAT_LA8)
	batch.mask=Image.create(128,128,false,Image.FORMAT_LA8)
	var old_times:Array=[];var new_times:Array=[]
	for step in 40:
		batch.points.clear();batch.radii.clear()
		for i in 128:
			var point:=Vector2((i%16)*320,(i/16)*640)
			if i%4==0: point+=Vector2(random.randf_range(-80,80),random.randf_range(-80,80))
			batch.points.append(point)
			batch.radii.append(40.0+float(i%12)*19.125+float(step%3))
		# Same point, distinct radii, negative/off-map, tangent and zero radius.
		for p in [Vector2.ZERO,Vector2(-40,80),Vector2(5200,5200),Vector2(5119.999,80)]:
			for r in [0.0,40.0,40.000001,200.0]:batch.points.append(p);batch.radii.append(r)
		old.fill(Color.TRANSPARENT);batch.mask.fill(Color.TRANSPARENT)
		for i in batch.points.size():Fog.SightBatch.raster_disc(old,128,batch.points[i],batch.radii[i])
		batch.rasterize()
		check(old.get_data()==batch.mask.get_data(),"exact union cells step "+str(step))
		check(batch.tiles.size()<=batch.points.size(),"cache bounded to current footprints "+str(step))
	for pass_index in 12:
		for variant in ([0,1] if pass_index%2==0 else [1,0]):
			var start:=Time.get_ticks_usec()
			for repeat in 100:
				if variant==0:
					old.fill(Color.TRANSPARENT)
					for i in batch.points.size():Fog.SightBatch.raster_disc(old,128,batch.points[i],batch.radii[i])
				else:batch.mask.fill(Color.TRANSPARENT);batch.rasterize()
			var elapsed:=(Time.get_ticks_usec()-start)/1000.0
			if variant==0:old_times.append(elapsed)
			else:new_times.append(elapsed)
	check(old.get_data()==batch.mask.get_data(),"timed batches remain byte identical")
	batch.points=PackedVector2Array();batch.radii=PackedFloat64Array();batch.rasterize()
	check(batch.tiles.is_empty(),"removed scouts evicted")
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"metrics":{"old_ms":old_times,"new_ms":new_times}},"\t"))
	get_tree().quit(0 if failed==0 else 1)
