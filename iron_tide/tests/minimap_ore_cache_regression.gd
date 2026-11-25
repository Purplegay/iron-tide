extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/minimap_ore_reference.gd")
var metrics:Array=[]
var before
var after
var ores:Array[ResourceNode]=[]

func compare(projection:Transform2D,label:String) -> void:
	before._refresh_ore_marks(projection)
	after._refresh_ore_marks(projection)
	check(before._ore_marks==after._ore_marks and before._ore_signature==after._ore_signature,label)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog)
		battle.fog.setup(battle)
		before=Reference.new();before.battle=battle
		after=MiniMap.new();after.battle=battle
		ores=[]
		for i in 1006:
			var ore:=ResourceNode.new()
			ore.position=Vector2(40+(i%42)*49,40+(i/42)*53)
			battle.add_child(ore);ore.set_process(false)
			ores.append(ore)
		var fog=battle.fog
		fog.explored_cells.ally.fill(1);fog.visible_cells.ally.fill(0)
		var projection:=Transform2D(Vector2(.05,0),Vector2(0,.03),Vector2(5,3))
		compare(projection,mode+" initial 1006 ore markers")
		for phase in 6:
			for i in fog.visible_cells.ally.size():
				fog.visible_cells.ally[i]=int((i+phase)%3==0)
				fog.explored_cells.ally[i]=int((i+phase)%7!=0)
			compare(projection,mode+" live fog visibility/exploration "+str(phase))
		for i in range(0,ores.size(),7):ores[i].amount=0
		compare(projection,mode+" depletion")
		for i in range(0,ores.size(),7):ores[i].amount=20
		compare(projection,mode+" regrowth")
		ores[0].position+=Vector2(100,100)
		projection.origin+=Vector2(1,0)
		compare(projection,mode+" relocation with reclustering")
		check(after._ore_source_points[0]==ores[0].global_position,mode+" movement invalidates cached source coordinates")
		battle.position+=Vector2(30,40)
		projection.origin+=Vector2(1,0)
		compare(projection,mode+" parent transform")
		check(after._ore_source_points[0]==ores[0].global_position,mode+" battle transform invalidates global coordinates")
		var removed=ores.pop_back();removed.free()
		compare(projection,mode+" removed node")
		var added:=ResourceNode.new();added.position=Vector2(600,600);battle.add_child(added)
		compare(projection,mode+" added node")
		var foreign:=Node2D.new();battle.add_child(foreign)
		added.reparent(foreign)
		compare(projection,mode+" foreign parent falls back")
		check(not after._ore_sources_owned,mode+" foreign sources are never retained without notifications")
		foreign.position+=Vector2(100,0);projection.origin+=Vector2(1,0)
		compare(projection,mode+" foreign parent movement")
		added.reparent(battle);foreign.free()
		battle.fog=null
		compare(projection,mode+" fog disabled")
		battle.fog=fog
		compare(projection,mode+" fog restored")
		for angle in [0.0,.3,-.3]:
			compare(projection.rotated(angle),mode+" rotated radar projection")
		benchmark(projection,mode)
		after.free();before=null
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics},"  "))
	get_tree().quit(0 if failed==0 else 1)

func benchmark(projection:Transform2D,mode:String) -> void:
	compare(projection,mode+" warm benchmark")
	var old_times:Array=[];var new_times:Array=[]
	for batch in 11:
		for variant in ([0,1] if batch%2==0 else [1,0]):
			var started:=Time.get_ticks_usec()
			for repeat in 100:
				if variant==0:before._refresh_ore_marks(projection)
				else:after._refresh_ore_marks(projection)
			var elapsed:=Time.get_ticks_usec()-started
			if variant==0:old_times.append(elapsed)
			else:new_times.append(elapsed)
		check(before._ore_marks==after._ore_marks,mode+" unchanged fog inputs preserve exact marker output")
	old_times.sort();new_times.sort()
	metrics.append({"mode":mode,"refreshes_per_batch":100,"before_us":old_times,"after_us":new_times,"before_p50_us":old_times[5],"after_p50_us":new_times[5]})
