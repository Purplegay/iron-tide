extends RefCounted
const LENGTH:=30.0
const SOURCE:=Vector2(45,70)
const FIRST:=Vector2(220,64)
const SECOND:=Vector2(285,95)
const RADIUS:=35.0

static func hits(part:int,limit:int) -> Array[float]:
	var result:Array[float]=[]
	result.assign([1.,4.,5.] if part==1 else [1.,2.,3.,3.3,3.6,3.9] if part==2 else [1.,2.,3.])
	if limit==2:result.assign([1.,4.] if part==1 else [1.,2.,3.3,3.9] if part==2 else [1.,2.])
	return result

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/10)
	var local:=fposmod(t,10)
	var limit:int=GameData.get_skill("ps_burning_payload").values.hits[rank]
	var times:=hits(part,limit)
	var count:=0
	for hit:float in times:
		if local+.000001>=hit:count+=1
	var starts:Array[float]=[]
	for i in times.size():
		if (i+1)%limit==0:starts.append(times[i])
	var index:=-1
	for i in starts.size():
		if local+.000001>=starts[i]:index=i
	var active:=index>=0 and local<starts[index]+3-.000001
	var field:=SECOND if index==1 else FIRST
	var ticks:Array[int]=[0,0]
	var flash:=false
	for i in starts.size():
		for n in range(1,7):
			var pulse:float=starts[i]+n*.5
			if i+1<starts.size() and pulse>=starts[i+1]:continue
			if local+.000001>=pulse:ticks[i]+=1
			if local>=pulse and local<pulse+.12:flash=true
	var coefficient:float=GameData.get_skill("ps_burning_payload").values.damage[rank]*100
	var title:String=["累计%d次普通直击 · 六次半秒燃烧"%limit,"游隼W／溅射不计普通直击","本人只留一区 · 新区替换旧区"][part]
	var text:="累计主直击 %d/%d · 返航补弹不清零"%[count%limit,limit]
	if active:text="燃烧 %.1fs · 每跳%.1f%%攻击 · 计数%d/%d"%[starts[index]+3-local,coefficient*.5,count%limit,limit]
	elif index>=0:text="燃烧到期 · 不反向累计导弹命中数"
	return {"time":t,"local":local,"part":part,"active":active,"charges":count%limit,"limit":limit,"value":coefficient,"title":title,"text":text,
		"hits":times,"hit_count":count,"field":field,"index":index,"ticks":ticks,"flash":flash,
		"left":starts[index]+3-local if active else 0.,"w_flash":part==1 and local>=2 and local<2.2,
		"splash_flash":part==1 and local>=3 and local<3.2}

static func missile(stage,local:float,arrival:float,destination:Vector2,color:Color,offset:float=0.) -> void:
	if local<arrival-.46 or local>=arrival:return
	var progress:=clampf((local-arrival+.46)/.46,0,1)
	var p:Vector2=(SOURCE+Vector2(0,offset)).lerp(destination,progress)
	stage.draw_line(p,p+Vector2(-7,0),color,2,true)

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,29),"直接命中和溅射仍会造成原有伤害",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(SOURCE,stage.ALLY)
	stage.actor(FIRST,stage.FOE,PI,false)
	stage.actor(FIRST+Vector2(20,17),stage.FOE,PI,false)
	if s.part==2:stage.actor(SECOND,stage.FOE,PI,false)
	for i in s.hits.size():
		var point:=SECOND if i>=s.limit else FIRST
		missile(stage,s.local,s.hits[i],point,stage.ALLY)
		if s.local>=s.hits[i] and s.local<s.hits[i]+.12:stage.ring(point,24,stage.MUTED)
	if s.part==1:
		for i in 4:missile(stage,s.local,2.,FIRST,stage.BONUS,(i-1.5)*7)
		missile(stage,s.local,3.,FIRST+Vector2(-26,0),stage.MUTED)
		if s.w_flash:stage.ring(FIRST,27,stage.BONUS)
		if s.splash_flash:stage.ring(FIRST+Vector2(-26,0),30,stage.MUTED)
		stage.draw_string(ThemeDB.fallback_font,Vector2(90,47),"2s：W不计 · 3s：仅溅射不计",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	if s.active:stage.ring(s.field,RADIUS,Color.ORANGE)
	if s.flash:stage.ring(s.field,RADIUS-5,stage.BONUS)
	for i in s.limit:stage.draw_circle(Vector2(42+i*10,107),3,stage.BONUS if i<s.charges else stage.MUTED)
	stage.draw_string(ThemeDB.fallback_font,Vector2(100,118),"原区%d跳 · 新区%d跳 · 每跳%.1f%%"%[s.ticks[0],s.ticks[1],s.value*.5],HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.BONUS)
