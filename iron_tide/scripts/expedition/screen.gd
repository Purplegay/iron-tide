extends Control
const Catalog=preload("res://scripts/expedition/catalog.gd")
const SchoolField=preload("res://scripts/expedition/yuriko_field.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Army=preload("res://scripts/expedition/army.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Glyph=preload("res://scripts/ui/progression_icon.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
const Relics=preload("res://scripts/expedition/relics.gd")
const Income=preload("res://scripts/expedition/income.gd")
const Attention=preload("res://scripts/expedition/attention.gd")
const Dot=preload("res://scripts/ui/attention_dot.gd")
var body:VBoxContainer
var scroll:ScrollContainer
const OPENING_PREFS := "user://expedition_opening.cfg"
var opening_prefs := ConfigFile.new()
var country_value:="美国"
var hero_value:=""
var keepsake_values:Array=[]
const Keepsakes=preload("res://scripts/expedition/commander_keepsakes.gd")
const GiftNotice=preload("res://scripts/expedition/keepsake_notice.gd")
var opening:Dictionary={}
var notice:Label
var budget:Label
var tab:=0
var selection_report_open:=false
var show_new:=false
var selected_unit:=""
var pending_action:Callable
var built_page:=""
var error_overlay:Label
var error_tween:Tween
const Insights=preload("res://scripts/expedition/insights.gd")
var equipment_open:=false
var army_filter:=0
var arrivals_open:=false

class CarriedKeepsakeRow extends HBoxContainer:
	func _make_custom_tooltip(for_text: String) -> Object:
		var panel := UiKit.make_panel(Color("#101a24"), UiKit.COL_GOLD, 5, 1, 12)
		var lines := VBoxContainer.new()
		panel.add_child(lines)
		lines.add_child(UiKit.make_label(for_text.get_slice("\n", 0), 16, UiKit.COL_GOLD))
		var details := UiKit.make_label(for_text.substr(for_text.find("\n") + 1), 14)
		details.custom_minimum_size.x = minf(420, get_viewport_rect().size.x - 48)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(details)
		return panel

func show_error(message:String) -> void:
	if is_instance_valid(notice):notice.text=message
	if not is_instance_valid(error_overlay):
		var layer:=CanvasLayer.new();layer.layer=100;add_child(layer)
		error_overlay=Label.new();error_overlay.name="CenterError"
		error_overlay.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		error_overlay.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		error_overlay.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		error_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
		error_overlay.add_theme_font_size_override("font_size",36)
		error_overlay.add_theme_color_override("font_color",Color("#ff5555"))
		error_overlay.add_theme_color_override("font_outline_color",Color("#101018"))
		error_overlay.add_theme_constant_override("outline_size",8)
		layer.add_child(error_overlay)
		error_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if error_tween!=null:error_tween.kill()
	error_overlay.text=message;error_overlay.modulate.a=1.0;error_overlay.show()
	error_tween=create_tween()
	error_tween.tween_interval(2.5)
	error_tween.tween_property(error_overlay,"modulate:a",0.0,0.4)
	error_tween.tween_callback(error_overlay.hide)

func _ready() -> void:
	MetaProgress.hero_portrait_changed.connect(build, CONNECT_DEFERRED)
	opening_prefs.load(OPENING_PREFS)
	country_value = str(opening_prefs.get_value("opening", "country", Expedition.state.get("country", "美国")))
	if country_value not in ["美国", "苏俄"]:
		country_value = "美国"
	restore_opening_hero()
	Expedition.flush_income()
	Music.set_context("camp")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	build()

func label(text:String,size:=16,color:=Color.WHITE) -> Label:
	var node:=UiKit.make_label(text,size,color)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return node

func button(parent:Node,text:String,action:Callable) -> Button:
	var node:=UiKit.make_button(text,15)
	node.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func row(parent:Node) -> HBoxContainer:
	var box:=HBoxContainer.new();box.add_theme_constant_override("separation",12);parent.add_child(box);return box

func cost_button(parent:Node,text:String,action:Callable,cost:int,available:=true) -> Button:
	var node:=button(parent,text,action)
	if cost>0:node.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("supplies")
	node.disabled=not available
	if available and int(Expedition.state.supplies)<cost:
		node.disabled=true
		node.tooltip_text="补给不足 · 还差 %d 补给"%(cost-int(Expedition.state.supplies))
		var style:StyleBoxFlat=node.get_theme_stylebox("normal").duplicate()
		style.bg_color=Color("#382025");style.border_color=Color("#c65b63")
		node.add_theme_stylebox_override("disabled",style)
		node.add_theme_color_override("font_disabled_color",Color("#ff8585"))
	return node

func grid(parent:Node,columns:=3,card_width:=340) -> GridContainer:
	var box:=GridContainer.new();box.columns=columns
	box.set_meta("max_columns",columns);box.set_meta("card_width",card_width)
	box.add_theme_constant_override("h_separation",12);box.add_theme_constant_override("v_separation",12)
	parent.add_child(box);resize_grids();return box

func resize_grids() -> void:
	if not is_instance_valid(body) or not is_instance_valid(scroll):return
	var available:=maxf(0,scroll.size.x-scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	for child in body.get_children():
		if child is GridContainer:
			var width:int=child.get_meta("card_width",340)
			child.columns=clampi(int((available+12)/(width+12)),1,int(child.get_meta("max_columns",3)))

func panel(parent:Node) -> VBoxContainer:
	var shell:=UiKit.make_panel(UiKit.COL_PANEL,UiKit.COL_ACCENT_2)
	shell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(shell)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);shell.add_child(box)
	return box

func icon(parent:Node,id:String,kind:="unit",glyph_size:=48) -> void:
	if kind=="hero":
		var portrait:=TextureRect.new();portrait.texture=preload("res://scripts/ui/hero_portraits.gd").texture(id)
		portrait.custom_minimum_size=Vector2(88,99);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(portrait);return
	if kind=="unit" and GameData.unit_index.has(id):
		var portrait:=UnitIcon.new();portrait.animate=false;portrait.show_status=false
		portrait.setup(GameData.get_unit(id),UiKit.COL_ACCENT_2)
		portrait.custom_minimum_size=Vector2(78,60);portrait.size_flags_vertical=Control.SIZE_SHRINK_CENTER;parent.add_child(portrait)
	else:
		var image:=TextureRect.new();image.custom_minimum_size=Vector2(glyph_size,glyph_size);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var path:String=Glyph.PATHS.get(id,Glyph.PATHS.tactics)
		var bitmap:=Image.new();bitmap.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#e8c273" stroke-width="1.5" stroke-linejoin="round"/></svg>'%path)
		image.texture=ImageTexture.create_from_image(bitmap);parent.add_child(image)

func create_layout() -> void:
	var background:=ColorRect.new();background.color=Color("#101923");background.set_anchors_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.add_child(scroll)
	scroll.resized.connect(resize_grids)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)

func page_key() -> String:
	if Expedition.state.is_empty() or show_new:return "opening"
	var run:Dictionary=Expedition.state
	return "%s:%d:%s:%s:%d"%[run.id,run.stage,run.phase,run.get("reward_round","") if run.phase=="reward" else "",tab if run.phase=="ready" else 0]

