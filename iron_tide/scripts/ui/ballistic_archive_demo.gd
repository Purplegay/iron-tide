extends RefCounted
const LENGTH:=48.0
const SOURCE:=Vector2(48,76)
const BUILDING:=Vector2(266,70)
const OTHER:=Vector2(208,98)

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/12)
	var local:=fposmod(t,12)
	var values:Dictionary=GameData.get_skill("ps_ballistic_archive").values
	var cut:float=values.reload[rank]
	var bonus:float=values.damage[rank]*100
	var hit:=part!=1 and local>=1
	var launch:=9.5 if part==3 else 6.0
	var active:=hit and local<minf(9,launch) and not (part==2 and local>=2)
	var initial:=0.0 if part==3 else 4.0
	var original:=maxf(0,initial+1-local) if initial>0 else 0.
	var remaining:=maxf(0,initial*(1-cut)-(local-1)) if hit else original
	var second_bonus:=bonus if part==0 else 0.
	var title:String=["直击建筑 · 缩短当前CD并留档","火箭被拦截 · 无留档、无CD减免","转火清空 · 回头也不恢复资格","空闲CD不储存 · 八秒资格到期"][part]
	var text:="火箭正常接近建筑 · 溅射不重复计次"
	if part==1 and local>=.6:text="首枚被拦截 · 当前CD正常倒数"
	elif hit:text="留档 %.1fs · 同建筑下一发 +%.0f%%"%[9-local,bonus] if active else "资格已清空 · 当前CD减免不会撤回"
	if part==2 and local>=2:text="转打其他目标：留档清空" if local<3 else "转回原建筑：仍无增伤资格"
	if part==3 and local>=9:text="八秒资格已过期 · 下次普通装填无储存减免"
	if local>=launch:text="发射已消费 · 本枚增伤 %.0f%%"%second_bonus if second_bonus>0 else "普通发射 · 无留档增伤"
	if local>=launch+.4:text="强化弹被拦截 · 不退资格、不生成新留档" if second_bonus>0 else "普通弹被拦截 · 不生成新留档"
	return {"time":t,"local":local,"part":part,"active":active,"value":bonus,"charges":1 if active else 0,"left":9-local if active else 0.,
		"hit":hit,"title":title,"text":text,"remaining":remaining,"original":original,"initial":initial,"cut":cut,
		"launch":launch,"second_bonus":second_bonus,"aim_other":part==2 and local>=2 and local<3,
		"first_intercept":part==1 and local>=.6,"second_intercept":local>=launch+.4,"cycle_finished":local>=launch}

static func flight(stage,local:float,start:float,end:float,color:Color) -> void:
	if local<start or local>=end:return
	var progress:=clampf((local-start)/.8,0,1)
	var p:=SOURCE.lerp(BUILDING,progress)+Vector2(0,-sin(progress*PI)*22)
	stage.draw_line(p,p+Vector2(-7,5),color,3,true)

static func crossed(stage,progress:float) -> void:
	var p:=SOURCE.lerp(BUILDING,progress)+Vector2(0,-sin(progress*PI)*22)
	stage.draw_line(p-Vector2(6,6),p+Vector2(6,6),stage.FOE,2)
	stage.draw_line(p+Vector2(-6,6),p+Vector2(6,-6),stage.FOE,2)

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,29),"命中时剩余CD %.0fs示例 · 抬架速度不变"%s.initial,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(SOURCE,stage.ALLY)
	stage.draw_rect(Rect2(BUILDING-Vector2(18,19),Vector2(36,38)),stage.FOE,false,2)
	if s.part==2:stage.actor(OTHER,stage.FOE,PI,false)
	stage.ring(OTHER if s.aim_other else BUILDING,25,stage.MUTED)
	flight(stage,s.local,.2,.6 if s.part==1 else 1.,stage.ALLY)
	flight(stage,s.local,s.launch,s.launch+.4,stage.BONUS if s.second_bonus>0 else stage.ALLY)
	if s.first_intercept and s.local<.85:crossed(stage,.5)
	if s.second_intercept and s.local<s.launch+.65:crossed(stage,.5)
	if s.hit and s.local<1.2:stage.ring(BUILDING,30,stage.FOE)
	if s.active:
		stage.ring(BUILDING,29,stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,BUILDING+Vector2(-26,-33),"%.1fs +%.0f%%"%[s.left,s.value],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	if s.cycle_finished:
		stage.draw_string(ThemeDB.fallback_font,Vector2(96,108),"本轮已结束 · 后续装填正常计算",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	else:
		stage.draw_rect(Rect2(94,91,120,4),stage.MUTED)
		stage.draw_rect(Rect2(94,91,120*clampf(s.remaining/5.,0,1),4),stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(94,111),"当前 %.2fs／未减免 %.2fs"%[s.remaining,s.original],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
