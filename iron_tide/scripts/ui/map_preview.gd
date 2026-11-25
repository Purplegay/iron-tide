extends Control
const Maps=preload("res://scripts/world/skirmish_maps.gd")
const Native=preload("res://scripts/world/native_maps.gd")
signal spawn_clicked(index:int)
const Houses=preload("res://scripts/rules/skirmish_houses.gd")
var pins:Array[Button]=[]
var pin_positions:=PackedVector2Array()
var map_id:="coast"
var mark_broken_bridge:=false
var preview:Texture2D
var world_size:=3200.0

func show_map(id:String,selected_size:=3200.0) -> void:
	map_id=id
	world_size=selected_size
	preview=load("res://assets/maps/yr/%s_preview.png"%id) if Native.has(id) else null
	_rebuild_positions()
	_layout_pins()
	queue_redraw()

func _image_area() -> Rect2:
	var extent:=size-Vector2(16,16)
	if preview!=null:
		var pixels:=preview.get_size()
		extent=pixels*minf(extent.x/pixels.x,extent.y/pixels.y)
	return Rect2((size-extent)*0.5,extent)

func _rebuild_positions() -> void:
	# Native positions can reference the shared map cache. Detach before rebuilding.
	pin_positions = PackedVector2Array()
	var starts:=Houses.starts(map_id,world_size)
	if not Native.has(map_id):
		for point in starts:pin_positions.append(point/world_size)
		return
	var data:=Native.data(map_id)
	if not data.has("preview_spawn_points"):
		var bounds:=Rect2()
		var first:=true
		for tile:Array in data.cells:
			var pos:=Vector2(tile[0]+tile[1],tile[1]-tile[0])
			bounds=Rect2(pos,Vector2.ZERO) if first else bounds.expand(pos)
			first=false
		var normalized:=PackedVector2Array()
		for start in starts:
			var nearest:=INF
			var mark:=Vector2.ZERO
			for row:Array in data.starts:
				var point:=Vector2(row[1],row[2])
				var dist:=start.distance_squared_to(point*Native.CELL)
				if dist<nearest:
					nearest=dist
					mark=Vector2(point.x+point.y-1,point.y-point.x)
			normalized.append((mark-bounds.position)/bounds.size)
		data.preview_spawn_points=normalized
	pin_positions=data.preview_spawn_points

func set_roster(rows:Array, selected:int) -> void:
	for pin in pins:remove_child(pin);pin.queue_free()
	pins.clear()
	var color_ids := HouseColor.roster_color_ids(rows)
	for index in pin_positions.size():
		var pin:=Button.new()
		var owner_index:=-1
		for i in rows.size():
			if int(rows[i].get("spawn",rows[i].get("seat",i)))==index:owner_index=i
		var name_text:="空位"
		var color:=Color("#79858c")
		if owner_index>=0:
			var row:Dictionary=rows[owner_index]
			name_text="玩家" if owner_index==0 else Houses.commander_label(row,owner_index)
			color=Color(HouseColor.hex_of(color_ids[owner_index]))
		pin.text=str(index+1)
		pin.tooltip_text="%d 号出生点 · %s"%[index+1,name_text]
		pin.add_theme_font_size_override("font_size",13)
		var style:=StyleBoxFlat.new()
		style.bg_color=color.darkened(0.5)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color=Color.WHITE if owner_index==selected else color
		pin.add_theme_stylebox_override("normal",style)
		pin.size=Vector2(24,22)
		pin.pressed.connect(func():spawn_clicked.emit(index))
		add_child(pin);pins.append(pin)
	_layout_pins()

const Preferences=preload("res://scripts/ui/lobby_preferences.gd")

func _notification(what:int) -> void:
	if what==NOTIFICATION_RESIZED:_layout_pins()

func _layout_pins() -> void:
	var area:=_image_area()
	for i in mini(pins.size(),pin_positions.size()):
		var pin:=pins[i]
		pin.position=(area.position+area.size*pin_positions[i]-pin.size*0.5).clamp(Vector2.ZERO,(size-pin.size).max(Vector2.ZERO))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("101b24"))
	if preview!=null:
		var extent:=preview.get_size()
		var scale_factor:=minf((size.x-16)/extent.x,(size.y-16)/extent.y)
		var drawn:=extent*scale_factor
		draw_texture_rect(preview,Rect2((size-drawn)*.5,drawn),false)
	else:
		var area:=Rect2(Vector2(8,8),size-Vector2(16,16))
		draw_rect(area,Color("667c45"))
		var water:Array=[]
		if Maps.custom(map_id):water=Maps.water(map_id,1.0)
		elif map_id=="coast":water=[Rect2(.09,.26,.17,.12),Rect2(.58125,.04,.41875,.92)]
		else:
			var width:=.14 if map_id=="crossings" else .32
			water=[Rect2((1-width)/2,0,width,1)]
		for lake:Rect2 in water:draw_rect(Rect2(area.position+lake.position*area.size,lake.size*area.size),Color("207c9c"))
		if Maps.custom(map_id):
			for bridge:Dictionary in Maps.bridges(map_id,world_size):
				var span:Rect2=bridge.span
				draw_rect(Rect2(area.position+span.position/world_size*area.size,span.size/world_size*area.size),Color("c7ad77"))
				if mark_broken_bridge and not bridge.intact:
					draw_arc(area.position+span.get_center()/world_size*area.size,8.0,0,TAU,24,Color.LIGHT_SKY_BLUE,2,true)
			for key in ["ore","enemy_ore","gems","oil"]:
				for point:Vector2 in Maps.points(map_id,key,1):draw_circle(area.position+point*area.size,2.5,Color("f3d26c") if key!="oil" else Color.WHITE)
		var ally:=Vector2(.5 if map_id=="coast" else .22,.8)
		var enemy:=Vector2(.5 if map_id=="coast" else .78,.16)
		if Maps.custom(map_id):
			ally=Maps.start(map_id,world_size)/world_size;enemy=Maps.start(map_id,world_size,true)/world_size
		if pins.is_empty():
			draw_circle(area.position+ally*area.size,5,Color.CYAN)
			draw_circle(area.position+enemy*area.size,5,Color.CORAL)
	draw_rect(Rect2(Vector2.ZERO,size),Color("699ab5"),false,1)