func build() -> void:
	if not is_instance_valid(body):create_layout()
	else:
		for child in body.get_children():body.remove_child(child);child.queue_free()
	for child in get_children():
		if child is ConfirmationDialog:remove_child(child);child.queue_free()
	var key:=page_key()
	if key!=built_page:
		scroll.scroll_vertical=0
		selection_report_open=false
	built_page=key
	var header:=row(body);icon(header,"tactics","glyph")
	var header_title:=label("铁潮远征",30,UiKit.COL_GOLD);header_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(header_title)
	var at_settlement: bool = not show_new and Expedition.state.get("phase", "") in ["complete", "failed"]
	if at_settlement:
		button(header,"筹备新远征",new_run)
	const Research = preload("res://scripts/expedition/research.gd")
	Research.watch_entry(button(header,"远征研究",Research.open.bind(self)))
	button(header,"支线百科",preload("res://scripts/expedition/field_guide.gd").open.bind(self))
	button(header,"返回主菜单",leave)
	notice=label(Expedition.error,14,UiKit.COL_WARN);body.add_child(notice)
	body.add_child(label("%d 关 · 六大战区 · 后期多轮 Buff · 最终章凶残 3"%Campaign.TOTAL,16,UiKit.COL_ACCENT_2))
	if Expedition.state.is_empty() or show_new:build_start();return
	var run:Dictionary=Expedition.state
	var heading:="第 %d 周目 · "%int(run.get("cycle",1))+"第 %d 章 · %s    %d / %d 关"%[Campaign.chapter(run.stage)+1,Campaign.CHAPTERS[Campaign.chapter(run.stage)],run.stage,Campaign.TOTAL]
	if run.phase=="event":heading="第 %d 关胜利 · 战后事件"%(int(run.stage)-1)
	var summary:=HFlowContainer.new()
	summary.add_theme_constant_override("h_separation",20)
	body.add_child(summary)
	summary.add_child(UiKit.make_label(heading,22,UiKit.COL_GOLD))
	var supplies:=row(summary)
	supplies.add_theme_constant_override("separation",6)
	icon(supplies,"supply_crate","glyph",24)
	supplies.add_child(UiKit.make_label("补给 %d"%run.supplies,22,UiKit.COL_GOLD))
	var kits:=row(summary)
	kits.add_theme_constant_override("separation",6)
	icon(kits,"heal","glyph",24)
	kits.add_child(UiKit.make_label("维修包 %d"%run.kits,22,UiKit.COL_GOLD))
	if run.phase=="ready":show_unread_gifts()
	elif run.phase not in ["reward","event"]:build_run_summary(run)
	if run.phase=="ready":
		var todo:PackedStringArray=[]
		if Growth.free_available(run):todo.append("免费强化可用")
		if not Attention.free_refills(run).is_empty():todo.append("免费补员可用")
		if free_refresh_available():todo.append("免费刷新可用")
		if not Catalog.Heroes.wounded(run).is_empty():todo.append("英雄待救治")
		if not todo.is_empty():body.add_child(label("营地待办："+" · ".join(todo),15,UiKit.COL_GOLD))
	if run.phase in ["ready","reward","event"]:build_tabs()
	if run.phase=="ready":
		var personnel_sale:=Expedition.excess_sale(run)
		if int(personnel_sale.count)>0:
			button(body,"一键售出多余人员 · %d 个 · 获得 %d 补给"%[personnel_sale.count,personnel_sale.supplies],sell_excess_personnel).tooltip_text="仅售出超过兵种或本章人数上限的普通部队；优先普通、低军衔单位，保留英雄。"
		var last_sale:Dictionary=run.get("last_personnel_sale",{})
		if not last_sale.is_empty():body.add_child(label("最近一键售出：%d 个多余人员 → +%d 补给"%[last_sale.count,last_sale.supplies],14,UiKit.COL_ACCENT_2))
	match str(run.phase):
		"reward","event":
			if selection_report_open:build_run_summary(run)
			elif run.phase=="reward":build_rewards()
			else:build_event()
		"ready":
			match tab:
				0:build_routes()
				1:build_shop()
				2:build_army()
				3:build_history()
				4:build_run_summary(run)
		"battle":
			body.add_child(label("战斗进行中 · "+str(run.route.title),22));button(body,"继续当前战斗",resume)
			body.add_child(label("每 30 秒自动保存，也可在战斗中保存并返回。",14))
		"complete":
			body.add_child(label("%d 关远征完成"%Campaign.TOTAL,26,UiKit.COL_OK));build_history()
		"failed":body.add_child(label("本次远征结束。局外养成保留。",22,UiKit.COL_WARN));build_history()
	if not at_settlement:
		button(body,"筹备新远征",new_run)

func build_run_summary(run:Dictionary) -> void:
	if run.phase in ["ready","reward","event"]:build_gain_summary(false)
	if run.phase=="reward":
		var losses:=Insights.reward_losses(run)
		if not losses.is_empty():body.add_child(label(losses,16,UiKit.COL_ACCENT_2))
	var reports:Array=run.get("battle_reports",[])
	if run.phase!="battle" and not reports.is_empty():
		build_last_report(reports.back())
	var carried:=Keepsakes.carried(run)
	body.add_child(label("本轮已携带 %d 件信物" % carried.size(),15,UiKit.COL_GOLD))
	for slot in carried.size():
		var id: String = carried[slot]
		var item:Dictionary=Keepsakes.ITEMS[id]
		var names:=PackedStringArray()
		for uid:String in item.partners:names.append(Army.training_name(uid))
		var carried_row := CarriedKeepsakeRow.new()
		body.add_child(carried_row)
		carried_row.mouse_filter = Control.MOUSE_FILTER_PASS
		carried_row.tooltip_text = "%s · %s\n%s\n从第 11 关起，你有机会招募这位搭档。" % [item.name, item.order, Keepsakes.guide_for_run(id,run)]
		carried_row.add_child(Keepsakes.icon_view(id))
		carried_row.add_child(UiKit.make_label("本轮信物 ·", 16, UiKit.COL_GOLD))
		var title := UiKit.make_label(item.name if Keepsakes.rank(id)<=1 else "%s · %d档" % [item.name,Keepsakes.rank(id)], 16, UiKit.COL_GOLD)
		title.add_theme_color_override("font_outline_color", Color("#50300b"))
		carried_row.add_child(title)
		carried_row.mouse_entered.connect(func(): title.add_theme_constant_override("outline_size", 4))
		carried_row.mouse_exited.connect(func(): title.add_theme_constant_override("outline_size", 0))
		carried_row.add_child(label("搭档：" + "、".join(names), 16, UiKit.COL_GOLD))
		var delay := Keepsakes.opening_cooldown(slot,run)
		carried_row.add_child(label("开场可用" if delay == 0 else "开场冷却 %d 秒" % delay, 15, UiKit.COL_DIM))
	if run.phase=="ready":
		body.add_child(label("出发时没带的信物，要在本轮救到曾获救的联络人，或等对方赴约支援后，才能补带。",14,UiKit.COL_DIM))
		for owner_id:String in Keepsakes.ITEMS:
			if Keepsakes.can_equip(run,owner_id):
				var item:Dictionary=Keepsakes.ITEMS[owner_id]
				var equip_button:=button(body,"携带"+item.name,equip_keepsake.bind(owner_id))
				equip_button.icon=Keepsakes.icon(owner_id)
				equip_button.add_theme_constant_override("icon_max_width",32)
				equip_button.tooltip_text=Keepsakes.guide_for_run(owner_id,run)
				Dot.mark(equip_button,true,"本轮可补带")
	body.add_child(label(Income.summary(run,MetaProgress),14,UiKit.COL_GOLD))
	if Income.has_pending(run,MetaProgress):button(body,"重试发放局外奖励",retry_income)
	var sale:Dictionary=run.get("last_auto_sale",{})
	if not sale.is_empty():body.add_child(label("最近自动出售：%d 名多余步兵 → +%d 补给（第 %d 关营地）"%[sale.count,sale.supplies,sale.stage],14,UiKit.COL_ACCENT_2))
	body.add_child(label("本轮继承出征时的养成；临时天赋、特装与装备不写回局外。战场资金每关重置，补给跨关保留。",14,UiKit.COL_DIM))

func retry_income() -> void:
	if Expedition.flush_income():Expedition.error=""
	build()

func free_refresh_available() -> bool:
	return Expedition.state.get("phase", "") == "ready" and Expedition.refresh_price() == 0 and Expedition.refresh_slots() > 0

func build_tabs() -> void:
	var run:Dictionary=Expedition.state
	var reminder:=Attention.summary(run) if run.phase=="ready" else ""
	if not reminder.is_empty():Dot.mark(button(body,reminder+" · 前往军团",change_tab.bind(2)),true,reminder)
	var tabs:=row(body)
	for index in 5:
		var entry:=button(tabs,["战区路线","军需商店","军团与天赋","藏品与记录","战报与收获"][index],change_tab.bind(index))
		entry.disabled=tab==index if run.phase=="ready" else index!=4 or selection_report_open
		if index == 1:
			Dot.mark(entry, free_refresh_available(), "免费刷新可用")
		elif index == 4:
			var can_equip := Keepsakes.ITEMS.keys().any(func(id:String): return Keepsakes.can_equip(run,id))
			Dot.mark(entry,can_equip,"有可补带的信物")
		else:
			Dot.mark(entry,index==2 and not reminder.is_empty(),reminder)
	if run.phase in ["reward","event"]:
		var pending:=button(tabs,"战后奖励 · 待领取" if run.phase=="reward" else "战后事件 · 待选择",change_tab.bind(5))
		pending.disabled=not selection_report_open
		Dot.mark(pending,true,Attention.summary(run))

