extends "res://tests/base_recovery_regression.gd"

var original: Dictionary
const ARMORS := ["none", "flak", "plate", "light", "medium", "heavy", "wood", "steel", "concrete", "special_1", "special_2"]

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	original = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/yr_damage_source.json"))
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		GM.god_mode = false
		GM.one_shot_kill = false
		battle.power_low = false
		battle.enemy_power.low = false
		check_catalog()
		await impact_timing_cases()
		for side in ["ally", "enemy"]:
			for instant in [false, true]:
				await hit_case("E1", "GGI", side, instant)
				await hit_case("E1", "GGI", side, instant, true)
				await hit_case("E1", "E1", side, instant, true, true)
				await hit_case("MTNK", "GGI", side, instant)
				await hit_case("MTNK", "MTNK", side, instant, false, false, 2, 1)
				await hit_case("MGTK", "MTNK", side, instant, false, false, 0, 0, 2.0)
				await hit_case("SREF", "GAPOWR", side, instant, false, false, 0, 0, 2.0)
				await hit_case("TANY", "GGI", side, instant)
			await splash_case(side)
			await prism_case(side)
		await armor_matrix()
		await critical_case()
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "original_rules_sha256": original.rules_sha256}, "  "))
	f.close()
	print("YR_DAMAGE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func raw_id(value: String) -> String:
	return value.trim_prefix("YR_").trim_prefix("ROBO_").trim_prefix("CAP_")

func impact_timing_cases() -> void:
	# Expectations come from the installed YR INI, not the runtime Inviso flag.
	for side in ["ally", "enemy"]:
		var other: String = "enemy" if side == "ally" else "ally"
		for spec in [["SREF", 0], ["SREF", 2], ["ATESLA", 0], ["E1", 0], ["MGTK", 0], ["MTNK", 0], ["FV", 0]]:
			for distance in [100.0, 300.0]:
				for target_id in ["MTNK", "GAPOWR"]:
					var shooter = actor(spec[0], side, Vector2(1200, 1200))
					if shooter is Unit: shooter._grant_veteran(spec[1], false)
					shooter.bonuses = {}
					var victim = actor(target_id, other, Vector2(1200 + distance, 1200))
					victim.hp = 10000.0
					var w: Dictionary = shooter._active_weapon() if shooter is Unit else shooter.weapon
					var raw: Dictionary = original.weapons[raw_id(w.ra2_weapon_id)]
					var source_projectile: Dictionary = original.projectiles[raw.projectile]
					var instant: bool = source_projectile.get("inviso", "no").to_lower() == "yes"
					var label: String = prefix + "%s/%s -> %s %s %.0f: " % [spec[0], raw_id(w.ra2_weapon_id), target_id, side, distance]
					check((GameData.ra2_projectile(w.ra2_projectile).get("inviso") == true) == instant,
						label + "runtime projectile matches original Inviso")
					var old: Array = battle.projectiles_root.get_children()
					var old_fx: Array = Effects._host().get_children()
					if shooter is Building:
						shooter.attack_target = victim
						check(shooter._fire(), label + "real tower fires")
					else:
						shooter._fire_shot(victim)
					var shots: Array = battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p))
					var expected := original_hit(w.ra2_weapon_id, target_id, false, 1.0, 1.0)
					check(10000.0 - victim.hp == (expected if instant else 0.0),
						label + "damage timing follows original projectile", {"actual": 10000.0 - victim.hp, "expected_now": expected if instant else 0.0})
					if raw.get("islaser", "false") in ["true", "yes"]:
						var beams: Array = Effects._host().get_children().filter(func(fx): return fx is Effects.Beam and not old_fx.has(fx))
						check(beams.size() == 1 and beams[0].t == 0.0, label + "beam starts in the damage frame")
						for beam in beams: beam._process(beam.duration + 0.1)
						check(10000.0 - victim.hp == expected, label + "beam expiry cannot delay or repeat damage")
					check(shots.size() == 1, label + "one projectile keeps shared warhead resolution")
					if instant:
						for shot in shots:
							check(shot.is_queued_for_deletion() and shot.global_position == victim.global_position,
								label + "Inviso already detonated at target")
							shot._physics_process(1.0)
							shot._explode()
					else:
						fly(shots)
					check(10000.0 - victim.hp == expected, label + "exactly one original damage result after time advances")
					remove_actor(shooter)
					remove_actor(victim)
					await get_tree().process_frame

func number(raw, fallback := 1.0) -> float:
	if raw == null: return fallback
	var text := str(raw)
	return float(text.trim_suffix("%")) / 100.0 if text.ends_with("%") else float(text)

