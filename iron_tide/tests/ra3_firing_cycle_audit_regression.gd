extends "res://tests/allied_abilities_regression.gd"
## Real fire-readiness, pre-attack and magazine consumers, against XML seconds.
func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var target = actor("R3FUTURE", "enemy", Vector2(1700, 1400))
	for id in ["R3MIRAGE", "R3FUTURE", "R3HARBINGER"]:
		var unit = actor(id, "ally", Vector2(1400, 1400))
		unit.fire_stance = "guard"; unit.attack_ordered = true; unit.attack_target = target
		for rank in [0, 3]:
			unit._grant_veteran(rank, false)
			for gun in ([false, true] if id == "R3HARBINGER" else [false]):
				if gun != bool(unit.special.get("ra3_gun_mode", false)): Ra3Expansion.use(unit, Vector2.ZERO)
				for hz in [15, 60, 120]:
					var dt: float = 1.0 / hz
					var label := "%s rank%d %s %dHz" % [id, rank, "gun" if gun else "primary", hz]
					unit._cd_timer = 0; unit.special.ra3_clip = 0
					unit.special.erase("ra3_mounts")
					unit.special.erase("ra3_pre_target"); unit.special.erase("ra3_pre_left")
					unit.attack_target = target
					target.position = unit.position + (Vector2(160, 0) if id == "R3MIRAGE" else (Vector2(450, 0) if gun else Vector2(0, -450)) if id == "R3HARBINGER" else Vector2(300, 0))
					unit.hull_angle = 0; unit.turret_angle = unit.position.direction_to(target.position).angle()
					if id == "R3HARBINGER":
						unit.logistics.air_lift = 1.0
						preload("res://scripts/units/ra3_gunship_mounts.gd").tick(unit, 5.0)
					var times: Array[float] = []
					var cycle := (1.35 if rank == 3 else 1.6) if id == "R3MIRAGE" else (0.1 if gun else 2.0) / (1.2 if rank == 3 else 1.0) if id == "R3HARBINGER" else (2.5 if rank == 3 else 3.0)
					var clip := (10 if gun else 12) if id == "R3HARBINGER" else 0
					var reload := (0.5 if gun else 2.0) if id == "R3HARBINGER" else 0.0
					var limit := 14 if clip > 0 else 4
					for frame in ceili((limit * (cycle + dt) + reload + 1.0) / dt):
						if id != "R3MIRAGE": Ra3Expansion.tick(unit, dt)
						if unit._try_fire_ready():
							times.append(frame * dt)
							check(battle.projectiles_root.get_child_count() == (2 if id == "R3HARBINGER" and not gun else 1), label + " emits expected payload count")
							for shot in battle.projectiles_root.get_children(): shot.free()
							for fx in Effects._host().get_children():
								if fx is Ra3WeaponFx: fx.free()
						unit._cd_timer -= dt
						if times.size() >= limit: break
					check(times.size() == limit, label + " sustained fire does not stall", times)
					for i in range(1, times.size()):
						var expected := cycle + (reload if clip > 0 and i % clip == 0 else 0.0)
						check(absf(times[i] - times[i - 1] - expected) <= dt + 0.0001, label + " cadence %d including fixed magazine reload" % i, times[i] - times[i - 1])
		remove_actor(unit)
	screen.free(); await get_tree().process_frame
