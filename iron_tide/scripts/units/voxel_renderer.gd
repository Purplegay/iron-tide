extends RefCounted
## Asset preparation is shared by every unit using the canonical atlas.
## Per-draw state is limited to facing, lift, opacity and power; no pose cache.
const Detail = preload("res://scripts/core/shp_detail.gd")
const TYPES := {"APOC":true,"MTNK":true,"HTNK":true,"HTK":true,"FV":true,"TTNK":true,"SREF":true,"ZEP":true,"BFRT":true,"CMIN":true,"HARV":true,"SHAD":true,"ORCA":true,"BEAG":true}
static var resources: Dictionary = {}

class Atlas:
	extends RefCounted
	var art: Dictionary
	var texture: Texture2D
	var size: Vector2
	var scaled_size: Vector2
	var offset: Vector2
	var anchor: Vector2
	var facings: int
	var facing_offset: int
	var frames: Array
	var sources: Array[Rect2] = []
	var uvs: Array[Rect2] = []
	var crops: Array[Rect2] = []
	var ratios: Array[Vector2] = []
	var grade: Color
	var split_shadow: bool

	func _init(data: Dictionary) -> void:
		art = data
		texture = data.get("detail_tex",data.tex)
		size = RA2Art.frame_size(data)
		scaled_size = size * Unit.RA2_SPRITE_SCALE
		facings = int(data.get("facings",8))
		facing_offset = int(data.get("facing_offset",0))
		frames = range(facings)
		frames.make_read_only()
		anchor = RA2Art.anchor(data,frames)
		grade = RA2Art.sprite_grade(data)
		split_shadow = bool(data.get("split_shadow",false))
		var translation: Array = data.get("draw_offset",[0,0])
		offset = Vector2(translation[0],translation[1])*Unit.RA2_SPRITE_SCALE
		var density := float(data.get("detail_scale",1.0))
		for frame in facings:
			var source := RA2Art.src_rect(data,frame)
			sources.append(source)
			uvs.append(source if density==1.0 else Rect2(source.position*density,source.size*density))
			crops.append(RA2Art.visible_sprite_rect(data,Rect2(Vector2.ZERO,size),source))
			ratios.append(scaled_size/source.size)

	func facing(angle: float) -> int:
		return posmod(RA2Art.facing_index(angle,facings)+facing_offset,facings)

static func atlas(data: Dictionary) -> Atlas:
	if data.is_empty() or data.get("kind")!="vxl" or int(data.get("poses",1))!=1 or data.get("tex")==null: return null
	var id: String = data.get("key","")
	# Private/custom art remains on the generic renderer, including in-place edits.
	if not is_same(RA2Art._cache.get(id),data): return null
	var reference: WeakRef = resources.get(id)
	var prepared: Atlas = reference.get_ref() if reference != null else null
	if prepared == null or not is_same(prepared.art,data):
		prepared = Atlas.new(data)
		resources[id] = weakref(prepared)
	return prepared

static func draw(unit: Unit, radius: float) -> bool:
	if not TYPES.has(unit.unit_id) or unit.is_naval or not unit._seq.is_empty() or unit._ra3_model!=null or unit.casemate_thruster!=null or unit._rock_t>0.0: return false
	if unit.special.get("hero_skin",false) or unit.special.has(Unit.Furnace.STANCE): return false
	if unit.unit_id in ["TTNK","SREF"] and unit.yr_finish!=null: return false
	if unit.unit_id=="HARV" and unit.side=="ally" and unit.cosmetic_outfit().get("skin")=="night_shift": return false
	var hull: Atlas = unit._voxel_hull
	var shadow: Atlas = unit._voxel_shadow
	var turret: Atlas = unit._voxel_turret
	if hull==null or shadow==null or (not unit._ra2_tur.is_empty() and turret==null): return false
	var frame := hull.facing(unit.hull_angle)
	var lift := unit._visual_lift()
	var scale := Unit.RA2_SPRITE_SCALE
	var base := Vector2(-hull.anchor.x*scale,radius*0.35-hull.anchor.y*scale-lift)
	var body_rect := Rect2(base,hull.scaled_size)
	var shadow_rect := Rect2(base+Vector2(0.0,lift),shadow.scaled_size)
	var alpha := Ra3Mirage.CloakVisual.opacity(unit)
	var joint: Texture2D
	var turret_frame := turret.facing(unit.turret_angle) if turret!=null else -1
	if hull.split_shadow and turret!=null:
		var turret_shadow := RA2Art.art(str(turret.art.key)+"_shd")
		if not turret_shadow.is_empty():
			joint = RA2Art.unit_shadow_texture(shadow.art,turret_shadow,frame,unit._sprite_facing(turret_shadow,unit.turret_angle))
	if joint!=null: unit.draw_texture_rect(joint,shadow_rect,false,Color(0,0,0,0.5*alpha))
	else: unit.draw_texture_rect_region(shadow.art.tex,shadow_rect,shadow.sources[posmod(frame,shadow.facings)],Color(0,0,0,0.5*alpha))
	var grade := hull.grade
	grade.a *= alpha
	if unit.powered_unit.offline: grade = grade.darkened(0.45)
	unit.draw_prepared_voxel(hull,body_rect,frame,grade)
	unit._turret_draw_rect = Rect2()
	if turret!=null:
		var rect := Rect2(base+turret.offset,turret.scaled_size)
		grade = turret.grade
		grade.a *= alpha
		if unit.powered_unit.offline: grade = grade.darkened(0.45)
		unit.draw_prepared_voxel(turret,rect,turret_frame,grade)
		unit._turret_draw_rect = rect
		unit._turret_draw_source = turret.sources[turret_frame]
	unit._shadow_draw_texture = joint
	unit._shadow_draw_rect = shadow_rect
	unit._pick_body_art = hull.art
	unit._pick_body_rect = body_rect
	unit._art_frame = frame
	unit._art_aframes = hull.frames
	unit._art_sc = scale
	unit._art_lift = lift
	unit._anchor_span_key = Vector4i(0,hull.facings,0,0)
	unit._anchor_span_frames = hull.frames
	return true

static func submit(unit: Unit, prepared: Atlas, rect: Rect2, frame: int, grade: Color) -> void:
	Detail.draw_region(unit,prepared.texture,rect,prepared.uvs[frame],grade,INF)
	var crop := prepared.crops[frame]
	var ratio := prepared.ratios[frame]
	var bounds := Rect2(rect.position+crop.position*ratio,crop.size*ratio)
	if bounds.has_area(): unit._body_bounds = unit._body_bounds.merge(bounds) if unit._body_bounds.has_area() else bounds
