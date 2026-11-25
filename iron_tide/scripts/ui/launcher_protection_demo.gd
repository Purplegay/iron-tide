extends RefCounted
const Native=preload("res://scripts/world/special_rules.gd")
const Racks=preload("res://scripts/units/soviet_advanced.gd")

static func departure(id:String) -> float:
	var prefix:="V3Rocket" if id=="launch_bulkhead" else "DMisl"
	return (Native.general(prefix+"PauseFrames",0)+Native.general(prefix+"TiltFrames",60))/15.

static func span(id:String) -> float:
	if id=="launch_bulkhead":return departure(id)+4.
	var data:Dictionary=GameData.get_unit("DRED")
	return departure(id)+float(data.weapon.burst_delay)+maxf(float(data.rocket.reload),4.)+1.5

static func duration(id:String) -> float:
	return span(id)*(4 if id=="launch_bulkhead" else 3)

static func sample(id:String,rank:int,time:float) -> Dictionary:
	return bulkhead(rank,time) if id=="launch_bulkhead" else magazine(rank,time)

static func bulkhead(rank:int,time:float) -> Dictionary:
	var id:="launch_bulkhead"
	var t:=fposmod(time,duration(id))
	var part:=int(t/span(id))
	var local:=fposmod(t,span(id))
	var release:=departure(id)
	var maximum:float=GameData.get_unit("V3").hp
	var value:float=MetaProgress.talent_options("V3")[id].values.shield[rank]*100
	var pool:=maximum*value/100
	var departed:=part!=2 and local>=release
	var left:=maxf(0,release+3-local) if departed else 0.
	var shield:=pool if left>0 else 0.
	var hp:=maximum
	if part==1 and local>=release+.5 and local<release+1:shield=pool*.5
	if part==1 and local>=release+1:shield=0.;left=0.;hp-=7
	var destroyed:=part==2 and local>=release*.5 or part==3 and local>=release+1
	var removed:=destroyed or local>=release+2.5
	var loss:=release*.5 if part==2 else release+1
	var reload:float=GameData.get_unit("V3").rocket.reload
	var start_reload:=release*.5 if part==2 else release
	var rack:=maxf(0,start_reload-local)+reload if local<start_reload else maxf(0,reload-(local-start_reload))
	var title:String=["真实离架才给发射车护盾 · 三秒到期","发射车受伤先扣盾 · 击破溢出扣生命","在架火箭被毁 · 不授予车体护盾","离架火箭仍可击落 · 车体盾独立保留"][part]
	var text:="仍在抬架 · 发射车无盾，火箭也无盾"
	if departed:text="发射车盾 %.1f · 剩余%.1fs · 间隔%.1fs"%[shield,left,maxf(0,release+12-local)]
	if part==2 and destroyed:text="未真实离架：车体盾0，触发间隔0"
	return {"time":t,"local":local,"part":part,"value":value,"charges":0,"active":shield>0,"text":text,"title":title,
		"release":release,"departed":departed,"left":left,"cooldown":maxf(0,release+12-local) if departed else 0.,
		"shield":shield,"pool":pool,"hp":hp,"maximum":maximum,"destroyed":destroyed,"removed":removed,"loss":loss,"racks":[rack]}

static func magazine(rank:int,time:float) -> Dictionary:
	var id:="escort_magazine"
	var t:=fposmod(time,duration(id))
	var part:=int(t/span(id))
	var local:=fposmod(t,span(id))
	var data:Dictionary=GameData.get_unit("DRED")
	var values:Dictionary=MetaProgress.talent_options("DRED")[id].values
	var reduction:float=values.reload[rank]
	var reload:float=data.rocket.reload*(1-reduction)
	var base:float=data.rocket.reload
	var delay:float=data.weapon.burst_delay
	var prep:=departure(id)
	var maximum:float=GameData.get_unit("DMISL").hp
	var pool:float=maximum*values.shield[rank]
	var missiles:Array=[]
	var racks:Array=[]
	for i in 2:
		var start:=i*delay
		var release:=start+prep
		var killed_at:=INF
		if i==0:killed_at=release+3 if part==0 else prep*.5 if part==1 else release+.5
		var destroyed:=local>=killed_at
		var departed:=local>=release and not (part==1 and i==0)
		var impact:=local>=release+4 and not destroyed
		var shield:=pool if departed and not destroyed and not impact else 0.
		var hp:=maximum
		if i==0 and part==0:
			if local>=release+1 and local<release+2:shield=pool-5
			if local>=release+2:shield=0.;hp-=7
		if destroyed or impact:hp=0.
		var reload_at:=minf(release,killed_at)
		var pending:=maxf(0,release-local) if local>=start and local<reload_at else 0.
		var remaining:=reload if local>=start and local<reload_at else maxf(0,reload-(local-reload_at)) if local>=reload_at else 0.
		racks.append(pending+remaining)
		missiles.append({"start":start,"release":release,"departed":departed,"destroyed":destroyed,"impact":impact,"shield":shield,"hp":hp,
			"pending":pending,"remaining":remaining,"reload_at":reload_at,"killed_at":killed_at,"visible":local>=start and not destroyed and not impact})
	var title:String=["双架独立补弹 · 拦截先破盾，仍可击落","第一枚在架被毁 · 第二枚正常离架获盾","直接摧毁效果 · 有盾仍按原规则移除"][part]
	var text:="仅补弹缩短%d%% · 抬架与双弹间隔不变"%(reduction*100)
	if part==0 and local>=prep+2:text="第一枚盾已耗尽，溢出扣7耐久 · 第二枚盾独立"
	if part==0 and local>=prep+3:text="第一枚已击落 · 护盾不会恢复，也不产生破盾爆炸"
	if part==1 and local>=prep*.5:text="在架被毁不获盾 · 该架从被毁时开始正常补弹"
	if part==2 and local>=prep+.5:text="直接摧毁不是数值扣伤 · 护盾不能阻止移除"
	return {"time":t,"local":local,"part":part,"value":reduction*100,"charges":0,"active":missiles.any(func(m):return m.shield>0),"text":text,"title":title,
		"missiles":missiles,"racks":racks,"base":base,"reload":reload,"delay":delay,"prep":prep,"pool":pool,"maximum":maximum}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.special.missile_racks=s.racks.duplicate()
	Racks.sync_rack(actor)

