class_name Ra3MirageFx
extends Node2D
## Original EXCloakingField geometry + source cloud/distortion textures.
const ROOT := "res://assets/ra3/mirage/presentation/"
const NATIVE := "res://assets/ra3/mirage/uprising/"
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NATIVE+"field.json"))
static var meshes: Dictionary = {}
var field_time := 0.0
var actor
var viewport: SubViewport
var field: MeshInstance3D
var disguise: MeshInstance3D
var field_material: ShaderMaterial
var disguise_material: ShaderMaterial
var strength := 0.0
var age := 0.0
var disguise_age := 2.0
var disguise_lifetime := 1.0
var was_disguised := false
var disguise_size := Vector3.ONE
var disguise_rate := Vector2.ZERO
var disguise_damping := Vector2.ONE
var disguise_frame_accum := 0.0
var _accum := 0.0

static func attach(unit) -> Ra3MirageFx:
	if unit.unit_id != Ra3Mirage.ID or DisplayServer.get_name() == "headless": return null
	var fx := Ra3MirageFx.new(); fx.actor = unit; fx.name = "Ra3MirageFx"
	unit.add_child(fx)
	fx._build()
	return fx

static func mesh_for(id: String) -> ArrayMesh:
	if meshes.has(id): return meshes[id]
	var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((NATIVE if FileAccess.file_exists(NATIVE+id+".json") else ROOT)+id+".json"))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
	for i in range(0,row.vertices.size(),3):
		vertices.append(Vector3(row.vertices[i],row.vertices[i+1],row.vertices[i+2]))
		normals.append(Vector3(row.normals[i],row.normals[i+1],row.normals[i+2]))
	for i in range(0,row.uv.size(),2): uv.append(Vector2(row.uv[i],row.uv[i+1]))
	var indices := PackedInt32Array()
	for i in range(0,row.indices.size(),3):indices.append_array([int(row.indices[i]),int(row.indices[i+2]),int(row.indices[i+1])])
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	if row.has("colors"):
		var colors:=PackedColorArray()
		for i in range(0,row.colors.size(),4): colors.append(Color(row.colors[i],row.colors[i+1],row.colors[i+2],row.colors[i+3]))
		arrays[Mesh.ARRAY_COLOR]=colors
	if row.has("uv2"):
		var uv2:=PackedVector2Array()
		for i in range(0,row.uv2.size(),2): uv2.append(Vector2(row.uv2[i],row.uv2[i+1]))
		arrays[Mesh.ARRAY_TEX_UV2]=uv2
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[id] = mesh
	return mesh

