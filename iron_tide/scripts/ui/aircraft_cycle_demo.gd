extends RefCounted
## Four independent examples. Waiting is explicitly skipped, not a reload/CD simulation.
const LENGTH:=32.0
const FX=preload("res://scripts/units/peregrine_visual.gd")

static func sample(id:String,rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=int(t/8)
	var local:=fposmod(t,8)
	var capacity:=4 if part>0 else int(GameData.ra2_source_units.get("ORCA",{}).get("extra",{}).get("Ammo",1))
	var first_card:=id=="full_sortie"
	var amount:float=(MetaProgress.talent_options("ORCA")[id].values.damage[rank] if first_card else GameData.get_skill(id).values.damage[rank])*100
	var events:Array=[]
	if part==0:
		for i in capacity:events.append({"at":1.0+i*.6,"cost":1,"w":false})
	elif part==1:
		for i in 4:events.append({"at":1.0+i*.8,"cost":1,"w":false})
	elif part==2:
		events=[{"at":1.0,"cost":2,"w":true},{"at":2.0,"cost":1,"w":false},{"at":3.0,"cost":1,"w":false}]
	else:
		events=[{"at":1.0,"cost":1,"w":false},{"at":2.0,"cost":1,"w":false},{"at":3.0,"cost":2,"w":true}]
	var ammo:=capacity
	var first:=true
	var last:=true
	var active:=false
	var shots:Array=[]
	for event:Dictionary in events:
		var qualifies:bool=not event.w and (first if first_card else last and ammo==event.cost)
		shots.append({"at":event.at,"w":event.w,"boost":qualifies})
		if local>=event.at:
			ammo-=int(event.cost);first=false
			if ammo==0:last=false
			if qualifies and local>=event.at+.46 and local<event.at+.75:active=true
		else:break
	# At six seconds the example cuts forward to a completed refill.
	if local>=6:ammo=capacity;first=true;last=true
	if local>=6.8:
		var qualifies:bool=first_card or capacity==1
		shots.append({"at":6.8,"w":false,"boost":qualifies})
		ammo-=1;first=false
		if ammo==0:last=false
		active=qualifies and local>=7.26 and local<7.55
	var label:String=["普通入侵者 · 满弹出航","游隼 Lv.0 · 普通射击","游隼 Lv.0 · W先发","游隼 Lv.0 · W打空"][part]
	var text:=""
	if local<1:text="满弹准备 · 首发／末发各一次"
	elif local>=6.8:text="补满后普通首发 · +%d%%"%amount if first_card or capacity==1 else "新周期普通首发 · 末弹资格保留"
	elif local>=6:text="已完整补满 · 首末资格重置"
	elif part==2 and local<2:text="W耗2弹 · 消耗首发资格，不吃首末加成"
	elif part==3 and local>=3:text="W耗尽末2弹 · 消耗末发资格，不加成"
	elif ammo==0:text="资格已用 · 等待空中自动补满" if part>0 else "资格已用 · 返航机场完整补弹"
	else:text="普通发射 · %s资格%s"%["首发" if first_card else "末发","保留" if (first if first_card else last) else "已用"]
	if active:text="普通%s弹 +%d%% · 已消费本次资格"%["首发" if first_card else "末发",amount]
	if part==0 and local>=1 and local<2:text="原生1弹同时是首末弹 · 同装时加成相加"
	return {"time":t,"local":local,"part":part,"hero":part>0,"ammo":ammo,"capacity":capacity,"first":first,"last":last,"active":active,"value":amount,"charges":ammo,"shots":shots,"label":label,"text":text}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.special.aircraft_cycle_preview=true
	if s.hero:
		if actor.peregrine_fx==null:FX.install_preview(actor)
		actor.peregrine_fx.clock=s.time
	else:
		var was_hero:bool=actor.hero_art!=null
		actor.special.erase("academy_hero");actor.special.erase("peregrine");actor.peregrine_fx=null
		if was_hero:actor.refresh_house_color()
	actor.logistics.ammo=s.ammo;actor.logistics.ammo_max=s.capacity
	actor.logistics.air_lift=1.0

static func draw(canvas,origin:Vector2,target:Vector2,s:Dictionary) -> void:
	for shot:Dictionary in s.shots:
		for index in (4 if shot.w else 1):
			var travel:float=(s.local-shot.at-index*.2)/.46
			if travel<0 or travel>1.45:continue
			var color:=Color.GOLD if shot.boost else Color.SKY_BLUE
			var offset:=Vector2(0,(index-1.5)*5) if shot.w else Vector2.ZERO
			if travel<=1:canvas.draw_line((origin+offset).lerp(target,maxf(0,travel-.2)),(origin+offset).lerp(target,travel),color,2,true)
			else:canvas.draw_arc(target,6+(travel-1)*24,0,TAU,24,color,1.5,true)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(10,18),s.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(10,35),"步骤示意 · 省略补弹等待 · 各片段独立",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.GRAY)
	canvas.draw_string(ThemeDB.fallback_font,origin+Vector2(-30,28),"弹药 %d/%d"%[s.ammo,s.capacity],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.SKY_BLUE)
	canvas.draw_string(ThemeDB.fallback_font,origin+Vector2(-45,43),"首发%s / 末发%s"%["就绪" if s.first else "已用","就绪" if s.last else "已用"],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
	if s.active:canvas.draw_arc(target,27,0,TAU,28,Color.GOLD,2,true)
