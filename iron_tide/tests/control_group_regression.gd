extends "res://tests/selection_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 5000, "starting_funds": 20000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.hud.set_process(false)
	GM.god_mode = false
	GM.one_shot_kill = false
	var a = battle.spawn_unit("E1", "ally", Vector2(2200, 2400))
	var b = battle.spawn_unit("MTNK", "ally", Vector2(2800, 2600))
	var transport = battle.spawn_unit("SHAD", "ally", Vector2(2200, 2400))
	for actor in [a, b, transport]:
		actor.process_mode = Node.PROCESS_MODE_ALWAYS
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.order_stop()
	battle.camera.zoom = Iso.cam_zoom(2.0)
	await get_tree().physics_frame
	battle.select_unit(a, false)
	press(KEY_1, true)
	battle.select_unit(b, false)
	press(KEY_2, true)
	check(battle.control_groups["1"] == [a] and battle.control_groups["2"] == [b],
		mode + ": Ctrl+digit stores independent groups")
	battle.clear_selection()
	press(KEY_1)
	check(battle.selected_units == [a], mode + ": digit recalls group")
	# All events in the same frame: deterministic rapid 1,2,1 rather than sleeps.
	battle.center_on(Vector2(2500, 2500))
	var before: Vector2 = battle.camera.position
	press(KEY_2)
	press(KEY_1)
	check(battle.selected_units == [a] and battle.camera.position == before,
		mode + ": alternating groups does not count as a double tap")
	# A double tap must reselect as well as center if selection changed in between.
	battle.select_unit(b, false)
	press(KEY_1)
	check(battle.selected_units == [a] and focused_on(a.global_position),
		mode + ": double tap selects and centers its own group")
	battle.select_unit(b, false)
	press(KEY_1, false, true)
	check(battle.selected_units == [b] and focused_on(a.global_position),
		mode + ": Alt+digit centers without replacing selection")
	battle.select_unit(a, false)
	press(KEY_0, true)
	battle.clear_selection()
	press(KEY_0)
	check(battle.control_groups["10"] == [a] and battle.selected_units == [a],
		mode + ": zero key addresses group ten")
	check(battle.control_group_badge(a)=="10",mode+": overlapping groups show the 1 and 0 keys")
	battle.hp_overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	var frame := stage.get_texture().get_image()
	var bar:Rect2 = a.hp_bar_rect()
	var anchor:Vector2i = Vector2i((stage.get_canvas_transform()*a.global_position + Vector2(bar.position.x,bar.end.y)*battle.camera.zoom.x + Vector2(0,2)).round())
	for offset in [0,11]:
		var matches := 0
		for y in range(1,12):
			for x in range(1,9):
				var pixel := anchor+Vector2i(offset+x,y)
				if not Rect2i(Vector2i.ZERO,frame.get_size()).has_point(pixel): continue
				var sample := frame.get_pixelv(pixel)
				if Vector3(sample.r,sample.g,sample.b).distance_to(Vector3(HouseColor.player_color().r,HouseColor.player_color().g,HouseColor.player_color().b))<0.22: matches+=1
		check(matches>=3,mode+": rendered group digit "+str(offset)+" contains team-colour pixels",matches)
	battle.clear_selection()
	a.set_hovered(true)
	check(battle.control_group_badge(a)=="10",mode+": hovered own member reveals groups")
	a.set_hovered(false)
	check(battle.control_group_badge(a).is_empty(),mode+": no badge on uninspected unit")
	battle.select_unit(a,false)
	# Input while editing text must leave the group and camera alone.
	var edit := LineEdit.new()
	stage.add_child(edit)
	edit.grab_focus()
	press(KEY_2)
	check(battle.selected_units == [a], mode + ": text field owns numeric input")
	edit.release_focus()
	edit.free()
	# Reassigning replaces the group; an empty selection cannot erase it.
	battle.select_unit(b, false)
	press(KEY_2, true)
	battle.select_unit(a, false)
	press(KEY_2, true)
	battle.clear_selection()
	press(KEY_2, true)
	press(KEY_2)
	check(battle.control_groups["2"] == [a] and battle.selected_units == [a],
		mode + ": reassignment replaces members and empty assignment preserves group")
	b.set_hovered(true)
	check(battle.control_group_badge(b).is_empty() and battle.control_group_badge(a)=="120",mode+": overwriting removes the old member badge")
	b.set_hovered(false)
	# Use actual boarding and unload logic; membership survives temporary stowage.
	# Flight now consumes YR height/climb; allow descent plus one second to board.
	var landing_ticks := int(ceil(transport.flight.height / transport.flight.climb * 60.0)) + 60
	check(not battle.in_water_world(transport.position), mode + ": boarding fixture is on land")
	check(a.logistics.request_board(transport), mode + ": real boarding order accepted")
	for tick in landing_ticks:
		transport._physics_process(1.0 / 60.0)
		a._physics_process(1.0 / 60.0)
		if a.embarked_in != null:
			break
	a.set_hovered(true)
	check(battle.control_group_badge(a).is_empty(),mode+": stowed unit hides badge")
	a.set_hovered(false)
	check(a.embarked_in == transport, mode + ": passenger is actually stowed")
	battle.select_unit(b, false)
	battle.center_on(Vector2(2500, 2500))
	before = battle.camera.position
	battle.select_control_group(1)
	battle.center_control_group(1)
	check(battle.selected_units == [b] and battle.selected_building == null and not a.selected,
		mode + ": stowed-only group preserves selection and cannot become a building")
	check(battle.camera.position == before and battle.control_groups["1"] == [a],
		mode + ": stowed member remains recorded without moving camera")
	check(transport.logistics.request_unload(), mode + ": real unload order accepted")
	for tick in landing_ticks:
		transport._physics_process(1.0 / 60.0)
		if a.embarked_in == null:
			break
	check(a.embarked_in == null, mode + ": real unload succeeds")
	battle.select_control_group(1)
	check(battle.selected_units == [a] and battle.selected_building == null,
		mode + ": unloaded member can be recalled again")
	# Dead actors can remain alive as Godot objects during their death animation.
	battle.select_unit(a, false)
	battle.select_unit(b, true)
	press(KEY_3, true)
	a.receive_hit(a.max_hp * 10.0)
	check(a._dead and is_instance_valid(a), mode + ": death-animation fixture retains object")
	battle.select_control_group(3)
	check(battle.selected_units == [b] and battle.selected_building == null,
		mode + ": recall excludes dying member without misclassifying it")
	check(battle.control_groups["3"] == [b], mode + ": dead member removed from group")
	battle.center_control_group(3)
	check(focused_on(b.global_position),
		mode + ": focus averages living available members only")
	# Freed objects and empty groups must not clear an unrelated current selection.
	var removed = battle.spawn_unit("MTNK", "ally", Vector2(3000, 2500))
	battle.select_unit(removed, false)
	press(KEY_4, true)
	battle.select_unit(b, false)
	battle.units.erase(removed)
	removed.free()
	battle.select_control_group(4)
	check(battle.control_groups["4"].is_empty() and battle.selected_units == [b],
		mode + ": freed-only group preserves current selection")
	var building = battle.buildings.filter(func(x): return is_instance_valid(x) and x.side == "ally")[0]
	battle.select_building(building)
	press(KEY_5, true)
	battle.select_unit(b, false)
	press(KEY_5)
	check(battle.selected_building == building and battle.selected_units.is_empty(),
		mode + ": building group remains a building-only selection")
	check(battle.control_group_badge(building)=="5",mode+": grouped building badge")
	# A key for an unassigned group is not a second tap of the previous group.
	battle.center_on(Vector2(2500, 2500))
	before = battle.camera.position
	press(KEY_9)
	press(KEY_5)
	check(battle.camera.position == before and battle.selected_building == building,
		mode + ": unassigned intervening group breaks double tap")
	screen.free()
	await get_tree().process_frame

func press(code: Key, ctrl := false, alt := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		event.alt_pressed = alt
		stage.push_input(event, true)

func focused_on(point: Vector2) -> bool:
	battle.camera.force_update_scroll()
	var pixel: Vector2 = stage.get_canvas_transform() * point
	return pixel.distance_to(battle.camera_play_rect().get_center()) < 1.0
