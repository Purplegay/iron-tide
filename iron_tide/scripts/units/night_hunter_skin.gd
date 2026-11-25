extends RefCounted
## Direct 32-facing sprites. One authored direction/pose is visible at a time.
const SKINS := {"SCHP":"obsidian_night_owl", "DRON":"rift_hunter"}
static var resources:Dictionary = {}
static var metadata:Dictionary = {}
static var bounds_cache:Dictionary = {}
static var drone_scale:=0.0
static var helicopter_scale:=0.0
const MOTION_TILE:=Vector2(128,128)
const GUN_TILE:=Vector2(192,192)
const GUN_KEY:="night_owl_mesh_gun"
const DRONE_SIZE_RATIO:=1.4
const DRONE_WALK_STRIDE:=40.0
const DRONE_MAX_GAIT_HZ:=3.0
var id:String
var clock:=0.0
var rotor:=0.0
var fold:=0.0
var original_filter:int
var surface:ShaderMaterial
var body_rect:=Rect2()
var body_source:=Rect2()
var body_key:=""
var gun_source:=Rect2()
var gun_rect:=Rect2()
var has_gun:=false
var previous_walk:=0.0
var previous_fold:=0.0
var previous_rotor:=0.0
var previous_clock:=0.0
var body_regions:Array[Rect2]=[]
var gait_phase:=0.0
var was_moving:=false
var last_position:=Vector2.INF
var exhaust=preload("res://scripts/units/night_owl_exhaust.gd").new()

static func configure(actor,house_color:Color) -> void:
	var value:String=actor.cosmetic_outfit().get("skin","")
	if actor.side!="ally" or not SKINS.has(actor.unit_id) or SKINS[actor.unit_id]!=value:
		if actor.night_skin!=null:actor.texture_filter=actor.night_skin.original_filter
		actor.night_skin=null
		var driver=actor.get_node_or_null("NightSkinClock")
		if driver!=null:
			actor.remove_child(driver)
			driver.queue_free()
		return
	if actor.night_skin==null:
		actor.night_skin=load("res://scripts/units/night_hunter_skin.gd").new()
		actor.night_skin.id=actor.unit_id
		actor.night_skin.original_filter=actor.texture_filter
		actor.night_skin.fold=float(actor.is_deployed())
		actor.night_skin.surface=ShaderMaterial.new()
		actor.night_skin.surface.shader=preload("res://shaders/night_hunter.gdshader")
		var driver=preload("res://scripts/units/night_hunter_clock.gd").new()
		driver.name="NightSkinClock"
		actor.add_child(driver)
	actor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	actor.material=actor.night_skin.surface
	actor.material.set_shader_parameter("house_color",house_color)
	actor.material.set_shader_parameter("drone",actor.unit_id=="DRON")
	actor.material.set_shader_parameter("ice_paint",actor.cosmetic_outfit().get("paint")=="ice")
	actor.material.set_shader_parameter("body_texel",Vector2.ONE/Vector2(asset(actor.night_skin.key()).tex.get_size()))
	if actor.unit_id=="SCHP":
		actor.material.set_shader_parameter("gun_texel",Vector2.ONE/Vector2(asset(GUN_KEY).tex.get_size()))
		var uv:Array=actor.night_skin.model().get("exhaust_uv",[0,0,1,1])
		actor.material.set_shader_parameter("exhaust_uv",Vector4(uv[0],uv[1],uv[2],uv[3]))

static func asset(key:String) -> Dictionary:
	if not resources.has(key):
		var extension:=".webp" if key.ends_with("_direct32") else ".png"
		var tex:Texture2D=load("res://assets/cosmetics/night_hunters/"+key+extension)
		resources[key]={"tex":tex}
	return resources[key]

static func pixels(key:String) -> Image:
	var resource:=asset(key)
	if not resource.has("image"):
		var image:Image=resource.tex.get_image()
		if image.is_compressed():image.decompress()
		resource.image=image
	return resource.image

func key() -> String:
	return "night_owl_mesh32" if id=="SCHP" else "rift_hunter_mesh32"

