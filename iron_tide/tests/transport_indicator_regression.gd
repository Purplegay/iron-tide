extends "res://tests/allied_abilities_regression.gd"
const Cargo = preload("res://scripts/ui/transport_indicator.gd")

func picture(unit, label: String) -> Image:
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	var at := Cargo.screen_origin(unit, battle.hp_overlay)
	return image.get_region(Rect2i(Vector2i(at), Vector2i(9 * mini(12, unit.logistics.capacity), 8)))

func difference(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
	return count

func exercise_mode(mode: String) -> void:
	get_tree().paused = false
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	battle.water_rects = []; battle.path_service.set_water([])
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle._refresh_pathing()
	for id in ["BFRT", "FV", "SHAD", "LCRF"]:
		var unit = actor(id, "ally", Vector2(1600,1600))
		unit.logistics.air_lift = 0.0
		battle.camera.position = unit.position
		Iso.apply_to(battle.camera, 2.0)
		battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
		check(Cargo.visible_slots(unit).is_empty(), mode+id+": unselected empty transport does not clutter battlefield")
		unit.hovered = true
		check(Cargo.visible_slots(unit).size() == unit.logistics.capacity, mode+id+": hover shows all empty capacity")
		unit.hovered = false; unit.set_selected(true)
		check(Cargo.state(unit).used == 0 and Cargo.visible_slots(unit).count("empty") == unit.logistics.capacity, mode+id+": empty selected transport shows empty slots")
		var empty := await picture(unit, mode+id+"-empty")
		var passenger = actor("ENGINEER", "ally", unit.position + Vector2(15,0))
		check(passenger.logistics.request_board(unit), mode+id+": real boarding command accepted")
		passenger.logistics.tick(0.1)
		check(passenger.embarked_in == unit and Cargo.state(unit).used == 1, mode+id+": actual boarding fills exactly one slot")
		check(Cargo.visible_slots(unit)[0] == "blue", mode+id+": engineer uses original blue Pip rule")
		var occupied := await picture(unit, mode+id+"-occupied")
		check(difference(empty,occupied) >= 8, mode+id+": actual pixels show occupied slot")
		var members: Array = unit.logistics.passengers.duplicate()
		for i in 10: Cargo.state(unit)
		check(members == unit.logistics.passengers and not unit.logistics.unloading, mode+id+": display reads never mutate transport")
		for i in range(1, unit.logistics.capacity):
			var extra = actor("E1", "ally", unit.position + Vector2(15,0))
			check(extra.logistics.request_board(unit), mode+id+": remaining slot accepts infantry")
			extra.logistics.tick(0.1)
		check(Cargo.state(unit).used == unit.logistics.capacity and not Cargo.visible_slots(unit).has("empty"), mode+id+": full transport has no empty slots")
		for zoom in [0.5, 1.0, 3.0]:
			Iso.apply_to(battle.camera, zoom); battle.camera.force_update_scroll()
			var full := await picture(unit, mode+id+"-full-"+str(zoom))
			check(full.get_height() == 8, mode+id+": cargo stays eight screen pixels high at zoom "+str(zoom))
		check(unit.logistics.request_unload(), mode+id+": real unload order accepted")
		unit.logistics.unload_one()
		check(passenger.embarked_in == null and Cargo.state(unit).used == unit.logistics.capacity-1, mode+id+": actual unloading frees a slot")
		unit.side = "enemy"
		check(Cargo.state(unit).is_empty(), mode+id+": enemy passenger information not exposed")
		unit.side = "ally"; unit.hide()
		check(Cargo.visible_slots(unit).is_empty(), mode+id+": hidden carrier indicator hidden")
		unit.show()
		if id == "SHAD":
			var grounded := Cargo.screen_origin(unit, battle.hp_overlay)
			unit.logistics.air_lift = 1.0
			await picture(unit, mode+id+"-airborne")
			check(Cargo.screen_origin(unit, battle.hp_overlay).y < grounded.y, mode+id+": cargo follows actual flight lift")
		unit.hp = 0.0
		check(Cargo.state(unit).is_empty(), mode+id+": destroyed transport indicator hidden")
		for u in battle.units.duplicate(): remove_actor(u)
	var landing = actor("LCRF", "ally", Vector2(1600,1600))
	var vehicle = actor("MTNK", "ally", landing.position + Vector2(15,0))
	landing.selected = true
	check(vehicle.logistics.request_board(landing), mode+": landing craft accepts real vehicle")
	vehicle.logistics.tick(0.1)
	var weight: int = landing.logistics.passenger_size(vehicle)
	check(weight > 1 and Cargo.state(landing).used == weight and Cargo.state(landing).passengers == 1, mode+": vehicle occupies its size rather than one infantry slot")
	check(Cargo.state(landing).slots[1] == "white", mode+": extra vehicle size slots remain filled")
	for u in battle.units.duplicate(): remove_actor(u)
	var ordinary = actor("MTNK", "ally", Vector2(1600,1600))
	ordinary.selected = true
	check(Cargo.visible_slots(ordinary).is_empty(), mode+": ordinary tank has no cargo indicator")
	screen.free()
	await get_tree().process_frame
