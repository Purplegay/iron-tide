extends Node3D
## Four workshop ornaments, sized in fractions of the model's horizontal span.
const STEEL := Color("#62798a")
const DARK := Color("#233343")
const BRASS := Color("#c98c48")
const CYAN := Color("#72faff")
const HEAT := Color("#ff6436")
const METAL := preload("res://shaders/signature_metal.gdshader")

var host
var style:String
const DragChain=preload("res://scripts/units/slag_drag_chain.gd")
var chains:Array[DragChain]=[]
var chain_span:=1.0
var preview_travel:=Vector2.ZERO
var lamps:Array[MeshInstance3D]=[]
var light_level:=0.0
var plume_heading:=0.0
var plume_bend:=0.0
var last_signal:=-2
var clock:=0.0

func build(model, id:String, ice_paint:=false) -> void:
	host=model.actor
	style=id
	chain_span=maxf(model.hull_bounds.size.x,model.hull_bounds.size.z)
	match style:
		"phase_case": _case()
		"slag_chains": _chains()
		"rangefinder": _optics(ice_paint)
		"wind_crown": _crown()
	set_process(true)
	_process(0.0)

func _piece(parent:Node3D,shape:Mesh,at:Vector3,tint:Color,lit:=false) -> MeshInstance3D:
	var item:=MeshInstance3D.new()
	var material:=ShaderMaterial.new()
	material.shader=METAL
	material.set_shader_parameter("enamel",tint)
	material.set_shader_parameter("lamp",float(lit))
	item.material_override=material
	item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.mesh=shape
	item.position=at
	parent.add_child(item)
	return item

func _box(parent:Node3D,at:Vector3,dimensions:Vector3,tint:Color) -> MeshInstance3D:
	var box:=BoxMesh.new()
	box.size=dimensions
	return _piece(parent,box,at,tint)

func _drum(parent:Node3D,at:Vector3,radius:float,height:float,tint:Color,lit:=false) -> MeshInstance3D:
	var drum:=CylinderMesh.new()
	drum.top_radius=radius
	drum.bottom_radius=radius
	drum.height=height
	drum.radial_segments=8
	drum.rings=0
	return _piece(parent,drum,at,tint,lit)

const PHASE_HOUSING:=preload("res://assets/cosmetics/mounts/future_phase_housing.png")
const PHASE_PLUME:=preload("res://assets/cosmetics/mounts/future_phase_exhaust.png")

func _case() -> void:
	plume_heading=host.hull_angle
	position=Vector3(0.09,-0.045,0)
	scale=Vector3.ONE*0.85
	_box(self,Vector3(0.03,-0.025,0),Vector3(0.13,0.11,0.18),STEEL)
	var armor:=ShaderMaterial.new()
	armor.shader=preload("res://shaders/future_phase_housing.gdshader")
	armor.set_shader_parameter("panels",PHASE_HOUSING)
	var casing:=_box(self,Vector3(0.02,0.03,0),Vector3(0.12,0.085,0.30),DARK)
	casing.material_override=armor
	var exit_material:ShaderMaterial=armor.duplicate()
	exit_material.set_shader_parameter("nozzle",true)
	for side in [-1,1]:
		var z:=0.095*float(side)
		var nozzle:=_drum(self,Vector3(-0.050,0.03,z),0.060,0.108,STEEL)
		nozzle.rotation.z=PI/2
		nozzle.material_override=exit_material
		var lip:=TorusMesh.new()
		lip.inner_radius=0.058
		lip.outer_radius=0.064
		lip.rings=20
		lip.ring_segments=5
		_piece(nozzle,lip,Vector3(0,0.048,0),Color("#94a0b2"))
		var jet:=MeshInstance3D.new()
		var material:=ShaderMaterial.new()
		material.shader=preload("res://shaders/future_phase_exhaust.gdshader")
		material.set_shader_parameter("plume",PHASE_PLUME)
		var ribbon:=QuadMesh.new()
		ribbon.subdivide_width=10
		jet.mesh=ribbon
		jet.material_override=material
		jet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jet.position=Vector3(-0.104,0.03,z)
		jet.custom_aabb=AABB(Vector3(-0.83,-0.11,-0.52),Vector3(0.95,0.22,1.04))
		add_child(jet)
		lamps.append(jet)

const SLAG_ATLAS:=preload("res://assets/cosmetics/mounts/apoc_slag_iron.png")
enum IronPart { BRACKET, LINK, PIN, WEIGHT }
static var iron_surfaces:Array[ShaderMaterial]=[]
static var hot_weight:ShaderMaterial

