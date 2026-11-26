extends Node
## Actual battle/HUD minimap, independent expected points, viewport GUI events.

var checks: Array = []
var failed := 0
var output_dir := ""
var screen
var battle
var minimap
var minimap_parent: Node

func check(ok: bool, label: String, details = null) -> void:
	checks.append({"name": label, "passed": ok, "details": details})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", details)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Use the isolated validation runner.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_size": 3200, "starting_funds": 8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	battle = screen.battle
	check(screen.hud.minimap.objective_marks().is_empty(),"ordinary skirmish has no expedition target markers")
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	minimap = screen.hud.minimap
	# Let the HUD skin its header before moving the radar out of that container.
	await get_tree().process_frame
	minimap_parent = minimap.get_parent()
	minimap.reparent(screen.overlay_layer)
	minimap.process_mode = Node.PROCESS_MODE_ALWAYS
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.position = Vector2(100, 150)
	minimap.custom_minimum_size = Vector2.ZERO
	await get_tree().process_frame
	for angle in [0.0, PI / 4.0, -PI / 4.0]:
		battle.camera.rotation = angle
		battle.camera.zoom = Vector2(2, 1)
		battle.camera.force_update_scroll()
		for dimensions in [Vector2(280, 130), Vector2(130, 280), Vector2(180, 180)]:
			await exercise_layout(dimensions)
	if DisplayServer.get_name() != "headless":
		await exercise_camera_outline()
		minimap.reparent(minimap_parent)
		minimap.custom_minimum_size = Vector2(280, 130)
		battle.camera.rotation = PI / 4.0
		battle.camera.zoom = Vector2(2, 1)
		battle.center_on(Vector2(1600, 2000))
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("minimap.png"))
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "evidence": {
		"project": ProjectSettings.globalize_path("res://"), "user_dir": OS.get_user_data_dir(),
		"engine": Engine.get_version_info().string,
		"input": "Viewport.push_input routes real mouse events to the production minimap",
		"layouts": ["280x130", "130x280", "180x180"]
	}}, "  "))
	f.close()
	print("MINIMAP checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func exercise_layout(dimensions: Vector2) -> void:
	minimap.size = dimensions
	await get_tree().process_frame
	get_window().focus_entered.emit()
	var label := str(dimensions) + ": "
	# Independent camera-axis projection, not the production transform helper.
	for fraction in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE, Vector2(0.5, 0.5), Vector2(0.25, 0.75)]:
		var local := expected_map_point(fraction * 3200.0)
		var actual: Vector2 = minimap._to_map(local)
		var expected: Vector2 = fraction * 3200.0
		check(actual.distance_to(expected) < 0.01, label + "displayed point maps to world " + str(fraction),
			{"expected": str(expected), "actual": str(actual)})
	battle.center_on(Vector2(1600, 1600))
	# Interior points avoid the camera's independent map-edge clamp.
	await button(expected_map_point(Vector2(1200, 1200)), true)
	check(centered_on(Vector2(1200, 1200)), label + "GUI click centers corresponding world point", str(battle.camera.position))
	check(minimap._dragging, label + "GUI click starts minimap drag")
	await motion(expected_map_point(Vector2(2000, 2000)))
	check(centered_on(Vector2(2000, 2000)), label + "GUI drag follows corresponding world point", str(battle.camera.position))
	await button(expected_map_point(Vector2(2000, 2000)), false)
	check(not minimap._dragging, label + "GUI release ends minimap drag")
	if absf(battle.camera.rotation) > 0.01 or dimensions.x != dimensions.y:
		var margin := Vector2(1, 1)
		battle.center_on(Vector2(1600, 1600))
		await button(margin, true)
		check(centered_on(Vector2(1600, 1600)) and not minimap._dragging,
			label + "pressing letterbox does not move camera or start drag", str(battle.camera.position))
		await button(margin, false)
		await button(expected_map_point(Vector2(1600, 1600)), true)
		await motion(margin)
		check(minimap._dragging, label + "active drag continues into letterbox")
		var edge: Vector2 = minimap._to_map(margin)
		check(edge.x < 0.01 or edge.y < 0.01 or edge.x > 3199.99 or edge.y > 3199.99,
			label + "active drag clamps to map edge")
		await button(margin, false)
	await button(expected_map_point(Vector2(1600, 1600)), true)
	await button(dimensions + Vector2(40, 40), false)
	check(not minimap._dragging, label + "release outside control ends drag")
	var released_position: Vector2 = battle.camera.position
	await motion(expected_map_point(Vector2(800, 800)), false)
	check(battle.camera.position.is_equal_approx(released_position), label + "moving after release does not pan camera")

