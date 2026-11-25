extends Node3D
## Retail JMPC_LEGS uses eight rigid joints and the vehicle's material.
const SOURCE="res://assets/ra3/soviet/R3REAPER/landing_legs.json"
static var data:Dictionary={}
static var meshes:Array[ArrayMesh]=[]
var joints:Array[Node3D]=[]

func setup(model) -> void:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for bone in data.bones:
		var node:=Node3D.new()
		var parent:Node3D=self if int(bone.parent)<0 else joints[int(bone.parent)]
		parent.add_child(node)
		joints.append(node)
	for i in data.parts.size():
		var part:Dictionary=data.parts[i]
		if meshes.size()==i:meshes.append(Ra3Wreck.make_mesh(part))
		var mesh:=MeshInstance3D.new()
		mesh.mesh=meshes[i]
		mesh.material_override=model.materials[0]
		joints[int(part.bone)].add_child(mesh)

func sample(age:float) -> void:
	# LifetimeUpdate at 5s, then SlowDeath's 5s before sinking, 8s before deletion.
	position.y=-maxf(0.0,age-10.0)*1.5
	var frame:=minf(age*float(data.fps),float(data.frames)-1)
	for i in joints.size():
		joints[i].position=Ra3BoneAnimation.vector(data.bones[i].position)
		joints[i].quaternion=Ra3BoneAnimation.quaternion(data.bones[i].rotation)
	for track in data.tracks:
		var hi:=clampi(track.times.bsearch(frame),0,track.times.size()-1)
		var lo:=maxi(0,hi-1)
		var weight:=clampf((frame-track.times[lo])/maxf(1.0,track.times[hi]-track.times[lo]),0.0,1.0)
		var joint:=joints[int(track.bone)]
		var a:Array=track.values[lo]
		var b:Array=track.values[hi]
		if track.kind=="Orientation":
			var q:=Ra3BoneAnimation.quaternion(a).slerp(Ra3BoneAnimation.quaternion(b),weight)
			joint.quaternion=joint.quaternion*Quaternion(q.x,q.z,-q.y,q.w)
		else:
			var offset:=lerpf(a[0],b[0],weight)
			var axis:=Vector3.ZERO
			match str(track.kind):
				"XTranslation":axis.x=offset
				"YTranslation":axis.z=-offset
				"ZTranslation":axis.y=offset
			joint.position+=Ra3BoneAnimation.quaternion(data.bones[int(track.bone)].rotation)*axis
