extends RefCounted
const LENGTH:=54.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/18)
	var local:=fposmod(t,18)
	var weapon:Dictionary=GameData.get_unit("E1").deployed_weapon
	var base:float=weapon.cooldown
	var cut:float=MetaProgress.talent_options("E1")["position_rotation"].values.reload[rank]
	var quick:=base*(1-cut)
	var rounds:Array=[]
	if part==0:
		for i in 4:rounds.append({"at":4+i*quick,"quick":i<3})
	elif part==1:
		rounds=[{"at":4.,"quick":true},{"at":8.,"quick":true},{"at":8.+quick,"quick":true}]
	else:rounds=[{"at":4.,"quick":true},{"at":14.,"quick":true}]
	var deployed:=part!=2 or local<5 or local>=10
	var rearm:float=13. if part==2 else maxf(13,float(rounds.back().at)+3)
	var charges:=3 if local>=3 else 0
	var remaining:=0.0
	var cycle:=base
	var discounted:=false
	var last_shot:=0.0
	for shot:Dictionary in rounds:
		if local<shot.at:continue
		last_shot=shot.at
		if shot.quick:charges-=1
		cycle=quick if shot.quick else base
		remaining=maxf(0,cycle-(local-shot.at));discounted=shot.quick and remaining>0
	if part==2 and local>=5:charges=0
	if local>=rearm:
		charges=2 if part==2 and local>=14 else 3
	var interval:=maxf(0,(rearm+10 if local>=rearm else 13)-local) if local>=3 else 0.
	var idle:=minf(3,local) if local<3 else 0.
	if local>=3 and charges==0 and deployed:idle=minf(3,local-(10 if part==2 else last_shot))
	var title:String=["三轮快速装填 · 第四轮恢复正常","中途停火不补次数 · 两次额度仍保留","起身清空 · 再卧倒重等三秒与间隔"][part]
	var text:="卧倒停火 %.1f/3秒"%idle if local<3 else "快速装填 %d/3 · 剩余间隔 %.1fs"%[charges,interval]
	if part==1 and local>=4+quick and local<8:text="停火等待 · 仍剩2次，不补回3次"
	if part==2 and local>=5 and local<10:text="已起身：剩余资格清空，间隔不重置"
	elif part==2 and local>=10 and local<rearm:text="再次卧倒 %.1f/3秒 · 间隔仍剩%.1fs"%[idle,interval]
	if local>=rearm:text="满足停火与间隔 · 新一组三次资格"
	if part==2 and local>=14:text="新一组已用一次 · 剩余2次"
	return {"time":t,"local":local,"part":part,"active":charges>0,"value":cut*100,"charges":charges,"text":text,"title":title,
		"deployed":deployed,"rearm":rearm,"interval":interval,"idle":idle,"base":base,"quick":quick,"remaining":remaining,"cycle":cycle,
		"discounted":discounted,"rounds":rounds,"burst":int(weapon.get("burst",1)),"burst_delay":float(weapon.get("burst_delay",0))}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"普通兵无额外增益 · 每轮只缩短新装填",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
	preload("res://scripts/ui/talent_stack_indicator.gd").paint(preview,origin,"轮值",s.charges,3,24)
	for shot:Dictionary in s.rounds:
		for i in s.burst:
			var start:float=shot.at+i*s.burst_delay
			if s.local>=start and s.local<start+.18:
				var p:Vector2=origin.lerp(preview.MAIN_POINT,(s.local-start)/.18)
				preview.draw_line(p,p+Vector2(-8,0),Color.GOLD if shot.quick else Color.SKY_BLUE,2,true)
	preview.draw_rect(Rect2(230,88,140,5),Color.DIM_GRAY)
	preview.draw_rect(Rect2(230,88,140*clampf(s.remaining/s.base,0,1),5),Color.GOLD if s.discounted else Color.SKY_BLUE)
	preview.draw_string(ThemeDB.fallback_font,Vector2(230,109),"剩余 %.2fs · 普通 %.2fs"%[s.remaining,s.base],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SKY_BLUE)
	preview.draw_string(ThemeDB.fallback_font,Vector2(230,127),"快速装填 %.2fs · 三轮额度"%s.quick,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
