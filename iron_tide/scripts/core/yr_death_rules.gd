extends RefCounted
## Original rules/art fields. Missing engine defaults stay explicit audit gaps.
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra2/death.json"))
	return _data

static func type_data(id: String) -> Dictionary:
	return data().get("types", {}).get(id.to_upper(), {})

static func flag(row: Dictionary, field: String) -> bool:
	return str(row.get(field, "")).to_lower() in ["yes", "true", "1"]

static func names(row: Dictionary, field: String) -> Array[String]:
	var result: Array[String] = []
	for item in str(row.get(field, "")).split(",", false): result.append(item.strip_edges().to_upper())
	return result

static func infantry_effect(kind: int) -> String:
	if kind == 5: return "ELECTRO"
	var key: String = {3:"infantryexplode", 4:"flaminginfantry", 6:"infantryheadpop", 7:"infantrynuked", 10:"infantrybrute"}.get(kind, "")
	return str(data().general.get(key, "")).to_upper()
