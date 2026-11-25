extends RefCounted

static func draw(view,a:Vector2,b:Vector2) -> void:
	var rank:int=view.levels.selected
	if rank==2:
		preload("res://scripts/ui/peregrine_reload_demo.gd").draw(view,a,b,false);return
	if rank==4:
		preload("res://scripts/ui/peregrine_maintenance_demo.gd").draw(view,minf(540,view.stage.size.x));return
	if rank==5:
		preload("res://scripts/ui/peregrine_crash_demo.gd").draw(view,minf(540,view.stage.size.x));return
	if rank in [1,3]:
		preload("res://scripts/ui/peregrine_cycle_defense_demo.gd").draw(view,minf(540,view.stage.size.x),rank)
