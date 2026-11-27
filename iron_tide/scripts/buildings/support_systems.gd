class_name SupportSystems
extends RefCounted
## Independent continuous-map adapter; raw fields exported from local YR.
static var _rules: Dictionary = {}

static func shared_charge(source) -> bool:
	return source.sw_type() in ["AmerParaDrop","ParaDrop","ForceShield","SpyPlane"]

static func charge_controller(source, exclude_self := false):
	if not shared_charge(source): return source
	var fallback = null
	for other in source.get_tree().get_nodes_in_group("charge_sites_" + source.sw_type()):
		if exclude_self and other == source: continue
		if not source.battle.actor_alive(other) or other.battle != source.battle or other.side != source.side or other.under_construction: continue
		if other.is_operational(): return other
		if fallback == null: fallback = other
	return fallback

static func sync_charge(source) -> void:
	if not shared_charge(source): return
	for other in source.get_tree().get_nodes_in_group("charge_sites_" + source.sw_type()):
		if other == source or not source.battle.actor_alive(other) or other.battle != source.battle or other.side != source.side: continue
		other._sw_charge = source._sw_charge
		other._sw_was_ready = source._sw_was_ready

static func join_charge(source) -> void:
	if not shared_charge(source): return
	var existing = charge_controller(source,true)
	source._sw_charge = existing._sw_charge if existing != null else 0.0
	source._sw_was_ready = existing._sw_was_ready if existing != null else false

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/support_rules.json"))
	return _rules

static func general(key: String, fallback: float) -> float:
	var value := str(rules().general.get(key, fallback))
	return float(value.trim_suffix("%")) / (100.0 if value.ends_with("%") else 1.0)

static func gap_radius(building) -> float:
	var raw: Dictionary = rules().buildings.get(building.building_id, {})
	return float(raw.get("gapradiusincells", 0.0)) * 55.0 if GameData._ra2_flag(raw.get("gapgenerator")) else 0.0

static func satellite(building) -> bool:
	if building.building_id == "GASPYSAT" and is_instance_valid(building.battle) and building.battle.mission.get("id") == "yr_allied_first": return false
	return GameData._ra2_flag(rules().buildings.get(building.building_id, {}).get("spysat"))

static func apply_intelligence(fog) -> void:
	for b in fog.battle.buildings:
		if not is_instance_valid(b) or not satellite(b) or not b.is_operational(): continue
		fog.visible_cells[b.side].fill(1)
		fog.explored_cells[b.side].fill(1)
	# Gap denies satellite intelligence. Real nearby scouts reveal again below.
	for b in fog.battle.buildings:
		if not is_instance_valid(b): continue
		var radius := gap_radius(b)
		if radius <= 0.0 or not b.is_operational(): continue
		var observer := "enemy" if b.side == "ally" else "ally"
		var low := Vector2i((b.position - Vector2.ONE * radius) / fog.CELL).max(Vector2i.ZERO)
		var high := Vector2i((b.position + Vector2.ONE * radius) / fog.CELL).min(Vector2i.ONE * (fog.width - 1))
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				if (Vector2(x + 0.5, y + 0.5) * fog.CELL).distance_to(b.position) <= radius:
					fog.visible_cells[observer][y * fog.width + x] = 0
					fog.explored_cells[observer][y * fog.width + x] = 0

static func chrono_units(world, point: Vector2, side: String) -> Array:
	return preload("res://scripts/world/chronoshift.gd").actors(world, point, side)

static func chrono_move(building, destination: Vector2, origin := Vector2.INF) -> bool:
	return preload("res://scripts/world/chronoshift.gd").move(building, destination, origin)
static func storm_bolt(building, at: Vector2) -> void:
	storm_bolt_at(building.battle, building.superweapon.get("storm", {}), at)

static func storm_bolt_at(world, storm: Dictionary, at: Vector2, include_cloud := true) -> void:
	var clouds: Array = storm.get("clouds", ["WCCLOUD1", "WCCLOUD2", "WCCLOUD3"])
	var bolts: Array = storm.get("bolts", ["WCLBOLT1", "WCLBOLT2", "WCLBOLT3"])
	var host = world.effects_root
	var cloud = Ra2Fx.play(host, at, str(clouds.pick_random())) if include_cloud and not clouds.is_empty() else null
	if cloud != null:
		cloud.draw_offset = Vector2(0, -110)
		cloud.tint = Color(0.6, 0.68, 0.85, 0.88)
	var bolt = Ra2Fx.play(host, at, str(bolts.pick_random()), 1.0, true) if not bolts.is_empty() else null
	if bolt != null: bolt.draw_offset = Vector2(0, -50)
	Ra2Fx.play(host, at, str(storm.get("bolt_explosion", "EXPLOLB")), 1.0, true)
	var sound: String = storm.get("strike_sound", "")
	if not sound.is_empty(): Ra2Sfx.play(sound, at)

static func storm_damage(building, at: Vector2) -> void:
	var rules: Dictionary = building.superweapon.get("storm", {}).duplicate(true)
	rules.damage = float(rules.get("damage", 250.0)) * preload("res://scripts/rules/superweapon_damage.gd").multiplier(building.side)
	storm_damage_at(building.battle, rules, at, building)

static func storm_damage_at(world, storm: Dictionary, at: Vector2, source = null) -> void:
	var wh: String = storm.get("warhead", "IonWH")
	var radius := maxf(1.0, GameData.ra2_cell_spread(wh) * 55.0)
	preload("res://scripts/world/bridge_damage.gd").blast(world,at,float(storm.get("damage",250.0)),wh,radius,source)
	for actor in world.units + world.buildings:
		if not world.actor_alive(actor) or actor is Unit and actor.embarked_in != null: continue
		var distance: float = actor.position.distance_to(at)
		if distance > radius: continue
		var damage := Ra2Damage.target_damage(float(storm.get("damage", 250.0)), wh, actor, distance)
		actor.receive_hit(damage, "tesla", {}, source, wh)

static func draw_gap(building) -> void:
	if not building.selected: return
	var radius := gap_radius(building)
	if radius <= 0.0: return
	var points := PackedVector2Array()
	for i in 65: points.append(Iso.dir(Vector2.from_angle(TAU * i / 64.0) * radius))
	building.draw_polyline(points, Color(0.55, 0.45, 1.0, 0.7 if building.is_operational() else 0.2), 1.5, true)
