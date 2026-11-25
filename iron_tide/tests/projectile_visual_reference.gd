extends RefCounted
## Original artmd flags, independently rendered in Godot. No damage/flight changes.
const SPEC_PATH := "res://assets/ra2/fx/projectile_visuals.json"
const SPACING := 4.0
const MAX_POINTS := 48
static var _specs: Dictionary = {}

static func spec(image: String) -> Dictionary:
	if _specs.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
		if parsed is Dictionary: _specs = parsed.get("images", {})
	return _specs.get(image.to_upper(), {})

static func kind(shot) -> String:
	if shot.ra2_inviso or shot.is_sonic: return ""
	if str(shot.ra2_image).to_lower() in ["", "none", "<null>"]: return "fallback"
	var art := spec(shot.ra2_image)
	if GameData._ra2_flag(art.get("UseLineTrail")): return "line"
	var trailer: String = art.get("Trailer", "")
	if trailer.begins_with("BBBLE"): return "wake"
	if not trailer.is_empty(): return "smoke"
	return ""

static func record(shot) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(62)
	var trail_kind:=kind(shot)
	if trail_kind.is_empty(): return
	var at := visual_position(shot)
	var spacing := 8.0 if trail_kind == "line" else SPACING
	if shot._trail.is_empty():
		shot._trail.append(at)
		return
	var previous: Vector2 = shot._trail.back()
	var remaining: float = previous.distance_to(at)
	# Discontinuities (e.g. a restored/relocated actor) must not draw a map-wide line.
	if remaining > spacing * MAX_POINTS:
		shot._trail.clear()
		shot._trail.append(at)
		return
	var direction: Vector2 = previous.direction_to(at)
	while remaining >= spacing:
		preload("res://scripts/world/battle_call_counters.gd").iterations(62, 1)
		previous += direction * spacing
		shot._trail.append(previous)
		if shot._trail.size() > MAX_POINTS: shot._trail.pop_front()
		remaining -= spacing

static func draw_trail(shot) -> void:
	var trail_kind := kind(shot)
	if trail_kind.is_empty() or shot._trail.is_empty(): return
	var art := spec(shot.ra2_image)
	var color: Color = GameData._ra2_rgb(art.get("LineTrailColor", "216,216,255"))
	var decrement := maxf(1.0, float(art.get("LineTrailColorDecrement", 12))) / 255.0
	var points: Array[Vector2] = shot._trail.duplicate()
	points.append(visual_position(shot))
	paint_path(shot, points, trail_kind, color, decrement, shot.tail_color)

static func paint_path(canvas: Node2D, points: Array[Vector2], trail_kind: String, color: Color, decrement: float, tail_color: Color, fade_ticks: float = 0.0) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(63)
	preload("res://scripts/world/battle_call_counters.gd").iterations(63, points.size())
	if trail_kind == "line":
		_paint_line_trail(canvas, points, color, decrement, fade_ticks)
		return
	# Resolve the world and canvas transform once, rather than for every segment.
	var host:=canvas.get_parent()
	var world:=host.get_parent() if host!=null else null
	var fog_check:=world!=null and world.has_method("position_visible_to")
	var to_local_space:=canvas.global_transform.affine_inverse()
	var prior_index:=-1
	var prior_visible:=false
	for i in range(1, points.size()):
		var age := float(points.size() - i - 1) + fade_ticks
		var alpha := clampf(1.0 - age * decrement, 0.0, 1.0)
		if alpha <= 0.0: continue
		if fog_check:
			var from_visible:bool=prior_visible if prior_index==i-1 else world.position_visible_to("ally",points[i-1])
			prior_visible=world.position_visible_to("ally",points[i])
			prior_index=i
			if not from_visible or not prior_visible:continue
		# Iso.begin is active on Projectile: world vectors must use Iso.dir.
		var a := Iso.dir(to_local_space*points[i-1])
		var b := Iso.dir(to_local_space*points[i])
		match trail_kind:
			"fallback":
				if age < 6.0: canvas.draw_circle(b, 2.0, Color(tail_color, (1.0 - age / 6.0) * 0.5))
			"wake":
				canvas.draw_line(a, b, Color(0.65, 0.85, 1.0, alpha * 0.4), 2.0, true)
				if i % 3 == 0: canvas.draw_arc(b, 1.5 + age * 0.08, 0.0, TAU, 8, Color(0.8, 0.94, 1.0, alpha * 0.55), 1.0, true)
			"smoke":
				if i % 2 == 0: canvas.draw_circle(b, 2.0 + age * 0.14, Color(0.65, 0.65, 0.67, alpha * 0.45))

