extends Node
var failed := 0
var checks := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failed += 1
	print("PASS " if ok else "FAIL ", title)

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode, {"map_size": 2400, "starting_funds": 8000, "enemy_base": "allied", "fog_of_war": false})
		await exercise(mode)
	BattleRequest.configure_mission("m01", {})
	await exercise("campaign")
	print("AUTOSAVE checks=", checks, " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func exercise(mode: String) -> void:
	Engine.time_scale = 1.0
	var expected_mode: String = BattleRequest.rules_mode
	var screen = load("res://scenes/battle.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,900)
	viewport.world_2d = World2D.new()
	add_child(viewport)
	viewport.add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	var timer
	for child in screen.get_children():
		if child.get_script() == preload("res://scripts/save/battle_autosave.gd"): timer = child
	check(timer != null, mode + " installed")
	world.paused = false
	timer.elapsed = 0.0
	timer._process(59.0)
	check(is_equal_approx(timer.elapsed, 59.0), mode + " waits interval")
	world.paused = true
	timer._process(5.0)
	check(is_equal_approx(timer.elapsed, 59.0), mode + " paused timer frozen")
	world.paused = false
	world.ended = true
	timer._process(5.0)
	check(is_equal_approx(timer.elapsed, 59.0), mode + " results timer frozen")
	world.ended = false
	var manual := BattleSaves.save_slot(world, "quick")
	var before := FileAccess.get_sha256(BattleSaves.slot_path("quick"))
	timer._process(1.01)
	var saved := BattleSaves.read_slot("auto")
	check(manual.ok and saved.ok, mode + " automatic snapshot validated from disk")
	check(saved.ok and saved.snapshot.context.mode == expected_mode, mode + " saved mode")
	check(before == FileAccess.get_sha256(BattleSaves.slot_path("quick")), mode + " quick slot unchanged")
	if saved.ok:
		BattleSaves.pending = saved.snapshot
		BattleSaves.restore_pending(world)
		check(world.paused and not world.ended, mode + " restores paused battle")
		await get_tree().process_frame
		check_load_resume(world,viewport,mode)
	world.paused = false
	get_tree().paused = false
	Engine.time_scale = 3.0
	timer.elapsed = 0
	timer._process(30.0)
	check(is_equal_approx(timer.elapsed, 10.0), mode + " real time independent of speed")
	Engine.time_scale = 1.0
	var panel = preload("res://scripts/ui/save_panel.gd").new()
	panel.battle = world
	add_child(panel)
	panel.refresh()
	check(panel.slot_buttons.auto.save.disabled and not panel.slot_buttons.auto.load.disabled, mode + " auto slot read-only and loadable")
	panel.free()
	get_tree().paused = false
	viewport.free()
	await get_tree().process_frame

func click(viewport: SubViewport, pixel: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	viewport.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = pixel
		event.pressed = down
		viewport.push_input(event,true)

func check_load_resume(world, viewport: SubViewport, mode: String) -> void:
	var hud = world.hud
	var hint: Label = hud._load_pause_hint
	check(hint.is_visible_in_tree() and hint.text.contains("点击战场空白处") and hint.get_global_rect().has_point(Vector2(800,450)),mode+" persistent centered load hint")
	var blank := Vector2.INF
	for y in range(300,550,25):
		for x in range(600,950,25):
			var pixel := Vector2(x,y)
			var point: Vector2 = world.get_canvas_transform().affine_inverse()*pixel
			if not hud.covers_world_pixel(pixel) and world._pick_at(point,false)==null and world._pick_node_at(point,"resource_nodes")==null:
				blank=pixel
				break
		if blank.is_finite():break
	check(blank.is_finite(),mode+" uncovered ground fixture")
	if not blank.is_finite():return
	var point: Vector2 = world.get_canvas_transform().affine_inverse()*blank
	var tank = world.spawn_unit("MTNK","ally",point)
	tank.global_position += point-tank.art_center()
	world.select_unit(tank,false)
	click(viewport,blank)
	check(world._pick_at(point,false)==tank and world.paused,mode+" clicking a unit leaves restore paused")
	tank.global_position += Vector2(400,400)
	click(viewport,blank,MOUSE_BUTTON_RIGHT)
	click(viewport,hud.minimap.get_global_rect().get_center())
	check(world.paused and hint.visible,mode+" right click and minimap leave restore paused")
	hud._open_saves()
	click(viewport,blank)
	check(world.paused and hint.visible,mode+" modal cannot resume the match")
	hud.save_panel.close()
	var selection: Array = world.selected_units.duplicate()
	click(viewport,blank)
	check(not world.paused and not get_tree().paused and not hint.visible and hud.pause_btn.text=="暂停",mode+" ground click resumes restored battle")
	check(world.selected_units==selection and not world.dragging,mode+" resume click preserves selection")
	hud._toggle_pause()
	click(viewport,blank)
	check(world.paused and not hint.visible,mode+" later manual pause is unaffected")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	viewport.push_input(key,true)
	check(not world.paused and not get_tree().paused,mode+" pause hotkey still resumes")
