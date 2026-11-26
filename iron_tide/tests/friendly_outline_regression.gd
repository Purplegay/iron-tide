extends "res://tests/attack_outline_regression.gd"

func exercise_mode(mode: String) -> void:
	await super.exercise_mode(mode)
	setup_logistics_scene(mode,"美国")
	if battle.fog != null: battle.fog.free(); battle.fog=null
	BattleRequest.house_teams={"ally":1,"ai2":1,"enemy":2,"ai3":2}
	battle.camera.position=Vector2(1700,1600)
	battle.camera.zoom=Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	var own=actor("MTNK","ally",Vector2(1550,1650))
	var friend=actor("HTNK","ai2",Vector2(1700,1600))
	var enemy=actor("E1","enemy",Vector2(1850,1600))
	var neutral=actor("E1","neutral",Vector2(1850,1750))
	var building=battle._place_building("GAPOWR","ai2",Vector2(1650,1850),true)
	building._buildup_play=-1
	var own_building=battle._place_building("GAPOWR","ally",Vector2(1450,1750),true)
	own_building._buildup_play=-1
	own.set_selected(true)
	for missile_id in ["V3ROCKET", "DMISL", "CMISL"]:
		var missile = actor(missile_id, "ally", Vector2(1600, 1600))
		missile.set_meta(Outline.FRIEND_META, true)
		missile.set_meta(Outline.ATTACK_META, true)
		missile.selected = true
		Outline.begin(missile)
		check(missile.get_node_or_null("SelectionOutline") == null, mode + ": no outline for " + missile_id)
	var tracker=battle.attack_target_outlines
	tracker.refresh(battle)
	check(friend.has_meta(Outline.FRIEND_META) and building.has_meta(Outline.FRIEND_META),mode+": allied AI units and buildings receive white outline")
	check(own.has_meta(Outline.FRIEND_META) and own_building.has_meta(Outline.FRIEND_META),mode+": player units and buildings receive persistent outline")
	check(not enemy.has_meta(Outline.FRIEND_META) and not neutral.has_meta(Outline.FRIEND_META),mode+": hostile and neutral units do not receive white outline")
	await get_tree().process_frame; await get_tree().process_frame
	var root=friend.get_node_or_null("SelectionOutline")
	check(root!=null and root.visible and root.used==2,mode+": actual friendly tank captures hull and turret")
	if root==null:
		screen.free(); await get_tree().process_frame; return
	check(root.color==Color.WHITE and root.get_child(0).material.get_shader_parameter("outline_color")==Color.WHITE,mode+": actual friendly shader is white")
	var structure=building.get_node_or_null("SelectionOutline")
	check(structure!=null and structure.visible and structure.used>0 and structure.color==Color.WHITE,mode+": actual allied building art is white")
	check(own.get_node("SelectionOutline").color==Outline.OWN_COLOR and own.get_node("SelectionOutline").get_child(0).material.get_shader_parameter("outline_color")==Outline.OWN_COLOR,mode+": selected player unit uses yellow silhouette and shader")
	var own_structure=own_building.get_node_or_null("SelectionOutline")
	check(own_structure!=null and own_structure.visible and own_structure.used>0 and own_structure.color==Outline.OWN_COLOR,mode+": actual player building art has yellow outline")
	own.set_selected(false)
	await get_tree().process_frame; await get_tree().process_frame
	check(own.get_node("SelectionOutline").visible and own.get_node("SelectionOutline").color==Outline.OWN_COLOR,mode+": unselected player unit retains yellow outline")
	own.set_selected(true)
	for zoom in [0.5,1.0,2.0,4.0]:
		battle.camera.zoom=Iso.cam_zoom(zoom); battle.camera.force_update_scroll(); tracker.refresh(battle)
		Outline.begin(friend)
		var transform:Transform2D=friend.get_global_transform_with_canvas()*root.transform
		check(is_equal_approx(root.width*transform.x.length(),Outline.SCREEN_WIDTH),mode+": white outline keeps screen width at zoom "+str(zoom))
	battle.camera.zoom=Iso.cam_zoom(2.0); battle.camera.force_update_scroll()
	# A deliberate attack order on a friend retains the more urgent red cue.
	own.attack_target=friend; tracker.refresh(battle)
	friend.queue_redraw()
	await get_tree().process_frame; await get_tree().process_frame
	check(root.color==Outline.ATTACK_COLOR,mode+": attack outline takes precedence over friendly white")
	own.order_stop(); tracker.refresh(battle)
	await get_tree().process_frame; await get_tree().process_frame
	check(root.visible and root.color==Color.WHITE,mode+": stopping attack restores friendly white")
	friend.hide(); Outline.begin(friend)
	check(not root.visible,mode+": hidden friend cannot leave a floating outline")
	friend.show(); friend.set_stowed(own); tracker.refresh(battle)
	check(not friend.has_meta(Outline.FRIEND_META) and not root.visible,mode+": embarked friend has no outline")
	friend.set_stowed(null); tracker.refresh(battle)
	await get_tree().process_frame; await get_tree().process_frame
	check(root.visible and root.color==Color.WHITE,mode+": unloading restores friendly outline")
	AlliedAbilities.change_side(friend,"enemy"); tracker.refresh(battle)
	check(not friend.has_meta(Outline.FRIEND_META) and not root.visible,mode+": hostile capture clears white outline immediately")
	AlliedAbilities.change_side(friend,"ai2"); tracker.refresh(battle)
	own.order_target(enemy,false,false); tracker.refresh(battle)
	await get_tree().process_frame; await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode+"-friendly-white.png"))
	friend._die(null,true); tracker.refresh(battle)
	check(not root.visible and not tracker.friendly_marked.has(friend),mode+": friendly death clears white outline")
	battle.ended=true; tracker.refresh(battle)
	check(tracker.friendly_marked.is_empty() and not building.has_meta(Outline.FRIEND_META),mode+": match end clears friendly indicators")
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	await get_tree().process_frame
