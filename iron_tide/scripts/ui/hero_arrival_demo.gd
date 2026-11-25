extends VBoxContainer
## Isolated illustration: seeking reconstructs the scene, never production or save state.
const Playback=preload("res://scripts/ui/demo_playback.gd")
var hero_id:="ORCA"
var elapsed:=0.0
var playing:=true
var playback_speed:=1.0
var stage:=Control.new()
var status:=Label.new()
var playback:Control

func _ready() -> void:
	add_child(UiKit.make_label("每局额外出场 · 流程演示",18,UiKit.COL_ACCENT_2))
	stage.custom_minimum_size=Vector2(0,172);stage.clip_contents=true
	add_child(stage);stage.draw.connect(_draw_stage)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	playback=Playback.new();add_child(playback)
	playback.bind(self,&"elapsed",duration,refresh_preview);playback.add_transport()
	var note:=UiKit.make_label("前提：累计主动生产飞机／磁暴坦克各5次解锁对应英雄，从下一局生效。此处演示解锁后的出场，生产耗时已压缩；拖动不改变实际进度。扩展对局适用，远征采用招募规则。",12,UiKit.COL_DIM)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree());refresh_preview()

func show_hero(id:String) -> void:
	hero_id=id;elapsed=0;playing=true
	refresh_preview()

func duration() -> float:
	return 23.0 if hero_id=="ORCA" else 28.0

static func sample(id:String,time:float) -> Dictionary:
	var plane:=id=="ORCA"
	var reset:=18.0 if plane else 19.0
	var fresh:=time>=reset
	var clock:=time-reset if fresh else time
	var times:Array=[2.0] if fresh and plane else [2.0,4.0,6.0] if fresh else [2.0,9.0,13.0,15.0] if plane else [2.0,4.0,8.0,16.0]
	var count:=0
	var last:=-1.0
	for at:float in times:
		if clock>=at:count+=1;last=at
	var threshold:=1 if plane else 3
	var gifted:=count>=threshold
	var dead:=not fresh and time>=(11.0 if plane else 14.0)
	var phase:="新对局：独立计数，可以再次获得英雄" if fresh else "等待普通产品完成"
	if not fresh:
		if plane:
			if time>=2:phase="第一架普通飞机完成，额外赠送游隼"
			if time>=4:phase="重复完成通知：普通产品和英雄都不增加"
			if time>=6:phase="保存：普通产品1，英雄1，赠送已用"
			if time>=7:phase="读档后仍是原来的英雄，本局只赠送一次"
			if time>=9:phase="第二架普通飞机完成，不再赠送"
			if time>=11:phase="游隼阵亡：本局赠送次数不返还"
			if time>=13:phase="继续生产：只有普通飞机，机场位正常保留"
		else:
			if time>=2:phase="第一辆普通磁能坦克完成，尚未达到三辆"
			if time>=4:phase="第二辆完成：累计2辆，雷铸尚未出场"
			if time>=5:phase="已生产 2 辆，读档后接着计数"
			if time>=8:phase="第三辆普通车保留，同时额外赠送雷铸"
			if time>=10:phase="重复第三辆完成通知：不重复计数或赠送"
			if time>=11:phase="保存：普通车3，雷铸1，赠送已用"
			if time>=12:phase="读档后，原来的雷铸仍在部队中"
			if time>=14:phase="雷铸阵亡：本局赠送次数不返还"
			if time>=16:phase="第四辆完成：只保留普通产品，不重送英雄"
	return {"count":count,"gifted":gifted,"alive":gifted and not dead,"dead":gifted and dead,"fresh":fresh,"phase":phase,
		"move":clampf((clock-last)/1.2,0,1) if last>=0 else 1.0,"slots":count if plane else 0}

func refresh_preview() -> void:
	status.text=sample(hero_id,elapsed).phase
	if stage.get_meta("hero_material","")!=hero_id:
		stage.set_meta("hero_material",hero_id)
		stage.material=preload("res://scripts/units/peregrine_art.gd").preview_material() if hero_id=="ORCA" else null
		stage.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if hero_id=="ORCA" else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	stage.queue_redraw()

func _process(dt:float) -> void:
	if not playing:return
	elapsed=fposmod(elapsed+dt*playback_speed,duration());refresh_preview()

func _text(at:Vector2,text:String,color:=Color.WHITE) -> void:
	stage.draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)

func _sprite(id:String,at:Vector2) -> void:
	var art:=RA2Art.art(id)
	if art.is_empty():return
	var frame:=maxi(0,RA2Art.seq_frame(RA2Art.seq(id),"Guard",6,0))
	var rect:=RA2Art.draw_rect(art,0,[frame],0,.8);rect.position+=at
	RA2Art.draw_sprite(stage,art,rect,RA2Art.src_rect(art,frame),Color.WHITE)

func _draw_stage() -> void:
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#142331"))
	var width:=minf(540,stage.size.x)
	stage.draw_set_transform(Vector2((stage.size.x-width)*.5,0))
	var s:=sample(hero_id,elapsed)
	_text(Vector2(12,22),"新对局" if s.fresh else "同一对局",UiKit.COL_GOLD)
	_text(Vector2(120,22),"普通产品 %d　赠送记录 %s"%[s.count,"已使用" if s.gifted else "未使用"])
	stage.draw_rect(Rect2(12,42,62,64),Color("#344958"))
	_text(Vector2(16,78),"机场" if hero_id=="ORCA" else "战车厂")
	for i in s.count:
		var to:=Vector2(120+i*64,101)
		var at:Vector2=Vector2(75,85).lerp(to,s.move) if i==s.count-1 else to
		_sprite(hero_id,at)
	_text(Vector2(100,128),"普通产品照常保留",UiKit.COL_OK)
	var point:=Vector2(width-77,96)
	if s.alive:
		stage.draw_arc(point+Vector2(0,-12),29,0,TAU,32,UiKit.COL_GOLD,2)
		if hero_id=="TTNK":preload("res://scripts/units/leizhu_art.gd").draw_preview(stage,point,53,0,Color.WHITE)
		elif hero_id=="ORCA":preload("res://scripts/units/peregrine_art.gd").draw_preview(stage,point,.8,28,Color.WHITE)
		else:_sprite(hero_id,point)
	elif s.dead:
		stage.draw_line(point+Vector2(-14,-25),point+Vector2(14,3),Color.ORANGE,3)
		stage.draw_line(point+Vector2(14,-25),point+Vector2(-14,3),Color.ORANGE,3)
	_text(Vector2(width-112,128),("游隼" if hero_id=="ORCA" else "雷铸")+(" · 阵亡" if s.dead else " · 额外" if s.alive else " · 待出场"),UiKit.COL_GOLD)
	_text(Vector2(12,157),"普通机场位 %d/4 · 游隼占用0"%s.slots if hero_id=="ORCA" else "第3辆触发 · 阵亡或读档不重置本局赠送记录",Color.CYAN)