func change_tab(index:int) -> void:
	if Expedition.state.get("phase","") in ["reward","event"]:
		selection_report_open=index==4
		scroll.scroll_vertical=0
	else:tab=index
	build()

func new_run() -> void:
	keepsake_values.clear()
	for id:String in Keepsakes.carried(Expedition.state):
		if Keepsakes.owned(id) and keepsake_values.size()<Keepsakes.slot_limit(Expedition.departure_cycle()):
			keepsake_values.append(id)
	show_new=true;build()

func build_start() -> void:
	body.add_child(label("初始军团 · 4000 部署点",24,UiKit.COL_GOLD))
	if opening.is_empty():
		opening = custom_opening()
		if opening.is_empty():
			opening = Campaign.STARTERS[country_value][0].units.duplicate()
	var options:=row(body)
	var country:=OptionButton.new()
	for name in ["美国","苏俄"]:country.add_item(name)
	country.select(0 if country_value=="美国" else 1);options.add_child(country);country.item_selected.connect(country_changed)
	var hero:=OptionButton.new();hero.add_item("不携带英雄");hero.set_item_metadata(0,"")
	hero.add_theme_constant_override("icon_max_width",32)
	for id:String in Expedition.heroes(country_value):
		hero.add_icon_item(preload("res://scripts/ui/hero_portraits.gd").texture(id),str(MetaProgress.Academy.HEROES[id]));hero.set_item_metadata(hero.item_count-1,id)
		hero.get_popup().set_item_icon_max_width(hero.item_count-1,32)
		if id==hero_value:hero.select(hero.item_count-1)
	hero.item_selected.connect(func(index:int):
		hero_value = str(hero.get_item_metadata(index))
		save_opening_choice())
	options.add_child(hero)
	var cycle:=Expedition.departure_cycle()
	body.add_child(label(Keepsakes.slot_hint(cycle,keepsake_values.size()),15,UiKit.COL_GOLD))
	var gifts:=grid(body)
	for id:String in Keepsakes.ITEMS:
		if not Keepsakes.owned(id):continue
		var choice:=CheckBox.new()
		choice.icon=Keepsakes.icon(id)
		choice.add_theme_constant_override("icon_max_width",32)
		choice.text=Keepsakes.ITEMS[id].name if Keepsakes.rank(id)<=1 else "%s · %d档" % [Keepsakes.ITEMS[id].name,Keepsakes.rank(id)]
		var partners:=PackedStringArray()
		for uid:String in Keepsakes.ITEMS[id].partners:partners.append(Army.training_name(uid))
		choice.tooltip_text=Keepsakes.guide_for_run(id,{})+"\n第 11 关起可招募："+"、".join(partners)
		choice.button_pressed=id in keepsake_values
		choice.disabled=not choice.button_pressed and keepsake_values.size()>=Keepsakes.slot_limit(cycle)
		choice.toggled.connect(toggle_keepsake.bind(id))
		gifts.add_child(choice)
	var presets:=row(body)
	for index in Campaign.STARTERS[country_value].size():button(presets,str(Campaign.STARTERS[country_value][index].name),select_preset.bind(index))
	var saved := custom_opening()
	var recall := button(presets, "自定义", func(): opening = saved.duplicate(); build())
	recall.disabled = saved.is_empty()
	recall.tooltip_text = "先调整部队数量，再保存自定义编成" if saved.is_empty() else "使用已保存的%s编成" % country_value
	button(presets, "保存为自定义", save_custom_opening)
	var units:=grid(body)
	for id:String in Campaign.opening_units(country_value):
		var box:=panel(units);var line:=row(box);icon(line,id)
		line.add_child(label(Army.training_name(id)+" · "+str(GameData.get_unit(id).cost)+" 点",17))
		box.add_child(label(tag_text(id),13,UiKit.COL_ACCENT_2))
		var count:=SpinBox.new();count.min_value=0;count.max_value=6;count.step=1;count.value=int(opening.get(id,0));box.add_child(count)
		count.value_changed.connect(opening_changed.bind(id))
	budget=label("",17,UiKit.COL_GOLD);body.add_child(budget);refresh_budget()
	body.add_child(label("选择 1～4 种兵种；基地设施和矿车另行提供，每关另配一艘气垫运输船。英雄不占部署点。出征后先选一件起始战术装备。",14))
	button(body,"开始 %d 关远征"%Campaign.TOTAL,request_start)
	if not Expedition.state.is_empty():button(body,"返回当前远征",cancel_new)

func show_unread_gifts() -> void:
	for owner_id:String in Keepsakes.ITEMS:
		var history := Keepsakes.receipts(owner_id)
		for i in history.size():
			var receipt: Dictionary = history[i]
			if receipt.get("camp_read",false):continue
			var frame:=GiftNotice.gift_panel()
			body.add_child(frame)
			var card:=VBoxContainer.new()
			card.add_theme_constant_override("separation",8)
			frame.add_child(card)
			card.add_child(GiftNotice.heading(owner_id,i+1))
			card.add_child(label(Keepsakes.story(owner_id,i+1),16))
			card.add_child(label(Keepsakes.guide_for_run(owner_id,Expedition.state),15,UiKit.COL_ACCENT_2))
			button(card,"收好信物" if i == 0 else "读过这次再会",acknowledge_gift.bind(receipt,frame))

func acknowledge_gift(receipt:Dictionary,card:Control) -> void:
	receipt["camp_read"]=true
	if MetaProgress.save():
		card.hide()
	else:
		receipt.erase("camp_read")
		show_error("没能保存这段赠礼记录，请重试。")

func toggle_keepsake(enabled:bool,id:String) -> void:
	if enabled and id not in keepsake_values and keepsake_values.size()<Keepsakes.slot_limit(Expedition.departure_cycle()):keepsake_values.append(id)
	elif not enabled:keepsake_values.erase(id)
	build()

func equip_keepsake(owner_id:String) -> void:
	confirm("本轮携带「%s」，直到这次远征结束。"%Keepsakes.ITEMS[owner_id].name,result_equip.bind(owner_id))

func result_equip(owner_id:String) -> void:
	result(Expedition.equip_keepsake(owner_id))

func opening_changed(value:float,id:String) -> void:
	opening[id]=int(value);refresh_budget()

func refresh_budget() -> void:
	var spent:=0
	for id:String in opening:spent+=int(GameData.get_unit(id).cost)*int(opening[id])
	budget.text="已使用 %d / 4000 部署点    %s"%[spent,Campaign.opening_error(country_value,opening)]

func custom_opening() -> Dictionary:
	var saved: Variant = opening_prefs.get_value("custom_army", country_value, {})
	if saved is Dictionary and Campaign.opening_error(country_value, saved).is_empty():
		return saved.duplicate()
	return {}

func save_custom_opening() -> void:
	var problem := Campaign.opening_error(country_value, opening)
	if not problem.is_empty():
		show_error(problem)
		return
	var previous: Variant = opening_prefs.get_value("custom_army", country_value, {})
	opening_prefs.set_value("custom_army", country_value, opening.duplicate())
	if opening_prefs.save(OPENING_PREFS) != OK:
		opening_prefs.set_value("custom_army", country_value, previous)
		show_error("自定义编成保存失败，请重试。")
		return
	build()
	budget.text += "　已保存%s自定义编成" % country_value

func select_preset(index:int) -> void:
	opening=Campaign.STARTERS[country_value][index].units.duplicate();build()

func country_changed(index:int) -> void:
	country_value = ["美国", "苏俄"][index]
	restore_opening_hero()
	save_opening_choice()
	opening = {}
	build()

