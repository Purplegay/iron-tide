extends "res://tests/logistics_regression.gd"
const Indicator = preload("res://scripts/ui/aircraft_ammo_indicator.gd")

func capture(plane, label: String) -> Image:
	if DisplayServer.get_name() == "headless": return null
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	var point: Vector2 = Indicator.screen_origin(plane, battle.hp_overlay)
	return image.get_region(Rect2i(Vector2i(point) - Vector2i(2, 2), Vector2i(int(Indicator.PIP_SIZE.x) * 4 + 4, int(Indicator.PIP_SIZE.y) + 4)))

func changed_pixels(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y): count += 1
	return count

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "韩国")
	battle.power_low = false
	var base = airport("ally", Vector2(1700, 1800))
	for id in ["ORCA", "BEAG", "HORNET"]:
		var plane = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		activate(plane)
		plane.logistics.air_lift = 1.0
		battle.camera.position = plane.position
		Iso.apply_to(battle.camera, 1.5)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		var info := Indicator.state(plane)
		check(info.ammo == plane.logistics.ammo_max and info.max > 0, mode + " " + id + " unselected aircraft shows real ammo")
		check(Indicator.visible_pips(plane) == 0, mode + " unselected aircraft has no floating ammo panel")
		plane.hovered = true
		check(Indicator.visible_pips(plane) == plane.logistics.ammo, mode + " hover reveals remaining rounds")
		plane.hovered = false
		plane.set_selected(true)
		check(Indicator.visible_pips(plane) == plane.logistics.ammo, mode + " selection reveals remaining rounds")
		var full := await capture(plane, mode + "-" + id + "-full")
		plane.logistics.consume_volley(null)
		check(Indicator.state(plane).ammo == 0, mode + " " + id + " actual volley consumes displayed ammunition")
		plane.logistics.request_return()
		check(Indicator.state(plane).status == "返航", mode + " " + id + " actual return order updates status")
		var empty := await capture(plane, mode + "-" + id + "-empty")
		if DisplayServer.get_name() != "headless":
			check(changed_pixels(full, empty) > 8, mode + " original ammo pip pixel change")
		check(Indicator.visible_pips(plane) == 0, mode + " " + id + " original ammo pip disappears after actual shot")
		if id != "HORNET":
			plane.position = plane.logistics.dock_destination()
			plane.logistics.air_lift = 0.0
			var seconds := float(GameData.ra2_general.aircraft.reload_minutes) * 60.0
			plane.logistics.tick_return(seconds * 0.5)
			info = Indicator.state(plane)
			check(Indicator.visible_pips(plane) == 0, mode + " reload progress does not display a fractional round")
			check(info.rearming and is_equal_approx(info.progress, 0.5) and info.status == "补弹 50%", mode + " " + id + " actual reload time drives progress")
			battle.camera.position = plane.position
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			await capture(plane, mode + "-" + id + "-rearming")
			battle.power_low = true
			plane.logistics.tick_return(seconds)
			check(Indicator.state(plane).status == "补弹暂停" and is_equal_approx(Indicator.state(plane).progress, 0.5), mode + " low power keeps real paused progress")
			battle.power_low = false
			plane.logistics.tick_return(seconds * 0.5)
			check(Indicator.state(plane).ammo == plane.logistics.ammo_max and Indicator.state(plane).status == "待机", mode + " actual completed reload fills indicator")
		# Multiple shots remain separate original-size icons, never one stretched bar.
		var maximum: int = plane.logistics.ammo_max
		plane.logistics.ammo_max = 4
		plane.logistics.ammo = 3
		check(Indicator.visible_pips(plane) == 3 and Indicator.PIP.get_size() == Vector2(6, 13), mode + " native marker size and three separate rounds")
		for zoom in [0.5, 1.0, 3.0]:
			Iso.apply_to(battle.camera, zoom)
			battle.camera.force_update_scroll()
			await capture(plane, mode + "-" + id + "-three-pips-" + str(zoom))
		plane.logistics.ammo_max = maximum
		plane.logistics.ammo = maximum
		plane.side = "enemy"
		check(Indicator.state(plane).is_empty(), mode + " no enemy ammo intelligence")
		plane.side = "ally"
		plane.hide()
		check(Indicator.state(plane).is_empty(), mode + " hidden aircraft has no indicator")
		plane.show()
		var before: int = plane.logistics.ammo
		var elapsed: float = plane.logistics.reload_elapsed
		for i in 20: Indicator.state(plane)
		check(before == plane.logistics.ammo and elapsed == plane.logistics.reload_elapsed, mode + " repeated UI reads cannot reload or consume ammo")
		plane.hp = 0.0
		check(Indicator.state(plane).is_empty(), mode + " dead aircraft has no indicator")
		remove_actor(plane)
	for id in ["JUMPJET", "SHAD", "MTNK"]:
		var unit = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		activate(unit)
		check(Indicator.state(unit).is_empty(), mode + " unlimited-ammo/non-air unit excluded: " + id)
		remove_actor(unit)
	screen.free()
	await get_tree().process_frame
