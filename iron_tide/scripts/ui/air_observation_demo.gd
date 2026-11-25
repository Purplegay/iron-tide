extends RefCounted
const LENGTH:=12.0

static func sample(id:String,rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var observer:=id=="ps_low_observation"
	var airborne:=t<8 or t>=9
	var moving:bool=(t<4 or (t>=6 and t<8)) if observer else t>=3 and t<5
	var age:=0.0
	if airborne:
		if t>=9:age=minf(2,t-9)
		elif observer:age=minf(2,t if t<4 else t-4)
		elif t<3:age=minf(2,t)
		elif t>=5:age=minf(2,t-5)
	var active:=age>=2-.000001 and airborne
	var distance:float=(minf(t,4)+clampf(t-6,0,2))*10 if observer else clampf(t-3,0,2)*24
	var value:float=GameData.get_skill(id).values.sight[rank] if observer else MetaProgress.talent_options("JUMPJET")[id].values.damage[rank]*100
	var shots:Array[float]=[]
	shots.assign([4.] if observer else [0.,.8,1.6,2.,2.8,4.,5.2,6.,6.8,7.2,9.2,10.,10.8,11.2])
	var text:="空中停火 %.1f/2秒 · 移动不打断"%age if observer else "原地攻击校准 %.1f/2秒 · 开火不打断"%age
	if active:text="视野 +%s格 · 移动保留 · 射程不变"%str(value) if observer else "普通直击 +%.0f%% · 开火保留 · 射程不变"%value
	if observer and t>=4 and t<6:text="开火清视野 · 重新停火 %.1f/2秒"%age
	if not observer and moving:text="实际移动：校枪清空 · 无直击增伤"
	if not airborne:text="落地：立即结束效果、清空进度"
	elif t>=9 and not active:text="重新起飞：从零累计 %.1f/2秒"%age
	return {"time":t,"active":active,"value":value,"charges":0,"text":text,"observer":observer,"airborne":airborne,"moving":moving,
		"age":age,"distance":distance,"shots":shots,"sight":value if observer and active else 0.,"damage":value if not observer and active else 0.}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.logistics.air_lift=1.0 if s.airborne else 0.0
	actor.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*40 if s.moving else Vector2.ZERO

static func shot(view,from:Vector2,to:Vector2,time:float,start:float,color:Color) -> void:
	if time<start or time>=start+.25:return
	var p:=from.lerp(to,(time-start)/.25)
	view.draw_line(p,p+Vector2(-9,0),color,2,true)

static func draw_card(stage,s:Dictionary) -> void:
	var at:Vector2=stage.A+Vector2(s.distance,0 if s.airborne else 18)
	stage.actor(at,stage.ALLY);stage.actor(stage.B,stage.FOE,PI,false)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),"低空观察 · 移动不打断，开火／落地清空",HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"灰色原视野 · 青色增加视野 · 不增加射程",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.draw_arc(at,32,0,TAU,40,stage.MUTED,1,true)
	if s.active:stage.draw_arc(at,32+s.value*12,0,TAU,40,stage.ALLY,2,true)
	for start:float in s.shots:shot(stage,stage.A+Vector2(40,0),stage.B,s.time,start,stage.ALLY)
	stage.draw_line(at+Vector2(-12,23),at+Vector2(12,23),stage.MUTED,2)
	stage.draw_string(ThemeDB.fallback_font,Vector2(188,116),"停火进度 %.1f/2s"%s.age,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)

static func draw_talent(preview,origin:Vector2,s:Dictionary) -> void:
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,20),"悬停校枪 · 原地攻击也累计，满2秒增伤",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,39),"持续射击 → 移动清空 → 停下继续射击校准",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
	if s.active:preview.draw_arc(origin,24,0,TAU,28,Color.GOLD,2,true)
	for start:float in s.shots:
		var at:=Vector2(123+clampf(start-3,0,2)*24,104)
		var empowered:bool=sample("hover_sighting",0,start).active
		shot(preview,at,preview.MAIN_POINT,s.time,start,Color.GOLD if empowered else Color.SKY_BLUE)
	preview.draw_string(ThemeDB.fallback_font,Vector2(230,105),"当前直击 +%.0f%%"%s.damage,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.GOLD)
	preview.draw_string(ThemeDB.fallback_font,Vector2(230,123),"静止进度 %.1f/2s"%s.age,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
