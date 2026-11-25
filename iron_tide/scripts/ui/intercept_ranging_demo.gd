extends RefCounted
const HIT_DELAY:=.18

static func span() -> float:
	return float(GameData.get_unit("AEGIS").weapon.cooldown)*6+2

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,span()*4)
	var part:=int(t/span())
	var local:=fposmod(t,span())
	var base:float=GameData.get_unit("AEGIS").weapon.cooldown
	var cut:float=MetaProgress.talent_options("AEGIS").intercept_ranging.values.reload[rank]
	var third:=.4+base*2
	var switch_at:=third+(.1 if part==2 else .5)
	var switched:=part>=2 and local>=switch_at
	var rounds:Array=[]
	for i in 3:rounds.append({"start":.4+base*i,"target":0,"discount":false})
	if part==0:
		for i in 3:rounds.append({"start":.4+base*3+base*(1-cut)*i,"target":0,"discount":i<2})
	elif part>=2:rounds.append({"start":.4+base*3,"target":1,"discount":false})
	var hits:=0
	var charges:=0
	var wait:=0.0
	var shots:Array=[]
	for i in rounds.size():
		var round:Dictionary=rounds[i]
		var hit:float=round.start+HIT_DELAY
		if local>=round.start:wait=maxf(0,round.start+base*(1-cut if round.discount else 1.0)-local)
		if part==0:
			if i<3 and local>=hit:
				hits+=1
				if hits==3:hits=0;charges=2
			elif i in [3,4] and local>=round.start:charges-=1
			elif i==5 and local>=hit:hits=1
		elif switched:
			if round.target==1 and local>=hit:hits=1
		elif local>=hit:
			hits+=1
			if hits==3:hits=0;charges=2
		shots.append({"start":round.start,"hit":hit,"target":round.target,"discount":round.discount})
		if part==1:shots.append({"start":round.start+.12,"hit":hit+.12,"target":0,"discount":false})
	var title:String=["同机三轮命中 → 两次新装填加速","同轮双弹计数示意 · 每轮只计一次","第三轮在途时转火 · 旧弹不记新目标","获得两次额度后转火 · 额度全部清空"][part]
	var text:="命中 %d/3 · 快速装填 %d/2 · 当前装填 %.2fs"%[hits,charges,wait]
	if part==0 and local>=rounds[5].start:text="两次已用尽 · 本轮恢复正常，命中重新计数"
	elif switched:text="当前目标B · 旧额度归零 · 新目标命中 %d/3"%hits
	return {"time":t,"local":local,"part":part,"active":charges>0,"value":cut*100,"charges":charges,"hits":hits,"wait":wait,
		"base":base,"rounds":rounds,"shots":shots,"switched":switched,"switch_at":switch_at,"title":title,"text":text}

static func draw(view,origin:Vector2,s:Dictionary) -> void:
	const Flight=preload("res://scripts/ui/wake_fork_demo.gd")
	var a:=Vector2(300,65)
	var b:=Vector2(365,108)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	view.draw_string(ThemeDB.fallback_font,Vector2(10,35),"新装填 -%.0f%% · 进行中的装填不追溯缩短"%s.value,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	view.draw_circle(a,9,Color.SALMON);view.draw_circle(b,9,Color.SALMON)
	view.draw_string(ThemeDB.fallback_font,a+Vector2(-5,-15),"A",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.SALMON)
	view.draw_string(ThemeDB.fallback_font,b+Vector2(-5,-15),"B",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.SALMON)
	view.draw_arc(b if s.switched else a,15,0,TAU,24,Color.WHITE,1,true)
	for shot:Dictionary in s.shots:
		var target:Vector2=a if shot.target==0 else b
		var color:=Color.GOLD if shot.discount else Color.SKY_BLUE
		if s.switched and shot.target==0:color=Color.DIM_GRAY
		Flight.trace(view,origin,target,s.local,shot.start,shot.hit,color)
		if s.local>=shot.hit and s.local<shot.hit+.08:view.draw_arc(target,19,0,TAU,24,color,2,true)
	for i in 2:view.draw_circle(origin+Vector2(-7+i*14,29),4,Color.GOLD if i<s.charges else Color.DIM_GRAY)
	view.draw_rect(Rect2(200,116,90,4),Color.DIM_GRAY)
	view.draw_rect(Rect2(200,116,90*clampf(s.wait/s.base,0,1),4),Color.SKY_BLUE)
