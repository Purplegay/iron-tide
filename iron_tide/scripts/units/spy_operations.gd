extends RefCounted
const Rules = preload("res://scripts/core/yr_death_rules.gd")

static func supported(target) -> bool:
	var row := Rules.type_data(target.building_id)
	return GameData._ra2_flag(row.get("spyable")) and (GameData._ra2_flag(row.get("radar")) or not target.superweapon.is_empty())

static func resolve(world, target, victim: String) -> void:
	if GameData._ra2_flag(Rules.type_data(target.building_id).get("radar")):
		if world.fog != null: world.fog.reset_exploration(victim)
	elif not target.superweapon.is_empty():
		target._sw_charge = 0.0
		target._sw_was_ready = false
		SupportSystems.sync_charge(target)
		target.queue_redraw()
