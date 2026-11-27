extends Control
## 排版坐标以确认的 1440×900 SVG 为基准；其余窗口等比居中，不拉伸卡片。

const Catalog = preload("res://scripts/ui/campaign_cg_catalog.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const Book = preload("res://scripts/units/yuriko_school.gd")
const SCREEN_SHADER = preload("res://assets/ui/cg_gallery/screen.gdshader")
const PORTRAIT = preload("res://assets/ra3/yuriko/Portrait_Japan_Yuriko_01.png")
const SNOW = preload("res://assets/ui/cg_gallery/snow.png")
const LOCK = preload("res://assets/ui/cg_gallery/lock.svg")
const PLAY = preload("res://assets/ui/cg_gallery/play.svg")
const POSTERS := {
	"A01_F00E": preload("res://assets/ui/cg_gallery/A01_F00E.webp"),
	"A01_P01E": preload("res://assets/ui/cg_gallery/A01_P01E.webp"),
	"A01_P02E": preload("res://assets/ui/cg_gallery/A01_P02E.webp"),
	"A01_P03E": preload("res://assets/ui/cg_gallery/A01_P03E.webp"),
	"A07_F00E": preload("res://assets/ui/cg_gallery/A07_F00E.webp"),
	"A07_P01E": preload("res://assets/ui/cg_gallery/A07_P01E.webp"),
	"A08_F00E": preload("res://assets/ui/cg_gallery/A08_F00E.webp"),
	"A02_F00E": preload("res://assets/ui/cg_gallery/A02_F00E.webp"),
	"A02_P01E": preload("res://assets/ui/cg_gallery/A02_P01E.webp"),
	"A02_P02E": preload("res://assets/ui/cg_gallery/A02_P02E.webp"),
	"A02_P03E": preload("res://assets/ui/cg_gallery/A02_P03E.webp"),
	"S01_F00E": preload("res://assets/ui/cg_gallery/S01_F00E.png"),
	"S01_P01E": preload("res://assets/ui/cg_gallery/S01_P01E.webp"),
	"S01_P02E": preload("res://assets/ui/cg_gallery/S01_P02E.webp"),
	"S01_P03E": preload("res://assets/ui/cg_gallery/S01_P03E.webp"),
	"S07_F00E": preload("res://assets/ui/cg_gallery/S07_F00E.webp"),
	"S07_P01E": preload("res://assets/ui/cg_gallery/S07_P01E.webp"),
	"S07_P02E": preload("res://assets/ui/cg_gallery/S07_P02E.webp"),
	"S08_F00E": preload("res://assets/ui/cg_gallery/S08_F00E.webp"),
}
const FACTIONS := {
	"allied": {"name":"盟军", "icon":preload("res://assets/ui/cg_gallery/allied.svg"), "light":"#a5d6f2", "line":"#8bc5e5", "border":"#567e98", "card_border":"#567e98", "top":"#273d50", "bottom":"#1b2632"},
	"soviet": {"name":"苏军", "icon":preload("res://assets/ui/cg_gallery/soviet.svg"), "light":"#ffc1ac", "line":"#ef9e85", "border":"#a5675a", "card_border":"#ac695b", "top":"#413031", "bottom":"#251f24"},
}
const DESIGN := Vector2(1440, 900)
const TEXT := Color("#e8ebef")
const BODY := Color("#c1c9d2")
const SMALL := Color("#aab6c3")
const RETURN_TAB := "cg_collection_return_tab"

var page: Control
var status: Label
var active_faction := "soviet"
var _bold: SystemFont
var _number: SystemFont
var _views := {}
var _tabs := {}
var _tab_active := {}
var _tab_counts := {}
var _tab_group := ButtonGroup.new()

func _ready() -> void:
	_bold = SystemFont.new()
	_bold.font_names = PackedStringArray(UiTheme.FONT_CANDIDATES)
	_bold.font_weight = 700
	_number = SystemFont.new()
	_number.font_names = PackedStringArray(["Consolas", "monospace"])
	_number.font_weight = 700
	_gradient(self, [Color("#17202b"),Color("#0e151e"),Color("#0b1017")], PackedFloat32Array([0.0,0.46,1.0])).set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page = Control.new()
	add_child(page)
	page.size = DESIGN
	resized.connect(_fit_page)
	_fit_page()

	var top_rule := ColorRect.new()
	top_rule.color = Color("#4c5c6d")
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rule)
	top_rule.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top_rule.offset_top = 1
	top_rule.offset_bottom = 2
	_solid(page,Rect2(48,46,23,2),Color("#e79a82"))
	_text(page,Rect2(81,36,180,21),"战役档案",13,Color("#aab8c6"))
	_text(page,Rect2(46,64,500,52),"CG 收藏",42,TEXT,true)
	status = _text(page,Rect2(48,116,800,24),"战役影片首次播放自动收藏并发奖，跳过也算。每段奖励：" + Catalog.reward_text(),14,BODY)
	var back := _button(page,Rect2(1260,41,132,38),"返回主菜单",_back)
	back.add_theme_stylebox_override("normal",_style(Color("#1c2632"),6,Color("#465665")))
	back.add_theme_stylebox_override("hover",_style(Color("#273543"),6,Color("#738b9f")))
	back.add_theme_stylebox_override("pressed",_style(Color("#1c2632"),6,Color("#8fa7b9")))
	_text(back,Rect2(0,0,132,38),"‹  返回主菜单",14,BODY,false,HORIZONTAL_ALIGNMENT_CENTER)
	var total := Vector2i.ZERO
	var counts := {"allied":Vector2i.ZERO,"soviet":Vector2i.ZERO}
	for group in Catalog.GROUPS:
		var subtotal := _count(group.clips)
		total += subtotal
		counts[group.faction] += subtotal
	_panel(page,Rect2(1264,118,6,6),_style(Color("#e79a82"),3))
	_text(page,Rect2(1277,108,115,24),"战役影片  %d / %d" % [total.x,total.y],14,SMALL,false,HORIZONTAL_ALIGNMENT_RIGHT)
	var progress := ProgressBar.new()
	progress.name = "CampaignCGProgress"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.show_percentage = false
	progress.step = 1.0
	progress.max_value = maxi(1,total.y)
	progress.value = total.x
	progress.add_theme_stylebox_override("background",_style(Color("#25313e"),4,Color("#465665")))
	progress.add_theme_stylebox_override("fill",_style(Color("#e79a82"),4))
	_place(page,progress,Rect2(1168,136,224,8))
	_solid(page,Rect2(48,203,1344,1),Color("#37434f"))
	_make_tab("allied",48,counts.allied)
	_make_tab("soviet",224,counts.soviet)
	var yuriko := _button(page,Rect2(1213,157,179,46),"百合子手记",_open_yuriko)
	yuriko.name = "YurikoJournal"
	yuriko.tooltip_text = "打开百合子 CG 集 · 婚纱 CG %d / 2" % (2 if Book.owns_wedding_cg() else 0)
	var avatar := _screen(yuriko,Rect2(44,8,30,30),PORTRAIT,2)
	avatar.name = "YurikoPortrait"
	_text(yuriko,Rect2(81,0,98,46),"百合子手记  ↗",14,BODY,false,HORIZONTAL_ALIGNMENT_RIGHT)
	for faction in FACTIONS:
		_make_faction(faction)
	_solid(page,Rect2(48,857,1344,1),Color("#323e4b"))
	_text(page,Rect2(48,863,830,25),"未解锁的影片只显示雪花，不会提前透露剧情画面。",13,SMALL)
	var requested: String = get_tree().get_meta(RETURN_TAB,active_faction)
	if get_tree().has_meta(RETURN_TAB): get_tree().remove_meta(RETURN_TAB)
	_select_faction(requested if FACTIONS.has(requested) else active_faction)

