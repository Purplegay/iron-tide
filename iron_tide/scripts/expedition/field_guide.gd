extends Control

const Missions=preload("res://scripts/expedition/field_missions.gd")
const Contacts=preload("res://scripts/expedition/contact_catalog.gd")
const Stories=preload("res://scripts/expedition/contact_stories.gd")
const Keepsakes=preload("res://scripts/expedition/commander_keepsakes.gd")
const FOLD_PATH := "user://field_guide_folds.cfg"
static var fold_preferences: ConfigFile

class ArchivePage:
	var key: String
	var title: String
	var text: String

	func _init(entry_key: String, heading: String, content: String) -> void:
		key = entry_key
		title = heading
		text = content

const GUIDE := {
	"contact":["还有可约定的友军支援关卡，且地图上有可用救援点。","保护蓝色标记处的联络人，让友方部队在附近累计控制 20 秒。有敌军争夺时计时暂停。","本关胜利获得 35 补给和 1 个维修包，联络人按约定关卡带领独立 AI 友军参战。友军进场时可解锁口述故事。部分联络人会在约定中写明本国特色单位。赢下救援关后获得本轮生产许可；步兵用兵营，车辆用战车工厂，黑鹰用空指部。两方均可使用，保留雷达前置和正常费用。黑鹰许可会在下关起提供可起降的空指部。"],
	"cache":["偶数关的常规物资点。","派友方部队进入蓝色军需标记，清除附近敌军，累计控制 20 秒。","本关胜利后获得 50 补给和 1 个维修包。"],
	"intel":["奇数关的常规情报点。","派友方部队靠近蓝色情报标记，排除敌军干扰，累计控制 20 秒。","暂时揭开敌军主基地附近的迷雾，本关胜利后获得 35 补给。"],
	"radio":["主线为「解救小队」时会避开这项支线。其他路线有机会收到两个电台的呼救。","派己方地面部队到监听点取得识别码，再前往对应电台。也可直接前往电台；选错会遇到伏兵，仍可接应另一处。","在真电台接回失联步兵，最多 3 人加入本场战斗。"],
	"box":["护送车队主线和最终关以外的路线有机会发现黑匣子。","让己方地面部队碰触闪框箱子，再点远征面板的「送回交付点」，携带者就会前往蓝色交付点。携带期间，F2 全选和 T 同型选择都会跳过它。携带者会间歇暴露位置，也可以点「放下黑匣子」让其他部队接手。","成功交付并赢下本关后，带回 1 个维修包，下一关选路线时可提前查看首波敌军情报。"],
	"fuel":["护送车队主线以外的路线有机会遇到油罐车和一座停机的中立科技前哨站。","派地面部队与车会合，在车旁选择护送或拆车。护送时保护油罐车抵达停靠点。","送达后前哨站提供防空，绿色圈内受损的己方地面载具持续恢复。拆车则在胜利后带回 1 个维修包。"],
	"divert":["多敌军路线有机会部署一支带通讯车的敌方车队。","可直接摧毁通讯车，也可派己方地面部队到中继台发送假撤退令。","直接排除通讯车，本关胜利后获得 45 补给。发送撤退令会暂时调开车队，车队在集结点重整后重新参战。"],
	"engineer":["后续仍有可用的侧桥地图时，路线有机会遇到受困工兵。","派己方地面部队接近工兵，把他安全撤出。工兵阵亡或失去控制会使救援失败。","本关胜利后揭示下一关的侧桥路线，选中对应地图即可获得工兵支援。"],
	"bridge":["上关救出桥梁工兵并获胜，本关选择对应的侧桥路线，且地图上有待修的桥。","找到蓝色标记的维修小屋，选中己方工程师，右键命令其进入小屋。","侧桥修复后，地面部队可以从新通路渡河。"]
}

var initial_kind := ""
var source: Control
var previous_focus: Control

