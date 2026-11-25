extends "res://tests/logistics_regression.gd"

func exercise_mode(mode: String) -> void:
	for moving in [false,true]:
		setup_logistics_scene(mode,"美国")
		var carrier=battle.spawn_unit("CARRIER","enemy",Vector2(1650,1500))
		var target=battle.spawn_unit("MTNK","ally",Vector2(2050,1500))
		activate(carrier)
		activate(target)
		target.hp=10000.0
		target.max_hp=10000.0
		carrier.order_target(target,false,false)
		carrier.logistics.tick_squadron(0.0)
		var planes:Array=carrier.logistics.squadron.map(func(s):return s.unit)
		if not planes.all(func(p):return is_instance_valid(p)):
			check(false,mode+" failed to launch squadron")
			screen.free()
			await get_tree().process_frame
			continue
		for plane in planes: activate(plane,false)
		var holder:Node=carrier._pick_projectile_parent()
		var shots:=0
		for tick in 1000:
			for plane in planes:
				if plane.embarked_in==null: plane._physics_process(1.0/60.0)
			for shot in holder.get_children():
				if not shot is Projectile or shot.is_queued_for_deletion(): continue
				if not shot.has_meta("seen"):
					shot.set_meta("seen",true)
					shots+=1
				shot._physics_process(1.0/60.0)
			if moving and shots > 0: target.position.y+=1.7
			if shots==3 and not holder.get_children().any(func(p):return p is Projectile and not p.is_queued_for_deletion()): break
		check(shots==3,mode+" three real Hornet bombs "+str(moving),shots)
		check(is_equal_approx(target.hp,9880.0),mode+" bomb damages "+("moving armor" if moving else "stationary armor"),target.hp)
		screen.free()
		await get_tree().process_frame

	setup_logistics_scene(mode,"美国")
	var ship=battle.spawn_unit("CARRIER","ally",Vector2(1650,1500))
	var victim=battle.spawn_unit("E2","enemy",Vector2(2150,1500))
	activate(ship)
	activate(victim)
	ship.order_target(victim,false,false)
	ship.logistics.tick_squadron(0.0)
	var flight:Array=ship.logistics.squadron.map(func(s):return s.unit)
	ship.order_move(Vector2(1650,1780))
	for plane in flight: activate(plane,false)
	for tick in 160:
		for plane in flight: plane._physics_process(1.0/60.0)
	var overhead=flight[0]
	var original_hp:float=victim.hp
	overhead.position=victim.position
	overhead.velocity=Vector2.ZERO
	overhead.logistics.air_lift=1.0
	overhead._cd_timer=0.0
	check(overhead._try_fire_ready(),mode+" airborne Hornet releases its bomb directly overhead")
	for shot in ship._pick_projectile_parent().get_children():
		if not shot is Projectile:continue
		for step in 240:
			if shot.is_queued_for_deletion():break
			shot._physics_process(1.0/60.0)
	check(victim.hp<original_hp,mode+" overhead bomb damages its target")
	victim.hp=0
	victim._die()
	victim.queue_free()
	await get_tree().process_frame
	# Previously stranded save state: armed, idle and already sitting on open ground.
	flight[1].order_stop()
	flight[1].logistics.air_lift=0.0
	flight[1].logistics.air_state="flying"
	for tick in 2400:
		ship.position=Vector2(1650,1500)+Vector2(sin(tick*0.012)*80,cos(tick*0.012)*80)
		for plane in flight:
			if plane.embarked_in==null:plane._physics_process(1.0/60.0)
		if flight.all(func(p):return p.embarked_in==ship):break
	check(flight.all(func(p):return p.embarked_in==ship and not p.visible),mode+" all surviving planes return to continuously moving carrier after target is freed",
		flight.map(func(p):return [p.logistics.air_state,p.logistics.ammo,p.logistics.air_lift,p.position.distance_to(ship.position)]))
	check(flight[0].logistics.ammo==0 and flight[1].logistics.ammo==1, mode+" recovery preserves fired and unused ammo until deck reload")
	ship.logistics.tick_squadron(11.0)
	check(flight.all(func(p):return p.embarked_in==ship),mode+" target loss leaves reloaded squadron aboard")
	var next=battle.spawn_unit("MTNK","enemy",ship.position+Vector2(230,0))
	ship.order_target(next,false,false)
	ship.logistics.tick_squadron(0.0)
	check(flight.all(func(p):return p.embarked_in==null and p.attack_target==next and p.logistics.ammo==1),mode+" new order launches same three aircraft")
	screen.free()
	await get_tree().process_frame
