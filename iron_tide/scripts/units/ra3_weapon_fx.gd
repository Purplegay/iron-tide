class_name Ra3WeaponFx
extends Node2D
const ROOT := "res://assets/ra3/mirage/presentation/"
const BEAM = preload(ROOT+"FXAlliedPrismBeam.png")
const FLASH = preload(ROOT+"FXLenzFlare01.png")
const FIRE = preload("res://assets/ra3/mirage/damage/FXFireScroll3.png")
# Exported from official weapon XML, LaserDraw XSD and particle templates.
static var sdk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_mirage_visuals.json"))
var source_ref: WeakRef
var target_ref: WeakRef
var from := Vector2.ZERO
var to := Vector2.ZERO
var age := 0.0
var elite := false
var scatter := false
var beam: Node2D
var beam_material: ShaderMaterial
var world
var origin_ground := Vector2.ZERO
var target_ground := Vector2.ZERO

static func spawn(unit, target, start: Vector2, secondary := false, source_actor = null) -> Ra3WeaponFx:
	var fx := Ra3WeaponFx.new()
	fx.world = unit._battle_world()
	fx.from = start
	fx.to = target.art_center() if target.has_method("art_center") else target.global_position
	fx.origin_ground = source_actor.global_position if secondary and is_instance_valid(source_actor) else unit.global_position
	fx.target_ground = target.global_position
	fx.elite = unit.veteran_level >= 3
	fx.scatter = secondary
	fx.source_ref = weakref(source_actor if secondary and is_instance_valid(source_actor) else unit)
	fx.target_ref = weakref(target)
	var host := Effects._host()
	if host == null: fx.free(); return null
	host.add_child(fx)
	return fx

func _ready() -> void:
	visible = is_instance_valid(world) and world.position_visible_to("ally",origin_ground) and world.position_visible_to("ally",target_ground)
	beam = Node2D.new(); add_child(beam)
	beam_material = ShaderMaterial.new()
	beam_material.shader = load("res://shaders/ra3_prism.gdshader")
	beam_material.set_shader_parameter("secondary",load(ROOT + ("FXAlliedPrismBeam_Vet.png" if elite and not scatter else "FXAlliedPrismBeam.png")))
	beam.material = beam_material
	beam.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	beam.draw.connect(_draw_beam)
	var additive := CanvasItemMaterial.new(); additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _process(delta: float) -> void:
	age += delta
	if age >= maxf(beam_lifetime(),particle_lifetime("AlliedPrismHitFIre")+5.0/30.0): queue_free(); return
	var source = source_ref.get_ref() if source_ref != null else null
	var target = target_ref.get_ref() if target_ref != null else null
	# Damage resolves before the first rendered frame. A lethal hit must retain
	# its emitted segment until the visual lifetime ends, even after queue_free.
	# Track each live endpoint independently; keep the last position of dead ones.
	if AlliedAbilities.alive(source):
		from = source.art_center() if scatter else source._weapon_muzzle()
		origin_ground = source.global_position
	if AlliedAbilities.alive(target):
		to = target.art_center() if target.has_method("art_center") else target.global_position
		target_ground = target.global_position
	visible = is_instance_valid(world) and world.position_visible_to("ally",origin_ground) and world.position_visible_to("ally",target_ground)
	beam_material.set_shader_parameter("age",age)
	beam_material.set_shader_parameter("opacity",beam_opacity())
	beam.queue_redraw(); queue_redraw()

static func particle_lifetime(id: String) -> float:
	return float(sdk.particles[id].lifetime_frames[1])/float(sdk.adapter.particle_frames_per_second)

static func particle_color(id: String, time: float) -> Color:
	var row: Dictionary = sdk.particles[id]
	var local := time-float(row.delay_frames)/float(sdk.adapter.particle_frames_per_second)
	var progress := local/particle_lifetime(id)
	if local<0.0 or progress>=1.0: return Color.BLACK
	var keys: Array = row.colors
	var first: Array = keys[0].rgb
	var result := Color(first[0],first[1],first[2])
	for i in range(1,keys.size()):
		var next: Array = keys[i].rgb
		var color := Color(next[0],next[1],next[2])
		if progress<=float(keys[i].age):
			return result.lerp(color,clampf((progress-float(keys[i-1].age))/(float(keys[i].age)-float(keys[i-1].age)),0.0,1.0))
		result=color
	return result

