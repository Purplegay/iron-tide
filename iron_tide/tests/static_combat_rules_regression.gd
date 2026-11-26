extends Node

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	for id: String in GameData.ra2_projectiles:
		var extra: Dictionary = GameData.ra2_projectiles[id].get("extra", {})
		var rule := GameData.projectile_combat_rule(id.to_upper())
		check(GameData.projectile_blocks_ground(id.to_upper()) == (str(extra.get("AG", "yes")).to_lower() in ["no", "false", "0"]), id + ": AG")
		check(rule.subject_to_walls == GameData._ra2_flag(extra.get("SubjectToWalls")), id + ": walls")
		check(rule.shrapnel_weapon == str(extra.get("ShrapnelWeapon", "")) and rule.shrapnel_count == int(extra.get("ShrapnelCount", 0)) and rule.drop_accel == maxf(1.0, float(extra.get("Acceleration", 1))), id + ": shrapnel/drop")
	for id: String in GameData.ra2_warheads:
		var row: Dictionary = GameData.ra2_warheads[id]
		if row.is_empty(): continue
		var rule := GameData.warhead_combat_rule(id.to_upper())
		var extra = row.get("extra")
		if not extra is Dictionary: extra = {}
		for pair in [["mind_control", "MindControl"], ["temporal", "Temporal"], ["radiation", "Radiation"], ["wall_absolute_destroyer", "WallAbsoluteDestroyer"]]:
			check(rule[pair[0]] == GameData._ra2_flag(Ra2Damage._extra(id, pair[1])), id + ": " + pair[1])
		for pair in [["rocker", "Rocker"], ["sparky", "Sparky"], ["bright", "Bright"], ["em_effect", "EMEffect"]]:
			check(rule[pair[0]] == (Ra2Damage._extra(id, pair[1]).to_lower() == "yes"), id + ": " + pair[1])
		for pair in [["wall", "Wall"], ["wood", "Wood"]]:
			check(rule[pair[0]] == GameData._ra2_flag(row.get(pair[0], extra.get(pair[1], false))), id + ": " + pair[1])
		check(rule.causes_death_weapon == (Ra2Damage._extra(id, "CausesDeathWeapon").to_lower() in ["yes", "true", "1"]), id + ": CausesDeathWeapon")
		check(GameData.warhead_blocks_friendly_damage(id) == (Ra2Damage._extra(id, "AffectsAllies").to_lower() in ["no", "false", "0"]), id + ": AffectsAllies")
		var deform := float(Ra2Damage._extra(id, "Deform").replace("%", "").strip_edges())
		check(rule.deform_ratio == (deform / 100.0 if deform > 1.0 else deform) and rule.deform_threshold == float(Ra2Damage._extra(id, "DeformThreshhold").strip_edges()), id + ": Deform")
		var anims = row.get("anim_list")
		var expected: Array = []
		if anims is Array:
			expected = anims
		elif anims != null:
			for name in str(anims).split(","):
				var clean := name.strip_edges()
				if not clean.is_empty(): expected.append(clean)
		check(GameData.ra2_impact_anims(id) == expected, id + ": AnimList")
		for pair in [["cell_spread", 0.0], ["percent_at_max", 1.0], ["prone_damage", 1.0]]:
			var value = row.get(pair[0])
			check(rule[pair[0]] == (pair[1] if value == null or str(value) == "" else float(value)), id + ": " + pair[0])
	for id: String in GameData.ra2_weapons:
		var extra: Dictionary = GameData.ra2_weapons[id].get("extra", {})
		var rule := GameData.weapon_combat_rule(id.to_upper())
		for pair in [["sonic", "IsSonic"], ["rad_beam", "IsRadBeam"], ["laser", "IsLaser"], ["electric_bolt", "IsElectricBolt"]]:
			check(rule[pair[0]] == GameData._ra2_flag(extra.get(pair[1])), id + ": " + pair[1])
	var overrides: Dictionary = GameData.allied_capabilities.get("units", {})
	for id: String in GameData.ra2_source_units:
		var source: Dictionary = GameData.ra2_source_units[id].get("extra", {})
		check(GameData.unit_blocks_land_targeting(id) == (int(source.get("LandTargeting", 0)) == 1), id + ": LandTargeting")
		check(GameData.unit_naval_targeting(id) == int(source.get("NavalTargeting", 0)), id + ": NavalTargeting")
		check(GameData.unit_sonic_type_immune(id) == GameData._ra2_flag(source.get("TypeImmune")), id + ": TypeImmune")
		check(GameData.unit_blocks_warp(id) == (str(overrides.get(id, source).get("Warpable", "yes")).to_lower() in ["no", "false", "0"]), id + ": Warpable")
	var probe := "__static_combat_probe"
	var cases := [["NO", true], ["FaLsE", true], ["0", true], [false, true], [" no ", false], [null, false], ["yes", false]]
	for item in cases:
		GameData.ra2_projectiles[probe] = {"extra": {"AG": item[0]}}
		GameData.rebuild_static_combat_rules()
		check(GameData.projectile_blocks_ground(probe.to_upper()) == item[1], "AG spelling/default: %s" % str(item[0]))
	GameData.ra2_projectiles[probe] = {"extra": {"AG": "no"}}
	GameData.ra2_warheads[probe] = {"anim_list": " one, , two ", "extra": {"AffectsAllies": "no", "EMEffect": true}}
	GameData.rebuild_static_combat_rules()
	check(GameData.projectile_blocks_ground(probe) and GameData.warhead_blocks_friendly_damage(probe), "fixture compiled")
	check(GameData.ra2_impact_anims(probe) == ["one", "two"] and not GameData.warhead_combat_rule(probe).em_effect, "comma-list and literal yes semantics")
	GameData.reload()
	check(not GameData.projectile_blocks_ground(probe) and not GameData.warhead_blocks_friendly_damage(probe) and GameData.ra2_impact_anims(probe).is_empty(), "reload drops removed rules and restores defaults")
	check(GameData.weapon_is_sonic("SonicZap"), "reload restores native sonic weapon")
	print("Static combat rules: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