func restore_opening_hero() -> void:
	var previous := ""
	if Expedition.state.get("country", "") == country_value:
		previous = str(Expedition.state.get("hero", ""))
	var remembered := str(opening_prefs.get_value("hero", country_value, previous))
	hero_value = remembered if remembered in Expedition.heroes(country_value) else ""

func save_opening_choice() -> void:
	opening_prefs.set_value("opening", "country", country_value)
	opening_prefs.set_value("hero", country_value, hero_value)
	if opening_prefs.save(OPENING_PREFS) != OK:
		push_warning("远征筹备选择保存失败")

func cancel_new() -> void:
	show_new=false;build()

func confirm(text:String,action:Callable) -> void:
	var dialog:=ConfirmationDialog.new();dialog.title="确认远征选择";dialog.dialog_text=text;dialog.confirmed.connect(action);add_child(dialog);dialog.popup_centered(Vector2i(540,200))

func request_start() -> void:
	var problem:=Campaign.opening_error(country_value,opening)
	if not problem.is_empty():show_error(problem);return
	if Expedition.state.is_empty() and not FileAccess.file_exists(Expedition.FILE):start()
	else:confirm("开始后替换当前远征进度，局外养成保持。",start)

func start() -> void:
	if Expedition.start(country_value,hero_value,0,opening,keepsake_values):show_new=false;tab=0;build()
	else:notice.text=Expedition.error

func add_unit_source(box:VBoxContainer,run:Dictionary,id:String) -> void:
	if not GameData.unit_index.has(id):return
	var faction:=str(GameData.get_unit(id).get("faction",""))
	var names:Dictionary={"allied":"盟军","soviet":"苏军","yuri":"尤里"}
	if not names.has(faction) or faction==GameData.ra2_country_side(run.country):return
	var details:=PackedStringArray(["兵种来源：%s"%names[faction]])
	if id in run.get("training_permits",[]):
		for person:Dictionary in preload("res://scripts/expedition/contact_catalog.gd").PEOPLE.values():
			if person.get("permit","")==id:
				details.append("%s提供了训练许可。"%person.name)
				break
	if int(run.stage)>=11:
		for owner_id:String in Keepsakes.carried(run):
			var gift:Dictionary=Keepsakes.ITEMS.get(owner_id,{})
			if id in gift.get("partners",[]):
				details.append("携带「%s」，从第 11 关起可招募该兵种。"%gift.name)
	if id in run.get("licenses",[]):
		details.append("本轮已有生产许可，商店可刷出该兵种的强化。")
	else:
		details.append("招募后获得本轮生产许可。")
	box.add_child(label("\n".join(details),14,UiKit.COL_ACCENT_2))

func tag_text(id:String) -> String:
	var tags:=PackedStringArray()
	for key:String in Army.tags(id,Expedition.state):tags.append(Army.TRAITS[key].name)
	return "适用羁绊："+" · ".join(tags)+"；战地支援对全军生效"

func grade_frame(box:VBoxContainer,item:Dictionary) -> String:
	var grade:=Market.item_grade(Expedition.state,item)
	var shell:PanelContainer=box.get_parent()
	var style:StyleBoxFlat=shell.get_theme_stylebox("panel").duplicate()
	style.border_color=Color(Relics.COLORS[grade])
	style.border_width_left=3
	shell.add_theme_stylebox_override("panel",style)
	return grade

func card(parent:Node,item:Dictionary,action:Callable,caption:String,attention:bool=false) -> VBoxContainer:
	var box:=panel(parent);box.custom_minimum_size.x=230
	var line:=row(box)
	var glyph:String={"firepower":"attack","armor":"guard","health":"heart","engines":"speed","infantry_fire":"infantry","infantry_health":"escort","vehicle_fire":"heavy","vehicle_health":"vehicle","crossfire":"focus","field_medic":"heal","emergency_position":"defense","mobile_magazine":"speed","breach_tools":"explosive","execution_plan":"sight","hunter_protocol":"exclusive","last_stand":"guard","veterans":"rank","repair":"build","medics":"heal","production":"queue","deployment":"coin","supplies":"coin","salvage":"reload","logistics":"tactics"}.get(str(item.id),"exclusive" if item.kind in ["native","specialization"] else "tactics")
	if item.kind=="relic":glyph=Relics.ITEMS[item.id].icon
	if item.kind=="trait_buff":glyph=str(Army.TRAITS[item.id].icon)
	icon(line,str(item.id) if GameData.unit_index.has(str(item.id)) else glyph,"hero" if item.kind=="hero" else "unit" if GameData.unit_index.has(str(item.id)) else "glyph")

	var grade:=grade_frame(box,item)
	var title:=Catalog.name_of(item)
	if not title.begins_with(grade+" · "):title=grade+" · "+title
	line.add_child(label(title,17,Color(Relics.COLORS[grade])))
	if item.kind=="relic" and Relics.ITEMS[item.id].has("max_level"):
		var cap:=int(Relics.ITEMS[item.id].max_level)
		var lv:=Relics.level(Expedition.state,item.id)
		box.add_child(label("当前 %d → %d / %d 层"%[lv,mini(cap,lv+1),cap],14,Relics.tint(item.id)))
	add_unit_source(box,Expedition.state,str(item.id))
	if item.kind == "trait_buff":
		var count := int(Expedition.state.get("trait_buffs", {}).get(item.id, 0))
		var target := mini(9, count + int(item.get("levels", 1)))
		var lines := PackedStringArray()
		if count < target:
			lines.append("获得后 %d 层：%s" % [target, Army.Progress.summary(item.id, target)])
		else:
			lines.append("已满 9 层")
		var spec: Dictionary = Army.TRAITS[item.id]
		if count < 3: lines.append("3 层解锁：" + str(Army.Progress.OPENINGS[item.id]))
		if count < 6: lines.append("6 层解锁：" + str(spec.desc[3]))
		if count < 9: lines.append("9 层解锁：" + str(spec.desc[4]))
		box.add_child(label("\n".join(lines), 14))
	else:
		box.add_child(label(Catalog.description(item),14))
		var benefit:=Insights.audience(Expedition.state,item)
		if not benefit.is_empty():box.add_child(label(benefit,14,UiKit.COL_ACCENT_2))
	if item.kind=="buff":
		var current_buff_level:=int(Expedition.state.get("buffs",{}).get(item.id,0))
		var gained_buff_levels:=maxi(1,int(item.get("levels",1)))
		box.add_child(label("当前等级 %d / 3 → 获得后 %d / 3"%[current_buff_level,mini(3,current_buff_level+gained_buff_levels)],14,UiKit.COL_ACCENT_2))
	if GameData.unit_index.has(str(item.id)):box.add_child(label(tag_text(item.id),13,UiKit.COL_ACCENT_2))
	if item.kind=="native":box.add_child(label(preload("res://scripts/rules/skill_training.gd").talent_description(item.id),13,UiKit.COL_DIM))
	Dot.mark(button(box,caption,action),attention,"奖励待领取")
	return box

func build_last_report(report:Dictionary) -> void:
	var line:=row(body)
	line.add_child(label("第 %d 关战报 · %s"%[report.stage,Campaign.map_name(report.map)],18,UiKit.COL_GOLD))
	var toggle:=UiKit.make_button("展开明细",14)
	line.add_child(toggle)
	body.add_child(label(Insights.headline(report),15,UiKit.COL_ACCENT_2))
	GiftNotice.add_report_rows(body,Expedition.state.id,report.stage)
	var details:=label(Insights.review_text(report),14)
	body.add_child(details)
	details.hide()
	toggle.pressed.connect(func():
		details.visible=not details.visible
		toggle.text="收起明细" if details.visible else "展开明细")

func build_rewards() -> void:
	var bonus_index:=Campaign.bonus_index(str(Expedition.state.get("reward_round","initial")))
	var rounds:=Campaign.bonus_rounds(int(Expedition.state.stage))
	body.add_child(label("额外 Buff · 第 %d / %d 轮 · %d 选一"%[bonus_index,rounds,Expedition.state.offers.size()] if bonus_index>0 else "选择一项本轮奖励",24,UiKit.COL_ACCENT_2))
	if Expedition.state.get("reward_round","")=="main":body.add_child(label("领取后还有 %d 次额外 Buff 选择。第 15 关胜利起每轮四选一；寻珍罗盘再增加一个选项。"%rounds,14,UiKit.COL_GOLD))
	var choices:=grid(body)
	for index in Expedition.state.offers.size():card(choices,Market.reward_item(Expedition.state,Expedition.state.offers[index]),request_item.bind("reward",index,Expedition.reward_token()),"选取奖励",true)
	build_equipment()

