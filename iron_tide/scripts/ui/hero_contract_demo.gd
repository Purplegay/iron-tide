extends VBoxContainer
## Read-only contract illustration; no calls to settle, equip or persistent saves.
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
const LENGTH=31.0
const LABELS={
	"TANY":["普通双枪击杀敌步兵","原生C4摧毁敌建筑","本局摧毁防御建筑",1],
	"BORIS":["普通步枪击杀敌步兵","本人米格摧毁敌建筑","本局空袭实际投弹轮数",2],
	"ORCA":["主导弹击毁敌作战地面载具","普通对地命中后自动补满","本局命中不同敌作战目标",3],
	"TTNK":["普通主电击击毁敌作战地面载具","敌方造成实际生命损失","本局亲自击毁敌作战地面载具",4]}
var hero_id:="TANY"
var elapsed:=0.0
var playing:=true
var playback_speed:=1.0
var status:=Label.new()
var reward:=Label.new()
var condition:=Label.new()
var rows:Array=[]
var bars:Array=[]
var stage:=Control.new()
var playback:Control

func _ready() -> void:
	add_child(UiKit.make_label("契约任务 · 两局结算演示",18,UiKit.COL_ACCENT_2))
	for label in [status,condition,reward]:label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	for i in 2:
		var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		rows.append(label);add_child(label)
		var bar:=ProgressBar.new();bar.custom_minimum_size.y=12;bar.show_percentage=false
		bars.append(bar);add_child(bar)
	add_child(condition)
	stage.custom_minimum_size.y=50;stage.clip_contents=true;add_child(stage)
	stage.draw.connect(_draw_transfer)
	add_child(reward)
	playback=preload("res://scripts/ui/demo_playback.gd").new();add_child(playback)
	playback.bind(self,&"elapsed",duration,refresh_preview);playback.add_transport()
	var note:=UiKit.make_label("演示从获得契约后开始，两场都未装备奖励卡。绿条显示战后累计进度。观看演示不会改变你的契约进度或卡牌。",12,UiKit.COL_DIM)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	visibility_changed.connect(func():set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree());refresh_preview()

func show_hero(id:String) -> void:
	hero_id=id;elapsed=0;playing=true;refresh_preview()

func duration() -> float:
	return LENGTH

static func sample(id:String,time:float) -> Dictionary:
	var goals:Array=Contracts.GOALS[id]
	var step:=100.0 if id=="TTNK" else 1.0
	var second_match:=time>=15
	var first:=0.0
	var second:=0.0
	if not second_match:
		first=float(int(time>=2)+int(time>=4))
		second=step*(int(time>=5)+int(time>=7))
	var requirement:int=LABELS[id][3]
	var criterion:=0
	if second_match:
		criterion=mini(requirement,maxi(0,int(floor((time-16)/2))+1))
		if id=="TTNK":first=criterion
	var settled:=time>=9
	var complete:=time>=24
	var phase:="第1局进行中：本局进度尚未计入累计"
	if time>=9:phase="第1局失败结算：累计任务入账，胜利任务未完成"
	if time>=10:phase="保存结算结果：保留累计，不发放奖励卡"
	if time>=11:phase="读档回到同一局：累计保持不变"
	if time>=12:phase="重复结算原对局：不重复累加，也不能改成胜利"
	if second_match:phase="第2局：普通难度，英雄存活，补足本局胜利条件"
	if time>=24:phase="第2局获胜结算：三项完成，解锁两张专属卡"
	if time>=26:phase="保存已完成契约与卡牌；读档保留奖励"
	if time>=28:phase="重复结算第2局：不再累加，不重复发卡"
	return {"first":first,"second":second,"saved_first":float(goals[0]) if settled else float(goals[0])-2,
		"saved_second":float(goals[1]) if settled else float(goals[1])-2*step,"criterion":criterion,
		"required":requirement,"complete":complete,"win":complete,"settled":settled,"second_match":second_match,
		"grants":1 if complete else 0,"phase":phase}

func refresh_preview() -> void:
	if rows.is_empty():return
	var s:=sample(hero_id,elapsed)
	status.text=s.phase
	for i in 2:
		var current:float=s.first if i==0 else s.second
		var saved:float=s.saved_first if i==0 else s.saved_second
		rows[i].text="%s\n本局 +%s　｜　已结算 %s / %s"%[LABELS[hero_id][i],String.num(current),String.num(saved),String.num(Contracts.GOALS[hero_id][i])]
		bars[i].max_value=Contracts.GOALS[hero_id][i];bars[i].value=saved
	condition.text="③ 普通以上获胜并存活：%s\n%s %d / %d%s"%["已完成" if s.win else "未结算完成",LABELS[hero_id][2],s.criterion,s.required," · 条件具备，等待获胜结算" if s.criterion==s.required and not s.win else ""]
	var names:Array=[]
	for id:String in Contracts.cards()[hero_id]:names.append(str(GameData.get_skill(id).name))
	reward.text=("已解锁：" if s.complete else "待解锁：")+" ＋ ".join(names)+"\n奖励发放 %d 次 · 两张卡均未装备"%s.grants
	reward.modulate=UiKit.COL_GOLD if s.complete else UiKit.COL_DIM
	stage.queue_redraw()

func _process(dt:float) -> void:
	if not playing:return
	elapsed=fposmod(elapsed+dt*playback_speed,LENGTH);refresh_preview()

func _draw_transfer() -> void:
	var width:=stage.size.x
	stage.draw_rect(Rect2(Vector2.ZERO,stage.size),Color("#142331"))
	stage.draw_string(ThemeDB.fallback_font,Vector2(12,30),"本局账本",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	stage.draw_string(ThemeDB.fallback_font,Vector2(width-100,30),"已结算累计",HORIZONTAL_ALIGNMENT_LEFT,-1,14,UiKit.COL_OK)
	stage.draw_line(Vector2(100,25),Vector2(width-112,25),UiKit.COL_DIM,1)
	for at:float in [9.0,24.0]:
		if elapsed>=at and elapsed<at+1:
			var progress:=elapsed-at
			stage.draw_circle(Vector2(100+(width-212)*progress,25),6,UiKit.COL_GOLD)
