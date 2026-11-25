extends VBoxContainer
signal demo_requested(card:String,unit_id:String)
const Icon=preload("res://scripts/ui/progression_icon.gd")
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const GOLD=Color("#ffe397")
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")
var card_id:=""
var hero_id:=""

static func badge(id:String,pixels:int) -> TextureRect:
	var icon:=TextureRect.new()
	icon.texture=Icon.texture(id)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size=Vector2(pixels,pixels)
	Icon.shine(icon)
	return icon

func refresh(id:String,hero:String) -> void:
	card_id=id
	hero_id=hero
	for child in get_children():remove_child(child);child.queue_free()
	var card:=GameData.get_skill(id)
	var owned:=MetaProgress.skill_unlocked(id)
	var rank:=MetaProgress.Academy.card_rank(MetaProgress,id)
	var row:=HFlowContainer.new()
	add_child(row)
	var icon:=badge(id,36)
	icon.name="RewardIcon_"+id
	row.add_child(icon)
	row.add_child(UiKit.make_label(("W · " if card.type=="active" else "被动 · ")+str(card.name)+("　Lv.%d / 3"%rank if owned else "　完成契约解锁"),16,GOLD))
	var play:=UiKit.make_button("技能演示")
	play.name="Demo_"+id
	play.pressed.connect(demo_requested.emit.bind(id,hero))
	row.add_child(play)
	var loadout:=Loadouts.effective(MetaProgress,hero)
	var equipped:bool=id in loadout.active if card.type=="active" else id==loadout.passive
	var slot:="英雄 W" if card.type=="active" else "英雄被动"
	var install:=UiKit.make_button(("已装配到" if equipped else "快速装配到")+slot)
	install.name="QuickEquip_"+id
	install.disabled=not owned or equipped
	install.tooltip_text="完成契约解锁后可装配。" if not owned else "替换该英雄的对应技能槽；普通兵种装配保持不变，新开扩展对局生效。"
	install.pressed.connect(_equip)
	row.add_child(install)
	if owned and rank<3:
		var cost:int=MetaProgress.Academy.card_upgrade_cost(id,rank)
		var upgrade:=UiKit.make_button("升级 · %d 战略核心"%cost)
		upgrade.name="Upgrade_"+id
		upgrade.disabled=MetaProgress.balance("cores")<cost
		upgrade.pressed.connect(_upgrade)
		row.add_child(upgrade)
		Upgrade.mark(upgrade,Upgrade.card(id))
	var desc:=UiKit.make_label(MetaProgress.Academy.skill_description(card,rank),13,UiKit.COL_TEXT)
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(desc)

func _equip() -> void:
	var kind:String=GameData.get_skill(card_id).get("type","")
	if not Loadouts.equip(MetaProgress,hero_id,kind,card_id):
		Events.emit_message("英雄装配未保存，请检查技能或存档。",UiKit.COL_WARN)
	refresh(card_id,hero_id)

func _upgrade() -> void:
	MetaProgress.Academy.purchase(MetaProgress,"level",card_id)
	refresh(card_id,hero_id)
