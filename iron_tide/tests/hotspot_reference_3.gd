# Frozen v0.30.46 function: independent before-change oracle.
extends RefCounted
const EMPTY_LOOKUP:Dictionary={}
static func source(unit) -> Dictionary:
	var rows: Dictionary = GameData.allied_capabilities.get("units", EMPTY_LOOKUP)
	if rows.has(unit.unit_id): return rows[unit.unit_id]
	return GameData.ra2_source_units.get(unit.unit_id, EMPTY_LOOKUP).get("extra", {})

static func flag(unit,key:String) -> bool:
	return GameData._ra2_flag(source(unit).get(key,false))
