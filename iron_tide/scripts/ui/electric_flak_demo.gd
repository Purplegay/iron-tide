extends RefCounted
const POLAR_LENGTH:=48.0
const FLAK_LENGTH:=24.0
const CELL:=20.0
const FIRST:=Vector2(215,52)
const SECOND:=Vector2(250,88)

static func polar(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,POLAR_LENGTH)
	var part:=int(t/6)
	var local:=fposmod(t,6)
	var second_at:=4.0 if part==2 else 2.0
	var formed:=part not in [1,2] and local>=2
	var broken:=part>=4 and local>=3
	var active:=formed and not broken and local<5
	var ticks:=clampi(floori((minf(local,2.99999 if part>=4 else 5.0)-2)*2+.000001),0,6) if formed else 0
	var per_tick:float=GameData.get_skill("ps_polar_link").values.damage[rank]*50
	var title:String=["双目标成链 · 第三人不受电链伤害","连续攻击同一目标 · 不成链","第二次超过3秒 · 重新开始配对","W分支不计数 · 普通主击仍可配对","拉开超过4格断链 · 靠近不恢复","一端死亡 · 立即断链","一端变友方 · 立即断链","一端被装载 · 立即断链"][part]
	var text:="两次普通主击配对 · 窗口3秒"
	if formed:text="已跳 %d/6 · 两端各追加 %.1f%% · 中间0"%[ticks,ticks*per_tick]
	if broken:text="已断链 · 停止后续跳伤 · 不重新连接"
	elif formed and local>=5:text="六跳结束 · 3秒到期 · 生成间隔8秒"
	elif part==1 and local>=second_at:text="同一个目标不满足双端条件"
	elif part==2 and local>=second_at:text="旧窗口已过期 · 此次只登记新首目标"
	return {"time":t,"local":local,"part":part,"active":active,"value":per_tick*2,"charges":ticks,
		"formed":formed,"broken":broken,"second_at":second_at,"tick_damage":per_tick,
		"extra_each":ticks*per_tick,"middle_extra":0,"title":title,"text":text}

static func endpoint(s:Dictionary) -> Vector2:
	if s.part==4 and s.local>=3 and s.local<4:return FIRST+Vector2(100,0)
	return SECOND

static func label(stage,point:Vector2,text:String,color:Color=Color.WHITE) -> void:
	stage.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

static func draw_polar(stage,s:Dictionary) -> void:
	var caster:=Vector2(55,75)
	var second:=endpoint(s)
	var middle:=FIRST.lerp(SECOND,.5)
	stage.actor(caster,stage.ALLY)
	stage.actor(FIRST,stage.FOE,PI,false)
	stage.draw_circle(middle,5,stage.MUTED)
	var hidden:bool=s.broken and s.part==7
	var dead:bool=s.broken and s.part==5
	if not hidden:stage.actor(second,stage.ALLY if s.broken and s.part==6 else stage.MUTED if dead else stage.FOE,PI,false)
	if dead:
		stage.draw_line(second-Vector2(8,8),second+Vector2(8,8),Color.RED,2)
		stage.draw_line(second+Vector2(-8,8),second+Vector2(8,-8),Color.RED,2)
	if hidden:stage.draw_rect(Rect2(second-Vector2(13,9),Vector2(26,18)),stage.MUTED,false,2)
	for shot in [[.5,FIRST],[s.second_at,FIRST if s.part==1 else SECOND]]:
		if s.local>=shot[0] and s.local<shot[0]+.15:stage.draw_line(caster,shot[1],Color.SKY_BLUE,2,true)
	if s.part==3 and s.local>=.5 and s.local<.7:stage.draw_line(FIRST,SECOND,Color.VIOLET,3,true)
	if s.active:stage.draw_line(FIRST,second,Color.SKY_BLUE,2,true)
	for tick in 6:
		var when:=2.5+tick*.5
		if s.charges>=tick+1 and s.local>=when and s.local<when+.15:
			stage.ring(FIRST,18,stage.BONUS);stage.ring(second,18,stage.BONUS)
	label(stage,Vector2(8,14),s.title,stage.BONUS)
	label(stage,Vector2(8,30),"独立示例 · 每0.5秒各追加 %.1f%%"%s.tick_damage,Color.SKY_BLUE)
	label(stage,Vector2(158,116),"A / B 累计各 +%.1f%%"%s.extra_each,stage.BONUS)
	label(stage,middle+Vector2(-65,3),"中间 +0",stage.MUTED)

static func flak(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,FLAK_LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var attack:=200.0 if part==1 else 100.0
	var fraction:float=GameData.get_skill("ap_flak_fan").values.damage[rank]
	var last:=-1.0
	for when:float in [.6,2.6,4.6,5.6]:
		if local>=when:last=when
	var extra:=attack*fraction if last>=0 and last<5 and part!=2 else 0.0
	return {"time":t,"local":local,"part":part,"active":local<5,"value":fraction*100,"charges":0,
		"attack":attack,"last":last,"flash":last>=0 and local<last+.16,
		"extra":extra,"direct":attack if last>=0 else 0.0,"main":attack+extra if last>=0 else 0.0,
		"ground_extra":0,"friendly_extra":0,"far_extra":0,
		"title":["单发基准100 · 主目标直击＋追加","单发基准200 · 追加随攻击成长","W期间对地开火 · 无防空追加"][part],
		"text":"追加半径0.8格 · 原生范围伤害保留" if local<5 else "5秒到期 · 新攻击无追加 · CD24秒"}

static func draw_flak(stage,s:Dictionary) -> void:
	var caster:=Vector2(47,76)
	var main:=Vector2(230,62)
	var neighbor:=main+Vector2(22,10)
	var friend:=main+Vector2(-10,-18)
	var ground:=main+Vector2(-12,18)
	var far:=Vector2(312,62)
	stage.actor(caster,stage.ALLY)
	if s.active:stage.ring(caster,21,stage.BONUS)
	stage.actor(main,stage.FOE,PI,false)
	stage.draw_circle(neighbor,5,stage.FOE);stage.draw_circle(friend,5,stage.ALLY)
	stage.draw_rect(Rect2(ground-Vector2(4,4),Vector2(8,8)),stage.MUTED)
	stage.draw_circle(far,5,stage.FOE)
	if s.flash:
		stage.draw_line(caster,ground if s.part==2 else main,stage.ALLY,2,true)
		if s.extra>0:stage.ring(main,28,stage.BONUS)
	label(stage,Vector2(8,14),s.title,stage.BONUS)
	label(stage,Vector2(8,30),"数值为伤害基准示例，实战仍计算护甲",stage.MUTED)
	label(stage,Vector2(8,109),("地面主目标：" if s.part==2 else "上次主目标：")+"%.0f + %.0f = %.0f"%[s.direct,s.extra,s.main],stage.BONUS)
	label(stage,Vector2(8,123),"邻机：原生伤害 + %.0f"%s.extra,stage.BONUS)
	label(stage,Vector2(267,88),"范围外 +0",stage.MUTED)
	label(stage,Vector2(197,108),"友机／地面追加0",stage.MUTED)
