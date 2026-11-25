extends RefCounted
const LENGTH:=32.0
const CENTER:=Vector2(246,73)
const OTHER:=Vector2(265,73)
const RADIUS:=37.5

static func target_point(part:int,time:float) -> Vector2:
	return CENTER+Vector2(clampf(time-3,0,1)*80 if part==1 else 0.,0)

static func zones(rank:int,part:int,time:float) -> Array:
	var values:Array=GameData.get_skill("ps_impact_calibration").values.damage
	return [{"point":CENTER,"left":maxf(0,5-time) if time>=1 else 0.,"value":20. if part==3 else float(values[rank])*100},
		{"point":OTHER,"left":maxf(0,6-time) if time>=2 else 0.,"value":12. if part==3 else float(values[maxi(0,rank-2)])*100}]

static func bonus_at(rank:int,part:int,time:float) -> float:
	var value:=0.
	for zone:Dictionary in zones(rank,part,time):
		if zone.left>0 and target_point(part,time).distance_to(zone.point)<=RADIUS:value=maxf(value,zone.value)
	return value

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var deployed:=part!=2 or local<3
	var field_bonus:=bonus_at(rank,part,local)
	var value:=field_bonus if deployed else 0.
	var ordinary:=0.
	var seismic:=0.
	var ordinary_at:=-1.
	var seismic_at:=-1.
	var rounds:Array=[]
	for at:float in [1.,2.,3.2,5.2,6.2]:
		var multiplier:=0. if at==1 else bonus_at(rank,part,at)
		var peer:bool=at==2 or (part==2 and at>=3)
		rounds.append({"at":at,"damage":100+multiplier,"peer":peer})
		if local>=at:ordinary=100+multiplier;ordinary_at=at
	for at:float in [3.,4.,5.,6.,7.]:
		if local<at:continue
		var hits:=target_point(part,at).distance_to(CENTER)<=RADIUS
		seismic=100+(bonus_at(rank,part,at) if part!=2 or at<3 else 0.) if hits else 0.
		seismic_at=at
	var title:String=["普通炮与震地锚 · 每次结算只取一份校射","目标移出区域 · 普通炮无加成／余震可躲开","起飞取消自身收益 · 旧区仍供同方部署炮","独立重叠例：12%＋20%仅取20%，随后12%"][part]
	var text:="普通首击不追溯增伤 · 命中后才生成四秒区域"
	if local>=1:text="自身校射 +%.0f%% · 同方部署炮 +%.0f%% · 生成间隔 %.1fs"%[value,field_bonus,maxf(0,7-local)]
	if part==1 and local>=4:text="目标已离开两个区 · 普通炮回到原值，固定余震落空"
	if part==2 and local>=3:text="自身已起飞：不享受校射 · 同方部署炮仍按最高区获益"
	return {"time":t,"local":local,"part":part,"active":value>0,"value":value,"charges":0,"title":title,"text":text,
		"point":target_point(part,local),"zones":zones(rank,part,local),"deployed":deployed,"field_bonus":field_bonus,
		"cooldown":maxf(0,7-local) if local>=1 else 0.,"ordinary":ordinary,"seismic":seismic,"ordinary_at":ordinary_at,"seismic_at":seismic_at,"rounds":rounds}

static func sync_actor(actor,s:Dictionary) -> void:
	actor._deployed=s.deployed
	actor.logistics.air_lift=0. if s.deployed else 20.
	actor.special.erase("siege_progress")
	preload("res://scripts/units/siege_chopper.gd").appearance(actor,"SCHD" if s.deployed else "SCHP")

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,29),"各自原伤害按100对照 · 截取余震前段 · 25像素/格",HORIZONTAL_ALIGNMENT_LEFT,-1,9,stage.MUTED)
	var own:Vector2=stage.A-Vector2(0,12 if not s.deployed else 0)
	var peer:=Vector2(104,101)
	stage.actor(own,stage.ALLY)
	stage.actor(peer,stage.ALLY,0,false)
	stage.draw_string(ThemeDB.fallback_font,peer+Vector2(-21,17),"同方部署炮",HORIZONTAL_ALIGNMENT_LEFT,-1,9,stage.ALLY)
	stage.actor(s.point,stage.FOE,PI,false)
	stage.draw_circle(OTHER,5,stage.FOE)
	for i in 2:
		var zone:Dictionary=s.zones[i]
		if zone.left<=0:continue
		stage.ring(zone.point,RADIUS,stage.ALLY if i==0 else stage.BONUS)
		stage.draw_string(ThemeDB.fallback_font,Vector2(169,46+i*13),"区%d +%.0f%%／%.1fs"%[i+1,zone.value,zone.left],HORIZONTAL_ALIGNMENT_LEFT,-1,9,stage.ALLY if i==0 else stage.BONUS)
	for shot:Dictionary in s.rounds:
		if s.local>=shot.at-.3 and s.local<shot.at:
			var from:Vector2=peer if shot.peer else own
			var end:Vector2=OTHER if shot.at==2 else target_point(s.part,shot.at)
			var tip:=from.lerp(end,(s.local-shot.at+.3)/.3)
			stage.draw_circle(tip,3,stage.ALLY)
	if s.local>=2 and s.local<3:stage.draw_arc(CENTER,RADIUS,0,TAU,32,stage.MUTED,1,true)
	for at in [3.,4.,5.,6.,7.]:
		if s.local>=at and s.local<at+.2:stage.draw_arc(CENTER,RADIUS,0,TAU,32,stage.BONUS,3,true)
	stage.draw_string(ThemeDB.fallback_font,Vector2(156,121),"最近普通炮：%s · W：%s"%["—" if s.ordinary_at<0 else "%.0f"%s.ordinary,"—" if s.seismic_at<0 else "落空" if s.seismic==0 else "%.0f"%s.seismic],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
