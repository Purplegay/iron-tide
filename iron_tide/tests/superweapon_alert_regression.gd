extends "res://tests/special_mechanics_regression.gd"

const SOURCES := ["NAMISL", "NAIRON", "GACSPH", "GAWEAT", "NARADR", "GAAIRC", "GATECH"]
var pings: Array[Vector2] = []
var notices: Array[String] = []

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	Events.radar_ping.connect(func(at, kind): if kind == "alert": pings.append(at))
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		arena(mode)
		battle._countries.enemy = "Americans"
		var hud = battle.hud
		var panel = hud._enemy_alerts
		battle.enemy_superweapon_launched.connect(func(label): notices.append(label))
		var launchers := []
		var landing := Vector2(1100, 1400)
		var tank = spawn("MTNK", "enemy", AIM)
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog); battle.fog.setup(battle)
		for i in SOURCES.size():
			var point := Vector2(300 + i * 160, 500)
			var id: String = SOURCES[i]
			Ra2Sfx.stop_eva()
			Ra2Sfx._eva_last.clear()
			pings.clear()
			battle.enemy_struct_ready[id] = 1
			var site = battle.deliver_ready_structure(id, "enemy", point)
			check(is_instance_valid(site), prefix + "AI places " + id)
			if not is_instance_valid(site):continue
			launchers.append(site)
			site._buildup_play = -1.0
			if id in ["NARADR","GAAIRC","GATECH"]:
				check(not Ra2Sfx._eva_last.has("EVA_BEACONDETECTED") and pings.is_empty(), prefix+id+" no support detection broadcast")
				check(not battle.fog.is_visible_at("ally", point),prefix+id+" support facility concealed on placement")
				continue
			var event: String = {"NAMISL":"EVA_NuclearSiloDetected","NAIRON":"EVA_IronCurtainDetected","GACSPH":"EVA_ChronosphereDetected","GAWEAT":"EVA_WeatherDeviceReady"}.get(id,"EVA_BeaconDetected")
			var file: Dictionary = GameData.ra2_eva_file(GameData.ra2_eva_sound_id(event, battle.roster_faction()))
			check(Ra2Sfx._eva_last.has(event.to_upper()) and Ra2Sfx._eva_player.playing and Ra2Sfx._eva_player.stream.resource_path == GameData.ra2_eva_path(file.file), prefix + id + " completion plays matching detection EVA clip")
			check(battle.fog.is_visible_at("ally", point) and site.visible and pings.count(point)==1, prefix + id + " completion reveals site and pings once")
		battle.fog._reveal("enemy",AIM,200,10)
		battle.fog._reveal("enemy",landing,200,10)
		battle.enemy_power.low = false
		panel.refresh()
		check(panel.is_visible_in_tree() and not hud.log_panel.visible and panel.timers.text.contains(":"), prefix + "charging visible on folded HUD")
		for site in launchers:
			var name_text: String = site.sw_label()
			if site.building_id in ["NARADR","GAAIRC","GATECH"]:
				check(not panel.timers.text.contains(name_text),name_text+" stays out of enemy countdowns")
				site._sw_charge=site.sw_recharge()
				pings.clear()
				var alerts_before := notices.size()
				var target_point: Vector2 = site.position if site.sw_type()=="ForceShield" else landing
				check(site.fire_superweapon(target_point,AIM),name_text+" support ability still activates")
				battle.fog.rebuild()
				check(pings.is_empty() and notices.size()==alerts_before and not panel.deadlines.has(name_text),name_text+" emits no launch alert or radar location")
				check(not battle.fog.is_visible_at("ally",site.position),name_text+" use does not reveal the facility")
				continue
			check(not name_text.is_empty() and panel.timers.text.contains(name_text), site.sw_type() + " listed before use")
			var aim: Vector2 = landing
			if site.sw_type() == "ForceShield": aim = site.position
			if site.sw_type() == "IronCurtain": aim = tank.position
			var before := notices.size()
			site._sw_charge = site.sw_recharge()
			panel.refresh()
			check(panel.timers.text.contains(name_text + " 就绪"), site.sw_type() + " ready state")
			pings.clear()
			Ra2Sfx.stop_eva()
			Ra2Sfx._eva_last.clear()
			battle.fog.sight_until.ally.clear(); battle.fog.rebuild()
			check(battle.fog.is_visible_at("ally",site.position),name_text+" finished site remains exposed before launch")
			var charge:float=site._sw_charge
			site._sw_charge=0.0
			check(not site.fire_superweapon(aim,AIM) and pings.is_empty() and battle.fog.is_visible_at("ally",site.position),name_text+" rejected launch keeps site visible without launch warning")
			site._sw_charge=charge
			check(site.fire_superweapon(aim, AIM), site.sw_type() + " enemy launch succeeds")
			check(battle.actor_visible_to("ally",site) and site.visible and battle.fog.is_visible_at("ally",site.position),name_text+" launch exposes source immediately")
			check(not battle.fog.is_visible_at("ally",Vector2(2300,100)),name_text+" reveal stays local")
			check(pings.count(site.position)==1,name_text+" source ping once even when source equals target")
			var deadline:float=battle.fog.sight_until.ally.get(battle.fog._index(site.position),0)
			check(is_equal_approx(deadline-battle.fog.sight_clock,10.0),name_text+" ten-second source window")
			check(notices.size() == before + 1 and panel.launches.is_visible_in_tree() and panel.launches.text.contains(name_text) and not hud.log_panel.visible, name_text + " launch banner immediately visible")
			check(pings.count(aim) == 1 and hud._logs.back().node.text.contains(name_text), name_text + " target and combat log")
			var voice: String = Ra2Sfx.SUPERWEAPON_ALERT_VOICES.get(site.sw_type(), "")
			if voice.is_empty():
				check(Ra2Sfx._global_pool.any(func(p): return p.stream != null and p.stream.resource_path.ends_with("/uwarning.wav") and p.playing), name_text + " global warning sound")
			else:
				check(Ra2Sfx._eva_last.has(voice.to_upper()), name_text + " matching EVA audio")
			check(not site.fire_superweapon(aim, AIM) and notices.size() == before + 1, name_text + " rejected repeat is silent")
		var our_radar = add("NARADR", "ally", Vector2(2000, 1950))
		battle.power_low = false
		our_radar._sw_charge = our_radar.sw_recharge()
		var before := notices.size()
		check(our_radar.fire_superweapon(landing) and notices.size() == before, prefix + "friendly use raises no enemy notice")
		check(float(battle.fog.sight_until.enemy.get(battle.fog._index(our_radar.position),0)) <= battle.fog.sight_clock,prefix+"friendly support does not expose source to enemy")
		check(panel.deadlines.size() == 4, prefix + "simultaneous warnings retained")
		for label in panel.deadlines.keys(): panel.deadlines[label] = 0
		panel.refresh()
		check(not panel.launches.visible and panel.timers.visible, prefix + "launch alerts expire independently of countdowns")
		var origin:Vector2=launchers[3].position
		BattleRequest.skirmish_config.fog_of_war=true
		var saved:=BattleSaves.save_slot(battle,"quick")
		var loaded:=BattleSaves.read_slot("quick")
		check(saved.ok and loaded.ok,prefix+"ten-second vision saves and validates from disk")
		if not loaded.ok: await finish(); continue
		var snapshot:Dictionary=loaded.snapshot
		var invalid:Dictionary=snapshot.duplicate(true)
		var cell=invalid.context.death_sight.ally.keys()[0]
		invalid.context.death_sight.ally[cell]=10.1
		check(BattleSaves.validate(invalid)=="迷雾时间无效",prefix+"hold duration above ten seconds rejected")
		Ra2Sfx.stop_eva()
		Ra2Sfx._eva_last.clear()
		Snapshot.new().restore(battle,snapshot)
		check(not Ra2Sfx._eva_last.has("EVA_NUCLEARSILODETECTED") and not Ra2Sfx._eva_last.has("EVA_BEACONDETECTED"),prefix+"restore does not repeat construction announcements")
		get_tree().paused=false; battle.paused=false
		check(battle.fog.is_visible_at("ally",origin),prefix+" launch reveal survives snapshot")
		battle.fog._process(9.5)
		check(battle.fog.is_visible_at("ally",origin),prefix+" still exposed before timeout")
		battle.fog._process(0.6)
		battle.enemy_power.low = true
		battle.fog._process(120)
		check(battle.fog.is_visible_at("ally",origin) and battle.fog.is_explored_at("ally",origin),prefix+" site stays visible after launch window even without power")
		for site in battle.buildings.duplicate():
			if is_instance_valid(site) and site.side == "enemy" and site.broadcasts_superweapon():
				battle.buildings.erase(site)
				site.free()
		panel.refresh()
		check(not panel.timers.visible and not panel.visible, prefix+"only enemy support powers left: no strategic HUD")
		battle.fog._process(11)
		check(not battle.fog.is_visible_at("ally",origin) and battle.fog.is_explored_at("ally",origin),prefix+" removed launcher leaves explored terrain without live vision")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failed": failed}))
	get_tree().quit(0 if failed == 0 else 1)
