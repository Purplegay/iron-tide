extends Node3D
## Offsets use one percent of the hull span. At rest, all parts share the hull axes.
var rig:Skeleton3D
var default_origin:=Vector3.ZERO
var part_id:=-1
var native_part:=""
var follow_from_rest:=false
var anchor_frame:=Transform3D.IDENTITY
var offset:=Vector3i.ZERO
var tilt:=0
var angles:=Vector3i.ZERO # X roll, Y yaw, Z legacy pitch.
var dimensions:=Vector3.ONE
var _local_transform:=Transform3D.IDENTITY
var _local_angles:=Vector3i(2147483647,0,0)
var _local_offset:=Vector3i.ZERO
var _local_dimensions:=Vector3.ONE

func local_transform() -> Transform3D:
	# Bone animation changes anchor_frame, not the authored rotation/size/offset.
	# Compare fields so editor adjustments and direct callers both invalidate safely.
	if angles!=_local_angles or offset!=_local_offset or dimensions!=_local_dimensions:
		_local_angles=angles;_local_offset=offset;_local_dimensions=dimensions
		_local_transform=Transform3D(rotation_basis()*Basis.from_scale(dimensions),Vector3(offset)*0.01)
	return _local_transform


func configure(part:String,degrees:int,shift:Vector3i,size_factor:=Vector3.ONE,extra_angles:=Vector2i.ZERO) -> void:
	dimensions=size_factor
	angles=Vector3i(extra_angles.x,extra_angles.y,degrees)
	follow_from_rest=part.is_empty() and not native_part.is_empty()
	var binding:=native_part if follow_from_rest else part
	part_id=rig.find_bone(binding) if not binding.is_empty() else -1
	tilt=degrees
	offset=shift
	if part_id>=0 and not rig.skeleton_updated.is_connected(_sync_pose):
		rig.skeleton_updated.connect(_sync_pose)
	elif part_id<0 and rig.skeleton_updated.is_connected(_sync_pose):
		rig.skeleton_updated.disconnect(_sync_pose)
	_sync_pose()

func _sync_pose() -> void:
	anchor_frame=Transform3D(Basis.IDENTITY,default_origin)
	if part_id>=0:
		var socket:=get_parent_node_3d()
		var pose:=rig.get_bone_global_pose(part_id)
		var rest:=rig.get_bone_global_rest(part_id)
		var rotation:=pose.basis.orthonormalized()*rest.basis.orthonormalized().inverse()
		# Socket and rig are siblings under the hull, including during unit setup before entering the tree.
		if follow_from_rest:
			var to_rig:=rig.transform.affine_inverse()*socket.transform
			var motion:=Transform3D(rotation,pose.origin-rotation*rest.origin)
			anchor_frame=to_rig.affine_inverse()*motion*to_rig*anchor_frame
		else:
			anchor_frame=socket.transform.affine_inverse()*rig.transform*Transform3D(rotation.scaled(Vector3.ONE*socket.scale.x),pose.origin)
	var next_transform:=anchor_frame*local_transform()
	if transform!=next_transform:transform=next_transform

func rotation_basis() -> Basis:
	return Basis.from_euler(Vector3(angles)*PI/180.0)

func editing_basis() -> Basis:
	return get_parent_node_3d().global_basis*anchor_frame.basis
