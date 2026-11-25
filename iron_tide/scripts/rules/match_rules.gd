extends RefCounted
class_name MatchRules
## Independent mode policy. No reference-project implementation is imported.

const EXTENDED := "iron_tide"
const RA2 := "ra2"

static func normalize(mode: String) -> String:
	return RA2 if mode == RA2 else EXTENDED

static func neutral_bonuses() -> Dictionary:
	return {
		"attack_bonus": 1.0, "defense_bonus": 1.0, "hp_bonus": 1.0,
		"speed_bonus": 1.0, "build_bonus": 1.0, "income_bonus": 1.0,
		"cap_bonus": 1.0, "deploy_bonus": 0.0, "ore_delivery_bonus": 1.0
	}

static func entity_data(mode: String, runtime: Dictionary, source: Dictionary) -> Dictionary:
	if mode != RA2 or runtime.is_empty():
		return runtime
	# A copy prevents entering RA2 from modifying the extension-mode catalog.
	var out := runtime.duplicate(true)
	for key in ["hp", "cost"]:
		if source.get(key) != null:
			out[key] = source[key]
	out["trickle"] = 0.0
	out["deploy_attack_mult"] = 1.0
	out["deploy_defense_mult"] = 1.0
	out.erase("abilities")
	out.erase("_hp_mult")
	out.erase("_attack_mult")
	return out
