extends RefCounted
## Offline model bake in native FALC coordinates; the gameplay unit stays ORCA.
const PATH="res://assets/cosmetics/heroes/peregrine_polar_32"
# Detailed bake averages 1.0041 times native ORCA's visible width over 32 frames.
const BODY_SCALE:=.825
static var texture:Texture2D
static var mask:Texture2D
static var pixels:Image
static var data:Dictionary={}
var surface:ShaderMaterial
var original_filter:int
var clock:=0.0
var body_rect:=Rect2()
var source_rect:=Rect2()

static func handles(actor) -> bool:
	return actor.unit_id=="ORCA" and actor.special.get("academy_hero")=="ORCA" and actor.special.has("peregrine") and (BattleRequest.extensions_enabled() or actor.has_method("cosmetic_preview_travel"))

static func ensure_asset() -> void:
	if texture!=null:return
	texture=load(PATH+".png")
	mask=load(PATH+"_mask.png")
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH+".json"))

static func configure(actor,color:Color) -> void:
	ensure_asset()
	if actor.hero_art==null or actor.hero_art.get_script()!=load("res://scripts/units/peregrine_art.gd"):
		var prior_filter:int=actor.hero_art.original_filter if actor.hero_art!=null else actor.texture_filter
		actor.hero_art=load("res://scripts/units/peregrine_art.gd").new()
		actor.hero_art.original_filter=prior_filter
		actor.hero_art.surface=ShaderMaterial.new()
		actor.hero_art.surface.shader=preload("res://shaders/peregrine_polar.gdshader")
	actor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	actor.material=actor.hero_art.surface
	actor.material.set_shader_parameter("house_color",color)
	actor.material.set_shader_parameter("paint_mask",mask)
	actor.material.set_shader_parameter("atlas_texel",Vector2.ONE/Vector2(texture.get_size()))
	actor.hero_art.tick(actor,0)

static func point(values:Array) -> Vector2:
	return Vector2(values[0],values[1])

static func preview_material() -> ShaderMaterial:
	ensure_asset()
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/peregrine_polar.gdshader")
	material.set_shader_parameter("house_color",HouseColor.color_for_side("ally","#c82828"))
	material.set_shader_parameter("paint_mask",mask)
	material.set_shader_parameter("atlas_texel",Vector2.ONE/Vector2(texture.get_size()))
	return material

static func draw_preview(canvas,foot:Vector2,size:float,frame:int,tint:Color) -> void:
	ensure_asset();frame=posmod(frame,32)
	var factor:=size*BODY_SCALE/float(data.scale)
	var rect:=Rect2(foot-point(data.origin)*factor,point(data.tile)*factor)
	canvas.draw_texture_rect_region(texture,rect,Rect2(Vector2(frame%8,frame/8)*point(data.tile),point(data.tile)),tint)

static func frame_for(actor) -> int:
	return actor._sprite_facing(actor._ra2,actor.hull_angle)

static func pose(actor) -> Dictionary:
	ensure_asset()
	var frame:=frame_for(actor)
	var factor:float=actor.RA2_SPRITE_SCALE*BODY_SCALE/float(data.scale)
	var native_rect:=RA2Art.draw_rect(actor._ra2,actor.radius,range(32),actor._visual_lift(),actor.RA2_SPRITE_SCALE)
	var origin:Vector2=point(actor._weapon_art.origins[frame])*actor.RA2_SPRITE_SCALE
	var rect:=Rect2(native_rect.position+origin-point(data.origin)*factor,point(data.tile)*factor)
	return {"frame":frame,"scale":factor,"rect":rect,
		"source":Rect2(Vector2(frame%8,frame/8)*point(data.tile),point(data.tile)),
		"muzzle":rect.position+point(data.muzzles[frame])*factor}

static func engine_mounts(actor) -> Array[Vector2]:
	var value:=pose(actor)
	var result:Array[Vector2]=[]
	for mount in data.engines[value.frame]:result.append(value.rect.position+point(mount)*float(value.scale))
	return result

func tick(actor,delta:float) -> void:
	clock=fposmod(clock+maxf(delta,0),60)
	surface.set_shader_parameter("pulse",.8+.2*sin(clock*2.4))
	surface.set_shader_parameter("broken",actor.special.has("hero_wreck"))
	surface.set_shader_parameter("online",not actor.special.has("hero_wreck") and actor.logistics.air_lift>.01)
	if actor.is_visible_in_tree() and not actor._dead:actor.queue_redraw()

func draw_on(actor) -> void:
	var value:=pose(actor)
	body_rect=value.rect;source_rect=value.source
	var alpha:float=preload("res://scripts/units/ra3_cloak_visual.gd").opacity(actor)
	Iso.shadow(actor,Vector2(actor.radius*.12,actor.radius*.15),actor.radius*1.15,.3*alpha)
	actor.draw_texture_rect_region(texture,body_rect,source_rect,Color(1,1,1,alpha))
	preload("res://scripts/ui/unit_selection_outline.gd").capture(actor,texture,body_rect,source_rect,alpha)
	var box:Array=data.bounds[value.frame]
	actor._body_bounds=Rect2(body_rect.position+Vector2(box[0],box[1])*float(value.scale),Vector2(box[2],box[3])*float(value.scale))
	actor._art_frame=value.frame;actor._turret_draw_rect=Rect2()

func muzzle(actor) -> Vector2:
	var offset:Vector2=pose(actor).muzzle
	if actor._rock_t>0:offset=actor.rocking_pose()*offset
	return actor.global_position+RA2Art.art_dir(offset)

func hits(actor,world_point:Vector2) -> bool:
	if not body_rect.has_area():return world_point.distance_to(actor.global_position)<=actor.radius+10
	var local:=Iso.dir(world_point-actor.presentation_position())
	if actor._rock_t>0:local=actor.rocking_pose().affine_inverse()*local
	if not body_rect.has_point(local):return false
	if pixels==null:
		pixels=texture.get_image()
		if pixels.is_compressed():pixels.decompress()
	var pixel:=Vector2i(source_rect.position+(local-body_rect.position)/body_rect.size*source_rect.size)
	return pixels.get_pixelv(pixel).a>=20.0/255

func center(actor) -> Vector2:
	var value:=pose(actor);var box:Array=data.bounds[value.frame]
	return actor.global_position+RA2Art.art_dir(value.rect.position+(Vector2(box[0],box[1])+Vector2(box[2],box[3])*.5)*float(value.scale))
