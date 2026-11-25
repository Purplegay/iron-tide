extends RefCounted
## 451330 / 44EB10 / 707D20 / 442D90, verified against installed gamemd.exe.
## Quantity/type gates follow the binary; continuous safe exits replace cell slots.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Landing = preload("res://scripts/world/chronoshift.gd")
class ExitProbe extends RefCounted:
	var world
	var radius := 7.0
	func _domain_ok(point: Vector2) -> bool:
		return not world.in_water_world(point)

static func faction(building) -> String:
	var country := str(building.battle._countries.get(building.side, "Americans"))
	if country == "YuriCountry": return "third"
	if country in ["Russians", "Confederation", "Africans", "Arabs"]: return "soviet"
	return "allied"

static func count(building) -> int:
	var row := Rules.type_data(building.building_id)
	if building.under_construction or building.side not in ["ally", "enemy"] or not Rules.flag(row, "crewed") or building.special.get("no_crew", false): return 0
	var divisor := int(Rules.data().general.get(faction(building) + "survivordivisor", 0))
	if building.special.get("has_been_captured", false): divisor *= 2
	if divisor <= 0: return 0
	return clampi(int(GameData.ra2_refund(int(building.data.get("cost", 0))) / float(divisor)), 1, 5)

static func crew_id(building, rng: RandomNumberGenerator) -> String:
	var general: Dictionary = Rules.data().general
	var row := Rules.type_data(building.building_id)
	if not building.special.get("has_been_captured", false) and str(row.get("factory", "")) == "BuildingType" and rng.randi_range(0, 99) < 25:
		return str(general.get("engineer", "ENGINEER"))
	# Native IsArmed branch can yield a technician (15%); unarmed plants use crew.
	if not str(row.get("primary", "")).is_empty() and rng.randi_range(0, 99) < 15:
		return str(general.get("technician", "CTECH"))
	return str(general.get(faction(building) + "crew", "E1"))

static func eject(building) -> Array:
	var spawned := []
	if building.special.get("crew_ejected", false): return spawned
	building.special.crew_ejected = true
	var remaining := count(building)
	if remaining <= 0: return spawned
	var world = building.battle
	if not world.allied_state.has("crew_rng"):
		var fresh := RandomNumberGenerator.new(); fresh.randomize()
		world.allied_state.crew_rng = fresh
	var rng: RandomNumberGenerator = world.allied_state.crew_rng
	var random_max := 1 if building.special.get("yr_c4_death", false) else 2
	if building.special.get("has_been_captured", false): random_max += 6
	# Original iterates finite foundation exit cells, not unlimited retries.
	# Our continuous collision shapes use a bounded ring of possible exits.
	for i in 16:
		if remaining <= 0: break
		if rng.randi_range(0, random_max) != 1: continue
		var id := crew_id(building, rng)
		var definition := GameData.get_unit(id)
		if definition.is_empty(): continue
		var probe := ExitProbe.new()
		probe.world = world
		probe.radius = float(definition.get("radius", 7.0))
		var direction := Vector2.from_angle(i * TAU / 16.0)
		var point: Vector2 = building.position + direction * (building.footprint_clearance(direction) + probe.radius + 20.0)
		var clear := Landing.landing_clear(world, probe, point, [])
		if not clear: continue
		var unit = world.spawn_unit(id, building.side, point)
		if unit == null: continue
		unit.order_stop()
		unit.hp = float(rng.randi_range(5, maxi(5, int(unit.max_hp))))
		unit.special.escaped_crew = true
		spawned.append(unit); remaining -= 1
	return spawned
