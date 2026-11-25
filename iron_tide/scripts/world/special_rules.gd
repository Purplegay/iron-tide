extends RefCounted
## Local rulesmd/artmd facts, separate from original-engine implementation.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/special_mechanics.json"))
	return _data

static func building(id: String) -> Dictionary:
	return data().buildings.get(id, {})

static func general(key: String, fallback: float) -> float:
	return float(data().general.get(key.to_lower(), fallback))