func _material(texture: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/ra3_cloaking.gdshader")
	mat.set_shader_parameter("cloud",load(ROOT+texture+".png"))
	mat.set_shader_parameter("distortion",load(ROOT+"FXFracTileNRM.png"))
	return mat

func _build() -> void:
	z_as_relative = false; z_index = DepthLayers.FX - 1
	var composite:=ShaderMaterial.new()
	composite.shader=load("res://shaders/ra3_additive_viewport.gdshader")
	material=composite
	viewport = SubViewport.new(); viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true; viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X; viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	field = MeshInstance3D.new(); field.mesh = mesh_for("excloakingfield")
	field_material = _material("FXCloud03")
	field_material.shader = load("res://shaders/ra3_field_lightning.gdshader")
	var constants: Dictionary=source.material.constants
	var offset: Array=constants.DiffuseCoordOffset
	field_material.set_shader_parameter("coord_offset",Vector4(offset[0],offset[1],offset[2],offset[3]))
	field_material.set_shader_parameter("edge_fade",float(constants.EdgeFadeOut[0]))
	field_material.set_shader_parameter("hdr_multiplier",float(constants.EmissiveHDRMultipler[0]))
	field_material.set_shader_parameter("displace_amp",float(constants.DisplaceAmp[0]))
	field_material.set_shader_parameter("displace_speed",float(constants.DisplaceSpeed[0]))
	field_material.set_shader_parameter("displace_scalar",float(constants.DisplaceScalar[0]))
	field_material.set_shader_parameter("divergence",deg_to_rad(float(constants.DisplaceDivergenceAngle[0])))
	field.material_override = field_material
	viewport.add_child(field)
	disguise = MeshInstance3D.new(); disguise.mesh = mesh_for("fxmiragedisguise")
	disguise_material = ShaderMaterial.new()
	disguise_material.shader=load("res://shaders/ra3_disguise.gdshader")
	disguise_material.set_shader_parameter("diffuse_map",load(NATIVE+"FXBuzzerRef.png"))
	disguise_material.set_shader_parameter("house_color",actor._col)
	disguise.material_override = disguise_material; viewport.add_child(disguise)
	disguise.visible=false
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=440
	camera.position=Vector3(0,250,433.0127); camera.rotation_degrees.x=-30
	viewport.add_child(camera)
	was_disguised = Ra3Mirage.disguised(actor)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor._dead: visible=false; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; return
	age += delta; disguise_age += delta
	var disguised := Ra3Mirage.disguised(actor)
	if disguised and not was_disguised:
		disguise_age=0.0
		var frames: Array = Ra3WeaponFx.sdk.particles.Primage_Disguise.lifetime_frames
		disguise_lifetime=randf_range(float(frames[0]),float(frames[1]))/float(Ra3WeaponFx.sdk.adapter.particle_frames_per_second)
		disguise_size=Vector3(randf_range(0.75,1.0),1.0,randf_range(0.75,1.0))
		disguise_rate=Vector2(randf_range(0.1,0.2),randf_range(0.1,0.2))
		disguise_damping=Vector2(randf_range(0.9,0.95),randf_range(0.9,0.95))
		disguise_frame_accum=0.0
	elif not disguised:
		# DisguiseFX is an entry effect, not a shell restarted by moving/firing.
		disguise_age=disguise_lifetime
	was_disguised=disguised
	if disguise_age<disguise_lifetime:
		disguise_frame_accum+=delta*30.0
		while disguise_frame_accum>=1.0:
			disguise_size.x+=disguise_rate.x; disguise_size.z+=disguise_rate.y
			disguise_rate*=disguise_damping; disguise_frame_accum-=1.0
	advance_field(delta,Ra3Mirage.field_active(actor))
	var world = actor._battle_world()
	visible = actor.embarked_in == null and world != null and world.actor_visible_to("ally",actor) and (strength>0.001 or disguise_age<disguise_lifetime)
	if not is_visible_in_tree(): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; return
	_accum += delta
	if _accum < 1.0/30.0: return
	_accum = 0.0
	field.visible = strength>0.001
	field.scale = Vector3.ONE # Native channel changes visibility, not geometry scale.
	field_material.set_shader_parameter("strength",strength)
	field_material.set_shader_parameter("phase",age)
	disguise.visible = disguise_age<disguise_lifetime
	disguise.scale = disguise_size # Source SizeRate.Z=0: never inflate vertically.
	disguise_material.set_shader_parameter("strength",disguise_opacity())
	disguise_material.set_shader_parameter("phase",age)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	queue_redraw()

func _draw() -> void:
	if viewport == null: return
	Iso.begin(self)
	draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-220.0*Ra3Mirage.WORLD_SCALE,Vector2.ONE*440.0*Ra3Mirage.WORLD_SCALE),false)

func disguise_opacity() -> float:
	# SDK alpha keys: 1 at 50% lifetime, 0 at 100%.
	return clampf((1.0-disguise_age/disguise_lifetime)*2.0,0.0,1.0)

func advance_field(delta: float, active: bool) -> void:
	var duration := float(source.frames-1)/float(source.fps)
	field_time=clampf(field_time+(delta if active else -delta),0.0,duration)
	var frame := field_time*float(source.fps)
	var index := mini(int(frame),int(source.frames)-1)
	strength=clampf(lerpf(float(source.visibility[index]),float(source.visibility[mini(index+1,int(source.frames)-1)]),frame-index),0.0,1.0)
