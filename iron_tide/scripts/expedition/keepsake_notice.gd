extends VBoxContainer

const Gifts = preload("res://scripts/expedition/commander_keepsakes.gd")
const Contacts = preload("res://scripts/expedition/contact_catalog.gd")
const DISPLAY_SECONDS := 6.0
var waiting: Array[String] = []
var displayed: PanelContainer
var elapsed := 0.0
var last_tick := 0

static func gift_panel() -> PanelContainer:
	return UiKit.make_panel(Color("#18232d"), Color("#d6ae54"), 4, 2, 14)

static func heading(id: String, level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var icon := Gifts.icon_view(id)
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)
	var description := VBoxContainer.new()
	row.add_child(description)
	var giver := str(Contacts.PEOPLE[id].name).get_slice(" · ", 0)
	description.add_child(UiKit.make_label(("获得永久信物" if level == 1 else "再会赠礼 · 强化至第 %d 档" % level) + "  ·  " + giver + " 赠", 16, UiKit.COL_GOLD))
	description.add_child(UiKit.make_label(Gifts.ITEMS[id].name, 26))
	description.add_child(UiKit.make_label("携带后可用指令「%s」" % Gifts.ITEMS[id].order, 15, UiKit.COL_ACCENT_2))
	return row

func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_top = 108
	offset_bottom = 108
	grow_horizontal = Control.GROW_DIRECTION_BOTH

func announce(id: String) -> void:
	waiting.append(id)
	if displayed == null: show_next()

func show_next() -> void:
	if waiting.is_empty():
		set_process(false)
		return
	var card := gift_panel()
	card.custom_minimum_size.x = 390
	var id: String = waiting.pop_front()
	card.add_child(heading(id, Gifts.rank(id)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in card.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	displayed = card
	last_tick = Time.get_ticks_msec()
	elapsed = 0.0
	set_process(true)
	Ra2Sfx.play("Bonus")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	# Loading the map or resuming from pause must not spend the reading time.
	elapsed += minf((now - last_tick) / 1000.0, 0.2)
	last_tick = now
	displayed.modulate.a = clampf((DISPLAY_SECONDS + 0.3 - elapsed) / 0.3, 0.0, 1.0)
	if elapsed >= DISPLAY_SECONDS + 0.3:
		remove_child(displayed)
		displayed.queue_free()
		displayed = null
		show_next()

static func add_report_rows(parent: Container, run_id: String, stage: int) -> void:
	for id: String in Gifts.ITEMS:
		var history := Gifts.receipts(id)
		for i in history.size():
			var receipt: Dictionary = history[i]
			if receipt.get("run", "") != run_id or int(receipt.get("stage", -1)) != stage:continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(Gifts.icon_view(id))
			var title := "本关新获永久信物 · " if i == 0 else "本关再会 · 强化至第 %d 档 · " % (i+1)
			row.add_child(UiKit.make_label(title + Gifts.ITEMS[id].name, 17, UiKit.COL_GOLD))
			parent.add_child(row)
