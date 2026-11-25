extends Node2D
var world
func _ready() -> void:
	if preload("res://scripts/world/native_maps.gd").has(world.map_layout()):
		hide()
		set_process(false)
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	# Imported maps already contain the exact original bridge deck artwork.
	if preload("res://scripts/world/native_maps.gd").has(world.map_layout()): return
	var spans: Dictionary = {}
	for span in world.allied_state.get("repaired_bridges", []): spans[span] = true
	for b in world.buildings:
		if not is_instance_valid(b) or not b.special.has("bridge_span"): continue
		var span: Rect2 = b.special.bridge_span
		spans[span] = bool(spans.get(span, false)) or bool(b.special.get("bridge_repaired", false))
	for span in spans:
		if not world.position_explored_by("ally", span.get_center()): continue
		var repaired: bool = spans[span]
		var pieces: Array = [span] if repaired else [Rect2(span.position, Vector2(35, span.size.y)), Rect2(Vector2(span.end.x - 35, span.position.y), Vector2(35, span.size.y))]
		if repaired:
			pieces = []
			for section: Rect2 in preload("res://scripts/world/bridge_sections.gd").split(span):
				if preload("res://scripts/world/bridge_damage.gd").health(world,section) > 0.0: pieces.append(section)
		for piece in pieces:
			draw_rect(piece, Color(0.38, 0.36, 0.30))
			for x in range(int(piece.position.x), int(piece.end.x), 14):
				draw_line(Vector2(x, piece.position.y), Vector2(x, piece.end.y), Color(0.16, 0.15, 0.13), 2)
			for edge in [piece.position.y + 4, piece.end.y - 4]:
				draw_line(Vector2(piece.position.x, edge), Vector2(piece.end.x, edge), Color(0.62, 0.59, 0.46), 4)
				for x in range(ceili(piece.position.x), floori(piece.end.x), 40):
					draw_rect(Rect2(x, edge - 3, 5, 6), Color(0.22, 0.23, 0.21))
