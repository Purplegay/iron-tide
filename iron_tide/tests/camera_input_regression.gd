extends "res://tests/input_ownership_regression.gd"

func exercise_mode(mode: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	get_window().focus_entered.emit()
	await get_tree().process_frame
	check(battle.camera.zoom.is_equal_approx(Iso.cam_zoom(1.0)), mode + " new battle starts at reference overview scale")
	reset_camera()
	check_live_camera_settings(mode)
	check_edges(mode)
	await check_top_edge(mode)
	var u = battle.spawn_unit("MTNK", "ally", Vector2(2400, 2500))
	u.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(u, false)
	await check_camera_motion(mode, u)
	await check_follow_pose(mode, u)
	check_pan_speed(mode)
	await check_middle_reset(mode, u)
	await check_pan_ownership(mode, u)
	await check_focus_pause(mode, u)
	await check_right_window_exit(mode)
	screen.free()
	await get_tree().process_frame

func check_top_edge(mode: String) -> void:
	var bar: Control = screen.hud._topbar
	var top: float = bar.get_global_rect().end.y
	var x: float = battle.camera_play_rect().get_center().x
	for offset in [1.0, 14.0, 27.0]:
		check(battle.camera_edge_pan_dir(Vector2(x, top + offset)) == Vector2.UP, mode + ": resource bar lower edge scrolls up " + str(offset))
	check(battle.camera_edge_pan_dir(Vector2(x, top + 28)) == Vector2.ZERO, mode + ": top scroll band ends at 28 pixels")
	check(battle.camera_edge_pan_dir(Vector2(x, top - 1)) == Vector2.ZERO, mode + ": resource bar is not the new scroll band")
	var point := Vector2(x, top + 1)
	await move_pointer(point)
	check(stage.gui_get_hovered_control() == null, mode + ": top edge strip is exposed battlefield")
	check(battle.edge_pointer_direction(point, Vector2.ZERO, false) == Vector2.UP, mode + ": live top edge reaches input routing")
	check(battle.edge_pointer_direction(point, Vector2.ZERO, true) == Vector2.ZERO, mode + ": overlay retains ownership of top edge")
	check(battle.edge_pointer_direction(bar.get_global_rect().get_center(), Vector2.ZERO, true) == Vector2.ZERO, mode + ": resource buttons do not scroll")
	var height: float = bar.size.y
	bar.size.y = height + 20
	check(battle.camera_edge_pan_dir(Vector2(x, bar.get_global_rect().end.y + 1)) == Vector2.UP, mode + ": top edge follows live HUD height")
	bar.size.y = height
	await move_pointer(Vector2(800, 400))

func check_right_window_exit(mode: String) -> void:
	reset_camera()
	battle.edge_scroll_enabled=true
	var panel: Rect2=screen.hud.prod_panel.get_global_rect()
	var point:=panel.position+Vector2(40,120)
	await move_pointer(point)
	check(battle._pointer_on_production_panel(point),mode+": real production control owns the inside sample")
	var before: Vector2=battle.camera.position
	battle._update_camera(0.1)
	check(battle.camera.position==before,mode+": hovering production controls does not scroll")
	check(battle.edge_pointer_direction(point,Vector2.ZERO,true)==Vector2.ZERO,mode+": production panel arms only outside continuation")
	for outside in [Vector2.RIGHT,Vector2(1,-1),Vector2(1,1)]:
		check(battle.edge_pointer_direction(point,outside,true)==outside,mode+": slow exit across panel ignores stale GUI hover "+str(outside))
	check(battle.edge_pointer_direction(point,Vector2.LEFT,true)==Vector2.ZERO,mode+": production panel cannot arm opposite edge")
	check(battle.edge_pointer_direction(point,Vector2.UP,true)==Vector2.ZERO,mode+": production panel cannot arm title-bar exit")
	check(battle.edge_pointer_direction(point,Vector2.ZERO,true)==Vector2.ZERO,mode+": returning to panel stops scrolling immediately")
	# A fast crossing can skip all intermediate panel samples.
	var middle:=Vector2(800,400)
	await move_pointer(middle)
	battle.edge_pointer_direction(middle,Vector2.ZERO,false)
	check(battle.edge_pointer_direction(middle,Vector2.RIGHT,true)==Vector2.RIGHT,mode+": fast crossing from battlefield still scrolls")
	await move_pointer(point)
	battle.edge_pointer_direction(point,Vector2.ZERO,true)
	battle._on_window_focus_exited()
	check(battle.edge_pointer_direction(point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": focus loss clears production exit continuation")
	battle._on_window_focus_entered()
	check(battle.edge_pointer_direction(point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": focus regain outside cannot resurrect old continuation")
	battle.edge_pointer_direction(point,Vector2.ZERO,true)
	battle.paused=true
	check(battle.edge_pointer_direction(point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": pause rejects production exit scrolling")
	battle.paused=false
	check(battle.edge_pointer_direction(point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": resume outside remains disarmed")
	battle.edge_pointer_direction(point,Vector2.ZERO,true)
	battle.edge_scroll_enabled=false
	battle._update_camera(0.1)
	check(not battle._edge_from_right_panel,mode+": disabled edge scrolling clears panel origin")
	battle.edge_scroll_enabled=true
	var minimap:Control=screen.hud.minimap
	var map_point:=minimap.get_global_rect().get_center()
	await move_pointer(map_point)
	battle.edge_pointer_direction(map_point,Vector2.ZERO,true)
	check(battle.edge_pointer_direction(map_point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": minimap cannot arm production exit continuation")
	# An unrelated overlay covering the same position must still own its input.
	var overlay:=Panel.new()
	overlay.position=point-Vector2(20,20); overlay.size=Vector2(80,80)
	screen.hud.add_child(overlay)
	await move_pointer(point)
	battle.edge_pointer_direction(point,Vector2.ZERO,true)
	check(not battle._pointer_on_production_panel(point) and battle.edge_pointer_direction(point,Vector2.RIGHT,true)==Vector2.ZERO,mode+": overlay over production panel cannot arm scrolling")
	overlay.free()
	await move_pointer(middle)

func reset_camera() -> void:
	battle.follow_target = null
	battle.camera.position = Vector2(2500, 2500)
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()

func check_follow_pose(mode: String, unit: Unit) -> void:
	reset_camera()
	battle.edge_scroll_enabled=false
	battle.select_unit(unit,false)
	await move_pointer(Vector2(800,400))
	await key(KEY_F)
	check(battle.follow_target==unit,mode+": F enters follow through actual HUD input")
	var original: Vector2=unit.global_position
	var sampled_between_steps := false
	for zoom in [0.5,1.0,2.0]:
		battle.camera.zoom=Iso.cam_zoom(zoom)
		for i in 8:
			await get_tree().process_frame
			# Controlled consecutive physics poses; use the real render fraction.
			unit.global_position=original+Vector2(i*12,i*6)
			unit.motion_pose.previous_position=unit.global_position-Vector2(12,6)
			var logical: Vector2=unit.global_position
			var shown: Vector2=unit.presentation_position()
			sampled_between_steps=sampled_between_steps or shown.distance_to(logical)>0.1
			battle._update_camera(1.0/60.0)
			var pixel: Vector2=stage.get_canvas_transform()*shown
			check(pixel.distance_to(battle.camera_play_rect().get_center())<0.05,mode+": follow keeps rendered unit centered in the same frame "+str([zoom,i]),pixel)
			check(unit.global_position==logical,mode+": camera sampling preserves logical position")
	check(sampled_between_steps,mode+": fixture exercises display/logic position mismatch")
	unit.global_position=original+Vector2(300,200)
	unit.reset_physics_interpolation()
	battle._update_camera(1.0/60.0)
	check((stage.get_canvas_transform()*unit.global_position).distance_to(battle.camera_play_rect().get_center())<0.05,mode+": teleport/reset follows current pose without stale trail")
	await key(KEY_F)
	check(battle.follow_target==null,mode+": F toggles follow off")
	var camera_before: Vector2=battle.camera.position
	unit.global_position+=Vector2(100,0)
	battle._update_camera(1.0/60.0)
	check(battle.camera.position==camera_before,mode+": camera remains still after follow cancellation")
	unit.global_position=original
	unit.reset_physics_interpolation()
	reset_camera()

func check_edges(mode: String) -> void:
	for vp in [Vector2(1280, 720), Vector2(1600, 900), Vector2(2560, 1440)]:
		for pair in [
			[Vector2(1, 100), Vector2.LEFT],
			[Vector2(vp.x - 1, 100), Vector2.RIGHT],
			[Vector2(100, 1), Vector2.UP],
			[Vector2(100, vp.y - 1), Vector2.DOWN],
			[Vector2(1, 1), Vector2(-1, -1)],
			[vp - Vector2.ONE, Vector2.ONE],
			[Vector2(vp.x - 1, 1), Vector2(1, -1)],
			[Vector2(1, vp.y - 1), Vector2(-1, 1)],
			[Vector2(-1, 200), Vector2.ZERO],
			[Vector2(vp.x + 1, 200), Vector2.ZERO],
			[Vector2(200, -1), Vector2.ZERO],
			[Vector2(200, vp.y), Vector2.ZERO],
			[Vector2(10, 100), Vector2.LEFT],
			[Vector2(27, 100), Vector2.LEFT],
			[Vector2(28, 100), Vector2.ZERO],
			[Vector2(vp.x - 28, 100), Vector2.RIGHT],
			[Vector2(vp.x - 29, 100), Vector2.ZERO],
			[Vector2(100, 10), Vector2.ZERO]]:
			check(battle.edge_pan_dir(pair[0], vp) == pair[1],
				mode + ": edge direction " + str(vp) + " " + str(pair[0]))

func check_camera_motion(mode: String, u) -> void:
	battle.edge_scroll_enabled = true
	# Cover a HUD that reaches the edge, not the default 8 px outside margin.
	var right_margin: float = screen.hud.prod_panel.offset_right
	screen.hud.prod_panel.offset_right = 0.0
	await get_tree().process_frame
	await move_pointer(Vector2(1599, 400))
	check(stage.gui_get_hovered_control() != null, mode + ": edge point hits real production HUD")
	var before: Vector2 = battle.camera.position
	battle._update_camera(0.1)
	check(battle.camera.position.is_equal_approx(before), mode + ": HUD edge does not scroll")
	screen.hud.prod_panel.offset_right = right_margin
	await move_pointer(Vector2(1, 400))
	check(stage.gui_get_hovered_control() == null, mode + ": left edge fixture is world")
	before = battle.camera.position
	battle._update_camera(0.1)
	if DisplayServer.get_name() == "headless":
		check(battle.camera.position.is_equal_approx(before), mode + ": headless skips physical mouse edge scrolling")
	else:
		check(not battle.camera.position.is_equal_approx(before), mode + ": exposed world edge scrolls")
		for frame_time in [1.0 / 60.0, 0.1, 0.16, 0.5]:
			reset_camera()
			await move_pointer(Vector2(20, 400))
			before = battle.camera.position
			battle._update_camera(frame_time)
			var shift: Vector2 = (battle.camera.position - before).rotated(-battle.camera.rotation) * battle.camera.zoom
			check(shift.distance_to(Vector2.LEFT * battle.cam_speed * minf(frame_time, 0.2)) < 0.01,
				mode + ": wide edge preserves speed on slow frames and bounds stalls " + str(frame_time), shift)
	var panel: Rect2 = screen.hud.prod_panel.get_global_rect()
	check(battle.camera_edge_pan_dir(Vector2(panel.position.x - 20, panel.position.y + 120)) == Vector2.RIGHT,
		mode + ": wider battlefield strip beside sidebar scrolls right")
	check(battle.edge_pointer_direction(panel.position + Vector2(20, 120), Vector2.ZERO, true) == Vector2.ZERO,
		mode + ": production controls retain mouse ownership")
	await move_pointer(Vector2(800, 400))
	battle.edge_scroll_enabled = false
	reset_camera()
	battle.follow_target = u
	Input.action_press("ui_right")
	battle._update_camera(0.1)
	Input.action_release("ui_right")
	var expected: Vector2 = Vector2(2500, 2500) + battle.screen_pan_to_world(Vector2(117, 0))
	check(battle.follow_target == null and battle.camera.position.distance_to(expected) < 0.01,
		mode + ": keyboard pan cancels follow and moves along screen axis", battle.camera.position)
	# The real GUI focus owner must prevent global action polling from panning.
	var edit := LineEdit.new()
	stage.add_child(edit)
	edit.grab_focus()
	reset_camera()
	Input.action_press("ui_left")
	battle._update_camera(0.1)
	Input.action_release("ui_left")
	check(battle.camera.position == Vector2(2500, 2500), mode + ": text editing owns arrows")
	check(stage.gui_get_focus_owner() == edit, mode + ": real LineEdit owns keyboard focus")
	edit.release_focus()
	edit.free()
	battle.follow_target = u
	var minimap: Control = screen.hud.minimap
	var point := minimap.get_global_rect().get_center()
	await move_pointer(point)
	await mouse_button(point, true)
	await mouse_button(point, false)
	before = battle.camera.position
	battle._update_camera(0.1)
	check(battle.follow_target == null and battle.camera.position.is_equal_approx(before),
		mode + ": minimap centering cancels follow without snap-back")

# Measure actual camera displacement back in screen coordinates, including vertical
# isometric compensation. Existing drag tests keep the direct grab gesture 1:1.
func check_pan_speed(mode: String) -> void:
	var old_setting: int = MetaProgress.scroll_speed
	var old_speed: float = battle.cam_speed
	for setting in [10, 50, 100]:
		MetaProgress.scroll_speed = setting
		battle.cam_speed = MetaProgress.scroll_px_per_sec()
		check(is_equal_approx(battle.cam_speed, 1170.0 * setting / 50.0), mode + ": scroll setting scales 1.5x " + str(setting))
		for zoom in [0.5, 1.0, 2.0]:
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2.ONE.normalized()]:
				reset_camera()
				battle.camera.zoom = Iso.cam_zoom(zoom)
				var before: Vector2 = battle.camera.position
				var actions: Array[String] = []
				if direction.x != 0: actions.append("ui_right" if direction.x > 0 else "ui_left")
				if direction.y != 0: actions.append("ui_down" if direction.y > 0 else "ui_up")
				for action in actions: Input.action_press(action)
				battle._update_camera(0.1)
				for action in actions: Input.action_release(action)
				var screen_shift: Vector2 = (battle.camera.position - before).rotated(-battle.camera.rotation) * battle.camera.zoom
				check(screen_shift.distance_to(direction * battle.cam_speed * 0.1) < 0.01,
					mode + ": screen-axis pan " + str([setting, zoom, direction]), screen_shift)
	MetaProgress.scroll_speed = old_setting
	battle.cam_speed = old_speed
	reset_camera()

func check_pan_ownership(mode: String, u) -> void:
	reset_camera()
	check(battle.right_click_scroll, mode + ": right drag enabled in a new match")
	var at := Vector2(800, 400)
	u.has_move_order = false
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(battle._rmb_panning and not u.has_move_order, mode + ": middle pan owns gesture across right click")
	var before: Vector2 = battle.camera.position
	await move_pointer(at + Vector2(20, 0), MOUSE_BUTTON_MASK_MIDDLE, Vector2(20, 0))
	check(not battle.camera.position.is_equal_approx(before), mode + ": owning middle button continues pan")
	await mouse_button(at + Vector2(20, 0), false, false, MOUSE_BUTTON_MIDDLE)
	check(not battle._rmb_panning and not u.has_move_order, mode + ": middle release never orders units")
	await move_pointer(at)
	before = battle.camera.position
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	check(battle._rmb_panning, mode + ": right pan ignores unrelated middle release")
	await move_pointer(at + Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT, Vector2(20, 0))
	await mouse_button(at + Vector2(20, 0), false, false, MOUSE_BUTTON_RIGHT)
	check(battle.camera.position.distance_to(before + battle.screen_pan_to_world(Vector2(-20, 0))) < 0.01, mode + ": right drag matches middle-button displacement")
	check(not battle._rmb_panning and not u.has_move_order, mode + ": right drag ends without order")
	# Aiming also waits for the release before treating the gesture as a cancel.
	battle.cast_slot = 0
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await move_pointer(at + Vector2(18, 3), MOUSE_BUTTON_MASK_RIGHT, Vector2(18, 3))
	await mouse_button(at + Vector2(18, 3), false, false, MOUSE_BUTTON_RIGHT)
	check(battle.cast_slot == 0, mode + ": right drag keeps targeting active")
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(battle.cast_slot < 0, mode + ": stationary right click cancels targeting")
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	before = battle.camera.position
	await move_pointer(at + Vector2(25, 0), 0, Vector2(25, 0))
	check(not battle._rmb_panning and battle.camera.position.is_equal_approx(before),
		mode + ": missing button release is recovered from motion mask")
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	# A normal right click retains the existing command behavior.
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(u.has_move_order, mode + ": normal right click still issues move")
	u.order_stop()

func check_focus_pause(mode: String, u) -> void:
	var at := Vector2(800, 400)
	reset_camera()
	await move_pointer(at)
	await mouse_button(at, true)
	check(battle.dragging, mode + ": real left gesture begins")
	get_window().focus_exited.emit()
	check(not battle.dragging, mode + ": focus loss cancels selection gesture")
	get_window().focus_entered.emit()
	await mouse_button(at, false)
	check(battle.selected_units.has(u), mode + ": stale release after refocus does not clear selection")
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	get_window().focus_exited.emit()
	check(not battle._rmb_panning, mode + ": focus loss cancels pan")
	var before: Vector2 = battle.camera.position
	Input.action_press("ui_right")
	battle._update_camera(0.1)
	Input.action_release("ui_right")
	await move_pointer(at + Vector2(20, 0), MOUSE_BUTTON_MASK_MIDDLE, Vector2(20, 0))
	check(battle.camera.position.is_equal_approx(before), mode + ": unfocused camera ignores keys and motion")
	get_window().focus_entered.emit()
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	var minimap: Control = screen.hud.minimap
	var point := minimap.get_global_rect().get_center()
	await move_pointer(point)
	await mouse_button(point, true)
	check(minimap._dragging, mode + ": minimap drag begins")
	get_window().focus_exited.emit()
	check(not minimap._dragging, mode + ": focus loss cancels minimap drag")
	get_window().focus_entered.emit()
	await mouse_button(point, false)
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_RIGHT)
	screen.hud._toggle_pause()
	check(get_tree().paused and not battle._rmb_panning, mode + ": pause cancels unfinished pan")
	before = battle.camera.position
	await move_pointer(at + Vector2(20, 0), MOUSE_BUTTON_MASK_RIGHT, Vector2(20, 0))
	check(battle.camera.position.is_equal_approx(before), mode + ": paused drag cannot move camera")
	await move_pointer(point)
	await mouse_button(point, true)
	check(not minimap._dragging and battle.camera.position.is_equal_approx(before),
		mode + ": paused minimap rejects new camera gesture")
	await mouse_button(point, false)
	screen.hud._toggle_pause()
	await mouse_button(at, false, false, MOUSE_BUTTON_RIGHT)
	check(not u.has_move_order and not battle._rmb_panning, mode + ": stale release after resume never issues order")

func check_middle_reset(mode: String, unit) -> void:
	var at := Vector2(800, 400)
	get_window().focus_entered.emit()
	for scale in [0.45, 1.0, 2.0, 3.2]:
		reset_camera()
		battle.camera.zoom = Iso.cam_zoom(scale)
		battle.view_zoom = scale
		battle.camera.force_update_scroll()
		await move_pointer(at)
		var focus: Vector2 = battle.camera.position + battle.camera_focus_offset()
		var angle: float = battle.camera.rotation
		unit.order_stop()
		battle.select_unit(unit, false)
		await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
		check(battle.camera.zoom == Iso.cam_zoom(scale), mode + " middle press waits for click or drag " + str(scale))
		await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
		check(battle.camera.zoom == Iso.cam_zoom(battle.DEFAULT_VIEW_ZOOM) and battle.view_zoom == battle.DEFAULT_VIEW_ZOOM, mode + " middle click restores default scale " + str(scale))
		check((battle.camera.position + battle.camera_focus_offset()).distance_to(focus) < 0.01 and battle.camera.rotation == angle, mode + " reset preserves usable center and angle " + str(scale))
		check(battle.selected_units.has(unit) and not unit.has_move_order and not battle._rmb_panning, mode + " reset preserves selection and never orders unit " + str(scale))
	# A real middle drag retains the current scale after release.
	battle.camera.zoom = Iso.cam_zoom(1.0)
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	await move_pointer(at + Vector2(30, 0), MOUSE_BUTTON_MASK_MIDDLE, Vector2(30, 0))
	await mouse_button(at + Vector2(30, 0), false, false, MOUSE_BUTTON_MIDDLE)
	check(battle.camera.zoom == Iso.cam_zoom(1.0), mode + " middle drag never resets zoom")
	# HUD and minimap own their clicks, including release of a world gesture.
	for point in [screen.hud.prod_panel.get_global_rect().get_center(), screen.hud.minimap.get_global_rect().get_center()]:
		await move_pointer(point)
		await mouse_button(point, true, false, MOUSE_BUTTON_MIDDLE)
		await mouse_button(point, false, false, MOUSE_BUTTON_MIDDLE)
		check(battle.camera.zoom == Iso.cam_zoom(1.0) and not battle._rmb_panning, mode + " GUI middle click does not reset world")
	await move_pointer(at)
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	get_window().focus_exited.emit()
	get_window().focus_entered.emit()
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	check(battle.camera.zoom == Iso.cam_zoom(1.0), mode + " stale release after focus loss never resets")
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	screen.hud._toggle_pause()
	screen.hud._toggle_pause()
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	check(battle.camera.zoom == Iso.cam_zoom(1.0), mode + " stale release after pause never resets")
	# Clicking with a building ready must not cancel or consume that building.
	battle.armed_build = "GAPOWR"
	battle.struct_ready.GAPOWR = 1
	await mouse_button(at, true, false, MOUSE_BUTTON_MIDDLE)
	await mouse_button(at, false, false, MOUSE_BUTTON_MIDDLE)
	check(battle.camera.zoom == Iso.cam_zoom(battle.DEFAULT_VIEW_ZOOM) and battle.armed_build == "GAPOWR" and battle.struct_ready.GAPOWR == 1, mode + " reset works during placement without consuming or cancelling")
	battle.armed_build = ""
	battle.struct_ready.erase("GAPOWR")

func check_live_camera_settings(mode: String) -> void:
	check(screen.hud.settings_panel.get_child(0) is ScrollContainer and screen.hud.settings_panel.offset_bottom <= screen.get_viewport_rect().size.y,mode+": in-battle settings stay within viewport and scroll")
	var controls = screen.hud.settings_panel.find_child("CameraControls",true,false)
	check(controls != null,mode+": in-battle camera controls available")
	var old: int = MetaProgress.scroll_speed
	MetaProgress.set_scroll_speed(75)
	check(is_equal_approx(battle.cam_speed,1755.0) and controls.slider.value==75 and "2.25" in controls.readout.text,mode+": live battle camera speed and multiplier sync")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(MetaProgress.SAVE_PATH))
	check(saved.scroll_speed==75,mode+": camera setting persisted")
	MetaProgress.set_scroll_speed(60,false)
	saved = JSON.parse_string(FileAccess.get_file_as_string(MetaProgress.SAVE_PATH))
	check(saved.scroll_speed==75 and is_equal_approx(battle.cam_speed,1404.0),mode+": live drag previews without disk writes")
	controls._commit_drag(true)
	saved = JSON.parse_string(FileAccess.get_file_as_string(MetaProgress.SAVE_PATH))
	check(saved.scroll_speed==60,mode+": completed drag saves final setting")
	MetaProgress.set_edge_scroll(false)
	check(not battle.edge_scroll_enabled and not controls.edge.button_pressed and controls.slider.editable,mode+": disabling edges leaves keyboard speed adjustable")
	MetaProgress.set_edge_scroll(true)
	MetaProgress.set_scroll_speed(old)
