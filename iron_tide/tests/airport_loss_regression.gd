extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "韩国")
	for side in ["ally", "enemy"]:
		var base = airport(side, Vector2(1400, 2200))
		var alternate = airport(side, Vector2(2100, 2200))
		var assigned: Array = []
		for id in ["ORCA", "BEAG", "ORCA", "BEAG"]:
			var plane = battle.spawn_unit(id, side, base.position)
			activate(plane)
			plane.logistics.assign_producer(base)
			assigned.append(plane)
		assigned[1].logistics.ammo = 0
		assigned[1].logistics.air_state = "rearming"
		assigned[2].order_move(base.position + Vector2(500,0))
		assigned[2].logistics.air_lift = 1.0
		assigned[2].position += Vector2(350,0)
		assigned[2].logistics.request_return(base)
		assigned[3].order_move(base.position + Vector2(600,0))
		assigned[3].logistics.air_lift = 1.0
		assigned[3].position += Vector2(600,0)
		check(assigned.all(func(p): return p.logistics.home == base), mode + side + " four reserved planes")
		var moved = assigned.pop_back()
		check(moved.logistics.request_return(alternate), "transfer plane to other airport")
		var airborne = battle.spawn_unit("ORCA", side, base.position)
		activate(airborne)
		airborne.logistics.assign_producer(base)
		airborne.order_move(base.position + Vector2(620,0))
		airborne.position = base.position + Vector2(620,0)
		airborne.logistics.air_lift = 1.0
		assigned.append(airborne)
		var helicopter = battle.spawn_unit("SHAD", side, base.position + Vector2(180,0))
		activate(helicopter)
		var lift: float = airborne._visual_lift()
		var label := mode + " " + str(side) + " "
		base.receive_hit(1)
		check(assigned.all(func(p): return battle.actor_alive(p)), label + "nonlethal damage leaves planes alive")
		base.receive_hit(base.max_hp * 100)
		check(assigned.all(func(p): return p._dead and p.hp == 0 and p.is_queued_for_deletion()), label + "parked rearming returning and airborne planes destroyed")
		check(assigned.all(func(p): return not p.is_in_group("combatants") and not battle.actor_alive(p)), label + "dead planes leave active roster")
		check(battle.actor_alive(moved) and moved.logistics.home == alternate and battle.actor_alive(helicopter), label + "transfer and independent helicopter survive")
		var explosion_found := false
		for fx in get_tree().get_nodes_in_group("yr_death_effects"):
			if fx.position.is_equal_approx(airborne.position) and is_equal_approx(fx.lift, lift):
				explosion_found = true
		check(explosion_found and lift > 0.0, label + "airborne explosion at aircraft height")
		remove_actor(moved)
		remove_actor(helicopter)
		battle.buildings.erase(alternate)
		alternate.free()
		await get_tree().process_frame
	screen.free()
	await get_tree().process_frame