func model() -> Dictionary:
	if not metadata.has(key()):
		metadata[key()]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetics/night_hunters/"+key()+".json"))
	return metadata[key()]

func frame_width(frame:int) -> float:
	var data:=model()
	var bounds:Array=data.bounds[frame]
	var left:=float(bounds[0])
	var right:=left+float(bounds[2])
	if id=="SCHP":
		var radius:float=data.rotor_radius_pixels
		left=minf(left,float(data.rotor_centers[frame][0])-radius)
		right=maxf(right,float(data.rotor_centers[frame][0])+radius)
	return right-left

func intensity(offset:=0.0) -> float:
	return 0.25+0.75*(0.5-0.5*cos((clock+offset)*TAU/3.2))

func tick(actor,dt:float) -> void:
	if actor._dead or actor.embarked_in!=null:return
	var before:=floori(clock*30.0)
	previous_walk=gait_phase
	var travel:Vector2=actor.global_position-last_position if last_position.is_finite() else Vector2.ZERO
	if actor.has_method("cosmetic_preview_travel"):travel=actor.cosmetic_preview_travel(dt)
	last_position=actor.global_position
	var distance:=travel.length()
	was_moving=distance>.01 and distance<maxf(64.0,actor.move_speed*dt*3.0)
	if was_moving:
		var advance:=minf(distance/DRONE_WALK_STRIDE,maxf(dt,0.0)*DRONE_MAX_GAIT_HZ) if id=="DRON" else distance/Unit.WALK_STRIDE
		gait_phase=fposmod(gait_phase+advance,1.0)
	previous_fold=fold
	previous_rotor=rotor
	previous_clock=clock
	clock=fposmod(clock+maxf(dt,0),960.0)
	surface.set_shader_parameter("breath",intensity())
	surface.set_shader_parameter("lamps_online",not actor.powered_unit.offline)
	if id=="SCHP":
		fold=float(actor.special.get("siege_progress",float(actor.is_deployed())))
		rotor=fposmod(rotor+dt*24.0*(1.0-fold),TAU)
		surface.set_shader_parameter("exhaust_phase",clock)
	if before!=floori(clock*30.0) and actor.is_visible_in_tree():actor.queue_redraw()

func hover_lift(actor,preview:=false) -> float:
	if id!="SCHP" or actor._dead or actor.embarked_in!=null or actor.powered_unit.offline:return 0.0
	var deployment:float=actor.special.get("siege_progress",float(actor.is_deployed()))
	var airborne:=1.0 if preview else smoothstep(.55,1.0,actor.logistics.air_lift)
	var strength:=airborne*(1.0-smoothstep(0.0,.75,deployment))
	if strength<=0.0:return 0.0
	var fraction:float=actor.motion_pose.fraction(actor) if actor.is_physics_processing() else 1.0
	var time:=previous_clock+fposmod(clock-previous_clock,960.0)*fraction
	var phase:=TAU*float(posmod(actor._seed,997))/997.0
	var moving:=clampf(actor.velocity.length()/maxf(actor.move_speed,1.0),0.0,1.0)
	return sin(time*TAU/3.2+phase)*lerpf(1.8,.7,moving)*strength

func visual_scale(actor) -> float:
	if (helicopter_scale if id=="SCHP" else drone_scale)<=0:
		var native_width:=0.0
		var custom_width:=0.0
		var native:=RA2Art.art("SCHP" if id=="SCHP" else "DRON")
		var first:=0 if id=="SCHP" else 48
		for i in 8:
			var native_frame:=i*int(native.get("facings",8))/8 if id=="SCHP" else first+i
			var native_source:=RA2Art.src_rect(native,native_frame)
			var native_rect:=RA2Art.draw_rect(native,actor.radius,range(first,first+8))
			native_width+=RA2Art.visible_sprite_rect(native,native_rect,native_source).size.x
			custom_width+=frame_width(i*4)
		if id=="SCHP":helicopter_scale=native_width/maxf(custom_width,1)
		else:drone_scale=native_width*DRONE_SIZE_RATIO/maxf(custom_width,1)
	return helicopter_scale if id=="SCHP" else drone_scale

