extends Node3D
## Original three attached FX meshes plus DISGUISED ear drawable emitters.
const ROOT := "res://assets/ra3/mirage/completion/"
const Factory = preload("res://scripts/units/ra3_gunship_material.gd")
const Particle = preload("res://scripts/units/ra3_gunship_impact.gd")
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"media.json"))
static var meshes: Dictionary={}
var model
var materials: Array[ShaderMaterial]=[]
var rays: Array[Dictionary]=[]
var clocks := [5.0,5.0]
var age:=0.0

static func mesh(part: Dictionary) -> ArrayMesh:
	if meshes.has(part.name):return meshes[part.name]
	var basic:=Factory.make_mesh(part)
	var arrays:=basic.surface_get_arrays(0)
	if not part.bones.is_empty():
		arrays[Mesh.ARRAY_BONES]=PackedInt32Array(part.bones)
		arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array(part.weights)
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[part.name]=result
	return result

func build(renderer) -> void:
	model=renderer
	for part: Dictionary in data.parts:
		var node:=MeshInstance3D.new();node.mesh=mesh(part);add_child(node)
		node.skin=model.animation.skin;node.skeleton=node.get_path_to(model.animation.skeleton)
		var material:=Factory.create(part.material,part.textures,ROOT)
		node.material_override=material;materials.append(material)

func tick(delta: float) -> void:
	age+=delta
	for material in materials:material.set_shader_parameter("age",age)
	if not Ra3Mirage.disguised(model.actor):
		for row in rays:row.node.queue_free()
		rays.clear();clocks=[5.0,5.0];return
	for i in 2:
		clocks[i]-=delta*30.0
		var rule: Dictionary=data.ray_particles[i]
		while clocks[i]<=0:
			var node:=MeshInstance3D.new();node.mesh=mesh(data.ray_mesh);add_child(node)
			var material:=Factory.create(data.ray_mesh.material,data.ray_mesh.textures,ROOT)
			node.material_override=material
			rays.append({"node":node,"material":material,"age":0.0,"side":i,"data":rule,"alpha":Particle.sample_alpha_keys(rule)})
			clocks[i]+=Particle.range_value(Particle.child(rule,"BurstDelay"))
	for row in rays.duplicate():
		row.age+=delta*30.0
		var life:=Particle.range_value(Particle.child(row.data,"Lifetime"))
		if row.age>=life:row.node.queue_free();rays.erase(row);continue
		var update:=Particle.child(row.data,"Update/RenderObject")
		var rate:=Particle.range_value(Particle.child(update,"SizeRate/x"))
		var damping:=Particle.range_value(Particle.child(update,"SizeDamping/x"))
		row.node.scale=Vector3.ONE*maxf(0.0001,rate*Particle.integral(row.age,damping))
		var bone: int = model.animation.skeleton.find_bone("BONE_EAR_LEFT" if row.side==0 else "BONE_EAR_RIGHT")
		var velocity:=Particle.xyz(Particle.child(row.data,"Velocity/Ortho/Position"))
		row.node.position=model.animation.skeleton.get_bone_global_pose(bone).origin+velocity*float(row.age)
		row.material.set_shader_parameter("age",row.age/30.0)
		row.material.set_shader_parameter("opacity",Particle.sampled_alpha(row.alpha,row.age/life*100.0))

static func disguise_id(actor) -> String:
	if not Ra3Mirage.disguised(actor):
		actor.special.erase("ra3_disguise_prop");return "Tree01"
	if actor.special.has("ra3_disguise_prop"):return actor.special.ra3_disguise_prop
	var world=actor._battle_world()
	var terrain: String=world.get_meta("ra3_terrain_class","Misc")
	var chosen: String=data.terrain.get(terrain,"Tree01")
	var distance:=100.0*Ra3Mirage.WORLD_SCALE
	for prop in world.get_tree().get_nodes_in_group("obstacles"):
		if not world.is_ancestor_of(prop):continue
		var d: float=actor.position.distance_to(prop.position)
		if d<distance:
			distance=d;chosen=prop.get_meta("ra3_disguise_prop","Rock01")
	if not data.props.has(chosen):chosen="Tree01"
	actor.special.ra3_disguise_prop=chosen
	return chosen
