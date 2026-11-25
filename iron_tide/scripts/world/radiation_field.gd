extends RefCounted
## Presentation only. Each live site owns one ground quad, including after loading a battle.
const FIELD := preload("res://shaders/radiation_field.gdshader")

# A site loses a discrete number of levels each RadLevelDelay, including restored sites.
static func level_at(site:Dictionary, seconds_per_level:float, decay_seconds:float, after:=0.0) -> float:
	var age:=float(site.level)*seconds_per_level-float(site.left)+after
	var steps:=floorf((maxf(0.0,age)+0.000001)/decay_seconds)
	return maxf(0.0,float(site.level)-steps*ceilf(decay_seconds/seconds_per_level-0.000001))

static func sync(world, duration_factor: float, max_level: float, decay_seconds:float) -> void:
	var sites: Array = world.allied_state.get("rad_sites", [])
	var layer = world.get_node_or_null("RadiationFields")
	if layer == null:
		if sites.is_empty(): return
		layer = Node2D.new()
		layer.name = "RadiationFields"
		layer.z_index = DepthLayers.DECAL + 1
		world.add_child(layer)
	while layer.get_child_count() > sites.size():
		var old = layer.get_child(-1)
		layer.remove_child(old)
		old.queue_free()
	for i in sites.size():
		var site: Dictionary = sites[i]
		var field: ColorRect
		if i < layer.get_child_count():
			field = layer.get_child(i)
		else:
			field = ColorRect.new()
			field.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.material = ShaderMaterial.new()
			field.material.shader = FIELD
			layer.add_child(field)
		var radius: float = site.radius
		field.position = site.point - Vector2.ONE * radius
		field.size = Vector2.ONE * radius * 2.0
		field.visible = world.position_visible_to("ally", site.point)
		var lifetime: float = site.level * duration_factor
		field.material.set_shader_parameter("age", maxf(0.0, lifetime - site.left))
		field.material.set_shader_parameter("strength", sqrt(clampf(level_at(site,duration_factor,decay_seconds) / max_level, 0.0, 1.0)))
		field.material.set_shader_parameter("origin", site.point)