func _chains() -> void:
	if iron_surfaces.is_empty():
		for part in IronPart.values():
			var metal:=ShaderMaterial.new()
			metal.shader=preload("res://shaders/apoc_slag_iron.gdshader")
			metal.set_shader_parameter("forged",SLAG_ATLAS)
			metal.set_shader_parameter("part",part)
			metal.set_shader_parameter("heat",0.0)
			iron_surfaces.append(metal)
		hot_weight=iron_surfaces[IronPart.WEIGHT].duplicate()
		hot_weight.set_shader_parameter("heat",1.0)
	for side in [-1,1]:
		var root:=Node3D.new()
		add_child(root)
		root.position=Vector3(0.076,0.012,0.24*float(side))
		var bracket:=_box(root,Vector3(0.033,0.008,0),Vector3(0.14,0.034,0.058),STEEL)
		bracket.material_override=iron_surfaces[IronPart.BRACKET]
		var pin:=_drum(root,Vector3(-0.012,0.02,0),0.025,0.026,STEEL)
		pin.material_override=iron_surfaces[IronPart.PIN]
		var chain:=DragChain.new()
		chain.root=root
		chains.append(chain)
		var loop:=TorusMesh.new()
		loop.inner_radius=0.012
		loop.outer_radius=0.025
		loop.rings=10
		loop.ring_segments=5
		for i in DragChain.LINKS:
			var link:=MeshInstance3D.new()
			link.mesh=loop
			link.material_override=iron_surfaces[IronPart.LINK]
			link.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(link)
			chain.rings.append(link)
		chain.shoe=_drum(root,Vector3.ZERO,0.041,0.063,DARK)
		chain.shoe.material_override=iron_surfaces[IronPart.WEIGHT]

func _drag_chains(delta:float) -> void:
	# The 3D model turns inside its private viewport. Restore the 2D map translation
	# so moving the vehicle pulls the pin instead of carrying all the links with it.
	var travel:Vector2=host.global_position
	if host.has_method("cosmetic_preview_travel"):
		preview_travel+=host.cosmetic_preview_travel(delta)
		travel=preview_travel
	var from_view:=Basis(Vector3.UP,-Iso.eff_angle()).scaled(Vector3.ONE/chain_span)
	var model_to_map:=Transform3D(from_view,Vector3(travel.x,0,travel.y)/(1.5*chain_span))
	var rear:=Vector3(-cos(host.hull_angle),0,-sin(host.hull_angle))
	for chain in chains:
		chain.set_dimensions(get_parent().dimensions)
		var root_to_map:=model_to_map*chain.root.global_transform
		chain.advance(delta,root_to_map.origin,rear)
		chain.pose(root_to_map.affine_inverse())

const OPTIC_ATLAS:=preload("res://assets/cosmetics/mounts/mirage_rangefinder.png")
static var optic_shell:CylinderMesh
var optic_finish:ShaderMaterial
var optic_cheeks:Array[ShaderMaterial]=[]
var scan_wait:=0.0

func _optics(ice:bool) -> void:
	if optic_shell==null:
		optic_shell=CylinderMesh.new()
		optic_shell.top_radius=0.056
		optic_shell.bottom_radius=0.072
		optic_shell.height=0.188
		optic_shell.radial_segments=16
		optic_shell.rings=0
	# Both lenses share this tank's contact signal, independently of other tanks.
	optic_finish=ShaderMaterial.new()
	optic_finish.shader=preload("res://shaders/mirage_rangefinder.gdshader")
	optic_finish.set_shader_parameter("atlas",OPTIC_ATLAS)
	optic_finish.set_shader_parameter("ice",float(ice))
	var shell_color:=Color("#88c5d6") if ice else Color("#a1b3c1")
	scale=Vector3.ONE*0.76
	_drum(self,Vector3(0,0.003,0),0.098,0.032,STEEL)
	_drum(self,Vector3(0,0.021,0),0.083,0.022,shell_color)
	_box(self,Vector3(-0.016,0.034,0),Vector3(0.094,0.036,0.268),shell_color)
	for side in [-1,1]:
		var z:=0.107*float(side)
		var shoe:=_box(self,Vector3(-0.012,0.048,z),Vector3(0.132,0.046,0.072),STEEL)
		shoe.rotation.z=-0.10
		# Inset IFF flash repeats the small house-colour panels on the turret cheeks.
		var cheek:=_box(self,Vector3(-0.015,0.056,z+0.045*float(side)),Vector3(0.083,0.015,0.011),host._col)
		cheek.rotation.z=-0.10
		optic_cheeks.append(cheek.material_override)
		var pod:=MeshInstance3D.new()
		pod.name="OpticLeft" if side<0 else "OpticRight"
		pod.mesh=optic_shell
		pod.material_override=optic_finish
		pod.position=Vector3(0.008,0.076,z)
		pod.rotation.z=-PI/2+0.065
		pod.scale=Vector3(0.75,1.0,1.0)
		pod.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pod)
	sync_house_color()

