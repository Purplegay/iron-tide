extends ColorRect
const NewContent=preload("res://scripts/ui/progression_new.gd")
## Playable rule illustrations for the faction cards. Never touch a match or wallet.
const HeroDemo = preload("res://scripts/ui/furnace_demo.gd")
const Stage = preload("res://scripts/ui/faction_card_stage.gd")
const Scope = preload("res://scripts/rules/skill_scope.gd")
const Contracts=preload("res://scripts/rules/hero_contract_pool.gd")
static func card_ids() -> Array:
	return MetaProgress.skill_draw_candidates().map(func(row): return str(row.id))

static func preview_ids() -> Array:
	var ids:Array=MetaProgress.skill_draw_candidates().map(func(row): return str(row.id))
	for contract in Contracts.entries():
		for id in contract.cards:
			if id not in HeroDemo.TABS and not ids.has(id):ids.append(id)
	return ids

var ids:Array = []
var cards: Array[Dictionary] = []
var refit_unit:=""
var return_label:=""
var selected := 0
var rank := 0
var stage: Control
var actor_view: TextureRect
var summary: Label
var values: Label
var pause: Button
var levels: OptionButton
var playback:Control
var picker:OptionButton
var mirror_ending:OptionButton
var picker_indices:Array=[]

func add_picker_card(id:String,label:String) -> void:
	picker.add_icon_item(preload("res://scripts/ui/progression_icon.gd").texture(id),label)
	var item:=picker.item_count-1
	picker.get_popup().set_item_icon_max_width(item,28)
	picker.set_item_metadata(item,id)
	var index:=ids.find(id)
	if index>=0:picker_indices[index]=item

func build_picker() -> void:
	picker.clear()
	picker_indices.resize(ids.size());picker_indices.fill(-1)
	var hero_cards:Array=[]
	for contract in Contracts.entries():
		for id in contract.cards:
			if not hero_cards.has(id):hero_cards.append(id)
	for i in ids.size():
		if ids[i] in hero_cards:continue
		var card:Dictionary=cards[i]
		add_picker_card(ids[i],"%s　%s　·　%s"%[card.group,card.slot,NewContent.card_name(ids[i])])
	for contract in Contracts.entries():
		picker.add_separator("英雄 · "+str(contract.name).trim_suffix("契约"))
		if contract.id in HeroDemo.TABS:add_picker_card(contract.id,"英雄　%s · 双技能联动"%contract.name)
		for id in contract.cards:
			var card:=GameData.get_skill(id)
			if card.is_empty():continue
			add_picker_card(id,"英雄　%s · %s"%["W" if card.type=="active" else "被动",card.name])

static func value(card: Dictionary, level: int) -> float:
	if card.has("objective_by_rank"): return float(card.objective_by_rank[level])
	var result:=float(card.base) * MetaProgress.Academy.card_strength(level,card)
	if card.get("effect","") in ["defense_buff","passive_armor"]: result=result/(1.0+result/100.0)
	return result

static func amount(card: Dictionary, level: int) -> String:
	if card.has("objective_by_rank"): return "%d 次" % int(value(card,level))
	return String.num(value(card,level),2) + str(card.suffix)

func _ready() -> void:
	Events.meta_changed.connect(_refresh_new_marks)
	color = Color("#101923f5")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	column.add_child(UiKit.make_label("技能卡演示",23,UiKit.COL_ACCENT_2))
	picker = OptionButton.new()
	picker.add_theme_constant_override("icon_max_width",28)
	ids=preview_ids()
	for id in ids:
		var row := GameData.get_skill(id)
		var seconds: bool = id == "ap_buoy"
		var allowed:Array=row.get("allowed_units",[])
		var model:String=str(allowed[0]) if not allowed.is_empty() else ("MTNK" if "vehicle" in row.get("allowed_categories",[]) else "E1")
		model=str(row.get("demo_model",model))
		cards.append({"rarity":{"common":"普通","rare":"稀有","epic":"史诗","legend":"传说","ultimate":"究极传说"}.get(row.rarity,row.rarity),"name":row.name,"group":row.get("group","分类通用"),"slot":"W" if row.type=="active" else "被动","model":model,"units":row.get("units",Scope.description(row)),"base":row.get("value",0.0) if seconds else row.get("value",0.0)*100,"suffix":" 秒" if seconds else "%","stat":row.get("stat","效果强度"),"effect":row.effect})
		if row.has("objective_by_rank"):
			cards.back().objective_by_rank=row.objective_by_rank
			cards.back().suffix=" 次"
		if row.has("strength_by_rank"): cards.back().strength_by_rank=row.strength_by_rank
	build_picker()
	picker.select(picker_indices[selected])
	picker.visible=refit_unit.is_empty()
	column.add_child(picker)
	var gallery := HBoxContainer.new()
	column.add_child(gallery)
	actor_view = preload("res://scripts/ui/unit_showcase.gd").new()
	actor_view.custom_minimum_size = Vector2(240,160)
	gallery.add_child(actor_view)
	if GameData.building_index.has(refit_unit):
		actor_view.hide()
		var structure:=TextureRect.new()
		structure.custom_minimum_size=actor_view.custom_minimum_size
		structure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		structure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var art:=RA2Art.art(refit_unit)
		var region:=AtlasTexture.new()
		region.atlas=art.get("tex")
		region.region=RA2Art.src_rect(art,0)
		structure.texture=region
		gallery.add_child(structure)
	stage = Stage.new()
	stage.custom_minimum_size = Vector2(260,170)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.add_child(stage)
	summary = UiKit.make_label("",16,UiKit.COL_TEXT)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	values = UiKit.make_label("",16,UiKit.COL_GOLD)
	values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(values)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	levels = UiKit.make_option(["0 级","1 级","2 级","3 级"],0,16)
	toolbar.add_child(levels)
	mirror_ending=UiKit.make_option(["再次 W 转移并引爆","被击毁爆炸","持续时间结束爆炸"])
	mirror_ending.name="MirrorEnding"
	toolbar.add_child(mirror_ending)
	mirror_ending.item_selected.connect(select_mirror_ending)
	pause = UiKit.make_button("暂停")
	toolbar.add_child(pause)
	var replay := UiKit.make_button("重播")
	toolbar.add_child(replay)
	playback=preload("res://scripts/ui/demo_playback.gd").new();column.add_child(playback)
	playback.bind(stage,&"elapsed",func():return stage.duration,stage.queue_redraw,pause)
	var close := UiKit.make_button("返回卡池" if refit_unit.is_empty() else "返回单位改造")
	if not return_label.is_empty():close.text=return_label
	toolbar.add_child(close)
	close.pressed.connect(queue_free)
	picker.item_selected.connect(_select_gallery_entry)
	levels.item_selected.connect(select_rank)
	pause.pressed.connect(func():
		stage.playing = not stage.playing
		pause.text = "暂停" if stage.playing else "继续")
	replay.pressed.connect(func(): select_card(selected,rank))
	select_card(selected,rank)
	close.grab_focus()

