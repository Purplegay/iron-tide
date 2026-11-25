extends RefCounted
const LENGTH:=40.0
const SOURCE:=Vector2(48,78)
const TARGET:=Vector2(218,78)
const NEIGHBOR:=Vector2(245,95)
const RADIUS:=42.0

static func target_at(part:int,time:float) -> Vector2:
	return TARGET+Vector2(70*clampf((time-1.4)/.6,0,1),0) if part==3 else TARGET

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/10)
	var local:=fposmod(t,10)
	var card:Dictionary=GameData.get_skill("ap_overload_seal")
	var expires:float=.5+float(card.values.duration[rank])
	var shots:Array[float]=[]
	if part!=1:shots.assign([1.,2.1,3.2,4.3])
	if part==2:shots.assign([1.,1.12,1.3,2.1,3.2,4.3])
	var triggers:Array[float]=[]
	if part!=1:triggers.assign([1.,2.1,3.2])
	var count:=0
	var near_hits:=0
	var last:=-100.0
	for event:float in triggers:
		if local<event:continue
		count+=1;last=event
		if target_at(part,event).distance_to(NEIGHBOR)<=RADIUS:near_hits+=1
	var active:=local>=.5 and local<expires and count<3
	var left:=maxf(0,expires-local) if active else 0.
	var title:String=["普通开火后电爆 · 最多三次","停火等待 · 只倒计时、不掉血","W／同轮连发／一秒内连射不追加","移出队形再开火 · 邻军避开后两次"][part]
	var text:="手动选择5格内可见敌载具／武装建筑"
	if local>=.5:
		text="封条 %.1fs · 剩余%d/3 · 每次%.0f%%攻击"%[left,3-count,float(card.values.damage[rank])*100] if active else ("停火等到期 · 三次额度未使用，无电爆" if part==1 else "三次耗尽 · 后续原弹照常，不再电爆")
	return {"time":t,"local":local,"part":part,"title":title,"text":text,"active":active,"left":left,
		"value":float(card.values.damage[rank])*100,"charges":3-count if active else 0,"triggers":count,"near_hits":near_hits,
		"flash":local>=last and local<last+.22,"shots":shots,"target":target_at(part,local),"cd":maxf(0,30-(local-.5)) if local>=.5 else 0.,
		"special_flash":part==2 and local>=.75 and local<.92}

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"独立开火示例 · W冷却%.1fs · 电爆不取消原弹"%s.cd,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(SOURCE,stage.ALLY)
	stage.actor(s.target,stage.FOE,PI,false)
	stage.actor(NEIGHBOR,stage.FOE,PI,false)
	stage.ring(s.target,19,Color.WHITE)
	for start:float in s.shots:
		if s.local>=start and s.local<start+.3:
			var origin:=target_at(s.part,start)
			var p:Vector2=origin.lerp(SOURCE,(s.local-start)/.3)
			stage.draw_line(p,p+Vector2(7,0),stage.FOE,3,true)
	if s.special_flash:stage.ring(s.target,30,stage.BONUS)
	if s.active:
		var mark:Vector2=s.target+Vector2(0,-24)
		stage.draw_line(mark-Vector2(8,6),mark+Vector2(8,6),Color.CYAN,2)
		stage.draw_line(mark+Vector2(-8,6),mark+Vector2(8,-6),Color.CYAN,2)
		stage.draw_string(ThemeDB.fallback_font,mark+Vector2(-18,-12),"%.1fs"%s.left,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.CYAN)
	for i in 3:stage.draw_rect(Rect2(125+i*12,47,8,8),Color.CYAN if i<s.charges else stage.MUTED)
	if s.flash:
		stage.ring(s.target,RADIUS,Color.CYAN)
		if s.target.distance_to(NEIGHBOR)<=RADIUS:stage.draw_line(s.target,NEIGHBOR,Color.CYAN,2)
	stage.draw_string(ThemeDB.fallback_font,Vector2(126,116),"电爆次数：主目标%d · 邻军%d"%[s.triggers,s.near_hits],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
