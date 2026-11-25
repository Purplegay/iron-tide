extends RefCounted
## Independent demonstration timelines; never mutate a battle actor or its timers.
static func water_duration() -> float:
	return preload("res://scripts/ui/water_relay_demo.gd").duration()

static func sample(id:String,rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,8.0)
	var active:=t<4
	var values:Dictionary=GameData.get_skill(id).values
	if id=="ap_escort_water":
		return preload("res://scripts/ui/water_relay_demo.gd").sample(rank,time)
	var base:float=GameData.get_unit("DEST").weapon.cooldown
	var cut:float=values.reload[rank]
	var normal:=launches(base,0)
	var boosted:=launches(base,cut)
	return {"time":t,"active":active,"value":cut*100,"charges":0,
		"normal":normal,"boosted":boosted,"base":base,
		"normal_wait":remaining(normal,t),"boosted_wait":remaining(boosted,t),
		"speed":.85 if active else 1.0,"damage":105 if active else 100,
		"normal_x":t*6,"boosted_x":minf(t,4)*6*.85+maxf(0,t-4)*6,
		"text":"直接武器装填 -%d%% · 持续4秒"%(cut*100) if active else "到期：新装填恢复 · 进行中的装填不改写"}

static func launches(base:float,cut:float) -> Array[float]:
	var times:Array[float]=[]
	var next:=.3
	while next<8+base:
		times.append(next)
		next+=base*(1-cut if next<4 else 1.0)
	return times

static func remaining(times:Array[float],time:float) -> float:
	if time<times[0]:return 0.0
	for next:float in times:
		if next>time:return next-time
	return 0.0

static func label(stage,point:Vector2,text:String,color:Color) -> void:
	stage.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

static func draw_water(stage,s:Dictionary) -> void:
	preload("res://scripts/ui/water_relay_demo.gd").draw(stage,s)

static func draw_ballast(stage,s:Dictionary) -> void:
	for row in 2:
		var origin:=Vector2(40+(s.normal_x if row==0 else s.boosted_x),42+row*52)
		var target:=Vector2(315,origin.y)
		stage.actor(origin,stage.ALLY);stage.actor(target,stage.FOE,PI,false)
		var times:Array[float]=s.normal if row==0 else s.boosted
		for time:float in times:stage.shot(origin,target,time,row==1 and time<4)
		var wait:float=s.normal_wait if row==0 else s.boosted_wait
		stage.draw_rect(Rect2(155,origin.y+7,110,4),stage.MUTED)
		stage.draw_rect(Rect2(155,origin.y+7,110*clampf(wait/s.base,0,1),4),stage.BONUS if row==1 else stage.ALLY)
		label(stage,Vector2(145,origin.y-6),("原装" if row==0 else "压舱")+" · 装填 %.2fs"%wait,stage.ALLY)
		label(stage,Vector2(8,origin.y+24),"航速 %d%% · 远程承伤示例 %d"%[100 if row==0 else roundi(s.speed*100),100 if row==0 else s.damage],stage.BONUS if row==1 else stage.MUTED)
	label(stage,Vector2(8,13),"驱逐舰对照 · 不加速鱼鹰补充或技能CD",stage.BONUS)
