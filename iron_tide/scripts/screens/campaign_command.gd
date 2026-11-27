extends Control
const Payout = preload("res://scripts/rules/campaign_payout.gd")
const Icons = preload("res://scripts/ui/resource_cost_icon.gd")
const SHEET := Vector2(1280,780)
const BG := Color("0b191e")
const PANEL := Color("142830")
const NAV := Color("12232d")
const BAR := Color("20353d")
const LINE := Color("304951")
const MINT := Color("82ddc9")
const GOLD := Color("f4c376")
const LIGHT := Color("eef2eb")
const MUTED := Color("b6c9cc")
var faction := ""
var mission: Dictionary = {}
var carry := false
var difficulty := 1
var page := Control.new()
var bold := FontVariation.new()

func _ready() -> void:
	bold.base_font = get_theme_default_font()
	bold.variation_embolden = 0.75
	var bg := ColorRect.new()
	bg.color = BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	page.size = SHEET
	resized.connect(fit_page)
	fit_page()
	draw_page()

func fit_page() -> void:
	var factor := minf(size.x/SHEET.x,size.y/SHEET.y)
	page.scale = Vector2.ONE * factor
	page.position = (size - SHEET*factor)*0.5

func rect(x:int,y:int,w:int,h:int,color:Color) -> void:
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(x,y)
	node.size = Vector2(w,h)
	node.color = color
	page.add_child(node)