# Draw each contiguous visible run in two strokes (halo and core). A hidden
# point splits the run so the joined polyline cannot bridge a fog boundary.
static func _paint_line_trail(canvas: Node2D, points: Array[Vector2], color: Color, decrement: float, fade_ticks: float) -> void:
	var remaining := 1.0 / decrement - fade_ticks
	if remaining <= 0.0 or points.size() < 2: return
	var first := maxi(0, points.size() - 1 - ceili(remaining))
	var host := canvas.get_parent()
	var world := host.get_parent() if host != null else null
	var fog_check := world != null and world.has_method("position_visible_to")
	var to_local_space := canvas.global_transform.affine_inverse()
	var run := PackedVector2Array()
	var halo := PackedColorArray()
	var core := PackedColorArray()
	for i in range(first, points.size()):
		if fog_check and not world.position_visible_to("ally", points[i]):
			if run.size() >= 2:
				canvas.draw_polyline_colors(run, halo, 3.0, true)
				canvas.draw_polyline_colors(run, core, 1.2, true)
			run.clear()
			halo.clear()
			core.clear()
			continue
		var local := Iso.dir(to_local_space * points[i])
		if not run.is_empty() and run[-1].is_equal_approx(local): continue
		run.append(local)
		var age := float(points.size() - 1 - i) + fade_ticks
		var alpha := clampf(1.0 - age * decrement, 0.0, 1.0)
		halo.append(Color(color, alpha * 0.20))
		core.append(Color(color, alpha * 0.90))
	if run.size() >= 2:
		canvas.draw_polyline_colors(run, halo, 3.0, true)
		canvas.draw_polyline_colors(run, core, 1.2, true)

static func target_lift(shot) -> float:
	if shot.splinters.get("bomb_drop", false): return 0.0
	if shot.splinters.get("hero_air_shell", false):
		if AlliedAbilities.alive(shot.target) and shot.target.is_air_target(): return shot.target._visual_lift()
		return float(shot.splinters.get("visual_target_lift", 0.0))
	if is_instance_valid(shot.target):
		return Effects.hit_lift(shot.target)
	# Last known height survives target removal and a mid-flight save.
	return float(shot.splinters.get("visual_target_lift", 0.0))

static func lift_at(shot, point: Vector2) -> float:
	if shot.ra2_arcing: return shot._arc_z
	if not shot.ra2_homing or kind(shot) != "line" or shot._arc_len <= 0.0: return 0.0
	var travelled: float = shot._arc_from.distance_to(point)
	var remaining: float = point.distance_to(shot.target_point)
	var phase := travelled / maxf(0.01, travelled + remaining)
	return sin(PI * phase) * shot._arc_h + target_lift(shot) * phase

static func visual_position(shot) -> Vector2:
	if kind(shot) != "line": return shot.global_position
	return shot.global_position + RA2Art.art_dir(Vector2(0, -lift_at(shot, shot.global_position)))

static func sprite_frame(shot, count: int) -> int:
	if count < 32 or not GameData._ra2_flag(spec(shot.ra2_image).get("Rotates")): return 0
	var direction: Vector2 = Iso.dir(shot._heading)
	if not shot._trail.is_empty():
		var tangent: Vector2 = Iso.dir(visual_position(shot) - shot._trail.back())
		if tangent.length_squared() > 0.01: direction = tangent
	# Original DRAGON/MEDUSA: frame 0 north, 8 west, 16 south, 24 east.
	return posmod(int(round((-direction.angle() - PI * 0.5) * 32.0 / TAU)), 32)

static func detach(shot) -> void:
	if kind(shot) != "line" or shot._trail.size() < 2 or not shot.is_inside_tree(): return
	var tail = load("res://scripts/units/projectile_tail.gd").new()
	tail.points.assign(shot._trail)
	tail.points.append(visual_position(shot))
	var art := spec(shot.ra2_image)
	tail.color = GameData._ra2_rgb(art.get("LineTrailColor", "216,216,255"))
	tail.decrement = maxf(1.0, float(art.get("LineTrailColorDecrement", 12))) / 255.0
	tail.z_index = shot.z_index
	shot.get_parent().add_child(tail)
	tail.add_to_group("missile_tails")

static func segment_visible(shot, from: Vector2, to: Vector2) -> bool:
	var host: Node = shot.get_parent()
	var world: Node = host.get_parent() if host != null else null
	if world != null and world.has_method("position_visible_to"):
		return world.position_visible_to("ally", from) and world.position_visible_to("ally", to)
	return true
