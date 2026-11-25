extends Node
var checks := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", message)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for country in ["美国", "苏俄"]:
		BattleRequest.configure_skirmish(MatchRules.RA2, {"country":country,"map_size":3200,"starting_funds":7600})
		var screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.battle.set_process(false)
		screen.battle.set_physics_process(false)
		for i in 6: await get_tree().process_frame
		var hud = screen.hud
		var soviet: bool = country == "苏俄"
		check((screen.battle.roster_faction("ally") == "soviet") == soviet, country+" actual faction")
		var cap: StyleBoxTexture = hud._deck_cap.get_theme_stylebox("normal")
		for id in ["repair", "sell"]:
			check(hud._deck_cap.get_global_rect().encloses(hud.building_action_buttons[id].get_global_rect()),country+" header contains "+id)
		check(hud.deck_title.global_position.y >= hud._deck_cap.get_global_rect().end.y,country+" title below header")
		check(hud.deck_title.get_global_rect().end.x <= hud.building_action_buttons.repair_all.global_position.x,country+" title clears repair all")
		hud.select_prod_tab("infantry")
		var expected_path := "res://assets/ra2/ui/soviet/top-0.png" if soviet else "res://assets/ra2/ui/top-0.png"
		check(cap != null and cap.texture.resource_path == expected_path, country+" header uses original faction art")
		check(hud._faction_accent() == (Ra3Skin.RED if soviet else UiKit.RA_CYAN), country+" accent")
		var late := UiKit.make_button("动态按钮")
		hud.prod_box.add_child(late)
		for i in 5: await get_tree().process_frame
		var sb: StyleBoxTexture = late.get_theme_stylebox("normal")
		var expected_accent: Color = Ra3Skin.RED if soviet else Color(0.28,0.42,0.6)
		check(sb.texture == Ra3Skin.tile(expected_accent,"normal").texture, country+" dynamic blue button follows faction")
		check(hud.prod_panel.get_global_rect().encloses(hud.deck_title.get_global_rect()), country+" header fits")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("soviet.png" if soviet else "allied.png"))
		screen.free()
		await get_tree().process_frame
	print("FACTION_SKIN checks=",checks," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
