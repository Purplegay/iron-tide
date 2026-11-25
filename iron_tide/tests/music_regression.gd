extends Node
const SOVIET_TRIUMPH := preload("res://assets/music/soviet-combat-1-triumphal.mp3")
var checks: Array = []
var failed := 0
var capture := AudioEffectCapture.new()
var master_capture := AudioEffectCapture.new()
var output := ""

func check(ok: bool, label: String, detail = null) -> void:
	checks.append({"name": label, "passed": ok, "detail": detail})
	if not ok:
		failed += 1
		print("FAIL ", label, " ", detail)

func peak(effect: AudioEffectCapture = null, require_frames: bool = true) -> float:
	if effect == null:
		effect = capture
	effect.clear_buffer()
	await get_tree().create_timer(0.4, true, false, true).timeout
	var frames := effect.get_buffer(effect.get_frames_available())
	if require_frames:
		check(not frames.is_empty(), "real mixer supplied frames", frames.size())
	var amplitude := 0.0
	for frame in frames:
		amplitude = maxf(amplitude, maxf(absf(frame.x), absf(frame.y)))
	return amplitude

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Music.set_enabled(true)
	Music.set_volume(.28)
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(bus, capture)
	AudioServer.add_bus_effect(0, master_capture)
	check(not Music.player.playing, "autoload stays quiet until a real screen enters context")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))
	check(manifest.tracks.size() == 27, "manifest includes faction combat, superweapon and Yuriko recordings")
	for track in manifest.tracks:
		var audio := load(str(track.file)) as AudioStreamMP3
		check(audio != null and audio.get_length()>1,"original recording decodes: "+str(track.title))
	Music.stop()
	Music.current_index = -1
	Music.player.stream = null
	Music.set_context("menu")
	Music.next_track()
	check(not Music.player.playing and Music.target_gain() == 0.0, "menu stays silent even when replay is called")
	# A stopped, unused bus may sleep entirely; playback checks still require PCM frames.
	check(await peak(null, false) < 0.0001, "menu has no BGM mixer output")
	await exercise_segments()
	Music.set_context("battle")
	await get_tree().create_timer(1.0).timeout
	check(Music.player.playing and Music.player.stream.get_length() > 30.0, "real MP3 decodes and starts", Music.player.stream.get_length())
	check(await peak() > 0.001, "music reaches actual Music mixer bus")
	var player_id := Music.player.get_instance_id()
	var at: float = Music.player.get_playback_position()
	Music.set_context("battle")
	check(Music.player.get_playback_position() >= at - 0.1 and Music.player.get_instance_id() == player_id, "reentering battle context does not duplicate or restart music")
	Music.set_volume(0.5)
	Music.set_context("battle")
	await get_tree().create_timer(1.0).timeout
	check(is_equal_approx(Music.target_gain(), 0.4), "battle gain leaves space for effects")
	var full_gain: float = Music.target_gain()
	Ra2Sfx.play_voice(GameData.get_unit("E1"), "select", Vector2.INF, 0)
	check(Ra2Sfx.unit_voice_active() and Music.target_gain() < full_gain * 0.5, "actual unit response ducks music")
	Ra2Sfx.stop_all()
	Ra2Sfx.play("GrizzlyTankAttack")
	check(not Ra2Sfx.unit_voice_active() and is_equal_approx(Music.target_gain(), full_gain), "weapon playback does not inherit voice ducking")
	Ra2Sfx.stop_all()
	Ra2Sfx.play_eva("EVA_Building", "allied", 0)
	check(Music.target_gain() < full_gain * 0.5, "actual EVA announcement ducks music")
	Ra2Sfx.stop_all()
	check(is_equal_approx(Music.target_gain(), full_gain), "music recovers after speech ends")
	get_tree().paused = true
	at = Music.player.get_playback_position()
	check(Music.target_gain() < full_gain, "pause lowers background level")
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(Music.player.get_playback_position() > at, "music continues while battle tree paused")
	get_tree().paused = false
	Engine.time_scale = 4.0
	at = Music.player.get_playback_position()
	await get_tree().create_timer(0.5, true, false, true).timeout
	var advance: float = Music.player.get_playback_position() - at
	check(advance > 0.2 and advance < 1.0 and Music.player.pitch_scale == 1.0, "battle speed does not accelerate music", advance)
	Engine.time_scale = 1.0
	Music.set_volume(0.0)
	await get_tree().create_timer(0.2).timeout
	check(await peak() < 0.0001, "zero music volume produces silent music mixer")
	Ra2Sfx.play("GrizzlyTankAttack")
	check(await peak(master_capture) > 0.001, "zero music volume leaves effects audible")
	Ra2Sfx.stop_all()
	Music.set_enabled(false)
	check(not Music.player.playing and not AudioServer.is_bus_mute(0), "music toggle stops only music")
	Music.set_context("menu")
	check(not Music.player.playing, "scene transition respects disabled preference")
	Music.set_volume(0.37)
	Music.enabled = true
	Music.volume = 0.9
	Music.load_settings()
	check(not Music.enabled and is_equal_approx(Music.volume, 0.37), "enabled and volume persist in isolated settings file")
	Music.set_enabled(true)
	check(not Music.player.playing, "reenabling in menu only changes preference")
	Music.set_context("battle")
	check(Music.player.playing, "reenable resumes active context")
	var previous_index: int = Music.current_index
	Music.player.seek(Music.player.stream.get_length() - 0.15)
	await get_tree().create_timer(0.7).timeout
	check(Music.player.playing and Music.current_index == previous_index and Music.player.get_playback_position() < 2.0, "real finished signal loops the single track")
	var controls = preload("res://scripts/ui/music_controls.gd").new()
	add_child(controls)
	check(controls.title.text == Music.current_title() and controls.next_button.text == "重播", "shared UI accurately labels single-track playback")
	controls.slider.value = 18.0
	check(is_equal_approx(Music.volume, 0.18) and controls.percent.text == "18%", "actual slider updates player setting and percentage")
	controls.toggle.button_pressed = false
	check(not Music.enabled and not Music.player.playing and not controls.slider.editable, "actual UI toggle disables playback and slider")
	controls.toggle.button_pressed = true
	controls.next_button.pressed.emit()
	check(Music.player.playing and Music.player.get_playback_position() < 0.1, "replay button restarts the single track")
	controls.free()
	BattleRequest.configure_skirmish("ra2", {"map_size": 2400, "starting_funds": 8000})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	check(Music.context == "battle" and Music.player.get_instance_id() == player_id, "actual battle scene reuses the same music player")
	screen.free()
	check(Music.context == "menu" and not Music.player.playing and Music.target_gain() == 0.0, "battle teardown stops BGM")
	await exercise_soviet()
	await exercise_yuriko_tension()
	await exercise_campaign_timing()
	Music.set_enabled(false)
	var menu = load("res://scenes/main.tscn").instantiate()
	add_child(menu)
	check(not Music.player.playing, "actual main menu does not override mute")
	menu.free()
	Music.stop()
	Ra2Sfx.stop_all()
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "audio_device": AudioServer.get_output_device(), "tested_tracks": Music.tracks}, "  "))
	file.close()
	print("MUSIC checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func exercise_yuriko_tension() -> void:
	var director := preload("res://scripts/world/battle_music_director.gd")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"country":"美国", "map_size":2400})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	var hero = world.spawn_unit("YURIKO", "ally", Vector2(600,600))
	var scout = world.spawn_unit("E1", "ally", Vector2(650,600))
	var opponent = world.spawn_unit("E2", "enemy", Vector2(800,600))
	world.reveal_attack(hero, opponent)
	var combat_track := Music.combat_id
	world.spawn_unit("E2", "enemy", opponent.position)._die(scout)
	world.spawn_unit("E1", "ally", scout.position)._die(hero)
	for i in 9:
		world.spawn_unit("E2", "enemy", opponent.position)._die(hero)
	director.tick(world, 21.0)
	check(director.state(world).yuriko_kills == 9 and Music.stage == "battle", "only Yuriko's personal enemy unit kills count; nine keep the faction track")
	check(BattleSaves.save_slot(world, "slot1").ok, "save partial kill count before unlock")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok, "stage nine-kill save")
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	world = screen.battle
	world.paused = false
	get_tree().paused = false
	hero = preload("res://scripts/units/yuriko.gd").hero(world)
	director.superweapon_used(world, "ally")
	director.superweapon_used(world, "enemy")
	var tenth = world.spawn_unit("E2", "enemy", hero.position + Vector2(60,0))
	tenth.hp = 1
	hero._fire_shot(tenth)
	director.tick(world, 19.0)
	check(Music.stage == "superweapon_used" and director.state(world).yuriko_kills == 10, "tenth kill leaves the active superweapon recording playing")
	director.tick(world, 1.0)
	await finish_recording()
	check(Music.stage == "enemy_superweapon", "queued hostile superweapon also plays before Yuriko tension")
	await finish_recording()
	check(Music.stage == "yuriko_tension" and Music.current_title() == "YurikoTensionb", "quiet battlefield returns to James Hannigan's recording")
	var stream := Music.player.stream
	check(stream.resource_path.ends_with("/yuriko-tensionb.mp3") and await peak() > 0.001, "Yuriko tension decodes and reaches the music bus")
	Music.player.seek(stream.get_length() - 0.12)
	await get_tree().create_timer(0.7, true, false, true).timeout
	check(Music.player.playing and Music.player.stream == stream and Music.player.get_playback_position() < 2, "Yuriko tension loops on its real finished signal")
	check(BattleSaves.save_slot(world, "slot1").ok, "save quiet battlefield with ten personal kills")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok, "stage quiet battlefield save")
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	world = screen.battle
	world.paused = false
	get_tree().paused = false
	check(Music.stage == "yuriko_tension" and Music.player.stream == stream, "load resumes unlocked tension directly")
	scout = world.spawn_unit("E1", "ally", Vector2(700,600))
	opponent = world.spawn_unit("E2", "enemy", Vector2(850,600))
	world.reveal_attack(opponent, scout)
	director.tick(world, 19.0)
	check(Music.stage == "battle" and Music.combat_id == combat_track, "incoming fire resumes the original combat recording")
	world.reveal_attack(scout, opponent)
	director.tick(world, 19.0)
	check(Music.stage == "battle", "continued exchanges postpone the idle loop")
	director.tick(world, 1.0)
	check(Music.stage == "yuriko_tension", "twenty quiet simulation seconds restore the loop")
	director.trigger_uprising(world)
	check(Music.stage == "uprising", "uprising interrupts the quiet loop")
	await finish_recording()
	check(Music.stage == "yuriko_tension", "uprising finishes back into the quiet loop")
	for i in 3:
		world.spawn_unit("E1", "ally", scout.position)._die(opponent)
	director.tick(world, 1.0)
	check(Music.stage == "disadvantage", "losses override the unlocked tension track")
	director.tick(world, 21.0)
	check(Music.stage == "yuriko_tension", "expired disadvantage releases the track")
	hero = preload("res://scripts/units/yuriko.gd").hero(world)
	hero._die()
	check(Music.stage == "battle" and Music.player.stream != stream and Music.combat_id == combat_track, "Yuriko death without a killer immediately restores the combat recording")
	director.tick(world, 21.0)
	check(Music.stage == "battle" and not director.state(world).has("yuriko_kills"), "quiet time after death keeps the battlefield score")
	hero = world.spawn_unit("YURIKO", "ally", scout.position)
	Music.play_cue("yuriko")
	hero._die(opponent)
	check(Music.stage == "battle" and Music.cue.is_empty(), "death during Yuriko's arrival interrupts her theme")
	hero = world.spawn_unit("YURIKO", "ally", scout.position)
	world.yuriko_support = hero
	hero.special.psi_support_left = 1.0
	Music.play_cue("yuriko")
	var psi := preload("res://scripts/units/yuriko.gd")
	psi.tick_deployment(world, 0.5)
	check(Music.stage == "yuriko", "arrival music continues while support time remains")
	psi.tick_deployment(world, 0.5)
	check(world.yuriko_support == null and Music.stage == "battle" and Music.cue.is_empty(), "support expiry restores the battle score immediately")
	Music.finish_battle(true)
	check(Music.stage == "victory", "victory takes over the quiet loop")
	screen.free()