func _fit_page() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if factor <= 0.0: return
	page.scale = Vector2.ONE * factor
	page.position = (size - DESIGN * factor) * 0.5

func _make_tab(faction: String, x: int, count: Vector2i) -> void:
	var spec: Dictionary = FACTIONS[faction]
	var tab := _button(page,Rect2(x,157,166,46),spec.name,_select_faction.bind(faction))
	tab.tooltip_text = "%s · 已收藏 %d / %d" % [spec.name,count.x,count.y]
	tab.name = "Tab_" + faction
	tab.toggle_mode = true
	tab.button_group = _tab_group
	_tabs[faction] = tab
	_panel(tab,Rect2(0,0,166,46),_style(Color("#18232e"),6,Color("#3d5161")))
	var active := _panel(tab,Rect2(0,0,166,46),_style(Color.WHITE,6,Color(spec.border)))
	_gradient(active,[Color(spec.top),Color(spec.bottom)],PackedFloat32Array([0.0,1.0]),Rect2(1,1,164,44),5)
	_solid(active,Rect2(6,44,154,2),Color(spec.line))
	_tab_active[faction] = active
	_texture(tab,Rect2(15,12,20,20),spec.icon)
	_text(tab,Rect2(46,0,63,46),spec.name,17,TEXT,true)
	_tab_counts[faction] = _text(tab,Rect2(102,0,42,46),"%d / %d" % [count.x,count.y],14,SMALL,false,HORIZONTAL_ALIGNMENT_RIGHT)

