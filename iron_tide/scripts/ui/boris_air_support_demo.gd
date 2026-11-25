extends RefCounted
const Soviet=preload("res://scripts/units/soviet_specials.gd")
const RELAY_LENGTH=27.0

static func recharge() -> float:
	return float(Soviet.Rules.type_data("BORIS").eliteairstrikerechargetime)/Soviet.TPS

static func duration(rank:int) -> float:
	return RELAY_LENGTH if rank==2 else (10.0+recharge())*(4 if rank==5 else 1)

static func sample(rank:int,t:float) -> Dictionary:
	if rank==2:
		var part:=mini(2,int(t/9));var local:=t-part*9
		var hit:=part!=1 and local>=2
		var tokens:Array=[]
		for i in 4:tokens.append(hit and local<7 and (i>0 or local<3))
		return {"part":part,"time":local,"hit":hit,"tokens":tokens,"left":maxf(0,7-local) if hit else 0.0,
			"second":part==2 and local>=4.5,"title":["空地接力 · 命中才发放一次半装填","空地接力 · 炸弹落空，不发放资格","空地接力 · 同编队后续命中不补资格"][part]}
	var segment:=10.0+recharge()
	var part:=mini(3,int(t/segment)) if rank==5 else 0
	var local:=t-part*segment
	var extra:=rank==5 and part!=1
	var invalid:=part>=2 and local>=2
	var aborted:=part==3 and invalid
	var count:=int(Soviet.Rules.type_data("BORIS").eliteairstriketeam)
	var end:=8.0 if extra and part!=3 else 6.0
	var main_count:=count if local>=1 and local<6 else 0
	var extra_count:=floori(count/2.0) if extra and local>=1 and local<(5 if part==3 else 8) else 0
	var cd:=maxf(0,recharge()-(local-end)) if local>=end else recharge()
	return {"part":part,"time":local,"extra":extra,"main":main_count,"secondary":extra_count,"invalid":invalid,"aborted":aborted,"retarget":part==2 and invalid,
		"occupied":main_count+extra_count>0,"cooldown":cd,"ready":local>=end and cd<=0,
		"title":["双目标空袭 · 主4＋副2，共占一轮","双目标空袭 · 无合法副建筑，仅主4架","双目标空袭 · 副楼失效，整组改派另一合法楼","双目标空袭 · 无替代副楼，额外两架撤退"][part] if rank==5 else "独立引导 · 可以移动开枪，不能再呼叫"}

