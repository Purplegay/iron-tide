extends RefCounted
## Stable values, not UI indices. Never deserialize into BattleRequest or MetaProgress.
const PATH := "user://lobby_preferences.cfg"
const OPTIONS := {
	"rules_mode": ["ra2", "iron_tide"],
	"opening": ["prebuilt", "mcv"],
	"victory_condition": ["short", "annihilation"],
	"map_size": [2400, 3200, 4000],
	"map_layout": preload("res://scripts/world/skirmish_maps.gd").IDS,
	"starting_funds": [4000, 8000, 10000, 12000, 20000, 30000, 50000],
	"enemy_base": ["allied", "swarm", "soviet", "yuri"],
	"difficulty": [0, 1, 2, 3, 4, 5, 6],
	"enemy_country": ["美国", "韩国", "法国", "德国", "英国", "苏俄", "古巴", "伊拉克", "利比亚", "尤里", "虫群巢穴"],
	"country": ["美国", "韩国", "法国", "德国", "英国", "苏俄", "古巴", "伊拉克", "利比亚", "尤里"],
	"fog_of_war": [true, false],
}
const DEFAULTS := {
	"rules_mode": "iron_tide", "opening": "prebuilt", "victory_condition": "short",
	"map_size": 3200, "map_layout": "coast", "starting_funds": 10000, "enemy_base": "allied",
	"difficulty": 1, "country": "美国", "enemy_country": "美国", "fog_of_war": true,
}

static func enemy_base_for(country: String) -> String:
	if country == "尤里": return "yuri"
	if country == "虫群巢穴": return "swarm"
	return "soviet" if country in ["苏俄", "古巴", "伊拉克", "利比亚"] else "allied"

static func normalize(values: Dictionary) -> Dictionary:
	var clean := DEFAULTS.duplicate()
	for key in OPTIONS:
		var value: Variant = values.get(key)
		if typeof(value) == typeof(DEFAULTS[key]) and value in OPTIONS[key]:
			clean[key] = value
	if not values.get("enemy_country") in OPTIONS.enemy_country:
		clean.enemy_country = "苏俄" if clean.enemy_base == "soviet" else "尤里" if clean.enemy_base == "yuri" else "虫群巢穴" if clean.enemy_base == "swarm" else "美国"
	if clean.rules_mode == "ra2":
		if clean.enemy_country == "虫群巢穴": clean.enemy_country = "美国"
	else:
		clean.opening = "prebuilt"
	if clean.opening == "mcv":
		clean.starting_funds = maxi(8000, clean.starting_funds)
	clean.enemy_base = enemy_base_for(clean.enemy_country)
	return clean

static func read() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULTS.duplicate()
	var values := {}
	for key in OPTIONS:
		if config.has_section_key("lobby",key): values[key] = config.get_value("lobby", key)
	return normalize(values)

static func write(values: Dictionary, config: ConfigFile = null) -> Error:
	if config == null:
		config = ConfigFile.new()
		config.load(PATH) # Keep map-specific selections when only lobby defaults change.
	var clean := normalize(values)
	for key in clean:
		config.set_value("lobby", key, clean[key])
	# Replace only after a complete write, preserving the old file on save failure.
	var error := config.save(PATH + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(PATH + ".tmp", PATH)
