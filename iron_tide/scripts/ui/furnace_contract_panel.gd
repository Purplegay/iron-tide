extends PanelContainer
signal demo_requested(card: String, unit_id: String)
const Icon = preload("res://scripts/ui/progression_icon.gd")
const Cards = preload("res://scripts/units/furnace_legend.gd")
const GOLD := Color("#ffe397")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")

static func shine(icon: CanvasItem) -> void:
	Icon.shine(icon)

func refresh() -> void:
	for child in get_children(): remove_child(child);child.queue_free()
	add_theme_stylebox_override("panel",UiKit.panel_style(Color("#251e1a"),Color("#ba8739"),6,2,12))
	var rows:=VBoxContainer.new()
	add_child(rows)
	var title:=HBoxContainer.new()
	rows.add_child(title)
	var icon:=TextureRect.new()
	icon.name="ContractIcon"
	icon.texture=Icon.texture("furnace_contract")
	icon.custom_minimum_size=Vector2(48,48)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	title.add_child(icon)
	shine(icon)
	title.add_child(UiKit.make_label(str(Pool.entry("furnace_contract").get("name","炉火契约"))+" · 究极传说",21,GOLD))
	var preview := UiKit.make_button("查看技能联动演示")
	preview.name="FurnacePreview"
	preview.pressed.connect(func(): demo_requested.emit("furnace_contract", "E2"))
	title.add_child(preview)
	var state:=MetaProgress.academy
	var rules:=UiKit.make_label(Pool.description(MetaProgress,"furnace_contract"),14,GOLD)
	rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(rules)
	if not state.get("furnace_contract",false):
		var buy:=UiKit.make_button("开启契约 · %d 碎片"%Pool.cost())
		buy.name="FurnaceRedeem"
		buy.disabled=int(state.get("card_shards",0))<Pool.cost()
		buy.pressed.connect(func(): MetaProgress.Academy.purchase(MetaProgress,"furnace_contract"))
		rows.add_child(buy)
	else:
		rows.add_child(UiKit.make_label("契约已完成" if state.get("furnace_complete",false) else "已获得契约 · 任务进行中",14,GOLD))
	var tasks:Dictionary=state.get("furnace_tasks",{})
	var damage:=float(tasks.get("damage",0))
	for item in [[tasks.get("takedown",false),"炉火亲自击毁敌建造厂或击杀英雄级单位"],[damage>=10000,"炉火累计造成实际伤害　%d / 10000"%int(damage)],[tasks.get("peace",false),"困难以上获胜，炉火全局未攻击（可不建造）"]]:
		rows.add_child(UiKit.make_label(("✓　" if item[0] else "○　")+str(item[1]),15,UiKit.COL_OK if item[0] else UiKit.COL_TEXT))
	for id in Pool.entry("furnace_contract").get("cards",[]):
		var reward:=preload("res://scripts/ui/hero_contract_reward.gd").new()
		rows.add_child(reward)
		reward.demo_requested.connect(demo_requested.emit)
		reward.refresh(str(id),"E2")
