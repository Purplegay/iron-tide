extends Node2D
## Retail projectile meshes; visuals are disposable, simulation remains in payload.
const ROOT := "res://assets/ra3/expansion/fx/"
static var cache: Dictionary = {}
var shot
var mode := ""
var viewport: SubViewport
var mesh: MeshInstance3D
var fx_material: ShaderMaterial
var size := 600.0
var budget := 0.0

func setup(projectile) -> void:
	shot=projectile;mode=str(shot.splinters.ra3_expansion)
	var composite:=ShaderMaterial.new();composite.shader=preload("res://shaders/ra3_fx_composite.gdshader");material=composite
	if mode=="shell" and shot.splinters.get("heroic",false):mode="shell_vet"
	size=600.0 if mode=="neutron" else 48.0
	if not cache.has(mode):
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+mode+".json"))
		cache[mode]={"source":source,"mesh":preload("res://scripts/units/ra3_gunship_material.gd").make_mesh(source)}
	var source: Dictionary=cache[mode].source
	viewport=SubViewport.new();viewport.size=Vector2i(384,384) if mode=="neutron" else Vector2i(96,96)
	viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	mesh=MeshInstance3D.new();mesh.mesh=cache[mode].mesh;viewport.add_child(mesh)
	fx_material=ShaderMaterial.new();fx_material.shader=load("res://shaders/ra3_expansion_fx.gdshader")
	fx_material.set_shader_parameter("shield",mode=="neutron")
	for pair in [["Texture_0","diffuse_map"],["Texture_1","noise_map"],["Texture_2","mask_map"],["TextureFadeOut","fade_map"]]:
		if source.textures.has(pair[0]):fx_material.set_shader_parameter(pair[1],load(ROOT+str(source.textures[pair[0]])))
	var constants: Dictionary=source.material.constants
	for pair in [["EmissiveHDRMultipler","emissive"],["DisplaceScalar","noise_scale"],["DisplaceAmp","amplitude"],["DisplaceDivergenceAngle","divergence"],["DisplaceSpeed","speed"]]:
		fx_material.set_shader_parameter(pair[1],float(constants[pair[0]][0]))
	var c: Array=constants.DiffuseCoordOffset
	fx_material.set_shader_parameter("coord",Vector4(c[0],c[1],c[2],c[3]))
	var color_: Array=constants.get("ColorDiffuseKey1",constants.get("ColorDiffuse",[1,1,1]))
	fx_material.set_shader_parameter("tint",Vector3(color_[0],color_[1],color_[2]))
	if mode.begins_with("shell"):
		fx_material=preload("res://scripts/units/ra3_gunship_material.gd").create(source.material,source.textures,ROOT)
	mesh.material_override=fx_material
	var camera:=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=size/1.5;camera.position=Vector3(0,200,346.41016);camera.rotation_degrees.x=-30
	_process(0.1)

func _process(delta: float) -> void:
	if not is_instance_valid(shot):return
	budget+=delta
	if budget<1.0/30.0:return
	budget=0.0
	var age:=float(shot.splinters.age)
	fx_material.set_shader_parameter("age",age)
	if mode.begins_with("shell"):
		fx_material.set_shader_parameter("source_origin",Vector3(shot.position.x/1.5,shot.position.y/1.5,0))
		var direction: Vector2=shot.splinters.start.direction_to(shot.target_point)
		mesh.rotation.y=Iso.eff_angle()-float(shot.splinters.get("shell_heading",direction.angle()))
		mesh.rotation.z=float(shot.splinters.get("shell_pitch",0.0))
	if mode=="neutron":
		var radius:=clampf(25.0+maxf(0.0,age-1.35)*125.0,25.0,180.0)
		mesh.scale=Vector3.ONE*radius/13.612405
		fx_material.set_shader_parameter("opacity",clampf((6.0-age)/0.4,0.0,1.0))
	preload("res://scripts/units/ra3_fx_resolution.gd").update(self, viewport, size, 384 if mode == "neutron" else 96)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if shot.visible else SubViewport.UPDATE_DISABLED
	queue_redraw()

func _draw() -> void:
	if viewport==null:return
	Iso.begin(self)
	draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-size*0.5,Vector2.ONE*size),false)
