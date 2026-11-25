extends VBoxContainer
## Progression view; purchases always go through MetaProgress's durable entry.
# A firing slit, range arcs and one chevron per research tier.
class BunkerOpticsIcon extends Control:
	var tier := 1
	func _draw() -> void:
		draw_rect(Rect2(1,1,43,35),Color("#182936"))
		draw_colored_polygon(PackedVector2Array([Vector2(5,25),Vector2(10,14),Vector2(27,14),Vector2(33,25)]),Color("#adbfcc"))
		draw_rect(Rect2(11,18,12,3),Color("#243442"))
		for radius in [7,12]:
			draw_arc(Vector2(28,15), radius,-1.35,-0.12,12,Color("#ffc55a"),2,true)
		for i in tier:
			var x := 7.0+i*8
			draw_polyline(PackedVector2Array([Vector2(x,32),Vector2(x+3,29),Vector2(x+6,32)]),Color("#ffc55a"),2,true)

const Tech = preload("res://scripts/rules/production_technology.gd")
var cosmetic_progress:Label
var cards: Dictionary = {}
var result_label: Label
var grid: GridContainer

func _ready() -> void:
	var kit = UiKit
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	var heading := kit.make_label("生产、防御与战术科技", 24, kit.COL_ACCENT_2)
	add_child(heading)
	var intro := kit.make_label("永久研究 · 消耗战略核心 · 同类数值升级合并展示，每级只购买一次", 16, kit.COL_GOLD)
	add_child(intro)
	var scope := kit.make_label("已解锁的科技可以开关；多级科技可选择生效等级，开启后在新的扩展对局生效。RA2 模式不加载养成；读取旧对局沿用当时的科技状态。", 14, kit.COL_TEXT)
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(scope)
	var root := kit.make_panel(kit.COL_PANEL_2, kit.COL_ACCENT)
	var root_text := kit.make_label("后勤指挥网络  →  选择下方分支进行永久研究", 17, kit.COL_ACCENT_2)
	root_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(root_text)
	add_child(root)
	cosmetic_progress=kit.make_label("",14,kit.COL_GOLD)
	cosmetic_progress.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(cosmetic_progress)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	add_child(grid)
	for id in ["structure_queue", "unit_queue_1", "refinery_miner", "joint_ra2_production", "superweapon_damage_1", "repair_all", "production_recipes", "auto_w"]:
		var definition := MetaProgress.technology_definition(id)
		var panel := kit.make_panel(kit.COL_PANEL_2, kit.COL_LINE)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		panel.add_child(content)
		var title := HBoxContainer.new()
		content.add_child(title)
		if str(id).begins_with("bunker_optics_"):
			var icon := BunkerOpticsIcon.new()
			icon.tier = str(id).right(1).to_int()
			icon.custom_minimum_size = Vector2(46,37)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title.add_child(icon)

		var name_label:=kit.make_label(str(definition.get("name", id)), 20, kit.COL_ACCENT_2)
		title.add_child(name_label)
		var desc := kit.make_label(str(definition.get("desc", "")), 15, kit.COL_TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300, 32)
		content.add_child(desc)
		var requirement := kit.make_label("前置科技：无", 13, kit.COL_DIM)
		content.add_child(requirement)
		var status := kit.make_label("", 15, kit.COL_WARN)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(status)
		var button := kit.make_button("", 17)
		button.icon = preload("res://scripts/ui/progression_icon.gd").texture(str(id))
		button.custom_minimum_size.y = 34
		button.pressed.connect(_research.bind(id))
		content.add_child(button)
		var toggle:=CheckButton.new()
		toggle.text = "立即启用" if id == "production_recipes" else "在新对局中启用"
		toggle.toggled.connect(func(enabled:bool):
			if not MetaProgress.set_effect_enabled("tech",id,"",enabled):
				refresh()
				result_label.text="开关未保存，请重试。")
		content.add_child(toggle)
		var levels:OptionButton
		if Tech.UPGRADE_GROUPS.has(id):
			levels=OptionButton.new()
			levels.item_selected.connect(_set_group_level.bind(str(id)))
			content.add_child(levels)
		if id == "production_recipes":
			var preset := kit.make_button("预设开局出兵…")
			preset.name = "OpeningOrders"
			content.add_child(preset)
			preset.pressed.connect(func():
				var editor = preload("res://scripts/ui/opening_orders.gd").new()
				add_child(editor)
				editor.popup_centered())
		cards[id] = {"toggle":toggle,"button": button, "status": status, "requirement": requirement,"title":name_label,"desc":desc,"levels":levels}
	result_label = kit.make_label("", 14, kit.COL_OK)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result_label)
	Events.meta_changed.connect(refresh)
	resized.connect(func(): grid.columns = 1 if size.x < 800 else 2)
	refresh()

