extends "res://tests/base_recovery_regression.gd"
var defeat_messages: Array = []
var delivered: Array = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	Events.battle_message.connect(record_message)
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await exercise(mode)
	await duel()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)

func record_message(message: String, color: Color) -> void:
	if message.contains("已被击败"): defeat_messages.append({"text":message,"color":color})

func record_notice(side: String, message: String, color: Color) -> void:
	delivered.append({"side":side,"text":message,"color":color,"ended":battle.ended})

func remove_assets(side: String) -> void:
	for actor in battle.units + battle.buildings:
		if is_instance_valid(actor) and actor.side == side: actor.hp = 0

func open_scene() -> void:
	screen = load("res://scenes/battle.tscn").instantiate(); add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED; battle = screen.battle
	battle.paused = false; battle.ended = false; get_tree().paused = false
	battle.computer_defeated.connect(record_notice)
	defeat_messages.clear(); delivered.clear()
	Ra2Sfx.stop_all()

func defeat_voice_count() -> int:
	return Ra2Sfx.a_eva_plays + Ra2Sfx.a_eva_queued

func check_defeat_voice(label: String) -> void:
	var id := GameData.ra2_eva_sound_id("EVA_PlayerDefeated", battle.roster_faction())
	var file: String = GameData.ra2_eva_file(id).get("file", "")
	var stream := Ra2Sfx._stream_eva(file)
	check(stream != null and stream.get_length() > 0 and not stream.data.is_empty(), label + " real defeat sample decodes")
	check(Ra2Sfx._eva_player.stream == stream and Ra2Sfx._eva_player.playing, label + " plays player's faction advisor")

