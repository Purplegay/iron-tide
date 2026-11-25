extends StaticBody2D
const radius := 21.0
var atlas: Texture2D
var variant := 0
var elapsed := 0.0

func _ready() -> void:
	add_to_group("native_ore_drills")
	collision_layer = 4
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = DepthLayers.GROUND_OBJ + 1
	Events.view_changed.connect(func(_view): queue_redraw())
	set_process(false)

func start() -> void:
	elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if get_parent().get_parent().paused: return
	elapsed += delta
	if elapsed >= 11.0 * 3 / BattleClock.RULE_TICKS_PER_SECOND:
		elapsed = 0
		set_process(false)
	queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	var frame_size := atlas.get_size() / Vector2(11, 3)
	var frame := floori(elapsed * BattleClock.RULE_TICKS_PER_SECOND / 3)
	var scale_factor := 55.0 * sqrt(2.0) / 60.0
	draw_texture_rect_region(atlas, Rect2(Vector2(-frame_size.x/2, -frame_size.y+15)*scale_factor, frame_size*scale_factor), Rect2(frame_size*Vector2(frame,variant),frame_size))
