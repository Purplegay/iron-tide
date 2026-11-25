extends "res://tests/allied_abilities_regression.gd"
const Outline = preload("res://scripts/ui/unit_selection_outline.gd")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	var tank = actor("MTNK", "ally", Vector2(1600, 1600))
	var unit = actor("E1", "ally", Vector2(1700, 1600))
	var texture: Texture2D = tank._ra2.tex
	var source := RA2Art.src_rect(tank._ra2, 0)
	var destination := Rect2(Vector2(-50, -70), source.size)
	Outline.begin(tank)
	check(tank.get_node_or_null("SelectionOutline") == null, "unselected unit allocates no outline")
	tank.set_hovered(true); Outline.begin(tank)
	check(tank.get_node_or_null("SelectionOutline") == null, "hover is distinct from SELECTED")
	battle.select_unit(tank, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var emitted = tank.get_node_or_null("SelectionOutline")
	check(emitted != null and emitted.used == 2, "actual Unit draw captures hull and turret but excludes shadow")
	Outline.begin(tank)
	Outline.capture(tank, texture, destination, source)
	Outline.capture(tank, texture, destination, source)
	Outline.end(tank)
	var root = tank.get_node("SelectionOutline")
	check(root.visible and root.used == 2 and root.show_behind_parent, "selected hull/turret silhouette behind original model")
	var layer = root.get_child(0)
	check(layer.texture == texture and layer.material.shader == Outline.OUTLINE_SHADER, "real texture feeds dedicated outline shader")
	check(layer.material.get_shader_parameter("source_region") == Vector4(source.position.x/texture.get_width(), source.position.y/texture.get_height(), source.size.x/texture.get_width(), source.size.y/texture.get_height()), "atlas region bounds match current frame")
	check(layer.destination == destination.grow(root.width), "expanded quad includes outer stroke without sprite clipping")
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		battle.camera.zoom = Iso.cam_zoom(zoom); battle.camera.force_update_scroll()
		Outline.begin(tank)
		var xform: Transform2D = tank.get_global_transform_with_canvas() * root.transform
		check(is_equal_approx(root.width * xform.x.length(), Outline.SCREEN_WIDTH), "screen stroke width stable at zoom " + str(zoom))
	Outline.capture(tank, texture, destination, source, 0.25); Outline.end(tank)
	check(root.used == 1 and not root.get_child(1).visible and root.get_child(1).texture == null, "obsolete turret/disguise layers release texture")
	check(root.get_child(0).material.get_shader_parameter("opacity") == 0.25, "cloak and disguise opacity reaches outline")
	var count: int = root.get_child_count()
	Outline.capture(tank, texture, destination, source)
	check(root.get_child_count() == count and root.used == 1, "status/weapon effects outside body capture cannot join outline")
	tank.set_selected(false)
	check(not root.visible and root.get_child(0).texture == null, "deselect immediately clears silhouette and retained texture")
	battle.select_unit(unit, false); Outline.begin(unit)
	check(Outline.eligible(unit) and not Outline.eligible(tank), "selection switch transfers eligibility")
	unit.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	check(unit.get_node("SelectionOutline").used == 1, "actual infantry detail draw captures one body without HUD or shadow")
	unit.hide(); Outline.begin(unit)
	check(not unit.get_node("SelectionOutline").visible, "fog-hidden unit cannot retain visible outline")
	unit.show(); unit.embarked_in = tank; Outline.begin(unit)
	check(not Outline.eligible(unit), "embarked unit has no silhouette")
	unit.embarked_in = null
	# Keep the track and its shadow visible against dry ground for the rendered comparison.
	tank.position = Vector2(1000, 1600)
	var heavy = actor("HTNK", "ally", tank.position + Vector2(180, 0))
	var push := Vector2.RIGHT.rotated(Iso.eff_angle())
	tank.receive_hit(1, "rocket", {}, null, "YR_SOV_V3WH", tank.position - push * 20.0, 300.0)
	heavy.receive_hit(1, "rocket", {}, null, "YR_SOV_V3WH", heavy.position + push * 20.0, 300.0)
	unit.receive_hit(1, "rocket", {}, null, "YR_SOV_V3WH", unit.position, 300.0)
	check(is_equal_approx(tank._rock_amp, 1.0) and is_equal_approx(heavy._rock_amp, 0.3) and unit._rock_t == 0.0, "same blast uses tank weight, excludes infantry")
	check(is_equal_approx(heavy._rock_t, tank._rock_t * 0.3) and tank._rock_dir.dot(heavy._rock_dir) < -0.99, "lighter tank rocks longer; blast directions oppose")
	tank._rock_update(tank._rock_t * 0.5)
	var pose: Transform2D = tank.rocking_pose()
	var grounded := Vector2.RIGHT * float(tank.radius)
	check((pose * grounded).is_equal_approx(grounded) and (pose * -grounded).y < -1.0, "outer track stays on ground while other track rises")
	tank.set_selected(true)
	Outline.begin(tank)
	check(not root.transform.is_equal_approx(Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO)), "damage rocking also transforms silhouette")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = tank.position
		battle.camera.zoom = Iso.cam_zoom(2.0)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		tank.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-blast-rock.png"))
	tank._rock_update(tank._rock_t)
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-blast-settled.png"))
	check(tank.rocking_pose().is_equal_approx(Transform2D.IDENTITY), "hull settles exactly at rest")
	Outline.begin(tank)
	Outline.capture(tank, texture, destination, source, 0.0); Outline.end(tank)
	check(not root.visible and root.used == 0, "fully transparent model leaves no halo")
	Outline.begin(tank); Outline.capture(tank, texture, destination, source); Outline.end(tank)
	tank._die(null, true)
	check(not root.visible and not Outline.eligible(tank), "death clears outline immediately")
	# Dynamic RA3 ViewportTexture follows the same region-free full-texture path.
	var viewport := SubViewport.new(); viewport.size = Vector2i(128, 128)
	stage.add_child(viewport)
	Outline.begin(unit); Outline.capture(unit, viewport.get_texture(), Rect2(-48, -80, 96, 96), Rect2(0, 0, 128, 128)); Outline.end(unit)
	var dynamic_root = unit.get_node("SelectionOutline")
	check(dynamic_root.get_child(0).texture == viewport.get_texture() and dynamic_root.get_child(0).material.get_shader_parameter("source_region") == Vector4(0, 0, 1, 1), "live RA3 viewport texture supported without CPU readback")
	unit.set_selected(false); viewport.free()
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	await get_tree().process_frame
