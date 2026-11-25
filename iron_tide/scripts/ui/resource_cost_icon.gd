extends RefCounted
## Resource badges share the dimensions of the progression icons.
const SHAPES := {
	"cores":["#ffcc68","M12 2L21 7V17L12 22L3 17V7ZM12 6L17 12L12 18L7 12Z"],
	"credits":["#a9e386","M2 6H22V18H2ZM5 9H7M17 15H19M12 9L15 12L12 15L9 12Z"],
	"diamonds":["#7ce5ff","M2 8L7 3H17L22 8L12 21ZM2 8H22M8 8L12 21L16 8"],
	"skin_ticket":["#ffa6b7","M2 5H22V10Q18 12 22 14V19H2V14Q6 12 2 10ZM12 8L15 12L12 16L9 12Z"],
	"tickets":["#ae9aff","M2 5H22V10Q18 12 22 14V19H2V14Q6 12 2 10ZM15 6V9M15 11V13M15 15V18"],
	"card_shards":["#dc9cff","M3 18L8 4L13 11L9 18ZM13 20L17 9L21 15L18 20Z"],
	"victory_shards":["#ffa568","M3 6H12L9 11L12 15L7 19H3ZM15 6H21V18H12L16 14L13 11Z"],
	"supplies":["#e8bf72","M2 8L12 3L22 8V17L12 22L2 17ZM2 8L12 13L22 8M12 13V22M7 6L17 11"],
	"kits":["#7de3c2","M3 8H21V21H3ZM8 8V4H16V8M12 11V18M8 14H16"],
	"talent_points":["#f3c8ff","M12 2L15 9L22 10L17 15L18 22L12 18L6 22L7 15L2 10L9 9Z"]}
static var cache:Dictionary={}

static func texture(id:String, second:="") -> Texture2D:
	if not SHAPES.has(id):return null
	var key:=id+"/"+second
	if cache.has(key):return cache[key]
	var ids:=[id]
	if SHAPES.has(second):ids.append(second)
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="24">'%(ids.size()*24)
	for i in ids.size():
		var shape:Array=SHAPES[ids[i]]
		svg+='<g transform="translate(%d 0)"><rect width="24" height="24" rx="4" fill="#172130"/><path d="%s" fill="none" stroke="%s" stroke-width="1.8" stroke-linejoin="round"/></g>'%[i*24,shape[1],shape[0]]
	var image:=Image.new()
	if image.load_svg_from_string(svg+"</svg>")!=OK:return null
	cache[key]=ImageTexture.create_from_image(image)
	return cache[key]

static func balance_label(parent:Control, id:String, text:String, font_size:int, color:Color) -> Label:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	var badge:=TextureRect.new()
	badge.name="ResourceIcon"
	badge.texture=texture(id)
	badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size=Vector2(font_size+3,font_size+3)
	badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var label:=UiKit.make_label(text,font_size,color)
	row.add_child(label)
	return label
