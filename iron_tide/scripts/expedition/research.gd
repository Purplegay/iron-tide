extends RefCounted

const BRANCHES := {"army":"军团调度", "supply":"前线后勤", "intel":"战场情报", "factory":"野战生产", "bargain":"折扣采购"}
const NODES := {
	"bargain":["一键锁定打折商品","一键购买打折商品"],
	"army":["第一批军团提前10%","增援移速提高1%","第二批军团提前10%","增援生命提高1%","第三批军团提前10%","增援移速再提高1%","第一批提前至12%","增援生命再提高1%","第二批提前至12%","第三批提前至12%"],
	"supply":["开局补给增加5","胜利补给增加1","商店增加一个货位","开局补给再增加5","每个营地多一次免费刷新","胜利补给再增加1","首次胜利额外获得3补给","开局补给再增加3","首次进入营地获得3补给","首个营地再送一次刷新"],
	"intel":["预览任务敌军，并在各战区标出百合子初遇地点","视野提高1%","显示首批敌军数量","显示首批抵达时间","预览第二批敌军","视野再提高1%","显示第二批数量","显示第二批抵达时间","标记精英战术","两批敌军并列比较"],
	"factory":["载具生产时间缩短1%","步兵生产费用降低1%","首辆载具生产时间缩短20%","载具生产再快1%","首单步兵生产时间缩短20%","步兵生产时间缩短1%","首架飞机生产时间缩短15%","舰船生产时间缩短1%","飞机生产时间缩短1%","首艘舰船生产时间缩短15%"]}
const COST := [100,200,300,400,500,600,700,800,900,1000]
const Upgrade = preload("res://scripts/ui/progression_upgrade.gd")

static func rank(run:Dictionary, branch:String) -> int:
	return clampi(int(run.get("research",{}).get(branch,0)),0,10)

static func current_level(branch: String) -> int:
	return int(MetaProgress.academy.get("expedition_research", {}).get(branch, 0))

static func can_buy(branch: String, index: int) -> bool:
	return NODES.has(branch) and index >= 0 and index < NODES[branch].size() and index == current_level(branch) and MetaProgress.balance("cores") >= COST[index]

static func mark_entry(button: Button) -> void:
	for branch: String in BRANCHES:
		if can_buy(branch, current_level(branch)):
			Upgrade.mark(button, true)
			return
	Upgrade.mark(button, false)

static func watch_changes(control: Control, refresh: Callable) -> void:
	refresh.call()
	# Godot compares bound static methods by target and method, ignoring their arguments.
	var on_change := func(): refresh.call()
	Events.meta_changed.connect(on_change)
	control.tree_exiting.connect(Events.meta_changed.disconnect.bind(on_change), CONNECT_ONE_SHOT)

static func watch_entry(button: Button) -> void:
	watch_changes(button, mark_entry.bind(button))

static func buy(branch:String, expected:int) -> bool:
	if not can_buy(branch, expected): return false
	var meta = MetaProgress
	var old := MetaProgress.academy.duplicate(true)
	var levels:Dictionary = meta.academy.get("expedition_research",{}).duplicate()
	var cores := MetaProgress.balance("cores")
	levels[branch] = expected+1
	meta.academy.expedition_research = levels
	meta.currency.cores = cores-COST[expected]
	if not meta.save():
		meta.currency.cores=cores
		meta.academy=old
		return false
	Events.meta_changed.emit()
	return true

static func open(screen) -> void:
	var window := AcceptDialog.new()
	window.title="远征司令部 · 永久研究"
	screen.add_child(window)
	var box := VBoxContainer.new()
	window.add_child(box)
	window.ok_button_text = "关闭"
	watch_changes(box, populate.bind(box))
	window.confirmed.connect(window.queue_free)
	window.close_requested.connect(window.queue_free)
	window.popup_centered_ratio(0.92)

