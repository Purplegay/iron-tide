extends Ra3UnitModel
## Uprising native skin/animation renderer. Meshes and textures shared across actors.
static var resources: Dictionary = {}
var bone_indices:Dictionary={}
var source: Dictionary
var clips: Dictionary
var rig: Skeleton3D
var native_skin: Skin
var rests: Array[Transform3D] = []
var materials: Array[ShaderMaterial] = []
var parts: Dictionary = {}
var fx_materials: Array[ShaderMaterial] = []
var pitch_bones: Array[int] = []
var gunship_yaw: Dictionary = {}
var gunship_pitch: Dictionary = {}
var contrails: Array[Dictionary] = []
var contrail_clock:=0.0
var contrail_texture: Texture2D
var fire_lights: Array[OmniLight3D] = []
var _surface_flash_active := false
var _material_map_angle := INF
var frame_size := Vector2(120, 120)
var folder := ""
var clip_time := 0.0
var clip_name := ""
var turret_bones: Array[int] = []
var muzzle_bones: Array[int] = []
var tread_distance := 0.0
var requested_clip := "BIDA"
var selection_transition := ""
var future_reverse:=false
var landing_legs:Node3D
var tank_pose
var reaper_pose
var future_charge: Array[Node3D]=[]
var damage_state

static func create(unit: Unit) -> Ra3UnitModel:
	if DisplayServer.get_name() == "headless" or (not unit.data.has("soviet_ra3") and not unit.unit_id in ["R3FUTURE", "R3HARBINGER"]): return null
	var result = load("res://scripts/units/ra3_expansion_model.gd").new()
	result.actor = unit
	unit.add_child(result)
	result._build()
	return result

