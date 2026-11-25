extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	await destroyer_counterfire(mode)
	setup_logistics_scene(mode, "美国")
	var ship = battle.spawn_unit("DEST", "ally", Vector2(1600, 1450))
	var sub = battle.spawn_unit("SUB", "enemy", Vector2(1600, 1900))
	var escort = battle.spawn_unit("MTNK", "ally", Vector2(1570, 1750))
	for u in [ship, sub, escort]: activate(u)
	sub.hp = 2000
	sub._physics_process(1.21)
	var label := mode + " ASW: "
	check(ship.logistics.squadron.size() == 1, label + "one Osprey berth")
	check(not GameData.unit_in_production_catalog("ASW") and GameData.unit_in_production_catalog("SUB") and GameData.get_unit("SUB").built_at == "NAYARD", label + "Osprey remains auxiliary while Typhoon belongs to Soviet yard")
	check(not battle.actor_visible_to("ally", sub) and not sub.visible, label + "ordinary scout cannot reveal submerged enemy in clear terrain")
	sub.position = ship.position + Vector2(0,440)
	check(battle.actor_visible_to("ally", sub), label + "destroyer detects exactly 8 cells")
	check(not escort._weapon_domain_valid(sub), label + "shared sensor does not give a tank depth charges")
	AlliedAbilities.change_side(ship, "enemy")
	check(not battle.actor_visible_to("ally", sub), label + "captured destroyer no longer provides allied sonar")
	AlliedAbilities.change_side(ship, "ally")
	check(battle.actor_visible_to("ally", sub), label + "regained destroyer provides sonar immediately")
	sub.position.y += 1
	check(not battle.actor_visible_to("ally", sub), label + "contact ends past sensor boundary")
	var dolphin = battle.spawn_unit("DLPH","ally",sub.position+Vector2(0,400))
	activate(dolphin)
	NavalContact.tick(dolphin,NavalContact.dive_delay())
	check(battle.actor_visible_to("ally", sub) and NavalContact.sensor_range(dolphin) == 440, label + "dolphin shares native YR eight-cell contact")
	check(not battle.actor_visible_to("enemy", dolphin) and NavalContact.sensor_range(sub) == 385, label + "Typhoon sensor is seven cells")
	sub.position = ship.position + Vector2(0,190)
	ship.set_fire_stance("none")
	ship._refresh_target()
	ship.logistics.tick_squadron(0.0)
	check(ship.logistics.squadron[0].unit==null,label+"hold fire waits for a direct order")
	battle.select_unit(ship,false)
	battle.force_attack(sub)
	ship.logistics.tick_squadron(0.0)
	var plane = ship.logistics.squadron[0].unit
	check(is_instance_valid(plane) and plane.unit_id == "ASW", label + "explicit attack launches real Osprey")
	if not is_instance_valid(plane):
		screen.free(); await get_tree().process_frame
		return
	ship.set_fire_stance("defend")
	activate(plane,false)
	check(plane.logistics.ammo == 1 and plane.logistics.carrier_owner == ship, label + "single bomb and assigned mother ship")
	check(ship._ra2.tex == RA2Art.art("DESTWO").get("tex") and ship._ra2_shd.tex == RA2Art.art("DESTWO_shd").get("tex"), label + "launch selects native empty deck and shadow")
	check(not ship._try_fire_ready(), label + "no simultaneous 155mm shot at submarine")
	# Preserve the in-flight contact and ownership through the real snapshot.
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var snap = codec.capture(battle)
	codec.restore(battle,snap)
	ship = find_unit("DEST","ally")
	sub = find_unit("SUB","enemy")
	plane = find_unit("ASW","ally")
	dolphin = find_unit("DLPH","ally")
	check(is_instance_valid(plane) and ship.logistics.squadron[0].unit == plane and plane.logistics.carrier_owner == ship and plane.attack_target == sub, label + "mid-sortie snapshot reconnects plane, host and target")
	activate(ship,false); activate(plane,false); activate(sub)
	var holder: Node = ship._pick_projectile_parent()
	var prior: float = sub.hp
	var launches := 0
	var wet_bomb := false
	await get_tree().physics_frame
	for tick in 2200:
		plane._physics_process(1.0 / 60.0)
		for shot in holder.get_children():
			if not shot is Projectile: continue
			if shot.ra2_warhead.to_lower() == "apsplash":
				launches += 1
				wet_bomb = plane._active_weapon().ra2_projectile == "DepthCharge" and shot.ra2_image.to_upper() == "DRAGON"
				for n in 600:
					if shot.is_queued_for_deletion(): break
					shot._physics_process(1.0/60)
				shot.free()
		if plane.embarked_in == ship: break
	check(launches == 1 and wet_bomb and is_equal_approx(prior-sub.hp,50.0), label + "one real DepthCharge/APSplash damages target", [launches,sub.hp,prior])
	check(plane.embarked_in == ship, label + "expended Osprey physically returns")
	check(ship._ra2.tex == RA2Art.art("DEST").tex, label + "recovered plane restores occupied deck")
	ship.logistics.tick_squadron(9.9)
	check(plane.embarked_in == ship, label + "no early rearm")
	ship.logistics.tick_squadron(0.2)
	check(plane.embarked_in == null and plane.logistics.ammo == 1, label + "ten-second reload relaunches")
	sub.order_stop()
	sub.position = Vector2(2200,2200)
	# Withdraw before advancing the dive timer: a Typhoon in firing range
	# stays on the surface and cannot exercise loss of underwater contact.
	sub._physics_process(1.21)
	check(NavalContact.submerged(sub),label + "retreating Typhoon dives before leaving sonar contact")
	plane._physics_process(1.0/60)
	ship._refresh_target()
	check(plane.attack_target == null and (plane.logistics.air_state == "returning" or plane.embarked_in == ship) and plane.logistics.ammo == 1 and ship.attack_target == null, label + "lost contact recalls loaded aircraft and clears ship lock")
	sub.position = ship.position + Vector2(0,190)
	ship._refresh_target()
	check(ship.attack_target == sub, label + "normal guard reacquires newly detected sub")
	for tick in 1200:
		if plane.embarked_in == ship: break
		plane._physics_process(1.0 / 60.0)
	ship.logistics.tick_squadron(10.0)
	check(plane.embarked_in == null and plane.attack_target == sub, label + "reacquired contact dispatches a fresh sortie")
	plane.receive_hit(10000.0, "shell")
	ship.logistics.tick_squadron(0.0)
	check(ship.logistics.squadron[0].unit == null and ship.logistics.squadron[0].timer > 26.5, label + "lost craft starts 400 tick replacement")
	ship.logistics.tick_squadron(26.0)
	check(ship.logistics.squadron[0].unit == null, label + "waiting for replacement")
	ship.logistics.tick_squadron(0.7)
	check(is_instance_valid(ship.logistics.squadron[0].unit), label + "replacement launches after 400 ticks")
	var surface = battle.spawn_unit("DEST","enemy",ship.position + Vector2(0,90))
	ship.attack_target = surface; ship.attack_ordered = true; ship._cd_timer = 0.0
	check(ship._try_fire_ready(), label + "155mm remains usable against surface ships")
	# Restore a pre-feature hangar shape, as stored by v0.5.14.
	ship.logistics.destroyed()
	codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var old_shape = codec.capture(battle)
	codec.restore(battle,old_shape)
	ship = find_unit("DEST","ally")
	check(ship.logistics.squadron.size() == 1, label + "empty legacy destroyer hangar migrates")
	sub = find_unit("SUB","enemy")
	dolphin = find_unit("DLPH","ally")
	escort = find_unit("MTNK","ally")
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	dolphin.position = ship.position + Vector2(0,-650)
	sub.position = ship.position + Vector2(0,440)
	fog.rebuild()
	check(sub.visible and battle.actor_visible_to("ally",sub), label + "outer sonar cell visible with real fog enabled")
	sub.position.y += 100
	escort.position = sub.position + Vector2(60,0)
	fog.rebuild()
	check(fog.is_visible_at("ally",sub.position) and not sub.visible and not ship.attack_domain_valid(sub), label + "ordinary sight of water does not reveal submerged targets")
	dolphin.position = sub.position + Vector2(0,-130)
	fog.rebuild()
	battle.select_unit(ship,false)
	battle.force_attack(sub)
	ship.logistics.tick_squadron(0.0)
	check(sub.visible and is_instance_valid(ship.logistics.squadron[0].unit), label + "allied dolphin contact enables explicit remote ASW launch")
	remove_actor(dolphin)
	fog.rebuild()
	check(not sub.visible and not battle.actor_visible_to("ally",sub), label + "loss of last detector removes shared contact")
	var patrol=battle.spawn_unit("DEST","ally",sub.position+Vector2(0,550))
	dolphin=battle.spawn_unit("DLPH","ally",sub.position+Vector2(55,0))
	activate(dolphin)
	activate(patrol)
	battle.fog.rebuild()
	patrol._think_timer=0.0
	patrol._physics_process(1.0/60)
	check(patrol.attack_range<550.0 and patrol.attack_target==sub and not patrol.attack_ordered and is_instance_valid(patrol.logistics.squadron[0].unit),label+"automatic launch on a sonar contact reported by an allied sensor beyond own sonar",[patrol.attack_range,patrol.position.distance_to(sub.position)])
	screen.free()
	await get_tree().process_frame

