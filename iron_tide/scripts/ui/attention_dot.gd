extends Control

static func mark(control:Control,active:bool,reason:String) -> void:
	control.set_meta("attention_reason",reason)
	control.set_meta("attention_active",active)
	var old:=control.get_node_or_null("AttentionDot")
	if old!=null:control.remove_child(old);old.queue_free()
	if not active:return
	var dot=load("res://scripts/ui/attention_dot.gd").new()
	dot.name="AttentionDot";dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	control.add_child(dot)
	dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left=-12;dot.offset_right=-2;dot.offset_top=2;dot.offset_bottom=12
	control.tooltip_text+=("\n" if not control.tooltip_text.is_empty() else "")+reason

func _draw() -> void:
	draw_circle(Vector2(5,5),5,Color("#591d27"))
	draw_circle(Vector2(5,5),4,Color("#ff4059"))
