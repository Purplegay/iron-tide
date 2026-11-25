extends Node3D
## SDK afternoon sun + accent lights; Godot response is an explicit adaptation.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra3/lighting.json"))
var environment: WorldEnvironment
var lights: Array[DirectionalLight3D] = []

static func install(world: Node3D) -> Node3D:
	var rig = load("res://scripts/units/ra3_lighting.gd").new()
	world.add_child(rig)
	rig.build()
	return rig

static func sun_direction() -> Vector3:
	var v: Array = source.lights[0].LightPos
	return Basis(Vector3.UP, Iso.eff_angle()) * Vector3(v[0], v[2], -v[1]).normalized()

func build() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var rgb := Vector3.ZERO
	for row: Dictionary in source.lights:
		rgb += Vector3(row.Ambient[0], row.Ambient[1], row.Ambient[2])
	environment.environment.ambient_light_color = Color(rgb.x, rgb.y, rgb.z).linear_to_srgb()
	environment.environment.ambient_light_energy = 1.0
	add_child(environment)
	for row: Dictionary in source.lights:
		var light := DirectionalLight3D.new()
		var ray := Vector3(row.LightPos[0], row.LightPos[2], -row.LightPos[1]).normalized()
		light.basis = Basis.looking_at(ray, Vector3.UP)
		light.light_color = Color(row.Diffuse[0], row.Diffuse[1], row.Diffuse[2]).linear_to_srgb()
		light.light_energy = 1.0
		# Body renderers enable shadows on the sun while visible. FX and disguise-only rigs stay unshadowed.
		light.shadow_enabled = false
		add_child(light); lights.append(light)
	rotation.y = Iso.eff_angle()

func _process(_delta: float) -> void:
	rotation.y = Iso.eff_angle()
