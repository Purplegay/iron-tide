extends RefCounted
const FX=preload("res://scripts/units/ra3_tank_fx.gd")
const P=preload("res://scripts/units/ra3_gunship_impact.gd")
const Mats=preload("res://scripts/units/ra3_gunship_material.gd")
const Beam=preload("res://scripts/units/ra3_tank_beam.gd")
static var ring_source:Dictionary={}
static var ring_mesh:ArrayMesh
var rings:Array[Dictionary]=[]
var ring_clock:=0.0
var emit_clock:=0.0
var last_heading:=NAN
var tractor:WeakRef
var previous_speed:=0.0
var hull_damage:=-1
var skins:Array[Dictionary]=[]
var attachment_clocks:Dictionary={}

static func tick(unit,dt:float) -> void:
	var open:bool=unit.special.get("soviet_mode",false)
	unit.special.door_phase=move_toward(float(unit.special.get("door_phase",1.0 if open else 0.0)),1.0 if open else 0.0,dt*30.0/100.0)
	if unit.special.has("barrel_age"):
		var ages:Array=unit.special.barrel_age
		for i in ages.size():ages[i]=minf(1.0,float(ages[i])+dt)

static func recoil(age:float) -> float:
	var spec:Dictionary=FX.bank.recoil
	var frames:=age*30
	var travel:=float(spec.MaxRecoilDistance)/float(spec.InitialRecoilSpeed)
	if frames<travel:return frames*float(spec.InitialRecoilSpeed)
	var settle:float=(frames-travel)*float(spec.RecoilSettleSpeed)/float(spec.MaxRecoilDistance)
	return float(spec.MaxRecoilDistance)*exp(-float(spec.RecoilDamping)*settle)

func present(model,dt:float) -> void:
	var unit=model.actor
	var deployed_reaper:bool=unit.unit_id=="R3REAPER" and unit.special.get("walker_deployed",false)
	_attachments(model,dt,"R3REAPERTURRET" if deployed_reaper else unit.unit_id)
	if deployed_reaper:return
	if unit.unit_id=="R3TESLA":
		var charge:Dictionary=unit.special.get("tesla_charge_up",{})
		var coil:MeshInstance3D=model.parts.FX_LIGHTNINGCHARGE
		if unit.veteran_level==3:
			var progress:=clampf(float(charge.get("age",0))/float(Ra3Expansion.tesla_balance.heroic_charge_seconds),0,1)
			coil.visible=not charge.is_empty() or unit._muzzle>0 or unit.special.get("soviet_mode",false)
			coil.material_override.set_shader_parameter("opacity",0.2+0.8*progress if not charge.is_empty() else 1.0)
		else:
			coil.visible=true
			coil.material_override.set_shader_parameter("opacity",1.0)
		var turn:=0.0 if is_nan(last_heading) else angle_difference(last_heading,unit.hull_angle)
		last_heading=unit.hull_angle
		var tread:="TREADSMOVE" if unit.velocity.length()>1.0 else "TREADSSTOP"
		if absf(turn)>0.002:tread="TREADSTURNRIGHT" if turn>0 else "TREADSTURNLEFT"
		for key in model.parts:
			if str(key).begins_with("TREADS"):model.parts[key].visible=key==tread
		_emp(model,dt)
		return
	var ages:Array=unit.special.get("barrel_age",[])
	for i in ages.size():
		var b:int=model.rig.find_bone("B_BARREL%02d"%(i+1))
		if b>=0:model.rig.set_bone_pose_position(b,model.rig.get_bone_pose_position(b)-Vector3.RIGHT*recoil(ages[i]))
	var t=unit.special.get("harpoon_target")
	if AlliedAbilities.alive(t) and unit.special.get("soviet_mode",false):
		var old=tractor.get_ref() if tractor!=null else null
		if old==null or old.is_queued_for_deletion() or old.target.get_ref()!=t:
			var beam=Beam.spawn(unit,t,true)
			if beam!=null:tractor=weakref(beam)
	if unit.special.get("soviet_mode",false) and model.actor.is_inside_tree() and DisplayServer.get_name()!="headless":
		emit_clock-=dt
		if emit_clock<=0:
			emit_clock=0.1
			FX.emit_entries(unit._battle_world(),model.bone_world("FX_HARPOON"),[FX.source_entry("Sov_Apoc_TB_Spark"),FX.source_entry("Sov_Apoc_TB_Glow")],unit.hull_angle)