static func populate(box:VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var cores:=floori(MetaProgress.balance("cores"))
	var wallet:=HBoxContainer.new()
	box.add_child(wallet)
	var badge:=TextureRect.new()
	badge.texture=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
	wallet.add_child(badge)
	wallet.add_child(UiKit.make_label("可用战略核心 %d　·　点击研究，下次出征生效"%cores))
	var arms:=HBoxContainer.new()
	box.add_child(arms)
	for branch:String in BRANCHES:
		var col:=VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arms.add_child(col)
		col.add_child(UiKit.make_label("┬　"+BRANCHES[branch],18,UiKit.COL_GOLD))
		var current:=current_level(branch)
		for index in NODES[branch].size():
			var text:String=NODES[branch][index]+"\n"+("已研究" if index<current else "%d 战略核心"%COST[index])
			var b:=UiKit.make_button(text)
			col.add_child(b)
			b.pressed.connect(buy.bind(branch,index))
			if index>=current:b.icon=badge.texture
			b.disabled=not can_buy(branch,index)
			Upgrade.mark(b, not b.disabled)
			if index>current:b.tooltip_text="请先研究上方节点"
			elif index==current and b.disabled:
				b.text+="（还差%d核心）"%(COST[index]-cores)
			if index < current:
				b.add_theme_color_override("font_disabled_color", Color.WHITE)

static func supply_reward(run:Dictionary) -> int:
	var level:=rank(run,"supply")
	return int(level>=2)+int(level>=6)+3*int(level>=7 and run.history.is_empty())

static func production(battle,side:String,uid:String) -> float:
	if side!="ally" or battle==null:return 1.0
	var level:=rank(BattleRequest.combat_context.get("expedition",{}),"factory")
	if level==0:return 1.0
	var kind:=GameData.unit_production_category(GameData.get_unit(uid))
	var reduction:=0.0
	match kind:
		"vehicle": reduction=.01+(.01 if level>=4 else 0.0)
		"infantry": reduction=.01 if level>=6 else 0.0
		"air": reduction=.01 if level>=9 else 0.0
		"naval": reduction=.01 if level>=8 else 0.0
	if not battle.allied_state.get("research_built",{}).has(kind) and level>=int({"vehicle":3,"infantry":5,"air":7,"naval":10}.get(kind,11)):
		reduction+=.15 if kind in ["air","naval"] else .20
	return 1.0/(1.0-reduction)

static func accelerate(rows:Array,run:Dictionary) -> void:
	var level:=rank(run,"army")
	if level==0:return
	var times:Array=[]
	for row:Dictionary in rows:
		if str(row.get("hero",""))!="":continue
		var due:=float(row.due)
		if not times.has(due):times.append(due)
	times.sort()
	for row:Dictionary in rows:
		if str(row.get("hero",""))!="":continue
		var index:=times.find(float(row.due))
		if index<3 and level>=[1,3,5][index]:row.due*=.88 if level>=[7,9,10][index] else .90

class GreenModel extends Control:
	var id:String
	func _draw() -> void:
		var art:=RA2Art.art(id)
		if art.is_empty():return
		var frame:=maxi(0,RA2Art.seq_frame(RA2Art.seq(id),"Guard",2,0))
		var src:=RA2Art.src_rect(art,frame)
		var fitted:Vector2=src.size*minf(size.x/maxf(1,src.size.x),size.y/maxf(1,src.size.y))
		RA2Art.draw_sprite(self,art,Rect2((size-fitted)*.5,fitted),src,Color(.35,1,.48))

static func intel_panel(screen,box,run:Dictionary,route:Dictionary) -> void:
	var level:=rank(run,"intel")
	if level==0:return
	const Campaign=preload("res://scripts/expedition/campaign.gd")
	var escort:bool=route.task=="escort"
	var counts:Dictionary={}
	
	var layout:Container=HBoxContainer.new() if level==10 else VBoxContainer.new()
	box.add_child(layout)
	for wave in (2 if level>=5 else 1):
		counts.clear()
		var convoy_wave:=escort and wave==0
		for id in Campaign.wave_units(run.stage,route.elite,"" if convoy_wave else route.get("elite_tactic",""),convoy_wave):counts[id]=int(counts.get(id,0))+1
		var section:=VBoxContainer.new()
		layout.add_child(section)
		var caption:="主要任务敌军" if level<3 else ("首批敌援" if wave==0 else "第二批敌援")
		if level>=(4 if wave==0 else 8):caption+=" · 约%d秒"%(([70,95] if escort else [45,90])[wave])
		section.add_child(screen.label(caption))
		var row:=HBoxContainer.new();section.add_child(row)
		for id:String in counts:
			var cell:=VBoxContainer.new();row.add_child(cell)
			var model:=GreenModel.new();model.id=id;model.custom_minimum_size=Vector2(64,44);cell.add_child(model)
			cell.add_child(screen.label(str(GameData.get_unit(id).name)+(" ×%d"%counts[id] if level>=(3 if wave==0 else 7) else ""),13))
	if level>=9 and route.elite:box.add_child(screen.label("精英部队 · "+str(Campaign.wave_intel(run.stage,route)),14,UiKit.COL_GOLD))
