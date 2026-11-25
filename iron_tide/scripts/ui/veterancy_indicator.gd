extends RefCounted
## Presentation only. Rank stays authoritative on Unit; the short flash is not saved.
const PROMOTION := &"veterancy_promotion_visual"
const DURATION := 1.25
const GOLD := Color(1.0, 0.83, 0.28)

static func state(unit) -> Dictionary:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit._dead or unit.hp <= 0.0:
		return {}
	if unit.veteran_level <= 0 or unit.embarked_in != null or not unit.is_visible_in_tree(): return {}
	var world = unit._battle_world()
	if world != null and not world.actor_visible_to("ally", unit): return {}
	var rank := clampi(unit.veteran_level, 0, 3 if HpBar.uses_ra3_ranks(unit.data) else 2)
	return {"rank": rank, "badge": HpBar.rank_texture(rank, unit.data),
		"flash": clampf(float(unit.get_meta(PROMOTION, 0.0)) / DURATION, 0.0, 1.0)}

static func promote(unit) -> void:
	# No delayed flash when an unseen enemy emerges from fog or cargo unloads.
	if state(unit).is_empty(): return
	unit.set_meta(PROMOTION, DURATION)

static func tick(unit, delta: float) -> void:
	if not unit.has_meta(PROMOTION): return
	var left := maxf(0.0, float(unit.get_meta(PROMOTION)) - delta)
	if left <= 0.0 or state(unit).is_empty(): unit.remove_meta(PROMOTION)
	else: unit.set_meta(PROMOTION, left)

static func screen_center(unit, canvas: Node2D) -> Vector2:
	var camera := canvas.get_viewport().get_camera_2d()
	var zoom: float = camera.zoom.x if camera != null else 1.0
	var bar: Rect2 = unit.hp_bar_rect()
	return canvas.get_global_transform_with_canvas() * canvas.to_local(unit.presentation_position()) \
		+ Vector2(bar.position.x * zoom - 13.0, bar.get_center().y * zoom)

# Canvas commands are retained after _draw. Keep the original colour and
# transparency in geometry, so the world badge never samples an unbound texture.
static var badge_meshes:Dictionary={}

static func badge_mesh(texture:Texture2D) -> ArrayMesh:
	if badge_meshes.has(texture):return badge_meshes[texture]
	var image:=texture.get_image()
	var dimensions:Vector2i=(Vector2(image.get_size())*0.75).round()
	image.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_NEAREST)
	var vertices:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for y in dimensions.y:
		for x in dimensions.x:
			var color:=image.get_pixel(x,y)
			if color.a==0:continue
			var p:=Vector2(x,y)
			var i:=vertices.size()
			vertices.append_array(PackedVector2Array([p,p+Vector2.RIGHT,p+Vector2.ONE,p+Vector2.DOWN]))
			colors.append_array(PackedColorArray([color,color,color,color]))
			indices.append_array(PackedInt32Array([i,i+1,i+2,i,i+2,i+3]))
	var surface:=[]
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX]=vertices
	surface[Mesh.ARRAY_COLOR]=colors
	surface[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
	badge_meshes[texture]=mesh
	return mesh

static func paint(unit, canvas: Node2D) -> void:
	var info := state(unit)
	if info.is_empty(): return
	var center := screen_center(unit, canvas)
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	var texture: Texture2D = info.badge
	var size := texture.get_size()
	if HpBar.uses_ra3_ranks(unit.data):
		# Uprising UnitOverlayIconSettings.VeterancyIconScale = 75%.
		size = (size * 0.75).round()
		canvas.draw_mesh(badge_mesh(texture),null,Transform2D(0.0,(center-size*0.5).floor()))
	else:canvas.draw_texture(texture,(center-size*0.5).floor())
	var flash: float = info.flash
	if flash > 0.0:
		var progress := 1.0 - flash
		var radius := lerpf(11.0, 29.0, progress)
		canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(GOLD, flash * 0.85), 2.0, true)
		for i in 8:
			var ray := Vector2.from_angle(TAU * i / 8.0)
			canvas.draw_line(center + ray * (radius + 3.0), center + ray * (radius + 3.0 + flash * 7.0), Color(GOLD, flash), 1.5, true)
		var text := "晋升·"+str(unit.veterancy_status().name)
		canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-28, -25 - progress * 17), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(GOLD, minf(1.0, flash * 2.0)))
	Iso.begin(canvas)
