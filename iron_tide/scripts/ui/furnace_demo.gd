extends ColorRect

const Cards = preload("res://scripts/units/furnace_legend.gd")
const Stage = preload("res://scripts/ui/furnace_demo_stage.gd")
const Playback = preload("res://scripts/ui/demo_playback.gd")
const TABS := ["furnace_contract", Cards.ACTIVE, Cards.PASSIVE]
const LEVELS := ["0 级", "1 级", "2 级", "3 级"]
var entry := "furnace_contract"
var badge:=TextureRect.new()
var return_text := "返回卡池"
var stage := Stage.new()
var playback := Playback.new()
var selects: Array[Button] = []
var w_options := HBoxContainer.new()
var p_options := HBoxContainer.new()
var summary := Label.new()

func _ready() -> void:
	color = Color("#14171bf9")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	badge.custom_minimum_size=Vector2(40,40)
	badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	header.add_child(badge)
	preload("res://scripts/ui/furnace_contract_panel.gd").shine(badge)
	var title := UiKit.make_label("炉火契约 · 技能演示",22,Color("#ffe397"))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var back := UiKit.make_button(return_text)
	back.name = "Back"
	back.pressed.connect(queue_free)
	header.add_child(back)
	var tabs := HFlowContainer.new()
	column.add_child(tabs)
	for id in TABS:
		var label := "双技能联动" if id == TABS[0] else ("W · " if id == Cards.ACTIVE else "被动 · ") + str(GameData.get_skill(id).name)
		var button := UiKit.make_button(label)
		button.icon = preload("res://scripts/ui/progression_icon.gd").texture(id)
		button.add_theme_constant_override("icon_max_width",28)
		button.pressed.connect(select_mode.bind(id))
		selects.append(button)
		tabs.add_child(button)
	var settings := HFlowContainer.new()
	column.add_child(settings)
	settings.add_child(w_options)
	settings.add_child(p_options)
	for id in [Cards.ACTIVE,Cards.PASSIVE]:
		var box := w_options if id == Cards.ACTIVE else p_options
		var rank := MetaProgress.Academy.card_rank(MetaProgress,id)
		box.add_child(UiKit.make_label("W" if id==Cards.ACTIVE else "被动"))
		var picker := UiKit.make_option(LEVELS,rank)
		box.add_child(picker)
		picker.item_selected.connect(set_rank.bind(id))
		set_rank(rank,id)
	var ending := UiKit.make_option(["受击破盾","带盾起身","自然消盾"])
	w_options.add_child(ending)
	ending.item_selected.connect(func(i): stage.ending=i; stage.queue_redraw())
	stage.custom_minimum_size = Vector2(0,260)
	column.add_child(stage)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	column.add_child(playback)
	playback.add_transport()
	playback.bind(stage,&"elapsed",func():return stage.LENGTH,stage.queue_redraw,playback.pause_button)
	select_mode(entry)
	back.grab_focus()

func select_mode(id: String) -> void:
	badge.texture=preload("res://scripts/ui/progression_icon.gd").texture(id)
	stage.mode=id
	for i in TABS.size(): selects[i].disabled = TABS[i]==id
	w_options.visible = id != Cards.PASSIVE
	p_options.visible = id != Cards.ACTIVE
	playback.seek(0)
	stage.playing=true
	playback.sync()
	refresh_summary()

func set_rank(rank:int,id:String) -> void:
	if id == Cards.ACTIVE: stage.w_rank=rank
	else: stage.p_rank=rank
	stage.queue_redraw()
	refresh_summary()

func refresh_summary() -> void:
	var lines := PackedStringArray()
	if stage.mode != Cards.PASSIVE: lines.append(MetaProgress.Academy.skill_description(GameData.get_skill(Cards.ACTIVE),stage.w_rank))
	if stage.mode != Cards.ACTIVE: lines.append(MetaProgress.Academy.skill_description(GameData.get_skill(Cards.PASSIVE),stage.p_rank))
	summary.text="\n".join(lines)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