static func draw(view,width:float,rank:int) -> void:
	var s:=sample(rank,view.elapsed)
	view._text(Vector2(8,22),s.title,UiKit.COL_GOLD)
	if rank==2:draw_relay(view,width,s);return
	var t:float=s.time
	var hero:=Vector2(width*.16+clampf(t-1,0,1)*25,105)
	var main:=Vector2(width*.69,93)
	var other:=Vector2(width*.84,112)
	var replacement:=Vector2(width*.94,92)
	view._text(Vector2(8,42),"飞行距离为示意；三星、无额外空袭补充加速",UiKit.COL_DIM)
	view._sprite("BORIS",hero,1.1,t>=1 and t<2)
	view._sprite("E2",Vector2(width*.43,108),1,false,Color(.95,.65,.65),2)
	if t>=2 and t<4 and fmod(t,.6)<.2:view.stage.draw_line(hero+Vector2(0,-18),Vector2(width*.43,90),Color.GOLD,2)
	view._sprite("NAPOWR",main,.35)
	if s.extra:
		if s.invalid:
			view.stage.draw_line(other-Vector2(15,20),other+Vector2(15,0),Color.ORANGE,3)
			view.stage.draw_line(other+Vector2(15,-20),other-Vector2(15,0),Color.ORANGE,3)
		else:view._sprite("NAPOWR",other,.3)
	if s.part==2:view._sprite("NAPOWR",replacement,.28)
	if s.invalid:view._text(Vector2(8,62),"副队不转打主楼；改派合法副楼" if s.retarget else "副队携弹撤退，不补主楼火力",Color.ORANGE)
	for group in 2:
		var count:int=s.main if group==0 else s.secondary
		for i in count:
			var target:Vector2=main if group==0 else replacement if s.retarget else other
			var exit_time:=6.0 if group==0 else 5.0 if s.aborted else 8.0
			var impact:=3.0 if group==0 else 4.0
			var from:=Vector2(width*.07,62+i*5)
			var at:=from.lerp(target-Vector2(0,30)+Vector2(i*9,0),clampf((t-1)/(impact-1),0,1))
			if group==1 and s.invalid:
				var junction:=from.lerp(other-Vector2(0,30)+Vector2(i*9,0),1.0/3.0)
				at=junction.lerp(Vector2(width+35,50+i*5) if s.aborted else target-Vector2(0,30)+Vector2(i*9,0),clampf((t-2)/(exit_time-2 if s.aborted else impact-2),0,1))
			if t>=impact and not (group==1 and s.aborted):at=at.lerp(Vector2(width+35,50+i*5),clampf((t-impact)/(exit_time-impact),0,1))
			view._sprite("BPLN",at,.34)
			if group==1 and s.aborted:view.stage.draw_circle(at+Vector2(0,5),2,Color.YELLOW)
			if t>=impact and t<impact+.45 and not (group==1 and s.aborted):view.stage.draw_circle(target+Vector2(i*3,-8),7,Color(1,.65,.2,.5))
	var status:="等待出发" if t<1 else "本轮剩余 %d 架 · 禁止第二轮"%(s.main+s.secondary) if s.occupied else "补充剩余 %.1f 秒 · 仍不可呼叫"%s.cooldown if not s.ready else "补充完成 · 可再次呼叫"
	view._text(Vector2(8,142),status,UiKit.COL_OK if s.ready else Color.CYAN)
	if t>=6 and s.secondary>0 and not s.invalid:view._text(Vector2(8,62),"主队已离场，副队仍占用；补充尚未开始",Color.ORANGE)

static func draw_relay(view,width:float,s:Dictionary) -> void:
	var t:float=s.time
	var target:=Vector2(width*.82,80)
	view._text(Vector2(8,42),"落点3格内最多4名同方步兵 · 资格保存5秒",UiKit.COL_DIM)
	view._sprite("NAPOWR",target,.36)
	if t<4:view._sprite("BPLN",Vector2(width*.45+clampf(t/4,0,1)*width*.5,60),.38)
	var impact:Vector2=target if s.part!=1 else target+Vector2(-70,-5)
	for impact_time:float in [2.0,4.5] if s.part==2 else [2.0]:
		if t>=impact_time-.7 and t<impact_time:view.stage.draw_circle(impact-Vector2(0,(impact_time-t)*35),3,Color.ORANGE)
		if t>=impact_time and t<impact_time+.4:view.stage.draw_arc(impact,15,0,TAU,24,Color.ORANGE,2)
	view._sprite("BORIS",Vector2(width*.11,104),1.0)
	for i in 4:
		var at:=Vector2(width*.29+i*width*.115,108)
		view._sprite("E2",at,1.0)
		view._text(at+Vector2(-26,22),"×0.5" if s.tokens[i] else "已用" if i==0 and s.hit and t>=3 else "无资格",Color.CYAN if s.tokens[i] else UiKit.COL_DIM)
		if i==0 and s.hit and t>=3 and t<3.3:view.stage.draw_line(at+Vector2(0,-18),target,Color.GOLD,2)
	var status:="等待首次实际命中" if t<2 else "落空：没有资格，也不触发装填减半" if not s.hit else "资格已过5秒，未使用的自然到期" if t>=7 else "同编队再命中：不补已用资格、不延长时限" if s.second else "资格剩余 %.1f 秒；第一名第3秒开火消耗一次"%s.left
	view._text(Vector2(8,146),status,UiKit.COL_OK)
