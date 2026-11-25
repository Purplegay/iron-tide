extends Node2D
## Saved gameplay records + disposable renderer. All motion uses 15-tick YR units.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Blast = preload("res://scripts/core/yr_death_combat.gd")
const Fx = preload("res://scripts/core/yr_death_fx.gd")
const KEY := "yr_vehicle_debris"
const PX_PER_LEPTON := 55.0 / 256.0
var world
var textures: Dictionary = {}

static func rng_for(world) -> RandomNumberGenerator:
	if not world.allied_state.has("yr_debris_rng"):
		var rng := RandomNumberGenerator.new(); rng.randomize()
		world.allied_state.yr_debris_rng = rng
	return world.allied_state.yr_debris_rng

static func restore(world):
	var visual = world.effects_root.get_node_or_null("YrVehicleDebris")
	if visual == null:
		visual = load("res://scripts/core/yr_vehicle_debris.gd").new()
		visual.name = "YrVehicleDebris"; visual.world = world
		visual.z_as_relative = false; visual.z_index = DepthLayers.FX
		visual.add_to_group("per_piece_fog_visibility")
		world.effects_root.add_child(visual)
	return visual

static func spawn(unit) -> void:
	var building: bool = unit is Building
	var row := Rules.type_data(unit.building_id if building else unit.unit_id)
	var world = unit.battle if building else unit._battle_world()
	if world == null: return
	spawn_at(world,row,unit.global_position,unit.side,0.0 if building else unit._visual_lift(),building)

static func spawn_at(world, row: Dictionary, point: Vector2, side: String, height: float, building: bool) -> void:
	if row.get("native_category", "") not in ["VehicleTypes", "AircraftTypes", "BuildingTypes"]: return
	var rng := rng_for(world)
	var maximum := clampi(int(row.get("maxdebris", 0)), 0, 32)
	# An intercepted V3 or Dread missile always sheds at least one original scrap voxel.
	var minimum := int(row.get("mindebris", 0))
	if Rules.flag(row, "missilespawn"): minimum = maxi(minimum, 1)
	var count := rng.randi_range(clampi(minimum, 0, maximum), maximum)
	var damages := str(row.get("debrisdamages", "yes")).to_lower() not in ["no", "false", "0"]
	if building:
		var animations := Rules.names(row, "debrisanims")
		if animations.is_empty(): animations = Rules.names(row, "debrisanim")
		animations.assign(animations.filter(func(id): return Rules.data().animations.has(id)))
		if animations.is_empty(): return
		for i in count: launch(world, animations[rng.randi_range(0, animations.size()-1)], point, side, 12.0, damages, "shp")
		return
	var declared := Rules.names(row, "debristypes")
	var caps := str(row.get("debrismaximums", "")).split(",")
	var used := {}
	var defaults := Rules.names(Rules.data().general, "explosivevoxeldebris" if Rules.flag(row, "explodes") else "scrapvoxeldebris")
	for i in count:
		var eligible: Array[String] = []
		for n in declared.size():
			if n < caps.size() and int(used.get(declared[n], 0)) < int(caps[n]) and Rules.data().voxels.has(declared[n]): eligible.append(declared[n])
		if eligible.is_empty(): eligible.assign(defaults.filter(func(id): return Rules.data().voxels.has(id)))
		if eligible.is_empty(): continue
		var id: String = eligible[rng.randi_range(0, eligible.size() - 1)]
		used[id] = int(used.get(id, 0)) + 1
		launch(world, id, point, side, maxf(8.0, height), damages)

