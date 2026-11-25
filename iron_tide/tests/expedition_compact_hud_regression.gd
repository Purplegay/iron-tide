extends Node
var checks:=0
var failed:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",message)

func capture_panel(filename:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join(filename))

func mouse_button_at(point:Vector2,button:MouseButton) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=button
		event.pressed=down
		get_viewport().push_input(event,true)

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	check(Expedition.start("美国","",12345),"start")
	check(Expedition.choose(0),"reward")
	check(Expedition.launch(0),"launch")
	var screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.battle.set_process(false);screen.battle.set_physics_process(false)
	var runtime=screen.expedition_runtime
	for i in 6:await get_tree().process_frame
	var panel=screen.hud.expedition_panel
	check(not runtime.hud_details.visible,"starts compact")
	var compact_size:Vector2=panel.size
	check(compact_size.x<=340 and compact_size.y<=220,"compact summary and two rows of commands fit "+str(compact_size))
	check(runtime.status.text.contains("增援"),"reinforcements visible")
	await capture_panel("compact.png")
	runtime.hud_toggle.pressed.emit()
	for i in 5:await get_tree().process_frame
	check(runtime.hud_details.visible,"details expand")
	check(panel.size.y>compact_size.y,"opening details adds space for the briefing")
	check(panel.size.x<=340,"expanded stays narrow")
	await capture_panel("expanded.png")
	var collapse:Button=runtime.hud_toggle.get_parent().get_child(1)
	mouse_button_at(collapse.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	for i in 5:await get_tree().process_frame
	check(runtime.hud_objective_only and not runtime.status.is_visible_in_tree() and not collapse.visible,"only objective header remains")
	check(runtime.hud_toggle.text==runtime.status.text.get_slice("\n",0),"header shows main objective progress")
	check(panel.size.y<compact_size.y,"objective-only panel takes less space")
	mouse_button_at(runtime.hud_toggle.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
	for i in 5:await get_tree().process_frame
	check(runtime.hud_details.is_visible_in_tree() and collapse.visible,"clicking progress restores expanded view")
	var hud=screen.hud
	var scroll:ScrollContainer=hud._expedition_scroll
	# Force a briefing longer than the viewport regardless of the generated mission.
	runtime.hud_detail_status.custom_minimum_size.y=scroll.get_viewport_rect().size.y
	for i in 7: hud.make_support_button()
	hud._sw_sidebar.refresh()
	for i in 8:await get_tree().process_frame
	check(scroll.get_v_scroll_bar().visible,"long briefing shows a scrollbar")
	check(hud._sw_sidebar.is_visible_in_tree() and panel.get_global_rect().end.x<=hud._sw_sidebar.global_position.x,"briefing clears visible support")
	check(hud._sw_sidebar.get_global_rect().end.y<=hud.red_alert_panel.global_position.y,"support clears alert")
	var header:Rect2=runtime.hud_toggle.get_global_rect()
	var zoom:Vector2=screen.battle.camera.zoom
	var last_pin:=runtime.hud_details.get_child(-1) as Button
	check(last_pin!=null,"briefing contains a tracking button")
	for i in 100:mouse_button_at(scroll.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().process_frame
	check(scroll.scroll_vertical>0 and runtime.hud_toggle.get_global_rect()==header,"wheel scrolls beneath the fixed header")
	check(screen.battle.camera.zoom==zoom,"scrolling leaves camera zoom unchanged")
	if last_pin!=null:
		check(scroll.get_global_rect().encloses(last_pin.get_global_rect()),"last tracking button fully inside visible area")
		var before:String=runtime.field_ops.data.get("tracked","")
		mouse_button_at(last_pin.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
		check(runtime.field_ops.data.get("tracked","")!=before,"last tracking button receives the click")
		await get_tree().process_frame
		mouse_button_at(last_pin.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
		check(runtime.field_ops.data.get("tracked","")==before,"cancel tracking restores the original summary")
	runtime.hud_detail_status.custom_minimum_size.y=0
	runtime.hud_toggle.pressed.emit()
	for i in 5:await get_tree().process_frame
	check(not runtime.hud_details.visible and panel.size.is_equal_approx(compact_size),"collapses back to its original size")
	check(scroll.scroll_vertical==0,"collapse resets scrolling")
	check(hud._expedition_tabs.get_child_count()==2 and not hud.log_btn.visible,"two tabs replace old intel toggle")
	check(panel.get_parent()==hud.log_panel.get_parent(),"pages share layout parent")
	hud._expedition_tab_buttons.intel.pressed.emit()
	for i in 5:await get_tree().process_frame
	check(hud.log_panel.visible and not panel.visible,"intel page excludes expedition")
	check(hud.covers_world_pixel(hud._expedition_tabs.get_global_rect().get_center()),"tab clicks belong to HUD")
	hud._on_message("很长的情报消息，用来验证内容换行，不会把左上面板横向撑到战场中央。".repeat(5),Color.WHITE)
	for i in 5:await get_tree().process_frame
	check(hud.log_panel.size.x<=340 and hud.log_panel.size.y<230,"intel wraps and scrolls within bounds")
	await capture_panel("intel.png")
	hud._expedition_tab_buttons.expedition.pressed.emit()
	for i in 5:await get_tree().process_frame
	check(panel.visible and not hud.log_panel.visible,"return to expedition excludes intel")
	check(panel.get_global_rect().position.y>=hud._expedition_tabs.get_global_rect().end.y,"page sits below tabs")
	print("COMPACT_HUD checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
