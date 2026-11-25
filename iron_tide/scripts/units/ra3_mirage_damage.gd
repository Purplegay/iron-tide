class_name Ra3MirageDamage
extends RefCounted
## Cross-game adapter approved by the user; never rewrite Yuri target stats.
static var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_mirage_targets.json"))

static func profile(target) -> Dictionary:
	if not is_instance_valid(target) or not (target is Unit or target is Building): return {}
	if target is Unit and target.data.get("veteran",{}).get("native_ra3",false): return {}
	if target is Unit and target.data.get("ra3_native",false): return {}
	var id: String = target.unit_id if target is Unit else target.building_id
	var category := "building" if target is Building else ("naval" if target.is_naval else ("infantry" if AlliedAbilities.infantry(target) else "vehicle"))
	return reference.profiles[reference.mapping.get(id,reference.fallback[category])]

static func raw_damage(weapon: Dictionary, target) -> float:
	var row := profile(target)
	var damage := float(weapon.get("damage",0.0))
	if row.is_empty(): return damage
	# Baseline config, never current/max HP: wounds and health upgrades must not
	# change outgoing damage. Generic/Yuri armor is replaced, not applied twice.
	var hp := float(target.data.get("hp",row.hp))
	return damage*float(row.prism_multiplier)*hp/float(row.hp)