func exercise(mode: String) -> void:
	var rows := [
		{"country":"美国" if mode == MatchRules.RA2 else "苏俄","team":1,"seat":0,"color":"allied"},
		{"country":"美国","team":2,"seat":1,"color":"indigo"},
		{"country":"苏俄","team":1,"seat":3,"color":"teal"},
		{"country":"德国","team":2,"seat":2,"color":"magenta"},
		{"country":"美国","team":2,"seat":4,"color":"brown"},
		{"country":"苏俄","team":2,"seat":5,"color":"orange"}]
	BattleRequest.configure_skirmish(mode, {"map_layout":"yr_isleland","opening":"prebuilt","houses":rows,"fog_of_war":false})
	open_scene()
	check(BattleRequest.house_teams.size() == 6, mode + " six-house fixture accepted")
	var notices = screen.hud._defeat_notices
	check(not notices.visible and not screen.hud.log_panel.visible, mode + " log and notices start closed")
	var voices := defeat_voice_count()
	remove_assets("enemy"); battle._check_end()
	check(defeat_voice_count() == voices + 1, mode + " newly defeated enemy announces once")
	check_defeat_voice(mode)
	check(battle.house_defeated("enemy") and not battle.ended, mode + " single computer loses without ending six-house match")
	check(delivered.size() == 1 and defeat_messages.size() == 1, mode + " defeat emits exactly one notification and log message")
	if notices.notices.has("enemy"):
		var row: Dictionary = notices.notices.enemy
		check(row.label.text == "敌方指挥官里德 · 电脑 1（美国）已被击败", mode + " notification identifies enemy commander, seat and country")
		check(row.color.color.is_equal_approx(Color(HouseColor.hex_of("indigo"))), mode + " chip uses chosen AI color")
		check(row.node.mouse_filter == Control.MOUSE_FILTER_IGNORE and row.label.mouse_filter == Control.MOUSE_FILTER_IGNORE and row.color.mouse_filter == Control.MOUSE_FILTER_IGNORE, mode + " notice never intercepts battlefield input")
	else: check(false, mode + " missing real notice row")
	check(notices.is_visible_in_tree() and not screen.hud.log_panel.visible, mode + " defeat visible while intelligence log remains collapsed")
	check(screen.hud._logs.any(func(entry): return entry.node.text.contains("电脑 1（美国）已被击败")), mode + " defeat also enters existing battle log")
	battle._check_end(); battle._check_end()
	check(defeat_voice_count() == voices + 1, mode + " repeated elimination checks do not repeat voice")
	check(delivered.size() == 1 and notices.notices.size() == 1, mode + " repeated defeat checks do not spam")
	remove_assets("ai2"); remove_assets("ai4"); battle._check_end()
	check(delivered.size() == 3 and notices.notices.size() == 3 and not battle.ended, mode + " simultaneous allied and enemy defeats each retained")
	if notices.notices.has("ai2"):
		check(notices.notices.ai2.label.text == "盟友指挥官奥尔洛夫 · 电脑 3（苏俄）已被击败", mode + " ally uses lobby seat instead of internal index")
		check(notices.notices.ai2.color.color == Color(HouseColor.hex_of("teal")), mode + " ally notice uses actual palette color")
	get_window().size = Vector2i(1280,720)
	for i in 4: await get_tree().process_frame
	check(get_viewport().get_visible_rect().encloses(notices.get_global_rect()), mode + " three simultaneous notices fit at 1280x720")
	var deadline: int = notices.notices.enemy.until
	GM.fast_forward = 3
	notices.refresh(deadline - 1)
	check(notices.notices.has("enemy"), mode + " notice remains until real-time deadline at 3x")
	notices.refresh(deadline + 11000)
	check(not notices.visible and notices.notices.is_empty(), mode + " expired notices clear independently of collapsed log")
	GM.fast_forward = 1
	battle._check_end()
	check(delivered.size() == 3 and not notices.visible, mode + " expired defeat is not reannounced")
	check(BattleSaves.save_slot(battle, "slot1").ok, mode + " eliminated-house battle saves")
	await finish()
	check(BattleSaves.prepare_load("slot1").ok, mode + " eliminated-house save loads")
	open_scene(); notices = screen.hud._defeat_notices
	voices = defeat_voice_count()
	battle._check_end()
	check(defeat_voice_count() == voices, mode + " load does not replay defeated-house audio")
	check(battle.house_defeated("enemy") and delivered.is_empty() and defeat_messages.is_empty() and not notices.visible, mode + " loading does not replay old defeats")
	remove_assets("ai3"); battle._check_end()
	check(defeat_voice_count() == voices + 1, mode + " fresh enemy defeat after load still announces")
	check(delivered.size() == 1 and delivered[0].text == "敌方指挥官莫罗 · 电脑 2（德国）已被击败", mode + " fresh defeat after reload still announces correct house")
	await finish()

func duel() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"map_size":2400,"enemy_country":"苏俄","fog_of_war":false})
	open_scene()
	var voices := defeat_voice_count()
	remove_assets("enemy"); battle._check_end()
	check(defeat_voice_count() == voices + 1, "last enemy announces alongside victory")
	check_defeat_voice("last enemy")
	check(battle.ended and delivered.size() == 1 and not delivered[0].ended, "last computer announces before result screen")
	check(delivered[0].text == "敌方指挥官罗曼诺娃 · 电脑 1（苏俄）已被击败" and screen.hud._defeat_notices.visible, "legacy duel has named defeat notice alongside victory")
	await finish()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"map_layout":"yr_isleland","opening":"prebuilt","houses":[
		{"country":"美国","team":1},{"country":"美国","team":2},{"country":"苏俄","team":1},
		{"country":"德国","team":2},{"country":"美国","team":2}],"fog_of_war":false})
	open_scene()
	voices = defeat_voice_count()
	remove_assets("ai2"); battle._check_end()
	check(defeat_voice_count() == voices and delivered.size() == 1, "allied AI defeat keeps its notice without an enemy-defeat announcement")
	remove_assets("enemy"); remove_assets("ai3"); battle._check_end()
	check(defeat_voice_count() == voices + 1 and delivered.size() == 3, "simultaneous enemy defeats retain separate notices and one shared voice")
	await finish()
