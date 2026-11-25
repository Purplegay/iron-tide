class_name Ra3BoneAnimation
extends RefCounted
## Source W3X channels are deltas from their pivot's bind transform.
const ROOT := "res://assets/ra3/mirage/native/"
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "skin.json"))
static var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "animations.json"))
var skeleton: Skeleton3D
var skin: Skin
var rests: Array[Transform3D] = []
var clip := "IDLA"
var time := 0.0
var enabled := true
var state_name := "STATE_bored"
var transition_left := 0.0

static func vector(v: Array) -> Vector3:
	return Vector3(v[0], v[1], v[2])

static func quaternion(v: Array) -> Quaternion:
	return Quaternion(v[0], v[1], v[2], v[3]).normalized()

func build(parent: Node3D) -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "NativeRig"
	parent.add_child(skeleton)
	skin = Skin.new()
	var global_rests: Array[Transform3D] = []
	for i in source.bones.size():
		var row: Dictionary = source.bones[i]
		var rest := Transform3D(Basis(quaternion(row.rotation)), vector(row.position))
		rests.append(rest)
		skeleton.add_bone(row.name)
		skeleton.set_bone_parent(i, int(row.parent))
		skeleton.set_bone_rest(i, rest)
		var global_rest := global_rests[int(row.parent)] * rest if int(row.parent) >= 0 else rest
		global_rests.append(global_rest)
		skin.add_bind(i, global_rest.affine_inverse())
	skeleton.reset_bone_poses()

func advance(delta: float, moving: bool, field: bool=false, selected: bool=false) -> void:
	if not enabled: return
	var next_state := "STATE_Field" if field else ("MOVING" if moving else ("STATE_SelectedPose" if selected else "STATE_bored"))
	if state_name=="STATE_Field" and not field:
		transition_left=(float(clips.IDLA.frames)-1.0)/float(clips.IDLA.fps)
		time=0.0;clip="IDLA"
	state_name=next_state
	if field: transition_left=0.0
	if transition_left>0.0:
		transition_left=maxf(0.0,transition_left-delta)
		time+=delta;sample("IDLA",time,true);return
	var next := "MOVA" if moving else "IDLA"
	if clip != next:
		clip = next
		time = 0.0
	time += maxf(delta, 0.0)
	# SDK idle has RESTART_ANIM_WHEN_COMPLETE; moving is LOOP.
	sample(clip, time)

func sample(name: String, seconds: float, once: bool=false) -> void:
	var data: Dictionary = clips[name]
	var frame := minf(seconds*float(data.fps),float(data.frames)-1.0) if once else fposmod(seconds * float(data.fps), float(data.frames))
	skeleton.reset_bone_poses()
	for channel: Dictionary in data.channels:
		var b := int(channel.bone)
		var values: Array = channel.frames
		var cursor := clampf(frame - float(channel.first), 0.0, values.size() - 1.0)
		var lower := int(cursor)
		var upper := mini(lower + 1, values.size() - 1)
		var fraction := cursor - lower
		if channel.type == "Orientation":
			var q := quaternion(values[lower]).slerp(quaternion(values[upper]), fraction)
			var converted := Quaternion(q.x, q.z, -q.y, q.w)
			skeleton.set_bone_pose_rotation(b, (rests[b].basis.get_rotation_quaternion() * converted).normalized())
		else:
			var amount := lerpf(float(values[lower]), float(values[upper]), fraction)
			var offset := Vector3.ZERO
			match str(channel.type):
				"XTranslation": offset.x = amount
				"YTranslation": offset.z = -amount
				"ZTranslation": offset.y = amount
			skeleton.set_bone_pose_position(b, rests[b].origin + offset)
	skeleton.force_update_all_bone_transforms()

func muzzle() -> Vector3:
	return skeleton.get_bone_global_pose(int(source.muzzle_bone)).origin
