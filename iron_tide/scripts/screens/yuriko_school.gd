extends Control

const Unread=preload("res://scripts/units/yuriko_unread.gd")
const Book=preload("res://scripts/units/yuriko_school.gd")
const Bonds=preload("res://scripts/units/yuriko_bonds.gd")
const Psi=preload("res://scripts/units/yuriko.gd")
const CLASSROOM=preload("res://assets/ra3/yuriko/school_days/classroom.png")
const HARBOR=preload("res://assets/ra3/yuriko/school_days/harbor.png")
const ACTIVITIES=preload("res://assets/ra3/yuriko/school_days/activities.png")
const PORTRAIT_SHEET=preload("res://assets/ra3/yuriko/school_days/story_portraits.png")
const SWIM_PORTRAIT=preload("res://assets/ra3/yuriko/school_days/story_swim.png")
const GIFT_PORTRAITS := [
	preload("res://assets/ra3/yuriko/school_days/gift_blush_rescue.png"),
	preload("res://assets/ra3/yuriko/school_days/gift_blush_casual.png"),
	preload("res://assets/ra3/yuriko/school_days/gift_blush_uniform.png"),
	preload("res://assets/ra3/yuriko/Portrait_Yuriko_Wedding.png"),
]
const SPEAKER_PORTRAITS:={
	"小满":preload("res://assets/ra3/yuriko/school_days/cast/xiaoman.webp"),
	"陈姨":preload("res://assets/ra3/yuriko/school_days/cast/chen.webp"),
	"路人甲":preload("res://assets/ra3/yuriko/school_days/cast/passerby_a.webp"),
	"路人乙":preload("res://assets/ra3/yuriko/school_days/cast/passerby_b.webp"),
	"路人丙":preload("res://assets/ra3/yuriko/school_days/cast/passerby_c.webp"),
	"路人丁":preload("res://assets/ra3/yuriko/school_days/cast/passerby_d.webp"),
}
const TOWNSPEOPLE:={
	"鱼摊叔叔":"路人甲", "店主":"路人甲", "体育老师":"路人甲",
	"园艺委员":"路人乙", "部长":"路人乙",
	"修车阿姨":"路人丙", "老师":"路人丙", "家政老师":"路人丙",
	"图书委员":"路人丁",
}
const INK:=Color("#203836")
const TEAL:=Color("#276b62")
const PAPER:=Color("#fbf7ebf5")
const WARM:=Color("#f4dfac")
const VIEW_NAMES:=["手记","日常活动","灵能练习","试衣间","私信与礼物","场景"]
const DETAILS:={"Shield":["护盾持续 5 秒","护盾持续 7 秒","护盾持续 9 秒"],"Lure":["最多控制 3 名步兵","最多控制 5 名步兵","最多控制 7 名步兵"],"Slam":["举起半径 22.5，冷却 5 秒","举起半径 30，冷却 4 秒","举起半径 37.5，冷却 3 秒"],"Speed":["基础移速 ×1.15","基础移速累计 ×1.3225"],"Health":["生命上限 ×1.15","生命上限累计 ×1.3225"],"AttackDamage":["攻击 ×1.25","攻击累计 ×1.5625"]}

var shop_day:=""
var shop_wallet:Label
var shop_count:=0
var reroll_button:Button
var buy_buttons:Dictionary={}
var give_buttons:Dictionary={}
var daily_scenes:Dictionary={}
var scenery:TextureRect
var stage:Control
var message:Label
var tab:=0
var from_base:=false
var from_cg_collection:=false
var current:Dictionary={}
var model
var photo:TextureRect
var pose:="STATE_bored"
var preview_playing:=true
var zoom:=1.0
var drag:=false
const HUB_PORTRAITS := ["uniform", "casual", "rescue", "swim"]
var hub_portrait_index := 0
var actor_layer:TextureRect
var story_portraits:Dictionary={"swim":SWIM_PORTRAIT}

func _ready() -> void:
	from_base=get_tree().get_meta("yuriko_from_base",false)
	if from_base:get_tree().remove_meta("yuriko_from_base")
	from_cg_collection=get_tree().get_meta("yuriko_from_cg_collection",false)
	if from_cg_collection:get_tree().remove_meta("yuriko_from_cg_collection")
	scenery=TextureRect.new()
	scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outfits:=["rescue","casual","uniform"]
	var side:=PORTRAIT_SHEET.get_height()
	for i in outfits.size():
		var portrait:=AtlasTexture.new()
		portrait.atlas=PORTRAIT_SHEET
		portrait.region=Rect2(i*side,0,side,side)
		portrait.filter_clip=true
		story_portraits[outfits[i]]=portrait
	actor_layer=TextureRect.new()
	actor_layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	actor_layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	actor_layer.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(actor_layer)
	actor_layer.anchor_left=.47
	actor_layer.anchor_right=.94
	actor_layer.anchor_top=.055
	actor_layer.anchor_bottom=.61
	actor_layer.hide()
	stage=Control.new()
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub(8 if from_cg_collection else (1 if Book.contact_ready() else 0))