func exercise_segments() -> void:
	for side in ["allied", "soviet"]:
		Music.set_context("battle", side)
		var drawn := {}
		Music._music_random.seed = 1947
		for draw in 32:
			drawn[Music._choose_combat("")] = true
		check(drawn.size() == 2 and drawn.has(side + "_combat_1") and drawn.has(side + "_combat_2"), "both local recordings drawn: " + side)
		for id in drawn:
			Music.set_context("menu")
			Music.set_context("battle", side, false, "", id)
			var original := Music.player.stream
			var victory_stream := SOVIET_TRIUMPH if id == "soviet_combat_1" else original
			var victory_start := 0.0 if id == "soviet_combat_1" else 143.0
			for row in [["battle", 0., 77.], ["disadvantage", 78., 142.], ["victory", 143., 248.]]:
				Music.set_battle_stage(row[0])
				var stream := victory_stream if row[0] == "victory" else original
				var start: float = victory_start if row[0] == "victory" else row[1]
				var end: float = minf(row[2], stream.get_length())
				var pos := Music.player.get_playback_position()
				check(Music.player.stream == stream and pos >= start - 0.1 and pos < start + 1., "%s %s enters at %s" % [id, row[0], start], pos)
				Music.player.seek(end - 0.1)
				var deadline := Time.get_ticks_msec() + 4000
				while Time.get_ticks_msec() < deadline:
					await get_tree().process_frame
					pos = Music.player.get_playback_position()
					if Music.player.playing and pos >= start - 0.1 and pos < start + 1.5: break
				check(Music.player.playing and pos >= start - 0.1 and pos < start + 1.5, "%s %s loops within segment" % [id, row[0]], pos)
			Music.set_enabled(false)
			Music.set_battle_stage("disadvantage")
			Music.set_enabled(true)
			check(absf(Music.player.get_playback_position() - 78.) < 1., "muted mood change resumes the right segment")
			Music.set_battle_stage("battle")
			Music.play_cue("uprising")
			Music.set_battle_stage("disadvantage")
			check(Music.cue.is_empty() and Music.player.stream == original and absf(Music.player.get_playback_position() - 78.) < 1., "new losses take priority over uprising music")
			Music.play_cue("superweapon_used")
			check(Music.current_title() == ("American Cowboys" if side == "allied" else "The Red Menace"), "own superweapon uses player's faction recording")
			Music.play_cue("enemy_superweapon")
			Music.play_cue("enemy_superweapon")
			Music.play_cue("yuriko")
			Music.set_battle_stage("victory")
			check(Music.stage == "superweapon_used", "active superweapon recording finishes before the other cue")
			await finish_recording()
			check(Music.current_title() == ("Allied - Up Yours" if side == "allied" else "Soviet - Up Yours"), "enemy superweapon uses listener's Up Yours")
			await finish_recording()
			check(Music.player.stream == victory_stream and absf(Music.player.get_playback_position() - victory_start) < 1., "%s returns from superweapon cues to its victory music" % id)
			if id == "soviet_combat_1":
				Music.player.seek(12.)
				Music.finish_battle(true)
				check(Music.player.stream == SOVIET_TRIUMPH and absf(Music.player.get_playback_position()-12.) < 1., "winning during the Soviet triumph continues its playback")
				Music.set_context("menu")
				Music.set_context("battle", side, false, "", id)
				Music.uprising_triggered = true
				Music.finish_battle(true)
				check(Music.player.playing and Music.player.stream == SOVIET_TRIUMPH and Music.player.get_playback_position() < 1., "direct victory from Red Rock uses Combat 1 after an earlier Uprising cue")
	Music.set_context("menu")

