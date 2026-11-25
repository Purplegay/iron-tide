extends RefCounted
const SEAT_LENGTH:=24.0

static func module_sample(rank:int,time:float) -> Dictionary:
	var card:Dictionary=GameData.get_skill("ps_module_shell")
	var t:=fposmod(time,float(card.trigger_interval)+4)
	var second:=1.0+float(card.trigger_interval)
	var at:=second if t>=second else 1.0
	var left:=maxf(0,at+float(card.duration)-t) if t>=1 else 0.0
	var cd:=maxf(0,at+float(card.trigger_interval)-t) if t>=1 else 0.0
	var crew:="";var unit:="";var event:="等待乘客上车"
	if t>=second:crew="D";unit="E1";event="间隔已结束 · 再次变型获得新盾"
	elif t>=second-.5:crew="工程师D";unit="ENGINEER";event="变型早了0.5秒 · 不触发、不重置间隔"
	elif t>=13:crew="C";unit="E1";event="护盾到期后仍需等触发间隔" if left==0 else "原护盾与间隔继续倒计时"
	elif t>=12:event="下客不补盾、不重置间隔"
	elif t>=10:crew="工程师C";unit="ENGINEER";event="维修模式 · 间隔内变型不补盾"
	elif t>=6:crew="B";unit="E1";event="同类型换成B · 不补盾、不续时"
	elif t>=1:crew="A";unit="E1";event="类型改变获得护盾" if t<3 else "受击消耗25%盾量 · 生命未损失"
	var maximum:float=1000*float(card.values.shield[rank])
	var hp:=maximum*(.75 if t>=3 and t<second else 1.0) if left>0 else 0.0
	return {"time":t,"active":left>0,"value":float(card.values.shield[rank])*100,"charges":0,"crew":crew,"unit":unit,
		"left":left,"cd":cd,"hp":hp,"maximum":maximum,"triggers":2 if t>=second else 1 if t>=1 else 0,"text":event}

static func seat_sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,SEAT_LENGTH)
	var crew:="A";var unit:="E1";var age:=minf(t,4)
	if t>=22:crew="";unit="";age=0
	elif t>=14:crew="工程师C";unit="ENGINEER";age=minf(t-14,4)
	elif t>=12:crew="";unit="";age=0
	elif t>=6.5:crew="B";age=minf(t-6.5,4)
	var active:=age>=4 and unit=="E1"
	var cut:float=MetaProgress.talent_options("FV").steady_seat.values.reload[rank]
	var text:="同一乘客 %.1f / 4秒 · 移动也计时"%age
	if active:text="乘客留在车内 · 每次新装填 -%d%%"%(cut*100)
	elif unit.is_empty():text="空车 · 稳座计时与收益清空"
	elif unit=="ENGINEER":text="工程师乘坐 %.1f秒 · 不缩短维修间隔"%age
	elif t>=6.5:text="同类型换人 · B重新计时 %.1f / 4秒"%age
	return {"time":t,"active":active,"value":cut*100,"charges":0,"crew":crew,"unit":unit,"age":age,
		"factor":1-cut if active else 1.0,"moving":t<12,"distance":minf(t,12)*2.5,"text":text}

static func sync_actor(actor,s:Dictionary) -> void:
	if actor.has_meta("ifv_demo_crew") and actor.get_meta("ifv_demo_crew")==s.crew:return
	var old:Array=actor.logistics.passengers.duplicate()
	actor.logistics.passengers.clear()
	actor.special.erase("progression_v2")
	for passenger in old:if is_instance_valid(passenger):passenger.free()
	# Fully initialized model-only cargo belongs to this private preview, never a match.
	if not s.unit.is_empty():
		var passenger:=Unit.new()
		passenger.set_meta("stack_preview",true)
		passenger.setup(GameData.get_unit(s.unit),"ally",Vector2.ZERO)
		actor.add_child(passenger)
		passenger.process_mode=Node.PROCESS_MODE_DISABLED
		passenger.embarked_in=actor
		passenger.collision_layer=0;passenger.collision_mask=0;passenger.hide()
		for group in passenger.get_groups():passenger.remove_from_group(group)
		actor.logistics.passengers.append(passenger)
	actor.passive={}
	actor._refresh_weapon_derived()
	AlliedAbilities.refresh_ifv_art(actor)
	actor.special.erase("progression_v2")
	actor.set_meta("ifv_demo_crew",s.crew)

static func label(view,at:Vector2,text:String,color:Color=Color.WHITE) -> void:
	view.draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

static func draw_module(stage,s:Dictionary) -> void:
	var at:=Vector2(70,74)
	stage.actor(at,stage.ALLY)
	if s.active:stage.ring(at,28,Color.CYAN)
	label(stage,Vector2(8,15),"最大生命1000示例 · 护盾上限 %.0f"%s.maximum,stage.BONUS)
	label(stage,Vector2(135,47),"乘客："+("空车" if s.crew.is_empty() else s.crew),stage.ALLY)
	label(stage,Vector2(135,66),"剩余护盾 %.0f · %.1fs"%[s.hp,s.left],Color.CYAN)
	label(stage,Vector2(135,85),"触发间隔 %.1fs · 已触发%d次"%[s.cd,s.triggers],stage.BONUS)
	label(stage,Vector2(135,104),"盾量与时长不因上下客补充",stage.MUTED)
	stage.draw_rect(Rect2(135,112,150,4),stage.MUTED)
	stage.draw_rect(Rect2(135,112,150*s.hp/s.maximum,4),Color.CYAN)
	if s.time>=3 and s.time<3.2:stage.draw_line(Vector2(300,75),at,stage.FOE,2,true)

static func draw_seat(view,origin:Vector2,s:Dictionary) -> void:
	label(view,Vector2(10,18),"按乘客身份计时 · 同类型另一人也重等4秒",Color.GOLD)
	label(view,Vector2(10,35),"当前乘客："+("空车" if s.crew.is_empty() else s.crew),Color.SKY_BLUE)
	label(view,Vector2(215,72),"乘坐 %.1f / 4秒"%s.age,Color.SKY_BLUE)
	label(view,Vector2(215,93),"维修间隔不变" if s.unit=="ENGINEER" else "新装填 × %.2f"%s.factor,Color.GOLD)
	view.draw_rect(Rect2(215,107,140,5),Color.DIM_GRAY)
	view.draw_rect(Rect2(215,107,140*s.age/4,5),Color.SKY_BLUE)
	if s.active:view.draw_arc(origin,28,0,TAU,32,Color.GOLD,2,true)
	if s.unit=="ENGINEER":
		view.draw_line(origin+Vector2(-5,-32),origin+Vector2(5,-32),Color.GREEN,2)
		view.draw_line(origin+Vector2(0,-37),origin+Vector2(0,-27),Color.GREEN,2)
