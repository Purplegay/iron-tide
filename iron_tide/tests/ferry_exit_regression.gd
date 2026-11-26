extends "res://tests/allied_abilities_regression.gd"
func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode,"美国")
	for id in ["LCRF","SAPC"]:
		var ship = actor(id,"ally",Vector2(1100,1800))
		var person = actor("E1","ally",ship.position+Vector2(10,0))
		person.logistics.request_board(ship)
		person.logistics.tick(0.1)
		check(person.embarked_in==ship and not person.visible,id+" boarding")
		ship.position=Vector2(1650,1600)
		person._physics_process(1.0/60)
		check(not person.visible and person.global_position.is_equal_approx(ship.global_position),id+" concealed passenger travels aboard")
		screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
		battle.select_unit(ship, false)
		battle._emit_selection()
		await key(KEY_E)
		check(ship.logistics.unloading, id + " selected ferry receives E unload order")
		ship.logistics.tick(0.1)
		check(person.embarked_in==ship,id+" deep water holds passenger")
		ship.position=Vector2(2150,1650);ship.hull_angle=PI/2
		ship.logistics.tick(0.5)
		var exit_point:Vector2=ship.position+Vector2.DOWN*(ship.radius+person.radius+4)
		check(person.visible and person.position.distance_to(exit_point)<1,id+" bow exit",str(person.position))
		check(person.motion_pose.point(person,0).distance_to(exit_point)<1,id+" first display sample")
		check(person.has_move_order and person.move_target.y>exit_point.y,id+" walk out")
		person.set_physics_process(true)
		for i in 60:
			await get_tree().physics_frame
			if person.position.y > exit_point.y + 5:
				break
		person.set_physics_process(false)
		check(person.position.y>exit_point.y+5,id+" walked clear",str(person.position))
		remove_actor(person);remove_actor(ship)
	screen.free()
	await get_tree().process_frame