func _build() -> void:
	bone_indices.clear()
	folder = "res://assets/ra3/expansion/" + ("future/" if actor.unit_id == "R3FUTURE" else "harbinger/")
	if actor.data.has("soviet_ra3"): folder = "res://assets/ra3/soviet/" + actor.unit_id + "/"
	if not resources.has(folder):
		resources[folder] = {"skin": JSON.parse_string(FileAccess.get_file_as_string(folder + "skin.json")),
			"clips": JSON.parse_string(FileAccess.get_file_as_string(folder + "animations.json")), "meshes": []}
	source = resources[folder].skin
	clips = resources[folder].clips
	frame_size = Vector2(120,120) if actor.unit_id == "R3FUTURE" else Vector2(192,192)
	if actor.data.has("soviet_ra3") and actor.unit_id!="R3APOC": frame_size = Vector2(160,160)
	# Keep the trailing chain shoes inside the Apocalypse capture at side-on angles.
	viewport = SubViewport.new()
	viewport.size = RESOLUTION
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	hull = Node3D.new(); world.add_child(hull)
	rig = Skeleton3D.new(); hull.add_child(rig)
	native_skin = Skin.new()
	var globals: Array[Transform3D] = []
	for i in source.bones.size():
		var b: Dictionary = source.bones[i]
		if not bone_indices.has(str(b.name).to_upper()):bone_indices[str(b.name).to_upper()]=i
		var rest := Transform3D(Basis(Ra3BoneAnimation.quaternion(b.rotation)), Ra3BoneAnimation.vector(b.position))
		rests.append(rest)
		rig.add_bone(str(b.name)); rig.set_bone_parent(i,int(b.parent)); rig.set_bone_rest(i,rest)
		var global_rest := globals[int(b.parent)] * rest if int(b.parent) >= 0 else rest
		globals.append(global_rest); native_skin.add_bind(i,global_rest.affine_inverse())
		if str(b.name).to_upper() in ["B_TURRET", "TURRET_FRONT", "TURRET_FR", "TURRET_BR"] or (actor.data.has("soviet_ra3") and str(b.name).to_upper() in ["TURRET", "B_TURRET_02", "B_TURRET_03", "B_TURRET_04", "B_TURRET_05"]): turret_bones.append(i)
		if str(b.name).to_upper().begins_with("TURRET_PITCH_"):pitch_bones.append(i)
		if str(b.name).to_upper() in ["FX_WEAPON_01", "FX_WEAPON_02", "FXGUN_FRONT", "FXGUN_FR", "FXGUN_BR"]: muzzle_bones.append(i)
	if actor.unit_id=="R3TESLA": turret_bones.assign([rig.find_bone("Bone_Turret")])
	rig.reset_bone_poses()
	var cache: Array = resources[folder].meshes
	for i in source.meshes.size():
		var part: Dictionary = source.meshes[i]
		if cache.size() <= i:
			var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
			var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array()
			for j in range(0,part.vertices.size(),3):
				vertices.append(Vector3(part.vertices[j],part.vertices[j+1],part.vertices[j+2]))
				normals.append(Vector3(part.normals[j],part.normals[j+1],part.normals[j+2]).normalized())
			for j in range(0,part.uv.size(),2): uv.append(Vector2(part.uv[j],part.uv[j+1]))
			var indices := PackedInt32Array()
			for j in range(0,part.indices.size(),3): indices.append_array([part.indices[j],part.indices[j+2],part.indices[j+1]])
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_TEX_UV]=uv
			arrays[Mesh.ARRAY_TEX_UV2]=preload("res://scripts/units/unit_cosmetics.gd").weapon_mask(part,source.bones)
			arrays[Mesh.ARRAY_INDEX]=indices; arrays[Mesh.ARRAY_BONES]=PackedInt32Array(part.bones); arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array(part.weights)
			preload("res://scripts/units/ra3_gunship_material.gd").attributes(arrays,part)
			var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var surface := SurfaceTool.new(); surface.create_from(mesh,0); surface.generate_tangents()
			cache.append(surface.commit())
		var material := ShaderMaterial.new(); material.shader=load("res://shaders/ra3_vehicle.gdshader")
		if part.material.has("Texture_0"):
			material=preload("res://scripts/units/ra3_gunship_material.gd").create(part.native_material,part.material,folder)
			fx_materials.append(material)
		else:
			if str(part.native_material.shader).to_lower() in ["objectssoviet.fx", "objectsallied.fx", "objectsalliedtread.fx"]:
				setup_object_surface(material, part.native_material.constants.get("AlphaTestEnable", false))
				material.set_shader_parameter("house_color", actor._col)
			for pair in [["DiffuseTexture","diffuse_map"],["NormalMap","normal_map"],["SpecMap","surface_map"]]:
				if part.material.has(pair[0]): material.set_shader_parameter(pair[1],load(folder+str(part.material[pair[0]])))
			material.set_shader_parameter("house_color",actor._col)
			material.set_shader_parameter("is_tread","TREAD" in str(part.name))
			materials.append(material)
		var instance := MeshInstance3D.new(); instance.mesh=cache[i]; instance.material_override=material
		# Several weapon meshes (including the gunship's CYLINDER01) use FX materials.
		# Tesla tread variants also use those materials but are physical geometry.
		if part.material.has("DiffuseTexture") or str(part.name).get_slice(".",1).begins_with("TREADS"):
			instance.layers |= BODY_MASK_LAYER
			include_body_mesh(instance)
		hull.add_child(instance); instance.skin=native_skin; instance.skeleton=instance.get_path_to(rig)
		parts[str(part.name).get_slice(".",1)]=instance
		if "FXMUZZLE" in str(part.name):instance.visible=false
	surface_lighting = preload("res://scripts/units/ra3_lighting.gd").install(world)
	camera=Camera3D.new(); world.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=frame_size.y/1.5; camera.position=Vector3(0,58,86.60254); camera.rotation_degrees.x=-30
	sync_pose(true)
	if DisplayServer.get_name()!="headless":ground_shadow = load("res://scripts/units/ra3_ground_shadow.gd").attach(self)
	if actor.data.has("soviet_ra3"):
		_sample()
		return
	if actor.unit_id=="R3HARBINGER":contrail_texture=load("res://assets/ra3/expansion/fx/FXMissileStreak.png")
	if actor.unit_id=="R3HARBINGER":
		for i in 2:
			var flash:=OmniLight3D.new();flash.omni_range=150.0;flash.visible=false
			flash.light_color=Color(0.901961,0.686275,0.458824);hull.add_child(flash);fire_lights.append(flash)
	else:
		# FX_Allied_FutureTank_Fire / AlliedFutureTankFireLight, 3 native frames.
		var flash:=OmniLight3D.new();flash.omni_range=150.0;flash.visible=false
		flash.light_color=Color(0.392157,0.392157,1.0);hull.add_child(flash);fire_lights.append(flash)
	_sample()
	# Damage particles reuse gunship helpers that reference Battle/Unit. Resolve
	# them after actor scripts load, rather than creating a preload dependency cycle.
	damage_state=load("res://scripts/units/ra3_damage_state.gd").new()
	actor.add_child(damage_state);damage_state.setup(self)
	if actor.unit_id=="R3FUTURE":
		for i in 2:
			var charge=preload("res://scripts/units/ra3_future_draw.gd").new()
			hull.add_child(charge);charge.build("exfuturetankcharge");charge.visible=false;future_charge.append(charge)

