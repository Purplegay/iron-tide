extends RefCounted
## Iron Tide cosmetic attachments. All positions are local to the visual hull.
const SKINS := {"stock":"原版","winter":"雪地迷彩"}
const PAINT := {"stock":"原版","ice":"冰蓝"}
const TOP := {"stock":"无装饰","crystal":"冰晶棱柱","rangefinder":"折光测距仪","wind_crown":"三向测风冠"}
# SCYTHE bind-pose crown ridge, vertex 874, rigidly weighted to the upper shell.
const REAPER_SHELL := "bone_248153f1"
const REAPER_CROWN_SEAT := Vector3(1.400411,32.130043,0)
const WINGS := {"stock":"无挂件","angel":"天使翼","demon":"恶魔翼"}
const TAILS := {"stock":"无尾部挂件","phase_case":"相位余辉匣","slag_chains":"炉渣收集链"}
const EXCLUSIVE_MOUNTS := {"R3FUTURE":"phase_case","R3APOC":"slag_chains","R3MIRAGE":"rangefinder","R3REAPER":"wind_crown"}
const TRACKS := {"stock":"原版","chevron_track":"双脊箭纹"}
const MOUNT_SLOTS := ["top","wing","tail"]
const SHIFT_LIMIT := 25 # Percentage of the larger horizontal hull dimension.
const SIZE_MIN := 25
const SIZE_MAX := 200
const ADJUST_COST := 100
const PARTS := {
	"R3MIRAGE":{"B_CHASISANIM":"活动底盘","BONE_EAR_LEFT":"左侧展开臂","BONE_EAR_RIGHT":"右侧展开臂","FX_WEAPON":"棱镜炮口"},
	"R3FUTURE":{"B_Turret":"主炮塔","FX_WEAPON_01":"一号炮口","FX_WEAPON_02":"二号炮口","B_Fender01":"挡板"},
	"R3HARBINGER":{"Turret_FRONT":"前炮座","Turret_Pitch_FRONT":"前炮俯仰架","Turret_FR":"前侧炮座","Turret_BR":"后侧炮座"},
	"R3APOC":{"Turret":"主炮塔","Turret_Pitch":"俯仰架","B_BARREL01":"一号炮管","B_BARREL02":"二号炮管","FX_Harpoon":"鱼叉发射口"},
	"R3TESLA":{"Bone_Turret":"磁暴炮塔","FX_Weapon_01":"一号放电端","FX_Weapon_02":"二号放电端"},
	"R3REAPER":{"B_Turret_02":"前榴弹炮座","B_Turret_03":"侧榴弹炮座 1","B_Turret_04":"侧榴弹炮座 2","B_Turret_05":"火箭炮座","B_TurretPitch_05":"火箭俯仰架","FX_Foot01":"一号机足"}
}
const COLORS := {"ice":Color("#64bdd2")}

static func is_ra3(data:Dictionary) -> bool:
	return data.has("soviet_ra3") or str(data.get("id","")) in ["R3MIRAGE","R3FUTURE","R3HARBINGER"]

# UV2.x follows original weapon bones even when the gun and hull share a mesh/material.
static func weapon_mask(part:Dictionary,bones:Array) -> PackedVector2Array:
	var mask:=PackedVector2Array()
	var marked:=PackedByteArray()
	marked.resize(bones.size())
	for i in bones.size():
		var name:=str(bones[i].name).to_upper()
		var parent:=int(bones[i].parent)
		marked[i]=int("TURRET" in name or "BARREL" in name or "B_SECONDARY" in name or "BONE_EAR" in name or (parent>=0 and marked[parent]!=0))
	var whole:bool="TURRET" in str(part.name).to_upper() or "SKINGUN" in str(part.name).to_upper()
	for i in range(0,part.bones.size(),4):
		var weight:=0.0
		for j in 4:
			var bone:=int(part.bones[i+j])
			if bone>=0 and bone<marked.size() and marked[bone]!=0:weight+=float(part.weights[i+j])
		mask.append(Vector2(1.0 if whole else clampf(weight,0,1),0))
	return mask

static func _mount(socket:Node3D,model,slot:String,edit_slot:String,native_part:="") -> Node3D:
	var anchor := preload("res://scripts/units/cosmetic_anchor.gd").new()
	anchor.name = slot
	socket.add_child(anchor)
	if slot=="tail":
		var bounds: AABB = model.hull_bounds
		var rear := Vector3(bounds.position.x,bounds.get_center().y,bounds.get_center().z)
		anchor.position = (rear-socket.position)/socket.scale.x
	elif native_part==REAPER_SHELL:
		anchor.position=socket.transform.affine_inverse()*REAPER_CROWN_SEAT
	anchor.default_origin=anchor.position
	anchor.rig=model.cosmetic_skeleton()
	anchor.native_part=native_part
	var id:String=model.actor.unit_id
	var pose:=MetaProgress.attachment_pose(id,slot)
	var angles:=MetaProgress.attachment_rotation(id,slot)
	anchor.configure(pose.part,pose.pitch,MetaProgress.attachment_position(id,slot),MetaProgress.attachment_scale(id,slot),Vector2i(angles.x,angles.y))
	if slot==edit_slot:
		var marker := MeshInstance3D.new()
		marker.name = "AdjustMarker"
		var sphere := SphereMesh.new()
		sphere.radius = 0.025
		sphere.height = 0.05
		sphere.radial_segments = 8
		sphere.rings = 4
		marker.mesh = sphere
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.no_depth_test = true
		ink.albedo_color = Color("#ffc963")
		marker.material_override = ink
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(marker)
	return anchor

