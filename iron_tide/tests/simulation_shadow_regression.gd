extends Node
## Diagnostic fixture: observes original callbacks; never drives Unit a second time.
var world
var screen
var expected:Array=[]
var observed:Array=[]
var checks:=0
var failed:=0
var frames:=0
var phase:="loading"
var phase_frames:Dictionary={}
var deltas:Array=[]
var armed:=false
var delta_values:Dictionary={}
class BeginObserver extends Node:
	func _physics_process(_delta:float) -> void:get_parent().begin()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",label)
func collect(node:Node) -> void:
	if node is Unit and node.is_physics_processing() and node.can_process() and not node.is_queued_for_deletion():expected.append(node.get_instance_id())
	for child in node.get_children():collect(child)
func begin() -> void:
	if not armed:return
	expected=[];observed=[];deltas=[]
	collect(screen)
func record(actor,delta:float) -> void:
	if not armed:return
	observed.append(actor.get_instance_id());deltas.append(delta)
func _physics_process(_delta:float) -> void:
	if not armed:return
	frames+=1;phase_frames[phase]=int(phase_frames.get(phase,0))+1
	check(observed==expected,phase+" original SceneTree order and exactly one callback "+str(frames))
	for delta in deltas:
		delta_values[str(delta)]=true
		check(absf(float(delta)-Engine.time_scale/15.0)<0.002,phase+" delta matches 15Hz scaled clock")
	if phase=="paused":check(observed.is_empty(),"pause suppresses all unit simulation")
func exercise(label:String) -> void:
	phase=label
	await get_tree().create_timer(0.30,true).timeout
	check(int(phase_frames.get(label,0))>=2,label+" observed multiple physical steps")
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_physics_priority=2000000
	call_deferred("run")
func run() -> void:
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400,"starting_funds":8000,"fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);world=screen.battle
	screen.process_mode=Node.PROCESS_MODE_PAUSABLE
	world.set_process(false)
	world.prepared=true
	for child in world.get_children():child.process_mode=Node.PROCESS_MODE_DISABLED
	for unit in world.units.duplicate():unit.free()
	world.units.clear()
	for building in world.buildings:building.set_process(false)
	var actors:Array=[]
	for spec in [["MTNK","ally"],["E1","ally"],["FV","ally"],["LCRF","ally"],["HTNK","enemy"]]:
		var actor=world.spawn_unit(spec[0],spec[1],Vector2(1000+actors.size()*100,1000))
		actor.process_mode=Node.PROCESS_MODE_INHERIT;actor.set_physics_process(true);actor.set_process(false)
		actor.order_stop();actor.fire_stance="none";actor.special.gm_stationary=true
		actors.append(actor)
	world.enemy_root.process_mode=Node.PROCESS_MODE_INHERIT
	get_tree().paused=false;world.paused=false
	Engine.time_scale=1.0
	check(Engine.physics_ticks_per_second==15,"actual battle installs 15Hz clock")
	check(screen.call_log.closed and screen.call_log.base_path.is_empty() and screen.call_log.writer==null,"ordinary battle does not create performance writer or log paths")
	check(preload("res://scripts/world/battle_call_counters.gd").owner==0,"ordinary battle diagnostic counters disabled")
	var observer:=BeginObserver.new()
	observer.process_mode=Node.PROCESS_MODE_ALWAYS
	observer.process_physics_priority=-2000000
	add_child(observer)
	await get_tree().create_timer(1.0,true).timeout
	Engine.physics_ticks_per_second=15
	await get_tree().physics_frame
	armed=true
	await exercise("normal")
	get_tree().paused=true;world.paused=true
	await exercise("paused")
	get_tree().paused=false;world.paused=false
	await exercise("resumed")
	AlliedAbilities.change_side(actors[4],"ally")
	check(actors[4].side=="ally","real ownership transition applied")
	await exercise("mind_control")
	actors[1].set_stowed(actors[3])
	check(actors[1].embarked_in==actors[3],"real transport entry applied")
	await exercise("transported")
	actors[1].set_stowed(null)
	await exercise("unloaded")
	actors[1]._dead=true;actors[1].special.erase("gm_stationary");actors[1]._dying=0.60
	var previous:float=actors[1]._dying
	actors[1].tree_exiting.connect(func():world.units.erase(actors[1]))
	await exercise("death_sequence")
	check(is_instance_valid(actors[1]) and actors[1]._dying<previous,"death clock advances on original callback")
	actors[0].set_physics_process(false)
	await exercise("disabled_unit")
	actors[0].set_physics_process(true)
	await exercise("enabled_unit")
	armed=false
	observer.queue_free()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"frames":frames,"phases":phase_frames,"observer_only":true,"physics_hz":Engine.physics_ticks_per_second,"delta_values":delta_values.keys()},"  "))
	print("SHADOW checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
