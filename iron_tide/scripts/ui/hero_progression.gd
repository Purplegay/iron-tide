extends ScrollContainer

const Parameters=preload("res://scripts/rules/progression_parameters.gd")
const Academy = preload("res://scripts/rules/academy.gd")
const Portraits = preload("res://scripts/ui/hero_portraits.gd")
const Showcase = preload("res://scripts/ui/unit_showcase.gd")
const Icon = preload("res://scripts/ui/progression_icon.gd")
const HoldUpgrade = preload("res://scripts/ui/hold_upgrade_button.gd")
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")

var bookmarks = preload("res://scripts/ui/progression_bookmarks.gd").new()
var contract_panel:=preload("res://scripts/ui/furnace_contract_panel.gd").new()
var expansion_contract:=preload("res://scripts/ui/expansion_contract_panel.gd").new()
var selected := ""
var picker := OptionButton.new()
var portrait_switch := UiKit.make_button("", 16)
var hero_grid := GridContainer.new()
var hero_buttons:Dictionary={}
var preview := Showcase.new()
var talent_demo:=preload("res://scripts/ui/hero_talent_demo.gd").new()
var trial := CheckButton.new()
var skin_description := Label.new()
var progress_label := preload("res://scripts/ui/hero_production_requirement.gd").new()
var affinity := Label.new()
var reward_toggle := Button.new()
var reward_panel := VBoxContainer.new()
var reward_page := OptionButton.new()
var reward_list := Label.new()
const REWARD_PAGE_SIZE := 10
var firepower := HoldUpgrade.new()
var health := HoldUpgrade.new()
var outfit := Button.new()
var survival := Button.new()
var survival_detail := RichTextLabel.new()
var escort := Button.new()
var escort_detail := RichTextLabel.new()
var escort_title:Label
var survival_title:Label
var equipment=preload("res://scripts/ui/hero_equipment.gd").new()

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(UiKit.make_label("英雄养成", 23, UiKit.COL_ACCENT_2))
	column.add_child(picker)
	picker.hide()
	hero_grid.columns=2
	hero_grid.add_theme_constant_override("h_separation",8)
	hero_grid.add_theme_constant_override("v_separation",8)
	column.add_child(hero_grid)
	portrait_switch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(portrait_switch)
	portrait_switch.pressed.connect(_switch_portrait)
	column.add_child(UiKit.make_label("英雄解锁与出场",18,UiKit.COL_ACCENT_2))
	progress_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(progress_label)
	column.add_child(contract_panel)
	column.add_child(expansion_contract)
	preview.hero_gallery=true
	column.add_child(preview)
	column.add_child(trial)
	column.add_child(outfit)
	skin_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skin_description)
	column.add_child(UiKit.make_label("点击暂停，按住左右拖动查看朝向。",12,UiKit.COL_DIM))
	column.add_child(equipment)
	column.add_child(talent_demo)
	var continuity_toggle:=UiKit.make_button("查看保存恢复示意")
	continuity_toggle.name="ContinuityDemoToggle";continuity_toggle.toggle_mode=true;column.add_child(continuity_toggle)
	var continuity_host:=VBoxContainer.new();continuity_host.name="ContinuityDemoHost";column.add_child(continuity_host);continuity_host.hide()
	continuity_toggle.toggled.connect(func(open:bool):
		if open and continuity_host.get_child_count()==0:
			var demo=preload("res://scripts/ui/state_continuity_demo.gd").new()
			demo.name="StateContinuityDemo";continuity_host.add_child(demo)
		continuity_host.visible=open
		continuity_toggle.text="收起保存恢复示意" if open else "查看保存恢复示意")
	for label in [affinity]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	var help := UiKit.make_label("好感经验　出场 +10　击杀 +5　助攻 +2　参战获胜 +20。升级奖励在结算时自动发放。",14,UiKit.COL_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	reward_toggle.text="预览好感度奖励"
	reward_toggle.toggle_mode=true
	column.add_child(reward_toggle)
	column.add_child(reward_panel)
	reward_panel.hide()
	reward_panel.add_child(reward_page)
	reward_panel.add_child(reward_list)
	for first in range(1,Academy.AFFINITY_CAP+1,REWARD_PAGE_SIZE):
		reward_page.add_item("Lv.%d ～ %d" % [first,mini(first+REWARD_PAGE_SIZE-1,Academy.AFFINITY_CAP)])
	reward_toggle.toggled.connect(func(open:bool):
		reward_panel.visible=open
		if open: _show_current_rewards())
	reward_page.item_selected.connect(_show_reward_page)
	column.add_child(UiKit.make_label("英雄训练",18,UiKit.COL_ACCENT_2))
	column.add_child(firepower)
	column.add_child(health)
	escort_title=UiKit.make_label("英雄专属天赋 · 随行护卫",18,UiKit.COL_ACCENT_2)
	column.add_child(escort_title)
	for detail in [escort_detail,survival_detail]:
		detail.bbcode_enabled=true
		detail.fit_content=true
		detail.scroll_active=false
		detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
		detail.add_theme_font_size_override("normal_font_size",skin_description.get_theme_font_size("font_size"))
	escort_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(escort_detail)
	column.add_child(escort)
	escort.pressed.connect(_purchase.bind("escort"))
	survival_title=UiKit.make_label("英雄专属天赋 · 战场生存",18,UiKit.COL_ACCENT_2)
	column.add_child(survival_title)
	survival_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(survival_detail)
	column.add_child(survival)
	survival.pressed.connect(_purchase.bind("survival"))
	picker.item_selected.connect(func(index):
		_cancel_training_hold()
		bookmarks.remember(self)
		selected = picker.get_item_metadata(index)
		bookmarks.set_value("hero",selected)
		bookmarks.save()
		refresh()
		bookmarks.restore(self,"hero/"+selected))
	trial.toggled.connect(_try_skin)
	firepower.purchase = _purchase.bind("firepower")
	health.purchase = _purchase.bind("health")
	outfit.pressed.connect(_purchase.bind("skin"))

func _purchase(action: String) -> bool:
	if not Academy.purchase(MetaProgress,action,selected):
		Events.emit_message("操作未完成，请检查解锁条件、余额或存档。",UiKit.COL_WARN)
		return false
	elif action == "skin":
		trial.button_pressed = MetaProgress.academy.get("hero_skin",{}).get(selected,false)
		refresh()
	return true

func _cancel_training_hold() -> void:
	firepower.cancel_hold()
	health.cancel_hold()

func _try_skin(enabled: bool) -> void:
	preview.actor.special.academy_hero = selected
	preview.actor.special.hero_skin = enabled
	if selected=="TTNK":preload("res://scripts/units/leizhu_art.gd").install_preview(preview.actor)
	if selected=="ORCA":preload("res://scripts/units/peregrine_visual.gd").install_preview(preview.actor)
	preview.refresh_outfit()

func open_page() -> void:
	bookmarks.remember(self)
	_cancel_training_hold()
	var state := MetaProgress.academy
	var builds: Dictionary = state.get("hero_builds",{})
	var recent: Array = state.get("hero_recency",[])
	var ids := Academy.HEROES.keys()
	ids.sort_custom(func(a,b):
		var count_a := int(builds.get(a,0))
		var count_b := int(builds.get(b,0))
		var unlocked_a := count_a >= Academy.hero_requirement(a)
		if unlocked_a != (count_b >= Academy.hero_requirement(b)): return unlocked_a
		var pos_a := recent.find(a)
		var pos_b := recent.find(b)
		if pos_a != pos_b: return pos_a >= 0 and (pos_b < 0 or pos_a < pos_b)
		if count_a != count_b: return count_a > count_b
		return a < b)
	picker.clear()
	for child in hero_grid.get_children():hero_grid.remove_child(child);child.queue_free()
	hero_buttons.clear()
	for id in ids:
		var locked := " · 未解锁" if int(builds.get(id,0)) < Academy.hero_requirement(id) else ""
		var unit_name:String=GameData.get_unit(id).name
		var hero_name:String=Academy.HEROES[id]
		picker.add_item((hero_name if unit_name==hero_name else "%s · %s"%[unit_name,hero_name])+locked)
		picker.set_item_metadata(picker.item_count-1,id)
		var button:=UiKit.make_button("")
		button.icon=Portraits.texture(id)
		button.add_theme_constant_override("icon_max_width",60)
		button.name="HeroSelect_"+id;button.toggle_mode=true
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y=52
		button.pressed.connect(_select_hero.bind(id))
		hero_grid.add_child(button);hero_buttons[id]=button
	if selected.is_empty():selected=str(bookmarks.get_value("hero",""))
	if not ids.has(selected):selected=ids[0]
	picker.select(ids.find(selected))
	bookmarks.set_value("hero",selected)
	refresh()
	bookmarks.restore(self,"hero/"+selected)

func _select_hero(id:String) -> void:
	for index in picker.item_count:
		if picker.get_item_metadata(index)==id:
			picker.select(index)
			picker.item_selected.emit(index)
			return

func _switch_portrait() -> void:
	if Portraits.choose_driver(selected, not Portraits.showing_driver(selected)):
		hero_buttons[selected].icon = Portraits.texture(selected)
		portrait_switch.text = Portraits.switch_action(selected)
	else:
		portrait_switch.text = "保存失败，点击重试"

func _refresh_hero_buttons() -> void:
	for id:String in hero_buttons:
		var requirement:=Academy.hero_requirement(id)
		var count:=Academy.hero_build_count(MetaProgress,id)
		var status:="已解锁" if count>=requirement else "未解锁 · %d / %d"%[count,requirement]
		var unit_name:String=GameData.get_unit(id).name
		if id=="ORCA":status+=" · 多机型合计"
		elif unit_name!=Academy.HEROES[id]:status+=" · "+unit_name
		hero_buttons[id].text=Academy.HEROES[id]+"\n"+status
		hero_buttons[id].set_pressed_no_signal(id==selected)
		Upgrade.mark(hero_buttons[id],Upgrade.hero(id))

func _reward_text(level:int) -> String:
	var reward:=Academy.affinity_reward(level)
	var parts:=PackedStringArray()
	for key in reward:
		parts.append("%d %s" % [reward[key],MetaProgress.currency_name(key)])
	return " ＋ ".join(parts)

func _show_current_rewards() -> void:
	var level:=Academy.affinity_level(int(MetaProgress.academy.get("affinity",{}).get(selected,0)))
	var page:=mini(level,Academy.AFFINITY_CAP-1)/REWARD_PAGE_SIZE
	reward_page.select(page)
	_show_reward_page(page)

func _show_reward_page(page:int) -> void:
	var reached:=Academy.affinity_level(int(MetaProgress.academy.get("affinity",{}).get(selected,0)))
	var first:=page*REWARD_PAGE_SIZE+1
	var rows:=PackedStringArray()
	for level in range(first,mini(first+REWARD_PAGE_SIZE,Academy.AFFINITY_CAP+1)):
		var status:="已发放" if level<=reached else ("下一级" if level==reached+1 else "未达到")
		rows.append("Lv.%d　%s　·　%s" % [level,_reward_text(level),status])
	reward_list.text="\n".join(rows)

func _training_button(button:Button,track:String,title:String,unlocked:bool) -> void:
	var level:=Academy.training_rank(MetaProgress.academy.get("hero_training",{}),selected,track)
	var cap:=Academy.training_cap(track)
	var cost:=Academy.hero_training_cost(level)
	var description:="%s训练 Lv.%d / %d　·　+%s%%" % [title,level,cap,Academy.skill_number(Academy.training_percent(track,level))]
	if level<cap:description+=" → +%s%%　·"%Academy.skill_number(Academy.training_percent(track,level+1))
	else:description+="　·　已满级"
	button.disabled=not unlocked or level>=cap or MetaProgress.balance("credits")<cost
	var row:=button.get_node_or_null("TrainingPrice") as HBoxContainer
	if row==null:
		row=HBoxContainer.new()
		row.name="TrainingPrice"
		row.alignment=BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var label:=UiKit.make_label("",16)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		var price_label:=preload("res://scripts/ui/resource_cost_icon.gd").balance_label(row,"credits","",16,UiKit.COL_GOLD)
		price_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		price_label.get_parent().mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.get_child(0).text=description
	var price_row:=row.get_child(1) as HBoxContainer
	price_row.visible=level<cap
	price_row.get_child(1).text="%d 军需券"%cost
	row.modulate=Color(0.65,0.65,0.65) if button.disabled else Color.WHITE
	button.accessibility_name=description+(" %d 军需券"%cost if level<cap else "")
	button.custom_minimum_size=row.get_combined_minimum_size()+Vector2(16,8)
	Upgrade.mark(button,false)

func refresh() -> void:
	_refresh_hero_buttons()
	portrait_switch.visible = selected in Portraits.DRIVER_IDS
	if portrait_switch.visible:
		portrait_switch.disabled = not Portraits.driver_unlocked(selected)
		portrait_switch.text = Portraits.DRIVER_UNLOCK_HINT if portrait_switch.disabled else Portraits.switch_action(selected)
	Upgrade.mark(escort,Upgrade.hero_talent(selected,"escort"))
	Upgrade.mark(survival,Upgrade.hero_talent(selected,"survival"))
	expansion_contract.refresh(selected)
	contract_panel.visible=selected=="E2"
	if contract_panel.visible:contract_panel.refresh()
	equipment.refresh(selected)
	var state := MetaProgress.academy
	var builds := Academy.hero_build_count(MetaProgress,selected)
	var unlocked := builds >= Academy.hero_requirement(selected)
	var xp := int(state.get("affinity",{}).get(selected,0))
	var equipped := bool(state.get("hero_skin",{}).get(selected,false))
	var tank_hero:=selected in Unit.TankHero.IDS
	trial.visible=true
	outfit.visible=true
	skin_description.visible=true
	var skin_name:String={"TANY":"霓虹断线","BORIS":"汽水假日","FV":"雨幕放映师","HARV":"第九地磅","E1":"极夜哨兵","E2":"炉前赤卫","MTNK":"北辰 · 星铠","HTNK":"铁脊 · 熔炉"}.get(selected,"")
	talent_demo.show_hero(selected)
	var changed_hero:=preview.unit_id != selected
	if changed_hero:
		preview.show_unit(selected)
		trial.set_pressed_no_signal(equipped)
		_try_skin(equipped)
	trial.text = "试穿英雄装甲 · " + skin_name
	skin_description.text = "%s · %s" % [skin_name,MetaProgress.Cosmetics.HERO_SKIN_TEXT.get(selected,"")]
	progress_label.show_requirement(selected,builds)
	var level:=Academy.affinity_level(xp)
	affinity.text="好感度 Lv.%d / %d" % [level,Academy.AFFINITY_CAP]
	if level<Academy.AFFINITY_CAP:
		affinity.text+="　·　本级经验 %d / 100　·　下一级 %s" % [xp%100,_reward_text(level+1)]
	else: affinity.text+="　·　全部奖励已发放"
	if reward_panel.visible:
		if changed_hero: _show_current_rewards()
		else: _show_reward_page(reward_page.selected)
	_training_button(firepower,"firepower","火力",unlocked)
	_training_button(health,"health","生命",unlocked)
	outfit.text = ("当前英雄皮肤：%s　·　换回英雄原版" % skin_name) if equipped else ("当前英雄皮肤：原版　·　装备%s" % skin_name)
	outfit.disabled = not unlocked
	if selected=="ORCA":
		_refresh_peregrine()
		return
	if selected=="TTNK":
		_refresh_leizhu()
		return
	if selected in ["FV","HARV"]:
		_refresh_commando(unlocked)
		outfit.disabled=not unlocked or not state.get("hero_contracts",{}).get(selected,{}).get("complete",false)
		if outfit.disabled:outfit.text="完成英雄契约后可装备"+skin_name
		return
	if selected in Academy.Commandos.IDS:
		_refresh_commando(unlocked)
		return
	escort_title.text="英雄专属天赋 · 战术中枢" if tank_hero else "英雄专属天赋 · 随行护卫"
	survival_title.text="英雄专属天赋 · 重装生存" if tank_hero else "英雄专属天赋 · 战场生存"
	var talent:=clampi(int(state.get("hero_escort_ranks",{}).get(selected,0)),0,Academy.ESCORT_RANKS.size()-1)
	var maxed:=talent==Academy.ESCORT_RANKS.size()-1
	escort_detail.text="英雄自身射程 +1 格。英雄出厂时，%s护卫随队出厂并前往兵营集结点。\n当前 Lv.%d　%s" % [GameData.get_unit(selected).name,talent,Academy.escort_description(talent)]
	if not maxed: escort_detail.text+="\n下一级　"+Academy.escort_description(talent+1)
	if tank_hero:
		escort_detail.text="英雄自身射程 +1 格。\n"
		for i in Unit.TankHero.COMMAND.size():escort_detail.text+="Lv.%d　%s　%s\n" % [i,_talent_status(unlocked and i<=talent),Unit.TankHero.COMMAND[i]]
	escort.icon=Icon.texture("hero_command_"+selected if tank_hero else "hero_escort_"+selected)
	var escort_cost:=Academy.hero_talent_cost("escort",talent)
	escort.text=("解锁英雄后开启" if not unlocked else ("随行护卫已满级" if maxed else "强化护卫 · %d 战略核心" % escort_cost))
	if tank_hero:escort.text=("解锁英雄后开启" if not unlocked else ("战术中枢已满级" if maxed else "升级战术中枢 · %d 战略核心" % escort_cost))
	if escort.text.contains("战略核心"):escort.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
	escort.disabled=not unlocked or maxed or escort_cost<=0 or MetaProgress.balance("cores")<escort_cost
	var rank:=clampi(int(state.get("hero_survival_ranks",{}).get(selected,0)),0,Academy.SURVIVAL_STAGES.size()-1)
	var stages:=PackedStringArray()
	for i in Academy.SURVIVAL_STAGES.size():
		stages.append("Lv.%d　%s　%s" % [i,_talent_status(unlocked and i<=rank),(Unit.TankHero.DEFENSE if tank_hero else Academy.SURVIVAL_STAGES)[i]])
	survival_detail.text="\n".join(stages)
	survival.icon=Icon.texture("hero_survival_"+selected)
	var survival_cost:=Academy.hero_talent_cost("survival",rank)
	survival.text="解锁英雄后开启" if not unlocked else ("战场生存已满级" if rank==5 else "升级战场生存 · %d 战略核心" % survival_cost)
	if survival.text.contains("战略核心"):survival.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
	survival.disabled=not unlocked or rank==5 or survival_cost<=0 or MetaProgress.balance("cores")<survival_cost

static func _talent_status(active:bool) -> String:
	return "[color=#%s]%s[/color]" % [(UiKit.COL_OK if active else UiKit.COL_DIM).to_html(false),"已生效" if active else "待解锁"]

func _refresh_commando(unlocked:bool) -> void:
	var convoy:=selected in ["FV","HARV"]
	var titles:Array=Unit.Convoy.Talents.TITLES[selected] if convoy else Academy.Commandos.TITLES[selected]
	escort_title.text="英雄专属天赋 · "+str(titles[0])
	survival_title.text="英雄专属天赋 · "+str(titles[1])
	for i in 2:
		var detail=escort_detail if i==0 else survival_detail
		var button=escort if i==0 else survival
		if convoy or selected in ["TANY","BORIS"]:
			var action:="escort" if i==0 else "survival"
			var key:="hero_escort_ranks" if i==0 else "hero_survival_ranks"
			var rank:=clampi(int(MetaProgress.academy.get(key,{}).get(selected,0)),0,5)
			var traits:Array=preload("res://scripts/units/tanya_talents.gd").COMMAND if i==0 else preload("res://scripts/units/tanya_talents.gd").DEFENSE
			if selected=="BORIS":traits=preload("res://scripts/units/boris_command.gd").COMMAND if i==0 else preload("res://scripts/units/boris_radio.gd").DEFENSE
			if convoy:traits=Unit.Convoy.Talents.TRAITS[selected][i]
			detail.text=""
			for level in 6:detail.text+="Lv.%d　%s　%s\n"%[level,_talent_status(unlocked and level<=rank),traits[level]]
			var cost:=Academy.hero_talent_cost(action,rank,selected)
			button.icon=Icon.texture("attack" if i==0 else "guard")
			button.text="解锁英雄后开启" if not unlocked else ("已满级" if rank>=5 else "升级%s · %d 战略核心"%[titles[i],cost])
			if button.text.contains("战略核心"):button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
			button.disabled=not unlocked or rank>=5 or cost<=0 or MetaProgress.balance("cores")<cost
			continue
		detail.text="Lv.0　%s　%s\nLv.1～5 将在后续批次开放；专属双卡见上方英雄契约。"%[_talent_status(unlocked),Academy.Commandos.BASE_TEXT[selected][i]]
		button.icon=Icon.texture("attack" if i==0 else "guard")
		button.text="后续等级尚未开放"
		button.disabled=true

func _exit_tree() -> void:
	if visible:bookmarks.remember(self,true)
	bookmarks.save()

func _refresh_peregrine() -> void:
	trial.hide();outfit.hide();skin_description.show()
	skin_description.text="极地游隼 · 英雄自带外观。白金翼甲、双涡轮与阵营标识；悬停时发动机呼吸发光，降落收束气流，迫降后熄灯。"
	var count:=Academy.hero_build_count(MetaProgress,"ORCA")
	var unlocked:=count>=Academy.hero_requirement("ORCA")
	var P=preload("res://scripts/units/peregrine.gd")
	for i in 2:
		var title=escort_title if i==0 else survival_title
		var detail=escort_detail if i==0 else survival_detail
		var button=escort if i==0 else survival
		title.text="英雄专属天赋 · "+P.TITLES[i]
		if i==0:
			var rank:=clampi(int(MetaProgress.academy.get("hero_escort_ranks",{}).get("ORCA",0)),0,5)
			var cost:=Academy.hero_talent_cost("escort",rank,"ORCA")
			detail.text="当前 Lv.%d / 5 · 基础空中补弹 %s 秒/发；每升一级缩短 %s 秒。\n"%[rank,Academy.skill_number(maxf(.1,Parameters.number("hero/ORCA/command","reload_base")-rank*Parameters.number("hero/ORCA/command","reload_per_rank"))),Academy.skill_number(Parameters.number("hero/ORCA/command","reload_per_rank"))]
			for level in P.Command.COMMAND.size():
				detail.text+="Lv.%d　%s　%s\n"%[level,_talent_status(unlocked and level<=rank),P.Command.COMMAND[level]]
			button.text="已满级" if rank==5 else "升级王牌航线 · %d 战略核心"%cost
			if button.text.contains("战略核心"):button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
			button.disabled=rank==5 or MetaProgress.balance("cores")<cost
		else:
			var rank:=clampi(int(MetaProgress.academy.get("hero_survival_ranks",{}).get("ORCA",0)),0,P.Defense.OPEN_RANK)
			var cost:=Academy.hero_talent_cost("survival",rank,"ORCA")
			detail.text=""
			for level in P.Defense.DEFENSE.size():
				detail.text+="Lv.%d　%s　%s\n"%[level,_talent_status(unlocked and level<=rank),P.Defense.DEFENSE[level]]
			button.text="已满级" if rank==P.Defense.OPEN_RANK else "升级滞空保障 · %d 战略核心"%cost
			if button.text.contains("战略核心"):button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
			button.disabled=rank==P.Defense.OPEN_RANK or MetaProgress.balance("cores")<cost
		if not unlocked:button.text="解锁英雄后开启";button.disabled=true

func _refresh_leizhu() -> void:
	trial.hide();outfit.hide();skin_description.show()
	skin_description.text="铜冕雷炉 · 英雄自带外观。铜环线圈、阵营装甲与琥珀炉芯；供电时增强亮度，停堆时熄灯。"
	var count:=Academy.hero_build_count(MetaProgress,"TTNK")
	var unlocked:=count>=Academy.hero_requirement("TTNK")
	var L=preload("res://scripts/units/leizhu.gd")
	for i in 2:
		var title=escort_title if i==0 else survival_title
		var detail=escort_detail if i==0 else survival_detail
		var button=escort if i==0 else survival
		title.text="英雄专属天赋 · "+L.TITLES[i]
		var defense=preload("res://scripts/units/leizhu_defense.gd")
		var defense_rank:=clampi(int(MetaProgress.academy.get("hero_survival_ranks",{}).get("TTNK",0)),0,defense.OPEN_RANK)
		detail.text=""
		for level in defense.OPEN_RANK+1:detail.text+="Lv.%d　%s　%s\n"%[level,_talent_status(unlocked and level<=defense_rank),defense.DEFENSE[level]]

		var defense_cost:=Academy.hero_talent_cost("survival",defense_rank,"TTNK")
		button.text="已满级" if defense_rank>=defense.OPEN_RANK else "升级过载保险 · %d 战略核心"%defense_cost
		if button.text.contains("战略核心"):button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
		button.disabled=defense_rank>=defense.OPEN_RANK or defense_cost<=0 or MetaProgress.balance("cores")<defense_cost
		if i==0:
			var command=preload("res://scripts/units/leizhu_command.gd")
			var rank:=clampi(int(MetaProgress.academy.get("hero_escort_ranks",{}).get("TTNK",0)),0,command.OPEN_RANK)
			detail.text=""
			for level in command.OPEN_RANK+1:detail.text+="Lv.%d　%s　%s\n"%[level,_talent_status(unlocked and level<=rank),command.COMMAND[level]]

			var cost:=Academy.hero_talent_cost("escort",rank,"TTNK")
			button.text="已满级" if rank>=command.OPEN_RANK else "升级移动变电站 · %d 战略核心"%cost
			if button.text.contains("战略核心"):button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
			button.disabled=rank>=command.OPEN_RANK or cost<=0 or MetaProgress.balance("cores")<cost
		if not unlocked:button.text="解锁英雄后开启";button.disabled=true