func expected_map_point(world: Vector2) -> Vector2:
	var angle: float = battle.camera.rotation
	var ratio: float = battle.camera.zoom.y / battle.camera.zoom.x
	var extent := Vector2(absf(cos(angle)) + absf(sin(angle)), (absf(cos(angle)) + absf(sin(angle))) * ratio) * 3200.0
	var scale := minf(minimap.size.x / extent.x, minimap.size.y / extent.y)
	var rotated := (world - Vector2(1600, 1600)).rotated(-angle)
	return minimap.size * 0.5 + Vector2(rotated.x, rotated.y * ratio) * scale

func centered_on(point: Vector2) -> bool:
	# Independent expected center from the actual HUD rectangle, not camera helpers.
	battle.camera.force_update_scroll()
	var size := get_viewport().get_visible_rect().size
	var expected := Vector2(screen.hud.prod_panel.get_global_rect().position.x * 0.5, size.y * 0.5)
	return (get_viewport().get_canvas_transform() * point).distance_to(expected) < 0.1

func button(local: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = minimap.get_global_transform_with_canvas() * local
	event.global_position = event.position
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func motion(local: Vector2, held: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = minimap.get_global_transform_with_canvas() * local
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func exercise_camera_outline() -> void:
	minimap.size = Vector2(280, 280)
	await get_tree().process_frame
	var poses := [
		{"angle": 0.0, "zoom": 3.0},
		{"angle": PI / 4.0, "zoom": 3.0},
		{"angle": -PI / 4.0, "zoom": 3.0},
		{"angle": PI / 4.0, "zoom": 2.0},
	]
	for index in range(poses.size()):
		var pose: Dictionary = poses[index]
		battle.camera.rotation = pose.angle
		battle.camera.zoom = Vector2(pose.zoom, pose.zoom * 0.5)
		battle.camera.position = Vector2(1600, 1600)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		minimap.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		pixels.save_png(output_dir.path_join("outline-%d.png" % index))
		# The captured framebuffer is in physical pixels, while Control geometry is in viewport units.
		var viewport_size := get_viewport().get_visible_rect().size
		var pixel_scale := Vector2(pixels.get_size()) / viewport_size
		var expected := PackedVector2Array()
		var right: float = screen.hud.prod_panel.get_global_rect().position.x
		for corner in [Vector2.ZERO, Vector2(right, 0), Vector2(right, viewport_size.y), Vector2(0, viewport_size.y)]:
			# Camera center, axis scales and rotation form an independent geometry oracle.
			var offset: Vector2 = (corner - viewport_size * 0.5) / battle.camera.zoom
			var world: Vector2 = battle.camera.get_screen_center_position() + offset.rotated(pose.angle)
			expected.append(expected_map_point(world))
		var outline: PackedVector2Array = minimap._view_outline()
		check(outline.size() == 4, "camera pose %d: interior footprint has four corners" % index)
		var straight := true
		for side in outline.size():
			var edge: Vector2 = outline[(side + 1) % outline.size()] - outline[side]
			straight = straight and (absf(edge.x) < 0.01 or absf(edge.y) < 0.01)
		check(straight, "camera pose %d: footprint edges are horizontal or vertical" % index)
		for side in range(4):
			var midpoint: Vector2 = (expected[side] + expected[(side + 1) % 4]) * 0.5
			var pixel: Vector2 = (minimap.get_global_transform_with_canvas() * midpoint) * pixel_scale
			check(has_outline_pixel(pixels, pixel), "camera pose %d: rendered side %d follows camera projection" % [index, side],
				{"angle": pose.angle, "zoom": pose.zoom, "pixel": str(pixel)})
	battle.camera.zoom = Vector2(0.45, 0.225)
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await get_tree().process_frame
	var clipped: PackedVector2Array = minimap._view_outline()
	var inside := true
	var touches_edge := false
	for point in clipped:
		var boundary: PackedVector2Array = minimap._map_boundary()
		var on_edge := false
		for side in boundary.size():
			on_edge = on_edge or point.distance_to(Geometry2D.get_closest_point_to_segment(point, boundary[side], boundary[(side + 1) % boundary.size()])) < 0.01
		inside = inside and (on_edge or Geometry2D.is_point_in_polygon(point, boundary))
		touches_edge = touches_edge or on_edge
	check(clipped.size() >= 3, "extreme zoom-out has a visible footprint", clipped.size())
	check(inside, "view footprint is clipped inside map bounds")
	check(touches_edge, "zoomed-out footprint reaches the map boundary")

func has_outline_pixel(pixels: Image, at: Vector2) -> bool:
	for x in range(-2, 3):
		for y in range(-2, 3):
			var point := Vector2i(roundi(at.x) + x, roundi(at.y) + y)
			if point.x < 0 or point.y < 0 or point.x >= pixels.get_width() or point.y >= pixels.get_height():
				continue
			var color := pixels.get_pixelv(point)
			# Fractional viewport scaling may blend the thin cyan line into dark terrain.
			# Keep a red floor above the blue water background and require near-equal green/blue.
			if color.r > 0.34 and color.g > color.r and color.b > color.r and absf(color.b - color.g) < 0.07:
				return true
	return false
