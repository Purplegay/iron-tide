extends RefCounted
const LENGTH:=48.0
const POINTS:=[Vector2(294,80),Vector2(330,60),Vector2(330,101)]

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/16)
	var local:=fposmod(t,16)
	var value:float=MetaProgress.talent_options("SREF")["prism_guard"].values.shield[rank]*100
	var maximum:=value*10
	var events:Array=[{"at":1.,"native":true,"victims":[0,1,2]},{"at":2.,"native":true,"victims":[0,1,2]},{"at":13.,"native":true,"victims":[0,1,2]}]
	if part==2:
		events=[{"at":1.,"native":true,"victims":[0,1]},{"at":2.,"native":false,"victims":[0,1,2]},{"at":2.6,"native":false,"victims":[0,1,2]},{"at":3.,"native":true,"victims":[2]},{"at":4.,"native":true,"victims":[0,1,2]}]
	var grant:=4. if part==2 else 1.
	if part!=2 and local>=13:grant=13.
	var cooldown:=maxf(0,grant+12-local) if local>=grant else 0.
	var left:=maxf(0,grant+3-local) if local>=grant else 0.
	var shield:=maximum if left>0 else 0.
	var hp:=1000.
	var broken:=part==1 and local>=3 and local<13
	if part==1 and local>=2 and local<3:shield=maximum*.5
	if part==1 and local>=3:hp=993.
	if broken:shield=0.;left=0.
	var charges:=0
	var last_native:=-1.
	for event:Dictionary in events:
		if event.at>local:break
		if event.native:charges=event.victims.size();last_native=event.at
	var title:String=["同轮三个不同敌人 · 三秒盾／十二秒间隔","先扣护盾 · 击破后溢出扣生命","两人不够 · W不凑数 · 不跨轮累计"][part]
	var text:="等待原生光束实际伤到三个不同敌人"
	if local>=1:text="本轮原生命中%d人 · 护盾%.0f · 剩余%.1fs"%[charges,shield,left]
	if part==2 and local>=2 and local<3:text="棱镜十字两轮命中三人 · 不授予护镜"
	if part==2 and local>=3 and local<4:text="新的原生轮次只命中一人 · 不继承上轮两人"
	if broken:text="护盾被击破 · 溢出7点扣生命，间隔不返还"
	elif local>=grant+3:text="护盾自然到期 · 生命不变，间隔仍在继续"
	return {"time":t,"local":local,"part":part,"value":value,"charges":charges,"active":shield>0,"text":text,"title":title,
		"shield":shield,"maximum":maximum,"hp":hp,"left":left,"cooldown":cooldown,"broken":broken,"events":events,"last_native":last_native}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"命中节点示例 · 最大生命1000 · 额外伤害不凑数",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	for index in 3:
		preview.draw_circle(POINTS[index],7,Color.SALMON)
		preview.draw_string(ThemeDB.fallback_font,POINTS[index]+Vector2(-3,-12),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	for event:Dictionary in s.events:
		if s.local<event.at or s.local>=event.at+.16:continue
		if event.native:
			var main:Vector2=POINTS[event.victims[0]]
			preview.draw_line(origin,main,Color.SKY_BLUE,2,true)
			for index in event.victims.slice(1):preview.draw_line(main,POINTS[index],Color.SKY_BLUE,2,true)
		else:
			preview.draw_line(Vector2(275,80),Vector2(382,80),Color.ORANGE,3,true)
			preview.draw_line(Vector2(330,44),Vector2(330,115),Color.ORANGE,3,true)
	if s.active:preview.draw_arc(origin,27,0,TAU,32,Color.CYAN,2,true)
	if s.part==1:
		for at in [2.,3.]:
			if s.local>=at and s.local<at+.16:preview.draw_line(POINTS[0],origin,Color.SALMON,2,true)
	if s.part==1 and s.local>=3 and s.local<3.25:
		for i in 4:preview.draw_arc(origin,29+i*2,i*PI/2,i*PI/2+.6,8,Color.CYAN,2,true)
	preview.draw_rect(Rect2(origin+Vector2(-43,27),Vector2(86,4)),Color.DIM_GRAY)
	preview.draw_rect(Rect2(origin+Vector2(-43,27),Vector2(86*s.shield/s.maximum,4)),Color.CYAN)
	preview.draw_string(ThemeDB.fallback_font,origin+Vector2(-70,20),"自身生命%.0f · 护盾%.0f"%[s.hp,s.shield],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.CYAN)
	preview.draw_string(ThemeDB.fallback_font,Vector2(235,123),"触发间隔剩余 %.1fs"%s.cooldown,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
