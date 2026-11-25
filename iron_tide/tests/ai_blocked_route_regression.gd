extends "res://tests/ground_control_regression.gd"
const Blocked=preload("res://scripts/world/ai_blocked_route.gd")
func exercise(mode:String) -> void:
	start(mode)
	battle.paused=false;get_tree().paused=false
	var unit=battle.spawn_unit("MTNK","enemy",Vector2(600,600))
	activate(unit)
	var goal:Vector2=unit.position+Vector2(600,0)
	check(not Blocked.failed(battle,unit,goal,goal),prefix+"reachable order is never delayed")
	check(not Blocked.failed(battle,unit,unit.position+Vector2(100,0),unit.position),prefix+"nearby formation adjustments are not delayed")
	check(Blocked.failed(battle,unit,goal,unit.position),prefix+"unreachable self destination starts bounded retry")
	check(Blocked.waiting(battle,unit),prefix+"same terrain waits")
	check(not battle.skirmish_ai.wave_candidates(true).has(unit),prefix+"full wave skips blocked retry instead of issuing self orders")
	unit._anim+=Blocked.RETRY
	check(not Blocked.waiting(battle,unit) and not unit.special.has(Blocked.KEY),prefix+"retry expires after six simulation seconds")
	Blocked.failed(battle,unit,goal,unit.position)
	battle._refresh_pathing()
	check(not Blocked.waiting(battle,unit),prefix+"bridge or building navigation change wakes unit immediately")
	unit.is_air=true
	check(not Blocked.failed(battle,unit,goal,unit.position),prefix+"air units keep existing dispatch")
	unit.is_air=false;unit.is_naval=true
	check(not Blocked.failed(battle,unit,goal,unit.position),prefix+"naval units keep existing dispatch")
	await finish()
