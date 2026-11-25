extends Window

const Plans = preload("res://scripts/rules/opening_order_plans.gd")
var book: Dictionary
var picker := OptionButton.new()
var plan_name := LineEdit.new()
var faction := "allied"
var catalog := GridContainer.new()
var orders := HFlowContainer.new()
var info := Label.new()
var reorder := UiKit.make_button("调整顺序", 14)
var move_from := -1

func _ready() -> void:
	title = "开局出兵预设"
	transient = true
	exclusive = true
	book = Plans.current(MetaProgress.academy)
	size = Vector2i(680,480).min(get_parent().get_viewport_rect().size * 0.9)
	var box := VBoxContainer.new()
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := HBoxContainer.new()
	box.add_child(toolbar)
	toolbar.add_child(picker)
	plan_name.placeholder_text = "方案名称"
	plan_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(plan_name)
	var add := UiKit.make_button("新建方案")
	toolbar.add_child(add)
	add.pressed.connect(_new_plan)
	picker.item_selected.connect(_select_plan)
	plan_name.text_changed.connect(func(text):
		book.plans[book.selected].name = text
		picker.set_item_text(book.selected,text))
	_sync_picker()
	var side := UiKit.make_option(["盟军", "苏军"],0,16)
	box.add_child(side)
	side.item_selected.connect(func(i): faction = "allied" if i==0 else "soviet"; refresh())
	box.add_child(UiKit.make_label("点击兵种添加一名，可切换阵营继续添加。",15))
	var list := ScrollContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	catalog.columns = 4
	list.add_child(catalog)
	var order_bar := HBoxContainer.new()
	box.add_child(order_bar)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_bar.add_child(info)
	order_bar.add_child(reorder)
	reorder.toggle_mode = true
	reorder.toggled.connect(func(_active): move_from = -1; refresh_orders())
	var preview := ScrollContainer.new()
	preview.custom_minimum_size.y = 100
	box.add_child(preview)
	orders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(orders)
	var save_button := UiKit.make_button("保存全部并启用当前方案")
	box.add_child(save_button)
	save_button.pressed.connect(_save)
	close_requested.connect(queue_free)
	refresh()

func tile(parent:Control, id:String, prefix:String, action:Callable, quantity:int=1) -> Button:
	var data := GameData.get_unit(id)
	var button := UiKit.make_button(prefix+str(data.get("name",id))+(" ×%d"%quantity if quantity>1 else ""),14)
	button.tooltip_text = str(data.get("name",id))+" · "+str(int(data.get("cost",0)))+" 资金"
	var portrait := UnitIcon.new()
	portrait.setup(data,UiKit.COL_ACCENT,1,1,true)
	portrait.animate = false
	portrait.show_status = false



	var container := HBoxContainer.new()
	parent.add_child(container)
	container.add_child(portrait)
	container.add_child(button)
	portrait.mouse_filter=Control.MOUSE_FILTER_STOP
	portrait.tooltip_text=button.tooltip_text
	portrait.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:action.call())
	button.pressed.connect(action)
	return button

func refresh() -> void:
	for child in catalog.get_children():catalog.remove_child(child);child.queue_free()
	for id:String in GameData.faction_unit_catalog(faction,true):
		if GameData.get_unit(id).get("built_at","")=="":continue
		tile(catalog,id,"",func():book.plans[book.selected].orders.append(id);refresh_orders())
	refresh_orders()

func refresh_orders() -> void:
	for child in orders.get_children():orders.remove_child(child);child.queue_free()
	var draft:Array=book.plans[book.selected].orders
	info.text="开局订单 · %d 项"%draft.size()
	reorder.text = "完成排序" if reorder.button_pressed else "调整顺序"
	if reorder.button_pressed:
		info.text += "　先点要移动的组" if move_from < 0 else "　再点目标位置"
	elif not draft.is_empty():
		info.text += "　点击订单移除一名"
	var first := 0
	while first < draft.size():
		var end := first + 1
		while end < draft.size() and draft[end] == draft[first]:
			end += 1
		var button := tile(orders, str(draft[first]), "", _order_clicked.bind(first, end), end - first)
		if reorder.button_pressed and first == move_from:
			button.toggle_mode = true
			button.set_pressed_no_signal(true)
		first = end

func _order_clicked(first: int, end: int) -> void:
	var draft: Array = book.plans[book.selected].orders
	if not reorder.button_pressed:
		draft.remove_at(first)
	elif move_from < 0:
		move_from = first
	else:
		var move_end := move_from + 1
		while move_end < draft.size() and draft[move_end] == draft[move_from]:
			move_end += 1
		var group := draft.slice(move_from, move_end)
		if first < move_from:
			book.plans[book.selected].orders = draft.slice(0, first) + group + draft.slice(first, move_from) + draft.slice(move_end)
		elif first > move_from:
			book.plans[book.selected].orders = draft.slice(0, move_from) + draft.slice(move_end, end) + group + draft.slice(end)
		move_from = -1
	refresh_orders()

func _select_plan(index:int) -> void:
	move_from = -1
	reorder.set_pressed_no_signal(false)
	book.selected=index
	plan_name.text=book.plans[index].name
	refresh_orders()

func _sync_picker() -> void:
	picker.clear()
	for plan in book.plans:picker.add_item(plan.name)
	picker.select(book.selected)
	_select_plan(book.selected)

func _new_plan() -> void:
	var number:int=book.plans.size()+1
	while book.plans.any(func(plan):return plan.name==str(number)):number+=1
	book.selected=book.plans.size()
	book.plans.append({"name":str(number),"orders":[]})
	_sync_picker()

func _save() -> void:
	var names:Dictionary={}
	for plan in book.plans:
		var title_text:=str(plan.name).strip_edges()
		if title_text.is_empty() or names.has(title_text):
			info.text="请为每套方案填写不同的名称。"
			return
		names[title_text]=true
		plan.name=title_text
	if not Plans.persist(book):
		info.text="保存失败，请重试。"
		return
	Events.meta_changed.emit()
	queue_free()
