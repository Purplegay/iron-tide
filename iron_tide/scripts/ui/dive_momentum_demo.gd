extends RefCounted

static func sample(clock:float,rank:int) -> Dictionary:
	var values:Dictionary=MetaProgress.talent_options("BEAG").dive_momentum.values
	var duration:float=values.cloak[clampi(rank,0,3)]
	var elapsed:=clock-1.2
	var hidden:=elapsed>=0 and elapsed<duration
	var point:=Vector2(70+minf(clock,1.2)*90,80)
	if elapsed>=0:point+=Vector2(minf(elapsed,4.0)*40,-minf(elapsed,2.0)*12)
	var text:="满弹出动 · 接近目标"
	if elapsed>=0:text="投弹后隐身 %ss · 加速 %d%%（2s）"%[String.num(maxf(0,duration-elapsed),2),roundi(float(values.speed[rank])*100)] if hidden else "已显形 · 本次出动不重复触发"
	if clock>=6.5:text="落地补满 · 恢复下次触发资格"
	return {"point":point,"hidden":hidden,"cloak_left":maxf(0,duration-elapsed) if elapsed>=0 else 0.0,"bomb":elapsed>=0 and elapsed<0.6,"bomb_phase":clampf(elapsed/0.6,0,1),"label":text}

static func animate(stage) -> void:
	var state:=sample(stage._demo_clock(),stage.rank)
	stage.actor.position=stage.viewport.canvas_transform.affine_inverse()*state.point
	var effects:Dictionary=stage.actor.special.get_or_add("progression_v1",{})
	if state.hidden:effects.dive_cloak=state.cloak_left
	else:effects.erase("dive_cloak")

static func draw(stage,clock:float) -> void:
	var state:=sample(clock,stage.rank)
	var target:=Vector2(178,122)
	stage.draw_rect(Rect2(target-Vector2(14,9),Vector2(28,18)),Color("#cf7158"))
	if state.bomb:stage.draw_circle(Vector2(178,80).lerp(target,state.bomb_phase),3,Color.GOLD)
	elif clock>=1.8 and clock<2.2:stage.draw_arc(target,12+(clock-1.8)*30,0,TAU,24,Color.ORANGE,2)
	stage.draw_string(ThemeDB.fallback_font,Vector2(10,163),state.label,HORIZONTAL_ALIGNMENT_CENTER,405,14,Color.WHITE)
