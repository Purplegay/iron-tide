extends Node
var checks := 0
var failed := 0
var events: Array = []
var sim
var actor: Node2D
var second := 0
var third := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1; print("FAIL ",label)
func first(_dt: float) -> void:
	events.append("first")
	sim.detach(second)
	if third == 0: third = sim.attach(actor, func(_delta): events.append("third"))
func _ready() -> void:
	sim=load("res://scripts/world/simulation_world.gd").new()
	actor=Node2D.new();add_child(actor)
	sim.register(actor,20.0,false)
	check(sim.entities.size()==1 and sim.neighborhood.membership.has(actor),"registration owns spatial membership")
	actor.position=Vector2(1024,1024);sim.relocate(actor)
	check(sim.neighborhood.membership[actor]==Vector2i(4,4),"relocation uses original cell geometry")
	sim.attach(actor,first)
	second=sim.attach(actor,func(_dt):events.append("second"))
	sim.step(0.1)
	check(events==["first"],"removal immediate and insertion deferred")
	events.clear();sim.step(0.1)
	check(events==["first","third"] and sim.tick==2,"stable order and one tick per step")
	sim.remove(actor);events.clear();sim.step(0.1)
	check(events.is_empty() and sim.entities.is_empty() and sim.neighborhood.membership.is_empty(),"removal unregisters components and index")
	sim.register(actor,20,false);sim.attach(actor,func(_dt):events.append("reentry"));sim.step(0.1)
	check(events==["reentry"],"reentry does not resurrect old components")
	var removed=Node2D.new();add_child(removed);sim.register(removed,10,false)
	var token:int=sim.attach(removed,func(_dt):events.append("freed"))
	removed.free();events.clear();sim.step(0.1)
	check(not events.has("freed"),"freed adapter never invoked")
	sim.detach(token)
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if not out.is_empty():FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("SIMULATION_WORLD checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
