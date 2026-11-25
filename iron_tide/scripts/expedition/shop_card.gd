extends RefCounted
const DISABLED_SHADER=preload("res://shaders/shop_unavailable.gdshader")

static func apply(box:VBoxContainer,index:int,sold:bool,reason:String) -> void:
	var shell:PanelContainer=box.get_parent()
	shell.set_meta("shop_index",index)
	shell.set_meta("purchase_state","sold" if sold else "unavailable" if not reason.is_empty() else "available")
	shell.set_meta("purchase_reason",reason)
	shell.tooltip_text=reason
	if reason.is_empty():return
	var style:StyleBoxFlat=shell.get_theme_stylebox("panel").duplicate()
	style.bg_color=Color("#22252a") if sold else Color("#32262b")
	style.border_color=Color("#60656c") if sold else Color("#a46f76")
	shell.add_theme_stylebox_override("panel",style)
	var material:=ShaderMaterial.new()
	material.shader=DISABLED_SHADER
	material.set_shader_parameter("sold_out",sold)
	shell.material=material
	inherit_material(shell)

static func add_new_badge(box: VBoxContainer) -> void:
	var badge := Label.new()
	badge.name = "NewStockBadge"
	badge.text = "NEW!"
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.8
	font.variation_transform = Transform2D(Vector2.RIGHT, Vector2(-0.2, 1), Vector2.ZERO)
	badge.add_theme_font_override("font", font)
	badge.add_theme_font_size_override("font_size", 19)
	badge.add_theme_color_override("font_color", Color("ffab50"))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(badge)
	box.move_child(badge, 1)

static func discount_percent(item:Dictionary) -> int:
	var original:=int(item.get("original_price",0))
	var price:=int(item.get("price",0))
	if not item.get("discounted",false) or original<=0 or price<0 or price>=original:return 0
	return clampi(roundi(100.0*(original-price)/original),1,100)

static func add_discount(box:VBoxContainer,item:Dictionary) -> void:
	var percent:=discount_percent(item)
	if percent<=0:return
	var shell:PanelContainer=box.get_parent()
	var overlay:=Control.new()
	overlay.name="DiscountOverlay"
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shell.add_child(overlay)
	var badge:=Label.new()
	badge.name="DiscountBadge"
	badge.text="-%d%%"%percent
	badge.tooltip_text="原价 %d 补给 · 现价 %d 补给"%[item.original_price,item.price]
	badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size",18)
	badge.add_theme_color_override("font_color",Color("#241a06"))
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("#ffd34e")
	style.set_corner_radius_all(5)
	badge.add_theme_stylebox_override("normal",style)
	overlay.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left=-70;badge.offset_right=-4
	badge.offset_top=4;badge.offset_bottom=34
	var header:=box.get_child(0)
	var space:=Control.new();space.custom_minimum_size.x=70
	space.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.add_child(space)
	# The discount remains yellow even when unavailable stock is tinted.
	overlay.use_parent_material=false
	badge.use_parent_material=false

static func inherit_material(parent:Node) -> void:
	for child in parent.get_children():
		if child is CanvasItem:child.use_parent_material=true
		inherit_material(child)
