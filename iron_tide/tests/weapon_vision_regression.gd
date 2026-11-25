extends "res://tests/attack_range_regression.gd"

const Fog = preload("res://scripts/world/fog_of_war.gd")

func exercise_ranges(mode: String) -> void:
	start(mode)
	for b in battle.buildings:
		b.sight = 40.0
		b.attack_range = 0.0
	battle.fog = Fog.new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	var origin := Vector2(1203, 1217)
	for side in ["ally", "enemy"]:
		for id in ["MTNK", "SREF", "SNIPE", "E1", "GGI", "FV", "GTGCAN", "GAPILL"]:
			var actor = battle._place_building(id, side, origin, true) if GameData.is_building(id) else battle.spawn_unit(id, side, origin)
			if actor is Building: actor._buildup_play = -1.0
			var label: String = prefix + side + " " + id + ": "
			var base: float = actor.sight
			var expected: float = maxf(base, actor.attack_range)
			battle.fog.rebuild()
			check(battle.fog.vision_radius(actor) == expected and actor.sight == base, label + "current weapon range covered without modifying base sight")
			check_circle(actor, label)
			if actor is Unit:
				if id in ["E1", "GGI"]:
					check(actor.set_deployed(true), label + "deploy accepted")
					battle.fog.rebuild()
					check_circle(actor, label + "deployed ")
				actor._grant_veteran(2, false)
				battle.fog.rebuild()
				check_circle(actor, label + "elite ")
				if id == "FV":
					var passenger = battle.spawn_unit("SNIPE", side, origin)
					actor.logistics.passengers.append(passenger)
					passenger.set_stowed(actor)
					actor._refresh_weapon_derived()
					battle.fog.rebuild()
					check_circle(actor, label + "sniper passenger ")
					actor.logistics.passengers.clear()
					actor._refresh_weapon_derived()
					battle.units.erase(passenger)
					passenger.free()
					battle.fog.rebuild()
					check(battle.fog.vision_radius(actor) == maxf(actor.sight, actor.attack_range), label + "unloading restores current vision radius")
			if id == "GTGCAN" and side == "ally":
				battle.select_building(actor)
				await picture(mode + "-cannon-vision", origin)
			if actor is Unit: battle.units.erase(actor)
			else: battle.buildings.erase(actor)
			actor.free()
	# Isolate circle rasterization from other vision sources at several grid offsets.
	for offset in [Vector2.ZERO, Vector2(1, 39), Vector2(20, 20), Vector2(39, 1)]:
		var center: Vector2 = Vector2(1200, 1200) + offset
		battle.fog.visible_cells.ally.fill(0)
		battle.fog._reveal("ally", center, 201.0)
		var misses := 0
		for i in 144:
			var point := center + Vector2.from_angle(TAU * i / 144.0) * 200.999
			if not battle.fog.is_visible_at("ally", point): misses += 1
		check(misses == 0, prefix + "no blind cells inside exact circle at offset " + str(offset), misses)
		check(not battle.fog.is_visible_at("ally", center + Vector2(300, 0)), prefix + "rasterization does not reveal distant terrain")
	await finish()

func check_circle(actor, label: String) -> void:
	var radius: float = actor.attack_range
	var unseen := 0
	for i in 72:
		var point: Vector2 = actor.global_position + Vector2.from_angle(TAU * i / 72.0) * maxf(0.0, radius - 0.01)
		if not battle.fog.is_visible_at(actor.side, point): unseen += 1
	check(unseen == 0, label + "all attack-circle boundary samples visible", unseen)
	check(battle.fog.vision_radius(actor) == maxf(actor.sight, radius), label + "dynamic weapon and fog radius agree")
	var other := "enemy" if actor.side == "ally" else "ally"
	var target = battle.spawn_unit("E1", other, actor.global_position + Vector2(radius - 1.0, 0))
	target.sight = 40.0
	target.attack_range = 0.0
	battle.fog.rebuild()
	check(battle.actor_visible_to(actor.side, target), label + "real target at range edge is visible")
	if actor is Unit:
		# Anti-air-only deployed GGI cannot shoot ground units; visibility still covers range.
		if actor.unit_id != "GGI": check(actor._weapon_target_valid(target), label + "real weapon can target revealed enemy")
	else: check(actor._valid_weapon_target(target), label + "real defense can target revealed enemy")
	if actor.side == "ally":
		var cell := Vector2i(target.position / Fog.CELL)
		check(target.visible and battle.fog.mask_image.get_pixelv(cell).a == 0.0, label + "sprite and fog texture both reveal target")
	battle.units.erase(target)
	target.free()