# Keep the exhaust in the capture without changing the tank's scale on the map.
func frame_phase_exhaust(equipped:bool) -> void:
	var size_px:=168.0 if equipped else 120.0
	if frame_size.x==size_px:return
	frame_size=Vector2.ONE*size_px
	camera.size=size_px/1.5
	if ground_shadow!=null:
		ground_shadow.shadow_camera.size=camera.size*ground_shadow.CAPTURE_SCALE
	sync_pose()
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func cosmetic_skeleton() -> Skeleton3D:
	return rig

func project(point: Vector3) -> Vector2:
	return frame_size*0.5+Vector2(point.x,point.z*0.5-(point.y-8.0)*sqrt(0.75))*1.5

func sync_pose(_force := false) -> void:
	if not is_equal_approx(_material_map_angle, Iso.eff_angle()):
		_material_map_angle = Iso.eff_angle()
		for mat in materials:
			if mat.shader == OBJECT_SHADER:
				mat.set_shader_parameter("world_to_map", Basis(Vector3.UP, -_material_map_angle))
	hull.rotation.y=Iso.eff_angle()-actor.hull_angle
	var lift := actor._visual_lift() if actor.is_air else 0.0
	draw_rect=Rect2(-project(Vector3.ZERO)+Vector2(0,actor.radius*0.35-lift-float(actor.special.get("walker_height",0))),frame_size)

func _process(delta: float) -> void:
	if not is_instance_valid(actor): return
	if not actor.is_visible_in_tree() or actor.embarked_in != null or not actor.get_viewport_rect().grow(220).has_point(actor.get_global_transform_with_canvas().origin):
		update_model_resolution(frame_size.x, false)
		if damage_state!=null:damage_state.suspend()
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	_animation_delta+=delta
	if _animation_delta<1.0/30.0: return
	update_model_resolution(frame_size.x, true)
	if not get_tree().paused and not AlliedAbilities.frozen(actor):
		clip_time+=_animation_delta
		tread_distance+=actor.velocity.length()*_animation_delta*0.004
		_sample(_animation_delta)
		if actor.unit_id=="R3HARBINGER":_update_contrails(_animation_delta)
		if damage_state!=null: damage_state.tick(_animation_delta)
	_animation_delta=0.0
	sync_pose()
	for material in materials:
		material.set_shader_parameter("house_color",actor._col)
		material.set_shader_parameter("tread_offset",fposmod(tread_distance,1.0))
	for material in fx_materials:material.set_shader_parameter("age",clip_time)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	actor.queue_redraw()

