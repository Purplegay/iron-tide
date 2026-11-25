extends SubViewport
## One static render per selected 3D unit type, shared by all its destination slots.
var hull:=Node3D.new()
var drawn_heading:=INF

func build(model) -> void:
	size=Vector2i(model.draw_rect.size*2.0)
	own_world_3d=true
	transparent_bg=true
	render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(hull)
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/formation_mesh.gdshader")
	var skeleton:Skeleton3D
	for original in model.hull.get_children():
		if not original is MeshInstance3D or not original.visible or not (original.layers & model.BODY_MASK_LAYER):continue
		var mesh:=MeshInstance3D.new()
		mesh.mesh=original.mesh
		mesh.transform=original.transform
		mesh.material_override=material
		hull.add_child(mesh)
		var source=original.get_node_or_null(original.skeleton)
		if source is Skeleton3D:
			if skeleton==null:
				skeleton=Skeleton3D.new()
				hull.add_child(skeleton)
				skeleton.transform=model.hull.global_transform.affine_inverse()*source.global_transform
				for b in source.get_bone_count():
					skeleton.add_bone(source.get_bone_name(b))
					skeleton.set_bone_parent(b,source.get_bone_parent(b))
					skeleton.set_bone_rest(b,source.get_bone_rest(b))
					var pose:Transform3D=source.get_bone_pose(b)
					if "TURRET" in str(source.get_bone_name(b)).to_upper():
						pose=source.get_bone_rest(b)
						if model.actor.unit_id=="R3REAPER":
							var reaper=preload("res://scripts/units/ra3_reaper_pose.gd")
							for mount in reaper.definitions.grenade_mounts:
								if StringName(mount.turret)==source.get_bone_name(b):
									pose.basis=pose.basis.rotated(Vector3.UP,-reaper.natural_heading(mount))
									break
					skeleton.set_bone_pose(b,pose)
			mesh.skin=original.skin
			mesh.skeleton=mesh.get_path_to(skeleton)
	var cam:=Camera3D.new()
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=model.camera.size
	cam.transform=model.camera.transform
	add_child(cam)

func face(heading:float) -> void:
	var yaw:=Iso.eff_angle()-heading
	if not is_equal_approx(yaw,drawn_heading) or not is_finite(drawn_heading):
		drawn_heading=yaw
		hull.rotation.y=yaw
		render_target_update_mode=SubViewport.UPDATE_ONCE