func build_equipment() -> void:
	var run:Dictionary=Expedition.state
	button(body,("收起" if equipment_open else "展开")+"战术装备 · %d 种"%run.buffs.size(),func():equipment_open=not equipment_open;build())
	if not equipment_open:return
	body.add_child(label("战术装备 · 已拥有 %d 种 · 全部自动生效"%run.buffs.size(),18,UiKit.COL_GOLD))
	body.add_child(label("装备数量不限，获得新装备直接装上；同名装备升级，最高 3 级。下方每级数值按等级叠加，本轮持续生效，不写回局外。",14,UiKit.COL_DIM))
	for id:String in run.buffs:
		var box:=panel(body)
		box.add_child(label(str(Catalog.BUFFS[id].name)+" · Lv.%d / 3"%int(run.buffs[id]),16,UiKit.COL_GOLD))
		box.add_child(label(Catalog.description({"kind":"buff","id":id}),14))
		if id=="veterans":box.add_child(label("用于更快提升战场军衔；不增加攻防强化等级或自带天赋等级。",13,UiKit.COL_DIM))
		if run.phase=="ready":button(box,"出售 "+str(Catalog.BUFFS[id].name)+(" · 章末重构返还已付补给 70%" if run.get("rebuild_coupon",false) else " · 付费装备返还 30%，免费装备每级 24"),sell_equipment.bind(id))
	if run.buffs.is_empty():body.add_child(label("暂无战术装备；从商店购买或战后奖励选择后即可自动生效。",14))

func request_item(kind:String,index:int,token:String="") -> void:
	if kind=="reward" and (Expedition.state.get("phase","")!="reward" or token!=Expedition.reward_token()):return
	if kind=="shop":
		var problem:=Expedition.purchase_problem(Expedition.state,index)
		if not problem.is_empty():show_error(problem);return
	var item:Dictionary=Market.reward_item(Expedition.state,Expedition.state.offers[index]) if kind=="reward" else Expedition.state.shop[index]
	var action:=apply_item.bind(kind,index,token)
	if item.get("enable_disabled",false):confirm("你在养成中关闭了这个自带天赋。确认仅在本轮启用？局外开关不变。",action)
	else:action.call()

func apply_item(kind:String,index:int,token:String="") -> void:
	var ok:bool=Expedition.choose(index,"",token) if kind=="reward" else Expedition.buy(index)
	result(ok)

func build_routes() -> void:
	var run:Dictionary=Expedition.state
	body.add_child(label(Campaign.title(run.stage)+" · "+Campaign.task_name(Campaign.task(run.stage),run.stage),24,UiKit.COL_ACCENT_2))
	var issue:=Army.roster_error(run)
	if not issue.is_empty():body.add_child(label(issue+"；请到「军团与天赋」整编。",16,UiKit.COL_WARN))
	if not SchoolField.Book.met() and not SchoolField.encounter(run,""):
		body.add_child(label("百合子线索 · 留意「海岸」战区。派部队前往雨棚，听到饭盒声后获胜，即可带回第一章。",16,SchoolField.PINK))
	var choices:=grid(body,2,420)
	for index in run.routes.size():
		var route:Dictionary=run.routes[index];var box:=panel(choices)
		box.add_child(label(route.title+(" · 精英" if route.elite else ""),21,UiKit.COL_GOLD))
		var preview=preload("res://scripts/ui/map_preview.gd").new();preview.custom_minimum_size=Vector2(300,150);box.add_child(preview);preview.show_map(route.map,route.size)
		if SchoolField.encounter(run,route.map):
			box.add_child(label(SchoolField.SHELTER+" · 选择此战区寻找百合子",17,SchoolField.PINK))
		if SchoolField.find_stage(run) and (SchoolField.Book.met() or run.get("yuriko_recruited",false)):
			var names:String=SchoolField.FINDS[SchoolField.find_kind(run)]
			box.add_child(label("百合子支线 · "+names+"。派地面部队前往粉色标记，获胜后带回。",15,SchoolField.PINK))
		if route.get("bridge_support",false):
			preview.mark_broken_bridge=true
			box.add_child(label("工兵回援 · 蓝圈为可修复的侧桥。开局获赠工程师，进入维修小屋即可通行。",14,UiKit.COL_ACCENT_2))
		box.add_child(label(Campaign.map_description(route.map),13,UiKit.COL_DIM))
		box.add_child(label(Campaign.task_name(route.task,run.stage),17))
		if int(run.get("intel_stage",0))==int(run.stage):box.add_child(label(Campaign.wave_intel(run.stage,route),15,UiKit.COL_ACCENT_2))
		if route.task=="boss":box.add_child(label(boss_preview(run.stage),14,UiKit.COL_WARN))
		var tactic:=preload("res://scripts/expedition/elite_tactics.gd").preview(str(route.get("elite_tactic","")))
		if not tactic.is_empty():box.add_child(label(tactic,14,UiKit.COL_WARN))
		box.add_child(label("敌军 %d 家 · 我方 %d 家 · 多线额外 +%d 补给"%[route.get("enemy_count",1),1+route.get("support_contacts",[]).size(),route.get("front_bonus",0)],16,UiKit.COL_GOLD))
		for contact:Dictionary in route.get("support_contacts",[]):box.add_child(label("友军参战："+str(contact.name)+" · 独立基地与生产",14,UiKit.COL_ACCENT_2))
		box.add_child(label("对手 %s · %s · 开局资金 %d\n%s"%[route.enemy,GameData.DIFFICULTY_NAMES[Campaign.difficulty(run.stage)],Campaign.funds(run.stage) + Campaign.EXTRA_FUNDS,route.condition.desc],14))
		box.add_child(label("基础胜利补给 +%d · 装备、藏品收益另计"%Campaign.victory_supplies(run.stage,route.elite),14,UiKit.COL_GOLD))
		preload("res://scripts/expedition/research.gd").intel_panel(self,box,run,route)
		var income:=Income.quote(int(run.stage))
		box.add_child(label("额外胜利收益：军需券 +%d · 战略核心 +%d"%[income.credits,income.cores],14,UiKit.COL_GOLD))
		if route.task in ["radar","supply","assault","annihilate","rescue"]:box.add_child(label("可选：6 分钟内完成，额外 %d 补给。"%Campaign.OPTIONAL_SUPPLIES,13,UiKit.COL_GOLD))
		var story:String=Campaign.task_description(route.task,run.stage)
		if route.task=="rescue":story="救出两组人员：医护组和失联侦察组；累计占领救援点即可完成，救援者将加入战场。"
		elif route.task=="research":story="分别接管两座研究所，每处单支部队需要 45 秒，多支更快，进度保留；每座为胜利补给 +40。"
		box.add_child(label(story,14,UiKit.COL_ACCENT_2))
		var missions=preload("res://scripts/expedition/field_missions.gd")
		var cycle:=int(run.get("cycle",1))
		var field_kind:String=missions.candidate(run.seed,run.stage,route,cycle)
		var arrival:=preload("res://scripts/expedition/field_operations.gd").available_arrival(run.stage,run.get("field_contacts",[]))
		var bridge:bool=route.get("bridge_support",false)
		var slots:Array=missions.Assign.slots(arrival)
		var previews:PackedStringArray=[]
		if bridge:previews.append("抢修侧桥")
		if 0 in slots:previews.append("救援联络人（维修包 ×1，第 %d 关增援）"%arrival)
		if 1 in slots:
			var supply_run:bool=field_kind.is_empty() and int(run.stage)%2==0
			var job:String=missions.NAMES.get(field_kind,missions.BASIC_NAMES.cache if supply_run else missions.BASIC_NAMES.intel)
			if supply_run or field_kind in ["box","fieldshop"]:job+="（维修包 ×1）"
			elif field_kind=="fuel":job+="（可拆车换维修包）"
			previews.append(job)
		if not previews.is_empty():box.add_child(label("可选支线 · "+"、".join(previews)+"（视可达地形部署）",13,UiKit.COL_SIDE_MISSION))
		var leads := []
		for slot: int in slots:
			var kind: String = "contact" if slot == 0 else field_kind
			if kind.is_empty():kind = "cache" if int(run.stage)%2==0 else "intel"
			leads.append({"kind":kind})
		preload("res://scripts/expedition/hero_field_stories.gd").assign(run, leads)
		for lead: Dictionary in leads:
			if lead.has("hero_chronicle"):
				box.add_child(label("同行委托 · "+preload("res://scripts/expedition/hero_field_stories.gd").chapter_hint(lead.hero_chronicle),14,UiKit.COL_GOLD))
			if lead.has("hero_lead"):
				box.add_child(label("英雄线索 · %s\n%s 完成这条支线并获胜后入队。" % [preload("res://scripts/expedition/hero_field_stories.gd").name_of(lead.hero_lead), preload("res://scripts/expedition/hero_field_stories.gd").BOOK[lead.hero_lead].clue], 14, SchoolField.PINK if lead.hero_lead=="YURIKO" else UiKit.COL_GOLD))
		button(box,"部署到此战区",launch.bind(index)).disabled=not issue.is_empty()
	build_arrivals()
	build_traits()

