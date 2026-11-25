extends RefCounted
## Two independent baked meshes per vehicle. Coordinates in the manifest use a
## 128-unit projection plane. The 512-pixel renders are cropped and packed offline.
const FILES={"FV":"yinpian_rain","HARV":"laocheng_weighbridge"}
const ROOT="res://assets/cosmetics/heroes/"
const Outline=preload("res://scripts/ui/unit_selection_outline.gd")
const Surface=preload("res://shaders/convoy_surface.gdshader")
static var assets:Dictionary={}
var atlas:Texture2D
var table:Dictionary
var surface:ShaderMaterial
var original_filter:int
var factor:float
var clock:=0.0
var body_rect:=Rect2()
var source_rect:=Rect2()
var head_rect:=Rect2()
var head_source:=Rect2()
var projected:=false

static func handles(u) -> bool:
	return u.unit_id in FILES and ((u.special.get("academy_hero")==u.unit_id and u.special.get("hero_skin",false)) or u.special.get("convoy_projected_skin",false))

static func resource(id:String) -> Dictionary:
	if not assets.has(id):
		var path:String=ROOT+FILES[id]
		assets[id]={"atlas":load(path+".png"),"table":JSON.parse_string(FileAccess.get_file_as_string(path+".json"))}
	return assets[id]

static func configure(u,color:Color) -> void:
	if u.hero_art==null or u.hero_art.get_script()!=load("res://scripts/units/convoy_art.gd"):
		var model=load("res://scripts/units/convoy_art.gd").new()
		model.original_filter=u.texture_filter
		u.hero_art=model
	var art=u.hero_art
	var record:=resource(u.unit_id)
	art.atlas=record.atlas
	art.table=record.table
	art.projected=u.special.get("convoy_projected_skin",false)
	var count:=int(u._ra2.get("facings",32))
	var rect:=RA2Art.draw_rect(u._ra2,u.radius,range(count),0,u.RA2_SPRITE_SCALE)
	var native_width:=0.0
	var art_width:=0.0
	for i in 8:
		native_width+=RA2Art.visible_sprite_rect(u._ra2,rect,RA2Art.src_rect(u._ra2,i*count/8)).size.x
		art_width+=float(art.table.bounds[4*i][2])
	art.factor=1.12*native_width/maxf(1,art_width)
	if art.surface==null:
		art.surface=ShaderMaterial.new()
		art.surface.shader=Surface
	art.surface.set_shader_parameter("atlas_texel",Vector2.ONE/Vector2(art.atlas.get_size()))
	art.surface.set_shader_parameter("house_color",color)
	u.material=art.surface
	u.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.tick(u,0.0)

static func vector(pair:Array) -> Vector2:
	return Vector2(pair[0],pair[1])

static func facing(angle:float) -> int:
	return posmod(roundi((angle-Iso.eff_angle())/TAU*32),32)

func body_pose(u) -> int:
	var s:=visual_state(u)
	if u.unit_id=="FV":
		var remaining:float=s.get("projection_cd",0)
		if remaining>17.8 or remaining>11.8 and remaining<=12.0:return 5
		return 1 if remaining>12 else 0
	var loaded:bool=u.cargo>0
	if s.has("press"):
		if float(s.press.left)>.3:return 7 if loaded else 8
		return 2 if loaded else 5
	if s.has("press_recoil"):return 6 if loaded else 3
	return 1 if loaded else 0

func head_pose(u) -> int:
	if u.unit_id=="HARV":return 4
	if projected:return int(u.special.get("convoy_projected_head",3))
	if u.logistics.passengers.is_empty():return 2
	if AlliedAbilities.is_repair_ifv(u):return 4
	return 2 if int(AlliedAbilities.source(u.logistics.passengers[0]).get("IFVMode",0))==0 else 3

func tile_rect(index:int,frame:int) -> Rect2:
	var box:Array=table.frames[index*32+frame]
	return Rect2(box[0],box[1],box[2],box[3])

func placement(index:int,frame:int,foot:Vector2) -> Rect2:
	var box:Array=table.bounds[index*32+frame]
	return Rect2(foot+(Vector2(box[0],box[1])-vector(table.origin))*factor,Vector2(box[2],box[3])*factor)

func tick(u,dt:float) -> void:
	clock=fposmod(clock+dt,60)
	var state:=visual_state(u)
	var heat:float=clampf(float(state.get("heat",0))/4,0,1)
	var light:float=.77+.07*sin(clock*2.6)
	if projected or float(state.get("projection_cd",0))>12 or state.has("crew_flash"):light=1.15+.13*sin(clock*10)
	if state.has("press") or state.has("press_recoil"):light=1.4
	surface.set_shader_parameter("optic_power",light)
	surface.set_shader_parameter("barrel_heat",heat)
	u.queue_redraw()