func _select_faction(faction: String) -> void:
	active_faction = faction
	for key in FACTIONS:
		var selected: bool = key == faction
		_views[key].visible = selected
		_tabs[key].set_pressed_no_signal(selected)
		_tab_active[key].visible = selected
		_tab_counts[key].add_theme_color_override("font_color",Color(FACTIONS[key].light) if selected else SMALL)
		_tab_counts[key].add_theme_font_override("font",_bold if selected else get_theme_default_font())

func _make_faction(faction: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Gallery_" + faction
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(page,scroll,Rect2(48,215,1360,632))
	_views[faction] = scroll
	var contents := Control.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(contents)
	var section := 0
	for group in Catalog.groups_for_faction(faction):
		var y := 25 + section * 314
		var spec: Dictionary = FACTIONS[faction]
		_panel(contents,Rect2(0,y-17,34,26),_style(Color(spec.bottom).lightened(0.08),4,Color(spec.border).darkened(0.4)))
		var number := _text(contents,Rect2(0,y-17,34,26),group.chapter,16,Color(spec.light),true,HORIZONTAL_ALIGNMENT_CENTER)
		number.add_theme_font_override("font",_number)
		_text(contents,Rect2(48,y-18,500,31),group.title,22,TEXT,true)
		var count := _count(group.clips)
		_text(contents,Rect2(1100,y-17,244,27),"已收藏  %d / %d" % [count.x,count.y],14,SMALL,false,HORIZONTAL_ALIGNMENT_RIGHT)
		for i in group.clips.size():
			_card(contents,Vector2(342*i,y+20),group.clips[i],section*4+i,spec)
		section += 1
	contents.custom_minimum_size = Vector2(1344,section * 314)

func _card(parent: Control, pos: Vector2, clip: Array, index: int, spec: Dictionary) -> void:
	var id: String = clip[0]
	var unlocked: bool = MetaProgress.campaign_cg.get(id) == true
	var button := _button(parent,Rect2(pos,Vector2(320,252)),clip[1])
	button.name = id
	button.disabled = not unlocked
	button.tooltip_text = "回看：" + clip[1] if unlocked else "未解锁 · " + clip[2]
	if unlocked: button.pressed.connect(_replay.bind(id,button))
	var bg := Color("#141b24")
	var edge := Color(spec.card_border) if unlocked else Color("#303942")
	button.add_theme_stylebox_override("normal",_style(bg,10,edge))
	button.add_theme_stylebox_override("disabled",_style(bg,10,edge))
	button.add_theme_stylebox_override("hover",_style(bg.lightened(0.045),10,Color(spec.line)))
	button.add_theme_stylebox_override("pressed",_style(bg,10,Color(spec.light)))
	var poster: Texture2D = POSTERS.get(id) if unlocked else null
	var preview := _screen(button,Rect2(8,8,304,171),poster if poster else SNOW,1 if poster else 0,Vector2(index*19%38,index*17%31))
	preview.name = "FilmPreview"
	_text(button,Rect2(16,187,220,31),clip[1],17,TEXT,true)
	if unlocked:
		_texture(button,Rect2(135,69,50,50),PLAY)
		_panel(button,Rect2(18,18,76,23),_style(Color("#171a20e6"),4))
		_panel(button,Rect2(26,26.5,6,6),_style(Color(spec.line),3))
		_text(button,Rect2(39,18,59,23),"已收藏",12,TEXT,true)
		_text(button,Rect2(16,216,260,27),"已解锁 · 可回看",14,BODY)
		_text(button,Rect2(231,187,69,31),"回看  ›",14,Color(spec.light),true,HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_panel(button,Rect2(100,78,120,31),_style(Color("#11161cee"),5,Color("#c4c6ca6b")))
		_texture(button,Rect2(120,86,12,15),LOCK)
		_text(button,Rect2(141,78,64,31),"无信号",12,TEXT,true)
		_text(button,Rect2(16,216,288,27),clip[2],14,Color("#a7b2bf"))

func _count(clips: Array) -> Vector2i:
	var owned := 0
	for clip in clips:
		if MetaProgress.campaign_cg.get(clip[0]) == true: owned += 1
	return Vector2i(owned,clips.size())

func _place(parent: Control, control: Control, bounds: Rect2) -> void:
	parent.add_child(control)
	control.position = bounds.position
	control.size = bounds.size

func _style(bg: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	return style

func _panel(parent: Control, bounds: Rect2, style: StyleBoxFlat) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",style)
	_place(parent,panel,bounds)
	return panel

func _solid(parent: Control, bounds: Rect2, fill: Color) -> void:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = fill
	_place(parent,rect,bounds)

func _text(parent: Control, bounds: Rect2, value: String, font_size: int, color: Color, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	if bold: label.add_theme_font_override("font",_bold)
	_place(parent,label,bounds)
	return label

func _texture(parent: Control, bounds: Rect2, tex: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = tex
	_place(parent,picture,bounds)
	return picture

func _gradient(parent: Control, colors: PackedColorArray, offsets: PackedFloat32Array, bounds := Rect2(), corner := 0) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 2
	tex.height = 256
	tex.fill_to = Vector2(0,1)
	var picture := _texture(parent,bounds,tex)
	if corner > 0:
		var clipper := _panel(parent,bounds,_style(Color.WHITE,corner))
		clipper.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		picture.reparent(clipper,false)
		picture.position = Vector2.ZERO
	return picture

func _screen(parent: Control, bounds: Rect2, tex: Texture2D, kind: int, offset := Vector2.ZERO) -> TextureRect:
	var picture := _texture(parent,bounds,tex)
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	mat.set_shader_parameter("screen_type",kind)
	mat.set_shader_parameter("snow_offset",offset)
	picture.material = mat
	return picture

func _button(parent: Control, bounds: Rect2, caption: String, action := Callable()) -> Button:
	var button := Button.new()
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		button.add_theme_stylebox_override(state,empty)
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color","font_hover_pressed_color"]:
		button.add_theme_color_override(key,Color.TRANSPARENT)
	var focus := _style(Color.TRANSPARENT,6,Color("#9ab7cc"))
	focus.draw_center = false
	button.add_theme_stylebox_override("focus",focus)
	_place(parent,button,bounds)
	if action.is_valid(): button.pressed.connect(action)
	return button

func _replay(id: String, button: Button) -> void:
	if not page.visible: return
	if Film.show_replay(self,id,_return_from_replay.bind(button)):
		page.hide()
	else:
		status.text = "这段影片无法播放，请检查游戏资源。"

func _return_from_replay(button: Button) -> void:
	page.show()
	button.grab_focus()

func _open_yuriko() -> void:
	var tree := get_tree()
	if tree.change_scene_to_file("res://scenes/yuriko_school.tscn") == OK:
		tree.set_meta("yuriko_from_cg_collection",true)
		tree.set_meta(RETURN_TAB,active_faction)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if page.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