func label(parent:Control,value:String,px:int,color:=INK) -> Label:
	var item:=Label.new()
	item.text=value
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",px)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item

func paper(color:Color,pad:int,radius:int=6)->StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,pad)
	return style

func button(parent:Control,value:String,action:Callable,primary:=false) -> Button:
	var b:=Button.new()
	b.text=value
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_stylebox_override("normal",paper(TEAL if primary else Color("#edf0e7"),9))
	b.add_theme_stylebox_override("hover",paper(Color("#317b6e"),9))
	b.add_theme_stylebox_override("pressed",paper(INK,9))
	b.add_theme_stylebox_override("disabled",paper(Color("#e9e7df"),9))
	b.add_theme_color_override("font_color",Color.WHITE if primary else INK)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.WHITE)
	b.add_theme_color_override("font_disabled_color",Color("#696e68"))
	if action.is_valid():b.pressed.connect(action)
	parent.add_child(b)
	return b

func source_row(list:VBoxContainer, hint:String) -> HBoxContainer:
	var row := HBoxContainer.new()
	list.add_child(row)
	var help := button(row,"?",show_source.bind(hint))
	help.icon = preload("res://scripts/ui/progression_icon.gd").texture("handbook")
	help.tooltip_text = hint
	help.accessibility_name = "查看来源。" + hint
	return row

func show_source(hint:String) -> void:
	message.text = hint

func episode_source(ep:Dictionary) -> String:
	if ep.has("diary_cost"):
		return "在远征中完成奖励含「日常日记」的小队目标并获胜，可得一本。与百合子相遇后，可用日记永久解锁这篇活动。"
	var previous := int(ep.unlock)
	if previous == 0:
		return "派地面部队寻找远征战区的雨棚（战场情报达到 2 级后会标出位置），听到饭盒声后获胜，即可带回第一章。"
	if ep.kind != "chapter":
		return "读完第 %d 章学期手记，这篇活动就会开放。" % previous
	if previous < 4:
		return "读完第 %d 章，再进入远征，派部队取回粉色标记的日常日记并获胜，即可带回下一章。" % previous
	return "读完第 %d 章并招募百合子，再进入远征，让她亲自取回「秘密档案」并获胜，即可带回下一章。" % previous

func panel(rect:Rect2,color:Color,pad:int) -> VBoxContainer:
	var box:=PanelContainer.new()
	stage.add_child(box)
	box.anchor_left=rect.position.x
	box.anchor_top=rect.position.y
	box.anchor_right=rect.end.x
	box.anchor_bottom=rect.end.y
	box.add_theme_stylebox_override("panel",paper(color,pad))
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	box.add_child(column)
	return column

func clear_view() -> void:
	buy_buttons.clear()
	give_buttons.clear()
	shop_wallet=null
	drag=false
	model=null
	photo=null
	message=null
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()

func scrolling(parent:Control) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.name="PageScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var entries:=VBoxContainer.new()
	entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation",7)
	scroll.add_child(entries)
	return entries

func place_portrait(portrait:Control) -> void:
	stage.add_child(portrait)
	portrait.anchor_left = 0.62
	portrait.anchor_right = 0.93
	portrait.anchor_top = 0.17
	portrait.anchor_bottom = 0.87

const SCENE_NAMES := ["南汐高中", "港口", "面包房", "游泳池", "屋顶菜园", "图书室", "家政教室", "广播室", "鱼市", "海边站台", "观星台"]

func scene_index(ep:Dictionary) -> int:
	if ep.has("art_cell"):
		return 2 + int(ep.art_cell)
	return 1 if ep.get("background") == "harbor" else 0

func unlocked_scenes() -> Dictionary:
	var unlocked := {0:true}
	var read:Dictionary = MetaProgress.yuriko_school.get("read", {})
	for ep:Dictionary in Book.episodes + Bonds.stories + Book.affinity_stories:
		if read.has(ep.id):
			unlocked[scene_index(ep)] = true
	return unlocked

func select_scene(index:int) -> void:
	if not unlocked_scenes().has(index):
		return
	var next := MetaProgress.yuriko_school.duplicate(true)
	next.hub_scene = index
	if Book.commit(next):
		hub(tab)
	else:
		message.text = "场景未能保存，请重试。"

