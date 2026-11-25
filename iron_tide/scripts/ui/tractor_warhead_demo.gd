extends RefCounted
const LENGTH:=50.0
const CELL:=20.0
const CENTER:=Vector2(220,76)
const LAUNCHER:=Vector2(50,76)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/10)
	var local:=fposmod(t,10)
	var card:Dictionary=GameData.get_skill("ap_tractor_warhead")
	var radius:float=card.values.radius[rank]*CELL
	var launch:=6.5 if part==4 else 1.0
	var impact:=launch+3
	var intercepted:=part==1 and local>=2.5
	var payload:=part!=4
	var field:=payload and part!=1 and local>=impact and local<impact+2
	var elapsed:=clampf(local-impact,0,2)
	var offset:=radius*.75
	if payload and part!=1:
		if part==3:offset+=radius*.3*elapsed
		else:offset-=.6*CELL*elapsed
		if part==2:offset=maxf(radius*.45+7,offset)
	var point:=CENTER+Vector2(offset,0)
	var burst:=payload and part!=1 and local>=impact+2
	var armed:bool=local<(6.0 if part==4 else launch)
	var title:String=["普通主弹落地 · 牵引两秒后爆破","火箭被拦截 · 不生成坑、不退款","墙阻止穿越 · 不额外免疫范围爆破","主动撤离范围 · 避开最终爆破","六秒待命过期 · 后续普通弹不牵引"][part]
	var text:="下一枚主弹待命 %.1fs"%maxf(0,6-local) if armed else "资格已消费 · 原生发射过程示意"
	if field:text="牵引 %.1fs · 每秒0.6格 · 范围%.2f格"%[impact+2-local,radius/CELL]
	elif intercepted:text="被拦截：无牵引坑、无追加爆破"
	elif part==4 and local>=6:text="待命已过期 · 原弹伤害保留，无牵引"
	elif burst:text="目标已离开 · 不受最终爆破" if part==3 else "仍在范围 · 承受%.0f%%攻击爆破"%(float(card.values.damage[rank])*100)
	return {"time":t,"local":local,"part":part,"active":field,"value":float(card.values.damage[rank])*100,"charges":1 if armed else 0,
		"launch":launch,"impact":impact,"payload":payload,"intercepted":intercepted,
		"flying":local>=launch and local<impact and not intercepted,"burst":burst,"flash":burst and local<impact+2.25,
		"point":point,"radius":radius,"victim_hit":burst and point.distance_to(CENTER)<=radius,
		"cd":maxf(0,float(card.cooldown_by_rank[rank])-local),"title":title,"text":text}

static func rocket(s:Dictionary,time:float) -> Vector2:
	var progress:=clampf((time-s.launch)/3,0,1)
	return LAUNCHER.lerp(CENTER,progress)+Vector2(0,-sin(progress*PI)*30)

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"独立示例 · 一枚强化资格 · W冷却%.1fs"%s.cd,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	stage.actor(LAUNCHER,stage.ALLY)
	stage.draw_circle(CENTER,3,stage.MUTED)
	stage.actor(s.point,stage.FOE,PI,false)
	var far:=CENTER+Vector2(-s.radius-16,17)
	stage.draw_circle(far,5,stage.MUTED)
	if s.part==2:stage.draw_line(CENTER+Vector2(s.radius*.45,-25),CENTER+Vector2(s.radius*.45,25),stage.MUTED,4)
	if s.charges>0:stage.ring(LAUNCHER,24,stage.BONUS)
	if s.flying:
		var at:=rocket(s,s.local)
		stage.draw_line(at,at+Vector2(-6,6),stage.BONUS if s.payload else stage.ALLY,4,true)
	if s.intercepted and s.local<2.8:
		var at:=rocket(s,2.5)
		stage.draw_line(Vector2(290,43),at,stage.FOE,2,true)
		stage.draw_line(at-Vector2(8,8),at+Vector2(8,8),stage.FOE,2)
		stage.draw_line(at+Vector2(-8,8),at+Vector2(8,-8),stage.FOE,2)
	if s.active:
		stage.ring(CENTER,s.radius,Color.CYAN)
		var inward:float=s.radius*fposmod((s.impact+2-s.local)*2,1)
		for i in 8:
			var axis:=Vector2.from_angle(TAU*i/8)
			stage.draw_line(CENTER+axis*inward,CENTER+axis*maxf(0,inward-7),Color.CYAN,1,true)
	if s.flash:stage.ring(CENTER,s.radius,stage.BONUS)
	if not s.intercepted and s.local>=s.impact and s.local<s.impact+.2:stage.ring(CENTER,16,stage.FOE)
	stage.draw_string(ThemeDB.fallback_font,Vector2(165,115),"原弹伤害保留 · 范围外不追加",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
