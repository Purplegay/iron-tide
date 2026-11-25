extends Node2D
## Retail container attachments, bind poses, native material, and grenade rotation.
const Pose=preload("res://scripts/units/ra3_reaper_pose.gd")
const MaterialTools=preload("res://scripts/units/ra3_gunship_material.gd")
const ROOT="res://assets/ra3/soviet/reaper_fx/"
const SIZE=72.0
static var meshes:Dictionary={}
var viewport:SubViewport
var axis:Node3D
var pivots:Array[Node3D]=[]
var materials:Array[ShaderMaterial]=[]
var data:Dictionary
var model_id:String
var house_color:Color

static func attach(shot):
	if DisplayServer.get_name()=="headless":return null
	var visual=shot.get_node_or_null("ReaperRound")
	if visual!=null:return visual
	var model:=model_for(shot.splinters)
	var color:Color=shot.splinters.get("reaper_color",Color.WHITE)
	var pool=shot.get_parent().get_parent().get_node_or_null("ReaperRoundPool")
	if pool!=null:
		for idle in pool.get_children():
			if idle.model_id==model and idle.house_color==color:
				idle.reparent(shot,false)
				idle.name="ReaperRound"
				return idle
	visual=load("res://scripts/units/ra3_reaper_round.gd").new()
	visual.name="ReaperRound"
	shot.add_child(visual)
	visual.setup(shot)
	return visual

static func release(shot) -> void:
	var visual=shot.get_node_or_null("ReaperRound")
	# Do not retain large zoomed-in render targets in the idle cache.
	if visual==null or visual.viewport.size.x>256:return
	var battle=shot.get_parent().get_parent()
	var pool=battle.get_node_or_null("ReaperRoundPool")
	if pool==null:
		pool=Node2D.new();pool.name="ReaperRoundPool";pool.visible=false
		pool.process_mode=Node.PROCESS_MODE_DISABLED
		battle.add_child(pool)
	if pool.get_child_count()>=24:return
	visual.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if visual.is_in_group("ra3_weapon_fx_captures"):visual.remove_from_group("ra3_weapon_fx_captures")
	visual.reparent(pool,false)

static func model_for(state:Dictionary) -> String:
	var kind:="rocket" if state.soviet_round=="rocket" else "grenade"
	var spec:Dictionary=Pose.definitions.rounds[kind]
	return spec.hero_model if state.get("reaper_heroic",false) else spec.model

func setup(shot) -> void:
	var state:Dictionary=shot.splinters
	house_color=state.get("reaper_color",Color.WHITE)
	model_id=model_for(state)
	data=Pose.definitions.models[model_id]
	viewport=SubViewport.new();viewport.size=Vector2i(96,96);viewport.own_world_3d=true;viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	var space:=Node3D.new();viewport.add_child(space)
	axis=Node3D.new();space.add_child(axis)
	for bone in data.bones:
		var pivot:=Node3D.new()
		if int(bone.get("parent",-1))>=0:pivots[int(bone.parent)].add_child(pivot)
		else:axis.add_child(pivot)
		pivot.position=Ra3BoneAnimation.vector(bone.position);pivot.quaternion=Ra3BoneAnimation.quaternion(bone.rotation)
		pivots.append(pivot)
	for i in data.parts.size():
		var row:Dictionary=data.parts[i]
		var key:=model_id+str(i)
		if not meshes.has(key):meshes[key]=MaterialTools.make_mesh(row)
		var part:=MeshInstance3D.new();part.mesh=meshes[key]
		var material_:ShaderMaterial
		if row.textures.has("Texture_0"):
			material_=MaterialTools.create(row.material,row.textures,ROOT)
			materials.append(material_)
		else:
			material_=ShaderMaterial.new();material_.shader=preload("res://shaders/ra3_vehicle.gdshader")
			for pair in [["DiffuseTexture","diffuse_map"],["NormalMap","normal_map"],["SpecMap","surface_map"]]:
				if row.textures.has(pair[0]):material_.set_shader_parameter(pair[1],load(ROOT+row.textures[pair[0]]))
			material_.set_shader_parameter("house_color",house_color)
		part.material_override=material_;pivots[int(row.bone)].add_child(part)
	preload("res://scripts/units/ra3_lighting.gd").install(space)
	var camera:=Camera3D.new();space.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=SIZE/1.5;camera.position=Vector3(0,100,173.205);camera.rotation_degrees.x=-30

func sync(state:Dictionary) -> void:
	var heading:float=state.get("reaper_yaw",0)
	axis.basis=Basis(Vector3.UP,Iso.eff_angle()-heading)*Basis(Vector3.BACK,float(state.get("reaper_pitch",0)))
	if data.has("animation"):
		var clip:Dictionary=data.animation
		var frame:=fposmod(float(state.age)*float(clip.fps),float(clip.frames))
		var hi:=clampi(clip.times.bsearch(frame),0,clip.times.size()-1)
		var lo:=maxi(hi-1,0)
		var factor:=clampf((frame-float(clip.times[lo]))/maxf(1,float(clip.times[hi])-float(clip.times[lo])),0,1)
		var rotation_key:=Ra3BoneAnimation.quaternion(clip.keys[lo]).slerp(Ra3BoneAnimation.quaternion(clip.keys[hi]),factor)
		pivots[int(clip.bone)].quaternion=Ra3BoneAnimation.quaternion(data.bones[int(clip.bone)].rotation)*rotation_key
	for mat in materials:mat.set_shader_parameter("age",float(state.age))
	preload("res://scripts/units/ra3_fx_resolution.gd").update(self, viewport, SIZE, 96)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	queue_redraw()

func _draw() -> void:
	if viewport==null:return
	Iso.begin(self)
	draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ONE*-SIZE/2,Vector2.ONE*SIZE),false)
