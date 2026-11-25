extends Node
## Read-only runtime catalog audit. Resource presence is not mechanism acceptance.

func fx_status(names: Array) -> Dictionary:
	var missing: Array = []
	for name in names:
		if RA2Art.fx(str(name)).is_empty(): missing.append(name)
	return {"requested": names, "missing": missing}

func weapon_status(weapon: Dictionary) -> Dictionary:
	var wid := str(weapon.get("ra2_weapon_id", ""))
	var wh := str(weapon.get("ra2_warhead", ""))
	var pid := str(weapon.get("ra2_projectile", ""))
	var projectile := GameData.ra2_projectile(pid)
	var image := "" if projectile.get("image") == null else str(projectile.image)
	return {"id": wid, "runtime": weapon, "raw_weapon": GameData.ra2_weapon(wid),
		"raw_warhead": GameData.ra2_warheads.get(wh.to_lower(), {}), "raw_projectile": projectile,
		"muzzle": fx_status(GameData.ra2_muzzle_anims(wid)), "impact": fx_status(GameData.ra2_impact_anims(wh)),
		"beam": GameData.ra2_beam_spec(wid),
		"projectile_image": image, "projectile_visible": projectile.get("inviso") != true,
		"projectile_art_available": not image.is_empty() and not RA2Art.fx(image).is_empty(),
		"report": str(weapon.get("report", "")),
		"sound_files": GameData.ra2_sound_files(str(weapon.get("report", "")))}

func _ready() -> void:
	var output := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	BattleRequest.configure_skirmish(MatchRules.RA2, {})
	var rows: Array = []
	for entry in GameData.units:
		var id := str(entry.id)
		var unit := GameData.get_unit(id)
		var weapons: Dictionary = {}
		for key in ["weapon", "elite_weapon", "deployed_weapon", "elite_deployed_weapon"]:
			if unit.get(key) is Dictionary and not unit[key].is_empty(): weapons[key] = weapon_status(unit[key])
		var veteran: Dictionary = unit.get("veteran", {})
		if veteran.get("elite_weapon") is Dictionary and not veteran.elite_weapon.is_empty():
			weapons["veteran.elite_weapon"] = weapon_status(veteran.elite_weapon)
		rows.append({"id": id, "name": str(unit.get("name", id)), "faction": unit.get("faction", ""),
			"raw_unit": GameData.ra2_source_units.get(id, {}), "weapons": weapons,
			"extension_defaults": GameData.skill_defaults.get(id, {}), "deployer": unit.get("deployer", false)})
	var buildings: Array = []
	for entry in GameData.buildings:
		var unit := GameData.get_building(str(entry.id))
		buildings.append({"id": entry.id, "name": unit.get("name", ""), "data": unit,
			"weapon": weapon_status(unit.weapon) if unit.get("weapon") is Dictionary else {}})
	var file := FileAccess.open(output.path_join("capabilities.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"units": rows, "buildings": buildings, "extension_skills": GameData.skills,
		"boundary": "runtime data/resource audit; no claim of original special-mechanism or visual parity"}, "  "))
	file.close()
	file = FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed": 0, "checks": [{"name": "catalog exported", "passed": not rows.is_empty()}], "units": rows.size(), "buildings": buildings.size()}))
	file.close()
	get_tree().quit()
