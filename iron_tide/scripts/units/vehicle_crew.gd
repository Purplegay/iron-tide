extends RefCounted
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Crew = preload("res://scripts/buildings/building_crew.gd")

static func eject(unit) -> Array:
	var result := []
	# Only non-flying vehicles can leave escape crew. Airframes stay excluded
	# when parked, and helicopters may appear under native VehicleTypes.
	if unit.is_air: return result
	var row := Rules.type_data(unit.unit_id)
	if row.get("native_category", "") != "VehicleTypes": return result
	if unit.special.get("yr_driver_checked", false): return result
	unit.special.yr_driver_checked = true
	if not Rules.flag(row, "crewed") or unit.side not in ["ally", "enemy"] or unit.special.get("no_crew", false): return result
	var world = unit._battle_world()
	if world == null: return result
	if not world.allied_state.has("crew_rng"):
		var fresh := RandomNumberGenerator.new(); fresh.randomize()
		world.allied_state.crew_rng = fresh
	var rng: RandomNumberGenerator = world.allied_state.crew_rng
	var chance := str(Rules.data().general.get("crewescape", "50%"))
	var probability := float(chance.trim_suffix("%")) / (100.0 if chance.ends_with("%") else 1.0)
	if rng.randf() >= clampf(probability, 0.0, 1.0): return result
	var country := str(world._countries.get(unit.side, "Americans"))
	var faction := "third" if country == "YuriCountry" else "soviet" if country in ["Russians", "Confederation", "Africans", "Arabs"] else "allied"
	var id := str(Rules.data().general.get(faction + "crew", "E1"))
	if not str(row.get("primary", "")).is_empty() and rng.randi_range(0, 99) < 15: id = str(Rules.data().general.get("technician", "CTECH"))
	var definition := GameData.get_unit(id)
	if definition.is_empty(): return result
	var probe := Crew.ExitProbe.new(); probe.world = world
	probe.radius = float(definition.get("radius", 7.0))
	var start := rng.randf_range(0.0, TAU)
	for i in 16:
		var point: Vector2 = unit.global_position + Vector2.from_angle(start + i * TAU / 16.0) * (unit.radius + probe.radius + 12.0)
		if not Crew.Landing.landing_clear(world, probe, point, [unit]): continue
		var survivor = world.spawn_unit(id, unit.side, point)
		if survivor == null: break
		survivor.order_stop()
		survivor.hp = float(rng.randi_range(5, maxi(5, int(survivor.max_hp))))
		survivor.special.escaped_crew = true
		survivor.special.escaped_driver = true
		result.append(survivor)
		break # TechnoClass::GetCrewCount returns 1 iff Crewed.
	return result
