extends Node3D
## Native rigid subobjects and EXFutureTankCharge's original visibility animation.
const ROOT="res://assets/ra3/expansion/future/fx/"
const MaterialFactory=preload("res://scripts/units/ra3_gunship_material.gd")
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"presentation.json"))
static var meshes: Dictionary={}
static var culled_shield: Shader
var definition: Dictionary
var parts: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var frame:=0.0

static func make_material(native: Dictionary, textures: Dictionary) -> ShaderMaterial:
	if str(native.shader).to_lower()!="fxshield.fx":return MaterialFactory.create(native,textures,ROOT)
	var result:=ShaderMaterial.new();result.shader=preload("res://shaders/ra3_future_shield.gdshader")
	var c: Dictionary=native.constants
	if c.get("CullingEnable",false):
		if culled_shield==null:
			culled_shield=Shader.new();culled_shield.code=result.shader.code.replace("cull_disabled","cull_back")
		result.shader=culled_shield
	for pair in [["Texture_0","diffuse_map"],["Texture_1","noise_map"],["TextureFadeOut","fade_map"]]:
		if textures.has(pair[0]):result.set_shader_parameter(pair[1],load(ROOT+str(textures[pair[0]])))
	for pair in [["EmissiveHDRMultipler","emissive"],["DisplaceScalar","noise_scale"],["DisplaceAmp","amplitude"],["DisplaceDivergenceAngle","divergence"],["DisplaceSpeed","speed"],["EdgeFadeOut","edge_fade"]]:
		result.set_shader_parameter(pair[1],float(c[pair[0]][0]))
	result.set_shader_parameter("intersection",float(c.get("IntersectionMultiplier",[0.0])[0]))
	var v: Array=c.ColorDiffuseKey1;result.set_shader_parameter("tint",Vector3(v[0],v[1],v[2]))
	v=c.DiffuseCoordOffset;result.set_shader_parameter("coord",Vector4(v[0],v[1],v[2],v[3]))
	for pair in [["MultiTextureEnable","multi"],["TextureFadeOutEnable","lut"],["OpacityOverrideEnable","override_key"]]:result.set_shader_parameter(pair[1],c[pair[0]])
	return result

func build(id: String) -> void:
	definition=data.models[id]
	var globals: Array[Transform3D]=[]
	for b: Dictionary in definition.bones:
		var pose:=Transform3D(Basis(Ra3BoneAnimation.quaternion(b.rotation)),Ra3BoneAnimation.vector(b.position))
		globals.append(globals[int(b.parent)]*pose if int(b.parent)>=0 else pose)
	for part: Dictionary in definition.parts:
		if not meshes.has(part.name):meshes[part.name]=MaterialFactory.make_mesh(part)
		var node:=MeshInstance3D.new();node.mesh=meshes[part.name];node.transform=globals[int(part.bone)];add_child(node)
		var mat:=make_material(part.material,part.textures);node.material_override=mat
		parts.append(node);materials.append(mat)
	sample(0.0)

func sample(seconds: float, absolute_time: float=0.0, backwards: bool=false, opacity: float=1.0) -> void:
	var clip: Dictionary=definition.clip
	var visibility: Dictionary={}
	if not clip.is_empty():
		var duration:=absolute_time if absolute_time>0 else (float(clip.frames)-1.0)/float(clip.fps)
		frame=clampf(seconds/maxf(0.001,duration),0,1)*(float(clip.frames)-1)
		if backwards:frame=float(clip.frames)-1-frame
		for channel: Dictionary in clip.channels:
			var cursor:=int(frame);var next:=mini(cursor+1,channel.values.size()-1)
			visibility[int(channel.bone)]=clampf(lerpf(float(channel.values[cursor]),float(channel.values[next]),frame-cursor),0,1)
	for i in parts.size():
		var bone:=int(definition.parts[i].bone);var alpha:=1.0
		while bone>=0:
			alpha*=float(visibility.get(bone,1.0));bone=int(definition.bones[bone].parent)
		parts[i].visible=alpha>0.0001
		materials[i].set_shader_parameter("age",seconds);materials[i].set_shader_parameter("opacity",opacity*alpha)