func sync_house_color() -> void:
	if optic_finish==null or not is_instance_valid(host):return
	optic_finish.set_shader_parameter("house_color",host._col)
	for material in optic_cheeks:
		material.set_shader_parameter("enamel",host._col)

const CROWN_ATLAS:=preload("res://assets/cosmetics/mounts/reaper_wind_crown.png")
const ReaperPose=preload("res://scripts/units/ra3_reaper_pose.gd")
var crown_vanes:Array[MeshInstance3D]=[]
var contact_mask:=0
static var crown_lit:ShaderMaterial
static var crown_plate:ShaderMaterial
static var crown_bearing:ShaderMaterial
static var crown_fin:ArrayMesh

# UVs on each broad face span the enamel tile, with a separate steel lip around the edge.
static func _build_crown_art() -> void:
	if crown_fin!=null:return
	crown_plate=ShaderMaterial.new()
	crown_plate.shader=preload("res://shaders/reaper_sensor.gdshader")
	crown_plate.set_shader_parameter("plates",CROWN_ATLAS)
	crown_lit=crown_plate.duplicate()
	crown_lit.set_shader_parameter("signal_on",true)
	crown_bearing=crown_plate.duplicate()
	crown_bearing.set_shader_parameter("bearing",true)
	var outline:=PackedVector2Array([Vector2(0,0),Vector2(0.096,0),Vector2(0.15,0.064),Vector2(0.142,0.098),Vector2(0.088,0.085),Vector2(0.020,0.037)])
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width:=0.011
	for direction:float in [-1.0,1.0]:
		for i in range(1,outline.size()-1):
			for index:int in ([0,i,i+1] if direction<0 else [0,i+1,i]):
				var p:=outline[index]
				mesh.set_normal(Vector3(0,0,direction))
				mesh.set_uv(Vector2(0.008+0.48*p.x/0.15,0.488-0.48*p.y/0.098))
				mesh.add_vertex(Vector3(p.x,p.y,half_width*direction))
	for i in outline.size():
		var a:=outline[i]
		var b:=outline[(i+1)%outline.size()]
		var edge:=b-a
		var normal:=Vector3(edge.y,-edge.x,0).normalized()
		for corner:int in [0,1,2,2,1,3]:
			var p:=a if corner<2 else b
			mesh.set_normal(normal)
			mesh.set_uv(Vector2(0.515 if corner<2 else 0.985,0.72 if corner%2==0 else 0.93))
			mesh.add_vertex(Vector3(p.x,p.y,half_width if corner%2==0 else -half_width))
	crown_fin=mesh.commit()

func _crown() -> void:
	# A recessed collar seats the plinth on the curved armor around the ridge.
	_drum(self,Vector3(0,-0.021,0),0.074,0.052,STEEL)
	_build_crown_art()
	var cap:=CylinderMesh.new()
	cap.top_radius=0.087
	cap.bottom_radius=0.092
	cap.height=0.045
	cap.radial_segments=24
	cap.rings=0
	var hub:=MeshInstance3D.new()
	hub.name="SensorBearing"
	hub.mesh=cap
	hub.material_override=crown_bearing
	hub.position.y=0.021
	hub.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hub)
	for i in 3:
		var spoke:=Node3D.new()
		add_child(spoke)
		var mount:Dictionary=preload("res://scripts/units/ra3_reaper_pose.gd").definitions.grenade_mounts[i]
		spoke.rotation.y=deg_to_rad(float(mount.angle))
		var fin:=MeshInstance3D.new()
		fin.name="SensorVane"
		fin.mesh=crown_fin
		fin.material_override=crown_plate
		fin.position=Vector3(0.052,0.024,0)
		fin.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spoke.add_child(fin)
		crown_vanes.append(fin)
		var bezel:=_box(spoke,Vector3(0.171,0.117,0),Vector3(0.052,0.008,0.026),STEEL)
		bezel.rotation.z=0.23
		var slit:=_box(spoke,Vector3(0.171,0.122,0),Vector3(0.041,0.005,0.021),DARK)
		slit.rotation.z=0.23
		lamps.append(slit)

