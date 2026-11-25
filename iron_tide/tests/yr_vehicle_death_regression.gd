extends "res://tests/allied_abilities_regression.gd"
const Death = preload("res://scripts/core/yr_death_combat.gd")
const Debris = preload("res://scripts/core/yr_vehicle_debris.gd")
const Driver = preload("res://scripts/units/vehicle_crew.gd")
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func reset_field() -> void:
	for node in battle.units + battle.buildings:
		if is_instance_valid(node): node.free()
	battle.units.clear(); battle.buildings.clear()
	for fx in battle.effects_root.get_children(): fx.free()
	battle.allied_state.clear()
	battle.paused = false; battle.ended = false

func check_missile_debris() -> void:
	var point := Vector2(1700, 1700)
	var scout = actor("E1", "ally", point + Vector2(40, 0))
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	check(fog.is_visible_at("ally", point) and not fog.is_visible_at("ally", Vector2.ZERO), "intercept visible while map origin is hidden")
	for id in ["V3ROCKET", "DMISL"]:
		for seed_value in 6:
			var missile = actor(id, "enemy", point)
			missile.logistics.air_lift = 90.0
			Debris.rng_for(battle).seed = seed_value
			battle.allied_state[Debris.KEY] = []
			missile.receive_hit(1, "flak", {}, scout)
			check(battle.allied_state[Debris.KEY].is_empty(), id + " survives flak without shedding debris")
			missile.receive_hit(9999, "flak", {}, scout)
			var pieces: Array = battle.allied_state[Debris.KEY]
			check(pieces.size() in [1, 2] and pieces.all(func(s): return s.id == "PIECE" and s.point == point and is_equal_approx(s.lift, 90.0)), id + " breaks apart at interception altitude", pieces.size())
			var visual = battle.effects_root.get_node_or_null("YrVehicleDebris")
			if visual != null:
				fog._filter_transient(visual)
				check(visual.is_visible_in_tree(), id + " renderer remains visible over explored battle site")
				visual.advance(0.1)
				check(pieces.all(func(s): return s.age > 0 and s.point != point), id + " fragments travel separately")
				if seed_value == 0 and not pieces.is_empty() and DisplayServer.get_name() != "headless":
					for fx in battle.effects_root.get_children():
						if fx.is_in_group("yr_death_effects"): fx._process(0.65)
					visual._physics_process(0.65)
					battle.camera.position = point
					battle.camera.reset_smoothing()
					battle.camera.force_update_scroll()
					await get_tree().process_frame
					var at: Vector2 = pieces[0].point + RA2Art.art_dir(Vector2.UP * float(pieces[0].lift))
					var area := Rect2i(Vector2i(stage.get_canvas_transform() * at) - Vector2i(30, 30), Vector2i(60, 60))
					await RenderingServer.frame_post_draw
					var shown: Image = stage.get_texture().get_image().get_region(area)
					visual.hide()
					await RenderingServer.frame_post_draw
					var hidden: Image = stage.get_texture().get_image().get_region(area)
					shown.save_png(output_dir.path_join(id + "-intercept.png"))
					check(shown.get_data() != hidden.get_data(), id + " fragment changes rendered pixels at altitude")
					visual.show()
	fog.free()
	battle.fog = null

