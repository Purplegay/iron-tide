extends Node
const Alert = preload("res://scripts/expedition/red_alert.gd")
var failed := 0
var checks := 0
var output := ""
var screen
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", label)
func shot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "capture "+label)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	check(Expedition.start("美国", "", 12345), "start isolated expedition")
	check(Expedition.choose(0), "opening reward")
	check(Expedition.launch(0), "launch expedition")
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world = screen.battle
	world.set_process(false)
	world.set_physics_process(false)
	for child in world.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	screen.expedition_runtime.set_process(false)
	var dock: Control = screen.hud.red_alert_panel
	var button = dock.get_child(0)
	check(dock.find_children("*", "Label", false, false).is_empty(), "gauge has no text row")
	check(is_equal_approx(dock.get_global_rect().end.y, button.threat_bar.get_global_rect().end.y), "housing sits flush with dock bottom")
	world.allied_state[Alert.KEY] = {"charge":0,"threat":24500.0,"left":0.0}
	await get_tree().create_timer(0.4).timeout
	check(button.reveal == 0.0 and button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "charging button hidden and ignores clicks")
	await shot("charging")
	world.allied_state[Alert.KEY].charge = 1
	await get_tree().create_timer(0.4).timeout
	check(button.reveal == 1.0 and not button.disabled, "ready button rises and enables")
	screen.hud._set_unit_menu_collapsed(false, false)
	world.clear_selection()
	world._emit_selection()
	await get_tree().process_frame
	for folded in [false,true,false]:
		screen.hud._set_unit_menu_collapsed(folded,false)
		var toggle_rect:Rect2=screen.hud.unit_menu_toggle.get_global_rect()
		var alert_rect:=dock.get_global_rect()
		check(is_equal_approx(alert_rect.end.y,toggle_rect.position.y) and is_equal_approx(alert_rect.position.x,toggle_rect.position.x),"empty selection docks above toggle " + str(folded))
	await shot("ready-empty")

	screen.hud.show_field_transmission("苏砚 · 前线研究员", preload("res://scripts/expedition/commander_keepsakes.gd").ITEMS.su.gift, "su")
	for i in 5: await get_tree().process_frame
	var radio:Control=screen.hud.field_radio
	var bounds:=radio.get_global_rect()
	var height:=get_viewport().get_visible_rect().size.y
	check(bounds.position.y>height*0.55 and absf(bounds.end.y-height+24)<2,"long field transmission anchored near bottom")
	check(bounds.encloses(radio.body.get_global_rect()) and bounds.size.y<height*0.35,"radio fits story without tall blank plate")
	check(screen.hud.minimap.radio_contact_id=="su","portrait remains on radar")
	screen.hud._topbar.show();screen.hud._layout_hud()
	await shot("su-bottom")
	check(radio.get_global_rect().is_equal_approx(bounds),"Esc toolbar does not move dialogue")
	screen.hud._topbar.hide();screen.hud._layout_hud()

	var tank = world.spawn_unit("MTNK", "ally", world.player_start()+Vector2(150,100))
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	world.select_unit(tank, false)
	world._emit_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	var expanded := dock.get_global_rect()
	check(expanded.position.x >= screen.hud.ability_panel.get_global_rect().end.x + 7.0 and is_equal_approx(dock.offset_bottom,-8.0), "expanded alert clears skills and sits at bottom")
	screen.hud._set_unit_menu_collapsed(true, false)
	var hud = screen.hud
	hud.set_process(false)
	var entries := []
	for i in 16: entries.append({"id":"status%d"%i,"name":"状态%d"%i,"icon":"speed"})
	for count in [14,16]:
		hud._clear_nodes(hud.buff_box)
		hud._buff_chips.clear()
		hud.buff_empty.hide()
		hud._fill_buff_grid(entries.slice(0,count))
		hud._fit_buff_panel()
		for frame in 4: await get_tree().process_frame
		check(hud.buff_box.get_child_count()==14,"two status rows")
		var more = hud.buff_box.get_node_or_null("StatusOverflow")
		if count==14: check(more==null,"exact fit needs no overflow")
		else:
			check(more!=null and more.tooltip_text.contains("其余 3 个状态") and more.tooltip_text.contains("状态15"),"overflow exposes hidden statuses")
		var lower_top := minf(hud._compact_vitals.global_position.y, hud.unit_menu_toggle.global_position.y)
		check(is_equal_approx(lower_top - button.threat_bar.get_global_rect().end.y, 4.0), "gauge housing docks four pixels above collapsed controls")
		check(dock.get_global_rect().end.y <= hud.unit_menu_toggle.global_position.y,"alert clears toggle")
	await shot("collapsed-overflow")
	hud._rebuild_buff_bar()
	for frame in 4: await get_tree().process_frame
	hud.set_process(true)
	screen.hud._set_unit_menu_collapsed(false, false)
	check(dock.get_global_rect().is_equal_approx(expanded), "reopening restores expanded position without drift")
	check(world.allied_state[Alert.KEY].left == 0.0 and world.allied_state[Alert.KEY].charge == 1, "selection never activates alert")
	check(not screen.hud._minimap_frame.get_global_rect().intersects(dock.get_global_rect()), "dock clears minimap")
	check(not screen.hud.sel_strip.get_global_rect().intersects(dock.get_global_rect()), "dock clears selected units")
	check(button.get_global_rect().end.y > button.threat_bar.get_global_rect().position.y + 25.0, "button base overlaps native gauge housing")
	check(screen.hud.sel_strip.get_global_rect().position.x > get_viewport().get_visible_rect().size.x * 0.7, "selected roster lives at bottom right")
	check(screen.hud.prod_panel.get_global_rect().encloses(screen.hud.sel_strip.get_global_rect()), "selected roster inside shared command deck")
	await shot("ready-selected")
	button.pressed.emit()
	check(float(world.allied_state[Alert.KEY].left) == Alert.DURATION and int(world.allied_state[Alert.KEY].charge) == 0, "explicit button activation")
	await get_tree().create_timer(0.4).timeout
	check(button.reveal == 0.0 and button.disabled, "running button retracts")
	await shot("active")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("RED_ALERT_UI checks=",checks," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
