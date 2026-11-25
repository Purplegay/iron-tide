extends MultiMeshInstance2D
## A single instanced draw per grinder impact. Recycle the slots after the last
## spark in a cohort dies; the shader reconstructs its path in SAGE frames.
const P = preload("res://scripts/units/ra3_gunship_impact.gd")
const SHADER = preload("res://shaders/ra3_apocalypse_grind.gdshader")
static var shared_mesh: MultiMesh
var world: Battle
var age := 0.0
var end_frame := 0.0

func setup(battle: Battle, point: Vector2, heading: float, data: Dictionary, texture_: Texture2D) -> void:
	world = battle
	position = point
	texture = texture_
	var duration := int(data.attrs.SystemLifetime)
	var life := P.range_value(P.child(data, "Lifetime"))
	var count := int(P.range_value(P.child(data, "BurstCount")))
	if shared_mesh == null:
		shared_mesh = MultiMesh.new()
		shared_mesh.transform_format = MultiMesh.TRANSFORM_2D
		shared_mesh.mesh = QuadMesh.new()
		shared_mesh.instance_count = count * ceili(life)
		for i in shared_mesh.instance_count:
			shared_mesh.set_instance_transform_2d(i, Transform2D.IDENTITY)
		# Vertex motion happens in the shader, outside the unit quad.
		shared_mesh.custom_aabb = AABB(Vector3(-384,-384,-1), Vector3(768,768,2))
	multimesh = shared_mesh
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("duration", float(duration))
	mat.set_shader_parameter("life", life)
	mat.set_shader_parameter("burst_count", count)
	mat.set_shader_parameter("trail_life", float(P.child(data,"Draw/Trail").attrs.TrailLife))
	mat.set_shader_parameter("start_color", P.color_at(data,0))
	mat.set_shader_parameter("end_color", P.color_at(data,100))
	mat.set_shader_parameter("heading", heading)
	mat.set_shader_parameter("variation", randf()*1000)
	material = mat
	end_frame = duration - 1 + life
	world.effects_root.add_child(self)
	_process(0)

func _process(delta: float) -> void:
	if world.paused: return
	age += delta * 30.0
	if age >= end_frame:
		queue_free()
		return
	rotation = Iso.eff_angle()
	scale = Iso.up()
	visible = world.position_visible_to("ally", position)
	material.set_shader_parameter("age", age)
