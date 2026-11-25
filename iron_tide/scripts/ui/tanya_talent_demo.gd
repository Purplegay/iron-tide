extends RefCounted

static func draw(view,width:float) -> void:
	var level:int=view.levels.selected
	var defense:bool=view.talent.selected==1
	if not defense and level in [3,4]:
		preload("res://scripts/ui/tanya_assault_demo.gd").draw(view,width,level);return
	if not defense and level in [1,2]:
		preload("res://scripts/ui/tanya_target_demo.gd").draw(view,width,level);return
	if not defense and level==5:
		preload("res://scripts/ui/tanya_chain_demo.gd").draw(view,width);return
	if defense and level==1:
		preload("res://scripts/ui/tanya_damage_demo.gd").draw(view,width,true);return
	if defense and level==2:
		preload("res://scripts/ui/tanya_swim_demo.gd").draw(view,width);return
	if defense and level>=3:
		preload("res://scripts/ui/tanya_survival_demo.gd").draw(view,width,level);return

static func wrap_caption(text:String,width:float) -> String:
	var result:=""
	var line:=""
	for character in text:
		if ThemeDB.fallback_font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>width:
			result+=line+"\n";line=""
		line+=character
	return result+line