func hub(index:int) -> void:
	clear_view()
	current={}
	actor_layer.hide()
	actor_layer.texture=null
	tab=index
	var unlocked := unlocked_scenes()
	var selected := int(MetaProgress.yuriko_school.get("hub_scene", 0))
	if not unlocked.has(selected):
		selected = 0
	scenery.material = null
	scenery.texture = scene_texture(selected)
	if tab in [0, 1, 2, 6]:
		var portrait := TextureButton.new()
		portrait.name = "HubPortrait"
		portrait.ignore_texture_size = true
		portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_normal = story_portraits[HUB_PORTRAITS[hub_portrait_index]]
		portrait.tooltip_text = "点击切换百合子头像"
		portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		place_portrait(portrait)
		portrait.pressed.connect(func():
			hub_portrait_index = (hub_portrait_index + 1) % HUB_PORTRAITS.size()
			portrait.texture_normal = story_portraits[HUB_PORTRAITS[hub_portrait_index]])
	var box:=panel(Rect2(.035,.055,.51,.89),PAPER,27)
	var top:=HBoxContainer.new()
	box.add_child(top)
	label(top,SCENE_NAMES[selected]+"　／　百合子手记",16,TEAL).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var exit_title := "返回 CG 收藏" if from_cg_collection else ("返回驻防基地" if from_base else "返回主菜单")
	var exit_scene := "res://scenes/cg_collection.tscn" if from_cg_collection else ("res://scenes/meta.tscn" if from_base else "res://scenes/main.tscn")
	var exit_button := button(stage,exit_title,func():get_tree().change_scene_to_file(exit_scene))
	exit_button.name = "ExitButton"
	exit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	label(box,"放学后，雨停以前",38)
	var nav:=HBoxContainer.new()
	box.add_child(nav)
	for i in VIEW_NAMES.size():
		var b:=button(nav,VIEW_NAMES[i],hub.bind(i),i==tab)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		Unread.Dot.mark(b,Unread.section(i),"有未读内容")
	button(nav,"CG 集",hub.bind(8),tab==8).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	message=label(box,"",16,TEAL)
	if tab in [0,1]:
		var next:=Book.suggested("chapter" if tab==0 else "activity")
		if not next.is_empty():
			Unread.Dot.mark(button(box,"继续阅读　·　"+str(next.title),read_episode.bind(next),true),Unread.episode(next),"有未读内容")
		if tab==0:
			message.text="学期手记　%02d / %02d"%[Book.chapter_count(),Book.chapter_total()]
		else:message.text="日常日记 ×%d　完成标有日记的远征目标并获胜，可得一本。"%Book.diary_balance()
		var list:=scrolling(box)
		if tab==0:
			Unread.Dot.mark(button(list,"好感手记 · 两个人的放学路",hub.bind(6)),Unread.section(6),"有未读内容")
			add_fragments(list)
			label(list,"学期手记",19,TEAL)
		for ep in Book.episodes:
			if (tab==0)!=(ep.kind=="chapter"):continue
			var available:=Book.available(ep)
			var read:bool=MetaProgress.yuriko_school.get("read",{}).has(ep.id)
			var state:="已读" if read else "未读" if available else "读完第 %d 章开放"%int(ep.unlock)
			var hint := episode_source(ep)
			var row := source_row(list, hint)
			if ep.has("diary_cost") and not available:
				var can_buy := Book.met() and Book.diary_balance() >= int(ep.diary_cost)
				var buy:=button(row,"%s　　解锁 · 日常日记 ×%d"%[ep.title,ep.diary_cost],open_diary.bind(ep) if can_buy else show_source.bind(hint))
				buy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				continue
			if ep.has("diary_cost"):state+=" · 免费阅读"
			var b:=button(row,"%s　　%s　·　%s"%[ep.title,ep.place,state],read_episode.bind(ep) if available else show_source.bind(hint))
			b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			b.alignment=HORIZONTAL_ALIGNMENT_LEFT
			Unread.Dot.mark(b,available and not read,"未读")
			if not available and ep.kind=="chapter" and Book.pages_open()<=int(ep.unlock):b.text="%s　　远征未解锁"%ep.title
	elif tab==2:study(box)
	elif tab==3:wardrobe(box)
	elif tab==4:correspondence(box)
	elif tab==6:affinity_archive(box)
	elif tab==7:gift_replies(box)
	elif tab==8:preload("res://scripts/screens/yuriko_cg.gd").gallery(self,box)
	else:scene_gallery(box, selected, unlocked)

func affinity_archive(box:VBoxContainer) -> void:
	message.text="两个人的放学路　·　好感每升 5 级，开放一篇手记。"
	var list:=scrolling(box)
	var state:=MetaProgress.yuriko_school
	for ep:Dictionary in Book.affinity_stories:
		var status:="未读"
		var available:=Book.available(ep)
		if not available:status="尚未开放"
		elif state.get("marks",{}).has(ep.id):status="继续阅读"
		elif state.get("read",{}).has(ep.id):status="重读"
		var entry:=button(list,"好感 %d 级　%s　·　%s"%[ep.level,ep.title,status],read_episode.bind(ep))
		entry.disabled=not available
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		Unread.Dot.mark(entry,Unread.episode(ep),"未读")

func scene_texture(index:int) -> Texture2D:
	if index >= 2:
		return backdrop({"art_cell":index-2})
	return HARBOR if index == 1 else CLASSROOM

