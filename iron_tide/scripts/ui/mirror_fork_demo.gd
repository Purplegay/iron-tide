extends RefCounted

static func sample(stage) -> Dictionary:
	var values:Dictionary=GameData.get_skill("ap_mirror_fork").values
	var life:float=values.life[stage.preview_rank]
	var ends:Array=[life,life]
	if stage.mirror_ending==0:ends=[life*.7,life*.7]
	elif stage.mirror_ending==1:ends[0]=life*.5
	var moved:bool=stage.mirror_ending==0 and stage.elapsed>=ends[1]
	var points:Array=[]
	var alive:Array=[]
	var blasts:Array=[]
	for i in 2:
		var travel:=minf(stage.elapsed,float(ends[i]))
		points.append(stage.A+Vector2(travel*24,(i*2-1)*travel*9))
		alive.append(stage.elapsed<float(ends[i]))
		blasts.append(stage.elapsed-float(ends[i]))
	var text:="镜像移动射击 · W 可转移至高血量镜像"
	if moved:text="再次 W · 转移至高血量镜像 · 等量护盾 8s"
	elif stage.elapsed>=life:text="镜像到期爆炸 · 1.5 格范围伤害"
	elif stage.mirror_ending==1 and not alive[0]:text="一辆被击毁爆炸 · 另一辆继续移动射击"
	return {"points":points,"alive":alive,"blasts":blasts,"moved":moved,"active":alive[0] or alive[1],"text":text,"life":life}

static func draw(stage) -> String:
	var state:=sample(stage)
	stage.actor(stage.B,stage.FOE,PI)
	var origin:Vector2=state.points[1] if state.moved else stage.A
	stage.actor(origin,stage.ALLY)
	for i in 2:
		var at:Vector2=state.points[i]
		if state.alive[i]:
			stage.actor(at,Color(stage.ALLY,.55))
			stage.draw_rect(Rect2(at+Vector2(-14,-15),Vector2(28,3)),stage.MUTED)
			stage.draw_rect(Rect2(at+Vector2(-14,-15),Vector2(28*(.55 if i==0 else .85),3)),stage.BONUS)
			for shot in ceili(state.life):stage.shot(at,stage.B,.3+shot*.7)
		if state.blasts[i]>=0 and state.blasts[i]<.7:
			stage.ring(at,8+float(state.blasts[i])*44,stage.BONUS)
			stage.ring(at,4+float(state.blasts[i])*30,stage.ALLY)
	if state.moved:
		stage.draw_dashed_line(stage.A,origin,stage.ALLY,1,5)
		stage.ring(origin,20,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,origin+Vector2(-23,-25),"等量护盾",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	var icon:=Rect2(12,9,30,30)
	stage.draw_texture_rect(preload("res://scripts/ui/progression_icon.gd").texture("ap_mirror_fork"),icon,false)
	stage.draw_string(ThemeDB.fallback_font,Vector2(22,54),"W",HORIZONTAL_ALIGNMENT_LEFT,-1,12,stage.BONUS)
	if state.active:
		stage.draw_rect(icon,stage.BONUS,false,2)
		stage.draw_arc(icon.get_center(),23,stage.elapsed*4,stage.elapsed*4+PI*1.4,24,stage.BONUS,2,true)
	return state.text
