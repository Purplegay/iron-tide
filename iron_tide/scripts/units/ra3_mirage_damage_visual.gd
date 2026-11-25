extends Node2D
## SDK ModuleTag_Draw / Draw_FX. Native 30-frame particle units; 2D projection.
const ROOT := "res://assets/ra3/mirage/damage/"
const Particle = preload("res://scripts/units/ra3_gunship_impact.gd")
const MAX_PARTICLES := 96
const SMOKE_OPACITY := 0.25
const SMOKE_SIZE_SCALE := 0.24
const SMOKE_INTERVAL_SCALE := 4.0
static var damaged_texture: Texture2D
var model
var normal_texture: Texture2D
var skin_state := -1
var rows: Array[Dictionary] = []
var clocks: Dictionary = {}

static func smoke_birth_fade(age: float) -> float:
	return smoothstep(0.0, 3.0, age)

func setup(renderer) -> void:
	model = renderer
	normal_texture = model._body_material.get_shader_parameter("diffuse_map")
	if damaged_texture == null:
		var texture: Texture2D = load(ROOT + "AUAntiVehicleVehicleTech3_D.png")
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		image.generate_mipmaps()
		damaged_texture = ImageTexture.create_from_image(image)
	sync_skin()

func sync_skin() -> bool:
	var state := Ra3Mirage.damage_state(model.actor)
	if skin_state == state: return false
	model._body_material.set_shader_parameter("diffuse_map", damaged_texture if state == 2 else normal_texture)
	skin_state = state
	return true

func clear_particles() -> void:
	for row in rows: row.sprite.queue_free()
	rows.clear()
	clocks.clear()

func active_systems() -> Array[String]:
	# The explicit DISGUISED damage states keep the skin but omit all smoke/fire.
	if Ra3Mirage.disguised(model.actor): return []
	match Ra3Mirage.damage_state(model.actor):
		1: return ["VehicleDamageSmoke"]
		2: return ["VehicleDamageSmoke", "VehicleDamageFire", "VehicleDamageFire02"]
	return []

func _process(delta: float) -> void:
	if model == null or not is_instance_valid(model.actor): return
	if sync_skin():
		model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		model.actor.queue_redraw()
	if model._suspended or model.actor._dead or model.actor.embarked_in != null or not model.actor.is_visible_in_tree():
		clear_particles()
		return
	if get_tree().paused or AlliedAbilities.frozen(model.actor): return
	rotation = Iso.eff_angle()
	scale = Iso.up()
	modulate.a = Ra3Mirage.CloakVisual.opacity(model.actor)
	var active := active_systems()
	# FollowBone effects disappear when their model condition no longer applies.
	for row in rows.duplicate():
		if row.system not in active:
			row.sprite.queue_free()
			rows.erase(row)
	for key in clocks.keys():
		if key not in active: clocks.erase(key)
	for system in active:
		var data: Dictionary = Ra3Mirage.model_conditions.particles[system]
		var left := maxf(float(clocks.get(system, 0.0)) - delta * 30.0, -35.0)
		while left <= 0.0:
			for i in maxi(1, roundi(Particle.range_value(Particle.child(data, "BurstCount"), 1))):
				if rows.size() < MAX_PARTICLES: emit_particle(system, data)
			var interval := maxf(1.0, Particle.range_value(Particle.child(data, "BurstDelay"), 1))
			if system == "VehicleDamageSmoke": interval *= SMOKE_INTERVAL_SCALE
			left += interval
		clocks[system] = left
	var p: Array = Ra3Mirage.model_conditions.damage_emitter.position
	var emitter: Vector3 = model.hull.transform * Vector3(p[0], p[1], p[2])
	for row in rows.duplicate():
		row.age += delta * 30.0
		if row.age >= row.life:
			row.sprite.queue_free()
			rows.erase(row)
			continue
		row.sprite.position = model.draw_rect.position + model.project(emitter + row.offset + row.velocity * row.age)
		var diameter: float = maxf(0.01, row.size + row.rate * Particle.integral(row.age, row.damping))
		if row.system == "VehicleDamageSmoke": diameter *= SMOKE_SIZE_SCALE
		row.sprite.scale = Vector2.ONE * diameter * Ra3Mirage.WORLD_SCALE / row.sprite.texture.get_width()
		var color := Particle.color_at(row.data, row.age / row.life * 100.0)
		color.r *= row.color_scale; color.g *= row.color_scale; color.b *= row.color_scale
		color.a = Particle.sampled_alpha(row.alpha, row.age / row.life * 100.0) * smoke_birth_fade(row.age)
		if row.system == "VehicleDamageSmoke": color.a *= SMOKE_OPACITY
		row.sprite.modulate = color
		row.sprite.rotation += row.angular_rate * delta * 30.0
		row.sprite.material.set_shader_parameter("frame", row.age * row.frame_speed)

func emit_particle(system: String, data: Dictionary) -> void:
	var update := Particle.child(data, "Update/Default")
	var gpu: Dictionary = Particle.child(data, "Draw/Gpu").get("attrs", {})
	var offset: Dictionary = Particle.child(data, "Volume/Cylinder/Offset").get("attrs", {})
	var drift: Dictionary = Particle.child(data, "Physics/Default/DriftVelocity").get("attrs", {})
	var sprite := Sprite2D.new()
	sprite.texture = load(ROOT + str(data.attrs.ParticleTexture) + ".png")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ra3_damage_particle.gdshader") if system == "VehicleDamageSmoke" else preload("res://shaders/ra3_mirage_damage_additive.gdshader")
	mat.set_shader_parameter("columns", float(gpu.get("FramesPerRow", 1)))
	mat.set_shader_parameter("frames", float(gpu.get("TotalFrames", 1)))
	sprite.material = mat
	sprite.rotation = Particle.range_value(Particle.child(update, "AngleZ"))
	add_child(sprite)
	var velocity := Particle.xyz(Particle.child(data, "Velocity/Ortho/Position"))
	if system == "VehicleDamageFire":
		var angle := randf() * TAU
		velocity = Vector3(cos(angle), 0, sin(angle)) * Particle.range_value(Particle.child(data, "Velocity/Outward/Speed"))
	velocity += Vector3(float(drift.get("x", 0)), float(drift.get("z", 0)), -float(drift.get("y", 0)))
	rows.append({"system": system, "data": data, "sprite": sprite, "age": 0.0,
		"life": Particle.range_value(Particle.child(data, "Lifetime")),
		"size": Particle.range_value(Particle.child(data, "Size")),
		"rate": Particle.range_value(Particle.child(update, "SizeRate")),
		"damping": Particle.range_value(Particle.child(update, "SizeRateDamping"), 1),
		"alpha": Particle.sample_alpha_keys(data), "velocity": velocity,
		"angular_rate": Particle.range_value(Particle.child(update, "AngularRateZ")),
		"offset": Vector3(float(offset.get("x", 0)), float(offset.get("z", 0)), -float(offset.get("y", 0))),
		"color_scale": Particle.range_value(Particle.child(data, "Colors/ColorScale"), 1),
		"frame_speed": float(gpu.get("SpeedMultiplier", 1))})
