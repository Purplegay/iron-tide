extends RefCounted
# Pre-optimization full scans retained as the independent differential oracle.
const Ra3Mirage = preload("res://scripts/units/ra3_mirage.gd")

static func concealed(unit: Unit, observer: String) -> bool:
	if unit.special.has("contact_reporters") and Unit.FactionCards.contact_exposes(unit,observer):return false
	if unit.side != observer and unit.special.has("echo_cloaked"): return true
	if not BattleRequest.friendly(unit.side,observer) and float(unit.special.get("progression_v1",{}).get("dive_cloak",0))>0:return true
	if Ra3Mirage.field_conceals(unit, observer): return true
	if unit.side == observer or float(unit.special.get("reveal", 0.0)) > 0.0: return false
	var hidden: bool = Ra3Mirage.disguised(unit) or unit.special.has("disguise") or unit.unit_id == "MGTK" and AlliedAbilities.mirage_at_rest(unit)
	if not hidden: return false
	var world = unit._battle_world()
	if world == null: return false
	for other in unit.get_tree().get_nodes_in_group("disguise_detectors"):
		if other.side != observer or other.embarked_in != null or not AlliedAbilities.alive(other) or not world.is_ancestor_of(other): continue
		if other.sight > 0.0 and other.global_position.distance_squared_to(unit.global_position) <= other.sight * other.sight: return false
	if unit.unit_id == "MGTK":
		for other in unit.get_tree().get_nodes_in_group("disguise_contact_infantry"):
			if other.is_in_group("disguise_detectors"): continue
			if other.side != observer or other.embarked_in != null or not AlliedAbilities.alive(other) or not world.is_ancestor_of(other): continue
			if other.global_position.distance_squared_to(unit.global_position) <= 55.0 * 55.0: return false
	return true


static func return_slot(unit: Unit, airport) -> int:
	var ammo_max := unit.logistics.ammo_max
	var carrier_owner = unit.logistics.carrier_owner
	var home = unit.logistics.home
	var dock_slot := unit.logistics.dock_slot
	if ammo_max <= 0 or is_instance_valid(carrier_owner) or not unit.is_air: return -1
	if not is_instance_valid(airport) or not airport is Building or airport.hp <= 0.0 \
			or airport.is_queued_for_deletion() or airport.side != unit.side or airport.under_construction: return -1
	var allowed: PackedStringArray = str(unit.logistics.source.get("Dock", "GAAIRC,AMRADR")).split(",")
	if not allowed.has(airport.building_id): return -1
	var world = unit._battle_world()
	if world == null: return -1
	var docks := int(GameData.ra2_source_buildings.get(airport.building_id, {}).get("extra", {}).get("NumberOfDocks", 0))
	# Keep a plane's own reservation when clicking its current airfield.
	var slots: Array = range(docks)
	if home == airport and dock_slot in slots:
		slots.erase(dock_slot)
		slots.push_front(dock_slot)
	for slot in slots:
		var busy := false
		for other in world.units:
			if is_instance_valid(other) and other != unit and other.hp > 0.0 and not other.is_queued_for_deletion() \
					and other.logistics.home == airport and other.logistics.dock_slot == slot:
				busy = true
				break
		if not busy: return slot
	return -1

