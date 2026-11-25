extends Node
const Reference=preload("res://tests/six_traffic_reference.gd")
var checks:Array=[]
var failed:=0
var saved:Array=[]
var movers:Array=[]
var probes:Array=[]
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label})
	if not ok:failed+=1;print("FAIL ",label)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	run.call_deferred()
func restore():
	for row in saved:
		row.unit.velocity=row.velocity
		row.unit._local_traffic.yield_target=row.target
		row.unit._local_traffic.yield_left=row.left
		row.unit._local_traffic.yield_origin=row.origin
	for i in movers.size():
		probes[i].reset()
		probes[i].yield_target=movers[i]._local_traffic.yield_target
		probes[i].yield_left=movers[i]._local_traffic.yield_left
		probes[i].yield_origin=movers[i]._local_traffic.yield_origin
func outcome() -> Array:
	var result:Array=[]
	for row in saved:
		var unit:Unit=row.unit
		result.append([unit.velocity,unit._local_traffic.yield_target,unit._local_traffic.yield_left,unit._local_traffic.yield_origin])
	return result
func run():
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
	if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
	while get_tree().current_scene==null:await get_tree().process_frame
	get_tree().paused=true
	var world=get_tree().current_scene.battle
	for unit:Unit in world.units:
		if not world.actor_alive(unit):continue
		saved.append({"unit":unit,"velocity":unit.velocity,"target":unit._local_traffic.yield_target,"left":unit._local_traffic.yield_left,"origin":unit._local_traffic.yield_origin})
		if unit.velocity.length_squared()>0.01:
			movers.append(unit);probes.append(Reference.new())
	check(movers.size()>80,"real quick save has moving workload")
	var micro:Array=[]
	var expected:Array=[]
	for pass_index in 20:
		var elapsed:=0
		for repeat in 20:
			restore()
			var begin:=Time.get_ticks_usec()
			for i in movers.size():
				if pass_index%2==0:probes[i].original_apply(movers[i],1.0/15)
				else:probes[i].apply(movers[i],1.0/15)
			elapsed+=Time.get_ticks_usec()-begin
			if repeat==0:
				if pass_index%2==0:expected=outcome()
				else:check(outcome()==expected,"saved velocities and yield decisions identical pass "+str(pass_index))
		micro.append({"variant":"before" if pass_index%2==0 else "after","us":elapsed,"calls":20*movers.size()})
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro,"movers":movers.size(),"units":world.units.size()}))
	get_tree().quit(0 if failed==0 else 1)
