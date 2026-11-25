extends Control
## Red Alert / Uprising challenge-style launch sting.
signal finished
var pulse := 0.0
var scan := 0.0
var label_node: Label
var tween: Tween

static func play(host: Node, done: Callable) -> void:
	var overlay := preload("res://scripts/ui/red_alert_overlay.gd").new()
	host.add_child(overlay)
	overlay.finished.connect(done)
	overlay._start()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	label_node = Label.new()
	label_node.text = "RED ALERT"
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.add_theme_font_size_override("font_size", 52)
	label_node.add_theme_color_override("font_color", Color("#ff3b30"))
	label_node.add_theme_color_override("font_outline_color", Color("#240509"))
	label_node.add_theme_constant_override("outline_size", 12)
	label_node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label_node.custom_minimum_size = Vector2(620, 90)
	label_node.modulate.a = 0.0
	add_child(label_node)
	queue_redraw()

func _start() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(bg, 0)
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_parallel(true)
	tween.tween_property(label_node, "modulate:a", 1.0, 0.22)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.chain().tween_interval(0.75)
	tween.chain().tween_property(label_node, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(func(): finished.emit(); queue_free())

func _process(delta: float) -> void:
	pulse += delta * 7.0
	scan = fposmod(scan + delta * 0.8, 1.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var radius := 90.0 + sin(pulse) * 12.0
	for i in 3:
		var r := radius + i * 34.0
		draw_arc(c, r, 0.0, TAU, 96, Color(1.0, 0.08, 0.05, 0.22 - i * 0.05), 2.0)
	var y := scan * size.y
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(1.0, 0.12, 0.08, 0.65), 2.0)
	var inset := 70.0
	var col := Color(1.0, 0.18, 0.12, 0.8)
	draw_line(Vector2(inset, inset), Vector2(inset + 80, inset), col, 3.0)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + 80), col, 3.0)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset - 80, size.y - inset), col, 3.0)
	draw_line(Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - 80), col, 3.0)
