extends "res://scripts/ui/hero_talent_demo.gd"
## Illustrates checkpoint continuity. Battle-snapshot regressions validate gameplay separately.
const CASES=[
	["炸药倒计时","TANY","NAPOWR","爆炸倒计时",2.0,"同一枚炸药只爆炸一次"],
	["米格飞行","BORIS","BPLN","本轮剩余飞机",6.0,"继续原编队，不重新召唤六架"],
	["弹药将满","ORCA","ORCA","补弹百分比",.95,"接着余下5%补弹，只触发一次满仓"],
	["电庭跳伤","TTNK","HTNK","跳伤已累计秒数",.3,"只补足0.2秒，原目标收到下一跳"],
	["阵地三发","E1","HTNK","剩余强化发数",2.0,"保存前已用一发，读档不是重新三发"],
	["机器人跳宿","DRON","HTNK","当前扑跃进度",.5,"继续扑向原目标，关闭自动不撤回本跳"],
	["Q自动关闭","DRON","HTNK","自动跳宿",0.0,"恢复后仍关闭，不重开或重置次数"],
	["鱼雷分叉","SUB","DEST","已产生副攻击",1.0,"原副鱼雷继续飞行，不再产生下一代"],
	["导弹破盾","DRED","DMISL","残余护盾",6.0,"已经损耗的盾不补满，继续正常受伤"],
	["基地供电","TTNK","NACNST","英雄供电",100.0,"原供电只算一次，不累加成200"],
	["迫降179秒","ORCA","ENGINEER","自动返修剩余秒数",1.0,"保持十倍机体，最后一秒后恢复正常生命一次"]]
var scenario:=OptionButton.new()
var details:=Label.new()

func _ready() -> void:
	add_child(UiKit.make_label("保存恢复 · 连续性示意",18,UiKit.COL_ACCENT_2))
	for row in CASES:scenario.add_item(row[0])
	add_child(scenario);scenario.item_selected.connect(func(_i):elapsed=0;playing=true;refresh_preview())
	stage.custom_minimum_size.y=175;stage.clip_contents=true;add_child(stage);stage.draw.connect(_draw_demo)
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(details)
	playback=preload("res://scripts/ui/demo_playback.gd").new();add_child(playback)
	playback.bind(self,&"elapsed",duration,refresh_preview);playback.add_transport()
	var note:=UiKit.make_label("左侧保留保存时刻，右侧从同一状态继续。数值是对应规则的示例；此窗口不读写真实对局存档。",12,UiKit.COL_DIM)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree());refresh_preview()

func duration() -> float:return 6.0

func _process(dt:float) -> void:
	if playing:elapsed=fposmod(elapsed+dt*playback_speed,duration());refresh_preview()

static func state(index:int,t:float) -> Dictionary:
	var after:=maxf(0,t-2)
	var value:float=CASES[index][4]
	var completed:=0
	match index:
		0:value=maxf(0,2-after);completed=int(after>=2)
		1:value=6 if after<1 else 2 if after<2 else 0
		2:value=minf(1,.95+after/8);completed=int(value>=1)
		3:value=fmod(.3+after,.5);completed=floori((.3+after)/.5)
		4:value=maxf(0,2-floori(after));completed=mini(2,floori(after))
		5:value=minf(1,.5+after);completed=int(value>=1)
		6:value=0
		7:value=1;completed=int(after>=2)
		8:value=maxf(0,6-floori(after)*2)
		9:value=100
		10:value=maxf(0,1-after);completed=int(after>=1)
	return {"value":value,"completed":completed,"after":after,"loaded":t>=2}

func refresh_preview() -> void:
	var row:Array=CASES[scenario.selected]
	var s:=state(scenario.selected,elapsed)
	hero_id=str(row[1])
	var value_text:="关闭" if scenario.selected==6 else "%.0f%%"%(s.value*100) if scenario.selected in [2,5] else String.num(s.value,2)
	details.text=("保存时刻：" if elapsed<1 else "读取同一状态：" if elapsed<2 else "恢复后继续：")+str(row[5])+"\n"+str(row[3])+"："+value_text
	if scenario.selected in [0,2,5,10]:details.text+=" · 完成次数%d"%s.completed
	if scenario.selected==3:details.text+=" · 恢复后的跳伤次数%d"%s.completed
	if scenario.selected==7:details.text+=" · 副攻击结束%d次，新增分叉0"%s.completed
	stage.queue_redraw()

func _draw_demo() -> void:
	var index:=scenario.selected;var row:Array=CASES[index];var s:=state(index,elapsed)
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#142331"))
	var width:=minf(540,stage.size.x);stage.draw_set_transform(Vector2((stage.size.x-width)*.5,0))
	_text(Vector2(12,22),"保存帧 · 保持不变",UiKit.COL_GOLD)
	_text(Vector2(width*.53,22),"读取相同状态" if elapsed<2 else "从原位置和剩余时间继续",Color.CYAN)
	stage.draw_line(Vector2(width*.5,35),Vector2(width*.5,165),UiKit.COL_DIM,1)
	for half in 2:
		var base:=Vector2(width*(.16+.5*half),105)
		var end:=base+Vector2(95,0)
		var after:float=s.after if half==1 else 0
		var current:=state(index,after+2)
		_sprite(str(row[1]),base,.65)
		if index!=10:_sprite(str(row[2]),end,.42)
		if index==0 and current.completed>0:
			stage.draw_arc(end,25,0,TAU,32,Color.ORANGE,3)
		elif index in [1,5,7,8]:
			var at:=base.lerp(end,clampf(.35+after*.2,0,1))-Vector2(0,25)
			if index==7 and current.completed==1:at=end
			stage.draw_circle(at,4,Color.CYAN)
		elif index==3:
			stage.draw_arc(end,27,0,TAU,32,Color.CYAN,2)
			if current.value<.1:stage.draw_line(base,end,Color.CYAN,3)
		elif index==9:stage.draw_line(base,end,Color.GREEN,2)
		elif index==10:
			stage.draw_arc(base,28,0,TAU,32,Color.CYAN if current.completed else Color.ORANGE,2)
			_text(base+Vector2(-34,31),"生命100%" if current.completed else "机体1000%",UiKit.COL_OK)
		var display:="关闭" if index==6 else "%.2f"%current.value
		_text(Vector2(width*(.03+.5*half),155),str(row[3])+" "+display,UiKit.COL_OK)