func finish_recording() -> void:
	var previous := Music.stage
	Music.player.seek(Music.player.stream.get_length() - 0.12)
	var deadline := Time.get_ticks_msec() + 4000
	while Music.stage == previous and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func exercise_soviet() -> void:
	Music._music_random.seed = 2 # First Soviet draw selects Red Rock for this save/restore scenario.
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"伊拉克","enemy_base":"allied","map_size":2400})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	check(Music.stage=="explore","Iraqi map starts with exploration")
	var scout=screen.battle.spawn_unit("E2","ally",Vector2(320,400))
	var enemy=screen.battle.spawn_unit("E1","enemy",Vector2(390,400))
	screen.battle.reveal_attack(scout,enemy)
	var expected := Music.player.stream.resource_path
	check(Music.faction=="soviet" and expected.get_file() in ["red-rock-for-mother-russia.mp3","battleground-of-the-bear.mp3"],"Iraqi player against Allied opponent starts Soviet track")
	await get_tree().create_timer(1.0).timeout
	check(Music.player.stream.get_length()>30 and await peak()>0.001,"actual Soviet MP3 decodes into Music bus",Music.player.stream.get_length())
	Music.next_track()
	check(Music.player.stream.resource_path==expected and Music.player.playing,"Soviet replay stays within faction")
	Music.set_enabled(false)
	Music.set_enabled(true)
	check(Music.player.stream.resource_path==expected and Music.player.playing,"reenabling retains Soviet score")
	var director := preload("res://scripts/world/battle_music_director.gd")
	for i in 3:
		var soldier = screen.battle.spawn_unit("E2","ally",Vector2(680,480))
		soldier._die(enemy)
	director.tick(screen.battle, 1.0)
	check(Music.stage == "disadvantage" and absf(Music.player.get_playback_position() - 78.) < 1., "three real hostile kills start the losing segment")
	var save := BattleSaves.save_slot(screen.battle,"slot1")
	check(save.ok,"Soviet skirmish saved")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok,"Soviet save staged")
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	check(Music.player.stream.resource_path==expected and Music.player.playing and Music.stage=="disadvantage","loaded Soviet battle keeps song and mood")
	screen.battle.paused = false
	get_tree().paused = false
	director.tick(screen.battle, 21.)
	check(Music.stage == "battle", "expired losses return to even combat")
	scout=screen.battle.spawn_unit("E2","ally",Vector2(750,480))
	for i in 5:
		var plant=screen.battle._place_building("GAPOWR","enemy",Vector2(1400+i*100,1400),true)
		plant._die(scout)
	director.tick(screen.battle, 20.)
	check(expected.ends_with("/red-rock-for-mother-russia.mp3") and Music.stage=="victory" and Music.player.stream==SOVIET_TRIUMPH and Music.player.get_playback_position()<1., "five enemy plants transition Red Rock into Soviet Combat 1 - Triumphal")
	check(BattleSaves.save_slot(screen.battle,"slot1").ok,"save Red Rock during battlefield advantage")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok,"stage Red Rock advantage save")
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	check(Music.combat_id=="soviet_combat_1" and Music.stage=="victory" and Music.player.playing and Music.player.stream==SOVIET_TRIUMPH, "restore Red Rock advantage directly into Soviet Combat 1 - Triumphal")
	screen.battle.paused = false
	get_tree().paused = false
	director.tick(screen.battle, 121.)
	enemy = screen.battle.spawn_unit("E1","enemy",Vector2(900,720))
	for i in 5:
		var plant=screen.battle._place_building("NAPOWR","ally",Vector2(700+i*100,950),true)
		plant._die(enemy)
	director.tick(screen.battle, 1.)
	check(Music.stage=="disadvantage" and Music.player.stream.resource_path==expected, "losing five key buildings selects the middle segment")
	await exercise_launchers(screen.battle)
	screen.free()
	get_tree().paused=false

