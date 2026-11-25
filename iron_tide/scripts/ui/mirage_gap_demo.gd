extends RefCounted
const LENGTH:=28.0

static func sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,LENGTH)
	var part:=0 if t<16 else 1+int((t-16)/6)
	var local:=t if part==0 else fposmod(t-16,6)
	var active:=part==0 and ((t>=1 and t<3) or (t>=13 and t<15))
	var disguised:=part==1 or (part==0 and (t<1 or (t>=5 and t<6) or (t>=12 and t<13)))
	var value:float=GameData.get_skill("ps_mirage_gap").values.defense[rank]*100
	var left:=maxf(0,(15 if t>=13 else 3)-t) if active else 0.
	var cooldown:=maxf(0,(25 if t>=13 else 13)-t) if part==0 and t>=1 else 0.
	var shots:Array[float]=[]
	shots.assign([1.,2.,6.,13.] if part==0 else [1.])
	var title:String=["原生伪装首次开火 · 两秒远程减伤","独立示例 · 镜像开火不授予减伤","独立示例 · 未伪装的开火不触发"][part]
	var text:="选取伪装／开火节点 · 不改原生伪装恢复时间"
	if part==0 and t>=1:text="远程减伤 %.0f%% · 剩余%.1fs · 间隔%.1fs"%[value,left,cooldown] if active else "减伤已结束 · 触发间隔还剩%.1fs"%cooldown
	if part==0 and t>=2 and t<3:text="再次开火不续时 · 减伤还剩%.1fs"%left
	if part==0 and t>=6 and t<12:text="再次伪装开火 · 仍在间隔内，不触发"
	if part>0:text="镜像开火：自身和本体均不获减伤" if part==1 else "本体直接开火：没有原生伪装前置"
	return {"time":t,"local":local,"part":part,"active":active,"value":value,"charges":0,"text":text,"title":title,"disguised":disguised,
		"left":left,"cooldown":cooldown,"shots":shots,"damage":100*(1-value*.01) if active else 100.,"other_damage":100.}

static func sync_actor(actor,s:Dictionary) -> void:
	actor.special.reveal=0.0 if s.disguised else 2.0
	AlliedAbilities.update_mirage_tree(actor)

static func beam(stage,from:Vector2,to:Vector2,time:float,start:float,color:Color) -> void:
	if time>=start and time<start+.16:stage.draw_line(from,to,color,2,true)

static func draw(stage,s:Dictionary) -> void:
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,14),s.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
	stage.draw_string(ThemeDB.fallback_font,Vector2(8,30),"普通远程100伤害示例 · 不影响原生伪装余温",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	stage.actor(stage.A,stage.ALLY);stage.actor(stage.B,stage.FOE,PI,false)
	var origin:Vector2=stage.A
	if s.part==1:
		origin+=Vector2(70,10)
		stage.actor(origin,stage.ALLY,0,false)
		stage.draw_string(ThemeDB.fallback_font,origin+Vector2(-20,27),"临时镜像",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
	for start:float in s.shots:beam(stage,origin,stage.B,s.local,start,stage.ALLY)
	var incoming:Array[float]=[]
	incoming.assign([1.5,2.5,3.5,13.5] if s.part==0 else [1.5])
	for start:float in incoming:beam(stage,stage.B,origin,s.local,start,stage.FOE)
	if s.active:stage.ring(stage.A,27,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(174,107),"普通远程 100 → %.0f"%s.damage,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
	stage.draw_string(ThemeDB.fallback_font,Vector2(174,122),"技能／碾压 100 → 100",HORIZONTAL_ALIGNMENT_LEFT,-1,10,stage.MUTED)