func check_catalog() -> void:
	for entries in [GameData.units, GameData.buildings]:
		for entity in entries:
			if not original.entities.has(entity.id): continue
			for key in ["weapon", "elite_weapon", "deployed_weapon", "elite_deployed_weapon"]:
				var w: Dictionary = entity.get(key, {})
				var id := raw_id(str(w.get("ra2_weapon_id", "")))
				if not original.weapons.has(id): continue
				var raw: Dictionary = original.weapons[id]
				var wh: Dictionary = original.warheads.get(raw.warhead, {})
				if wh.get("temporal", "no") == "yes" or wh.get("mindcontrol", "no") == "yes": continue
				var label: String = prefix + str(entity.id) + "." + str(key)
				check(float(w.damage) == number(raw.damage), label + " original Damage")
				check(is_equal_approx(float(w.cooldown), number(raw.rof) / 15.0), label + " original ROF / rules clock")
				check(int(w.burst) == int(number(raw.get("burst"))), label + " original Burst")
				check(raw_id(w.ra2_warhead) == raw.warhead, label + " original Warhead")
	for id in original.warheads:
		if not GameData.has_ra2_warhead(id): continue
		var values: PackedStringArray = str(original.warheads[id].get("verses", "")).split(",")
		for i in ARMORS.size():
			var expected := number(values[i]) if i < values.size() and not values[i].is_empty() else 1.0
			check(is_equal_approx(GameData.ra2_verse(id, ARMORS[i]), expected), prefix + id + " original Verses " + ARMORS[i])
	if BattleRequest.rules_mode == MatchRules.RA2:
		check(GameData.get_unit("TANY").hp == 200.0, prefix + "Tanya uses YR Strength 200")
	else:
		check(GameData.get_building("GAPOWR").hp == 750.0, prefix + "extension uses native Strength before explicit progression bonuses")

func actor(id: String, side: String, pos: Vector2):
	var a = battle._place_building(id, side, pos, true) if id.begins_with("GA") or id == "ATESLA" else battle.spawn_unit(id, side, pos)
	if a is Building: a._buildup_play = -1.0
	a.data = a.data.duplicate(true)
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.bonuses = {}
	if a is Unit: a.order_guard() # Explicit firing fixture; default is now return-fire.
	return a

func remove_actor(a) -> void:
	battle.units.erase(a)
	battle.buildings.erase(a)
	a.free()

# Expected values use only the independently extracted original INI fixture.
func original_hit(weapon_id: String, target_id: String, prone: bool, offense: float, defense: float, distance := 0.0) -> float:
	var w: Dictionary = original.weapons[raw_id(weapon_id)]
	var wh: Dictionary = original.warheads[w.warhead]
	var armor: String = original.entities[target_id].armor.to_lower()
	var verses: PackedStringArray = str(wh.verses).split(",")
	var amount := number(w.damage) * number(verses[ARMORS.find(armor)])
	if prone: amount *= number(wh.get("pronedamage"))
	if distance > 0.0:
		amount *= lerpf(1.0, number(wh.get("percentatmax")), distance / (55.0 * number(wh.cellspread)))
	return floorf(amount * offense / defense)

func fly(shots: Array) -> void:
	for shot in shots:
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 360:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(1.0 / 60.0)
		check(shot.is_queued_for_deletion(), prefix + "real projectile reaches impact")

func hit_case(id: String, target_id: String, side: String, instant: bool, deploy := false, prone := false, rank := 0, target_rank := 0, defense := 1.0) -> void:
	var other := "enemy" if side == "ally" else "ally"
	var shooter = actor(id, side, Vector2(1450, 1500))
	var victim = actor(target_id, other, Vector2(1580, 1500))
	var base_hp: float = victim.max_hp
	shooter._grant_veteran(rank, false)
	if victim is Unit: victim._grant_veteran(target_rank, false)
	check(victim.max_hp == base_hp, prefix + "veteran armor does not inflate Strength")
	if deploy: shooter.set_deployed(true)
	if prone: victim.set_deployed(true)
	# Neutralize extension-only buffs while retaining native veterancy.
	shooter.bonuses["attack_bonus"] = 1.0
	victim.bonuses["defense_bonus"] = defense
	victim.hp = 10000.0
	var w: Dictionary = shooter._active_weapon().duplicate(true)
	# CommandoCombat resolves a native weapon dynamically; its real projectile path
	# cannot be replaced by modifying the generic actor weapon fixture.
	var force_instant: bool = instant and not CommandoCombat.handles(shooter)
	if force_instant: w.projectile_speed = 0.0
	if deploy:
		shooter.data["elite_deployed_weapon" if rank >= 2 else "deployed_weapon"] = w
	elif rank >= 2: shooter._ra2_weapon_override = w
	else: shooter.weapon = w
	var offense := 1.1 if rank > 0 else 1.0
	var expected := original_hit(w.ra2_weapon_id, target_id, prone, offense, defense * (1.5 if target_rank > 0 else 1.0))
	var old: Array = battle.projectiles_root.get_children()
	shooter._fire_shot(victim)
	var shots: Array = battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p))
	check(shots.size() == (0 if force_instant else 1), prefix + "selected hit path " + str(force_instant))
	# Projectile damage must retain fire-time offense, not a mutable actor dictionary.
	shooter.bonuses["attack_bonus"] = 9.0
	fly(shots)
	check(10000.0 - victim.hp == expected, prefix + "%s -> %s %s instant=%s deploy=%s rank=%d/%d" % [id, target_id, side, instant, deploy, rank, target_rank], {"actual": 10000.0 - victim.hp, "expected": expected})
	remove_actor(shooter)
	remove_actor(victim)
	await get_tree().process_frame

