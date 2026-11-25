extends RefCounted
const LENGTH:=24.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var accepted:=part<2 and local>=1
	var end:=7. if part==0 else 3.
	var active:=accepted and local<end
	var moving:=part==1 and local>=3 and local<5 or part==2 and local<3
	var distance:=clampf(local-3,0,2)*18 if part==1 else minf(local,3)*18 if part==2 else 0.
	var value:float=GameData.get_skill("ap_observer_line").values.sight[rank]
	var cooldown:=maxf(0,25-local) if accepted else 0.
	var titles:=["静止观察 · 正常开火 · 六秒自然到期","提前移动取消 · 停下不会自动恢复","移动中按W失败 · 停下不会补执行"]
	var text:="1秒按W · 仅扩展视野，不反隐／反潜"
	if local>=1:
		text="视野 +%s格 · 剩余%.1fs · W冷却%.1fs"%[str(value),7-local,cooldown] if active else "观察结束 · 视野恢复 · W冷却%.1fs"%cooldown
		if part==1 and local>=3:text="移动提前取消 · 停下不恢复 · W冷却%.1fs"%cooldown
		if part==2:text="移动施放失败 · W冷却0 · 停下不自动施放"
	return {"time":t,"local":local,"part":part,"active":active,"value":value,"charges":0,"text":text,"title":titles[part],
		"moving":moving,"distance":distance,"cooldown":cooldown,"left":maxf(0,7-local) if active else 0.,"shot":part<2 and local>=2.2 and local<2.36}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42 if s.moving else Vector2.ZERO

static func draw(stage,s:Dictionary) -> void:
	var a:Vector2=Vector2(100,78)+Vector2(s.distance,0)
	var target:=Vector2(150,78)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(202,40),"青：视野",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(202,57),"金：射程不变",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(202,74),"圈半径为示意",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_arc(a,39,0,TAU,48,stage.MUTED,1,true)
	stage.draw_arc(a,39+(s.value*9 if s.active else 0),0,TAU,48,stage.ALLY,2,true)
	stage.draw_arc(a,53,0,TAU,48,stage.BONUS,1,true)
	stage.actor(a,stage.ALLY);stage.actor(target,stage.FOE,PI,false)
	if s.shot:stage.draw_line(a,target,stage.ALLY,2,true)
	stage.draw_string(ThemeDB.fallback_font,Vector2(202,103),"开火时机",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_string(ThemeDB.fallback_font,Vector2(202,120),"不改变普通装填",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
