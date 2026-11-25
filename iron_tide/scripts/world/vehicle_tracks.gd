class_name VehicleTracks
extends Node2D
## Cosmetic ground marks only. Never changes movement, collision or saved orders.
const TRACKED := ["R3MIRAGE", "R3FUTURE", "R3TESLA", "R3APOC", "MTNK", "TNKD", "SREF", "MGTK", "BFRT"]
const CHEVRON = preload("res://assets/cosmetics/chevron_track.svg")
const Arrow = preload("res://scripts/world/chevron_arrow.gd")
const STOP_DELAY := 0.25
const STEP := 5.0
const LIFETIME := 18.0
const LIMIT := 1600
const ROOT := "res://assets/ra3/mirage/presentation/"
var marks: Array = []
var clock := 0.0
var world
var _redraw_clock := 0.0
var _batches: Array[MultiMeshInstance2D] = []
var batch_updates := 0
const UPDATE_INTERVAL := 0.20

func _ready() -> void:
	# Fog rebuilds at priority 100. Filter the batch after its current visibility.
	process_priority = 110
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var half := STEP * 0.53
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-half,-3.2,0),Vector3(-half,3.2,0),Vector3(half,3.2,0),Vector3(half,-3.2,0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for texture in [tank_texture, tire_texture]:
		_add_batch(texture,mesh)

func _add_batch(texture:Texture2D,mesh:Mesh) -> void:
	var batch := MultiMeshInstance2D.new()
	batch.texture = texture
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = LIMIT
	batch.multimesh.visible_instance_count = 0
	add_child(batch)
	_batches.append(batch)

var tire_texture: Texture2D = load(ROOT+"EXTireTrack2.png")
var tank_texture: Texture2D = load(ROOT+"EXTnkTrack.png")

static func supports_tire_skin(id: String) -> bool:
	return id.begins_with("R3") and id in TRACKED

static func sample(unit, delta: float) -> void:
	if unit.unit_id not in TRACKED: return
	var chevron:bool=unit.side=="ally" and unit.unit_id.begins_with("R3") and MetaProgress.cosmetic_style(unit.unit_id).get("track")=="chevron_track"
	var current: Vector2 = unit.global_position
	var previous: Vector2 = unit.get_meta("track_position", current)
	var old_heading: float = unit.get_meta("track_heading", unit.hull_angle)
	unit.set_meta("track_position", current)
	unit.set_meta("track_heading", unit.hull_angle)
	var distance := current.distance_to(previous)
	var battle = unit._battle_world()
	if delta <= 0.0 or unit.special.has("walker_jump") or unit._dead or unit.embarked_in != null or unit.is_air or unit.is_naval or battle == null \
		or not unit.is_visible_in_tree() or not battle.actor_visible_to("ally", unit) or AlliedAbilities.concealed(unit,"ally") \
		or distance > maxf(80.0, unit.move_speed * delta * 4.0):
		unit.set_meta("track_remainder", 0.0)
		if unit.has_meta("chevron_stop"): unit.remove_meta("chevron_stop")
		return
	if not chevron and unit.has_meta("chevron_stop"): unit.remove_meta("chevron_stop")
	if distance < 0.001:
		if chevron and unit.has_meta("chevron_stop"):
			var left := float(unit.get_meta("chevron_stop")) - delta
			if left > 0.0:
				unit.set_meta("chevron_stop", left)
			else:
				unit.remove_meta("chevron_stop")
				var tracks: VehicleTracks = battle.get_node_or_null("VehicleTracks")
				if tracks != null: tracks.plant_arrow(unit)
		return
	var layer = battle.get_node_or_null("VehicleTracks")
	if layer == null:
		layer = VehicleTracks.new(); layer.name = "VehicleTracks"; layer.world = battle
		layer.z_as_relative = false; layer.z_index = DepthLayers.DECAL + 1
		battle.add_child(layer)
	var remainder: float = unit.get_meta("track_remainder", 0.0)
	var cursor := STEP - remainder
	if chevron and (cursor <= distance or unit.has_meta("chevron_stop")):
		unit.set_meta("chevron_stop", STOP_DELAY)
	while cursor <= distance:
		var fraction := cursor / distance
		var heading := lerp_angle(old_heading, unit.hull_angle, fraction)
		var forward := Vector2.RIGHT.rotated(heading)
		var lateral := forward.orthogonal()
		var center: Vector2 = previous.lerp(current, fraction) - forward * unit.radius * 0.6
		var spacing: float = 16.0 if unit.unit_id == "R3MIRAGE" else unit.radius * 0.65
		for sign in [-1, 1]:
			layer.add_mark(center + lateral * spacing * sign, heading, unit.unit_id.begins_with("R3"),chevron,unit.get_instance_id() if chevron else 0)
		cursor += STEP
	unit.set_meta("track_remainder", fmod(remainder + distance, STEP))

func plant_arrow(unit) -> void:
	var owner_id: int = unit.get_instance_id()
	var farthest: Dictionary = {}
	var best_distance := -1.0
	for mark: Dictionary in marks:
		if mark.get("owner_id",0) != owner_id or clock - float(mark.born) >= LIFETIME: continue
		var distance: float = unit.global_position.distance_squared_to(mark.position)
		if distance >= best_distance:
			best_distance = distance
			farthest = mark
	if farthest.is_empty(): return
	var arrow := Arrow.new()
	arrow.position = farthest.position
	arrow.heading = farthest.angle
	arrow.world = world
	arrow.visible = world.position_visible_to("ally",arrow.position)
	add_child(arrow)

func add_mark(point: Vector2, heading: float, ra3: bool,chevron:=false,owner_id:=0) -> void:
	if chevron and _batches.size()==2:_add_batch(CHEVRON,_batches[0].multimesh.mesh)
	marks.append({"position": point, "angle": heading, "born": clock, "ra3": ra3, "chevron":chevron,
		"transform": Transform2D(heading, point)})
	if chevron: marks.back().owner_id = owner_id
	while marks.size() > LIMIT: marks.pop_front()

func _process(delta: float) -> void:
	clock += delta
	while not marks.is_empty() and clock - float(marks[0].born) >= LIFETIME:
		marks.pop_front()
	_redraw_clock += BattleClock.control_delta(delta)
	# Sampling keeps every footprint. Only cosmetic GPU uploads/fading wait
	# for the 5 Hz presentation cadence, independent of simulation speed.
	if _redraw_clock + 0.000001 >= UPDATE_INTERVAL:
		_redraw_clock = 0.0
		_refresh_batches()

func _refresh_batches() -> void:
	if _batches.is_empty():return
	var counts := [0,0,0]
	var canvas := get_global_transform_with_canvas()
	var screen := get_viewport_rect().grow(24.0)
	for mark: Dictionary in marks:
		if not screen.has_point(canvas * mark.position): continue
		if not is_instance_valid(world) or not world.position_visible_to("ally",mark.position): continue
		var kind := 2 if mark.chevron else (1 if mark.ra3 else 0)
		var index: int = counts[kind]
		var multimesh := _batches[kind].multimesh
		multimesh.set_instance_transform_2d(index,mark.transform)
		var opacity := 0.8 * clampf((LIFETIME - (clock - float(mark.born))) / 5.0,0.0,1.0)
		multimesh.set_instance_color(index,Color(1,1,1,opacity))
		counts[kind] += 1
	for i in _batches.size(): _batches[i].multimesh.visible_instance_count = counts[i]
	batch_updates += 1
