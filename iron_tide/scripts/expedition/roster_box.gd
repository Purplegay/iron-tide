extends HBoxContainer

const Army=preload("res://scripts/expedition/army.gd")
const Plan=preload("res://scripts/expedition/reinforcement_plan.gd")
const Insights=preload("res://scripts/expedition/insights.gd")
signal changed(ok:bool)
var picked:=""
var times:Dictionary={}

class Slot extends Button:
	var board
	var unit_id:=""
	var slot_index:=-1

	func _get_drag_data(_at:Vector2) -> Variant:
		if unit_id.is_empty():return null
		board.select_unit(unit_id)
		var ghost:=UiKit.make_label(text,15,UiKit.COL_ACCENT_2)
		set_drag_preview(ghost)
		return {"board":board,"unit":unit_id}

	func _can_drop_data(_at:Vector2,payload:Variant) -> bool:
		if not payload is Dictionary or payload.get("board")!=board:return false
		var id:String=payload.get("unit","")
		return id!=unit_id and (slot_index>=0 or id in Expedition.state.active_roster)

	func _drop_data(at:Vector2,payload:Variant) -> void:
		if _can_drop_data(at,payload):board.move(payload.unit,self)

func _ready() -> void:
	add_theme_constant_override("separation",14)
	var run:Dictionary=Expedition.state
	for unit:Dictionary in Army.inventory(run):
		if not str(unit.get("hero","")).is_empty():continue
		var due:=Plan.delay_for(unit.id,"",run,str(unit.get("variant","")))
		times[unit.id]=minf(float(times.get(unit.id,INF)),due)
	var left:=section("本关出战")
	left.get_parent().size_flags_stretch_ratio=1.6
	var slots:=GridContainer.new()
	left.add_child(slots)
	slots.add_theme_constant_override("h_separation",6)
	slots.add_theme_constant_override("v_separation",6)
	slots.resized.connect(func():slots.columns=clampi(floori(slots.size.x/200.0),1,3))
	var cells:=Expedition.formation_slots()
	for i in cells.size():tile(slots,cells[i],i)
	var right:=section("预备兵种")
	for id:String in Army.available(run):
		if id not in cells:tile(right,id,-1)
	tile(right,"",-1)

func section(title:String) -> VBoxContainer:
	var panel:=UiKit.make_panel(UiKit.COL_PANEL,UiKit.COL_LINE)
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(panel)
	var column:=VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UiKit.make_label(title,17,UiKit.COL_GOLD))
	return column

func tile(parent:Control,id:String,index:int) -> void:
	var button:=Slot.new()
	button.board=self
	button.unit_id=id
	button.slot_index=index
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y=54
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.toggle_mode=true
	button.text="拖回预备栏" if index<0 else "空槽 %d"%[index+1]
	if not id.is_empty():
		button.text="%s ×%d"%[Army.training_name(id),Army.quantity(Expedition.state,id)]
		if times.has(id):button.text+="\n首批 "+Insights.time_text(times[id])
		var portrait:=UnitIcon.new()
		portrait.animate=false;portrait.show_status=false
		portrait.setup(GameData.get_unit(id),UiKit.COL_ACCENT_2)
		portrait.custom_minimum_size=Vector2(44,36)
		portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(portrait)
		portrait.position=Vector2(4,6)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		# Keep the button's normal, hover and selection backgrounds.
		for state in ["normal","hover","pressed","hover_pressed","focus"]:
			var style:=button.get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_left=52
			button.add_theme_stylebox_override(state,style)
	parent.add_child(button)
	button.pressed.connect(choose.bind(button))

func select_unit(id:String) -> void:
	picked=id
	for tile_button in find_children("*","Button",true,false):
		tile_button.set_pressed_no_signal(not id.is_empty() and tile_button.unit_id==id)

func choose(target:Slot) -> void:
	if picked.is_empty() or target.unit_id==picked:
		select_unit("" if picked==target.unit_id else target.unit_id)
	elif target.slot_index<0 and picked not in Expedition.state.active_roster:
		select_unit(target.unit_id)
	else:
		move(picked,target)

func move(id:String,target:Slot) -> void:
	var ok:bool
	if target.slot_index < 0 and not target.unit_id.is_empty():
		# Bring the reserve into the exact slot vacated by the outgoing type.
		var source_slot:=Expedition.formation_slots().find(id)
		ok=source_slot>=0 and target.unit_id not in Expedition.state.active_roster and Expedition.move_formation(target.unit_id,source_slot)
	else:
		ok=Expedition.move_formation(id,target.slot_index)
	select_unit("")
	changed.emit(ok)