func refresh() -> void:
	var rewards:=PackedStringArray()
	for value:String in GameData.meta_config.get("cosmetic_research_rewards",{}):
		var name:=MetaProgress.Cosmetics.display_name(value)
		var count:=MetaProgress.Cosmetics.research_required(value)
		rewards.append("%s（%d 项%s）"%[name,count," · 已解锁" if MetaProgress.cosmetic_owned(value) else ""])
	cosmetic_progress.text="外观奖励 · 累计研究 %d 项　%s"%[MetaProgress.researched_count(),"　".join(rewards)]
	for id in cards:
		var card: Dictionary = cards[id]
		if Tech.UPGRADE_GROUPS.has(id):
			_refresh_group(str(id),card)
			var next:=_next_tier(id)
			card.button.icon=null if next.is_empty() else preload("res://scripts/ui/resource_cost_icon.gd").texture(MetaProgress.technology_definition(next).currency)
			continue
		var definition := MetaProgress.technology_definition(id)
		var owned := MetaProgress.technology_owned(id)
		var reason := MetaProgress.technology_block_reason(id)
		card.button.disabled = not reason.is_empty()
		card.button.text = "已永久解锁" if owned else "研究 · %d %s" % [int(definition.get("cost", 0)), MetaProgress.currency_name(str(definition.get("currency", "credits")))]
		card.button.icon=null if owned else preload("res://scripts/ui/resource_cost_icon.gd").texture(definition.currency)
		card.button.tooltip_text = reason if not reason.is_empty() else "立即研究并永久保存；在下一场扩展模式对局启用。"
		if id == "production_recipes" and reason.is_empty():
			card.button.tooltip_text = "研究后立即在当前扩展对局启用。"
		card.toggle.visible=owned
		card.toggle.set_pressed_no_signal(MetaProgress.effect_enabled("tech",id))
		if owned:
			card.status.text="已启用" if MetaProgress.technology_active(id) else ("前置已关闭，暂不生效" if card.toggle.button_pressed else "已关闭")
		else:card.status.text=reason if not reason.is_empty() else "可研究 · 尚未解锁"
		if id == "refinery_miner" and GM.unlock_production_tech and not owned:
			card.status.text += "\n当前矿车调试开关已开启，临时可用不代表永久解锁。"
		var prerequisites := PackedStringArray()
		for dependency in definition.get("requires", []):
			prerequisites.append(str(MetaProgress.technology_definition(str(dependency)).get("name", dependency)))
		card.requirement.text = "前置科技：" + ("无" if prerequisites.is_empty() else "、".join(prerequisites))

func _research(id: String) -> void:
	if Tech.UPGRADE_GROUPS.has(id):
		id=_next_tier(id)
		if id.is_empty():return
	if MetaProgress.research_technology(id):
		result_label.text = "已永久解锁「%s」。开始新的扩展模式对局即可生效。" % MetaProgress.technology_definition(id).name
		if id == "production_recipes":
			result_label.text = "已解锁生产配方，当前扩展对局即可使用。"
	else:
		var reason := MetaProgress.technology_block_reason(id)
		result_label.text = reason if not reason.is_empty() else "保存失败，未扣除核心，请重试。"
	refresh()