func _crown_contacts(world) -> int:
	var mask:=0
	var reach:float=ReaperPose.definitions.rounds.grenade.max_range*1.5
	var mounts:Array=ReaperPose.definitions.grenade_mounts
	for enemy in host.get_tree().get_nodes_in_group("enemies"):
		if not world.actor_alive(enemy) or (enemy is Unit and enemy.is_air_target()): continue
		var offset:Vector2=enemy.global_position-host.global_position
		if offset.length_squared()>reach*reach:
			if not enemy is Building: continue
			if offset.length_squared()>pow(reach+enemy.footprint_radius(),2): continue
			offset=enemy.closest_footprint_point(host.global_position)-host.global_position
			if offset.length_squared()>reach*reach: continue
		if not world.actor_visible_to(host.side,enemy,host): continue
		for i in mounts.size():
			if not (mask & (1<<i)) and host.ReaperSplit.covers_ground_offset(host,offset,mounts[i]):
				mask|=1<<i
		if mask==7: break
	return mask

func _rangefinder_contact() -> bool:
	var world = host._battle_world()
	if world == null: return false
	for enemy in host.get_tree().get_nodes_in_group("enemies"):
		if enemy.side != "enemy" or not world.actor_alive(enemy): continue
		if CommandoCombat.distance_to(host,enemy) <= host.attack_range and world.actor_visible_to(host.side,enemy,host):
			return true
	return false

func _refresh_rangefinder(delta:float) -> void:
	var signal_on:=false
	if host.side=="ally" and not host._dead and host.embarked_in==null:
		scan_wait-=delta
		if scan_wait>0: return
		scan_wait=0.2
		signal_on=_rangefinder_contact()
	if int(signal_on)!=last_signal:
		last_signal=int(signal_on)
		optic_finish.set_shader_parameter("contact",float(signal_on))

func _process(delta:float) -> void:
	if not is_instance_valid(host) or not host.is_visible_in_tree():return
	match style:
		"rangefinder":
			_refresh_rangefinder(delta)
		"phase_case":
			clock=fmod(clock+delta,TAU)
			var moving:bool=host.velocity.length_squared()>1
			# Tight corners brake translation while the tracks still drive the hull around.
			var pivot:bool=host._drive_turning and (host.has_move_order or is_instance_valid(host.attack_target))
			var thrusting:=moving or pivot
			if delta>0:
				# The exhaust already emitted retains its previous direction briefly.
				# Integrate angular speed over the frame, including the -PI/PI seam.
				var decay:=exp(-2.2*delta)
				var turn:=angle_difference(plume_heading,host.hull_angle) if pivot or (moving and light_level>0) else 0.0
				plume_bend=clampf(plume_bend*decay+1.25*turn*(1.0-decay)/(2.2*delta),-1.35,1.35)
			plume_heading=host.hull_angle
			light_level=move_toward(light_level,1.0 if thrusting else 0.0,delta*(6.0 if pivot else 2.6))
			if light_level==0:plume_bend=0.0
			for i in lamps.size():
				var power:=clampf(light_level*1.55-i*0.55,0,1)
				lamps[i].visible=power>0.001
				if lamps[i].visible:
					lamps[i].material_override.set_shader_parameter("bend",plume_bend)
					lamps[i].material_override.set_shader_parameter("thrust",power)
					lamps[i].material_override.set_shader_parameter("phase",clock+i*1.71)
		"slag_chains":
			if delta>0 and not host.get_viewport_rect().grow(220).has_point(host.get_global_transform_with_canvas().origin):return
			_drag_chains(delta)
			var grinding:bool=is_instance_valid(host.special.get("harpoon_target")) and float(host.special.get("crush_contact",0))>0
			if int(grinding)!=last_signal:
				last_signal=int(grinding)
				for chain in chains:chain.shoe.material_override=hot_weight if grinding else iron_surfaces[IronPart.WEIGHT]
		"wind_crown":
			var assigned:int=host.special.get("split_side_index",-1) if is_instance_valid(host.special.get("split_enemy")) else -1
			var owner_view:bool=host.side=="ally" and not host._dead and host.embarked_in==null
			if owner_view:
				scan_wait-=delta
				if scan_wait<=0:
					scan_wait=0.2
					var world=host._battle_world()
					contact_mask=_crown_contacts(world) if world!=null else 0
			else:
				contact_mask=0
				assigned=-1
			var lit_mask:=contact_mask
			if assigned>=0 and assigned<3: lit_mask|=1<<assigned
			if lit_mask==last_signal:return
			last_signal=lit_mask
			for i in lamps.size():
				var lit:bool=(lit_mask & (1<<i))!=0
				crown_vanes[i].material_override=crown_lit if lit else crown_plate
				lamps[i].material_override.set_shader_parameter("enamel",HEAT if lit else DARK)
				lamps[i].material_override.set_shader_parameter("lamp",float(lit))
