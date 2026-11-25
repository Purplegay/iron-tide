extends RefCounted
const LENGTH:=56.0
const RADIUS:=70.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=0 if t<24 else 1+int((t-24)/8)
	var local:=t if part==0 else fposmod(t-24,8)
	var rate:float=GameData.get_skill("ps_convoy_repair").values.heal[rank]
	var start:=6.0 if part==1 else 3.0
	var end:=start+3
	if part in [2,4]:end=4.0
	if part==3:end=3+(sqrt(RADIUS*RADIUS-400)-40)/30
	var active:=local>=start and local<end
	var second:=part==0 and local>=21
	if second:active=true
	var healing:=clampf(local-start,0,end-start)+(clampf(local-21,0,3) if part==0 else 0.)
	var damaged:=part==4 and local>=4
	var hp:=500+1000*rate*healing-(10 if damaged else 0)
	var pause:=clampf(local-2,0,1) if part==1 else clampf(local-4,0,1) if part==2 else 0.
	var moving:=not (part==1 and local>=2 and local<3) and not (part==2 and local>=4 and local<5)
	var at:=Vector2(50+(local-pause)*4,74)
	var peer:Vector2=at+Vector2(40+(clampf(local-3,0,2)*30 if part==3 else 0),20)
	var cd:=maxf(0,(39 if second else start+18)-local) if local>=start else 0.
	var preparation:=minf(3,local)
	if part==1:preparation=minf(3,maxf(0,local-3)) if local>=2 else local
	if local>=start:preparation=0. if active or not moving or part==3 else minf(3,maxf(0,local-end))
	var title:String=["连续同行三秒 · 自修三秒 · 间隔18秒","准备时停车 · 重新连续同行三秒","维修中停车 · 立刻停止回血","同行车离开两格 · 维修立即中断","受到敌人伤害 · 维修与准备清空"][part]
	var text:="实际同行 %.1f/3秒 · 仅自身回血"%preparation
	if local>=start:text="自身每秒最大生命%.1f%% · 本次剩%.1fs"%[rate*100,(24 if second else end)-local] if active else "本次维修结束 · 间隔还剩%.1fs"%cd
	if part==1 and local>=2 and local<3:text="停止实际移动：未完成的准备清空"
	if part==3 and local>=end:text="同伴已超出两格 · 剩余间隔%.1fs"%cd
	if damaged:text="受敌伤终止 · 恢复同行也须等剩余间隔"
	return {"time":t,"local":local,"part":part,"active":active,"value":rate*100,"charges":0,"title":title,"text":text,
		"start":start,"end":end,"second":second,"preparation":preparation,"hp":hp,"peer_hp":500.,"healed":1000*rate*healing,
		"cooldown":cd,"moving":moving,"point":at,"peer":peer,"damaged":damaged}

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"自身最大生命1000示例 · 同伴不回血",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_arc(s.point,RADIUS,0,TAU,40,Color(stage.MUTED,.5),1,true)
	stage.actor(s.point,stage.ALLY);stage.actor(s.peer,stage.ALLY,0,false)
	stage.draw_string(ThemeDB.fallback_font,s.point+Vector2(-25,-27),"自身 %.1f"%s.hp,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,s.peer+Vector2(-20,20),"同伴 500",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	if s.active:
		stage.ring(s.point,24,Color.GREEN)
		stage.draw_line(s.point+Vector2(-5,-20),s.point+Vector2(5,-20),Color.GREEN,2)
		stage.draw_line(s.point+Vector2(0,-25),s.point+Vector2(0,-15),Color.GREEN,2)
	if s.part==4 and s.local>=3.6 and s.local<4:
		var tip:Vector2=Vector2(300,65).lerp(s.point,(s.local-3.6)/.4)
		stage.draw_line(tip,tip+Vector2(8,0),stage.FOE,2,true)
	stage.draw_string(ThemeDB.fallback_font,Vector2(224,60),"准备 %.1f/3s"%s.preparation,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(224,80),"间隔 %.1fs"%s.cooldown,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	stage.draw_string(ThemeDB.fallback_font,Vector2(224,100),"累计自修 %.1f"%s.healed,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GREEN)