static func open(parent: Control, kind := "") -> void:
	var book = load("res://scenes/field_guide.tscn").instantiate()
	book.initial_kind = kind
	book.source = parent
	book.previous_focus = parent.get_viewport().gui_get_focus_owner()
	parent.hide()
	parent.get_parent().add_child(book)
	parent.tree_exiting.connect(book.queue_free, CONNECT_ONE_SHOT)

func close() -> void:
	if is_instance_valid(source):
		source.show()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101b26")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 42 if edge in ["left", "right"] else 24)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var banner := Panel.new()
	banner.custom_minimum_size.y = 144
	banner.clip_contents = true
	page.add_child(banner)
	var terrain := TextureRect.new()
	terrain.texture = preload("res://assets/maps/yr/yr_valley_preview.png")
	terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	terrain.modulate = Color("a8bcbb")
	banner.add_child(terrain)
	terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := GradientTexture2D.new()
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color("101e29"), Color("15263372")])
	var tint := TextureRect.new()
	tint.texture = fade
	banner.add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := UiKit.make_label("支线百科", 48, Color("f3f0de"))
	banner.add_child(title)
	title.position = Vector2(28, 34)
	var back := UiKit.make_button("返回远征" if is_instance_valid(source) and source.scene_file_path.ends_with("expedition.tscn") else "返回主菜单", 16)
	banner.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -154
	back.offset_right = -20
	back.offset_top = 18
	back.offset_bottom = 58
	back.pressed.connect(close)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 20)
	page.add_child(tabs)
	var names: Dictionary = Missions.BASIC_NAMES.merged(Missions.NAMES)
	var missions := reader(tabs, "支线任务", "任务目录 · %d" % names.size())
	var list: ItemList = missions.list
	var detail: VBoxContainer = missions.detail
	for kind: String in names:
		var index := list.add_item(names[kind])
		list.set_item_metadata(index, kind)
	list.item_selected.connect(show_mission.bind(list, detail))
	var selected := maxi(0, names.keys().find(initial_kind))
	list.select(selected)
	list.ensure_current_is_visible()
	show_mission(selected, list, detail)
	var records := archive_records()
	var known := records.filter(func(record): return record.unlocked > 0)
	var archive := reader(tabs, "指挥官档案", "指挥官目录 · %d" % known.size())
	var commanders: ItemList = archive.list
	for record: Dictionary in known:
		commanders.add_item(Stories.PEOPLE[record.id].name)
	if known.is_empty():
		add_text(archive.detail, "暂无已解锁档案", 18, UiKit.COL_DIM)
	else:
		commanders.item_selected.connect(show_commander.bind(known, archive.detail))
		commanders.select(0)
		show_commander(0, known, archive.detail)
	var ids := HeroStories.BOOK.keys().filter(func(id):return id not in MetaProgress.Academy.Stars.IDS or MetaProgress.Academy.hero_build_count(MetaProgress,id)>0)
	var stories := reader(tabs, "英雄故事", "英雄目录 · %d" % ids.size())
	var heroes: ItemList = stories.list
	for id: String in ids:
		heroes.add_item(HeroStories.name_of(id))
	heroes.item_selected.connect(show_hero_story.bind(ids, stories.detail))
	heroes.select(0)
	show_hero_story(0, ids, stories.detail)
	list.grab_focus()

const Portraits = preload("res://scripts/ui/hero_portraits.gd")
const HeroStories = preload("res://scripts/expedition/hero_field_stories.gd")

func reader(tabs: TabContainer, tab_name: String, caption: String) -> Dictionary:
	var missions := HBoxContainer.new()
	missions.name = tab_name
	missions.add_theme_constant_override("separation", 18)
	tabs.add_child(missions)
	var directory := VBoxContainer.new()
	directory.custom_minimum_size.x = 238
	missions.add_child(directory)
	directory.add_child(UiKit.make_label(caption, 18, UiKit.COL_SIDE_MISSION))
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_constant_override("v_separation", 10)
	directory.add_child(list)
	var sheet := UiKit.make_panel(Color("142333"),Color("374c5c"),4,1,24)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missions.add_child(sheet)
	var detail := scrolling_column(sheet)
	return {"list": list, "detail": detail}

