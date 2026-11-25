extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	start(mode)
	check_native_facings()
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	for id in ["MTNK", "FV", "SREF", "MGTK", "TNKD", "AMCV", "HTNK", "APOC", "V3", "HTK", "SMCV", "R3APOC", "R3TESLA"]:
		for degrees in [60.0, 90.0, 180.0]:
			var origin := Vector2(800, 800)
			var tank = battle.spawn_unit(id, "ally", origin)
			activate(tank)
			tank.hull_angle = 0.0
			tank.order_move(origin + Vector2.from_angle(deg_to_rad(degrees)) * 600.0)
			await get_tree().physics_frame
			var first_motion := -1
			var reached_80 := -1
			var max_slip := 0.0
			var max_turn := 0.0
			for tick in 600:
				var before: float = tank.hull_angle
				tank._physics_process(1.0 / 60.0)
				max_turn = maxf(max_turn, absf(angle_difference(before, tank.hull_angle)))
				if tank.velocity.length() > 1.0:
					if first_motion < 0: first_motion = tick + 1
					max_slip = maxf(max_slip, absf(angle_difference(tank.hull_angle, tank.velocity.angle())))
				if reached_80 < 0 and tank.position.distance_to(origin) >= 80: reached_80 = tick + 1
				if not tank.has_move_order: break
				if tick % 60 == 0: await get_tree().process_frame
			check(max_slip < 0.001, prefix + id + " no sideways sliding at " + str(degrees))
			check(max_turn <= deg_to_rad(float(tank._mv("rot", 0.0))) / 60.0 + 0.0001, prefix + id + " retains source ROT limit")
			if degrees == 60.0 and not tank.data.has("soviet_ra3"): check(first_motion <= 2, prefix + id + " clear moderate turn rolls immediately", first_motion)
			if degrees == 180.0:
				var first_seconds := float(first_motion) / 60.0
				check(first_motion > 2, prefix + id + " reversal still pivots before rolling", first_motion)
				check(first_motion > 0 and first_seconds * float(tank._mv("rot", 0.0)) < 85.0, prefix + id + " open reversal rolls before 85 degrees of turning", first_seconds)
			check(reached_80 > 0, prefix + id + " turn converges into forward travel")
			metrics.append({"mode":mode,"unit":id,"angle":degrees,"first_motion_seconds":first_motion / 60.0,"eighty_pixels_seconds":reached_80 / 60.0})
			tank.order_stop()
			var stopped: Vector2 = tank.position
			for tick in 30: tank._physics_process(1.0 / 60.0)
			check(tank.position.is_equal_approx(stopped), prefix + id + " stop remains stationary")
			battle.units.erase(tank)
			tank.free()
	var probe = battle.spawn_unit("MTNK", "ally", Vector2(800, 800))
	activate(probe)
	probe.order_move(Vector2(1400, 1400))
	probe._hull_prev = 0.0
	await get_tree().physics_frame
	probe.velocity = Vector2.ONE.normalized() * probe.move_speed
	probe._local_traffic.apply(probe, 0.1)
	var steering = preload("res://scripts/units/vehicle_steering.gd")
	check(steering.open_corridor(probe, PI / 4.0), prefix + "isolated clear corridor allows rolling turn")
	steering.pivot_angle(probe, PI, PI)
	check(steering.pivot_angle(probe, deg_to_rad(100.0), deg_to_rad(100.0)) > 100.0, prefix + "clear ongoing U-turn starts forward roll")
	var peer = battle.spawn_unit("E1", "ally", Vector2(850, 850))
	activate(peer)
	await get_tree().physics_frame
	probe._local_traffic.reset()
	probe._local_traffic.apply(probe, 0.1)
	check(not steering.open_corridor(probe, PI / 4.0), prefix + "nearby infantry preserves tight pivot")
	check(steering.pivot_angle(probe, deg_to_rad(100.0), deg_to_rad(100.0)) == 35.0, prefix + "nearby infantry cancels wide moving arc")
	battle.units.erase(peer)
	peer.free()
	var rock := Obstacle.new()
	rock.position = Vector2(900, 800)
	rock.radius = 32.0
	battle.add_child(rock)
	battle._refresh_pathing()
	check(not steering.open_corridor(probe, PI / 4.0), prefix + "blocked swept corridor preserves tight pivot")
	check(steering.pivot_angle(probe, deg_to_rad(100.0), deg_to_rad(100.0)) == 35.0, prefix + "terrain blocker cancels wide moving arc")
	rock.free()
	battle._refresh_pathing()
	var building = battle._place_building("GAPOWR", "ally", Vector2(905,800), true)
	check(steering.pivot_angle(probe, deg_to_rad(100.0), deg_to_rad(100.0)) == 35.0, prefix + "factory approach stays tight beside occupied foundation")
	battle.buildings.erase(building)
	building.free()
	battle._refresh_pathing()
	probe.move_target = Vector2(850, 850)
	check(not steering.open_corridor(probe, PI / 4.0), prefix + "final formation approach preserves tight pivot")
	check(steering.pivot_angle(probe, deg_to_rad(100.0), deg_to_rad(100.0)) == 35.0, prefix + "arrival never takes the wide arc")
	probe.order_stop()
	check(not probe.special.has(steering.REVERSAL), prefix + "stop discards reversal phase")
	Ra2Sfx.stop_all(); Music.stop()
	Music.player.stream = null
	OS.delay_msec(150)
	await finish()

# VXL art uses the nearest projected facing, including when the map is mirrored.
func check_native_facings() -> void:
	var old_mirror:=Iso.MIRROR
	for mirror in [false,true]:
		Iso.MIRROR=mirror
		for count:int in [8,16,32]:
			var matches:=true
			for i in 720:
				var angle:=i*TAU/720
				var direction:=Iso.dir(Vector2.from_angle(angle)).normalized()
				var best:=0
				var score:=-2.0
				for facing in count:
					var az:=PI*0.25-facing*TAU/count
					var dot:=direction.dot(Vector2(sin(az),-0.5*cos(az)).normalized())
					if dot>score:
						best=facing
						score=dot
				if RA2Art.facing_index(angle,count)!=posmod(best+RA2Art.FACING_OFFSET,count):
					matches=false
					break
			check(matches,prefix+"nearest projected facing matches full sweep "+str([mirror,count]))
	Iso.MIRROR=old_mirror