func beam_lifetime() -> float:
	return float(sdk.scatter_lifetime if scatter else sdk.primary_lifetime)

func beam_width() -> float:
	return float(sdk.scatter_width if scatter else sdk.primary_width)*Ra3Mirage.WORLD_SCALE

static func native_opacity(time: float, created: float, expires: float, fade_in: float, fade_out: float) -> float:
	# Uprising 1.1, 0x5fed9b..0x5fee29. Linear envelopes multiply; -1 is
	# an indefinite end time. Mirage uses zero envelopes (texture motion fades it).
	var result := clampf((time-created)/fade_in,0.0,1.0) if fade_in>0.0 else 1.0
	if fade_out>0.0 and expires!=-1.0:
		result *= clampf((expires-time)/fade_out,0.0,1.0)
	return result

static func native_half_width(delta: Vector3, camera_to_midpoint: Vector3, full_width: float) -> Vector3:
	# Do not normalize the cross product: its length is part of native width.
	var direction := delta.normalized() if delta.length_squared()>0.0001 else delta
	return direction.cross(camera_to_midpoint.normalized())*(full_width*0.5)

static func endpoint_3d(point: Vector2, ground: Vector2) -> Vector3:
	# Adapter for this 2D world's orthographic camera, in a Z-up view basis.
	# Ground depth supplies the unavailable 3D target depth; preserve exact
	# rendered muzzle/impact pixels, including the last pose of dead actors.
	var screen := Iso.dir(point)
	var depth := ground.rotated(-Iso.eff_angle()).y
	var cosine := sqrt(maxf(0.0001,1.0-Iso.K*Iso.K))
	return Vector3(screen.x,depth,(depth*Iso.K-screen.y)/cosine)

func beam_half_width() -> Vector2:
	var cosine := sqrt(maxf(0.0001,1.0-Iso.K*Iso.K))
	var delta := endpoint_3d(to,target_ground)-endpoint_3d(from,origin_ground)
	var offset := native_half_width(delta,Vector3(0,cosine,Iso.K),beam_width())
	return Vector2(offset.x,offset.y*Iso.K-offset.z*cosine)

func beam_opacity() -> float:
	# Expiration removes the native draw; it is separate from vertex opacity.
	if age>=beam_lifetime(): return 0.0
	return native_opacity(age,0.0,beam_lifetime(),float(sdk.beam_fade_in),float(sdk.beam_fade_out))

func _draw_beam() -> void:
	if beam_opacity()<=0.0: return
	Iso.begin(beam)
	var start := Iso.dir(to_local(from)); var finish := Iso.dir(to_local(to))
	var normal := beam_half_width()
	beam.draw_polygon(PackedVector2Array([start+normal,start-normal,finish-normal,finish+normal]),
		PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]),BEAM)

func _draw() -> void:
	Iso.begin(self)
	var end := Iso.dir(to_local(to))
	var tint := particle_color("AlliedPrismHitFlash",age)
	var radius := 18.0 if scatter else 32.0
	if tint != Color.BLACK:
		draw_texture_rect(FLASH,Rect2(end-Vector2.ONE*radius,Vector2.ONE*radius*2.0),false,tint)
	if not scatter:
		var muzzle_tint := particle_color("AlliedPrismFireFlash_Vet" if elite else "AlliedPrismFireFlash",age)
		if muzzle_tint != Color.BLACK:
			var muzzle := Iso.dir(to_local(from))
			draw_texture_rect(FLASH,Rect2(muzzle-Vector2(16,16),Vector2(32,32)),false,muzzle_tint)
	var fire_tint := particle_color("AlliedPrismHitFIre",age)
	if fire_tint != Color.BLACK:
		for i in 2:
			var center := end + Vector2((i*2-1)*6.0,-age*12.0)
			draw_texture_rect(FIRE,Rect2(center-Vector2(14,20),Vector2(28,40)),false,Color(fire_tint,0.65))