static func launch(world, id: String, point: Vector2, side: String, height := 8.0, damages := true, kind := "vxl") -> Dictionary:
	var entry: Dictionary = Rules.data().get("animations" if kind == "shp" else "voxels", {}).get(id, {})
	if entry.is_empty(): return {}
	var raw: Dictionary = entry.raw
	var rng := rng_for(world)
	var speed := float(raw.get("maxxyvel", 0)) * PX_PER_LEPTON * 15.0
	var state := {"id": id, "kind": kind, "point": point, "side": side, "age": 0.0, "lift": height, "damages": damages,
		"velocity": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.35, 1.0) * speed,
		"vz": rng.randf_range(float(raw.get("minzvel", 0)), float(raw.get("maxzvel", raw.get("minzvel", 0)))) * PX_PER_LEPTON * 15.0,
		"spin": rng.randf_range(float(raw.get("minangularvelocity", 0)), float(raw.get("maxangularvelocity", 0))) * PI / 180.0 * 15.0,
		"phase": rng.randf_range(0.0, TAU), "facing": rng.randi_range(0, 15), "bounces": 0, "next_smoke": 0.0}
	var rates := str(raw.get("randomrate", "900,900")).split(",")
	state.fps = rng.randf_range(float(rates[0]), float(rates[-1])) / 60.0
	if not world.allied_state.has(KEY): world.allied_state[KEY] = []
	world.allied_state[KEY].append(state)
	restore(world)
	return state

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world): queue_free(); return
	if world.paused or world.ended or get_tree().paused: return
	# Keep integration stable on slow frames; gameplay never depends on visibility.
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 60.0)
		advance(step)
		remaining -= step
	queue_redraw()

func advance(delta: float) -> void:
	var states: Array = world.allied_state.get(KEY, [])
	# Damage can append debris through a chain explosion. Remove only spent items.
	for state in states.duplicate():
		var entry: Dictionary = Rules.data().get("animations" if state.get("kind", "vxl") == "shp" else "voxels")[state.id]
		var raw: Dictionary = entry.raw
		state.age += delta
		state.point += state.velocity * delta
		state.vz -= float(Rules.data().gravity) * PX_PER_LEPTON * 225.0 * delta
		state.lift += state.vz * delta
		if not str(raw.get("traileranim", "")).is_empty() and state.age >= float(state.get("next_smoke", 0.0)):
			var smoke = Fx.play(world, state.point, str(raw.traileranim).to_upper())
			if smoke != null: smoke.lift = maxf(0.0, state.lift)
			state.next_smoke = state.age + maxf(1.0, float(raw.get("trailerseperation", 2))) / 15.0
		var expired: bool = state.age >= maxf(1.0, float(raw.get("duration", 75))) / 15.0
		var impact: bool = state.lift <= 0.0
		if not expired and not impact: continue
		var elasticity := clampf(float(raw.get("elasticity", 0)), 0.0, 1.0)
		var water: bool = world.in_water_world(state.point)
		if impact and not expired and not water and elasticity > 0.0 and absf(float(state.vz)) > 12.0 and int(state.bounces) < 8:
			state.lift = 0.0; state.vz = absf(float(state.vz)) * elasticity
			state.velocity *= elasticity; state.bounces += 1
			continue
		states.erase(state) # Consumption precedes any reentrant damage callbacks.
		if water: continue
		var animation := str(raw.get("expireanim", "")).to_upper()
		if not animation.is_empty(): Fx.play(world, state.point, animation)
		# ExpireAnim already supplies the original impact; do not layer a second blast.
		if state.damages: Blast.queue_blast(world, state.point, state.side, float(raw.get("damage", 0)), str(raw.get("warhead", "")), "", false)

func _draw() -> void:
	Iso.begin(self)
	for state in world.allied_state.get(KEY, []):
		if not world.position_visible_to("ally", state.point): continue
		var shp: bool = state.get("kind", "vxl") == "shp"
		var art: Dictionary = Rules.data().get("animations" if shp else "voxels")[state.id]
		if not textures.has(state.id): textures[state.id] = load("res://assets/ra2/death/" + str(state.id) + ".png")
		var texture: Texture2D = textures[state.id]
		var pose := posmod(int((float(state.phase) + float(state.spin) * float(state.age)) / TAU * 8.0), 8)
		var frame := posmod(int(float(state.age) * float(state.fps)), int(art.count)) if shp else pose * 16 + int(state.facing)
		var rect: Dictionary = art.rects[frame]
		var point := Iso.dir(state.point)
		draw_set_transform(Vector2.ZERO, Iso.eff_angle(), Iso.up())
		draw_ellipse_shadow(point, 3.0)
		var size := Vector2(float(art.cell[0]), float(art.cell[1]))
		var origin := size * 0.5 if shp else Vector2(float(art.origin[0]), float(art.origin[1]))
		draw_texture_rect_region(texture, Rect2(point - origin - Vector2(0, maxf(0, state.lift)), size), Rect2(rect.x, rect.y, rect.w, rect.h))

func draw_ellipse_shadow(point: Vector2, radius: float) -> void:
	draw_circle(point, radius, Color(0, 0, 0, 0.2))
