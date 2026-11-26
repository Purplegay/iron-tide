extends RefCounted

const Book=preload("res://scripts/units/yuriko_school.gd")
const CostIcon=preload("res://scripts/ui/resource_cost_icon.gd")
const ART_DIR:="res://assets/ra3/yuriko/school_days/cg/"
static var story:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko_wedding_cg.json"))

static func add_art(parent:Control,file:String,rect:Rect2) -> TextureRect:
	var image:=TextureRect.new()
	image.name="CGArt"
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.texture=load(ART_DIR+file+".webp")
	parent.add_child(image)
	image.anchor_left=rect.position.x
	image.anchor_top=rect.position.y
	image.anchor_right=rect.end.x
	image.anchor_bottom=rect.end.y
	return image

static func gallery(view,box:VBoxContainer) -> void:
	view.message.text="看剧情时，点右侧的「下一页」继续。读完第一幕，在同一位置点「下一幕」。"
	var list:VBoxContainer=view.scrolling(box)
	view.label(list,"同一站下车",28)
	view.label(list,"毕业多年以后，百合子穿着婚纱回到海边站台。这一回，两个人只买了去程票。",18)
	var preview_art:String=story.scenes[0].art
	if Book.owns_wedding_cg():
		var last_art=MetaProgress.yuriko_school.get("last_cg_art","")
		for scene:Dictionary in story.scenes:
			if scene.art==last_art:
				preview_art=scene.art
				break
	add_art(view.stage,preview_art,Rect2(.575,.16,.39,.65))
	if Book.owns_wedding_cg():
		view.label(list,"已收藏 2 张。右侧会保留你最近看过的那张图。",17,view.TEAL)
		for i in story.scenes.size():
			view.button(list,"重温 · "+str(story.scenes[i].title),show_page.bind(view,i,0,false))
	else:
		view.label(list,"婚纱 CG 2 张、完整番外及可出战的婚纱衣装，整组购买。",17)
		CostIcon.balance_label(list,"diamonds","持有钻石 %d"%floori(MetaProgress.balance("diamonds")),16,view.TEAL)
		var buy:Button=view.button(list,"收藏整组　·　%d 钻石"%Book.WEDDING_CG_PRICE,buy_set.bind(view),true)
		buy.icon=CostIcon.texture("diamonds")
		var shortfall:=Book.WEDDING_CG_PRICE-MetaProgress.balance("diamonds")
		buy.disabled=not Book.journal_head_unlocked() or shortfall>0
		if not Book.journal_head_unlocked():view.label(list,Book.WEDDING_HEAD_REQUIREMENT,16)
		if shortfall>0:view.label(list,"还差 %d 钻石"%ceili(Book.WEDDING_CG_PRICE-MetaProgress.balance("diamonds")),16)
	view.button(list,"返回手记",view.hub.bind(0))

static func buy_set(view) -> void:
	var error:=Book.buy_wedding_cg()
	if error.is_empty():show_page(view,0,0,false)
	else:
		view.hub(8)
		view.message.text=error

static func show_page(view,scene_index:int,page_index:int,art_only:bool) -> void:
	if not Book.owns_wedding_cg():
		view.hub(8)
		return
	view.clear_view()
	view.actor_layer.hide()
	var scene:Dictionary=story.scenes[scene_index]
	if MetaProgress.yuriko_school.get("last_cg_art","")!=scene.art:
		var next:=MetaProgress.yuriko_school.duplicate(true)
		next.last_cg_art=scene.art
		if not Book.commit(next):
			push_warning("最近看过的 CG 未能保存")
	var backdrop:=ColorRect.new()
	backdrop.color=Color("#17272b")
	view.stage.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_art(view.stage,scene.art,Rect2(0,0,1,1) if art_only else Rect2(.012,.02,.675,.96))
	if art_only:
		var back:Button=view.button(view.stage,"返回剧情",show_page.bind(view,scene_index,page_index,false))
		back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,Control.PRESET_MODE_MINSIZE,16)
		return
	var box:VBoxContainer=view.panel(Rect2(.70,.09,.275,.82),view.PAPER,20)
	view.label(box,story.title,17,view.TEAL)
	view.label(box,scene.title,28)
	var page:Array=scene.pages[page_index]
	var name_:String=MetaProgress.commander_name() if page[0]=="指挥官" else str(page[0])
	view.label(box,name_,18,view.TEAL)
	var text_:Label=view.label(box,page[1],21)
	text_.size_flags_vertical=Control.SIZE_EXPAND_FILL
	view.label(box,"%d / %d"%[page_index+1,scene.pages.size()],15,view.TEAL)
	var row:=HBoxContainer.new()
	box.add_child(row)
	if page_index>0:view.button(row,"上一页",show_page.bind(view,scene_index,page_index-1,false))
	elif scene_index>0:view.button(row,"上一页",show_page.bind(view,scene_index-1,story.scenes[scene_index-1].pages.size()-1,false))
	else:view.button(row,"上一页",Callable()).disabled=true
	if page_index+1<scene.pages.size():view.button(row,"下一页",show_page.bind(view,scene_index,page_index+1,false),true)
	elif scene_index+1<story.scenes.size():view.button(row,"下一幕",show_page.bind(view,scene_index+1,0,false),true)
	else:view.button(row,"下一页",Callable()).disabled=true
	for key:Button in row.get_children():key.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	view.button(box,"全屏赏图",show_page.bind(view,scene_index,page_index,true))
	view.button(box,"返回 CG 集",view.hub.bind(8))