static func install(model, style:Dictionary, edit_slot := "") -> void:
	if model.actor.unit_id=="R3FUTURE":model.frame_phase_exhaust(style.get("tail","stock")=="phase_case")
	var previous=model.hull.get_node_or_null("CosmeticMount")
	if style.is_empty() and edit_slot.is_empty() and previous==null:return
	if previous!=null:previous.free()
	for child in model.hull.get_children():
		if not child is MeshInstance3D:continue
		var mat=child.material_override
		if not mat is ShaderMaterial or mat.shader!=model.OBJECT_SHADER:continue
		var dye: Color = COLORS.get(style.get("paint","stock"), Color.TRANSPARENT)
		mat.set_shader_parameter("custom_body", dye)
		mat.set_shader_parameter("custom_weapon", dye)
	if style.is_empty() and edit_slot.is_empty():return
	var bounds:AABB=model.hull_bounds
	if bounds.size==Vector3.ZERO:return
	var socket:=Node3D.new()
	socket.name="CosmeticMount"
	model.hull.add_child(socket)
	var span:=maxf(1.0,maxf(bounds.size.x,bounds.size.z))
	socket.position=bounds.get_center()+Vector3(-bounds.size.x*0.12,bounds.size.y*0.48,0)
	socket.scale=Vector3.ONE*span
	var top:String=style.get("top","stock")
	var crystal_mount: Node3D
	if top!="stock" or edit_slot=="top":
		var native_part:String={"rangefinder":"B_CHASISANIM","wind_crown":REAPER_SHELL}.get(top,"")
		crystal_mount=_mount(socket,model,"top",edit_slot,native_part)
	if top == "crystal":
		var sides := 5
		var ring:=PackedVector3Array()
		for i in sides:
			var angle:=TAU*i/sides
			ring.append(Vector3(cos(angle)*0.055,0.075,sin(angle)*0.055))
		var jewel := Color("#8af5ff")
		var top_tip:=Vector3(0,0.19,0)
		var bottom_tip:=Vector3(0,0.018,0)
		_fan(crystal_mount,ring,top_tip,jewel)
		_fan(crystal_mount,ring,bottom_tip,jewel.darkened(0.35))
		var sparkles := MeshInstance3D.new()
		sparkles.name = "CrystalSparkles"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.48,0.48)
		var shimmer := ShaderMaterial.new()
		shimmer.shader = preload("res://shaders/crystal_sparkles.gdshader")
		# Project the same facet vertices as the solid crystal into the sparkle quad.
		var glow_origin:=Vector3(0,0.17,0)
		var outline:=PackedVector3Array()
		for point in ring: outline.append((point-glow_origin)/quad.size.x)
		shimmer.set_shader_parameter("rim",outline)
		shimmer.set_shader_parameter("tip",(top_tip-glow_origin)/quad.size.x)
		shimmer.set_shader_parameter("base",(bottom_tip-glow_origin)/quad.size.x)
		shimmer.set_shader_parameter("phase", float(model.get_instance_id() % 101) * 0.1)
		sparkles.mesh = quad
		sparkles.material_override = shimmer
		sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparkles.position = glow_origin
		sparkles.extra_cull_margin = 0.24
		crystal_mount.add_child(sparkles)
	var tail:String=style.get("tail","stock")
	var tail_mount:Node3D
	if tail!="stock" or edit_slot=="tail": tail_mount=_mount(socket,model,"tail",edit_slot)
	var signature:String=EXCLUSIVE_MOUNTS.get(model.actor.unit_id,"")
	if not signature.is_empty() and signature in [top,tail]:
		var display:=preload("res://scripts/units/signature_mount.gd").new()
		var mount:=crystal_mount if signature==top else tail_mount
		mount.add_child(display)
		display.build(model,signature,style.get("paint","stock")=="ice")
	var wing:String=style.get("wing","stock")
	var wing_mount: Node3D
	if wing in ["angel","demon"] or edit_slot=="wing": wing_mount=_mount(socket,model,"wing",edit_slot)
	if wing not in ["angel","demon"]:return
	for sign_z in [-1.0,1.0]:
		var pivot:=Node3D.new()
		wing_mount.add_child(pivot)
		pivot.position=Vector3(-0.02,0.05,0.12*sign_z)
		var outline:=PackedVector2Array([Vector2(0,0),Vector2(0.13,0.22),Vector2(0.30,0.34),Vector2(0.42,0.39),Vector2(0.35,0.24),Vector2(0.44,0.26),Vector2(0.33,0.14),Vector2(0.39,0.14),Vector2(0.24,0.05),Vector2(0.29,0.04),Vector2(0.14,0)])
		if wing=="demon":
			outline=PackedVector2Array([Vector2(0,0),Vector2(0.1,0.20),Vector2(0.22,0.32),Vector2(0.25,0.26),Vector2(0.47,0.13),Vector2(0.36,0.12),Vector2(0.31,0.02),Vector2(0.23,0.09),Vector2(0.17,-0.02),Vector2(0.10,0.05)])
		var vertices:=PackedVector3Array()
		for pt in outline: vertices.append(Vector3(-pt.x*0.35,pt.y,pt.x*sign_z))
		var color:=Color("#e4eefb") if wing=="angel" else Color("#af354c")
		_fan(pivot,vertices,Vector3(0.014,0.11,0.14*sign_z),color)
		var tween:=pivot.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tween.tween_property(pivot,"rotation:x",0.16*sign_z,0.85)
		tween.tween_property(pivot,"rotation:x",-0.08*sign_z,0.85)

static func _fan(parent:Node3D,points:PackedVector3Array,center:Vector3,color:Color) -> void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		surface.set_color(color.lightened(0.15))
		surface.add_vertex(center)
		surface.set_color(color.darkened(0.12 if i%2==0 else 0.26))
		surface.add_vertex(points[i])
		surface.add_vertex(points[(i+1)%points.size()])
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=material
	parent.add_child(mesh)