func build_arrivals() -> void:
	var plan:Array=preload("res://scripts/expedition/reinforcement_plan.gd").build(Expedition.state)
	var times:="暂无军团" if plan.is_empty() else "首批 %s · 到齐 %s"%[Insights.time_text(plan[0].due),Insights.time_text(plan[-1].due)]
	button(body,("收起" if arrivals_open else "展开")+"增援 · "+times,func():arrivals_open=not arrivals_open;build())
	if not arrivals_open:return
	body.add_child(label("出战增援时间表",20,UiKit.COL_GOLD))
	body.add_child(label("每局从零重新计时；只有军团与英雄跨关，工厂自产兵不加入军团。",13,UiKit.COL_DIM))
	for id:String in Catalog.Heroes.owned(Expedition.state):
		var line:=row(body);icon(line,id,"hero");line.add_child(label(MetaProgress.Academy.hero_label(id)+(" · 待救治" if id in Catalog.Heroes.wounded(Expedition.state) else " · 本关自动排队"),16,UiKit.COL_GOLD))
	body.add_child(label(Insights.arrival_text(Expedition.state),14))

func boss_preview(stage:int) -> String:
	return {5:"先破坏两座供能节点，再进攻指挥部。",10:"供能节点与机动防空配合；拆节点后突击指挥部。",15:"拆一个节点后，每 30 秒出现 12 秒攻击窗口；两个全拆永久解除护盾。",20:"指挥车每 30 秒在敌营附近转移；每拆一座节点，间隔增加 20 秒。可先做支线，击毁指挥车即过关。",25:"拆除双供能节点，突破钢铁壁垒；胜利后进入凶残 3 最终章。",30:"三阶段：拆除双节点 → 同时守住两点破盾，两点都增派守军可加快进度 → 摧毁指挥部。"}.get(stage,"")

func build_shop() -> void:
	var run:Dictionary=Expedition.state
	body.add_child(label("军需商店 · 等级 %d"%(Campaign.chapter(run.stage)+1),23,UiKit.COL_GOLD))
	var count:=Expedition.refresh_slots()
	var refresh_text:="全部已锁定" if count==0 else "刷新 · %s · 更换 %d 格"%["免费" if Expedition.refresh_price()==0 else "%d 补给"%Expedition.refresh_price(),count]
	var refresh_button := cost_button(body,refresh_text,refresh_shop,Expedition.refresh_price(),count>0)
	Dot.mark(refresh_button, free_refresh_available(), "免费刷新可用")
	if Expedition.bargain_level()>=1:
		var bulk:=row(body)
		var locks:=Expedition.lockable_discounts().size()
		var lock_button:=button(bulk,"一键锁定打折商品 · %d 件 · 免费"%locks,func():result(Expedition.lock_discounts()))
		lock_button.disabled=locks==0
		if Expedition.bargain_level()>=2:
			var quote:=Expedition.plan_discount_purchases(run.duplicate(true))
			var price:="%d 补给"%quote.cost if quote.cost>0 else "免费"
			var purchase:=button(bulk,"一键购买打折商品 · %d 件 · %s"%[quote.count,price],request_discount_purchase.bind(quote))
			purchase.disabled=quote.count==0
			if quote.cost>0:purchase.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("supplies")
			purchase.tooltip_text="按货架顺序购买，跳过补给不足或当前无法购买的商品。"
	var services:=row(body)
	cost_button(services,"整备全军 · %d"%Expedition.repair_price(),repair,Expedition.repair_price())
	cost_button(services,"维修包 · 40",service.bind("kit","","a"),40)
	cost_button(services,("已持有 · " if run.get("relics",{}).get(Growth.RELIC,false) else "购买藏品 · ")+Growth.RELIC_NAME+("" if run.get("relics",{}).get(Growth.RELIC,false) else " · 40"),service.bind("relic","","a"),Growth.RELIC_PRICE,not run.get("relics",{}).get(Growth.RELIC,false))
	body.add_child(label(Growth.RELIC_NAME+"：每关免费强化一个兵种一次；攻防各 +1 级，最高 5 级，独立于战术装备。",14,UiKit.COL_DIM))
	for id:String in Catalog.Heroes.wounded(run):cost_button(body,"救治 "+str(MetaProgress.Academy.HEROES[id])+" · 60",rescue.bind(id),60)
	body.add_child(label("每店首次刷新免费，之后 "+("5／10／15 封顶（暗线地图）" if Relics.owned(run,"bargain_map") else "10／20／30 封顶")+"。满员时也能锁定招募商品，等有空位再买。锁定不限数量，可全部锁定并跨店保留；全部锁定时暂停刷新，保留免费次数与补给。黄色定向商品跟随标记羁绊。未锁定的末格优先提供未持有藏品，专属藏品按已有兵种筛选。同一件商品每店只出现一次；可升级装备显示购买前后等级，满级不可购买。",14,UiKit.COL_DIM))
	var choices:=grid(body)
	for index in run.shop.size():
		var item:Dictionary=run.shop[index]
		var problem:=Expedition.purchase_problem(run,index)
		var level_text:=""
		if item.kind=="buff":
			var current:=int(run.buffs.get(item.id,0))
			level_text="Lv.%d → Lv.%d / 3"%[current,mini(3,current+int(item.get("levels",1)))]
		var price_text:="首购免费（原售 %d 补给）"%item.price if Expedition.free_shelf_purchase(run) else "%d 补给"%item.price
		var caption:="已售罄" if item.sold else "购买 · "+price_text
		var box:=card(choices,item,request_item.bind("shop",index),caption)
		var purchase:Button=box.get_child(box.get_child_count()-1)
		if not item.sold and not Expedition.free_shelf_purchase(run) and item.price>0:purchase.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("supplies")
		purchase.name="PurchaseButton";purchase.disabled=not problem.is_empty()
		if not level_text.is_empty():box.add_child(label(level_text,14,UiKit.COL_GOLD))
		box.add_child(label(problem if not problem.is_empty() else "可购买",14,Color.WHITE))
		if item.get("targeted",false):box.add_child(label("定向",13,UiKit.COL_GOLD))
		var locked:bool=item.get("locked",false)
		var lock_button:=button(box,"解除锁定" if locked else "锁定商品",lock_shop.bind(index))
		lock_button.name="LockButton"
		lock_button.disabled=not Expedition.can_lock_shop(index)
		if locked:
			lock_button.icon=Glyph.texture("lock")
			lock_button.add_theme_constant_override("icon_max_width",18)
		preload("res://scripts/expedition/shop_card.gd").apply(box,index,bool(item.sold),problem)
		preload("res://scripts/expedition/shop_card.gd").add_discount(box,item)
		if item.get("fresh_stock", false) and not item.sold:
			preload("res://scripts/expedition/shop_card.gd").add_new_badge(box)
	build_equipment()
	build_traits()