func scene_gallery(box:VBoxContainer, selected:int, unlocked:Dictionary) -> void:
	message.text = "点彩色卡片更换背景。在右侧人物上按住左键拖动可转身，滚动滚轮可调远近。"
	show_model_preview(Book.snapshot().skin, Color.TRANSPARENT)
	var list := scrolling(box)
	var grid := GridContainer.new()
	grid.name = "SceneCards"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	list.add_child(grid)
	var examples := {}
	for ep:Dictionary in Book.episodes + Bonds.stories:
		examples.get_or_add(scene_index(ep), ep)
	var gray := ShaderMaterial.new()
	gray.shader = preload("res://shaders/yuriko_locked_scene.gdshader")
	for i in SCENE_NAMES.size():
		var ep:Dictionary = examples[i]
		var available := unlocked.has(i)
		var title:String = SCENE_NAMES[i]
		var card := button(grid, "", select_scene.bind(i), i == selected)
		card.name = "SceneCard%d" % i
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 180
		card.disabled = not available
		card.accessibility_name = title
		card.tooltip_text = title if available else "读完《%s》即可解锁" % ep.title
		var image := TextureRect.new()
		image.name = "Scenery"
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture = scene_texture(i)
		image.clip_contents = true
		card.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.offset_left = 5
		image.offset_right = -5
		image.offset_top = 5
		image.offset_bottom = -40
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var person := TextureRect.new()
		person.name = "Yuriko"
		person.texture = story_portraits[ep.portrait]
		person.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		person.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.add_child(person)
		person.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		person.anchor_left = .36
		person.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not available:
			image.material = gray
			person.use_parent_material = true
		var caption := label(card, title, 19, INK)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -37
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == selected:
			caption.text += "　·　使用中"
			caption.add_theme_color_override("font_color", Color.WHITE)
		elif not available:
			caption.text += "　·　未解锁"

func add_fragments(list:VBoxContainer) -> void:
	var state:=MetaProgress.yuriko_school
	label(list,"远征残章　·　已收集 %d / %d"%[state.get("fragments",{}).size(),Bonds.stories.size()],19,TEAL)
	if state.get("fragments",{}).size()<Bonds.stories.size():
		label(list,"派地面小队取回粉色标记的破碎残章并获胜，可带回下一篇残章。",16)
	for ep:Dictionary in Bonds.stories:
		if ep.id=="tide_cover":label(list,"潮线以外　·　初读每篇提升 1 级好感",19,TEAL)
		var available := Book.available(ep)
		var hint := "相遇后，派地面小队前往粉色的破碎残章标记并获胜。每次可带回列表中第一篇尚未收集的残章。"
		var status := "已读" if state.get("read",{}).has(ep.id) else "未读"
		if not available:
			status = "解锁 · 带回本篇残章"
			if state.get("fragments",{}).has(str(int(ep.fragment))):
				status = "解锁 · 与百合子相遇"
				hint = "你已带回本篇残章。派地面部队寻找雨棚，或用 2 级战场情报定位，听到饭盒声后获胜，即可阅读。"
		var row := source_row(list,hint)
		var entry:=button(row,"%s　　%s　·　%s"%[ep.title,ep.place,status],read_episode.bind(ep) if available else show_source.bind(hint))
		entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		Unread.Dot.mark(entry,Unread.episode(ep),"未读")

func gift_replies(box:VBoxContainer) -> void:
	add_gift_portrait()
	message.text="赠礼回应"
	button(box,"返回私信与礼物",hub.bind(4))
	var list:=scrolling(box)
	var given:Dictionary=MetaProgress.yuriko_school.get("given",{})
	var has_replies:=false
	for id:String in Bonds.GIFTS:
		var count:=int(given.get(id,0))
		if count<1:continue
		has_replies=true
		var gift:Dictionary=Bonds.GIFTS[id]
		for index in mini(count,2):
			var key:="first" if index==0 else "again"
			var caption:=str(gift.name)+(" · 第一次收到" if index==0 else " · 再次收到")
			var reply:=label(list,str(gift[key]),19)
			var entry:=button(list,caption,open_reply.bind(id,key))
			list.move_child(entry,reply.get_index())
			var seen:Dictionary=MetaProgress.yuriko_school.get("reply_read",{})
			reply.visible=seen.has(id+"/"+key)
			Unread.Dot.mark(entry,not reply.visible,"未读回应")
	if not has_replies:
		label(list,"送给百合子一件礼物后，就能在这里重读她的回应。",18)

func open_reply(id:String,key:String) -> void:
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.get_or_add("reply_read",{})[id+"/"+key]=true
	if Book.commit(next):hub(7)
	else:message.text="阅读记录未保存，请重试。"

func add_gift_portrait() -> void:
	var portrait:=TextureRect.new()
	portrait.name="GiftPortrait"
	portrait.texture=GIFT_PORTRAITS[Book.snapshot().skin]
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place_portrait(portrait)