func splash_case(side: String) -> void:
	var other := "enemy" if side == "ally" else "ally"
	var shooter = actor("MTNK", side, Vector2(1400, 1700))
	var direct = actor("MTNK", other, Vector2(1600, 1700))
	var edge = actor("GGI", other, direct.position + Vector2(8.25, 0)) # AP CellSpread=.3, halfway.
	var friendly = actor("GGI", side, direct.position)
	var far = actor("GGI", other, direct.position + Vector2(55, 0))
	for a in [direct, edge, friendly, far]: a.hp = 10000.0
	var old: Array = battle.projectiles_root.get_children()
	shooter._fire_shot(direct)
	fly(battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p)))
	check(10000.0 - edge.hp == original_hit("105mm", "GGI", false, 1.0, 1.0, 8.25), prefix + "splash uses each victim armor and original PercentAtMax")
	check(10000.0 - friendly.hp == original_hit("105mm","GGI",false,1.0,1.0,0.0) and far.hp == 10000.0, prefix + "allied infantry at impact takes native splash; distant actor retains HP")
	for a in [shooter, direct, edge, friendly, far]: remove_actor(a)
	await get_tree().process_frame

func prism_case(side: String) -> void:
	var other := "enemy" if side == "ally" else "ally"
	var tower = actor("ATESLA", side, Vector2(1450, 1500))
	var support = actor("ATESLA", side, Vector2(1450, 1600))
	var victim = actor("MTNK", other, Vector2(1650, 1500))
	victim.hp = 10000.0
	victim.bonuses["defense_bonus"] = 2.0
	tower.attack_target = victim
	var old: Array = battle.projectiles_root.get_children()
	check(tower._fire(), prefix + "real operational prism tower fires")
	fly(battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p)))
	check(10000.0 - victim.hp == original_hit("PrismShot", "MTNK", false, 2.5, 2.0), prefix + "prism support reaches actual projectile damage exactly once", 10000.0 - victim.hp)
	for a in [tower, support, victim]: remove_actor(a)
	await get_tree().process_frame

func armor_matrix() -> void:
	for id in ["E1", "MTNK", "MGTK", "TANY"]:
		var shooter = actor(id, "ally", Vector2(1400, 1500))
		var victim = actor("MTNK", "enemy", Vector2(1580, 1500))
		var w: Dictionary = original.weapons[raw_id(shooter.weapon.ra2_weapon_id)]
		var wh: Dictionary = original.warheads[w.warhead]
		var verses: PackedStringArray = str(wh.verses).split(",")
		for i in ARMORS.size():
			victim.ra2_armor = ARMORS[i]
			victim.hp = 10000.0
			var old: Array = battle.projectiles_root.get_children()
			shooter._fire_shot(victim)
			fly(battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p)))
			var expected := floorf(number(w.damage) * number(verses[i]))
			check(10000.0 - victim.hp == expected, prefix + id + " actual hit versus " + ARMORS[i], {"actual": 10000.0 - victim.hp, "expected": expected})
			await get_tree().process_frame
		remove_actor(shooter)
		remove_actor(victim)
		await get_tree().process_frame

func critical_case() -> void:
	# Extension criticals must survive projectile creation; deterministic seeds
	# exercise the real random roll without replacing its damage implementation.
	if BattleRequest.rules_mode != MatchRules.EXTENDED: return
	for instant in [false, true]:
		var shooter = actor("MTNK", "ally", Vector2(1400, 1500))
		var victim = actor("MTNK", "enemy", Vector2(1580, 1500))
		shooter.weapon = shooter.weapon.duplicate(true)
		if instant: shooter.weapon.projectile_speed = 0.0
		shooter.add_buff("crit", 10.0, 0.95, "critical regression")
		var crits := 0
		for i in 8:
			seed(1000 + i)
			victim.hp = 10000.0
			var old: Array = battle.projectiles_root.get_children()
			shooter._fire_shot(victim)
			fly(battle.projectiles_root.get_children().filter(func(p): return p is Projectile and not old.has(p)))
			var actual: float = 10000.0 - victim.hp
			if actual == 104.0: crits += 1 # YR 105mm.Damage=65, heavy=100%, extension critical x1.6.
			check(actual == 65.0 or actual == 104.0, prefix + "critical applies zero or one 1.6 multiplier", actual)
			await get_tree().process_frame
		check(crits > 0 and shooter.bonuses.get("attack_bonus", 1.0) == 1.0, prefix + "actual critical occurs without polluting subsequent shots")
		remove_actor(shooter)
		remove_actor(victim)
		await get_tree().process_frame
