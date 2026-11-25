extends PanelContainer
signal demo_requested(card:String,unit_id:String)
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
const Reward=preload("res://scripts/ui/hero_contract_reward.gd")
var hero_id:="E1"
const TASKS={"FV":["用武装炮塔打伤敌人、用工程师炮塔修复友车，各一次","同一炮塔模式连续三次有效攻击或维修，累计三组","普通以上获胜：两种不同武装乘员模式各打伤一个敌人"],"HARV":["带至少四分之一原仓矿，用普攻打伤敌人十二次","三秒内用普攻先后打伤两个不同敌人，累计三组","普通以上获胜：带货打伤两辆不同敌车后手动交回四分之一原仓，老秤存活"],"TTNK":["雷铸普通主电击亲自击毁25辆敌战斗地面载具","在敌方攻击下累计损失 6000 点生命，护盾吸收的伤害不计入","普通以上单局获胜：亲自击毁至少4辆敌战斗地面载具并最终存活"],"ORCA":["游隼普通导弹或追猎主弹亲自击毁20辆敌作战地面载具","用普通对地导弹命中敌人后，自动补满弹药 12 次。出场时的满弹不计入","普通以上获胜：本局命中至少3个不同敌作战目标且最终存活"],"E1":["亲自击杀敌方步兵","初始护卫在英雄存活时击杀作战单位","普通以上获胜：英雄与至少两名初始护卫存活，英雄造成过实际伤害"],"MTNK":["亲自击毁敌方作战地面载具","技能实际回血累计（按每次回复时生命上限折算）","普通以上获胜：北辰存活，亲自击毁至少五辆作战载具"],"HTNK":["亲自击毁敌方作战地面载具","累计承受敌方实际生命伤害","普通以上获胜：铁脊存活，亲自摧毁至少两座防御建筑"],"TANY":["英雄谭雅使用普通双枪击杀真实敌步兵","谭雅亲自用 C4 摧毁敌方建筑","普通以上单局获胜：谭雅亲自摧毁至少一座防御建筑并存活"],"BORIS":["英雄鲍里斯用普通步枪击杀60名真实敌步兵","用鲍里斯呼叫的米格战机累计摧毁 10 座敌方建筑","普通以上单局获胜：鲍里斯至少有两轮空袭成功投弹，并存活到战斗结束"]}

func refresh(id:String) -> void:
	hero_id=id
	for child in get_children():remove_child(child);child.queue_free()
	visible=Contracts.cards().has(id)
	if not visible:return
	add_theme_stylebox_override("panel",UiKit.panel_style(Color("#251e1a"),Color("#ba8739"),6,2,12))
	var rows:=VBoxContainer.new();add_child(rows)
	var contract:=Contracts.Pool.for_hero(id)
	var title:=HBoxContainer.new()
	rows.add_child(title)
	var icon:=Reward.badge(str(contract.id),48)
	icon.name="ContractIcon"
	title.add_child(icon)
	var heading:=UiKit.make_label("专属技能解锁 · "+str(contract.name),20,Color("#ffe397"))
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	var explanation:=UiKit.make_label("完成以下三项任务，解锁英雄专属 W 和被动卡；英雄本体按上方条件出场，无需先完成契约。",14,UiKit.COL_TEXT)
	explanation.name="ContractPurpose"
	explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(explanation)
	var acquisition:=UiKit.make_label(Contracts.Pool.description(MetaProgress,str(contract.id)),14,Color.GOLD)
	acquisition.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(acquisition)
	var quest:Dictionary=MetaProgress.academy.get("hero_contracts",{}).get(id,{})
	if quest.is_empty():
		var buy:=UiKit.make_button("开启契约 · %d 兑换碎片"%Contracts.Pool.cost())
		buy.disabled=int(MetaProgress.academy.get("card_shards",0))<Contracts.Pool.cost()
		buy.pressed.connect(_buy);rows.add_child(buy)
	else:rows.add_child(UiKit.make_label("已完成 · 两张专属卡已解锁" if quest.get("complete",false) else "契约任务进行中",15,Color.GOLD))
	rows.add_child(UiKit.make_label("任务进度 · 需完成全部3项",16,UiKit.COL_ACCENT_2))
	for i in 3:
		var text:String=TASKS[id][i]
		var done:bool=float(quest.get("first" if i==0 else "second",0))>=float(Contracts.GOALS[id][i]) if i<2 else bool(quest.get("win",false))
		if i<2:text+="　%s / %s%s"%[String.num(float(quest.get("first" if i==0 else "second",0)),2),str(Contracts.GOALS[id][i]),"%" if id=="MTNK" and i==1 else ""]
		else:text+="　1 / 1" if done else "　0 / 1"
		text="%s %d. %s"%["✓" if done else "○",i+1,text]
		var task:=UiKit.make_label(text,15,UiKit.COL_OK if done else UiKit.COL_TEXT)
		task.name="ContractTask_"+str(i)
		task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(task)
	rows.add_child(UiKit.make_label("获得契约后的新对局累计，结算计入；自定义测试和临时单位不计。",12,UiKit.COL_DIM))
	rows.add_child(UiKit.make_label("完成奖励 · 两张英雄专属卡"+({"FV":"及皮肤「雨幕放映师」","HARV":"及皮肤「第九地磅」"}.get(id,"") as String),16,Color.GOLD))
	for card_id in Contracts.cards()[id]:
		var reward:=Reward.new()
		rows.add_child(reward)
		reward.demo_requested.connect(demo_requested.emit)
		reward.refresh(str(card_id),id)

	_add_demos(rows,id)

