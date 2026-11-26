extends "res://tests/base_recovery_regression.gd"

const Rules = preload("res://scripts/core/yr_death_rules.gd")
const ORIGIN := Vector2(1250, 1350)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	start(MatchRules.RA2)
	if battle.fog != null: battle.fog.free(); battle.fog = null
	check_infantry()
	check_vehicles()
	await check_disc()
	await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func check_infantry() -> void:
	# Retail artmd.ini death strips, including the engineer's shared image.
	var frames := {"INIT":[139,15,154,15], "YURI":[134,15,149,15], "YURIPR":[134,20,154,15],
		"YENGINEER":[134,15,149,15], "BRUTE":[86,15,101,15], "VIRUS":[134,15,149,15], "SLAV":[86,15,101,15]}
	for id in frames:
		for kind in [1,2]:
			var unit = battle.spawn_unit(id,"ally",ORIGIN)
			var seq := "Die%d" % kind
			check(unit != null, id + " spawns")
			if unit == null: continue
			unit._anim = 42.0
			unit.receive_hit(100000,"explosive",{},null,"HE" if kind == 2 else "")
			var row: Dictionary = unit._seq.get(seq,{})
			var start_frame: int = frames[id][(kind-1)*2]
			var count: int = frames[id][(kind-1)*2+1]
			check(unit._dead and unit.special.get("death_sequence") == seq and unit._anim == 0.0
				and is_equal_approx(unit._dying,count/13.0) and row.get("start") == start_frame and row.get("per") == count
				and int(unit._ra2.get("count",0)) >= start_frame+count, id + " " + seq + " uses complete retail strip", row)

func check_vehicles() -> void:
	for id in ["PCV", "LTNK", "YTNK", "SMIN", "YHVR", "TELE", "CAOS", "BSUB", "MIND", "CMISL"]:
		var unit = battle.spawn_unit(id,"ally",ORIGIN)
		check(unit != null, id + " spawns")
		if unit == null: continue
		var before := get_tree().get_node_count_in_group("yr_death_effects")
		unit.receive_hit(100000)
		check(unit._dead and get_tree().get_node_count_in_group("yr_death_effects") > before, id + " lethal damage produces original SHP explosion")
	# The deployed miner is represented by a building, not a spawnable SMON actor.
	var refinery = battle._place_building("YAREFN","ally",ORIGIN,true)
	var effects_before := get_tree().get_node_count_in_group("yr_death_effects")
	refinery._die()
	check(refinery._dead and get_tree().get_node_count_in_group("yr_death_effects") > effects_before, "deployed slave miner plays original building explosion")
	for id in Rules.names(Rules.type_data("DISK"),"explosion"):
		check(Rules.data().animations.has(id) and ResourceLoader.exists("res://assets/ra2/death/" + id + ".png"), id + " has imported explosion art")

func falling_disc():
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.splinters.get("hull_id") == "DISK" and not shot.is_queued_for_deletion(): return shot
	return null

func check_disc() -> void:
	var point := ORIGIN + Vector2(250, 110)
	var disc = battle.spawn_unit("DISK","ally",point)
	var tank = battle.spawn_unit("MTNK","enemy",point + Vector2(13,0))
	var air = battle.spawn_unit("DISK","enemy",point + Vector2(45,-45))
	disc.logistics.air_lift = 1.0
	air.logistics.air_lift = 1.0
	var lift: float = disc._visual_lift()
	var heading: float = disc.hull_angle
	var clips := GameData.ra2_sound_files("FloatingDiscDie")
	check(clips == ["head_games/vflodiea.wav"] and Ra2Sfx._stream(clips[0]) != null, "source crash sample loads")
	check(RA2Art.has_art("DISK_turret") and ResourceLoader.exists("res://assets/ra2/vxl/DISK_detail.png") and ResourceLoader.exists("res://assets/ra2/vxl/DISK_turret_detail.png"), "both lit voxel detail layers load")
	var effects_before := get_tree().get_node_count_in_group("yr_death_effects")
	disc.receive_hit(100000)
	var wreck = falling_disc()
	check(wreck != null and disc._dead and not disc.is_in_group("combatants"), "lethal hit immediately removes combatant and leaves a falling hull")
	if wreck == null: return
	check(is_equal_approx(wreck.splinters.height,lift) and wreck.splinters.damage == 25.0 and wreck.splinters.warhead == "BlimpHEEffect", "flight height and retail death payload are captured")
	wreck._physics_process(0.86)
	var mid: float = wreck.splinters.height
	check(mid > 0.0 and mid < lift and not is_equal_approx(wreck.splinters.heading,heading), "hull turns and descends")
	check(tank.hp == tank.max_hp and get_tree().get_node_count_in_group("yr_death_effects") == effects_before, "no premature death blast or explosion")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = point
		battle.camera.zoom = Iso.cam_zoom(2.0)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(output_dir.path_join("disc-falling.png"))
	battle.paused = true
	wreck._physics_process(2.0)
	check(wreck.splinters.height == mid,"paused crash holds altitude")
	battle.paused = false
	var saved := BattleSaves.save_slot(battle,"slot2")
	var loaded := BattleSaves.read_slot("slot2")
	check(saved.ok and loaded.ok,"mid-crash save roundtrip")
	if not loaded.ok: return
	BattleSaves.Snapshot.new().restore(battle,loaded.snapshot)
	wreck = falling_disc()
	check(wreck != null and is_equal_approx(wreck.splinters.height,mid),"restored crash retains hull type and altitude")
	if wreck == null: return
	battle.paused = false
	get_tree().paused = false
	var target = battle.units.filter(func(u): return u.unit_id == "MTNK" and u.position.distance_to(point) < 20.0)[0]
	var flyer = battle.units.filter(func(u): return u.unit_id == "DISK" and u.side == "enemy")[0]
	var before := get_tree().get_node_count_in_group("yr_death_effects")
	var debris_before: int = battle.allied_state.get("yr_vehicle_debris", []).size()
	wreck._physics_process(3.0)
	check(wreck._detonated and target.hp < target.max_hp and flyer.hp == flyer.max_hp, "touchdown hits ground only", [wreck._detonated, target.hp, flyer.hp, battle.ended])
	check(get_tree().get_node_count_in_group("yr_death_effects") > before,"touchdown plays original explosion")
	var debris_count: int = battle.allied_state.get("yr_vehicle_debris", []).size() - debris_before
	check(debris_count >= 0 and debris_count <= 14,"touchdown uses retail debris cap",debris_count)
	var hp: float = target.hp
	wreck._physics_process(1.0)
	check(target.hp == hp,"touchdown resolves exactly once")
	flyer._die(null,true)
	check(falling_disc() == null,"temporal erasure does not spawn a crash")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("disc-impact.png"))