func text(value:String,x:int,y:int,w:int,h:int,px:int,color:=LIGHT,heavy:=false) -> void:
	var node := UiKit.make_label(value,px,color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(x,y)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heavy: node.add_theme_font_override("font",bold)
	node.size = Vector2(w,h)
	page.add_child(node)

func style(fill:Color,border:Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	return box

func button(value:String,x:int,y:int,w:int,h:int,action:Callable,fill:=BAR,fg:=LIGHT,edge:=LINE) -> Button:
	var node := Button.new()
	node.text = value
	node.position = Vector2(x,y)
	node.size = Vector2(w,h)
	for state in ["normal","hover","pressed","disabled"]:
		node.add_theme_stylebox_override(state,style(fill.lightened(0.08) if state=="hover" else fill,edge))
		node.add_theme_color_override("font_color" if state=="normal" else "font_"+state+"_color",fg)
	node.add_theme_font_size_override("font_size",18)
	node.pressed.connect(action)
	page.add_child(node)
	return node

func home() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func groups() -> void:
	faction=""
	draw_page()

func draw_page() -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	text("IRON TIDE",38,6,260,32,23,GOLD,true)
	text("战役指挥室",36,39,460,60,42,LIGHT,true)
	var allied := faction=="allied"
	var group_name := "盟军" if allied else "苏军" if faction=="soviet" else "原创行动"
	text("大厅 › 战役" + (" › "+group_name if faction!="" else ""),1000,19,250,45,18,MUTED)
	rect(36,126,1208,620,LINE)
	rect(37,127,1206,618,PANEL)
	rect(37,127,1206,57,BAR)
	if faction=="":
		button("返回主菜单",43,132,195,44,home,BAR,MUTED,BAR)
		text("选择战役阵营",275,133,450,42,22,LIGHT,true)
		faction_emblems()
		return
	button("‹  返回阵营选择",42,133,192,43,groups,BAR,MUTED,BAR)
	text("任务简报",285,130,300,50,22,LIGHT,true)
	text("盟军 / 尤里的复仇" if allied else "苏军 / 尤里的复仇" if faction=="soviet" else "Iron Tide / 原创战役",1030,132,212,48,17,MUTED)
	rect(37,184,224,560,NAV)
	var crest:=Line2D.new()
	crest.position=Vector2(79,230)
	crest.points=PackedVector2Array([Vector2(-17,-11),Vector2(0,-17),Vector2(17,-11),Vector2(13,6),Vector2(0,16),Vector2(-13,6),Vector2(-17,-11)])
	crest.width=2
	crest.default_color=MINT
	crest.antialiased=true
	page.add_child(crest)
	text("✦",67,212,26,33,23,MINT,true)
	text("盟军战役" if allied else "苏军战役" if faction=="soviet" else "原创战役",106,205,150,48,23,LIGHT,true)
	text("可执行任务",58,263,160,30,16,MUTED)
	var y := 302
	for item in GameData.missions:
		if item.get("campaign_group","original")!=faction:continue
		var selected:bool=item.id==mission.id
		var title:String=str(item.name)
		var entry := button(title,48,y,207,78,select_mission.bind(item),Color("203e4a") if selected else NAV,LIGHT,NAV)
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		entry.add_theme_stylebox_override("normal",style(Color("203e4a") if selected else NAV,NAV))
		for state in ["normal","hover","pressed"]: entry.get_theme_stylebox(state).content_margin_left=15
		entry.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		entry.add_theme_font_override("font",bold)
		entry.add_theme_font_size_override("font_size",22)
		for state in ["normal","hover","pressed"]: entry.get_theme_stylebox(state).content_margin_top=24
		text("盟军任务 %s"%item.get("campaign_number","02") if allied else "苏军任务 %s"%item.get("campaign_number","07") if faction=="soviet" else "原创任务",64,y+6,104,23,14,MINT)
		if Payout.cleared(item.id): completion_badge(174,y+6)
		if selected: rect(48,y,4,78,MINT)
		y+=85
	button("‹  更换阵营",48,645,145,38,groups,NAV,MUTED,NAV)
	button("返回主菜单",48,690,145,38,home,NAV,MUTED,NAV)
	text(str(mission.get("map_title", "旧金山作战地图" if mission.id=="yr_time_shift" else "特兰西瓦尼亚作战地图" if faction=="soviet" else "来袭部队")),285,196,445,46,23,LIGHT,true)
	rect(285,248,454,296,LINE)
	rect(287,250,450,292,BG)
	if mission.has("map_layout"):
		var preview:=TextureRect.new()
		preview.texture=load("res://assets/maps/yr/%s_preview.png"%mission.map_layout)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.position=Vector2(287,250)
		preview.size=Vector2(450,292)
		page.add_child(preview)
	else:
		var n:=0
		for wave in mission.waves:
			text("%02d   %s"%[n+1,wave.name],307,260+n*41,410,38,18)
			n+=1
	text(mission.subtitle,285,550,450,38,16,MUTED)
	rect(285,600,454,1,LINE)
	text("作战目标",285,615,400,32,17,MINT)
	if mission.has("objectives_text"):
		text(mission.objectives_text,285,646,452,90,17)
	elif mission.id == "yr_time_shift":
		text("摧毁港口守军，登陆接管时光机。\n夺取科技发电厂供电，保护时光机完成充能。\n穿越时空后，摧毁恶魔岛的心灵控制器。",285,646,452,90,17)
	elif mission.id == "yr_head_games":
		text("摧毁两座心灵信标，接管苏军和盟军基地。\n摧毁尤里的城堡。",285,646,452,90,17)
	else: text(mission.brief,285,650,452,84,17)
	rect(761,206,1,518,LINE)
	text("盟军任务 %s"%mission.get("campaign_number","02") if allied else "苏军任务 %s"%mission.get("campaign_number","07") if faction=="soviet" else "原创任务",786,203,340,30,16,MINT)
	if Payout.cleared(mission.id): completion_badge(1146,207)
	text(mission.name,785,232,435,56,37,LIGHT,true)
	text(mission.subtitle,786,293,430,36,17)
	rect(786,337,430,1,LINE)
	text("通关奖励",785,351,220,42,24,LIGHT,true)
	if mission.has("first_win_reward"):
		text("可重复挑战",1119,352,110,40,16,MUTED)
		rewards_table()
	elif mission.get("endless",false): text("无尽挑战 · 按波数结算",786,418,427,68,20,GOLD)
	else: text("本关没有通关奖励",786,418,427,68,20,MUTED)
	rect(786,557,430,1,LINE)
	text("本关养成",786,571,280,40,22,LIGHT,true)
	for value:bool in [false,true]:
		var pick:=button("带入我的养成" if value else "原版配置",786+(218 if value else 0),620,211,44,set_growth.bind(value),Color("294640") if value==carry else BAR,MINT if value==carry else LIGHT,MINT if value==carry else LINE)
		if value==carry:pick.add_theme_font_override("font",bold)
	if faction in ["allied","soviet"]:
		var level:=OptionButton.new()
		for name_text in ["难度 · 简单","难度 · 普通","难度 · 困难"]:level.add_item(name_text)
		level.select(difficulty)
		level.position=Vector2(786,687)
		level.size=Vector2(175,42)
		var level_style:=style(BAR,MINT)
		level_style.content_margin_left=12
		level.add_theme_stylebox_override("normal",level_style)
		level.add_theme_font_size_override("font_size",18)
		level.item_selected.connect(set_difficulty)
		page.add_child(level)
	var launch_btn:=button("出击",1003,680,212,55,launch,GOLD,BG,GOLD)
	launch_btn.add_theme_font_size_override("font_size",24)
	launch_btn.add_theme_font_override("font",bold)

func completion_badge(x:int,y:int) -> void:
	rect(x,y,70,23,Color("356457"))
	rect(x+1,y+1,68,21,Color("203d37"))
	text("已完成",x+14,y,56,23,14,MINT,true)

func faction_emblems() -> void:
	var board := Sprite2D.new()
	board.centered = false
	board.texture = preload("res://assets/ra2/ui/campaign/background.png")
	board.position = Vector2(250, 196)
	board.scale = Vector2.ONE * 0.94
	page.add_child(board)
	for row in [
		["allied", Vector2(30,26), "盟军战役", 236],
		["original", Vector2(82,187), "Iron Tide 原创战役", 381],
		["soviet", Vector2(98,298), "苏军战役", 501]
	]:
		var id: String = row[0]
		var emblem := Sprite2D.new()
		emblem.name = id
		emblem.texture = load("res://assets/ra2/ui/campaign/%s.png" % id)
		emblem.hframes = 3
		emblem.vframes = 3
		emblem.centered = false
		emblem.position = row[1]
		board.add_child(emblem)
		var animation := emblem.create_tween().set_loops()
		animation.tween_method(func(value:int): emblem.frame=value, 0, 7, 0.8)
		var entry := button(row[2], 860, row[3], 277, 56, choose_faction.bind(id), PANEL, MINT if id=="allied" else MUTED, LINE)
		entry.mouse_entered.connect(Ra2Sfx.play.bind("CampaignFactionHover"))
		var hit := Button.new()
		hit.flat = true
		hit.position = emblem.position
		hit.size = emblem.texture.get_size() / 3.0
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.tooltip_text = row[2]
		board.add_child(hit)
		hit.mouse_entered.connect(Ra2Sfx.play.bind("CampaignFactionHover"))
		hit.pressed.connect(choose_faction.bind(id))

func badge(id:String,x:int,y:int) -> void:
	var icon:=TextureRect.new()
	icon.name="ResourceIcon"
	icon.texture=Icons.texture(id)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.position=Vector2(x,y)
	icon.size=Vector2(20,20)
	var host:=Control.new()
	host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(host)
	host.add_child(icon)

func rewards_table() -> void:
	rect(786,400,430,115,LINE)
	rect(787,401,428,113,BG)
	rect(797,438,408,1,LINE)
	text("已领首胜" if Payout.cleared(mission.id) else "首胜",798,441,88,32,16)
	text("重打胜利",798,476,88,32,16,MUTED)
	var first:=Payout.amount(mission,false)
	var again:=Payout.amount(mission,true)
	var x:=893
	for id in ["war_points","credits","diamonds"]:
		var color:Color={"war_points":GOLD,"credits":MINT,"diamonds":Color("99dcff")}[id]
		badge(id,x,410)
		text(MetaProgress.currency_name(id),x+23,402,80,34,16,color)
		text(str(first[id]),x,441,96,32,18)
		text(str(again[id]),x,476,96,32,19,color,true)
		x+=109
	text("重打可得首胜战略点和军需券的 5%。",786,518,430,32,16,MUTED)

func set_growth(value:bool) -> void:
	carry=value
	DisplayPreferences.campaign_growth = value
	DisplayPreferences.save()
	draw_page()

func set_difficulty(index:int) -> void:
	difficulty = index
	DisplayPreferences.campaign_difficulty = index
	DisplayPreferences.save()

func choose_faction(id:String) -> void:
	var voices := {"allied":"AlliedCampaignSelect", "soviet":"SovietCampaignSelect", "original":"BootCampSelect"}
	if voices.has(id): Ra2Sfx.play(voices[id])
	faction=id
	for item in GameData.missions:
		if item.get("campaign_group","original")==id:
			select_mission(item)
			return

func select_mission(item:Dictionary) -> void:
	mission=item
	carry=DisplayPreferences.campaign_growth
	difficulty=DisplayPreferences.campaign_difficulty if faction in ["allied","soviet"] else 1
	draw_page()

func launch() -> void:
	BattleRequest.configure_mission(mission.id,{"campaign_growth":carry,"country":"苏俄" if faction=="soviet" else "美国","difficulty":difficulty})
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