func show_hero_story(index: int, ids: Array, passage: VBoxContainer) -> void:
	for old in passage.get_children():
		passage.remove_child(old)
		old.queue_free()
	(passage.get_parent() as ScrollContainer).scroll_vertical = 0
	var id: String = ids[index]
	var story: Dictionary = HeroStories.BOOK[id]
	var names := Missions.BASIC_NAMES.merged(Missions.NAMES)
	if id == "YURIKO":
		profile_header(passage,load("res://assets/ra3/yuriko/Portrait_Japan_Yuriko_01.png"),"百合子","升阳帝国 · 灵能特工")
		if preload("res://scripts/units/yuriko_school.gd").recruit_ready():
			reading_section(passage,story.title,story.story)
			reading_section(passage,"招募",preload("res://scripts/units/yuriko_school.gd").RETURN_HINT if preload("res://scripts/units/yuriko_school.gd").recruited_before() else story.clue+" 完成标有她名字的情报支线并获胜，之后可从战场菜单召唤。")
		else:
			reading_section(passage,"港口手记","她还没有留下联络方式。")
		reading_section(passage,"灵能天赋","在主菜单「百合子手记」完成章节与日常，在灵能练习中分配技能点。之后召唤的百合子会使用已习得的强化。")
		return
	var record := hero_archive(id, names)
	var status := "%s · 同行档案 %d/%d" % [GameData.get_unit(id).name, record.pages.size() + 1, record.total]
	var portrait := profile_header(passage, Portraits.texture(id), HeroStories.name_of(id), status)
	if id in Portraits.DRIVER_IDS:
		if Portraits.driver_unlocked(id):
			var switcher := UiKit.make_button(Portraits.switch_action(id), 16)
			switcher.name = "SwitchHeroPortrait"
			switcher.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			passage.add_child(switcher)
			switcher.pressed.connect(switch_portrait.bind(id, switcher, portrait))
		else:
			add_text(passage, Portraits.DRIVER_UNLOCK_HINT, 16, UiKit.COL_DIM)
	add_text(passage, story.title, 26, Color("f3f0de"))
	add_text(passage, story.story, 18, UiKit.COL_TEXT)
	add_text(passage, HeroStories.chronicles[id].intro, 18, UiKit.COL_TEXT)
	archive_sections(passage, id, record.pages)
	if not record.next_clue.is_empty():
		reading_section(passage, "下一条线索", record.next_clue)
	var recruitment := remembered_section(id, "recruitment", "招募条件与行动")
	passage.add_child(recruitment)
	var instructions := VBoxContainer.new()
	instructions.add_theme_constant_override("separation", 10)
	recruitment.add_child(instructions)
	var start := 5 if id in MetaProgress.Academy.Commandos.IDS or id in ["ORCA","TTNK","FV","HARV"] else 1
	if id in MetaProgress.Academy.Stars.IDS:
		reading_section(instructions,"出现条件","英雄入册后，各阵营远征都可能遇到这条线索。")
	else:reading_section(instructions, "出现条件", "第 %d 关起，同阵营路线可能出现「%s」的英雄线索。完成支线即可招募这名英雄。" % [start, names[story.kind]])
	reading_section(instructions, "行动", "%s\n%s" % [story.clue, GUIDE[story.kind][1]])
	reading_section(instructions, "结果", "完成标有%s线索的委托并赢下本关，%s会加入本轮远征，从下一关起随队增援。" % [HeroStories.name_of(id), HeroStories.name_of(id)])
	reading_section(passage, "同行归档", "带这名英雄同行，选择标有其篇名的路线。完成对应支线并赢下本关即可归档，跨周目保留。油罐车委托需要护送到站。")
	if not record.missing.is_empty():
		reading_section(passage, "尚待寻访", "\n".join(record.missing))