static func point(origin:Vector2,local:float,start:float,release:float,end:float,index:int,id:String) -> Vector2:
	var mount:=origin+Vector2(-9+index*18,-15)
	var pause:=Native.general("V3RocketPauseFrames" if id=="launch_bulkhead" else "DMislPauseFrames",0)/15.
	var raised:=mount+Vector2(0,-18*clampf((local-start-pause)/(release-start-pause),0,1))
	if local<release:return raised
	var phase:=clampf((local-release)/(end-release),0,1)
	return (mount-Vector2(0,18)).lerp(Vector2(330,52+index*24),phase)+Vector2(0,-sin(phase*PI)*20)

static func missile(preview,p:Vector2,id:String,local:float,start:float,release:float) -> void:
	var prefix:="V3Rocket" if id=="launch_bulkhead" else "DMisl"
	var pause:=Native.general(prefix+"PauseFrames",0)/15.
	var phase:=clampf((local-start-pause)/(release-start-pause),0,1)
	var pitch:=lerpf(Native.general(prefix+"PitchInitial",0),Native.general(prefix+"PitchFinal",.5),phase)*PI*.5
	var axis:=Vector2.from_angle(-pitch)
	preview.draw_line(p-axis*6,p+axis*6,Color.ORANGE,4,true)

static func draw(preview,origin:Vector2,id:String,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,36),"原生抬架／补弹时长 · 飞行位置与来伤为示意",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	if id=="launch_bulkhead":
		var p:=point(origin,minf(s.local,s.loss) if s.destroyed else s.local,0,s.release,s.release+2.5,0,id)
		if not s.removed:missile(preview,p,id,s.local,0,s.release)
		if s.active:preview.draw_arc(origin,29,0,TAU,28,Color.CYAN,2,true)
		if s.destroyed and s.local<s.loss+.18:preview.draw_arc(p,12,0,TAU,20,Color.SALMON,2,true)
		preview.draw_string(ThemeDB.fallback_font,origin+Vector2(-66,23),"车体生命%.0f · 盾%.1f"%[s.hp,s.shield],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.CYAN)
		preview.draw_string(ThemeDB.fallback_font,Vector2(224,111),"火箭护盾：0",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
		preview.draw_string(ThemeDB.fallback_font,Vector2(224,128),"真实离架：%.2fs"%s.release,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GRAY)
	else:
		for i in 2:
			var m:Dictionary=s.missiles[i]
			var p:=point(origin,minf(s.local,m.killed_at),m.start,m.release,m.release+4,i,id)
			if m.visible:
				missile(preview,p,id,s.local,m.start,m.release)
				preview.draw_string(ThemeDB.fallback_font,p+Vector2(-8,-17),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
				if m.shield>0:
					preview.draw_line(p+Vector2(-12,-11),p+Vector2(12,-11),Color.DIM_GRAY,3)
					preview.draw_line(p+Vector2(-12,-11),p+Vector2(-12+24*m.shield/s.pool,-11),Color.CYAN,3)
				if i==0 and s.part==0:
					for offset in [1.,2.,3.]:
						if s.local>=m.release+offset and s.local<m.release+offset+.12:preview.draw_line(Vector2(380,76),p,Color.SALMON,2,true)
			if m.destroyed and s.local<m.killed_at+.18:preview.draw_arc(p,12,0,TAU,20,Color.SALMON,2,true)
			var y:=107.+i*20
			preview.draw_rect(Rect2(210,y-5,100,4),Color.DIM_GRAY)
			preview.draw_rect(Rect2(210,y-5,100*m.remaining/s.base,4),Color.CYAN)
			preview.draw_string(ThemeDB.fallback_font,Vector2(205,y+9),"架%d 抬%.2f／补%.2f  盾%.1f／命%.0f"%[i+1,m.pending,m.remaining,m.shield,m.hp],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.SKY_BLUE)