func build_event() -> void:
	var run:Dictionary=Expedition.state
	var available:Array=[]
	for index in run.event.choices.size():
		if run.event.choices[index].item.kind!="equipment_slot":available.append(index)
	body.add_child(label("战后事件 · "+str(run.event.name),24,UiKit.COL_ACCENT_2))
	body.add_child(label("本关奖励已领取。以下 %d 项只能选择一项，完成后进入第 %d 关营地；退出重进会保留当前事件。"%[available.size(),run.stage],15))
	var choices:=grid(body,2)
	for index:int in available:
		var choice:Dictionary=run.event.choices[index]
		var box:=panel(choices)
		var heading:=row(box)
		var item:Dictionary=choice.item
		match item.kind:
			"supplies": icon(heading,"supply_crate","glyph")
			"repair_kit": icon(heading,"heal","glyph")
			"refresh_token": icon(heading,"reload","glyph")
			_: icon(heading,str(item.id))
		var grade:=grade_frame(box,item)
		heading.add_child(label(grade+" · "+str(choice.label),18,Color(Relics.COLORS[grade])))
		add_unit_source(box,run,str(item.id))
		box.add_child(label(Catalog.description(choice.item),14))
		if choice.item.kind=="native":box.add_child(label(preload("res://scripts/rules/skill_training.gd").talent_description(choice.item.id),13,UiKit.COL_DIM))
		var cost:int=choice.cost
		var kits:int=choice.get("kit_cost",0)
		if kits>0:
			box.add_child(label("维修包：持有 %d 个 · 需要 %d 个%s"%[run.kits,kits," · 数量不足" if run.kits<kits else ""],14,UiKit.COL_DIM))
		var caption:="选择 · 免费" if cost==0 and kits==0 else "选择 · %d 补给"%cost if kits==0 else "选择 · %d 维修包"%kits
		var choice_button:=cost_button(box,caption,event_choice.bind(index,Expedition.event_token()),cost,run.kits>=kits and not (choice.item.kind=="reinforce" and Expedition.refill_count(run,choice.item.id)<=0))
		if kits>0:choice_button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("kits","supplies" if cost>0 else "")
		Dot.mark(choice_button,not choice_button.disabled,"战后事件待选择")

func build_traits() -> void:
	var run:Dictionary=Expedition.state
	body.add_child(label("羁绊进度 · 悬停查看详情",18,UiKit.COL_GOLD))
	body.add_child(label("3／6／9 层解锁构筑效果；标记最多两项，仅影响奖励方向。",13,UiKit.COL_DIM))
	var choices:=grid(body,3)
	for key:String in Army.TRAITS:
		var tile:=preload("res://scripts/expedition/trait_card.gd").new()
		choices.add_child(tile);tile.setup(key,run);tile.tracking_requested.connect(track.bind(key))

func build_army() -> void:
	var run:Dictionary=Expedition.state
	var roster_issue:=Army.roster_error(run)
	if not roster_issue.is_empty():body.add_child(label(roster_issue,18,UiKit.COL_WARN))
	var total:=0
	var reserve_types:=0
	for id:String in Army.available(run):
		total+=Army.quantity(run,id)
		if id not in run.active_roster:reserve_types+=1
	body.add_child(label("出战编制 %d / %d · 预备 %d 种（不限种类）· 跨关部队 %d / %d"%[run.active_roster.size(),Campaign.slots(run),reserve_types,total,Campaign.population(run.stage)],19,UiKit.COL_GOLD))
	body.add_child(label("出战与预备兵种可互换：把一方拖到另一方，或依次点击两者。拖到「拖回预备栏」可单独撤下。",14,UiKit.COL_ACCENT_2))
	var board:=preload("res://scripts/expedition/roster_box.gd").new()
	board.name="FormationBox"
	board.changed.connect(result,CONNECT_DEFERRED)
	body.add_child(board)
	body.add_child(label("每种步兵最多带 8 人，其余最多 4 台。超过兵种或本章人数上限的步兵自动出售返还补给，优先普通、低军衔单位，英雄保留。补员只补空缺；整备只回血。其余超限部队可使用上方「一键售出多余人员」，也可手动遣散。",14))
	body.add_child(label("攻防分别按局外等级 ÷ 4 四舍五入带入，最高 5 级。每次强化攻防各 +1，相当于局外各 +4 级；不回写局外。",14,UiKit.COL_DIM))
	if run.get("relics",{}).get(Growth.RELIC,false):body.add_child(label(Growth.RELIC_NAME+(" · 本关免费强化 1 次可用" if Growth.free_available(run) else " · 本关免费次数已使用，下关恢复"),14,UiKit.COL_GOLD))
	var filters:=OptionButton.new()
	for title:String in ["全部军团","已出战","可强化","需补员"]:filters.add_item(title)
	filters.select(army_filter);body.add_child(filters)
	filters.item_selected.connect(func(index:int):army_filter=index;build())
	var choices:=grid(body)
	var free_upgrades:=Attention.free_units(run)
	var free_refills:=Attention.free_refills(run)
	for id:String in Army.available(run):
		if army_filter==1 and id not in run.active_roster:continue
		if army_filter==2 and not Growth.can_upgrade(run,id):continue
		if army_filter==3 and Expedition.refill_count(run,id)<=0:continue
		var box:=panel(choices)
		var line:=row(box)
		icon(line,id)
		var unit_name:=label(Army.training_name(id)+" ×"+str(Army.quantity(run,id)),18)
		unit_name.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		unit_name.autowrap_mode=TextServer.AUTOWRAP_OFF
		line.add_child(unit_name)
		var badge:=button(line,"￥",request_dismiss.bind(id))
		badge.custom_minimum_size=Vector2(26,26)
		badge.tooltip_text="遣散 1 个%s，获得 %d 补给"%[Army.training_name(id),Catalog.dismissal_value(id)]
		badge.accessibility_name=badge.tooltip_text
		badge.add_theme_color_override("font_color",UiKit.COL_GOLD)
		for state:String in ["normal","hover","pressed"]:
			var fill:=Color("302a21") if state=="normal" else Color("665035")
			badge.add_theme_stylebox_override(state,UiKit.panel_style(fill,UiKit.COL_GOLD,13,1,2))
		box.add_child(label(tag_text(id),13,UiKit.COL_ACCENT_2))
		add_unit_source(box,run,id)
		box.add_child(label("攻击 %d / 5 级 · 防御 %d / 5 级"%[Growth.level(run,id,"atk"),Growth.level(run,id,"def")],16,UiKit.COL_GOLD))
		box.add_child(label("局外攻击 %d / 20 · 防御 %d / 20，开局攻防各 %d 级"%[Growth.source_level(run,id,"atk"),Growth.source_level(run,id,"def"),Growth.starting_level(run,id)],13,UiKit.COL_DIM))
		box.add_child(label(Army.Talents.summary(run,id),13,UiKit.COL_ACCENT_2))
		var can_upgrade:=Growth.can_upgrade(run,id)
		var upgrade:=cost_button(box,("攻防强化 +1 · "+("本关免费" if Growth.free_available(run) else str(Growth.PRICE)+" 补给")) if can_upgrade else Growth.upgrade_problem(run,id),upgrade_unit.bind(id,Growth.price(run)),Growth.price(run),can_upgrade)
		Dot.mark(upgrade,id in free_upgrades,"本关免费强化待使用")
		var refill:=Expedition.refill_count(run,id)
		var refill_button:=cost_button(box,"补员 +%d · "%refill+("免费" if run.repair_coupon else "40 补给") if refill>0 else "补员 · 人数已满",service.bind("refill",id,"a"),0 if run.repair_coupon else 40,id in run.licenses and refill>0)
		Dot.mark(refill_button,id in free_refills,"本关免费补员待使用")
		var talent:=Market.talent_item(run,id)
		if not talent.is_empty():
			if talent.kind=="specialization":
				box.add_child(label("天赋专精 · 本兵种二选一",15,UiKit.COL_GOLD))
				box.add_child(label("当前天赋已满 3 级，下面是额外能力。覆盖本轮全部"+Army.training_name(id)+"及后续招募；本轮不能更换，其他兵种可独立选择。",13,UiKit.COL_DIM))
				for branch:String in ["a","b"]:
					box.add_child(label(Market.specialization_description(id,branch),13))
					cost_button(box,"选择"+("阵地" if branch=="a" else "机动")+"专精 · 200 补给",request_native.bind(id,branch),int(talent.price))
			else:
				box.add_child(label(Market.description(talent),13,UiKit.COL_DIM))
				cost_button(box,Catalog.name_of(talent)+" · "+str(talent.price)+" 补给",request_native.bind(id,"a"),int(talent.price))
		if run.specializations.has(id):
			box.add_child(label("已选天赋专精 · 本轮全体同兵种生效",15,UiKit.COL_GOLD))
			box.add_child(label(Market.specialization_description(id,str(run.specializations[id])),13))
		for special:Dictionary in run.special_squads:
			if special.id==id and int(special.count)>0:
				box.add_child(label("特装 %s ×%d · 全部天赋与同兵种共享"%[["","I","II","III"][special.tier],special.count],14,UiKit.COL_GOLD));break
	build_traits()