func switch_portrait(id: String, button: Button, portrait: TextureRect) -> void:
	if Portraits.choose_driver(id, not Portraits.showing_driver(id)):
		portrait.texture = Portraits.texture(id)
		button.text = Portraits.switch_action(id)
	else:
		button.text = "保存失败，点击重试"

static func hero_archive(id: String, names: Dictionary) -> Dictionary:
	var chapters: Array = HeroStories.chronicles[id].chapters
	var read: Dictionary = MetaProgress.hero_story_archive.get(id, {})
	var pages: Array[ArchivePage] = []
	var missing: PackedStringArray = []
	var next_clue := ""
	var total := 1 # The opening story is always available.
	for i in chapters.size():
		var chapter: Dictionary = chapters[i]
		total += 1 + int(chapter.has("artifact")) + int(chapter.has("letter"))
		var title := "第%d章《%s》" % [i+1,chapter.title]
		if not read.has(str(i+1)):
			missing.append("%s　%d周目起 · %s" % [title, int(chapter.cycle), names[chapter.kind]])
			if next_clue.is_empty():
				next_clue = "%s\n%d周目起 · %s\n%s" % [title, int(chapter.cycle), names[chapter.kind], chapter.clue]
			continue
		var key := "chapter_%d" % (i + 1)
		pages.append(ArchivePage.new(key, title, chapter.text))
		if chapter.has("artifact"):pages.append(ArchivePage.new(key + "_artifact", "随卷物证 · "+str(chapter.title), chapter.artifact))
		if chapter.has("letter"):pages.append(ArchivePage.new(key + "_letter", "私人来信 · "+str(chapter.title), chapter.letter))
	return {"pages": pages, "total": total, "next_clue": next_clue, "missing": missing}

static func reading_section(detail: VBoxContainer, heading: String, content: String) -> void:
	detail.add_child(UiKit.divider())
	add_text(detail, heading, 18, Color("e4bf7a"))
	add_text(detail, content, 18, UiKit.COL_TEXT)

static func scrolling_column(parent:Container) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	return column

static func add_text(parent:Container,value:String,font_size:int,color:Color) -> Label:
	var text:=UiKit.make_label(value,font_size,color)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(text)
	return text

func show_mission(index:int,list:ItemList,detail:VBoxContainer) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var key:String=list.get_item_metadata(index)
	var guide:Array=GUIDE.get(key,[])
	if Missions.Assign.BOOK.has(key):
		var row:Array=Missions.Assign.BOOK[key]
		guide=["第 %d 周目起进入轮换"%row[1],row[2],"胜利后获得维修包" if key=="fieldshop" else "胜利后获得 35 补给"]
	add_text(detail,list.get_item_text(index),32,Color("f3f0de"))
	var headings:=["出现条件","行动","结果"]
	for i in headings.size():
		reading_section(detail, headings[i], guide[i])
	if key=="contact":
		add_text(detail,"联络人签发的本轮许可",16,UiKit.COL_SIDE_MISSION)
		for person:Dictionary in Contacts.PEOPLE.values():
			if person.has("permit"):
				add_text(detail,"%s · %s　→　%s"%[person.country,str(person.name).get_slice(" · ",0),GameData.get_unit(person.permit).name],15,UiKit.COL_TEXT)
	for id: String in HeroStories.BOOK:
		if id in MetaProgress.Academy.Stars.IDS and MetaProgress.Academy.hero_build_count(MetaProgress,id)==0:continue
		if id=="YURIKO" and not preload("res://scripts/units/yuriko_school.gd").recruit_ready():continue
		var entry: Dictionary = HeroStories.BOOK[id]
		if entry.kind == key:
			add_text(detail, "英雄线索 · " + HeroStories.name_of(id), 17, UiKit.COL_GOLD)
			add_text(detail, entry.clue, 16, UiKit.COL_TEXT)
		var chapters: PackedStringArray = []
		for chapter: Dictionary in HeroStories.chronicles.get(id,{}).get("chapters",[]):
			if chapter.kind == key:
				chapters.append("《%s》（%d周目起）" % [chapter.title, int(chapter.cycle)])
		if not chapters.is_empty():
			add_text(detail, "%s同行 · %s" % [HeroStories.name_of(id), "、".join(chapters)], 16, UiKit.COL_TEXT)
	var scroll:ScrollContainer=detail.get_parent()
	scroll.scroll_vertical=0