func _sample(step: float=0.0) -> void:
	if actor.unit_id=="R3HARBINGER":
		_sample_gunship(step)
		return
	var name := "MOVA" if actor.velocity.length()>1.0 else ("AIDA" if actor.selected else "BIDA")
	if actor.special.has("ra3_riot_point"):name="ATKD"
	elif float(actor.special.get("ra3_fire_anim",0.0))>0.0:name="ATKE" if int(actor.special.get("ra3_barrel",0))%2==0 else "ATKF"
	# DEPLOY exists in the include but neither active XML state calls it.
	if actor.unit_id == "R3HARBINGER": name=""
	if actor.unit_id == "R3FUTURE":
		name=_future_clip()
	var reaper_frame:=0.0
	if actor.unit_id=="R3REAPER":
		if reaper_pose==null:reaper_pose=preload("res://scripts/units/ra3_reaper_pose.gd").new()
		reaper_frame=reaper_pose.advance(self,step)
		name=reaper_pose.clip
	elif actor.unit_id=="R3APOC":
		name="MOVA" if actor.velocity.length()>1.0 else "IDLA"
		if actor.special.get("soviet_mode",false): name+="_DOOROPEN"
		var phase:float=actor.special.get("door_phase",1.0 if actor.special.get("soviet_mode",false) else 0.0)
		if phase>0 and phase<1:name="DOOROPEN"
	elif actor.unit_id=="R3TESLA":name=""

	if name != clip_name: clip_name=name; clip_time=0.0
	rig.reset_bone_poses()
	if clips.has(name):
		var data: Dictionary=clips[name]
		var frame := fposmod(clip_time*float(data.fps),float(data.frames))
		if name=="DOOROPEN":frame=float(actor.special.door_phase)*(float(data.frames)-1)
		if reaper_pose!=null:frame=reaper_frame
		if not selection_transition.is_empty():frame=minf(clip_time*float(data.fps),float(data.frames)-1.0)
		if actor.unit_id=="R3FUTURE":
			if selection_transition=="BATB" and future_reverse:frame=float(data.frames)-1.0-frame
			elif selection_transition.is_empty() and requested_clip.begins_with("LASER"):frame=float(data.frames)-1.0
			elif name in ["ATKE","ATKF"]:frame=minf(float(actor.special.get("ra3_attack_age",0.0))*float(data.fps),float(data.frames)-1.0)
		_sample_channels(data,frame)
		if name=="AIDB":_sample_landing()

	if reaper_pose!=null:
		reaper_pose.blend(self)
		reaper_pose.aim_grenades(self,step)
	for b in turret_bones:
		if reaper_pose!=null and (reaper_pose.clip_poses.has(b) or not AlliedAbilities.alive(actor.attack_target)):continue
		var yaw: float=actor.hull_angle-actor.turret_angle
		if actor.unit_id=="R3HARBINGER":
			var front:=str(source.bones[b].name).to_upper()=="TURRET_FRONT"
			var natural:=0.0 if front else PI/2.0
			# Simulation owns rotation; render rate cannot change firing readiness.
			gunship_yaw[b]=float(actor.special.get("ra3_aim_front" if front else ("ra3_aim_rear" if str(source.bones[b].name).to_upper()=="TURRET_BR" else "ra3_aim_side"),natural))
			yaw=gunship_yaw[b]
		rig.set_bone_pose_rotation(b,Quaternion(Vector3.UP,yaw)*rests[b].basis.get_rotation_quaternion())
	if actor.unit_id in ["R3APOC","R3TESLA"] or (actor.unit_id=="R3REAPER" and actor.special.get("walker_deployed",false)):
		if tank_pose==null:tank_pose=preload("res://scripts/units/ra3_tank_presentation.gd").new()
		tank_pose.present(self,step)
	rig.force_update_all_bone_transforms()
	if actor.unit_id=="R3HARBINGER":_gunship_pose(step)
	elif actor.unit_id=="R3FUTURE":_future_effects()
	if not fire_lights.is_empty(): _sync_surface_muzzle_lights()

