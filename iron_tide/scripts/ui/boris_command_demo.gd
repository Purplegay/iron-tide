extends RefCounted

static func draw(view,width:float) -> void:
	var level:int=view.levels.selected
	if level in [2,3,5]:
		preload("res://scripts/ui/boris_air_support_demo.gd").draw(view,width,level);return
	if level in [1,4]:
		preload("res://scripts/ui/boris_rifle_demo.gd").draw(view,width,level)
