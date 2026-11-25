extends RefCounted
const LENGTH:=30.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/10)
	var local:=fposmod(t,10)
	var values:Dictionary=GameData.get_skill("ps_sea_air_crossfire").values
	var interval:float=values.interval[rank]
	var events:Array=[]
	if part==0:
		events=[{"at":.5,"primary":"air","extra":true},{"at":1.5,"primary":"sea","extra":false},{"at":.6+interval,"primary":"sea","extra":true}]
	else:
		var domain:="air" if part==1 else "sea"
		events=[{"at":.5,"primary":domain,"extra":false},{"at":2.,"primary":domain,"extra":true},{"at":2.1+interval,"primary":domain,"extra":true}]
	var cd:=0.0
	var count:=0
	var primary:="sea" if part==2 else "air"
	for event:Dictionary in events:
		if local<event.at:continue
		primary=event.primary
		if event.extra:cd=maxf(0,event.at+interval-local);count+=1
	var missing:=part>0 and local<2
	var title:String=["两方向共用间隔 · 转火不刷新","缺少敌舰 · 普通防空不空耗间隔","缺少敌机 · 普通对海不空耗间隔"][part]
	var text:="普通开火 · 无另一领域合法目标" if missing else "主目标不变 · 追加不递归 · 共用间隔%.1fs"%cd
	return {"time":t,"local":local,"part":part,"active":cd>0,"value":float(values.damage[rank])*100,"charges":count,
		"cd":cd,"interval":interval,"events":events,"primary":primary,"missing":missing,"title":title,"text":text}

static func draw(stage,s:Dictionary) -> void:
	var at:=Vector2(55,76)
	var air:=Vector2(275,49)
	var sea:=Vector2(275,96)
	stage.actor(at,stage.ALLY)
	var no_air:bool=s.missing and s.part==2
	var no_sea:bool=s.missing and s.part==1
	if not no_air:stage.actor(air,stage.FOE,PI,false)
	if not no_sea:stage.actor(sea,stage.FOE,PI,false)
	stage.ring(air if s.primary=="air" else sea,18,Color.WHITE)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"青色主攻击／金色补射 · 补射%.0f%%"%s.value,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,air+Vector2(20,4),"暂无敌机" if no_air else "空",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED if no_air else stage.FOE)
	stage.draw_string(ThemeDB.fallback_font,sea+Vector2(20,4),"暂无敌舰" if no_sea else "海",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED if no_sea else stage.FOE)
	for event:Dictionary in s.events:
		for secondary in ([false,true] if event.extra else [false]):
			var domain:String=event.primary
			if secondary:domain="sea" if domain=="air" else "air"
			if domain=="air":
				if s.local>=event.at and s.local<event.at+.15:stage.draw_line(at+Vector2(0,-5 if secondary else 0),air,stage.BONUS if secondary else stage.ALLY,2,true)
			else:stage.shot(at+Vector2(0,5 if secondary else 0),sea,s.part*10+event.at,secondary)
	stage.draw_string(ThemeDB.fallback_font,Vector2(110,114),"补射%d次 · 共用间隔 %.1fs"%[s.charges,s.cd],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