func _sample_gunship(step:float) -> void:
	# Gunship has no animation clip. Only turret and pitch bones change.
	if not clip_name.is_empty():clip_name="";clip_time=0.0
	for b in pitch_bones:rig.reset_bone_pose(b)
	for b in turret_bones:
		var name:=str(source.bones[b].name).to_upper()
		var front:=name=="TURRET_FRONT"
		var yaw:=float(actor.special.get("ra3_aim_front" if front else ("ra3_aim_rear" if name=="TURRET_BR" else "ra3_aim_side"),0.0 if front else PI/2.0))
		gunship_yaw[b]=yaw
		rig.set_bone_pose_rotation(b,Quaternion(Vector3.UP,yaw)*rests[b].basis.get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
	_gunship_pose(step)
	if not fire_lights.is_empty():_sync_surface_muzzle_lights()

func _sample_channels(data:Dictionary,frame:float) -> void:
	for channel: Dictionary in data.channels:
		if channel.type=="Visibility": continue
		var b:=int(channel.bone); var values: Array=channel.frames
		var cursor:=clampf(frame,0.0,values.size()-1.0); var lo:=int(cursor); var hi:=mini(lo+1,values.size()-1)
		if channel.type=="Orientation":
			var q:=Ra3BoneAnimation.quaternion(values[lo]).slerp(Ra3BoneAnimation.quaternion(values[hi]),cursor-lo)
			rig.set_bone_pose_rotation(b,(rests[b].basis.get_rotation_quaternion()*Quaternion(q.x,q.z,-q.y,q.w)).normalized())
		else:
			var delta_pos:=Vector3.ZERO
			var amount:=lerpf(float(values[lo]),float(values[hi]),cursor-lo)
			match str(channel.type):
				"XTranslation":delta_pos.x=amount
				"YTranslation":delta_pos.z=-amount
				"ZTranslation":delta_pos.y=amount
			if actor.unit_id=="R3REAPER":delta_pos=rests[b].basis*delta_pos
			rig.set_bone_pose_position(b,rig.get_bone_pose_position(b)+delta_pos)

func _sample_landing() -> void:
	if not actor.special.has("walker_landing_age"):
		if is_instance_valid(landing_legs):
			landing_legs.queue_free()
			landing_legs=null
		return
	var age:float=actor.special.walker_landing_age
	if age<20.0/30.0:
		# The replacement building blends from the last airborne skeleton into AIDB.
		var ground:Array[Transform3D]=[]
		for i in rig.get_bone_count():ground.append(rig.get_bone_pose(i))
		rig.reset_bone_poses()
		_sample_channels(clips.JMPB,actor.special.get("walker_touch_frame",0.0))
		for i in ground.size():rig.set_bone_pose(i,rig.get_bone_pose(i).interpolate_with(ground[i],age*30/20))
	if landing_legs==null:
		landing_legs=preload("res://scripts/units/ra3_reaper_legs.gd").new()
		hull.add_child(landing_legs)
		landing_legs.setup(self)
	landing_legs.sample(age)

func _future_clip() -> String:
	var desired:=preload("res://scripts/units/ra3_future_state.gd").desired(actor)
	if desired!=requested_clip:
		var previous:=requested_clip
		if selection_transition=="BATB" and future_reverse and not desired.begins_with("LASER"):
			requested_clip=desired
			if clip_time<1.0:return "BATB"
			selection_transition=""
			return desired
		if desired.begins_with("LASER") and previous.begins_with("LASER"):
			# A movement-condition change must not restart or skip the active unpack.
			requested_clip=desired
			if selection_transition=="BATB" and clip_time<1.0:return "BATB"
			selection_transition=""
			return "BATB" if desired=="LASER_MOVING" else "ATKD"
		var old_transition:=selection_transition
		var old_time:=clip_time
		requested_clip=desired;selection_transition="";future_reverse=false
		if desired.begins_with("LASER") and not previous.begins_with("LASER"):
			selection_transition="BATB"
		elif previous.begins_with("LASER") and not desired.begins_with("LASER"):
			selection_transition="BATB";future_reverse=true
			Ra2Sfx.play("RA3_EXP_ALL_FutureTank_ArmPrimaryWeapon",actor.position)
		elif desired=="AIDA" and previous=="BIDA":selection_transition="BATA"
		elif desired=="BIDA" and previous in ["AIDA","MOVA"]:selection_transition="ABTA"
		if not selection_transition.is_empty():
			clip_name=selection_transition;clip_time=0.0
			if old_transition=="BATB":clip_time=maxf(0.0,1.0-minf(old_time,1.0))
		if desired.begins_with("LASER") and not previous.begins_with("LASER"):
			Ra2Sfx.play("RA3_EXP_ALL_FutureTank_ArmSecondaryWeaponMS",actor.position)
	if not selection_transition.is_empty():
		var transition: Dictionary=clips[selection_transition]
		if clip_time<(float(transition.frames)-1.0)/float(transition.fps):return selection_transition
		selection_transition=""
	return ("BATB" if desired=="LASER_MOVING" else "ATKD") if desired.begins_with("LASER") else desired

func _sync_surface_muzzle_lights() -> void:
	var positions := PackedVector4Array()
	var colors := PackedVector3Array()
	for light in fire_lights:
		if not light.visible or light.light_energy <= 0.0: continue
		var p := light.position
		positions.append(Vector4(p.x, p.y, p.z, light.omni_range))
		var color := light.light_color
		colors.append(Vector3(color.r, color.g, color.b) * light.light_energy)
	var count := positions.size()
	if count == 0 and not _surface_flash_active: return
	_surface_flash_active = count > 0
	positions.resize(2)
	colors.resize(2)
	for material in materials:
		if material.shader != OBJECT_SHADER: continue
		material.set_shader_parameter("muzzle_light_count", count)
		if count > 0:
			material.set_shader_parameter("muzzle_positions_ranges", positions)
			material.set_shader_parameter("muzzle_colors", colors)

func _future_effects() -> void:
	var pre:=float(actor.special.get("ra3_pre_left",0.0))>0.0
	var firing_age:=float(actor.special.get("ra3_attack_age",100.0))
	if not fire_lights.is_empty():
		var light:=fire_lights[0]
		light.visible=firing_age<0.1 and not actor.special.has("ra3_riot_point")
		light.light_energy=4.0*(1.0-clampf((firing_age/0.1-0.1)/0.9,0,1))
		light.position=rig.get_bone_global_pose(12 if int(actor.special.get("ra3_barrel",0))%2==0 else 7).origin+Vector3.UP*10.0
	for i in future_charge.size():
		var charge=future_charge[i]
		charge.visible=(pre or firing_age<5.0) and not requested_clip.begins_with("LASER") and not actor.special.has("ra3_riot_point")
		if not charge.visible:continue
		var bone:=7 if i==1 else 12 # Named FX_Laser02 / FX_Laser01, verified in imported rig.
		charge.transform=rig.get_bone_global_pose(bone)
		var barrel:=int(actor.special.get("ra3_barrel",0))%2
		var backwards:=barrel==i
		var seconds:=float(actor.special.get("ra3_pre_elapsed",0.0)) if pre else firing_age
		charge.sample(seconds,0.0 if pre else (1.0 if backwards else 4.0),backwards and not pre)

func _gunship_pose(step: float) -> void:
	var gun:=bool(actor.special.get("ra3_gun_mode",false))
	var firing:=float(actor.special.get("ra3_fire_anim",0.0))
	var mounts: Dictionary=actor.special.get("ra3_mounts",{})
	var flashes: Array[float]=[float(mounts.get("front",{}).get("flash",firing)),float(mounts.get("side",{}).get("flash",firing)),float(mounts.get("rear",{}).get("flash",firing))]
	parts.SKINGUNS.visible=not gun
	parts.CYLINDER01.visible=not gun
	parts.SKINMACHINEGUN.visible=gun
	parts.FXMUZZLEFRONT.visible=gun and flashes[0]>0.44
	parts.FXMUZZLE_FR.visible=not gun and flashes[1]>0.4
	parts.FXMUZZLE_BR.visible=not gun and flashes[2]>0.4
	for i in 2:
		parts[["FXMUZZLE_FR","FXMUZZLE_BR"][i]].material_override.set_shader_parameter("opacity",clampf((flashes[i+1]-0.4)/0.1,0.0,1.0))
	var target=actor.attack_target
	if AlliedAbilities.alive(target):
		for b in pitch_bones:
			var parent:=rig.get_bone_parent(b)
			var global_parent:=rig.get_bone_global_pose(parent).basis
			var yaw: float=gunship_yaw.get(parent,0.0)
			var forward:=Vector3(cos(yaw),0,-sin(yaw))
			var axis:=global_parent.inverse()*(Vector3.UP.cross(forward))
			var front:=str(source.bones[parent].name).to_upper()=="TURRET_FRONT"
			# Official front gun pitches at 20deg/s, down to -30deg;
			# side guns pitch at 180deg/s, down to -45deg.
			gunship_pitch[b]=float(actor.special.get("ra3_aim_front_pitch" if front else ("ra3_aim_rear_pitch" if str(source.bones[parent].name).to_upper()=="TURRET_BR" else "ra3_aim_side_pitch"),0.0))
			rig.set_bone_pose_rotation(b,Quaternion(axis.normalized(),float(gunship_pitch[b]))*rests[b].basis.get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
	for i in fire_lights.size():
		# AlliedGunshipFireLight is a 3-frame LightSource, not a large billboard.
		fire_lights[i].visible=not gun and flashes[i+1]>0.4
		fire_lights[i].light_energy=4.0*clampf((flashes[i+1]-0.4)/0.1,0,1)
		fire_lights[i].position=rig.get_bone_global_pose(16 if i==0 else 25).origin+Vector3.UP*10.0

func draw_on() -> void:
	sync_pose()
	_draw_contrails()
	capture_body_outline(Ra3Mirage.CloakVisual.opacity(actor))
	if actor.has_meta("time_fracture"):
		preload("res://scripts/core/yr_signature_fx.gd").ghosts(actor,viewport.get_texture(),draw_rect,Rect2(Vector2.ZERO,viewport.size),actor.get_meta("time_fracture"))
	actor.draw_texture_rect(viewport.get_texture(),draw_rect,false,Color(1,1,1,Ra3Mirage.CloakVisual.opacity(actor)))

func muzzle() -> Vector2:
	sync_pose()
	var barrel:=int(actor.special.get("ra3_barrel",0))%2
	var name: String
	if actor.unit_id=="R3FUTURE":name=("FX_WEAPON_0" if actor.special.has("ra3_riot_point") else "FX_LASER0")+str(barrel+1)
	else:name="FXGUN_FRONT" if actor.special.get("ra3_gun_mode",false) else ("FXGUN_FR" if barrel==0 else "FXGUN_BR")
	if actor.unit_id=="R3APOC": name="FX_HARPOON" if actor.special.get("soviet_mode",false) else "FX_MUZZLEFLASH%02d"%(barrel+1)
	elif actor.unit_id=="R3TESLA": name="FX_WEAPON_%02d"%(barrel+1)
	elif actor.unit_id=="R3REAPER": name=str(actor.special.get("soviet_muzzle","FX_ROCKET01"))
	return bone_world(name)

func bone_world(name: String) -> Vector2:
	var bone:int=bone_indices.get(name,-1)
	var point:=rig.get_bone_global_pose(bone).origin if bone>=0 else Vector3.ZERO
	return actor.global_position+RA2Art.art_dir(draw_rect.position+project(hull.transform*point))

func _update_contrails(delta: float) -> void:
	contrail_clock+=delta
	# FireHawkConTrail: TrailLife=15 frames, Size=1, FXCon_R/FXCon_L.
	contrails=contrails.filter(func(p):return contrail_clock-float(p.time)<=15.0/30.0)
	if actor.velocity.length()<1.0:return
	sync_pose()
	if not contrails.is_empty() and actor.position.distance_to(contrails[-1].ground)>300.0:contrails.clear()
	contrails.append({"time":contrail_clock,"ground":actor.position,"right":bone_world("FXCON_R"),"left":bone_world("FXCON_L")})

func _draw_contrails() -> void:
	if contrail_texture==null:return
	for i in range(1,contrails.size()):
		for side in ["right","left"]:
			var a:=Iso.dir(contrails[i-1][side]-actor.global_position)
			var b:=Iso.dir(contrails[i][side]-actor.global_position)
			var normal:=a.direction_to(b).orthogonal()*1.5
			var alpha:=clampf(1.0-(contrail_clock-float(contrails[i].time))/0.5,0,1)
			actor.draw_polygon(PackedVector2Array([a-normal,b-normal,b+normal,a+normal]),PackedColorArray([Color(0.282353,0.282353,0.282353,alpha)]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),contrail_texture)

func center() -> Vector2:
	sync_pose()
	return actor.global_position+RA2Art.art_dir(draw_rect.position+project(Vector3(0,8,0)))

func hits(world_point: Vector2) -> bool:
	var local:=Iso.dir(world_point-actor.global_position)
	if not draw_rect.has_point(local): return false
	if _image_frame!=Engine.get_process_frames():
		_image=viewport.get_texture().get_image();_image_frame=Engine.get_process_frames()
	if _image==null or _image.is_empty():return false
	var pixel:=Vector2i((local-draw_rect.position)/frame_size*Vector2(_image.get_size()))
	return _image.get_pixelv(pixel).a>0.15