func _next_tier(id:String) -> String:
	for tier:String in Tech.UPGRADE_GROUPS[id]:
		if not MetaProgress.technology_owned(tier):return tier
	return ""

func _capacity(id:String, level:int) -> int:
	if id == Tech.REFINERY_MINER:
		return [0, 1, Tech.MINER_CAPACITY][level]
	var preview:=Tech.new()
	preview.unlocked["ally"]=Tech.UPGRADE_GROUPS[id].slice(0,level)
	return preview.structure_capacity("ally") if id==Tech.STRUCTURE_QUEUE else preview.unit_capacity("ally")

func _refresh_group(id:String, card:Dictionary) -> void:
	if id == preload("res://scripts/rules/superweapon_damage.gd").ID:
		_refresh_superweapon_damage(card)
		return
	var tiers:Array=Tech.UPGRADE_GROUPS[id]
	var researched:=0
	var active:=0
	for i in tiers.size():
		if MetaProgress.technology_owned(tiers[i]):researched=i+1
		if MetaProgress.technology_active(tiers[i]):active=i+1
	var next:=_next_tier(id)
	if id == "production_recipes":
		_refresh_repair_group(card, researched, active, next)
		card.title.text="生产配方 · Lv.%d / 2"%researched
		card.desc.text="一级可在战场保存配方并整组下单。二级可在此预设出兵，新的扩展对局会在工厂就绪时自动排队，按生产进度付费。"
		card.requirement.text="先研究生产配方，再研究开局自动出兵。"
		card.button.get_parent().get_node("OpeningOrders").disabled = researched < 2
		return
	if id == "repair_all":
		_refresh_repair_group(card, researched, active, next)
		return
	var title:="建筑预约" if id==Tech.STRUCTURE_QUEUE else "单位预约"
	card.title.text="%s · Lv.%d / %d"%[title,researched,tiers.size()]
	var scope:="建筑与防御各自的订单上限" if id==Tech.STRUCTURE_QUEUE else "每座单位生产建筑的订单上限"
	card.desc.text="%s：%d 项"%[scope,_capacity(id,researched)]
	if not next.is_empty():card.desc.text+=" → %d 项（下一等级）"%_capacity(id,tiers.find(next)+1)
	card.desc.text+="。\n"+("研究后，已就绪建筑不阻塞后续生产。" if id==Tech.STRUCTURE_QUEUE else "包含正在生产的一项；矿场容量由矿场科技决定。")
	var progression:=PackedStringArray()
	for i in tiers.size():progression.append("Lv.%d：%d 项"%[i+1,_capacity(id,i+1)])
	card.requirement.text="各级容量："+" / ".join(progression)
	if id == Tech.REFINERY_MINER:
		card.title.text = "矿场矿车制造 · Lv.%d / 2" % researched
		card.desc.text = "1级可在每座矿场付费制造一辆矿车，出厂后自动采矿。\n2级解锁矿车复数预约，连续点击可排入最多 %d 辆（含在产），逐辆制造。" % Tech.MINER_CAPACITY
		card.requirement.text = "研究1级后可升级至2级。"
	card.requirement.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var reason:="" if next.is_empty() else MetaProgress.technology_block_reason(next)
	card.button.disabled=next.is_empty() or not reason.is_empty()
	if next.is_empty():card.button.text="已满级 · 永久解锁"
	else:
		var definition:=MetaProgress.technology_definition(next)
		card.button.text="%s Lv.%d · %d %s"%["研究" if researched==0 else "升级至",tiers.find(next)+1,int(definition.cost),MetaProgress.currency_name(str(definition.currency))]
	card.button.tooltip_text=reason if not reason.is_empty() else "逐级研究并永久保存；仅新扩展对局生效。"
	card.status.text="新对局：%s · 当前上限 %d 项"%["关闭" if active==0 else "启用 Lv.%d"%active,_capacity(id,active)]
	if not reason.is_empty():card.status.text+="\n"+reason
	if id == Tech.REFINERY_MINER and GM.unlock_production_tech and researched == 0:
		card.status.text += "\n调试开关临时启用1级。"
	card.toggle.hide()
	card.levels.clear()
	card.levels.add_item("在新对局中关闭",0)
	for i in tiers.size():
		if not MetaProgress.technology_owned(tiers[i]):break
		card.levels.add_item("在新对局中启用 Lv.%d · %d 项"%[i+1,_capacity(id,i+1)],i+1)
	card.levels.select(card.levels.get_item_index(active))
	card.levels.visible=researched>0

