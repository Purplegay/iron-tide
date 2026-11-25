extends Control
## Player cosmetics are stored per unit; team colours are chosen in the menus.
const NightShift=preload("res://scripts/units/night_shift.gd")
const Styles=preload("res://scripts/units/unit_cosmetics.gd")
const Showcase=preload("res://scripts/ui/unit_showcase.gd")
const EXCLUSIVE_SKINS = MetaProgress.Cosmetics.EXCLUSIVE_SKINS
var exclusive_only: CheckBox
var series: OptionButton
var units: OptionButton
var slots: VBoxContainer
var preview
var view_hint:Label
var wallet: Label
var status: Label
var unit_id := ""
var initial_unit := ""
var return_to_refit := false
var back_button: Button
const SERIES_KEYS := ["ra3", "yr_units", "yr_buildings"]
var bookmarks = preload("res://scripts/ui/progression_bookmarks.gd").new()
class TreadStrip extends Control:
	var tread:Texture2D
	var phase:=0.0
	var sample: Showcase.TrackSample
	func _process(_delta:float) -> void:
		phase = sample.phase * 16.0 / VehicleTracks.STEP
		queue_redraw()
	func _draw() -> void:
		if tread==null:return
		draw_rect(Rect2(Vector2.ZERO,size),UiKit.COL_PANEL_2)
		for row in [-1,1]:
			for col in range(ceili(size.x/16)+1):
				var center:=Vector2(col*16-phase,size.y*(0.5+row*0.21))
				draw_texture_rect(tread,Rect2(center-Vector2(8,7),Vector2(16,14)),false)

var tread_strip:TreadStrip
var tread_button:Button
var structure_trial := ""
var structure: TextureRect
var fx_strip: Control
var fx_host: Node2D
var fx_button: Button
var preview_shot := 0
var workshop: ScrollContainer

