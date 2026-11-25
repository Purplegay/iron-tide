extends RefCounted
const LENGTH:=48.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=0 if t<16 else 1+int((t-16)/8)
	var local:=t if part==0 else fposmod(t-16,8)
	var fraction:float=MetaProgress.talent_options("E2")["alternate_advance"].values.reload[rank]
	var weapon:Dictionary=GameData.get_unit("E2").weapon
	var base:float=weapon.cooldown
	var quick:=base*(1-fraction)
	var moves:Array=[]
	match part:
		0:moves=[Vector2(0,2),Vector2(4,6),Vector2(9,11),Vector2(11.2,13.2)]
		1:moves=[Vector2(0,1),Vector2(2,3)]
		3:moves=[Vector2(0,2),Vector2(3,5)]
		4:moves=[Vector2(0,2)]
	var distance:=0.
	var moving:=false
	var age:=0.
	for interval:Vector2 in moves:
		distance+=clampf(local-interval.x,0,interval.y-interval.x)*8
		if local>=interval.x and local<interval.y:moving=true;age=minf(2,local-interval.x)
	var grant:=13.2 if part==0 and local>=13.2 else 2. if part==0 else 5. if part==3 else -1.
	var left:=maxf(0,grant+5-local) if grant>=0 and local>=grant else 0.
	var cooldown:=maxf(0,grant+10-local) if grant>=0 and local>=grant else 0.
	var rounds:Array=[]
	if part==0:
		var at:=2.2
		while at<4:
			rounds.append({"at":at,"quick":true});at+=quick
		at=6.9
		while at<9:
			rounds.append({"at":at,"quick":at<7});at+=quick if at<7 else base
		at=13.4
		while at<16:
			rounds.append({"at":at,"quick":true});at+=quick
	elif part==3:rounds=[{"at":5.2,"quick":true},{"at":5.2+quick,"quick":true}]
	else:rounds=[{"at":3.5,"quick":false}]
	var remaining:=0.
	var discounted:=false
	var damage:=0.
	for shot:Dictionary in rounds:
		if shot.at>local:break
		var cycle:=quick if shot.quick else base
		remaining=maxf(0,shot.at+cycle-local);discounted=shot.quick and remaining>0
		damage=100*(1+fraction if shot.quick else 1)
	var title:String=["实际移动两秒后停下 · 强化五秒","两段各一秒 · 中途停下，不能合并","原地转向 · 没有实际位移，不蓄势","控制中止不算停下 · 解控后重新移动","临时召唤物 · 不继承交替推进"][part]
	var text:="实际连续移动 %.1f/2秒"%age
	if left>0:text="攻击／新装填 +%d%%／-%d%% · %.1fs"%[fraction*100,fraction*100,left]
	elif cooldown>0:text="强化已结束 · 间隔%.1fs · 旧装填不改写"%cooldown
	elif not moving:text="没有强化 · 普通攻击与装填保持原值"
	var controlled:=part==3 and local>=2 and local<3
	if controlled:text="受控中止：丢弃两秒移动资格"
	return {"time":t,"local":local,"part":part,"active":left>0,"value":fraction*100,"charges":0,"text":text,"title":title,
		"left":left,"cooldown":cooldown,"moving":moving,"distance":distance,"speed":8.,"age":age,"turning":part==2 and local<3,
		"controlled":controlled,"rounds":rounds,"base":base,"quick":quick,"remaining":remaining,"discounted":discounted,"damage":damage}

static func draw(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"再移动不刷新 · 开火不消耗 · 十秒触发间隔",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	preview.draw_dashed_line(Vector2(123,104),origin,Color.SKY_BLUE,2,6)
	preview.draw_circle(preview.MAIN_POINT,7,Color.SALMON)
	if s.active:preview.draw_arc(origin,24,0,TAU,28,Color.GOLD,2,true)
	if s.controlled:preview.draw_string(ThemeDB.fallback_font,origin+Vector2(-12,-25),"受控",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.SALMON)
	for shot:Dictionary in s.rounds:
		if s.local>=shot.at and s.local<shot.at+.12:preview.draw_line(origin,preview.MAIN_POINT,Color.GOLD if shot.quick else Color.SKY_BLUE,2,true)
	preview.draw_rect(Rect2(220,86,150,4),Color.DIM_GRAY)
	preview.draw_rect(Rect2(220,86,150*clampf(s.remaining/s.base,0,1),4),Color.GOLD if s.discounted else Color.SKY_BLUE)
	preview.draw_string(ThemeDB.fallback_font,Vector2(220,106),"本轮装填剩余%.2fs／普通%.2fs"%[s.remaining,s.base],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.SKY_BLUE)
	preview.draw_string(ThemeDB.fallback_font,Vector2(220,125),"最近伤害%.0f · 间隔%.1fs"%[s.damage,s.cooldown],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GOLD)
