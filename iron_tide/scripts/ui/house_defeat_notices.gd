extends PanelContainer
## Independent of the collapsible log. Only defeat events add rows; no actor scans.
const NOTICE_MS := 10000
var notices: Dictionary = {}
var rows: VBoxContainer

func setup(world) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.panel_style(Color("#172330ed"), Color("#dfbd75"), 3, 1, 5))
	rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)
	world.computer_defeated.connect(_on_defeat)
	hide()

func _on_defeat(side: String, message: String, color: Color) -> void:
	if notices.has(side): return
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := ColorRect.new()
	chip.color = color
	chip.custom_minimum_size = Vector2(12, 12)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(chip)
	var label := UiKit.make_label(message, 17, Color("#fff0cb"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(label)
	rows.add_child(line)
	notices[side] = {"node":line, "label":label, "color":chip, "until":Time.get_ticks_msec() + NOTICE_MS}
	show()

func refresh(now: int = -1) -> void:
	if notices.is_empty(): return
	if now < 0: now = Time.get_ticks_msec()
	for side in notices.keys():
		if now < int(notices[side].until): continue
		var line: Control = notices[side].node
		rows.remove_child(line)
		line.queue_free()
		notices.erase(side)
	visible = not notices.is_empty()
