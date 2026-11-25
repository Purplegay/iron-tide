extends RefCounted
## Per-slot simulation angles, shared with the animated model bones.
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func desired(actor, target) -> float:
	return wrapf(actor.hull_angle-actor.position.direction_to(target.position).angle(),-PI,PI)

static func settings(key: String) -> Dictionary:
	for child: Dictionary in rules.mounts[key].turret.children:
		if child.type == "TurretSettings": return child.attrs
	return {}

static func in_arc(actor, target, key: String) -> bool:
	if not AlliedAbilities.alive(target): return false
	return key == "front" or absf(wrapf(desired(actor,target)-PI/2.0,-PI,PI)) <= PI/4.0+0.00001

static func pitch_to(actor, target) -> float:
	var height: float = target._visual_lift() if target is Unit else 0.0
	return atan2(maxf(0.0,actor._visual_lift()-height)*0.9,maxf(1.0,actor.position.distance_to(target.position)))

static func tick(actor, delta: float) -> void:
	for mode in ["front","side","rear"]:
		var target = actor.special.get("ra3_mounts",{}).get(mode,{}).get("target",actor.attack_target)
		var valid := AlliedAbilities.alive(target)
		var native := settings(mode)
		var natural := 0.0 if mode=="front" else PI/2.0
		var yaw := desired(actor,target) if valid else natural
		if mode!="front": yaw=natural+clampf(wrapf(yaw-natural,-PI,PI),-PI/4.0,PI/4.0)
		var key: String="ra3_aim_"+mode
		actor.special[key]=rotate_toward(float(actor.special.get(key,natural)),yaw,deg_to_rad(float(native.TurretTurnRate))*delta)
		var pitch := pitch_to(actor,target) if valid else 0.0
		var limit := absf(deg_to_rad(float(str(native.MinimumPitch).trim_suffix("d"))))
		actor.special[key+"_pitch"]=move_toward(float(actor.special.get(key+"_pitch",0.0)),minf(pitch,limit),deg_to_rad(float(native.TurretPitchRate))*delta)

static func ready(actor, target, mount: String = "") -> bool:
	if mount.is_empty(): mount="front" if actor.special.get("ra3_gun_mode",false) else "side"
	if not in_arc(actor,target,mount): return false
	var key := "ra3_aim_"+mount
	if not actor.special.has(key): return false
	var tolerance := deg_to_rad(float(str(rules.mounts[mount].weapon.attrs.AcceptableAimDelta).trim_suffix("d")))
	return absf(angle_difference(float(actor.special[key]),desired(actor,target)))<=tolerance and absf(float(actor.special.get(key+"_pitch",0.0))-pitch_to(actor,target))<=tolerance
