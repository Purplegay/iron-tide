extends "res://tests/leizhu_art_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var hero=setup_hero()
	BattleRequest.combat_context.unit_talents.TTNK={"ground_capacitor":3}
	var talents=preload("res://scripts/units/expansion_talents.gd")
	var state:Dictionary=preload("res://scripts/units/expansion_rules.gd").state(hero)
	state.shot_idle=3.0;talents.tick(hero,2.1)
	hero.position+=Vector2(65,0);talents.tick(hero,.1)
	var token=hero.get_meta(preload("res://scripts/units/ground_capacitor_token.gd").META).get_ref()
	hero.special.leizhu.shield={"hp":20.0,"left":10.0}
	battle.camera.position=Vector2(1100,1000);battle.camera.reset_smoothing();Iso.apply_to(battle.camera,2);battle.camera.force_update_scroll()
	battle.select_unit(hero,false);battle._emit_selection()
	if not screen.hud.unit_menu_collapsed:screen.hud._toggle_unit_menu()
	refresh_pose(hero);await rendered();await rendered()
	check(token.is_visible_in_tree() and token.global_position==Vector2(1000,1000),"GPU renders independent capacitor token at the drop point")
	check(token.seconds==7,"token shows actual remaining lifetime rounded up")
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("token-before.png"))
	hero.position+=Vector2(170,0);talents.tick(hero,.1)
	refresh_pose(hero);await rendered();await rendered()
	check(token.global_position==Vector2(1000,1000) and token.global_position.distance_to(hero.global_position)>200,"capacitor remains fixed while hero moves")
	check(hero.shield_readout_amount()==20 and screen.hud.sel_shield_label.visible,"separate live shield retains its numerical readout")
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("token-after.png"))
	talents.tick(hero,8);await rendered();await rendered()
	check(not is_instance_valid(token),"expired token is removed from the rendered scene")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func refresh_pose(hero) -> void:
	hero.motion_pose.capture(hero);hero.reset_physics_interpolation();hero.queue_redraw()
	battle.hp_overlay.queue_redraw()