func motion_source(frame:int,pose:int) -> Rect2:
	var tile:=Vector2.ONE*float(model().get("texture_tile",128))
	return Rect2(Vector2(frame%8,pose*4+frame/8)*tile,tile)

func view_bounds(actor) -> Rect2:
	var factor:=visual_scale(actor)
	var result:=Rect2()
	for anchor:Array in model().get("pose_anchors",model().anchors):
		var frame_rect:=Rect2(-Vector2(anchor[0],anchor[1])*factor,MOTION_TILE*factor)
		result=frame_rect if not result.has_area() else result.merge(frame_rect)
	return result

func pose_index(deployment:float,walk:float) -> int:
	if id=="SCHP":return clampi(roundi(deployment*4),0,4)
	return 1+posmod(floori(walk*8.0),8) if was_moving else 0

func draw_on(actor) -> void:
	if actor._dead or actor.embarked_in!=null:return
	var lift:float=actor._visual_lift()
	if id=="DRON":lift+=preload("res://scripts/units/dog_pounce.gd").lift(actor)
	var factor:=visual_scale(actor)
	var fraction:float=actor.motion_pose.fraction(actor) if actor.is_physics_processing() else 1.0
	var visual_fold:=lerpf(previous_fold,fold,fraction)
	var walk:=fposmod(previous_walk+wrapf(gait_phase-previous_walk,-.5,.5)*fraction,1.0)
	var direction:=fposmod((actor.hull_angle-Iso.eff_angle())/TAU*32.0,32.0)
	var frame:=posmod(roundi(direction),32)
	var pose:=pose_index(visual_fold,walk)
	if id=="DRON" and actor.special.has("pounce"):
		var jump:Dictionary=actor.special.pounce
		var progress:=float(jump.elapsed)/maxf(.001,float(jump.duration))
		pose=10 if progress>=.25 and progress<=.75 else 9
	body_regions=[motion_source(frame,pose)]
	body_source=body_regions[0]
	var anchor:Array=model().pose_anchors[pose*32+frame] if model().has("pose_anchors") else model().anchors[frame]
	body_rect=Rect2(-Vector2(anchor[0],anchor[1])*factor,MOTION_TILE*factor)
	body_rect.position.y-=lift
	body_key=key()
	var alpha:float=Ra3Mirage.CloakVisual.opacity(actor)
	var tint:=Color(1,1,1,alpha)
	if actor.powered_unit.offline:tint=tint.darkened(.45)
	Iso.shadow(actor,Vector2(actor.radius*.2,actor.radius*.3),actor.radius*1.3,.3*alpha)
	has_gun=id=="SCHP" and visual_fold>0.05
	if has_gun:
		var gun_frame:=posmod(roundi((actor.turret_angle-Iso.eff_angle())/TAU*32.0),32)
		gun_source=Rect2(Vector2(gun_frame%8,gun_frame/8)*GUN_TILE,GUN_TILE)
		var extension:=smoothstep(0.05,1.0,visual_fold)
		gun_rect=Rect2(Vector2(-64,-94)*factor-Vector2(0,lift),MOTION_TILE*factor)
		gun_rect.position-=Iso.dir(Vector2.from_angle(actor.turret_angle))*(1-extension)*24*factor
		actor.draw_texture_rect_region(asset(GUN_KEY).tex,gun_rect,gun_source,Color(tint,alpha*extension))
		preload("res://scripts/ui/unit_selection_outline.gd").capture(actor,asset(GUN_KEY).tex,gun_rect,gun_source,alpha*extension)
	if id=="SCHP":exhaust.draw(actor,self,frame,visual_fold,tint,factor)
	else:actor.draw_texture_rect_region(asset(body_key).tex,body_rect,body_source,tint)
	preload("res://scripts/ui/unit_selection_outline.gd").capture(actor,asset(body_key).tex,body_rect,body_source,alpha)
	if id=="SCHP":_rotor(actor,alpha,factor,lerp_angle(previous_rotor,rotor,fraction),frame)
	preload("res://scripts/units/night_hunter_mounts.gd").draw(actor,self,lift)
	actor._body_bounds=_bounds(body_key,body_source,body_rect)
	for region:Rect2 in body_regions:actor._body_bounds=actor._body_bounds.merge(_bounds(body_key,region,body_rect))
	if has_gun:actor._body_bounds=actor._body_bounds.merge(_bounds(GUN_KEY,gun_source,gun_rect))
	actor._art_frame=0
	actor._turret_draw_rect=Rect2()