func correspondence(box:VBoxContainer) -> void:
	add_gift_portrait()
	message.text="好感 Lv.%d / %d"%[Book.affinity_level(),Book.AFFINITY_CAP]
	Unread.Dot.mark(button(box,"回看赠礼回应",hub.bind(7)),Unread.replies(),"有未读内容")
	var list:=scrolling(box)
	var counts:=Book.bonus_counts()
	label(list,"驻场 %d 秒　生命 +%d%%　攻击 +%d%%　移速 +%s%%　冷却 −%s%%"%[Psi.BASE_DURATION+2*int(counts.get("duration",0)),int(counts.get("health",0)),int(counts.get("attack",0)),String.num(0.5*int(counts.get("speed",0)),1),String.num(0.25*int(counts.get("cooldown",0)),2)],16)
	var level:=Book.next_bonus_level()
	if level<=Book.affinity_level():
		label(list,"第 %d 级 · 选择一项加成（待选 %d 级）"%[level,Book.affinity_level()-level+1],19,TEAL)
		var row:=HFlowContainer.new()
		list.add_child(row)
		for key:String in Book.bonus_options():
			button(row,Book.BONUSES[key],choose_affinity.bind(level,key))
	Unread.Dot.mark(button(list,"好感手记 · 两个人的放学路",hub.bind(6)),Unread.section(6),"有未读内容")
	label(list,"送给百合子",19,TEAL)
	shop_wallet=label(list,"",16)
	reroll_button=button(list,"",reroll_prices)
	reroll_button.tooltip_text="重新抽取全部礼物的价格。每天零点恢复一次免费刷新，付费次数也从头计算。"
	for id:String in Bonds.GIFTS:
		var gift:Dictionary=Bonds.GIFTS[id]
		var row:=HFlowContainer.new()
		list.add_child(row)
		var give_button:=button(row,"",present.bind(id))
		give_button.icon=preload("res://scripts/ui/progression_icon.gd").texture(gift.icon)
		give_buttons[id]=give_button
		var buy_button:=button(row,"",buy_present.bind(id))
		buy_button.tooltip_text="购买 "+str(gift.name)+" ×1"
		buy_button.icon=preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
		buy_buttons[id]=buy_button
	label(list,"每件礼物每日零点独立换价，原价 500 战略核心。95% 概率加价，最高 750。5% 概率降价，最低七折。远征委托也能带回礼物。",16)
	refresh_gift_shop()
	var clock:=Timer.new()
	list.add_child(clock)
	clock.timeout.connect(refresh_gift_shop)
	clock.start(1.0)

func refresh_gift_shop(day:String=Time.get_date_string_from_system()) -> void:
	if not is_instance_valid(shop_wallet):return
	shop_day=day
	shop_count=Bonds.refresh_count(day)
	var cost:=Bonds.refresh_cost(shop_count)
	var funds:=MetaProgress.balance("cores")
	reroll_button.text="免费刷新礼物价格" if cost==0 else "刷新礼物价格　%d 战略核心"%cost
	reroll_button.icon=null if cost==0 else preload("res://scripts/ui/resource_cost_icon.gd").texture("cores")
	reroll_button.disabled=funds<cost
	shop_wallet.text="%s　｜　可用战略核心 %d"%[shop_day,floori(funds)]
	for id:String in buy_buttons:
		var owned:=int(MetaProgress.yuriko_school.get("gifts",{}).get(id,0))
		var price:=Bonds.gift_price(id,shop_day)
		var delta:=100.0*(price-Bonds.BASE_GIFT_PRICE)/Bonds.BASE_GIFT_PRICE
		var percent_text:=str(roundi(absf(delta))) if is_equal_approx(delta,roundf(delta)) else "%.1f"%absf(delta)
		give_buttons[id].text="赠送 %s ×1　　持有 %d"%[Bonds.GIFTS[id].name,owned]
		give_buttons[id].disabled=owned==0
		buy_buttons[id].text="购买 ×1　%d 战略核心（%s %s%%）"%[price,"加价" if delta>0 else "降价",percent_text]
		buy_buttons[id].disabled=funds<price

func reroll_prices() -> void:
	var problem:=Bonds.reroll_gifts(shop_day,shop_count)
	refresh_gift_shop()
	message.text="三件礼物已重新报价。" if problem.is_empty() else problem

func buy_present(id:String) -> void:
	var quoted_price:=Bonds.gift_price(id,shop_day)
	var problem:=Bonds.buy_gift(id,shop_day,shop_count)
	refresh_gift_shop()
	message.text=problem if not problem.is_empty() else "%s ×1 已入库，花费 %d 战略核心。"%[Bonds.GIFTS[id].name,quoted_price]

func choose_affinity(level:int,key:String) -> void:
	if Book.choose_bonus(level,key):hub(4)
	else:message.text="加成未保存，请重试。"

func present(id:String) -> void:
	var had_head:=Book.journal_head_unlocked()
	var reply:=Bonds.give(id)
	if reply.is_empty():
		message.text="礼物未送出，请检查库存和存档。"
		return
	hub(4)
	message.text=reply+"　好感 %d"%int(MetaProgress.yuriko_school.affinity)
	if not had_head and Book.journal_head_unlocked():message.text+="　·　试衣间已解锁手记头型"