func _add_demos(rows:VBoxContainer,id:String) -> void:
	if id in ["ORCA","BORIS","TTNK"]:
		var combo_toggle:=UiKit.make_button("查看完整联动演示")
		combo_toggle.name="ComboDemoToggle";combo_toggle.toggle_mode=true;rows.add_child(combo_toggle)
		var combo_host:=VBoxContainer.new();combo_host.name="ComboDemoHost";rows.add_child(combo_host);combo_host.hide()
		combo_toggle.toggled.connect(func(open:bool):
			if open and combo_host.get_child_count()==0:
				var demo=preload("res://scripts/ui/hero_combo_demo.gd").new()
				demo.name="HeroComboDemo";combo_host.add_child(demo);demo.show_hero(id)
			combo_host.visible=open
			combo_toggle.text="收起完整联动演示" if open else "查看完整联动演示")
	if id in ["ORCA","TTNK"]:
		var arrival_toggle:=UiKit.make_button("查看额外出场演示")
		arrival_toggle.name="ArrivalDemoToggle";arrival_toggle.toggle_mode=true
		rows.add_child(arrival_toggle)
		var arrival_host:=VBoxContainer.new();rows.add_child(arrival_host)
		arrival_host.name="ArrivalDemoHost";arrival_host.hide()
		arrival_toggle.toggled.connect(func(open:bool):
			if open and arrival_host.get_child_count()==0:
				var demo=preload("res://scripts/ui/hero_arrival_demo.gd").new()
				demo.name="HeroArrivalDemo";arrival_host.add_child(demo);demo.show_hero(id)
			arrival_host.visible=open
			arrival_toggle.text="收起额外出场演示" if open else "查看额外出场演示")
	if id in ["TANY","BORIS","ORCA","TTNK"]:
		var task_toggle:=UiKit.make_button("查看任务与结算演示")
		task_toggle.name="ContractDemoToggle";task_toggle.toggle_mode=true;rows.add_child(task_toggle)
		var task_host:=VBoxContainer.new();task_host.name="ContractDemoHost";rows.add_child(task_host);task_host.hide()
		task_toggle.toggled.connect(func(open:bool):
			if open and task_host.get_child_count()==0:
				var demo=preload("res://scripts/ui/hero_contract_demo.gd").new()
				demo.name="HeroContractDemo";task_host.add_child(demo);demo.show_hero(id)
			task_host.visible=open
			task_toggle.text="收起任务与结算演示" if open else "查看任务与结算演示")

func _buy() -> void:
	Contracts.purchase(MetaProgress,hero_id);refresh(hero_id)