static func _bounds(name:String,region:Rect2,rect:Rect2) -> Rect2:
	if metadata.has(name) and metadata[name].has("texture_tile"):
		var tile:float=metadata[name].texture_tile
		var frame:=int(region.position.y/tile)*8+int(region.position.x/tile)
		var box:Array=metadata[name].bounds[frame]
		return Rect2(rect.position+Vector2(box[0],box[1])/128.0*rect.size,Vector2(box[2],box[3])/128.0*rect.size)
	var cache_key:=name+str(region.position)
	if not bounds_cache.has(cache_key):bounds_cache[cache_key]=pixels(name).get_region(Rect2i(region)).get_used_rect()
	var used:Rect2=bounds_cache[cache_key]
	return Rect2(rect.position+used.position/region.size*rect.size,used.size/region.size*rect.size)

func _rotor(actor,alpha:float,factor:float,visual_rotor:float,frame:int) -> void:
	var center:=body_rect.position+rotor_center(frame)*factor
	factor*=float(model().rotor_radius_pixels)/59.0
	var angle:float=actor.hull_angle+visual_rotor
	preload("res://scripts/units/night_owl_rotor.gd").draw(actor,center,angle,factor,alpha)

func rotor_center(frame:int) -> Vector2:
	var data:=model()
	var pose:=int(body_source.position.y/float(data.texture_tile))/4
	var hub:Array=data.pose_rotor_centers[pose*32+frame] if data.has("pose_rotor_centers") else data.rotor_centers[frame]
	return Vector2(hub[0],hub[1])

func hits(actor,world_point:Vector2) -> bool:
	if not body_rect.has_area():return world_point.distance_to(actor.global_position)<=actor.radius+10
	var corrected:Vector2=world_point+actor.global_position-actor.presentation_position()
	var local:=Iso.dir(corrected-actor.global_position)
	if actor._rock_t>0:local=actor.rocking_pose().affine_inverse()*local
	for region:Rect2 in body_regions:
		if _opaque(body_key,body_rect,region,local):return true
	return has_gun and _opaque(GUN_KEY,gun_rect,gun_source,local)

func muzzle(actor) -> Vector2:
	var deployed:bool=actor.is_deployed()
	var angle:float=actor.turret_angle if deployed else actor.hull_angle
	var facing:=posmod(roundi((angle-Iso.eff_angle())/TAU*32),32)
	var yaw:=facing*TAU/32
	var forward:=38.0 if deployed else 28.0
	var height:=9.0 if deployed else 11.0
	var offset:=Vector2(cos(yaw)*forward,sin(yaw)*forward*.5-height*sqrt(.75))*1.2*visual_scale(actor)
	offset.y-=actor._visual_lift()
	return actor.global_position+RA2Art.art_dir(offset)

static func _opaque(name:String,rect:Rect2,region:Rect2,point:Vector2) -> bool:
	if not rect.has_point(point):return false
	var pixel:Vector2i=Vector2i(region.position+(point-rect.position)/rect.size*region.size)
	return pixels(name).get_pixelv(pixel).a>.2

func center(actor) -> Vector2:
	var jump:=preload("res://scripts/units/dog_pounce.gd").lift(actor) if id=="DRON" else 0.0
	return actor.global_position+RA2Art.art_dir(Vector2(0,-actor._visual_lift()-jump-10.0))