func study(box:VBoxContainer) -> void:
	message.text="可用灵能点　%d　　已习得　%d / 15"%[Book.balance(),MetaProgress.yuriko_school.get("learned",[]).size()]
	button(box,"观看技能与等级演示",show_demo)
	var list:=scrolling(box)
	for talent in Book.talents:
		var owned:bool=talent.id in MetaProgress.yuriko_school.get("learned",[])
		var text_:String="%s %d　·　%s　　%s"%[Psi.NAMES[talent.branch],talent.rank,DETAILS[talent.branch][int(talent.rank)-1],"已习得" if owned else "1 灵能点"]
		var row:=HBoxContainer.new()
		list.add_child(row)
		var emblem:=TextureRect.new()
		emblem.texture=load(Psi.ART+talent.icon+".png")
		emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.custom_minimum_size=Vector2(40,40)
		row.add_child(emblem)
		var b:=button(row,text_,learn.bind(talent.id))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if not owned:b.icon=load(Psi.ART+"FactionIconYuriko.png")
		b.add_theme_constant_override("icon_max_width",30)
		b.disabled=not Book.can_learn(talent)
		for prereq in talent.requires:
			for prev in Book.talents:
				if prev.id==prereq:b.tooltip_text="前置　%s %d"%[Psi.NAMES[prev.branch],prev.rank]
		if not owned:b.tooltip_text+="　初读手记和日常可得灵能点"

func learn(id:String) -> void:
	if Book.learn(id):hub(2)
	else:message.text="本次练习未保存，请检查点数、前置技能和存档。"

func show_demo() -> void:
	var demo=preload("res://scripts/ui/yuriko_demo.gd").new()
	add_child(demo)
	demo.play(Book.snapshot().skin)

func backdrop(ep:Dictionary) -> Texture2D:
	if not ep.has("art_cell"):
		return HARBOR if ep.background=="harbor" else CLASSROOM
	var index:int=ep.art_cell
	if not daily_scenes.has(index):
		var tex:=AtlasTexture.new()
		tex.atlas=ACTIVITIES
		@warning_ignore("integer_division")
		var cell:=Vector2i(index%3,index/3)
		var span:Vector2=ACTIVITIES.get_size()/3.0
		tex.region=Rect2(Vector2(cell)*span,span).grow(-2)
		tex.filter_clip=true
		daily_scenes[index]=tex
	return daily_scenes[index]

func open_diary(ep:Dictionary) -> void:
	if Book.unlock_diary(ep):read_episode(ep)
	else:message.text="解锁失败，请检查日记数量和存档后重试。"

func read_episode(ep:Dictionary) -> void:
	if not Book.available(ep):return
	clear_view()
	current=ep
	scenery.texture=backdrop(ep)
	var heading:=panel(Rect2(.035,.055,.34,.14),Color("#193834e8"),15)
	label(heading,ep.place,16,WARM)
	label(heading,ep.title,29,Color.WHITE)
	var box:=panel(Rect2(.085,.59,.83,.36),PAPER,24)
	var mark:=Book.cursor(ep)
	var top:=HBoxContainer.new()
	box.add_child(top)
	var choosing:=Book.choosing(ep)
	var line: String="" if choosing else Book.lines(ep,int(mark.answer))[int(mark.step)]
	var speaker:String=ep.get("choice_speaker","百合子") if choosing else line.get_slice("｜",0)
	var townsfolk:String=TOWNSPEOPLE.get(speaker,"")
	var caption:=speaker if townsfolk.is_empty() else "%s · %s"%[townsfolk,speaker]
	var player_speaking:=speaker in ["指挥官","男人"]
	if player_speaking:
		caption=MetaProgress.commander_name()
		if caption.is_empty():caption="指挥官"
	var who:=label(top,caption,21,TEAL)
	who.autowrap_mode=TextServer.AUTOWRAP_OFF
	who.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	who.name="SpeakerName"
	who.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(top,"收起手记",hub.bind(tab))
	var dialogue:=HBoxContainer.new()
	dialogue.size_flags_vertical=Control.SIZE_EXPAND_FILL
	dialogue.add_theme_constant_override("separation",18)
	box.add_child(dialogue)
	var identity:=speaker if townsfolk.is_empty() else townsfolk
	var texture:Texture2D=story_portraits[ep.portrait] if speaker=="百合子" else SPEAKER_PORTRAITS.get(identity)
	actor_layer.texture=texture
	actor_layer.visible=texture!=null
	if texture!=null:
		var portrait:=TextureRect.new()
		portrait.name="SpeakerPortrait"
		portrait.texture=texture
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size=Vector2(96,96)
		portrait.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		dialogue.add_child(portrait)
	var words:=label(dialogue,"我要怎么做？" if choosing else line.substr(line.find("｜")+1),26)
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if not choosing:
		words.mouse_filter=Control.MOUSE_FILTER_STOP
		words.gui_input.connect(func(event:InputEvent):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
				words.accept_event()
				advance(-1))
	if choosing:
		var choices:=HBoxContainer.new()
		box.add_child(choices)
		for i in ep.choices.size():
			var b:=button(choices,ep.choices[i].text,advance.bind(i))
			b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	else:
		var last:bool=int(mark.answer)>=0 and int(mark.step)==Book.lines(ep,int(mark.answer)).size()-1
		var title:="记入手记" if last else "下一句　›"
		if last and ep.award and not MetaProgress.yuriko_school.get("read",{}).has(ep.id):title+="　＋1 灵能点"
		if last and ep.has("affinity_award") and not MetaProgress.yuriko_school.get("read",{}).has(ep.id):
			title+="　好感已满" if Book.affinity_level()==Book.AFFINITY_CAP else "　好感等级 ＋1"
		button(box,title,advance.bind(-1),true)
	message=label(box,"",15,TEAL)
	message.visible=false

