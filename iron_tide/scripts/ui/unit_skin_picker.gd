extends VBoxContainer
## Refit uses the workshop's ownership, compatibility and durable equip path.
const Catalog = preload("res://scripts/rules/cosmetic_catalog.gd")
const Styles = preload("res://scripts/units/unit_cosmetics.gd")
var unit_id := ""
var slot := "skin"
var preview
var picker := OptionButton.new()
var status := Label.new()

static func choices(id:String) -> Dictionary:
	var key := "paint" if Styles.is_ra3(GameData.get_unit(id)) else "skin"
	var result:Dictionary = (Styles.PAINT if key=="paint" else Styles.SKINS).duplicate()
	if key=="skin" and Catalog.EXCLUSIVE_SKINS.has(id):
		var value:String=Catalog.EXCLUSIVE_SKINS[id]
		result[value]=Catalog.display_name(value)
	for value in result.keys():
		if not Catalog.available(id,key,value):result.erase(value)
	return result

static func requirement(id:String, key:String, value:String) -> String:
	var research := Catalog.research_required(value)
	var wins := Catalog.wins_required(value)
	if research>0:return "累计研究 %d 项科技"%research
	if wins>0:return "累计 %d 胜"%wins
	if Catalog.victory_tier(value)>0:return Catalog.requirement(value)
	if Catalog.win_reward_only(id,value):return "胜场奖励待开放"
	return "涂装工房解锁 · %d 钻石／皮肤券"%Catalog.price(key)

func setup(id:String, model) -> void:
	name="UnitSkinPicker"
	unit_id=id;preview=model
	slot="paint" if Styles.is_ra3(GameData.get_unit(id)) else "skin"
	var options:=choices(id)
	visible=options.size()>1
	if not visible:return
	var row:=HBoxContainer.new()
	add_child(row)
	row.add_child(UiKit.make_label("单位涂装" if slot=="paint" else "单位皮肤",15,UiKit.COL_ACCENT_2))
	picker.name="SkinOptions"
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	for value:String in options:
		var owned:=MetaProgress.cosmetic_owned(value)
		var text:String=options[value]
		if not owned:text+=" · 未解锁（%s）"%requirement(id,slot,value)
		picker.add_item(text)
		var i:=picker.item_count-1
		picker.set_item_metadata(i,value)
		picker.set_item_disabled(i,not owned)
		picker.get_popup().set_item_tooltip(i,Catalog.effect_text(id,slot,value))
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",12)
	add_child(status)
	_sync()
	picker.item_selected.connect(_select)

func _sync() -> void:
	var saved:String=MetaProgress.cosmetic_style(unit_id).get(slot,"stock")
	for i in picker.item_count:
		if picker.get_item_metadata(i)==saved:picker.select(i);break
	status.text="已装备 · %s。切换自动保存，原版可随时恢复。\n%s"%[picker.get_item_text(picker.selected),Catalog.effect_text(unit_id,slot,saved)]

func _select(index:int) -> void:
	if index<0 or index>=picker.item_count:return
	var value:String=picker.get_item_metadata(index)
	if not MetaProgress.cosmetic_owned(value) or not Catalog.available(unit_id,slot,value):
		_sync()
		return
	if not MetaProgress.set_cosmetic(unit_id,slot,value):
		_sync()
		status.text="皮肤未保存，请重试；原装配保持不变。"
		return
	preview.try_outfit(slot,value)
	_sync()
