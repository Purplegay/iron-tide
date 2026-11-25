extends Button
## Sidebar cards use fixed details; other callers retain the bounded tooltip.

var docked_details := false
var detail_highlight := false:
	set(value):
		if detail_highlight != value:
			detail_highlight = value
			queue_redraw()

func _get_tooltip(_at_position: Vector2) -> String:
	return "" if docked_details else tooltip_text

var guide_highlight := false:
	set(value):
		if guide_highlight != value:
			guide_highlight = value
			queue_redraw()

func _draw() -> void:
	if detail_highlight:
		var color := Color(1.0, 0.65, 0.35) if disabled else Color(0.35, 0.9, 1.0)
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), color, false, 1.0)
	if guide_highlight:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color(0.35, 0.9, 1.0), false, 2.0)

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.10, 0.98)
	style.border_color = Color(0.25, 0.65, 0.80, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
		style.set_content_margin(side, 10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.custom_minimum_size.x = 400
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.96))
	label.text = for_text
	panel.add_child(label)
	return panel
