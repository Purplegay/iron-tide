extends Node
const Tasks=preload("res://scripts/expedition/objectives.gd")
class World:
	extends Node
	var ended:=false
	var allied_state:Dictionary={}
	var calls:=0
	var accept:=false
	var base:=true
	var last_win:=false
	func has_base_assets(_side:String) -> bool:return base
	func end_battle(win:bool) -> void:
		calls+=1
		last_win=win
		if accept:ended=true
var failed:=0
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",label)
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	var world:=World.new()
	var task:=Tasks.new()
	task.world=world
	task.state={"kind":"capture","progress":60.0,"outcome":0,"elapsed":65.0}
	task.finish(true)
	check(world.calls==1 and not world.ended and world.last_win,"completed objective attempts victory")
	task.tick(1.0)
	check(world.calls==2 and not world.ended,"failed settlement retries next task tick")
	world.accept=true
	task.tick(1.0)
	check(world.calls==3 and world.ended and world.last_win,"retry can complete settlement")
	task.tick(1.0)
	task.finish(true)
	check(world.calls==3,"ended battle does not settle twice")
	world.ended=false;world.calls=0
	task.state.outcome=1
	task.tick(1.0)
	check(world.ended and world.calls==1 and world.last_win,"restored completed outcome settles without recapturing")
	world.ended=false;world.calls=0;task.state.outcome=-1
	task.tick(1.0)
	check(world.ended and not world.last_win,"failed objective keeps loss on retry")
	world.ended=false;world.base=false;task.state.outcome=0
	task.finish(true)
	check(world.ended and not world.last_win,"original base survival rule retained")
	task.free();world.free()
	print("EXPEDITION SETTLEMENT RETRY checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