func exercise_launchers(world) -> void:
	var point := Vector2(1100, 1170)
	var tank = world.spawn_unit("MTNK", "ally", point)
	for row in [["NAIRON", "ally", "The Red Menace"], ["GACSPH", "ally", "The Red Menace"], ["GAWEAT", "enemy", "Soviet - Up Yours"]]:
		var site = world._place_building(row[0], row[1], Vector2(1250, 800), true)
		site._buildup_play = -1.
		site._sw_charge = site.sw_recharge()
		world.power_low = false
		world.enemy_power.low = false
		var target: Vector2 = point if row[0] == "NAIRON" else point + Vector2(220, 260)
		check(site.fire_superweapon(target, tank.position) and Music.current_title() == row[2], "successful %s launch selects %s" % [row[0],row[2]])
		if Music.cue in Music.SUPERWEAPON_CUES: await finish_recording()
		check(Music.stage == "disadvantage", "one-shot returns to losing combat after " + row[0])
	var teams: Dictionary = BattleRequest.house_teams
	BattleRequest.house_teams = {"ally":1, "ai2":1}
	preload("res://scripts/world/battle_music_director.gd").superweapon_used(world, "ai2")
	BattleRequest.house_teams = teams
	check(Music.stage == "disadvantage", "allied AI launches leave the local score alone")

