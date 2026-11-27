extends Node

func _ready() -> void:
	call_deferred("run")

func click(root: Node, label: String) -> bool:
	for item in root.find_children("*","Button",true,false):
		if item.text==label and not item.disabled:
			item.pressed.emit()
			return true
	return false

func run() -> void:
	var tree := get_tree()
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else "yr_allied_first"
	var skip := "--skip" in args
	var track_radio := "--track-radio" in args
	var natural_full := "--natural-full" in args
	var hide_radar := "--hide-radar" in args
	var force_stall := "--stall-ended-signal" in args
	var title := ""
	for item in GameData.missions:
		if item.id==id: title=item.name; break
	tree.current_scene=null
	var menu = load("res://scenes/campaign_command.tscn").instantiate()
	tree.root.add_child(menu)
	if title.is_empty() or not click(menu,"盟军战役" if id in ["yr_allied_first","yr_allied_finale","yr_hollywood"] else "苏军战役") or not click(menu,title) or menu.mission.id!=id or not click(menu,"原版配置") or not click(menu,"出击"):
		printerr("OPEN menu failed: ",id," ",title)
		tree.quit(1)
		return
	await tree.scene_changed
	var world = tree.current_scene.battle
	for child in tree.current_scene.get_children():
		var script: Script = child.get_script()
		if script!=null and script.resource_path=="res://scripts/save/battle_autosave.gd": child.set_process(false)
	if hide_radar: world.hud.minimap.hide()
	var start := Time.get_ticks_msec()
	var last_film: Node
	var last := ""
	var checked := 0
	var was_usable := false
	var audio_end := 0
	var command_sent := false
	var layout_ok := true
	var empty_since := -1
	var longest_empty := 0
	var budget_ms := 145000 if natural_full else 48000
	while true:
		var film = world.get_node_or_null("HollywoodFilm")
		var usable: bool = world.world_input_enabled()
		var locked := not usable
		var clip: String = film.clip_id if is_instance_valid(film) and not film.is_queued_for_deletion() else "-"
		var status := "%s usable=%s tree_pause=%s" % [clip,usable,tree.paused]
		var ms := Time.get_ticks_msec()-start
		if locked and clip=="-":
			if empty_since<0: empty_since=ms
			longest_empty=maxi(longest_empty,ms-empty_since)
		else:
			if empty_since>=0: longest_empty=maxi(longest_empty,ms-empty_since)
			empty_since=-1
		if status!=last:
			print("OPEN ",id," ",ms," ",status," media=",film._playback_seconds() if clip!="-" else -1.0)
			last=status
		if clip!="-" and film!=last_film:
			last_film=film
			checked+=1
			print("OPEN clip assets: ",clip," skip_visible=",film.skip.is_visible_in_tree()," box=",film.skip.get_global_rect()," audio=",film.mission_audio.stream.get_length() if film.mission_audio!=null else 0.0)
			layout_ok = layout_ok and film.skip.is_visible_in_tree() and film.skip.get_parent()==film and film.opening_radio_deadline_ms>0
			if clip.contains("_F") and not natural_full or skip:
				film.skip.pressed.emit()
			elif force_stall:
				film.player.stop()
				if film.mission_audio!=null: film.mission_audio.stop()
				film.opening_radio_deadline_ms=Time.get_ticks_msec()+700
		if not locked and clip=="-" and not was_usable:
			var actors: Array = world.units.filter(func(u): return world.actor_alive(u) and u.side=="ally" and not u.is_air and u.embarked_in==null)
			if not actors.is_empty():
				was_usable=true
				audio_end=ms+3500
				var u = actors[0]
				world.select_unit(u,false)
				world._issue_order(u.position+Vector2(30,12))
				command_sent=u.has_move_order
				print("OPEN first move ",ms," unit=",u.unit_id," accepted=",command_sent," title=",world.hud.wave_label.text)
		if was_usable and (not track_radio or ms>=audio_end): break
		if ms>budget_ms or world.ended: break
		await tree.create_timer(0.25,true,false,true).timeout
	var expected_clips := 1 if id=="yr_time_shift" else (3 if id=="yr_hollywood" else 2)
	# Brain Dead still waits for physical flight and landing even when the film is skipped.
	var gap_limit := 28000 if id=="yr_allied_finale" else (16000 if id=="yr_hollywood" else (9000 if id in ["yr_allied_first","yr_head_games"] else 5000))
	print("OPEN result ",id," usable=",was_usable," clips=",checked," command=",command_sent," skip_layout=",layout_ok," longest_no_media_ms=",longest_empty," limit_ms=",gap_limit)
	tree.quit(0 if was_usable and checked==expected_clips and command_sent and layout_ok and longest_empty<=gap_limit else 1)