func _select_gallery_entry(index:int) -> void:
	if index<0 or index>=picker.item_count or picker.get_popup().is_item_separator(index):return
	var id=picker.get_item_metadata(index)
	var card_index:=ids.find(id)
	if card_index>=0:
		select_card(card_index,rank)
		return
	picker.select(picker_indices[selected])
	if not id in HeroDemo.TABS or has_node("HeroDemo"):return
	var previous_playing:bool=stage.playing
	stage.playing=false
	var demo:=HeroDemo.new()
	demo.name="HeroDemo"
	demo.entry=id
	demo.return_text="返回技能卡演示"
	demo.tree_exiting.connect(func():stage.playing=previous_playing;playback.sync();picker.grab_focus())
	add_child(demo)

func select_mirror_ending(ending:int) -> void:
	stage.mirror_ending=ending
	select_card(selected,rank)

func select_rank(level:int) -> void:
	var position:float=stage.elapsed
	var was_playing:bool=stage.playing
	var optional_hit:bool=stage.show_optional_hit
	select_card(selected,level)
	stage.show_optional_hit=optional_hit
	playback.restore_position(position,was_playing)

func select_card(index: int, level: int) -> void:
	selected = index
	mirror_ending.visible=ids[index]=="ap_mirror_fork"
	picker.select(picker_indices[index])
	rank = level
	var card: Dictionary = cards[index]
	var model:String=refit_unit if not refit_unit.is_empty() else card.model
	if actor_view.visible and actor_view.unit_id!=model: actor_view.show_unit(model)
	levels.select(level)
	var definition:=GameData.get_skill(ids[index])
	var rarity_color:=Scope.rarity_color(definition)
	summary.add_theme_color_override("font_color",rarity_color)
	values.add_theme_color_override("font_color",rarity_color)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:picker.add_theme_color_override(state,rarity_color)
	summary.text = "%s　｜　%s\n%s" % [NewContent.card_name(ids[index])+" · "+card.rarity,card.units,MetaProgress.Academy.skill_description(definition,level)]
	var steps := PackedStringArray()
	for i in 4:
		var step:="%d 级  %s" % [i,amount(card,i)]
		if ids[index]=="ap_tesla_chain":step="%d 级 主伤害 +%s%% · 分支 %s%%" % [i,MetaProgress.Academy.skill_number(definition.primary_bonus_by_rank[i]*100),MetaProgress.Academy.skill_number(definition.branch_by_rank[i]*100)]
		if definition.has("cooldown_by_rank"): step+=" · 冷却 %s 秒" % Ability.cooldown_text(Ability.cooldown_at_rank(definition,i))
		if ids[index]=="ap_slope": step+=" · 加速 %d%%" % roundi(Unit.FactionCards.slope_speed(i)*100)
		if ids[index]=="ap_twin": step+=" · "+Unit.FactionCards.twin_summary(i)
		if ids[index]=="ps_contact": step+=" · 视野 %s 秒 · 冷却 %d 秒" % [String.num(Unit.FactionCards.contact_seconds(i),1),Unit.FactionCards.contact_cooldown(i)]
		if definition.get("expansion",false):step=MetaProgress.Academy.skill_description(definition,i)
		if preload("res://scripts/ui/pool_research_demo.gd").supports(ids[index]):step="%d 级　%s"%[i,preload("res://scripts/ui/pool_research_demo.gd").result(ids[index],i)]
		steps.append(step)
	values.text = "\n".join(steps) if definition.get("expansion",false) or preload("res://scripts/ui/pool_research_demo.gd").supports(ids[index]) else "%s　｜　%s" % [card.stat,"　→　".join(steps)]
	stage.configure(ids[index],value(card,level),amount(card,level),level)
	pause.text = "暂停"
	playback.sync()

func _refresh_new_marks() -> void:
	if ids.is_empty() or summary==null:return
	build_picker();picker.select(picker_indices[selected])
	var card:Dictionary=cards[selected]
	summary.text="%s　｜　%s\n%s"%[NewContent.card_name(ids[selected])+" · "+card.rarity,card.units,MetaProgress.Academy.skill_description(GameData.get_skill(ids[selected]),rank)]