func _refresh_repair_group(card: Dictionary, researched: int, active: int, next: String) -> void:
	var labels := ["关闭", "生产配方", "开局自动出兵"] if card == cards.production_recipes else ["关闭", "一键维修", "自动抢修"]
	card.title.text = "一键维修 · Lv.%d / 2" % researched
	card.desc.text = "1级同时维修当前受损的己方建筑。2级可切换自动抢修，持续维修新受损的建筑，按实际维修量付费。"
	card.requirement.text = "研究一键维修后可升级自动抢修。"
	var reason := "" if next.is_empty() else MetaProgress.technology_block_reason(next)
	card.button.disabled = next.is_empty() or not reason.is_empty()
	card.button.text = "已满级" if next.is_empty() else "研究%s · %d 战略核心" % [labels[researched + 1], MetaProgress.technology_definition(next).cost]
	card.status.text = "新对局 · " + str(labels[active])
	if not reason.is_empty(): card.status.text += "\n" + reason
	card.toggle.hide()
	card.levels.clear()
	for i in range(researched + 1): card.levels.add_item(labels[i], i)
	card.levels.select(active)
	card.levels.visible = researched > 0

func _set_group_level(index:int,id:String) -> void:
	var level:int=cards[id].levels.get_item_id(index)
	if not MetaProgress.set_technology_group_level(id,level):
		refresh()
		result_label.text="科技等级开关未保存，请重试。"

func _refresh_superweapon_damage(card: Dictionary) -> void:
	var rule = preload("res://scripts/rules/superweapon_damage.gd")
	var researched := 0
	var active := 0
	for i in rule.LEVELS.size():
		if MetaProgress.technology_owned(rule.LEVELS[i]): researched = i + 1
		if MetaProgress.technology_active(rule.LEVELS[i]): active = i + 1
	var next := _next_tier(rule.ID)
	card.title.text = "超级武器伤害强化 · Lv.%d / 20" % researched
	card.desc.text = "总伤害：%d%%" % rule.percent(researched)
	if not next.is_empty(): card.desc.text += " → %d%%（下一等级）" % rule.percent(researched + 1)
	card.desc.text += "。\n强化己方核弹爆炸、核弹辐射和闪电风暴；不改变范围、持续时间及充能时间。仅新扩展对局生效。"
	card.desc.text += "\n" + rule.ai_description()
	card.requirement.text = "每级 +20 个百分点，满级总伤害 500%（5 倍）；逐级研究。"
	card.requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reason := "" if next.is_empty() else MetaProgress.technology_block_reason(next)
	card.button.disabled = next.is_empty() or not reason.is_empty()
	card.button.text = "已满级 · 永久解锁" if next.is_empty() else "升级至 Lv.%d · %d 战略核心" % [researched + 1, MetaProgress.technology_definition(next).cost]
	card.button.tooltip_text = reason if not reason.is_empty() else "逐级研究并永久保存；仅新扩展对局生效。"
	card.status.text = "新对局：%s · 总伤害 %d%%" % ["关闭" if active == 0 else "启用 Lv.%d" % active, rule.percent(active)]
	if not reason.is_empty(): card.status.text += "\n" + reason
	card.toggle.hide()
	card.levels.clear()
	card.levels.add_item("在新对局中关闭", 0)
	for i in researched:
		card.levels.add_item("启用 Lv.%d · 总伤害 %d%%" % [i + 1, rule.percent(i + 1)], i + 1)
	card.levels.select(card.levels.get_item_index(active))
	card.levels.visible = researched > 0