func mount(u,frame:int) -> Vector2:
	return vector(table.mounts[frame])*factor if not projected else Vector2.UP*2

func draw_on(u) -> void:
	var hull:=facing(u.hull_angle)
	var turret:=facing(u.turret_angle)
	var shell:=body_pose(u)
	var head:=head_pose(u)
	var foot:=Vector2.UP*float(u._visual_lift())
	body_rect=placement(shell,hull,foot)
	source_rect=tile_rect(shell,hull)
	head_rect=placement(head,turret,foot+mount(u,hull))
	head_source=tile_rect(head,turret)
	var alpha:float=preload("res://scripts/units/ra3_cloak_visual.gd").opacity(u)
	var tint:=Color(1,1,1,alpha)
	Iso.shadow(u,Vector2(2,2),u.radius*(.62 if projected else 1.18),.28*alpha)
	if not projected:
		u.draw_texture_rect_region(atlas,body_rect,source_rect,tint)
		Outline.capture(u,atlas,body_rect,source_rect,alpha)
	else:
		tint=Color(.55,1,1,.78*alpha)
		u.draw_arc(Vector2.ZERO,8,0,TAU,24,Color(.36,.92,1,.68),1.4,true)
	u.draw_texture_rect_region(atlas,head_rect,head_source,tint)
	Outline.capture(u,atlas,head_rect,head_source,tint.a)
	u._body_bounds=head_rect if projected else head_rect.merge(body_rect)
	u._art_frame=0
	u._turret_draw_rect=Rect2()

func muzzle(u) -> Vector2:
	var head:=head_pose(u)
	var barrel:=0 if u.unit_id=="HARV" else head-2
	var tip:=mount(u,facing(u.hull_angle))+vector(table.muzzles[barrel][facing(u.turret_angle)])*factor
	return u.global_position+RA2Art.art_dir(tip-Vector2.DOWN*u._visual_lift())

func center(u) -> Vector2:
	if u._body_bounds.has_area():return u.global_position+RA2Art.art_dir(u._body_bounds.get_center())
	return u.global_position

func hits(u,point:Vector2) -> bool:
	if not body_rect.has_area():return u.global_position.distance_to(point)<=u.radius
	var local:=Iso.dir(point-u.presentation_position())
	if u._rock_t>0:local=u.rocking_pose().affine_inverse()*local
	var record:=resource(u.unit_id)
	if not record.has("mask"):
		var pixels:=atlas.get_image()
		if pixels.is_compressed():pixels.decompress()
		var mask:=BitMap.new()
		mask.create_from_image_alpha(pixels,.08)
		record.mask=mask
	if layer_hit(record.mask,local,head_rect,head_source):return true
	return not projected and layer_hit(record.mask,local,body_rect,source_rect)

func layer_hit(mask:BitMap,local:Vector2,dest:Rect2,src:Rect2) -> bool:
	if not dest.has_point(local):return false
	var px:=Vector2i(src.position+(local-dest.position)/dest.size*src.size)
	return mask.get_bitv(px)


func view_bounds() -> Rect2:
	var result:=Rect2()
	var count:=2 if table.poses[0]=="cruise" else 4
	for pose in count:
		for frame in 32:
			var box:Array=table.bounds[pose*32+frame]
			var bounds:=Rect2((Vector2(box[0],box[1])-vector(table.origin))*factor,Vector2(box[2],box[3])*factor)
			result=bounds if not result.has_area() else result.merge(bounds)
	return result.grow(2.0*factor)

# Workshop-only action cycle. The preview actor has no battle or player inventory.
func preview_cycle(u,age:float) -> void:
	var t:=fmod(age,8.0)
	var state:Dictionary=u.special.get_or_add("convoy_preview",{})
	if u.unit_id=="FV":
		state.projection_cd=18-(t-2.0) if t>=2 and t<6 else 0.0
	else:
		u.cargo=u.cargo_cap if t<4.6 else u.cargo_cap*.75
		state.heat=minf(4,t)
		if t>=4 and t<4.6:state.press={"left":4.6-t}
		else:state.erase("press")
		if t>=4.6 and t<4.92:state.press_recoil=4.92-t
		else:state.erase("press_recoil")

func visual_state(u) -> Dictionary:
	return u.special.get("convoy_preview",{}) if u.has_method("cosmetic_preview_travel") else u.special.get("convoy",{})