func find_unit(id: String, side: String):
	for u in battle.units:
		if u.unit_id == id and u.side == side: return u
	return null

func destroyer_counterfire(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var ship = battle.spawn_unit("DEST", "enemy", Vector2(1620, 1500))
	var decoy = battle.spawn_unit("DEST", "ally", Vector2(1700, 1650))
	var attacker = battle.spawn_unit("GGI", "ally", ship.position - Vector2(ship.attack_range + 45.0, 0))
	for actor in [ship, decoy, attacker]: activate(actor)
	attacker.set_deployed(true, false)
	var ai = battle.skirmish_ai
	var ops = preload("res://scripts/world/skirmish_operations.gd")
	var micro = preload("res://scripts/world/skirmish_micro.gd")
	ops.order_attack(ship, decoy)
	ship.receive_hit(12, "shell", {}, attacker)
	check(is_same(ship.special.get("retaliation_target"), attacker), mode + " destroyer knows which shore soldier fired")
	var start: Vector2 = ship.position
	var before: float = attacker.hp
	for tick in 600:
		micro.tick(ai, 1.0 / 60.0)
		if tick % 120 == 60: ops.naval_orders(ai, ship, [decoy, attacker])
		ship._physics_process(1.0 / 60.0)
		for shot in ship._pick_projectile_parent().get_children():
			if shot is Projectile and not shot.is_queued_for_deletion(): shot._physics_process(1.0 / 60.0)
		if attacker.hp < before: break
	check(ship.position.x < start.x - 20 and battle.path_service.in_naval_water(ship.position),
		mode + " destroyer closes on shore attacker in connected water", ship.position)
	check(attacker.hp < before, mode + " destroyer's surface gun damages the attacker despite a competing naval target", attacker.hp)
	check(ship.logistics.squadron[0].unit == null, mode + " shore retaliation does not dispatch anti-submarine aircraft")
	ship.order_stop()
	ship.set_fire_stance("none")
	ship.receive_hit(12, "shell", {}, attacker)
	micro.tick(ai, 0.5)
	ops.naval_orders(ai, ship, [attacker])
	check(ship.attack_target == null and not ship.has_move_order, mode + " AI hold-fire ship keeps its order when hit")
	ship.set_fire_stance("defend")
	attacker.queue_free()
	await get_tree().process_frame
	micro.tick(ai, 0.5)
	check(not ship.attack_ordered, mode + " dead shore attacker is discarded")
	screen.free()
	await get_tree().process_frame