func _ready() -> void:
	var bg:=ColorRect.new()
	bg.color=Color("#101720")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll:=ScrollContainer.new()
	workshop=scroll
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new()
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel=UiKit.make_panel(UiKit.COL_PANEL,UiKit.COL_LINE)
	panel.custom_minimum_size.x=580
	center.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	panel.add_child(column)
	column.add_child(UiKit.make_label("涂装工房",28,UiKit.COL_ACCENT_2))
	column.add_child(UiKit.make_label("每个兵种单独装配，阵营色在主菜单或开战菜单选择。",14,UiKit.COL_DIM))
	wallet=UiKit.make_label("",14,UiKit.COL_GOLD)
	column.add_child(wallet)
	var row:=HBoxContainer.new()
	column.add_child(row)
	series=UiKit.make_option(["红警 3 · 配件装配","尤里的复仇 · 单位","尤里的复仇 · 建筑"],0,15)
	row.add_child(series)
	units=OptionButton.new()
	units.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(units)
	exclusive_only=CheckBox.new()
	exclusive_only.text="仅看有专属外观"
	exclusive_only.tooltip_text="列出可装配专属皮肤、挂件或武器特效的单位与建筑。"
	row.add_child(exclusive_only)
	exclusive_only.toggled.connect(func(_enabled:bool):_list_units())
	series.item_selected.connect(_change_series)
	units.item_selected.connect(func(i):_select_unit(str(units.get_item_metadata(i))))
	preview=Showcase.new()
	preview.workshop_view=true
	column.add_child(preview)
	view_hint=UiKit.make_label("左键点击暂停 · 按住左右拖动看朝向 · 静置 5 秒归位",12,UiKit.COL_DIM)
	view_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(view_hint)
	structure=TextureRect.new()
	structure.custom_minimum_size.y=146
	structure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	structure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(structure)
	structure.draw.connect(_draw_ramp_preview)
	slots=VBoxContainer.new()
	column.add_child(slots)
	status=UiKit.make_label("",13,UiKit.COL_DIM)
	column.add_child(status)
	var stats_button=UiKit.make_button("查看建造统计")
	column.add_child(stats_button)
	var report=UiKit.make_label("",14,UiKit.COL_TEXT)
	column.add_child(report)
	report.hide()
	stats_button.pressed.connect(func():
		report.visible=not report.visible
		if report.visible:report.text=preload("res://scripts/world/production_counts.gd").summary()
		stats_button.text="收起建造统计" if report.visible else "查看建造统计")
	var back=UiKit.make_button("返回单位改造" if return_to_refit else "返回主菜单")
	back_button=back
	back.pressed.connect(func():
		if return_to_refit: queue_free()
		else: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	column.add_child(back)
	var saved_series:=SERIES_KEYS.find(bookmarks.get_value("paint_series","ra3"))
	series.select(maxi(0,saved_series))
	exclusive_only.set_pressed_no_signal(bookmarks.get_value("paint_exclusive",false)==true)
	if not initial_unit.is_empty() and not GameData.get_unit(initial_unit).is_empty():
		series.select(0 if Styles.is_ra3(GameData.get_unit(initial_unit)) else 1)
		unit_id=initial_unit
		if not _has_exclusive(initial_unit): exclusive_only.set_pressed_no_signal(false)
		# A direct link starts at the model and equipment rather than an old scroll offset.
		bookmarks.config.set_value("scroll","paint/"+SERIES_KEYS[series.selected]+"/"+initial_unit,0)
		_list_units()
	else:
		_change_series(series.selected)

func _change_series(_index:int) -> void:
	unit_id=str(bookmarks.get_value("paint_unit/"+SERIES_KEYS[series.selected],""))
	_list_units()

func _remember_selection() -> void:
	bookmarks.set_value("paint_series",SERIES_KEYS[series.selected])
	bookmarks.set_value("paint_exclusive",exclusive_only.button_pressed)
	if not unit_id.is_empty():
		bookmarks.set_value("paint_unit/"+SERIES_KEYS[series.selected],unit_id)
	bookmarks.save()

func _exit_tree() -> void:
	bookmarks.remember(workshop,true)
	bookmarks.save()

func _list_units() -> void:
	units.clear()
	if series.selected==2:
		for id in ["TESLA","NABNKR","NAFLAK","NAREFN"]:
			_add_candidate(GameData.get_building(id))
	else:
		for data:Dictionary in GameData.units:
			if Styles.is_ra3(data)!=(series.selected==0):continue
			if series.selected==1 and (not data.get("ra2",false) or not GameData.unit_in_production_catalog(data.id)):continue
			_add_candidate(data)
		# Explicit refit links also support units absent from the normal production catalog.
		if not initial_unit.is_empty():
			var requested:=GameData.get_unit(initial_unit)
			if not requested.is_empty() and Styles.is_ra3(requested)==(series.selected==0):
				var present:=false
				for i in units.item_count:
					if units.get_item_metadata(i)==initial_unit: present=true
				if not present: _add_candidate(requested)
	units.disabled=units.item_count==0
	if units.disabled:
		_select_unit("")
		return
	var index:=0
	for i in units.item_count:
		if units.get_item_metadata(i)==unit_id:
			index=i
			break
	units.select(index)
	_select_unit(str(units.get_item_metadata(index)))

func _has_exclusive(id:String) -> bool:
	return EXCLUSIVE_SKINS.has(id) or Styles.EXCLUSIVE_MOUNTS.has(id) or Effects.Looks.CHOICES.has(id)

func _add_candidate(data:Dictionary) -> void:
	var id:String=data.id
	if exclusive_only.button_pressed and not _has_exclusive(id):return
	units.add_item(str(data.name))
	units.set_item_metadata(units.item_count-1,id)

func _select_unit(id:String) -> void:
	bookmarks.remember(workshop)
	unit_id=id
	_remember_selection()
	if tread_strip != null: _set_tread_preview(false)
	tread_strip=null
	tread_button=null
	structure_trial=""
	wallet.text="钻石　%d　·　皮肤券　%d　·　外观累计胜场　%d"%[MetaProgress.balance("diamonds"),MetaProgress.academy.get("skin_ticket",0),MetaProgress.appearance_wins()]
	preview_shot=0
	fx_button=null
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	if id.is_empty():
		preview.hide()
		structure.hide()
		view_hint.hide()
		set_process(false)
		status.text="当前分类暂无符合条件的外观。"
		bookmarks.restore(workshop,"paint/empty")
		return
	if series.selected==0:
		_slot("整机涂装","paint",Styles.PAINT)
		_slot("顶部装饰","top",Styles.TOP)
		_slot("悬浮挂件","wing",Styles.WINGS)
		_slot("尾部挂件","tail",Styles.TAILS)
		if VehicleTracks.supports_tire_skin(id):
			_slot("轮胎印","track",Styles.TRACKS)
			tread_strip=TreadStrip.new()
			tread_strip.sample=preview.track_sample
			tread_strip.custom_minimum_size.y=44
			tread_strip.clip_contents=true
			tread_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
			slots.add_child(tread_strip)
			tread_strip.hide()
			tread_strip.set_process(false)
	elif series.selected==1 or id=="NAREFN":
		var skins:Dictionary=Styles.SKINS.duplicate() if series.selected==1 else {"stock":"原版"}
		if EXCLUSIVE_SKINS.has(id):
			var exclusive:String=EXCLUSIVE_SKINS[id]
			skins[exclusive]=MetaProgress.Cosmetics.display_name(exclusive)
		_slot("整套皮肤","skin",skins)
	if Effects.Looks.CHOICES.has(id):
		var look:String=Effects.Looks.CHOICES[id]
		var choices:={"stock":"原版"}
		choices[look]=Effects.Looks.NAMES[look]
		_slot("武器特效","weapon_fx",choices)
		var row:=HBoxContainer.new()
		slots.add_child(row)
		fx_button=UiKit.make_button("试放特效")
		fx_button.disabled=MetaProgress.cosmetic_style(id).get("weapon_fx","stock")=="stock"
		fx_button.pressed.connect(_sample)
		row.add_child(fx_button)
		fx_strip=Control.new()
		fx_strip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		fx_strip.custom_minimum_size=Vector2(200,88 if look in ["love_peace",Effects.Looks.BlueArc.ID] else 55)
		if look in ["molten_duet","reentry","time_fracture","duplex"]:fx_strip.custom_minimum_size.y=106
		if look==Effects.Looks.Sonar.ID:fx_strip.custom_minimum_size.y=106
		fx_strip.clip_contents=true
		row.add_child(fx_strip)
		if look==Effects.Looks.BlueArc.ID:
			fx_strip.custom_minimum_size.y=154
			var terrain:=TextureRect.new()
			terrain.texture=preload("res://assets/ra3/terrain/grass.png")
			terrain.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			terrain.stretch_mode=TextureRect.STRETCH_TILE
			terrain.mouse_filter=Control.MOUSE_FILTER_IGNORE
			fx_strip.add_child(terrain)
			terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fx_host=Node2D.new()
		fx_strip.add_child(fx_host)
		fx_host.transform=Transform2D(Iso.eff_angle(),Iso.up(),0,Vector2.ZERO).affine_inverse()
	status.text="外观设置随兵种保存，进入战斗时生效。"
	structure.visible=series.selected==2
	preview.visible=not structure.visible
	view_hint.visible=preview.visible
	if structure.visible:
		var art:=RA2Art.art(id)
		var region:=AtlasTexture.new()
		region.atlas=art.get("tex")
		region.region=RA2Art.src_rect(art,0)
		structure.texture=region
		_update_structure_skin()
	else:
		set_process(false)
		preview.show_unit(id)
	bookmarks.restore(workshop,"paint/"+SERIES_KEYS[series.selected]+"/"+id)

func _structure_skin() -> String:
	return structure_trial if not structure_trial.is_empty() else MetaProgress.cosmetic_style(unit_id).get("skin","stock")

func _try_outfit(key:String,value:String) -> void:
	if structure.visible:
		structure_trial=value
		_update_structure_skin()
	else:
		preview.try_outfit(key,value)
		if key == "track": _set_tread_preview(false)

func _set_tread_preview(enabled: bool) -> void:
	preview.set_track_preview(enabled)
	tread_strip.tread = preview.track_sample.tread
	tread_strip.visible = preview.track_sample.visible
	tread_strip.phase = 0.0
	tread_strip.set_process(tread_strip.visible)
	tread_strip.queue_redraw()
	tread_button.text = "结束预览" if tread_strip.visible else "预览轮胎印"

func _update_structure_skin() -> void:
	var styled:bool=unit_id=="NAREFN" and _structure_skin()==NightShift.ID
	structure.material=HouseColor.material_for(HouseColor.player_color(),HouseColor.PaintMode.NONE,3 if styled else 0)
	set_process(styled and structure.visible)
	structure.queue_redraw()

func _process(_delta:float) -> void:
	if structure.visible:structure.queue_redraw()

func _draw_ramp_preview() -> void:
	if unit_id!="NAREFN" or structure.texture==null or _structure_skin()!=NightShift.ID:return
	var frame:=structure.texture.get_size()
	var scale_factor:=minf(structure.size.x/frame.x,structure.size.y/frame.y)
	NightShift.ramp(structure,(structure.size-frame*scale_factor)/2,scale_factor,1.0-fposmod(Time.get_ticks_msec()/3000.0,1.0))

func _sample() -> void:
	var picker:OptionButton=slots.find_child("weapon_fx",true,false)
	var look:String=picker.get_item_metadata(picker.selected)
	if look=="stock":return
	for child in fx_host.get_children():child.free()
	preview_shot+=1
	var at:=Vector2(fx_strip.size.x*0.62,fx_strip.size.y*0.5)
	if look in ["molten_duet","time_fracture","reentry"]:
		var center:=fx_host.to_local(fx_strip.get_global_transform()*at)
		match look:
			"molten_duet":
				Effects.Looks.Signature.spawn(fx_host,center,"molten_red")
				Effects.Looks.Signature.spawn(fx_host,center,"molten_gold",0.12)
			"time_fracture":Effects.Looks.Signature.spawn(fx_host,center,"chrono_sample")
			"reentry":Effects.Looks.Signature.spawn(fx_host,center,"meteor_sample")
	elif look==Effects.Looks.Sonar.ID:
		var origin:=fx_strip.get_global_transform()
		var muzzle:=fx_host.to_local(origin*(at-Vector2(75,0)))
		var hit:=fx_host.to_local(origin*at)
		Effects.Looks.Sonar.spawn(fx_host,muzzle,true,hit-muzzle,0,hit-muzzle)
		Effects.Looks.Sonar.spawn(fx_host,hit,false,Vector2.RIGHT,0.35)
	elif look==Effects.Looks.BlueArc.ID:
		var origin:=fx_strip.get_global_transform()
		Effects.Looks.BlueArc.spawn(fx_host,fx_host.to_local(origin*(at-Vector2(107,0))),true,Iso.eff_angle())
		Effects.Looks.BlueArc.spawn(fx_host,fx_host.to_local(origin*at),false,0.0,0.09)
	elif look in ["duplex","spectrum"]:
		var kind:="yr_bolt" if look=="spectrum" else "laser"
		if look=="duplex":look="prism_red" if preview_shot%2==0 else "prism_blue"
		var origin:=fx_strip.get_global_transform()
		Effects.spawn_beam(origin*(at-Vector2(110,0)),origin*at,Color.WHITE,kind,2.6,0.45,look,fx_host)
		if look in ["prism_blue","prism_red"]:
			for offset in [Vector2(43,-20),Vector2(38,22)]:
				Effects.spawn_beam(origin*at,origin*(at+offset),Color.WHITE,kind,2.2,0.36,look,fx_host,true)
	else:Effects.Looks.impact(fx_host,fx_host.to_local(fx_strip.get_global_transform()*at),look)

func _mount_controls(row:HBoxContainer,key:String) -> Button:
	var button := UiKit.make_button("调整挂件",14)
	button.tooltip_text="调整位置、三轴旋转、整体缩放和分轴拉伸；支持圆环拖动与快捷键。"
	button.name = "Adjust_"+key
	row.add_child(button)
	button.pressed.connect(_open_mount_editor.bind(key,button))
	return button

func _open_mount_editor(key:String, button:Button) -> void:
	if button.disabled or has_node("MountEditor"): return
	var model:Ra3UnitModel=preview.actor._ra3_model
	if model==null:
		status.text="当前预览无法加载 3D 模型。"
		return
	preview.actor.velocity=Vector2.ZERO
	preview.edit_mount=key
	preview.refresh_outfit()
	workshop.hide()
	var editor=preload("res://scripts/ui/mount_position_editor.gd").new()
	editor.name="MountEditor"
	add_child(editor)
	editor.open(model,unit_id,key)
	editor.closed.connect(func(saved:bool):
		remove_child(editor)
		editor.queue_free()
		preview.edit_mount=""
		preview.refresh_outfit()
		workshop.show()
		button.grab_focus()
		if saved: status.text="挂件位置、旋转与尺寸已保存。")

func _slot(label:String,key:String,options:Dictionary) -> void:
	if key in ["top","tail"]:
		options=options.duplicate()
		for value in options.keys():
			if not MetaProgress.Cosmetics.available(unit_id,key,value):options.erase(value)
	var row:=HBoxContainer.new()
	slots.add_child(row)
	var caption=UiKit.make_label(label,15,UiKit.COL_TEXT)
	caption.custom_minimum_size.x=110
	row.add_child(caption)
	var picker:=OptionButton.new()
	picker.name=key
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	var adjust:Button=_mount_controls(row,key) if key in Styles.MOUNT_SLOTS else null
	var details := UiKit.make_label("",14,UiKit.COL_TEXT)
	details.name = "EffectText_"+key
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slots.add_child(details)
	var describe := func(value:String):
		if adjust!=null:
			adjust.disabled=value=="stock" or not MetaProgress.cosmetic_owned(value)
			adjust.tooltip_text="请先装配"+label if adjust.disabled else "调整"+label+"的位置"
		var description := MetaProgress.Cosmetics.effect_text(unit_id,key,value)
		picker.tooltip_text = description
		details.text = description
		details.visible = value!="stock" or key in ["skin","weapon_fx","paint","track"]
	var saved:String=MetaProgress.cosmetic_style(unit_id).get(key,"stock")
	var buy=UiKit.make_button("购买并装配",14)
	buy.name="Buy_"+key
	row.add_child(buy)
	buy.hide()
	if key == "track":
		tread_button = UiKit.make_button("预览轮胎印",14)
		tread_button.name = "Preview_track"
		row.add_child(tread_button)
		tread_button.pressed.connect(func(): _set_tread_preview(not tread_strip.visible))
	for value:String in options:
		var text:String=options[value]
		if not MetaProgress.cosmetic_owned(value):
			var wins:=MetaProgress.Cosmetics.wins_required(value)
			var research:=MetaProgress.Cosmetics.research_required(value)
			if research>0:text+=" · 累计研究 %d 项科技"%research
			elif wins>0:text+=" · %d 胜"%wins
			elif MetaProgress.Cosmetics.win_reward_only(unit_id,value):text+=" · 胜场奖励待开放"
			elif MetaProgress.Cosmetics.victory_tier(value)>0:text+=" · "+MetaProgress.Cosmetics.requirement(value)
			else:text+=" · %d 钻石"%MetaProgress.Cosmetics.price(key)
		picker.add_item(text)
		picker.set_item_metadata(picker.item_count-1,value)
		picker.get_popup().set_item_tooltip(picker.item_count-1,MetaProgress.Cosmetics.effect_text(unit_id,key,value))
		if value==saved:picker.select(picker.item_count-1)
	describe.call(picker.get_item_metadata(picker.selected))
	buy.pressed.connect(func():
		var value:String=picker.get_item_metadata(picker.selected)
		if not MetaProgress.buy_cosmetic(unit_id,key,value):
			status.text="购买未成功，请检查余额或存档。"
			return
		_select_unit(unit_id)
		status.text="已购买并装配「%s」，所有适用单位共享同名外观。"%options[value])
	picker.item_selected.connect(func(i):
		var value:String=picker.get_item_metadata(i)
		describe.call(value)
		var owned:=MetaProgress.cosmetic_owned(value)
		var wins:=MetaProgress.Cosmetics.wins_required(value)
		var award:=MetaProgress.Cosmetics.victory_tier(value)>0
		var wins_only:=MetaProgress.Cosmetics.win_reward_only(unit_id,value)
		buy.visible=not owned and not award and not wins_only
		var ticket := key in ["skin","weapon_fx"] and int(MetaProgress.academy.get("skin_ticket",0)) > 0
		buy.disabled=not ticket and MetaProgress.balance("diamonds")<MetaProgress.Cosmetics.price(key)
		buy.text = "使用皮肤券并装配" if ticket else "购买并装配"
		if not owned:
			var research:=MetaProgress.Cosmetics.research_required(value)
			if research>0:
				status.text="累计研究 %d 项科技解锁「%s」，当前已研究 %d 项。"%[research,options[value],MetaProgress.researched_count()]
			elif wins>0:
				status.text="累计 %d 胜免费解锁「%s」，还差 %d 胜。"%[wins,options[value],maxi(0,wins-MetaProgress.appearance_wins())]
			elif wins_only:
				status.text="这项胜场奖励尚未开放。"
			elif award:
				status.text=MetaProgress.Cosmetics.requirement(value)+"后免费解锁。"
			else:
				var message:="余额不足，需 %d 钻石。" if buy.disabled else "购买并装配需 %d 钻石，同名外观仅付费一次。"
				status.text="将使用 1 张皮肤券。" if ticket else message%MetaProgress.Cosmetics.price(key)
			if key!="weapon_fx":
				_try_outfit(key,value)
				status.text="预览中 · "+status.text
			if key=="weapon_fx":
				fx_button.disabled=false
				_sample()
			return
		if MetaProgress.set_cosmetic(unit_id,key,value):
			status.text="%s · %s已保存" % [units.get_item_text(units.selected),label]
			if key=="weapon_fx":
				fx_button.disabled=value=="stock"
				for child in fx_host.get_children():child.free()
				if not fx_button.disabled:_sample()
			else:_try_outfit(key,value)
		else:
			picker.select(maxi(0,options.keys().find(MetaProgress.cosmetic_style(unit_id).get(key,"stock"))))
			describe.call(picker.get_item_metadata(picker.selected))
			status.text="外观未保存，请检查本地存档。")