func advance(answer:int) -> void:
	var ep:=current
	if ep.is_empty():return
	var new_scene := not unlocked_scenes().has(scene_index(ep))
	var finishing_story:bool=ep.id=="letter" and not Book.contact_ready()
	var had_head:=Book.journal_head_unlocked()
	var outfit_index:=Book.OUTFIT_CHAPTERS.find(ep.id)
	var unlocks_outfit:=outfit_index>0 and not Book.outfit_unlocked(outfit_index)
	if not Book.advance(ep,answer):
		message.text="未能保存阅读进度。请重试。"
		message.show()
		return
	if not MetaProgress.yuriko_school.get("marks",{}).has(ep.id):
		hub(1 if finishing_story else tab)
		if new_scene:message.text += "　·　已解锁背景：" + SCENE_NAMES[scene_index(ep)]
		if unlocks_outfit:message.text+="　·　试衣间已解锁 "+Psi.SKINS[outfit_index]
		if not had_head and Book.journal_head_unlocked():message.text+="　·　试衣间已解锁手记头型"
	else:read_episode(ep)

const HEAD_NAMES := ["原版头型", "手记头型"]
const CARDS_PER_PAGE := 4
var wardrobe_section := 0
var wardrobe_pages := [0, 0]
var wardrobe_catalog: VBoxContainer