func show_commander(index: int, records: Array, detail: VBoxContainer) -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	(detail.get_parent() as ScrollContainer).scroll_vertical = 0
	var record: Dictionary = records[index]
	var profile: Dictionary = Stories.PEOPLE[record.id]
	var status := "%s%s · 档案解锁 %d/%d" % [profile.base, record.progress, record.unlocked, record.total]
	profile_header(detail, Contacts.portrait(record.id), profile.name, status)
	archive_sections(detail, record.id, record.pages)

static func profile_header(detail: VBoxContainer, texture: Texture2D, person_name: String, status: String) -> TextureRect:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	detail.add_child(header)
	var frame := UiKit.make_panel(Color("0f1c28"), Color("657582"), 3, 1, 4)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(frame)
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 6)
	header.add_child(identity)
	add_text(identity, person_name, 36, UiKit.COL_GOLD)
	add_text(identity, status, 18, UiKit.COL_SIDE_MISSION)
	detail.add_child(UiKit.divider())
	return portrait

static func archive_records() -> Array:
	var result := []
	for id:String in Stories.PEOPLE:
		var profile:Dictionary=Stories.PEOPLE[id]
		var read:Dictionary=MetaProgress.contact_archive.get(id,{})
		var records:Dictionary=MetaProgress.contact_transcripts.get(id,{})
		var pages: Array[ArchivePage] = []
		var unlocked:=0
		var headings:={"bio":"救援前 · 人物情报","promise":"救援前 · 支援约定","rescue":"救援成功 · 现场答话","arrival":"赴约支援 · 报到通话"}
		for kind:String in headings:
			var original:String=profile[kind]
			var variants:Array=records.get(kind,[])
			var earned:bool=not variants.is_empty() or (kind=="rescue" and records.get("rescued",false))
			if not earned:continue
			unlocked+=1
			var content:=PackedStringArray()
			for line:String in variants:content.append("已记录 · "+line)
			if variants.is_empty():
				content.append("原文 · "+original)
			pages.append(ArchivePage.new(kind, headings[kind], "\n".join(content)))
		for key:String in profile.chapters:
			var chapter:Dictionary=profile.chapters[key]
			var receipt:Dictionary=read.get(key,{})
			if not read.has(key):continue
			unlocked+=1
			pages.append(ArchivePage.new("chapter_" + key, "《%s》"%receipt.get("title",chapter.title), "\n".join(receipt.get("lines",chapter.lines))))
		if Keepsakes.owned(id):
			var gift:Dictionary=Keepsakes.ITEMS[id]
			unlocked+=1
			pages.append(ArchivePage.new("keepsake", "信物 · "+str(gift.name), "%s\n%s"%[gift.gift,Keepsakes.guide_for_run(id,{})]))
			for level in range(2, Keepsakes.rank(id) + 1):
				unlocked += 1
				var scene := Keepsakes.story(id,level)
				pages.append(ArchivePage.new("gift_reunion_%d" % level, "再会 · 第 %d 档 %s" % [level,scene.get_slice("\n",0)], scene.get_slice("\n",1)))
			if records.has("joint_record"):
				unlocked+=1
				pages.append(ArchivePage.new("joint_record", "合击战记 · %s · 第 %d 关"%[records.joint_record.date,records.joint_record.stage], gift.after))
		var letters:=preload("res://scripts/expedition/cycle_letters.gd").letters(id,int(Expedition.state.get("cycle",1)),records)
		for title: String in letters:
			# The journal also identifies cycle letters by their authored titles.
			pages.append(ArchivePage.new("mail_" + title.sha256_text(), title, letters[title]))
		unlocked+=letters.size()
		var total:int=headings.size()+profile.chapters.size()
		if Keepsakes.ITEMS.has(id):total+=7 + Keepsakes.MAX_RANK - 1
		result.append({"id":id,"pages":pages,"unlocked":unlocked,"total":total,"progress":" · 已获救" if records.get("rescued",false) else ""})
	return result

