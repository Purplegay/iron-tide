extends RefCounted
## Switches consume one remaining-wait credit, never both the wait and new reload.
const LENGTH:=50.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	if t>=26:return idle_sample(rank,t)
	var values:Dictionary=GameData.get_skill("ps_anchor_armor").values
	var defense:float=values.defense[rank]
	var cut:float=values.reload[rank]
	var base:float=GameData.get_unit("APOC").weapon.cooldown
	var rounds:Array=[{"at":4.0,"air":true,"credit":false}]
	var uses:Array=[]
	var previous:=4.0
	for index in 3:
		var wait:=.5 if index==0 else .25
		var consume:=previous+wait
		var reduced:float=(base-wait)*(1-cut)
		uses.append({"at":consume,"before":base-wait,"after":reduced})
		previous=consume+reduced
		rounds.append({"at":previous,"air":index==1,"credit":true})
	rounds.append({"at":previous+base,"air":false,"credit":false})
	var credits:=3 if t>=4 else 0
	var remaining:=0.0
	var discounted:=false
	var waiting_for_air:=false
	for shot:Dictionary in rounds:
		if t>=shot.at:remaining=maxf(0,base-(t-shot.at));discounted=false
	for index in uses.size():
		var use:Dictionary=uses[index]
		if t>=use.at:credits-=1
		if t>=use.at and t<rounds[index+1].at:
			remaining=maxf(0,use.after-(t-use.at));discounted=true;waiting_for_air=rounds[index+1].air
	var active:=t>=3 and t<8
	var text:="静止交火 %.1f/3秒"%t if t<3 else "正面减伤5秒 · 移动仍保留"
	if t>=4:text="防空齐射获得3次额度 · 不按导弹数叠加"
	if t>=4.5:text="等待%s -%d%% · 额度%d/3"%["防空" if waiting_for_air else "主炮",cut*100,credits] if discounted else "本轮已用额度 · 新装填不再减一次"
	if t>=8 and t<uses[1].at:text="减伤到期 · 剩余额度仍保留%d/3"%credits
	if t>=rounds[3].at:text="三次用尽 · 后续恢复原装填"
	return {"time":t,"idle":false,"active":active,"value":defense*100,"charges":credits,"front":100*(1-defense) if active else 100.,"rear":100.,"base":base,"remaining":remaining,"discounted":discounted,"rounds":rounds,"uses":uses,"text":text}

static func idle_sample(rank:int,t:float) -> Dictionary:
	var base:float=GameData.get_unit("APOC").weapon.cooldown
	var cut:float=GameData.get_skill("ps_anchor_armor").values.reload[rank]
	var duration:=base*(1-cut)
	var rounds:Array=[]
	var credits:=3
	var remaining:=0.0
	var discounted:=false
	for index in 4:
		var at:=27.0+duration*index
		rounds.append({"at":at,"air":false,"credit":index<3})
		if t>=at:
			credits=maxi(0,2-index);discounted=index<3
			remaining=maxf(0,(duration if discounted else base)-(t-at))
	var text:="独立示例 · 已保留3次额度 · 空闲等待不消耗" if t<27 else ("开火时消耗1次 · 只缩短本轮新装填" if credits>0 or discounted else "额度已用尽 · 第四轮正常装填")
	return {"time":t,"idle":true,"active":false,"value":0.,"charges":credits,"front":100.,"rear":100.,"base":base,"remaining":remaining,"discounted":discounted,"rounds":rounds,"uses":[],"text":text}

static func draw(stage,a:Vector2,b:Vector2,s:Dictionary) -> void:
	var air:=b+Vector2(0,-45)
	stage.actor(air,stage.FOE,PI,false)
	stage.actor(Vector2(12,a.y),stage.FOE,0,false)
	stage.shot(b,a,3.04);stage.shot(Vector2(12,a.y),a,4.04)
	if s.active:stage.draw_arc(a,30,-PI/3,PI/3,24,stage.BONUS,3,true)
	for shot:Dictionary in s.rounds:
		var weapon:Dictionary=GameData.get_unit("APOC")["anti_air_weapon" if shot.air else "weapon"]
		for index in int(weapon.burst):stage.shot(a,air if shot.air else b,shot.at+index*float(weapon.burst_delay),shot.credit)
	stage.draw_string(ThemeDB.fallback_font,Vector2(120,20),"空闲额度：缩短新装填" if s.idle else "普通直击100示例",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	stage.draw_string(ThemeDB.fallback_font,Vector2(120,36),"等待结束才开火 · 每轮一次" if s.idle else "正面 %.0f / 背面 %.0f"%[s.front,s.rear],HORIZONTAL_ALIGNMENT_LEFT,-1,12,stage.BONUS)
	for i in 3:stage.draw_circle(a+Vector2(-8+i*8,27),3,stage.BONUS if i<s.charges else stage.MUTED)
	stage.draw_rect(Rect2(110,90,120,5),stage.MUTED)
	stage.draw_rect(Rect2(110,90,120*clampf(s.remaining/s.base,0,1),5),stage.BONUS if s.discounted else stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(110,111),"剩余装填 %.2fs · 基础 %.2fs"%[s.remaining,s.base],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