func check_demo_base_safety() -> void:
	var yard = battle._place_building("NACNST", "enemy", Vector2(1100, 1100), true)
	var truck = actor("DTRUCK", "enemy", yard.position + Vector2(160, 0))
	var target = actor("MTNK", "ally", truck.position + Vector2(30, 0))
	truck.hull_angle = 0
	truck.set_fire_stance("free")
	truck._refresh_target()
	check(truck.attack_target == target and not truck._try_fire_ready() and not truck._dead, "AI truck refuses automatic detonation inside its base")
	battle.skirmish_ai._army = [truck]
	check(not battle.skirmish_ai._defend_base() and not truck.has_move_order, "truck not assigned to intercept base intruder")
	preload("res://scripts/world/skirmish_operations.gd").order_attack(truck, target)
	var depot = battle._place_building("NADEPT", "enemy", Vector2(2200, 1400), true)
	var edge: float = depot.footprint_clearance(Vector2.RIGHT)
	truck.position = depot.position + Vector2(440 + edge - 2, 0)
	target.position = truck.position + Vector2(30, 0)
	check(truck._weapon_target_valid(target) and not truck._try_fire_ready() and truck._cd_timer == 0 and not battle.allied_state.has("rad_sites"), "outpost footprint inside real blast blocks even explicit AI order without consuming cooldown")
	truck.position = depot.position + Vector2(640 + edge, 0)
	target.position = truck.position + Vector2(30, 0)
	var hp: float = target.hp
	check(truck._try_fire_ready() and truck._dead and target.hp < hp and battle.allied_state.has("rad_sites"), "same order detonates outside AI base")
	truck = actor("DTRUCK", "enemy", yard.position + Vector2(100, 0))
	hp = yard.hp
	truck.receive_hit(10000)
	check(truck._dead and yard.hp < hp, "enemy can still destroy AI truck in base and trigger death blast")
	var player_yard = battle._place_building("GACNST", "ally", Vector2(600, 550), true)
	var manual = actor("DTRUCK", "ally", player_yard.position + Vector2(110, 0))
	var foe = actor("HTNK", "enemy", manual.position + Vector2(30, 0))
	battle.select_unit(manual, false)
	battle.force_attack(foe)
	manual.hull_angle = 0
	check(manual._try_fire_ready() and manual._dead, "player retains manual detonation beside own yard")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode, "美国")
	for group in ["obstacles", "resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group): node.free()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	battle.water_rects = []; battle.path_service.set_water([])
	reset_field()
	check_demo_base_safety()
	reset_field()
	await check_missile_debris()
	reset_field()
	for id in ["PIECE", "TIRE", "GASTANK"]:
		var v: Dictionary = Rules.data().voxels[id]
		check(v.rects.size() == 128 and ResourceLoader.exists("res://assets/ra2/death/" + id + ".png"), "original voxel atlas with 16 directions x 8 tumble poses " + id)
	check(Rules.data().general.crewescape == "50%", "native crew probability preserved")
	check(Rules.data().voxels.PIECE.raw.damage == "5" and Rules.data().voxels.GASTANK.raw.damage == "20", "original fragment damage")
	check(Ra2Damage.has("BlimpHEEffect"), "missing YR death-only warhead now resolves")
	var before_units: int = battle.units.size()
	var carrier = actor("AMCV", "ally", Vector2(1700, 1700))
	var rng := RandomNumberGenerator.new(); rng.seed = 812
	battle.allied_state.crew_rng = rng
	var success := 0
	for i in 60:
		carrier.special.erase("yr_driver_checked")
		var escaped := Driver.eject(carrier)
		check(escaped.size() <= 1, "one-driver upper bound " + str(i))
		for crew in escaped:
			success += 1
			check(crew.side == "ally" and crew.special.escaped_driver and crew.hp >= 5 and crew.hp <= crew.max_hp, "driver ownership and health")
			remove_actor(crew)
	check(success > 12 and success < 48, "fixed RNG produces both 50% outcomes", success)
	var saved_chance: String = Rules.data().general.crewescape
	Rules.data().general.crewescape = "100%"
	carrier.special.erase("yr_driver_checked")
	carrier.receive_hit(100000)
	check(battle.units.size() == before_units + 2, "real lethal MCV hit emits driver")
	var population: int = battle.units.size()
	carrier._die()
	check(battle.units.size() == population, "duplicate death cannot emit second driver")
	var miner = actor("CMIN", "ally", Vector2(1950, 1700))
	check(Driver.eject(miner).is_empty(), "Crewed=no miner cannot escape")
	var robot = actor("ROBO", "ally", Vector2(1900, 1900))
	check(Driver.eject(robot).is_empty(), "robot without Crewed cannot spawn organic driver")
	for owner in ["ally", "enemy"]:
		var jet = actor("ORCA", owner, Vector2(2500, 1500))
		jet.logistics.air_lift = 1.0
		var before_loss: int = battle.units.size()
		jet.receive_hit(100000, "flak")
		check(jet._dead and battle.units.size() == before_loss, owner + " Intruder shot down over clear land spawns no soldier or technician")
	var drone = actor("HORNET", "enemy", Vector2(2500, 1700))
	check(Driver.eject(drone).is_empty(), "carrier drone has no pilot escape")
	var blocked = actor("AMCV", "enemy", Vector2(2200, 2200))
	battle.water_rects = [Rect2(0, 0, 3200, 3200)]
	battle.path_service.set_water(battle.water_rects)
	check(Driver.eject(blocked).is_empty(), "no land exit discards escape without stacking or water spawn")
	battle.water_rects = []
	battle.path_service.set_water([])
	var erased = actor("AMCV", "ally", Vector2(2300, 1900))
	population = battle.units.size()
	var pieces: int = battle.allied_state.get(Debris.KEY, []).size()
	erased._die(null, true)
	check(battle.units.size() == population and battle.allied_state.get(Debris.KEY, []).size() == pieces, "temporal erase suppresses crew and fragments")
	Rules.data().general.crewescape = saved_chance
	reset_field()
	var target = actor("E1", "enemy", Vector2(1700, 1700))
	target.hp = 1000; target.max_hp = 1000
	var friendly = actor("E1", "ally", Vector2(1700, 1700))
	friendly.hp = 1000; friendly.max_hp = 1000
	var outside = actor("E1", "enemy", Vector2(1800, 1700))
	var outside_hp: float = outside.hp
	var state := Debris.launch(battle, "GASTANK", target.position, "ally")
	state.velocity = Vector2.ZERO; state.lift = 0.01; state.vz = -10.0
	var visual = Debris.restore(battle)
	battle.paused = true; visual._physics_process(1.0)
	check(state.age == 0 and target.hp == 1000, "pause suspends damage and motion")
	battle.paused = false; visual._physics_process(1.0 / 60)
	check(target.hp == 982 and friendly.hp == 982, "oil fragment 20 x 90% applies to both sides")
	check(outside.hp == outside_hp, "outside CellSpread remains unharmed")
	check(battle.allied_state[Debris.KEY].is_empty(), "impact record consumed before damage")
	visual._physics_process(2.0)
	check(target.hp == 982, "spent fragment cannot damage twice")
	var extra: Dictionary = GameData.ra2_warheads.tankogas.extra
	extra.AffectsAllies = "no"
	Death.queue_blast(battle, target.position, "ally", 20.0, "TankOGas")
	check(target.hp == 964 and friendly.hp == 982, "warhead AffectsAllies=no suppresses friendly damage")
	extra.erase("AffectsAllies")
	target.hp = 982
	var prone = actor("E1", "enemy", target.position)
	prone.set_deployed(true, false)
	prone.bonuses = {} # Isolate the original warhead from extended-mode posture bonuses.
	var prone_hp: float = prone.hp
	Death.queue_blast(battle, target.position, "ally", 20.0, "TankOGas")
	check(prone.hp == prone_hp - 9, "original ProneDamage halves 18-point fragment blast")
	remove_actor(prone); target.hp = 982; friendly.hp = 982
	state = Debris.launch(battle, "PIECE", target.position, "ally", 1.0, false)
	state.velocity = Vector2.ZERO; state.vz = -10
	visual._physics_process(0.1)
	check(target.hp == 982, "DebrisDamages=no is cosmetic")
	state = Debris.launch(battle, "TIRE", Vector2(1500, 1500), "ally", 0.1)
	state.vz = -40; visual._physics_process(0.02)
	check(state.bounces > 0 and state.vz > 0, "elastic original tire bounces")
	visual._physics_process(11.0)
	check(battle.allied_state[Debris.KEY].is_empty(), "Duration bounds bouncing fragment lifetime")
	state = Debris.launch(battle, "GASTANK", target.position, "ally", 0.01)
	state.velocity = Vector2.ZERO; state.vz = -10
	battle.water_rects = [Rect2(1600, 1600, 200, 200)]
	battle.path_service.set_water(battle.water_rects)
	visual._physics_process(0.1)
	check(target.hp == 982 and battle.allied_state[Debris.KEY].is_empty(), "water disposes debris without land blast")
	battle.water_rects = []
	battle.path_service.set_water([])
	reset_field()
	var victim = actor("MTNK", "enemy", Vector2(1700, 1700))
	var ifv = actor("FV", "ally", Vector2(1710, 1700))
	var hp: float = victim.hp
	ifv.receive_hit(100000)
	check(victim.hp == hp, "IFV DeathWeapon alone does not trigger a nuclear blast")
	reset_field()
	var truck = actor("DTRUCK", "ally", Vector2(1700, 1700))
	victim = actor("MTNK", "enemy", Vector2(1750, 1700))
	var expected := floorf(Ra2Damage.target_damage(300, "DemobombWH", victim, 50.0))
	hp = victim.hp
	truck.receive_hit(100000)
	check(victim.hp == hp - expected, "native demo death weapon uses Verses and falloff", [victim.hp, hp - expected])
	truck._die()
	check(victim.hp == hp - expected, "duplicate truck death does not redetonate")
	reset_field()
	var a = actor("DTRUCK", "ally", Vector2(1700, 1700))
	var b = actor("DTRUCK", "enemy", Vector2(1750, 1700))
	var c = actor("DTRUCK", "enemy", Vector2(1800, 1700))
	b.hp = 1; c.hp = 1
	a.receive_hit(100000)
	check(a._dead and b._dead and c._dead, "death chain propagates through actual receive_hit")
	check(battle.allied_state[Death.KEY].is_empty() and not battle.has_meta(Death.KEY), "chain queue drained without recursive state leak")
	reset_field()
	var yard = battle._place_building("GAYARD", "enemy", Vector2(1700, 1700), true)
	yard._buildup_play = -1
	victim = actor("MTNK", "ally", Vector2(1700, 1700))
	hp = victim.hp
	yard.retire_sold()
	check(victim.hp == hp and not battle.allied_state.has(Death.KEY), "sale cannot trigger Explodes default weapon")
	var yard2 = battle._place_building("GAYARD", "enemy", Vector2(1700, 1700), true)
	yard2._buildup_play = -1
	yard2.receive_hit(100000)
	check(victim._dead, "unarmed Explodes uses original strength/2 default weapon")
	reset_field()
	var plant = battle._place_building("GAPOWR", "enemy", Vector2(1700, 1700), true)
	plant._buildup_play = -1; plant.special.no_crew = true
	plant.receive_hit(100000)
	var building_fragments: Array = battle.allied_state.get(Debris.KEY, [])
	check(building_fragments.size() >= 4 and building_fragments.size() <= 6, "building reads original plural DebrisAnims and min/max count")
	check(building_fragments.all(func(s): return s.kind == "shp"), "building fragment media remains original SHP")
	victim = actor("MTNK", "ally", Vector2(1800, 1700)); hp = victim.hp
	state = Debris.launch(battle, "DBRIS1LG", victim.position, "enemy", 0.01, true, "shp")
	state.velocity = Vector2.ZERO; state.vz = -10
	Debris.restore(battle)._physics_process(0.02)
	check(victim.hp == hp - floorf(Ra2Damage.target_damage(20, "HE", victim, 0)), "building SHP debris also applies original damage")
	reset_field()
	target = actor("E1", "enemy", Vector2(1700, 1700)); target.hp = 1000; target.max_hp = 1000
	battle.allied_state[Death.KEY] = []
	for i in 70: battle.allied_state[Death.KEY].append({"point": target.position, "side": "ally", "damage": 2, "warhead": "DeathWH", "sound": ""})
	Death.drain(battle)
	check(battle.allied_state[Death.KEY].size() == 6 and target.hp == 872, "bounded blast dispatch preserves unprocessed tail")
	battle.paused = true; Death.tick(battle)
	check(target.hp == 872, "paused pending blast queue cannot advance")
	battle.paused = false; Death.tick(battle)
	check(battle.allied_state[Death.KEY].is_empty() and target.hp == 860, "next tick resolves remaining chain exactly once")
	reset_field()
	target = actor("E1", "enemy", Vector2(1700, 1700))
	state = Debris.launch(battle, "GASTANK", target.position, "ally", 50.0)
	state.velocity = Vector2.ZERO
	visual = Debris.restore(battle); visual._physics_process(0.1)
	var rng_state: int = Debris.rng_for(battle).state
	var snapshot := Snapshot.new().capture(battle)
	check(BattleSaves.validate(snapshot).is_empty(), "actual snapshot validator accepts pending damage and RNG", BattleSaves.validate(snapshot))
	visual._physics_process(5.0)
	var resulting_hp: float = target.hp
	Snapshot.new().restore(battle, snapshot)
	check(battle.allied_state[Debris.KEY].size() == 1 and Debris.rng_for(battle).state == rng_state, "restore retains pending fragment and RNG")
	visual = Debris.restore(battle)
	battle.paused = false; battle.ended = false; get_tree().paused = false
	visual._physics_process(5.0)
	check(battle.units[0].hp == resulting_hp and battle.allied_state[Debris.KEY].is_empty(), "save before impact yields identical one-shot damage after restore", [battle.units[0].hp, resulting_hp, battle.allied_state[Debris.KEY].size()])
	check(battle.effects_root.get_children().filter(func(n): return n.name == "YrVehicleDebris").size() == 1, "restore never duplicates debris renderer")
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	get_tree().paused = false
	await get_tree().process_frame
