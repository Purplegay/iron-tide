extends Node
var checks:=0
var failed:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",label)
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene=null
	call_deferred("run")
func run() -> void:
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	check(DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))==OK,"copy isolated checkpoint")
	check(BattleSaves.load_into_scene("slot1").ok,"checkpoint accepted")
	while get_tree().current_scene==null:await get_tree().process_frame
	var screen=get_tree().current_scene
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	var world=screen.battle
	var total:int=world.units.size()+world.buildings.size()
	check(world.simulation.entities.size()==total,"restored entity registry count")
	check(world.neighborhood==world.simulation.neighborhood,"single authoritative index")
	for actor in world.units+world.buildings:
		check(world.simulation.entities.has(actor),"restored actor registered")
		check(world.neighborhood.membership.has(actor),"restored actor indexed")
		check(world.simulation.entities[actor]==(actor is Building),"restored actor kind")
	var actor=world.units[0]
	var old:Vector2=actor.position
	actor.position+=Vector2(1024,512)
	check(world.neighborhood.membership[actor]==Vector2i((actor.global_position/256.0).floor()),"restored actor moves index immediately")
	actor.position=old
	var parent:Node=actor.get_parent()
	parent.remove_child(actor)
	check(not world.simulation.entities.has(actor) and not world.neighborhood.membership.has(actor),"restored actor exit")
	parent.add_child(actor)
	check(world.simulation.entities.size()==total and world.neighborhood.membership.has(actor),"restored actor reentry")
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"units":world.units.size(),"buildings":world.buildings.size()}))
	print("SIMULATION_SAVED checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
