extends RefCounted

static func draw(view,width:float) -> void:
	var level:int=view.levels.selected
	if level==2:
		preload("res://scripts/ui/boris_control_demo.gd").draw(view,width);return
	if level in [3,4]:
		preload("res://scripts/ui/boris_support_demo.gd").draw(view,width,level);return
	if level in [1,5]:
		preload("res://scripts/ui/boris_lethal_demo.gd").draw(view,width,level)