func exercise_campaign_timing() -> void:
	BattleRequest.configure_mission("m01", {})
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	check(not screen.battle.prepared and Music.stage == "explore" and Music.player.playing, "campaign preparation plays exploration music")
	var saved: Dictionary = BattleSaves.save_slot(screen.battle, "slot1")
	check(saved.ok, "preparation snapshot saves")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok, "preparation snapshot stages")
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	check(not screen.battle.prepared and Music.stage=="explore" and Music.player.playing, "restored preparation plays exploration")
	screen.hud._toggle_pause()
	check(not screen.battle.paused, "real resume control leaves load-time pause")
	screen.battle.wave_timer = 0.01
	screen.battle._update_waves(0.02)
	check(screen.battle.prepared and Music.context == "battle" and Music.player.playing and Music.faction=="allied" and Music.stage=="explore", "spawning a wave keeps exploration until contact")
	var at: float = Music.player.get_playback_position()
	screen.battle._spawn_wave(0)
	check(Music.player.get_playback_position() >= at - 0.1, "later waves do not restart song")
	check(BattleSaves.save_slot(screen.battle, "slot1").ok, "ongoing campaign snapshot saves")
	screen.free()
	check(BattleSaves.prepare_load("slot1").ok, "ongoing campaign snapshot stages")
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false
	check(screen.battle.prepared and Music.player.playing, "ongoing campaign load starts BGM")
	screen._on_battle_ended({"win": false})
	check(Music.context == "results" and not Music.player.playing and Music.target_gain() == 0.0, "actual results screen stops BGM")
	Music.next_track()
	check(not Music.player.playing, "replay cannot start music on results screen")
	screen.free()
