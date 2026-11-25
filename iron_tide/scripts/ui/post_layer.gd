extends CanvasLayer
class_name PostLayer
## 战场后期层：位于世界（layer 0）之上、HUD（layer 2）之下，只给战场加光照/调色。

var grade: ShaderMaterial
var exposure_ev := 0.0
var samples := {}

# Meter the visible fraction of a bright particle. Track simulation time so pause
# freezes adaptation and a camera pan immediately drops an offscreen source.
static func bright_flash(world, emitter: Node2D, point: Vector2, diameter: float, intensity: float) -> void:
	if not is_instance_valid(world) or world._post_layer == null or not emitter.is_visible_in_tree(): return
	if intensity <= 0.0 or diameter <= 0.0 or not world.position_visible_to("ally", point): return
	world._post_layer.samples[emitter.get_instance_id()] = {"point":point, "diameter":diameter, "power":intensity, "left":0.06}

func clear_exposure() -> void:
	samples.clear()
	exposure_ev = 0.0
	grade.set_shader_parameter("exposure_ev", 0.0)

func _process(delta: float) -> void:
	if (samples.is_empty() and exposure_ev == 0.0) or get_parent().paused: return
	var world = get_parent()
	var transform: Transform2D = world.get_global_transform_with_canvas()
	var screen: Rect2 = world.get_viewport_rect()
	var power := 0.0
	for id in samples.keys():
		var s: Dictionary = samples[id]
		var side := float(s.diameter) * transform.x.length()
		var area := Rect2(transform * Vector2(s.point) - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		if world.position_visible_to("ally", s.point):
			power += screen.intersection(area).get_area() / maxf(1.0, screen.get_area()) * float(s.power)
		s.left -= delta
		if s.left <= 0.0: samples.erase(id)
	var target := minf(0.85, log(1.0 + 4.0 * power) / log(2.0))
	exposure_ev = lerpf(exposure_ev, target, 1.0 - exp(-delta / (0.045 if target > exposure_ev else 0.32)))
	if target == 0.0 and exposure_ev < 0.001: exposure_ev = 0.0
	grade.set_shader_parameter("exposure_ev", exposure_ev)

func _ready() -> void:
	layer = 1
	var cr := ColorRect.new()
	cr.name = "GradeRect"
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color(1, 1, 1, 1)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.anchor_right = 1.0
	cr.anchor_bottom = 1.0
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	grade = ShaderMaterial.new()
	var sh: Shader = load("res://shaders/post_grade.gdshader")
	if sh != null:
		grade.shader = sh
	cr.material = grade
	add_child(cr)
