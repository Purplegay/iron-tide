extends PanelContainer
const Army=preload("res://scripts/expedition/army.gd")
const Glyph=preload("res://scripts/ui/progression_icon.gd")
signal tracking_requested

func setup(key:String,run:Dictionary) -> void:
	var count:=clampi(int(run.get("trait_buffs",{}).get(key,0)),0,9)
	var tracked:bool=key in run.get("tracked_traits",[])
	set_meta("trait_key",key)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel",UiKit.panel_style(UiKit.COL_PANEL,UiKit.COL_GOLD if tracked else UiKit.COL_LINE))
	tooltip_text=details(key,run,count)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(box)
	var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(line)
	var image:=TextureRect.new();image.texture=Glyph.texture(str(Army.TRAITS[key].icon))
	image.custom_minimum_size=Vector2(22,22);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical=Control.SIZE_SHRINK_CENTER;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(image)
	var title:=UiKit.make_label("%s  %d / 9 层"%[Army.TRAITS[key].name,count],15,UiKit.COL_ACCENT_2)
	title.name="TraitTitle";title.custom_minimum_size.x=150;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(title)
	if run.get("phase","")=="ready":
		var mark:=UiKit.make_button("已标记" if tracked else "标记",13)
		mark.name="TrackButton";mark.custom_minimum_size.y=26;mark.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		mark.tooltip_text="取消此构筑方向标记" if tracked else "标记构筑方向，仅影响奖励候选；最多标记两项，不改变受益兵种。"
		mark.pressed.connect(tracking_requested.emit);line.add_child(mark)
	var progress:=UiKit.ra_progress(UiKit.COL_OK if count==9 else UiKit.COL_GOLD)
	progress.name="LayerProgress";progress.max_value=9;progress.value=count;progress.custom_minimum_size.y=7
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(progress)
	var hint:=UiKit.make_label(next_milestone(count),12,UiKit.COL_DIM)
	hint.name="MilestoneHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(hint)

static func next_milestone(count:int) -> String:
	if count>=9:return "9 层终局已解锁"
	var target:=3 if count<3 else 6 if count<6 else 9
	return "距 %d 层%s还差 %d 层"%[target,"前期" if target==3 else "中期" if target==6 else "终局",target-count]

static func details(key:String,run:Dictionary,count:int) -> String:
	var data:Dictionary=Army.TRAITS[key]
	var text:="%s · %d / 9 层\n%s\n\n当前收益：%s"%[data.name,count,Army.trait_audience(key,run),Army.trait_detail(key,count)]
	if count<9:text+="\n\n下一层基础收益："+Army.Progress.summary(key,count+1)
	if count<3:text+="\n\n3 层前期（未解锁）："+str(Army.Progress.OPENINGS[key])
	if count<6:text+="\n\n6 层中期（未解锁）："+str(data.desc[3])
	if count<9:text+="\n\n9 层终局（未解锁）："+str(data.desc[4])
	return text+"\n\n搭配建议　"+str(Army.Progress.BUILDS[key])+"\n每次获得同类加成都叠加 1 层，部队自动受益。"

func _make_custom_tooltip(for_text:String) -> Object:
	var panel:=UiKit.make_panel(Color(0.04,0.07,0.10,0.98),UiKit.COL_ACCENT_2,6,1,10)
	var text:=UiKit.make_label(for_text,13)
	text.custom_minimum_size.x=minf(500,maxf(260,get_viewport_rect().size.x-48))
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)
	return panel
