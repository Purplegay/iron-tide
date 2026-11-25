extends RefCounted
## Authored direct-facing sprites; gameplay identity and state remain in Leizhu.
const PATH="res://assets/cosmetics/heroes/leizhu_copper_model32"
static var texture:Texture2D
static var pixels:Image
static var data:Dictionary={}
static var scale_cache:Dictionary={}
var surface:ShaderMaterial
var original_filter:int
var clock:=0.0
var body_rect:=Rect2()
var source_rect:=Rect2()

static func handles(actor) -> bool:
	return actor.unit_id=="TTNK" and actor.special.get("academy_hero")=="TTNK" and actor.special.has("leizhu") and (BattleRequest.extensions_enabled() or actor.has_method("cosmetic_preview_travel"))

static func install_preview(actor) -> void:
	actor.special.academy_hero="TTNK"
	actor.special.leizhu={"quiet":0.0,"marks":{},"side":actor.side}
	actor.refresh_house_color()

static func preview_material() -> ShaderMaterial:
	ensure_asset()
	var result:=ShaderMaterial.new()
	result.shader=preload("res://shaders/leizhu_copper.gdshader")
	result.set_shader_parameter("house_color",HouseColor.color_for_side("ally","#c82828"))
	result.set_shader_parameter("atlas_texel",Vector2.ONE/Vector2(texture.get_size()))
	return result

static func draw_preview(canvas,foot:Vector2,width:float,frame:int,tint:Color) -> void:
	ensure_asset();frame=posmod(frame,32)
	var factor:=width/float(data.preview_width);var tile:=float(data.tile)
	var rect:=Rect2(foot-point(data.anchors[frame])*factor,Vector2.ONE*tile*factor)
	canvas.draw_texture_rect_region(texture,rect,Rect2(Vector2(frame%8,frame/8)*tile,Vector2.ONE*tile),tint)

static func configure(actor,color:Color) -> void:
	if not handles(actor):
		if actor.hero_art!=null:actor.texture_filter=actor.hero_art.original_filter
		actor.hero_art=null
		return
	ensure_asset()
	if actor.hero_art==null or actor.hero_art.get_script()!=load("res://scripts/units/leizhu_art.gd"):
		var prior_filter:int=actor.hero_art.original_filter if actor.hero_art!=null else actor.texture_filter
		actor.hero_art=load("res://scripts/units/leizhu_art.gd").new()
		actor.hero_art.original_filter=prior_filter
		actor.hero_art.surface=ShaderMaterial.new()
		actor.hero_art.surface.shader=preload("res://shaders/leizhu_copper.gdshader")
	actor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	actor.material=actor.hero_art.surface
	actor.material.set_shader_parameter("house_color",color)
	actor.material.set_shader_parameter("atlas_texel",Vector2.ONE/Vector2(texture.get_size()))
	actor.hero_art.tick(actor,0)

static func ensure_asset() -> void:
	if texture!=null:return
	texture=load(PATH+".png")
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH+".json"))

static func frame_for(actor) -> int:
	return posmod(roundi((actor.hull_angle-Iso.eff_angle())/TAU*32),32)

static func scale_for(actor) -> float:
	ensure_asset()
	if not scale_cache.has(actor.radius):
		var native:=RA2Art.art("TTNK");var width:=0.0;var custom:=0.0
		var count:=int(native.get("facings",32))
		var rect:=RA2Art.draw_rect(native,actor.radius,range(count),0,actor.RA2_SPRITE_SCALE)
		for i in 8:
			width+=RA2Art.visible_sprite_rect(native,rect,RA2Art.src_rect(native,i*count/8)).size.x
			custom+=float(data.bounds[i*4][2])
		scale_cache[actor.radius]=width/maxf(custom,1)
	return scale_cache[actor.radius]

static func point(values:Array) -> Vector2:
	return Vector2(values[0],values[1])

static func pose(actor) -> Dictionary:
	var factor:=scale_for(actor);var frame:=frame_for(actor);var tile:=float(data.tile)
	var rect:=Rect2(-point(data.anchors[frame])*factor-Vector2(0,actor._visual_lift()),Vector2.ONE*tile*factor)
	return {"frame":frame,"scale":factor,"rect":rect,"source":Rect2(Vector2(frame%8,frame/8)*tile,Vector2.ONE*tile),
		"reactor":rect.position+point(data.reactors[frame])*factor,"coil":rect.position+point(data.coils[frame])*factor}

func tick(actor,dt:float) -> void:
	clock=fposmod(clock+maxf(0,dt),600)
	var state:Dictionary=actor.special.get("leizhu",{})
	var stopped:bool=float(state.get("shutdown_left",0))>0 or actor._dead
	surface.set_shader_parameter("online",not stopped)
	surface.set_shader_parameter("phase",clock)
	surface.set_shader_parameter("supplying",state.get("power_active",false) and not stopped)
	if actor.is_visible_in_tree() and not actor._dead:actor.queue_redraw()

func draw_on(actor) -> void:
	var value:=pose(actor);var factor:float=value.scale
	body_rect=value.rect;source_rect=value.source
	var alpha:float=preload("res://scripts/units/ra3_cloak_visual.gd").opacity(actor)
	Iso.shadow(actor,Vector2(actor.radius*.12,actor.radius*.15),actor.radius*1.15,.3*alpha)
	actor.draw_texture_rect_region(texture,body_rect,source_rect,Color(1,1,1,alpha))
	preload("res://scripts/ui/unit_selection_outline.gd").capture(actor,texture,body_rect,source_rect,alpha)
	var box:Array=data.bounds[value.frame]
	actor._body_bounds=Rect2(body_rect.position+Vector2(box[0],box[1])*factor,Vector2(box[2],box[3])*factor)
	actor._art_frame=0;actor._turret_draw_rect=Rect2()
	if float(actor.special.leizhu.get("shutdown_left",0))>0:return
	# Short moving copper highlights make the circular segmented coil rotate.
	# No particles, node allocation, or permanent lightning outside the chassis.
	var radius:=float(data.coil_radius)*factor
	for segment in 3:
		var points:=PackedVector2Array()
		for step in 6:
			var angle:=clock*1.5+segment*TAU/3+step*.07
			points.append(value.coil+Vector2(cos(angle),sin(angle)*.45)*radius)
		actor.draw_polyline(points,Color(.82,.55,.3,.65*alpha),1,true)
	if actor.special.leizhu.get("power_active",false):
		actor.draw_circle(value.reactor,2.3,Color(.7,.9,1,.65*alpha))
		# Confined to the copper crown: supply feedback, not a fake attack beam.
		for arc in 2:
			var points:=PackedVector2Array()
			for step in 9:
				var angle:=clock*1.8+arc*PI+step*.12
				var jitter:=sin(clock*26+step*7)*.7
				points.append(value.coil+Vector2(cos(angle),sin(angle)*.5)*(radius+jitter))
			actor.draw_polyline(points,Color(.2,.55,1,.25*alpha),2.5,true)
			actor.draw_polyline(points,Color(.65,.88,1,.85*alpha),.7,true)

func muzzle(actor) -> Vector2:
	return actor.global_position+RA2Art.art_dir(pose(actor).coil-Vector2(0,3))

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