func request_native(id:String,branch:String) -> void:
	var item:=Market.talent_item(Expedition.state,id)
	if item.get("enable_disabled",false):confirm("这个自带天赋在养成里已关闭。仅为本轮启用并保留已拥有的等级？",service.bind("native",id,branch))
	else:service("native",id,branch)

func request_dismiss(id:String) -> void:
	confirm("遣散 1 个"+Army.training_name(id)+"，获得 %d 补给；优先移除普通单位，同类优先低军衔；不会遣散英雄。"%Catalog.dismissal_value(id),dismiss.bind(id))

func build_contact_archive() -> void:
	preload("res://scripts/expedition/field_guide.gd").add_archive(body)

func build_gain_summary(full:bool) -> void:
	var entries:Array=Expedition.state.get("gain_journal",[])
	if entries.is_empty():return
	var parent:Container=body
	if full:
		var fold:=FoldableContainer.new()
		fold.title="本轮收获记录 · 共 %d 条"%entries.size()
		fold.folded=false
		body.add_child(fold)
		parent=VBoxContainer.new()
		fold.add_child(parent)
	else:
		body.add_child(label("最近收获",17,UiKit.COL_GOLD))
	var last_stage:=-1
	for index in range(entries.size()-1,-1,-1):
		var entry:Dictionary=entries[index]
		if not full and index<entries.size()-3:break
		if full and last_stage!=int(entry.stage):
			last_stage=entry.stage
			parent.add_child(label("第 %d 关"%last_stage,17,UiKit.COL_GOLD))
		var prefix:="" if full else "第 %d 关 · "%entry.stage
		if entry.kind=="dialogue":
			var parts:=str(entry.text).split("\n",true,1)
			var story:=FoldableContainer.new()
			story.title=prefix+"新对话 · "+parts[0]
			story.folded=true
			parent.add_child(story)
			if parts.size()>1:story.add_child(label(parts[1],15))
			continue
		var line:=row(parent)
		var specs:Dictionary=Relics.ITEMS if entry.kind=="relics" else Army.TRAITS if entry.kind=="trait_buffs" else Catalog.BUFFS
		var item:Dictionary=specs[entry.id]
		if entry.kind=="relics":icon(line,item.icon,"glyph",26)
		var category:String={"relics":"藏品","buffs":"战术装备","trait_buffs":"羁绊"}[entry.kind]
		var change:="新获得" if int(entry.before)==0 else "升层"
		var levels:="第 %d 层"%entry.after if int(entry.before)==0 else "%d → %d 层"%[entry.before,entry.after]
		if entry.kind=="relics" and not item.has("max_level"):levels=""
		line.add_child(label(prefix+change+category+" · "+item.name+(" · "+levels if levels!="" else ""),15))

func build_history() -> void:
	build_gain_summary(true)
	build_contact_archive()
	body.add_child(label("战区联络人 · 约定支援",20,UiKit.COL_GOLD))
	for contact:Dictionary in Expedition.state.get("field_contacts",[]):body.add_child(label("%s\n%s\n约定第 %d 关独立友军参战 · %s"%[contact.name,contact.bio,contact.stage,"待赴约" if int(contact.stage)>=int(Expedition.state.stage) else "已赴约"],14,UiKit.COL_ACCENT_2))
	body.add_child(label(Insights.economy_text(Expedition.state),14,UiKit.COL_GOLD))
	for report:Dictionary in Expedition.state.get("battle_reports",[]):
		var box:=panel(body)
		box.add_child(label("第 %d 关 · %s"%[report.stage,Campaign.map_name(report.map)],18,UiKit.COL_GOLD))
		GiftNotice.add_report_rows(box,Expedition.state.id,report.stage)
		box.add_child(label(Insights.review_text(report),14))
	for item:Dictionary in Expedition.state.history:body.add_child(label("第 %d 关 · %s · 补给 +%d"%[item.stage,Campaign.map_name(item.map),item.supplies]+Income.history_text(Expedition.state,item,MetaProgress),15))
	body.add_child(label("本轮装备",20,UiKit.COL_GOLD))
	for id:String in Expedition.state.buffs:body.add_child(label(str(Catalog.BUFFS[id].name)+" Lv."+str(Expedition.state.buffs[id])+" · "+str(Catalog.BUFFS[id].desc),14))
	build_relics()

func build_relics() -> void:
	body.add_child(label("本轮圣遗物 · 持续藏品",22,UiKit.COL_GOLD))
	body.add_child(label("持有即生效，独立于战术装备；标有层数的藏品可重复获得至满层，本轮结束后清空。单位专属效果也适用于同兵种的特装与英雄。商店、战后奖励及章节首领奖励可获取。",14,UiKit.COL_DIM))
	var choices:=grid(body)
	var count:=0
	for id:String in Expedition.state.get("relics",{}):
		if not Relics.owned(Expedition.state,id) or not Relics.ITEMS.has(id):continue
		count+=1
		var spec:Dictionary=Relics.ITEMS[id]
		var box:=panel(choices);var line:=row(box);icon(line,str(spec.icon),"glyph")
		var suffix:=" · %d/%d 层"%[Relics.level(Expedition.state,id),spec.max_level] if spec.has("max_level") else ""
		line.add_child(label(Relics.grade(id)+" · "+str(spec.name)+suffix,17,Relics.tint(id)))
		box.add_child(label(Relics.description(id),14))
		if id==Growth.RELIC:box.add_child(label("本关免费强化可用" if Growth.free_available(Expedition.state) else "本关免费强化已用，下关恢复",14,UiKit.COL_ACCENT_2))
	if count==0:body.add_child(label("尚未获得持续藏品。军需商店固定出售 40 补给的战地教范。",14))

func result(ok:bool) -> void:
	if ok:build()
	else:show_error(Expedition.error if not Expedition.error.is_empty() else "当前条件不满足")
func sell_excess_personnel() -> void:result(Expedition.sell_excess_personnel())

func dismiss(id:String) -> void:result(Expedition.dismiss(id,1))
func service(kind:String,id:String,branch:String) -> void:result(Expedition.service(kind,id,branch))
func upgrade_unit(id:String,expected_price:int) -> void:result(Expedition.service("training",id,"a",expected_price))
func event_choice(index:int,token:String="") -> void:result(Expedition.resolve_event(index,token))
func request_discount_purchase(quote:Dictionary) -> void:
	var purchase:=func():result(Expedition.buy_discounts(quote))
	if quote.confirm_talent:confirm("折扣商品中含有你在养成中关闭的天赋。确认购买并在本轮启用？",purchase)
	else:purchase.call()

func lock_shop(index:int) -> void:result(Expedition.lock_shop(index))
func track(key:String) -> void:result(Expedition.track_trait(key))
func refresh_shop() -> void:result(Expedition.refresh_shop())
func repair() -> void:result(Expedition.repair())
func rescue(id:String) -> void:result(Expedition.rescue_hero(id))
func launch(index:int) -> void:
	if Expedition.launch(index):enter_battle()
	else:notice.text=Expedition.error
func resume() -> void:
	if Expedition.prepare_battle():enter_battle()
	else:notice.text=Expedition.error
func enter_battle() -> void:
	get_tree().paused=false;get_tree().change_scene_to_file("res://scenes/battle.tscn")
func leave() -> void:get_tree().change_scene_to_file("res://scenes/main.tscn")

func sell_equipment(id:String) -> void:result(Expedition.sell_equipment(id))
