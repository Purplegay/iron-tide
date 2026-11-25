extends RefCounted
const P=preload("res://scripts/units/peregrine.gd")

static func draw(view,width:float) -> void:
	var t:float=view.elapsed
	var start:=Vector2(width*.24,85)
	var target:=Vector2(width*.74,105)
	if view.talent.selected==1 and view.levels.selected>0:
		preload("res://scripts/ui/peregrine_defense_demo.gd").draw(view,start,target);return
	if view.talent.selected==0 and view.levels.selected>0:
		command(view,start,target,width);return
	if view.talent.selected==0:
		preload("res://scripts/ui/peregrine_sensor_demo.gd").draw(view,width,0)
	else:
		preload("res://scripts/ui/peregrine_formation_demo.gd").draw(view,width)

static func command(view,a:Vector2,b:Vector2,width:float) -> void:
	var t:float=view.elapsed
	var rank:int=view.levels.selected
	if rank==1:
		preload("res://scripts/ui/peregrine_reload_demo.gd").draw(view,a,b,true);return
	if rank in [2,3]:
		preload("res://scripts/ui/peregrine_sensor_demo.gd").draw(view,width,rank);return
	if rank==4:
		preload("res://scripts/ui/peregrine_formation_demo.gd").draw(view,width);return
	if rank==5:preload("res://scripts/ui/peregrine_split_demo.gd").draw(view,width)