func _emp(model,dt:float) -> void:
	var data:Dictionary=FX.bank.particles.SovietTesla_EMP
	ring_clock-=dt
	if model.actor.special.get("soviet_mode",false) and ring_clock<=0:
		ring_clock=maxf(1,P.range_value(P.child(data,"BurstDelay"),1))/30
		if ring_mesh==null:
			ring_source=JSON.parse_string(FileAccess.get_file_as_string(FX.ROOT_FX+"exlightningring.json"))
			ring_mesh=Mats.make_mesh(ring_source)
		var node:=MeshInstance3D.new();node.mesh=ring_mesh
		var mat:=Mats.create(ring_source.material,ring_source.textures,FX.ROOT_FX)
		node.material_override=mat;model.hull.add_child(node)
		var update:=P.child(data,"Update/RenderObject")
		rings.append({"node":node,"age":0.0,"life":P.range_value(P.child(data,"Lifetime")),"angle":P.range_value(P.child(update,"AngleZ")),"start":P.xyz(P.child(update,"StartSize")).abs(),"rate":P.xyz(P.child(update,"SizeRate")).abs(),"drag":P.xyz(P.child(update,"SizeDamping")).abs()})
	for i in range(rings.size()-1,-1,-1):
		var row:Dictionary=rings[i]
		row.age+=dt*30
		if row.age>=row.life:
			row.node.queue_free();rings.remove_at(i);continue
		var size_:Vector3=row.start
		for axis in 3:size_[axis]+=row.rate[axis]*P.integral(row.age,row.drag[axis])
		row.node.rotation.y=row.angle
		var training := Unit.Training.scale(model.actor)
		row.node.scale=(size_ * Vector3(training,1.0,training)).max(Vector3.ONE*0.001)
		row.node.material_override.set_shader_parameter("age",row.age/30.0)
		row.node.material_override.set_shader_parameter("opacity",1-row.age/row.life)

func _attachments(model,dt:float,object_id:String) -> void:
	var unit=model.actor
	var spec:Dictionary=FX.bank.mounts[object_id]
	var fraction:float=unit.hp/maxf(unit.max_hp,1)
	var thresholds:Dictionary=preload("res://scripts/units/ra3_damage_state.gd").rules.thresholds
	var damage:=2 if fraction<=float(thresholds.MaxHealthReallyDamagedPercentage) else (1 if fraction<=float(thresholds.MaxHealthDamagedPercentage) else 0)
	if hull_damage<0:
		for mat in model.materials:
			var texture:Texture2D=mat.get_shader_parameter("diffuse_map")
			if texture!=null and texture.resource_path.get_file().get_basename()==spec.skin.original:
				skins.append({"material":mat,"normal":texture,"damaged":load(FX.ROOT_FX+str(spec.skin.damaged)+".png")})
	if damage!=hull_damage:
		for skin in skins:skin.material.set_shader_parameter("diffuse_map",skin.damaged if damage==2 else skin.normal)
		hull_damage=damage
	var speed:float=unit.velocity.length()
	var moving:="ACCELERATE" if speed>previous_speed+0.1 and unit.unit_id=="R3APOC" else "MOVING"
	previous_speed=speed
	if dt<=0 or not unit.is_inside_tree():return
	var world=unit._battle_world()
	if world==null or world.effects_root.get_child_count()>=128:return
	var emitters:Array=spec.get(moving,[]).duplicate() if speed>1.0 else []
	var motion_count:=emitters.size()
	if damage>0:emitters.append_array(spec.get("REALLYDAMAGED" if damage==2 else "DAMAGED",[]))
	var clocks:Dictionary={}
	for i in emitters.size():
		var mount:Dictionary=emitters[i]
		var motion:=i<motion_count
		var key:String=mount.bone+mount.fx
		var left:float=attachment_clocks.get(key,0.0)-dt*30
		if left<=0:
			var point:Vector2
			if mount.bone=="FX_BONE01":
				var socket:=Ra3BoneAnimation.vector(FX.bank.apoc_damage_socket)
				point=unit.global_position+RA2Art.art_dir(model.draw_rect.position+model.project(model.hull.transform*socket))
			else:point=model.bone_world(str(mount.bone).to_upper())
			FX.emit_entries(world,point,[FX.source_entry(mount.fx)],unit.hull_angle,motion)
			left=maxf(1,P.range_value(P.child(FX.bank.particles[mount.fx],"BurstDelay"),1))
			# Sample the trail at 5 Hz per socket, keeping damage and weapon FX at their native cadence.
			if motion:left=maxf(left,6.0)
		clocks[key]=left
	attachment_clocks=clocks
