extends RefCounted
## Material constants retained verbatim by import_expansion.py.
static var culled_shader: Shader
static func create(native: Dictionary, textures: Dictionary, folder: String) -> ShaderMaterial:
	var result:=ShaderMaterial.new()
	result.shader=preload("res://shaders/ra3_gunship_fx.gdshader")
	var c: Dictionary=native.constants
	if c.get("CullingEnable",false):
		if culled_shader==null:
			culled_shader=Shader.new();culled_shader.code=result.shader.code.replace("cull_disabled","cull_back")
		result.shader=culled_shader
	var shader:=str(native.shader).to_lower()
	var kind:=1 if "protoncollider" in shader else (2 if "defaultw3d" in shader else (3 if "muzzleflash" in shader else 0))
	result.set_shader_parameter("kind",kind)
	for pair in [["Texture_0","diffuse_map"],["Texture_1","noise_map"],["Texture_2","mask_map"]]:
		if textures.has(pair[0]):result.set_shader_parameter(pair[1],load(folder+str(textures[pair[0]])))
	for pair in [["EmissiveHDRMultipler","emissive"],["DisplaceScalar","noise_scale"],["DisplaceAmp","amplitude"],["DisplaceDivergenceAngle","divergence"],["DisplaceSpeed","speed"],["EdgeFadeOut","edge_fade"],["UniqueWorldCoordScalar","world_scale"],["UniqueWorldCoordStrength","world_strength"]]:
		if c.has(pair[0]):result.set_shader_parameter(pair[1],float(c[pair[0]][0]))
	for pair in [["MultiTextureEnable","multi"],["UniqueWorldCoordEnable","unique_world"],["UV2Enable","mask_uv2"]]:
		result.set_shader_parameter(pair[1],bool(c.get(pair[0],false)))
	var tint: Array=c.get("ColorDiffuse",[1,1,1]) if kind<2 else c.get("ColorEmissive",[1,1,1])
	result.set_shader_parameter("tint",Vector3(tint[0],tint[1],tint[2]))
	var coord: Array=c.get("DiffuseCoordOffset",[0,0,1,1])
	if kind==2:
		result.set_shader_parameter("secondary_enabled",int(c.get("NumTextures",2))>1)
		var transform_: Array=c.get("TexCoordTransform_0",[1,1,0,0])
		coord=[transform_[2],transform_[3],transform_[0],transform_[1]]
		var second: Array=c.get("TexCoordTransform_1",[1,1,0,0])
		result.set_shader_parameter("coord2",Vector4(second[0],second[1],second[2],second[3]))
	if kind==3:result.set_shader_parameter("speed",float(c.get("TexCoordTransformAngle_0",[0])[0]))
	result.set_shader_parameter("coord",Vector4(coord[0],coord[1],coord[2],coord[3]))
	return result

static func attributes(arrays: Array, source: Dictionary) -> void:
	if source.has("uv2"):arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array(_uv(source.uv2))
	if source.has("colors") and not source.colors.is_empty():
		var colors:=PackedColorArray()
		for c: Array in source.colors:colors.append(Color(c[0]/255.0,c[1]/255.0,c[2]/255.0,c[3]/255.0))
		arrays[Mesh.ARRAY_COLOR]=colors

static func _uv(values: Array) -> Array[Vector2]:
	var result: Array[Vector2]=[]
	for i in range(0,values.size(),2):result.append(Vector2(values[i],values[i+1]))
	return result

static func make_mesh(source: Dictionary) -> ArrayMesh:
	var basic:=Ra3Wreck.make_mesh(source)
	var arrays:=basic.surface_get_arrays(0)
	attributes(arrays,source)
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
