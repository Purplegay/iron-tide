extends RefCounted
const Weapons=preload("res://scripts/units/soviet_advanced.gd")
const LAUNCH=1.0
const INTERCEPT=2.0
const RATE=4.0
const START=Vector2(112,83)
const HIT=Vector2(260,36)
const DEFENSE=Vector2(355,91)

static func reload_time() -> float:
	return float(GameData.get_unit("V3").rocket.reload)

static func duration() -> float:
	return LAUNCH+reload_time()/RATE+1.5

static func sample(clock:float,rank:int) -> Dictionary:
	var reduction:float=MetaProgress.talent_options("V3").lost_missile.values.reload[clampi(rank,0,3)]
	var total:=reload_time()
	var before:=maxf(0,total-(INTERCEPT-LAUNCH)*RATE)
	var saved:=before*reduction
	var fired:=clock>=LAUNCH
	var intercepted:=clock>=INTERCEPT
	var baseline:=maxf(0,total-maxf(0,clock-LAUNCH)*RATE) if fired else 0.0
	var remaining:=maxf(0,baseline-saved) if intercepted else baseline
	var phase:=clampf((clock-LAUNCH)/(INTERCEPT-LAUNCH),0,1)
	var point:=START.lerp(HIT,phase)+Vector2(0,-sin(phase*PI)*24)
	var label:="准备发射 · 火箭在架"
	if fired:label="火箭已离架 · 敌方防空拦截中"
	if intercepted:label="敌方击毁 · 剩余 %.1f → %.1f 秒（−%d%%）"%[before,before-saved,roundi(reduction*100)]
	if intercepted and remaining<=0:label="天赋补弹完成 · 本轮仅减免一次"
	return {"fired":fired,"intercepted":intercepted,"missile":fired and not intercepted,"point":point,"baseline":baseline,"remaining":remaining,"saved":saved,"before":before,"after":before-saved,"total":total,"label":label}

static func animate(stage) -> void:
	var state:=sample(stage._demo_clock(),stage.rank)
	stage.actor.position=stage.viewport.canvas_transform.affine_inverse()*Vector2(92,92)
	stage.actor.special.missile_racks=[state.remaining]
	Weapons.sync_rack(stage.actor)

static func draw(stage,clock:float) -> void:
	var state:=sample(clock,stage.rank)
	stage.draw_string(ThemeDB.fallback_font,Vector2(10,15),"补弹计时演示 ×4 · 不改变实际战斗速度",HORIZONTAL_ALIGNMENT_LEFT,410,12,Color("#91a7b9"))
	stage.draw_rect(Rect2(DEFENSE-Vector2(17,10),Vector2(34,20)),Color("#b55655"))
	stage.draw_line(DEFENSE,DEFENSE+Vector2(-17,-17),Color("#ffb6a0"),4,true)
	stage.draw_string(ThemeDB.fallback_font,DEFENSE+Vector2(-27,16),"敌方防空",HORIZONTAL_ALIGNMENT_LEFT,100,12,Color("#ffb6a0"))
	if state.missile:
		var point:Vector2=state.point
		stage.draw_dashed_line(START,point,Color("#829ea6"),1,4)
		stage.draw_colored_polygon(PackedVector2Array([point+Vector2(10,-3),point+Vector2(-7,-5),point+Vector2(-5,4)]),Color("#c4e9eb"))
		stage.draw_line(point-Vector2(6,0),point-Vector2(17,0),Color.ORANGE,3,true)
		if clock>1.55:
			var shot:=clampf((clock-1.55)/.45,0,1)
			stage.draw_line(DEFENSE,DEFENSE.lerp(HIT,shot),Color("#ff7770"),2,true)
	if clock>=INTERCEPT and clock<INTERCEPT+.7:
		var phase:float=(clock-INTERCEPT)/.7
		stage.draw_circle(HIT,5+phase*15,Color(1,.65,.2,1-phase))
		for i in 6:
			var direction:=Vector2.from_angle(i*TAU/6)
			stage.draw_line(HIT+direction*(8+phase*18),HIT+direction*(12+phase*25),Color(1,.4,.2,1-phase),2,true)
	bar(stage,119,"无天赋",state.baseline,state.total,Color("#87929b"))
	bar(stage,139,"失联预案",state.remaining,state.total,Color("#65d9f0"))
	stage.draw_string(ThemeDB.fallback_font,Vector2(10,168),state.label,HORIZONTAL_ALIGNMENT_CENTER,410,13,Color.WHITE)

static func bar(stage,y:float,label:String,left:float,total:float,color:Color) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(10,y+5),label,HORIZONTAL_ALIGNMENT_LEFT,80,12,color)
	stage.draw_rect(Rect2(92,y-7,235,10),Color("#303c49"))
	stage.draw_rect(Rect2(92,y-7,235*clampf(left/maxf(.01,total),0,1),10),color)
	stage.draw_string(ThemeDB.fallback_font,Vector2(337,y+4),"%.1f 秒"%left,HORIZONTAL_ALIGNMENT_LEFT,90,12,color)
