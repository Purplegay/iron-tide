extends "res://tests/high_bridge_regression.gd"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var saved:=OS.get_environment("IRON_BRIDGE_SAVE")
	var original_hash:=FileAccess.get_sha256(saved) if not saved.is_empty() else ""
	if not saved.is_empty():
		DirAccess.make_dir_recursive_absolute("user://battles")
		check(DirAccess.copy_absolute(saved,ProjectSettings.globalize_path("user://battles/quick.itsave"))==OK,"copy player save into isolated profile without modifying original")
		var result:Dictionary=BattleSaves.prepare_load("quick")
		check(result.ok,"real quick save passes normal load validation",result)
		if not result.ok:
			write_result();get_tree().quit(1);return
	else:BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_layout":"yr_unrepent","opening":"mcv","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle;screen.hud.hide()
	await rendered()
	check(battle.map_layout()=="yr_unrepent","target save/scene is Unrepentant")
	# Reveal for inspection only in this disposable runtime.
	if battle.fog!=null:battle.fog.hide()
	for child in battle.get_children():
		if child is Ground:
			check(child._surface.texture.resource_path.ends_with("yr_unrepent_terrain.png"),"real scene uses repaired terrain resource")
	for i in 2:
		var center:=Vector2(119.5,73) if i==0 else Vector2(43.5,97)
		battle.camera.position=center*55;battle.camera.reset_smoothing();Iso.apply_to(battle.camera,.85);battle.camera.force_update_scroll()
		battle.hp_overlay.queue_redraw();battle.queue_redraw()
		await rendered();await rendered()
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("bridge-%d.png"%i))
	var current:Rect2=Native.data("yr_unrepent").bridge_decks[0]
	var parts:Array=Bridges.sections(battle,current)
	var middle:Rect2=parts[parts.size()/2]
	battle.camera.position=middle.get_center();battle.camera.reset_smoothing();Iso.apply_to(battle.camera,1.5);battle.camera.force_update_scroll()
	Bridges.damage_section(battle,middle,Bridges.strength())
	await rendered();await rendered()
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("broken.png"))
	check(battle.path_service.is_blocked(middle.get_center()),"rendered break also blocks actual land movement")
	var hut=battle.buildings.filter(func(b):return b.special.get("bridge_span")==current)[0]
	preload("res://scripts/world/civilian_sites.gd").repair(hut)
	await rendered();await rendered()
	get_viewport().get_texture().get_image().save_png(output_dir.path_join("repaired.png"))
	check(not battle.path_service.is_blocked(middle.get_center()),"rendered repair reopens actual road")
	if not saved.is_empty():check(FileAccess.get_sha256(saved)==original_hash,"player quick save bytes unchanged after normal load and runtime inspection")
	write_result()
	get_tree().quit(0 if failed==0 else 1)

func write_result() -> void:
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))

func rendered() -> void:
	await get_tree().process_frame;await RenderingServer.frame_post_draw
