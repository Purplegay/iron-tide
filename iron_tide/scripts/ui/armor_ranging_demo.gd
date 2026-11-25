extends RefCounted
const LENGTH:=40.0
const A:=Vector2(294,62)
const B:=Vector2(370,82)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var value:float=MetaProgress.talent_options("GGI")["armor_ranging"].values.damage[rank]*100
	var rounds:Array=[]
	var times:Array=[1.,2.,3.,4.,6.5,7.5]
	if part==1:times=[1.,2.,3.,4.,5.]
	if part in [2,3]:times=[1.,2.,5.,6.,7.]
	if part==4:times=[1.,2.,3.]
	var charges:=0
	var until:=0.
	var damage:=0.
	var last_hit:=-1.
	for at:float in times:
		var target:=1 if (part==1 and at>=3) or (part==3 and at>=5) else 0
		var clears:bool=(part in [1,2,3] and at==times[2]) or (until>0 and at>=until)
		var boosted:=until>at and not clears
		# Reset precedes the next hit; switching back never restores the old pair.
		var dealt:=100.*(1+value/100) if boosted else 100.
		rounds.append({"at":at,"target":target,"damage":dealt})
		if at>local:break
		if clears:charges=0;until=0.
		damage=dealt;last_hit=at
		if part!=4 and until==0:
			charges+=1
			if charges==2:until=at+4
	if part in [1,2,3] and local>=2.5 and local<float(times[2]):charges=0;until=0.
	if until>0 and local>=until:charges=0;until=0.
	var left:=maxf(0,until-local)
	var deployed:=not (part==2 and local>=2.5 and local<4)
	var target:=1 if (part in [1,3] and local>=2.5) else 0
	var title:String=["前两次命中不增伤 · 后续命中不续时","转火立即清空 · 新目标重新两次","起身清空 · 再部署从零开始","原目标死亡清空 · 新目标从零开始","对空普通命中 · 不累计反甲校距"][part]
	var text:="部署主直击 %d/2 · 仅地面载具"%charges
	if left>0:text="仅绑定目标 +%d%% · 剩余 %.1fs · 命中不续时"%[value,left]
	elif part==4:text="对空命中仍为100 · 校距始终0/2"
	elif not deployed:text="已起身：原有层数和增伤均清空"
	elif part in [1,3] and local>=2.5 and local<float(times[2]):text="原绑定已清空 · 等待新目标第一次命中"
	return {"time":t,"local":local,"part":part,"active":left>0,"value":value,"charges":charges,"text":text,
		"title":title,"left":left,"deployed":deployed,"target":target,"dead":part==3 and local>=2.5,
		"air":part==4,"damage":damage,"last_hit":last_hit,"rounds":rounds}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"以 100 点伤害为例，不会额外开火或加快射击",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	for index in 2:
		var at:Vector2=A if index==0 else B
		if s.dead and index==0:
			preview.draw_line(at-Vector2(6,6),at+Vector2(6,6),Color.GRAY,2)
			preview.draw_line(at+Vector2(-6,6),at+Vector2(6,-6),Color.GRAY,2)
		else:preview.draw_circle(at,8,Color.SALMON)
		preview.draw_string(ThemeDB.fallback_font,at+Vector2(-20,-14),("飞机A" if s.air else "载具A") if index==0 else "载具B",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
		if index==s.target and s.active:preview.draw_arc(at,14,0,TAU,24,Color.GOLD,2,true)
	for shot:Dictionary in s.rounds:
		var at:Vector2=A if shot.target==0 else B
		if s.local>=shot.at-.3 and s.local<shot.at:
			var p:Vector2=origin.lerp(at,(s.local-shot.at+.3)/.3)
			preview.draw_circle(p,3,Color.GOLD if shot.damage>100 else Color.SKY_BLUE)
		if s.local>=shot.at and s.local<shot.at+.12:preview.draw_arc(at,11,0,TAU,20,Color.GOLD,2,true)
	preload("res://scripts/ui/talent_stack_indicator.gd").paint(preview,origin,"校距",s.charges,2,24)
	preview.draw_string(ThemeDB.fallback_font,Vector2(225,116),"最近直击：%s"%("尚未命中" if s.last_hit<0 else "%.0f"%s.damage),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