static func add_archive(parent:VBoxContainer) -> void:
	add_text(parent,"指挥官口述档案",20,UiKit.COL_SIDE_MISSION)
	var complete_list:VBoxContainer
	var complete_count:=0
	var locked:=0
	var known:=0
	for record: Dictionary in archive_records():
		var id: String = record.id
		var profile: Dictionary = Stories.PEOPLE[id]
		var total: int = record.total
		var unlocked: int = record.unlocked
		locked+=total-unlocked
		if unlocked==0:continue
		known+=1
		var list_parent:=parent
		if unlocked==total:
			if complete_count==0:
				complete_list=VBoxContainer.new()
			complete_count+=1
			list_parent=complete_list
		var progress: String = record.progress
		var entry:=UiKit.make_button("%s\n%s%s · 档案解锁 %d/%d"%[profile.name,profile.base,progress,unlocked,total],15)
		entry.icon=Contacts.portrait(id)
		entry.add_theme_constant_override("icon_max_width",44)
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		entry.toggle_mode=true
		list_parent.add_child(entry)
		var entries:=VBoxContainer.new()
		list_parent.add_child(entries)
		entries.hide()
		entry.toggled.connect(entries.set_visible)
		archive_sections(entries, id, record.pages)
	if known==0:add_text(parent,"暂无已解锁档案",15,UiKit.COL_DIM)
	if complete_count>0:
		var complete_group:=UiKit.make_button("已集齐（%d 位指挥官）"%complete_count,15)
		complete_group.toggle_mode=true
		parent.add_child(complete_group)
		parent.add_child(complete_list)
		complete_list.hide()
		complete_group.toggled.connect(complete_list.set_visible)
	if locked>0:
		parent.add_child(HSeparator.new())
		add_text(parent,"未解锁 · %d 项"%locked,16,UiKit.COL_DIM)

static func remembered_section(id: String, key: String, title: String) -> FoldableContainer:
	if fold_preferences == null:
		fold_preferences = ConfigFile.new()
		if fold_preferences.load(FOLD_PATH) != OK:
			fold_preferences.clear()
	var section := FoldableContainer.new()
	section.title = title
	section.folded = fold_preferences.get_value(id, key, true) != false
	section.folding_changed.connect(save_fold.bind(id, key))
	return section

static func save_fold(folded: bool, id: String, key: String) -> void:
	fold_preferences.set_value(id, key, folded)
	var error := fold_preferences.save(FOLD_PATH + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(FOLD_PATH + ".tmp", FOLD_PATH)
	if error != OK:
		push_warning("无法保存百科折叠状态：" + error_string(error))

static func archive_sections(entries: VBoxContainer, id: String, pages: Array[ArchivePage]) -> void:
	for page in pages:
		var section := remembered_section(id, page.key, page.title)
		entries.add_child(section)
		var content_parent:Container=section
		if page.key == "keepsake":
			var column:=VBoxContainer.new()
			section.add_child(column)
			var icon:=Keepsakes.icon_view(id)
			icon.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
			column.add_child(icon)
			content_parent=column
		add_text(content_parent,page.text,15,UiKit.COL_TEXT)
