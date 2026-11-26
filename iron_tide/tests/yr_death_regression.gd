extends "res://tests/allied_abilities_regression.gd"
const Crew = preload("res://scripts/buildings/building_crew.gd")
const DeathRules = preload("res://scripts/core/yr_death_rules.gd")
const DeathFx = preload("res://scripts/core/yr_death_fx.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func add(id: String, side := "ally", point := Vector2(1700, 1700)):
	var b = battle._place_building(id, side, point, true)
	b._buildup_play = -1.0
	return b

func check_null_death_warhead() -> void:
	var prism = actor("SREF", "ally", Vector2(800, 1200))
	var gun: Dictionary = prism._active_weapon()
	check(GameData.ra2_warheads[str(gun.ra2_warhead).to_lower()].get("inf_death") == null, "native Prism warhead omits infantry death kind")
	for id in ["E2", "SCHP"]:
		var victim = actor(id, "enemy", prism.position + Vector2(110, 0))
		victim.logistics.air_lift = 0.0
		victim.hp = 1
		victim.attack_target = prism
		victim.attack_ordered = true
		victim.hull_angle = PI
		victim.turret_angle = PI
		var before: int = battle.kills
		var hp_before: float = prism.hp
		var shot := Projectile.new()
		shot.setup(prism.position, victim, gun, gun.damage, {}, "ally", prism)
		battle.projectiles_root.add_child(shot)
		check(victim.hp == 0 and victim._dead and victim.special.get("death_kind") == 1, str(id) + " lethal prism impact completes death")
		check(not victim.is_in_group("combatants") and victim.collision_layer == 0, str(id) + " removed from combat and collision")
		check(not victim._try_fire_ready(), str(id) + " dead shooter rejects a ready shot")
		victim._physics_process(4)
		victim.receive_hit(10)
		check(victim.is_queued_for_deletion() and prism.hp == hp_before and battle.kills == before + 1, str(id) + " expires without firing or double kill")
	remove_actor(prism)

func exercise_mode(mode: String) -> void:
	get_tree().paused = false
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects = []; battle.path_service.set_water([])
	battle.paused = false; battle.ended = false
	var rng := RandomNumberGenerator.new(); rng.seed = 812
	battle.allied_state.crew_rng = rng
	check(DeathRules.data().source.rules == "3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef", "original YR manifest")
	var soviet_plant = add("NAPOWR", "enemy", Vector2(800, 600))
	var old_country: String = battle._countries.enemy
	battle._countries.enemy = "Russians"
	check(GameData.get_unit("E2").built_at == "NAHAND" and Crew.crew_id(soviet_plant, rng) == "E2", "ordinary Soviet escapee resolves to producible conscript")
	battle._countries.enemy = old_country
	battle.buildings.erase(soviet_plant)
	soviet_plant.free()
	battle._refresh_pathing()
	for id in ["INIT", "CTECH"]:
		check(not GameData.get_unit(id).is_empty() and not GameData.units.any(func(u): return u.id == id), "escape-only ID resolves without production entry " + id)
		check(not GameData.unit_index.has(id), "escape fallback leaves old roster hash intact " + id)
	var plant = add("GAPOWR")
	check(Crew.count(plant) == 1, "800 plant refund / 500 -> minimum one crew")
	plant.under_construction = true
	check(Crew.count(plant) == 0, "unfinished structure has no crew")
	plant.under_construction = false
	var hq = add("GACNST", "ally", Vector2(2100, 1700))
	check(Crew.count(hq) == 3, "3000 construction yard refund -> three")
	var engineer_seen := false
	for i in 100:
		if Crew.crew_id(hq, rng) == "ENGINEER": engineer_seen = true
	check(engineer_seen, "construction yard can choose original engineer type")
	rng.seed = 812
	AlliedAbilities.change_side(hq, "enemy")
	check(Crew.count(hq) == 1 and hq.special.has_been_captured, "captured divisor doubles and persists")
	var captured_engineer := false
	for i in 100:
		if Crew.crew_id(hq, rng) == "ENGINEER": captured_engineer = true
	check(not captured_engineer, "captured construction yard suppresses engineer branch")
	rng.seed = 812
	var tower = add("ATESLA", "ally", Vector2(2300, 1900))
	check(Crew.count(tower) == 0, "Crewed=no defense cannot generate soldiers")
	var before: int = battle.units.size()
	plant.receive_hit(1.0)
	check(battle.units.size() == before, "ordinary damage never spawns crew")
	plant.receive_hit(100000.0)
	var escaped: Array = battle.units.filter(func(u): return is_instance_valid(u) and u.special.get("escaped_crew", false))
	check(escaped.size() == 1, "actual destruction generates source-limited crew", escaped.size())
	if not escaped.is_empty():
		check(escaped[0].side == "ally" and escaped[0].hp >= 5.0 and escaped[0].hp <= escaped[0].max_hp, "crew owner and native random health")
		check(not Geometry2D.is_point_in_polygon(escaped[0].position - plant.position, plant.footprint_poly()), "safe exit is outside demolished foundation")
	plant._die()
	check(battle.units.size() == before + 1, "duplicate death cannot generate extra crew")
	var sold = add("GAREFN", "ally", Vector2(1200, 1700))
	var funds: float = battle.funds
	before = battle.units.size()
	battle.select_building(sold)
	battle.sell_selected_building()
	check(is_equal_approx(battle.funds - funds, 1000.0), "sale refund unchanged by crew budget")
	check(battle.units.size() > before and battle.units.size() <= before + 2, "sale emits at most refund-funded crew")
	var erased = add("GAPOWR", "enemy", Vector2(2700, 1700))
	before = battle.units.size()
	var fx_count := get_tree().get_nodes_in_group("yr_death_effects").size()
	erased._die(null, true)
	check(battle.units.size() == before and get_tree().get_nodes_in_group("yr_death_effects").size() == fx_count, "temporal erasure emits neither crew nor normal death FX")
	var blocked = add("GAPOWR", "ally", Vector2(1700, 2300))
	battle.water_rects = [Rect2(0, 0, 3200, 3200)]
	battle.path_service.set_water(battle.water_rects)
	before = battle.units.size()
	blocked._die()
	check(battle.units.size() == before, "no land exit never spawns crew into water")
	battle.water_rects = []
	battle.path_service.set_water([])
	check_null_death_warhead()
	for pair in [["SA", "Die1"], ["HE", "Die2"]]:
		var gi = actor("E1", "ally", Vector2(1650, 1500))
		gi._anim = 987.0
		gi.receive_hit(100000.0, "bullet", {}, null, pair[0])
		check(gi.special.death_sequence == pair[1] and gi._anim == 0.0, "death begins at correct first frame " + pair[1])
		check(is_equal_approx(gi._dying, 15.0 / 13.0), "all 15 original infantry frames are scheduled")
		check(gi.collision_layer == 0 and not gi.is_in_group("combatants"), "corpse cannot block or fight")
		gi.set_physics_process(false)
		gi._physics_process(0.7)
		check(not gi.is_queued_for_deletion(), "corpse survives beyond old truncated 0.6 seconds")
		gi._physics_process(0.5)
		check(gi.is_queued_for_deletion(), "complete sequence releases original actor")
	var tank = actor("MTNK", "ally", Vector2(1600, 1900))
	fx_count = get_tree().get_nodes_in_group("yr_death_effects").size()
	tank._die()
	check(get_tree().get_nodes_in_group("yr_death_effects").size() > fx_count, "RA2 vehicle consumes original Explosion list")
	var effect = DeathFx.play(battle, Vector2(1750, 1700), "DBRIS1LG", true)
	check(effect != null and effect.vertical_speed > 0 and effect.velocity.length() > 0, "original debris emits moving SHP fragment")
	battle.paused = true
	effect._process(0.5)
	check(effect.age == 0, "death effects respect battle pause")
	battle.paused = false
	effect._process(5.1)
	check(effect.is_queued_for_deletion(), "debris has finite landing/cleanup lifetime")
	var flame = DeathFx.play(battle, Vector2(1700, 1700), "FLAMEGUY")
	check(flame.art.count == 108 and flame.playback.size() == 66, "flame death excludes shadow half and uses one running direction")
	check(flame.playback[6] == 48 and flame.playback[-1] == 107, "flame collapse follows directional running strip")
	var electro = DeathFx.play(battle, Vector2(1740, 1700), "ELECTRO")
	check(electro.playback.size() == 31, "electrocution preserves original loop count before ending")
	for spec in [["YR_DEATH_FIRE", 4], ["YR_DEATH_ELECTRO", 5]]:
		GameData.ra2_warheads[spec[0].to_lower()] = {"inf_death": spec[1]}
		var infantry = actor("E1", "ally", Vector2(1600, 1500))
		fx_count = get_tree().get_nodes_in_group("yr_death_effects").size()
		infantry.receive_hit(100000, "bullet", {}, null, spec[0])
		check(infantry.is_queued_for_deletion() and get_tree().get_nodes_in_group("yr_death_effects").size() == fx_count + 1, "actual warhead routes special death " + spec[0])
		GameData.ra2_warheads.erase(spec[0].to_lower())
	var house = Sites.create(battle, "CAHSE01", Vector2(1800, 1300))
	house._die()
	check(battle.allied_state.building_rubble.size() == 1, "LeaveRubble retains source civilian ruin")
	var ruins := get_tree().get_nodes_in_group("yr_building_rubble")
	check(ruins.size() == 1 and ruins[0].frame == 3 and not ruins[0].is_in_group("combatants"), "rubble uses final visible frame and is not a combat actor")
	await get_tree().process_frame
	var snapshot := Snapshot.new().capture(battle)
	check(BattleSaves.validate(snapshot).is_empty(), "new death/rubble state passes actual save validator", BattleSaves.validate(snapshot))
	var legacy := snapshot.duplicate(true)
	legacy.erase("death_rules")
	check(BattleSaves.validate(legacy).is_empty(), "pre-death-rules save remains accepted")
	legacy.death_rules = "changed rules"
	check(not BattleSaves.validate(legacy).is_empty(), "new saves reject mismatched death rules")
	var rng_state := rng.state
	Snapshot.new().restore(battle, snapshot)
	check(battle.allied_state.building_rubble.size() == 1 and get_tree().get_nodes_in_group("yr_building_rubble").size() == 1, "save restore preserves rubble without duplication")
	check(battle.allied_state.crew_rng.state == rng_state, "save restores crew RNG state")
	check(battle.units.any(func(u): return is_instance_valid(u) and u.special.get("escaped_crew", false)), "escaped crew are ordinary saved units")
	if DisplayServer.get_name() != "headless":
		battle.paused = false; battle.ended = false; get_tree().paused = false
		var visual_plant = add("GAPOWR", "ally", Vector2(1760, 1600))
		visual_plant._die()
		var visual_gi = actor("E1", "ally", Vector2(1660, 1540))
		visual_gi.receive_hit(100000, "bullet", {}, null, "SA")
		visual_gi.set_physics_process(false); visual_gi._physics_process(0.4)
		for fx in get_tree().get_nodes_in_group("yr_death_effects"):
			if not fx.is_queued_for_deletion(): fx._process(0.35)
		battle.camera.position = Vector2(1800, 1550); battle.camera.force_update_scroll()
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-death.png"))
	var reactor = add("YAPOWR", "enemy", Vector2(940, 680))
	battle._countries.enemy = "Americans"
	for site_house in ["YuriCountry", "Yuri2", "Yuri3", "Yuri4"]:
		reactor.special.hollywood_house = site_house
		check(Crew.crew_id(reactor, rng) == "INIT", "mission crew uses " + site_house)
	var codec := Snapshot.new()
	var saved := codec.capture(battle)
	var restored_id: int = codec.ids[reactor]
	codec.restore(battle, saved)
	reactor = codec.objects[restored_id]
	battle.allied_state.crew_rng.seed = 812
	before = battle.units.size()
	reactor.receive_hit(100000.0)
	var survivors: Array = battle.units.slice(before)
	check(survivors.size() == 1 and survivors[0].unit_id == "INIT" and survivors[0].side == "enemy", "restored Yuri reactor releases enemy initiate on destruction")
	var captured = add("YAPOWR", "enemy", Vector2(900, 850))
	captured.special.hollywood_house = "Yuri2"
	AlliedAbilities.change_side(captured, "ally")
	check(Crew.crew_id(captured, rng) == "E1", "captured Yuri reactor follows American controller")
	await check_rocketeer_crash(mode)
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	get_tree().paused = false
	await get_tree().process_frame

func check_rocketeer_crash(mode: String) -> void:
	var point := Vector2(850, 2350)
	var flyer = actor("JUMPJET", "enemy", point)
	flyer.logistics.air_lift = 1.0
	var start_lift: float = flyer._visual_lift()
	var kills_before: int = battle.kills
	flyer.receive_hit(100000, "flak", {}, null, "FlakWH")
	check(flyer._dead and not flyer.is_in_group("combatants") and not flyer.hit_test(point) and battle.kills == kills_before + 1, "air kill counted once and actor removed from combat immediately")
	check(flyer.special.get("death_sequence") == "AirDeathStart" and is_equal_approx(flyer._visual_lift(), start_lift), "rocketeer starts crash at actual hover height")
	check(is_equal_approx(flyer.flight.crash_speed, 25.0 * 2 * 15 * 30 / 256), "YR crash rate is projected into the 15 Hz flight clock")
	flyer.set_physics_process(false)
	battle.camera.position = point
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var fall_time: float = start_lift / flyer.flight.crash_speed
	var elapsed := 0.0
	for sample in [[0.07, "AirDeathStart"], [fall_time * 0.5, "AirDeathStart"], [fall_time - 0.05, "AirDeathFalling"], [fall_time + 0.12, "AirDeathFinish"]]:
		flyer._physics_process(float(sample[0]) - elapsed)
		elapsed = float(sample[0])
		check(flyer.special.get("death_sequence") == sample[1] and flyer.position == point and is_equal_approx(flyer._visual_lift(), maxf(0, start_lift - elapsed * flyer.flight.crash_speed)), "crash height and sequence " + str(sample[1]))
		if DisplayServer.get_name() != "headless":
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var seq: Dictionary = flyer._seq[sample[1]]
			check(flyer._art_frame >= seq.start and flyer._art_frame < seq.start + seq.per, "rendered original SHP frame " + str(sample[1]))
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + str(sample[1]) + "-" + str(roundi(elapsed * 100)) + ".png"))
	flyer._physics_process(1.0)
	check(flyer.is_queued_for_deletion() and battle.kills == kills_before + 1, "touchdown finishes once")
	var low = actor("JUMPJET", "ally", point)
	low.logistics.air_lift = 0.08
	low.receive_hit(100000)
	low._physics_process(0.1)
	check(low.special.get("death_sequence") == "AirDeathFinish" and low._visual_lift() == 0.0, "low altitude lands sooner")
	var ground = actor("JUMPJET", "ally", point)
	ground.logistics.air_lift = 0.0
	ground.receive_hit(100000)
	check(ground.special.get("death_sequence") == "Die1", "grounded infantry retains ordinary death")
	var erased = actor("JUMPJET", "ally", point)
	erased.logistics.air_lift = 1.0
	erased._die(null, true)
	check(erased.is_queued_for_deletion() and erased.flight.crash_lift < 0.0, "temporal erasure bypasses crash")
