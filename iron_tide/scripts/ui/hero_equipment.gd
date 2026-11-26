extends VBoxContainer
signal demo_requested(card:String,unit_id:String)
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")
const Icon=preload("res://scripts/ui/progression_icon.gd")
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")
var unit_id:=""
var inheritance:Label

func refresh(id:String) -> void:
	unit_id=id
	for child in get_children():remove_child(child);child.queue_free()
	add_child(UiKit.make_label("继承本体改造 · "+str(GameData.get_unit(id).name),18,UiKit.COL_ACCENT_2))
	inheritance=UiKit.make_label("",14,UiKit.COL_OK)
	inheritance.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(inheritance)
	var bonus:=MetaProgress.unit_stat_bonus(id)
	var lines:=PackedStringArray(["火力 ×%.2f · 减伤系数 ×%.2f（与英雄训练叠加）"%[bonus.attack_bonus,bonus.defense_bonus]])
	for track in MetaProgress.unit_upgrade_tracks():
		var key:String=track.id
		if key=="skill" and MetaProgress.skill_training_benefits(id).is_empty():continue
		lines.append("%s Lv.%d / %d · %s"%[track.name,MetaProgress.unit_level(id,key),track.max_level,"继承生效" if MetaProgress.effect_enabled("track",key,id) else "本体已停用"])
	var benefits:=MetaProgress.skill_training_benefits(id)
	if not benefits.is_empty():lines.append(preload("res://scripts/rules/skill_training.gd").description(benefits,false))
	inheritance.text="\n".join(lines)
	if id in MetaProgress.Academy.Stars.IDS:return
	add_child(UiKit.make_label("英雄独立装配 · W 主动 + 被动",18,UiKit.COL_ACCENT_2))
	var help:=UiKit.make_label("与普通兵种分别保存；共享已获得卡牌及培养等级。新开扩展对局生效，Q／E 与英雄天赋保持原规则。",13,UiKit.COL_DIM)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var loadout:=Loadouts.effective(MetaProgress,id)
	_slot("active",str(loadout.active[0]))
	_slot("passive",str(loadout.passive))

func _slot(kind:String,current:String) -> void:
	var row:=HBoxContainer.new();add_child(row)
	row.add_child(UiKit.make_label("英雄 W 主动" if kind=="active" else "英雄被动",14,UiKit.COL_ACCENT_2))
	var picker:=OptionButton.new();picker.name=kind
	picker.add_theme_constant_override("icon_max_width",28)
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	picker.add_item("（空）");picker.set_item_metadata(0,"")
	for card in MetaProgress.owned_skills(kind):
		if not UnitSkillLayout.compatible(unit_id,card.id,true) or (kind=="active" and not UnitSkillLayout.equippable(unit_id,card.id,true)):continue
		var rank:=MetaProgress.Academy.card_rank(MetaProgress,card.id)
		picker.add_icon_item(Icon.texture(card.id),("专属 · " if Scope.exclusive(card) else "")+str(card.name)+" · Lv.%d"%rank)
		var index:=picker.item_count-1
		picker.get_popup().set_item_icon_max_width(index,28)
		picker.set_item_metadata(index,card.id)
		picker.get_popup().set_item_tooltip(index,MetaProgress.Academy.skill_description(card,rank))
		if card.id==current:
			picker.select(index)
			picker.add_theme_color_override("font_color",Scope.rarity_color(card))
	picker.tooltip_text=picker.get_popup().get_item_tooltip(picker.selected)
	Upgrade.mark(picker,Upgrade.skill_slots(unit_id,true)[kind])
	var demo:=UiKit.make_button("技能演示",14)
	demo.disabled=current.is_empty()
	row.add_child(demo)
	demo.pressed.connect(func():demo_requested.emit(current,unit_id))
	var detail:=UiKit.make_label(picker.tooltip_text,13,UiKit.COL_DIM)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	picker.item_selected.connect(func(index):
		if not Loadouts.equip(MetaProgress,unit_id,kind,str(picker.get_item_metadata(index))):
			Events.emit_message("英雄装配未保存，请检查技能或存档。",UiKit.COL_WARN)
			refresh(unit_id))
