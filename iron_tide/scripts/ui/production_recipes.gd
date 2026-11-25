extends Window

var hud
var category: String
var bucket: String
var factory: Building
var default_key: String
var draft: Array = []
var grid := GridContainer.new()
var page_drafts := {}
var draft_key: String
var plan_button := Button.new()
var choices := OptionButton.new()
var title_edit := LineEdit.new()
var preview := Label.new()
var message := Label.new()

static func open(owner_hud) -> void:
	if is_instance_valid(owner_hud._recipe_window) and not owner_hud._recipe_window.is_queued_for_deletion():
		owner_hud._recipe_window.grab_focus()
		return
	var window = load("res://scripts/ui/production_recipes.gd").new()
	owner_hud._recipe_window = window
	window.hud = owner_hud
	owner_hud.add_child(window)
	window.popup_centered_clamped(Vector2i(560, 480))

func _ready() -> void:
	transient = true
	exclusive = false
	close_requested.connect(queue_free)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(plan_button)
	plan_button.clip_text = true
	plan_button.pressed.connect(func(): hud._opening_orders_button.pressed.emit())
	hud._sync_plan_button(plan_button, hud.battle.allied_state.get("opening_orders_pending", []))
	box.add_child(choices)
	choices.item_selected.connect(_on_choice)
	title_edit.placeholder_text = "配方名称"
	title_edit.max_length = 32
	box.add_child(title_edit)
	box.add_child(preview)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.max_lines_visible = 3
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	grid.columns = 3
	scroll.add_child(grid)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "撤回末项", _undo)
	_button(actions, "保存配方", _save)
	_button(actions, "删除所选", _remove)
	_button(actions, "整组下单", _order)
	_button(actions, "关闭", queue_free)
	box.add_child(message)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_page()

func sync_from_deck() -> void:
	if not hud._recipe_button.visible:
		queue_free()
		return
	var active = hud._factories.current()
	var active_id: int = active.get_instance_id() if active else 0
	if category == hud.prod_tab and draft_key == "%s/%d" % [bucket, active_id]:
		return
	_keep_draft()
	_load_page()

func _keep_draft() -> void:
	page_drafts[draft_key] = [choices.get_item_text(choices.selected) if choices.selected > 0 else "", title_edit.text, draft.duplicate()]

func _load_page() -> void:
	category = hud.prod_tab
	factory = hud._factories.current()
	var faction: String = factory.faction if factory else hud.battle.roster_faction()
	bucket = faction + "/" + category
	draft_key = "%s/%d" % [bucket, factory.get_instance_id() if factory else 0]
	message.text = ""
	default_key = bucket + "/" + factory.building_id if factory else ""
	title = "生产配方 · " + str(hud._tab_label(category))
	if factory:
		title += " · %s %d" % [factory.display_name, hud._factories.number_for(factory)]
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for uid: String in hud._unit_catalog():
		if hud._cat_match(GameData.get_unit(uid)):
			_button(grid, hud._entity_name(uid), _append.bind(uid))
	if page_drafts.has(draft_key):
		var saved: Array = page_drafts[draft_key]
		_refresh(saved[0])
		title_edit.text = saved[1]
		draft = saved[2].duplicate()
		_update_preview()
		return
	var last: String = MetaProgress.recipe_defaults.get(default_key, "")
	if factory:
		last = factory.special.get("recipe_selection", {}).get(category, last)
	_refresh(last)
	_remember_here(title_edit.text)

func _button(parent: Control, label: String, action: Callable) -> void:
	var button := UiKit.make_button(label, 14)
	parent.add_child(button)
	button.pressed.connect(action)

func _refresh(selected_name: String) -> void:
	choices.clear()
	choices.add_item("新建配方")
	var entries: Dictionary = MetaProgress.production_recipes.get(bucket, {})
	for key in entries:
		choices.add_item(key)
		if key == selected_name: choices.select(choices.item_count - 1)
	_select(choices.selected)

func _on_choice(index: int) -> void:
	_select(index)
	if not is_instance_valid(factory): return
	var previous := MetaProgress.recipe_defaults.duplicate()
	MetaProgress.recipe_defaults[default_key] = title_edit.text
	if previous != MetaProgress.recipe_defaults and not MetaProgress.save():
		MetaProgress.recipe_defaults = previous
		message.text = "未能保存下次默认选用的配方。"
	_remember_here(title_edit.text)

func _remember_here(key: String) -> void:
	if is_instance_valid(factory):
		var selections: Dictionary = factory.special.get("recipe_selection", {})
		selections[category] = key
		factory.special["recipe_selection"] = selections

func _select(index: int) -> void:
	var key := choices.get_item_text(index) if index > 0 else ""
	title_edit.text = key
	draft = MetaProgress.production_recipes.get(bucket, {}).get(key, []).duplicate()
	message.text = ""
	_update_preview()

func _append(uid: String) -> void:
	draft.append(uid)
	_update_preview()

func _undo() -> void:
	draft.pop_back()
	_update_preview()

func _update_preview() -> void:
	var names := PackedStringArray()
	var start := 0
	while start < draft.size():
		var count := 1
		while start + count < draft.size() and draft[start + count] == draft[start]:
			count += 1
		var label: String = hud._entity_name(draft[start])
		if count > 1:
			label += " x %d" % count
		names.append(label)
		start += count
	preview.text = "按出兵顺序点击下方兵种" if names.is_empty() else "%d 项 · %s" % [draft.size(), " → ".join(names)]
	preview.tooltip_text = preview.text

func _save() -> void:
	var key := title_edit.text.strip_edges()
	if key.is_empty() or draft.is_empty():
		message.text = "请输入名称，至少选择一个兵种。"
		return
	if MetaProgress.production_recipes.get(bucket, {}).has(key) and (choices.selected == 0 or choices.get_item_text(choices.selected) != key):
		message.text = "名称已使用。请选择原配方编辑，或换一个名称。"
		return
	_persist(key, false)

func _remove() -> void:
	if choices.selected > 0: _persist(choices.get_item_text(choices.selected), true)

func _persist(key: String, remove: bool) -> void:
	var previous := MetaProgress.production_recipes.duplicate(true)
	var entries: Dictionary = MetaProgress.production_recipes.get(bucket, {})
	if remove: entries.erase(key)
	else: entries[key] = draft.duplicate()
	MetaProgress.production_recipes[bucket] = entries
	var previous_defaults := MetaProgress.recipe_defaults.duplicate()
	var selected_name := "" if remove else key
	if is_instance_valid(factory): MetaProgress.recipe_defaults[default_key] = selected_name
	if not MetaProgress.save():
		MetaProgress.recipe_defaults = previous_defaults
		MetaProgress.production_recipes = previous
		message.text = "保存失败，请重试。"
		return
	_remember_here(selected_name)
	_refresh(selected_name)
	message.text = "已删除" if remove else "已保存"

func _order() -> void:
	if not is_instance_valid(factory) or hud.prod_tab != category or hud._factories.current() != factory:
		message.text = "请先选择本页的生产工厂。"
		return
	var reason: String = factory.order_recipe(draft)
	message.text = reason if not reason.is_empty() else "已追加 %d 项订单" % draft.size()