func wardrobe(box: VBoxContainer) -> void:
	var selected := int(Book.snapshot().skin)
	var journal := selected == Book.WEDDING_OUTFIT or Book.journal_head_equipped()
	var heading := label(box, "试衣间", 31)
	box.move_child(heading, message.get_index())
	message.text = "出战搭配　%s　/　%s" % [Psi.SKINS[selected], HEAD_NAMES[int(journal)]]
	wardrobe_catalog = VBoxContainer.new()
	wardrobe_catalog.add_theme_constant_override("separation", 18)
	wardrobe_catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(wardrobe_catalog)
	refresh_wardrobe(wardrobe_section)
	var viewer := panel(Rect2(.565,.09,.40,.855), Color("#234b45"), 16)
	show_model_preview(selected, Color.TRANSPARENT, viewer)
	label(viewer, Psi.SKINS[selected], 22, Color.WHITE)
	var actions := HBoxContainer.new()
	viewer.add_child(actions)
	for control in [["向左转",rotate_model.bind(-.35)], ["向右转",rotate_model.bind(.35)], ["拉近",adjust_zoom.bind(.15)], ["拉远",adjust_zoom.bind(-.15)]]:
		button(actions, control[0], control[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	photo.tooltip_text = "按住左键拖动转身，滚动滚轮调整远近。"
	var row := HBoxContainer.new()
	viewer.add_child(row)
	row.add_theme_constant_override("separation", 10)
	var motion := OptionButton.new()
	motion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion.add_theme_font_size_override("font_size", 18)
	motion.add_theme_stylebox_override("normal", paper(Color("#edf0e7"), 9))
	motion.add_theme_color_override("font_color", INK)
	for action in ["待机", "走动", "施法"]: motion.add_item("动作　·　" + action)
	row.add_child(motion)
	var playback := button(row, "暂停", Callable())
	playback.pressed.connect(func():
		preview_playing = not preview_playing
		playback.text = "暂停" if preview_playing else "播放")
	motion.item_selected.connect(func(i:int):
		pose = ["STATE_bored", "MOVING", "USER_8"][i]
		preview_playing = true
		playback.text = "暂停")

func refresh_wardrobe(section: int, delta := 0) -> void:
	wardrobe_section = section
	for child in wardrobe_catalog.get_children():
		wardrobe_catalog.remove_child(child)
		child.queue_free()
	var outfits := section == 0
	var count := Psi.SKINS.size() if outfits else HEAD_NAMES.size()
	var pages := maxi(1, ceili(float(count) / CARDS_PER_PAGE))
	var page := clampi(int(wardrobe_pages[section]) + delta, 0, pages - 1)
	wardrobe_pages[section] = page
	var tabs := HBoxContainer.new()
	wardrobe_catalog.add_child(tabs)
	button(tabs, "衣装　%d" % Psi.SKINS.size(), refresh_wardrobe.bind(0), outfits)
	button(tabs, "头部外观　%d" % HEAD_NAMES.size(), refresh_wardrobe.bind(1), not outfits)
	var selected := int(Book.snapshot().skin)
	var bridal := selected == Book.WEDDING_OUTFIT
	var journal := bridal or Book.journal_head_equipped()
	for line in 2:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 14)
		wardrobe_catalog.add_child(row)
		for column in 2:
			var i := page * CARDS_PER_PAGE + line * 2 + column
			if i >= count:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(spacer)
				continue
			var equipped := selected == i if outfits else int(journal) == i
			var available := Book.outfit_unlocked(i) if outfits else not bridal and (i == 0 or Book.journal_head_unlocked())
			var title: String = Psi.SKINS[i] if outfits else HEAD_NAMES[i]
			var status := Book.outfit_label(i) if outfits else ("已解锁" if available else "未解锁")
			if bridal and not outfits: status = "婚纱固定搭配手记头型"
			if equipped: status = "出战中" if outfits else "使用中"
			var card := button(row, title + "\n" + status, wear.bind(i) if outfits else wear_head.bind(i == 1), equipped)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.alignment = HORIZONTAL_ALIGNMENT_LEFT
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.disabled = not available
			if outfits:
				card.icon = load(Psi.ART + Psi.PORTRAITS[i] + ".png")
				card.add_theme_constant_override("icon_max_width", 88)
				card.add_theme_constant_override("h_separation", 14)
	if not outfits and not Book.journal_head_unlocked():
		label(wardrobe_catalog, "手记头型需好感达到 %d 级并读完第五章《靠窗第三排》。当前好感 %d 级，第五章%s。" % [Book.JOURNAL_HEAD_AFFINITY, Book.affinity_level(), "已读完" if MetaProgress.yuriko_school.get("read", {}).has(Book.JOURNAL_HEAD_CHAPTER) else "未读完"], 16)
	var pager := HBoxContainer.new()
	wardrobe_catalog.add_child(pager)
	label(pager, ("共 %d 套衣装" if outfits else "共 %d 种头部外观") % count, 16, TEAL).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(pager, "上一页", refresh_wardrobe.bind(section, -1)).disabled = page == 0
	label(pager, "%d / %d" % [page + 1, pages], 16).autowrap_mode = TextServer.AUTOWRAP_OFF
	button(pager, "下一页", refresh_wardrobe.bind(section, 1)).disabled = page + 1 == pages

func show_model_preview(selected:int,background:Color, viewer:VBoxContainer = null) -> void:
	preview_playing=true
	if viewer == null: viewer = panel(Rect2(.565,.09,.40,.82),background,12)
	photo=TextureRect.new()
	photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	photo.size_flags_vertical=Control.SIZE_EXPAND_FILL
	viewer.add_child(photo)
	photo.mouse_filter=Control.MOUSE_FILTER_STOP
	photo.gui_input.connect(turn_input)
	model=preload("res://scripts/units/yuriko_model.gd").new()
	photo.add_child(model)
	model.set_skin(selected)
	model.size=Vector2i(1024,1024)
	photo.texture=model.get_texture()
	model.body.rotation.y=-.28
	pose="STATE_bored"
	zoom=1.0
	frame_model()

func wear_head(journal:bool) -> void:
	if Book.wear_journal_head(journal):hub(3)
	else:message.text="头部外观未能装备。"

func wear(i:int) -> void:
	if Book.wear(i):hub(3)
	else:message.text="衣装未能保存。"

func frame_model() -> void:
	var rig:Skeleton3D=model.rig
	var bounds:=AABB(rig.to_global(rig.get_bone_global_pose(0).origin),Vector3.ZERO)
	for bone in range(1,rig.get_bone_count()):
		bounds=bounds.expand(rig.to_global(rig.get_bone_global_pose(bone).origin))
	var center:=bounds.get_center()
	var camera:Camera3D=model.get_camera_3d()
	camera.position=center+Vector3(0,3,60)
	camera.look_at(center)
	# Include depth projected onto the tilted camera and room beyond joint tips for the mesh.
	var up:=camera.global_basis.y.abs()
	var safe_size:=maxf(bounds.size.x,up.dot(bounds.size))+8.0
	camera.size=maxf(39.0/zoom,safe_size)

func rotate_model(amount:float) -> void:
	if is_instance_valid(model):
		model.body.rotate_y(amount)
		frame_model()

func adjust_zoom(amount:float) -> void:
	zoom=clampf(zoom+amount,.7,1.6)
	frame_model()

func turn_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:drag=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_MIDDLE:adjust_zoom(.15)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:adjust_zoom(.1)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:adjust_zoom(-.1)
	elif event is InputEventMouseMotion and drag and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rotate_model(event.relative.x*.012)

func _process(dt:float) -> void:
	if is_instance_valid(model) and preview_playing:
		model.pose(pose,dt,false,true)
		frame_model()
		model.hover_fx.advance(dt,Psi.COLORS[model.outfit],true)
