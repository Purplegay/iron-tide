extends RefCounted
const LENGTH:=30.0
const HOST:=Vector2(280,73)
const CELL:=35.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/6)
	var local:=fposmod(t,6)
	var values:Dictionary=GameData.get_skill("ap_lure_pounce").values
	var entered:=part==0 and local>=1.65
	var guard_start:=0.0 if part==3 else 1.0
	var guard:=maxf(0,guard_start+float(values.guard[rank])-local) if part in [0,3,4] and local>=guard_start and not entered else 0.0
	var approach:=maxf(0,3-local) if not entered else 0.0
	var burrow:=maxf(0,3.65-local) if entered else 0.0
	var x:=60.0
	match part:
		0:x=60+150*local if local<1 else lerpf(210,280,clampf((local-1)/.65,0,1))
		1:x+=minf(local,1.6)*45
		2:x+=minf(local,.8)*90
		3:x=230
		4:x+=minf(local,1)*150
	var moving:bool=local<([1.65,1.6,.8,0.,1.][part])
	var title:String=["入侵立即取消无敌 · 保留2秒寄生加速","未进入两格 · 不触发无敌","主目标失效 · 无敌资格作废","两格内施放 · 立即无敌且仅一次","接近受阻 · 无敌自然到期不重触发"][part]
	var text:="加速 %.1fs · 无敌 %.2fs"%[approach,guard]
	if entered:text="已入侵 · 无敌0 · 寄生加速 %.1fs"%burrow
	elif part==2 and local>=.8:text="目标失效 · 加速仍计时 · 不触发无敌"
	return {"time":t,"local":local,"part":part,"active":guard>0,"value":float(values.speed[rank])*100,"charges":0,
		"guard":guard,"approach":approach,"burrow":burrow,"reload":float(values.reload[rank])*100,
		"entered":entered,"target_valid":part!=2 or local<.8,"moving":moving,"point":Vector2(x,73),
		"cd":maxf(0,32-local),"title":title,"text":text}

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"独立接近示例 · 移速+%.0f%% · W冷却%.1fs"%[s.value,s.cd],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.MUTED)
	stage.draw_arc(HOST,2*CELL,PI*.65,PI*1.35,32,stage.MUTED,1,true)
	stage.draw_string(ThemeDB.fallback_font,Vector2(198,49),"2格",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(HOST,stage.FOE if s.target_valid else stage.MUTED,PI,false)
	if not s.entered:stage.actor(s.point,stage.ALLY)
	if s.active:stage.ring(s.point,18,stage.BONUS)
	if not s.target_valid:
		stage.draw_line(HOST-Vector2(9,9),HOST+Vector2(9,9),Color.RED,2)
		stage.draw_line(HOST+Vector2(-9,9),HOST+Vector2(9,-9),Color.RED,2)
	if s.part==4:stage.draw_line(Vector2(235,49),Vector2(235,97),stage.MUTED,5)
	if s.entered:
		stage.draw_circle(HOST+Vector2(0,-20),5,stage.ALLY)
		stage.draw_string(ThemeDB.fallback_font,Vector2(150,114),"寄生间隔 -%.0f%%"%(s.reload if s.burrow>0 else 0),HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	else:
		stage.draw_string(ThemeDB.fallback_font,Vector2(150,114),"剩余无敌 %.2fs"%s.guard,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
