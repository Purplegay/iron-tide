extends RefCounted
const LENGTH:=36.0

static func overlap(time:float,a:float,b:float,c:float,d:float) -> float:
	return maxf(0,minf(time,minf(b,d))-maxf(a,c))

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=0 if t<12 else 1+int((t-12)/6)
	var local:=t if part==0 else fposmod(t-12,6)
	var value:float=MetaProgress.talent_options("SNIPE")["sniper_relocate"].values.speed[rank]*100
	var shots:Array=[1.,9.] if part==0 else [1.,2.] if part==1 else [1.]
	var moves:Array=[Vector2(1.2,5.2),Vector2(9.2,11.8)] if part==0 else [Vector2(2.2,4.2)] if part==1 else [Vector2(1.2,3.2)]
	var grant:=9. if part==0 and local>=9 else 1.
	var left:=maxf(0,grant+2-local) if part<2 and local>=grant else 0.
	var cooldown:=maxf(0,grant+8-local) if part<2 and local>=grant else 0.
	var distance:=0.
	var moving:=false
	for interval:Vector2 in moves:
		distance+=clampf(local-interval.x,0,interval.y-interval.x)*10
		moving=moving or (local>=interval.x and local<interval.y)
		if part<2:
			for start:float in ([1.,9.] if part==0 else [1.]):distance+=overlap(local,interval.x,interval.y,start,start+2)*10*value/100
	var kills:=0
	for at:float in shots:
		if local>=at and part!=2:kills+=1
	var title:String=["本人普通狙击击杀 · 两秒加速／八秒间隔","间隔内再次击杀 · 不续时不重置间隔","只命中未击杀 · 不获得加速","击杀临时召唤物 · 不获得加速","追加技能伤害击杀 · 不获得加速"][part]
	var text:="等待命中 · 不提高狙击伤害或射程"
	if local>=1:text="移速 +%d%% · 剩余%.1fs · 间隔%.1fs"%[value if left>0 else 0,left,cooldown]
	if part>=2 and local>=1:text="不满足触发条件 · 按原移速执行移动命令"
	return {"time":t,"local":local,"part":part,"active":left>0,"value":value,"charges":0,"text":text,"title":title,
		"left":left,"cooldown":cooldown,"moving":moving,"distance":distance,"speed":10*(1+value/100 if left>0 else 1),"kills":kills,"shots":shots}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"加速后仍执行原来的命令，未下达移动命令时会留在原地。",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	for i in s.shots.size():
		var point:Vector2=preview.MAIN_POINT+Vector2(i*46,i*20)
		if s.local>=s.shots[i] and s.part!=2:
			preview.draw_line(point-Vector2(5,5),point+Vector2(5,5),Color.GRAY,2)
			preview.draw_line(point+Vector2(-5,5),point+Vector2(5,-5),Color.GRAY,2)
		else:preview.draw_circle(point,7,Color.SALMON)
		if s.local>=s.shots[i] and s.local<s.shots[i]+.12:preview.draw_line(origin,point,Color.ORANGE if s.part==4 else Color.GOLD,2,true)
	preview.draw_dashed_line(Vector2(123,104),origin,Color.SKY_BLUE,2,6)
	if s.active:preview.draw_arc(origin,23,0,TAU,24,Color.SKY_BLUE,2,true)
	preview.draw_string(ThemeDB.fallback_font,Vector2(215,119),"命令：%s · 加速%.1fs"%["移动" if s.moving else "停留",s.left],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
