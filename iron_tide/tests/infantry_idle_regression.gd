extends "res://tests/base_recovery_regression.gd"

const INFANTRY := ["E1","ENGINEER","JUMPJET","GHOST","DOG","CLEG","SPY","CCOMAND","PTROOP","SNIPE","TANY","GGI","E2","SHK","FLAKT","SENGINEER","SOV_DOG","BORIS","IVAN","CIVAN","DESO","TERROR","CTECH","INIT"]
const POINT := Vector2(1200,1200)

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	start(MatchRules.RA2)
	# Boris can designate buildings far beyond rifle range. Isolate our combat target.
	for building in battle.buildings:
		if building.is_in_group("enemies"): building.remove_from_group("enemies")
	for id in INFANTRY:
		var u = battle.spawn_unit(id, "ally", POINT)
		u.logistics.air_lift = 0.0
		inspect_sequence(u, false)
		if id in ["GHOST","TANY"]:
			battle.path_service.water_rects.assign([Rect2(POINT-Vector2(80,80),Vector2(160,160))])
			inspect_sequence(u,true)
			battle.path_service.water_rects.clear()
		battle.units.erase(u)
		u.free()
	for id in ["E1","E2","SHK","BORIS"]:
		await repeat_under_orders(id)
	if DisplayServer.get_name() != "headless":
		for id in ["E1","SHK"]:
			for stop_early in [false,true]: await render_arrival(id,stop_early)
	await tesla_render()
	await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	report.close()
	get_tree().quit(0 if failed == 0 else 1)

func inspect_sequence(u, water: bool) -> void:
	var label: String = u.unit_id + (" water" if water else " land")
	check(u.idle_pose != null and not u._ra2.get("detail",{}).is_empty(), label + " sequence and 2x artwork loaded")
	if u.idle_pose == null: return
	var expected := {}
	for name in (["WetIdle1","WetIdle2"] if water else ["Idle1","Idle2"]):
		if int(u._seq.get(name,{}).get("per",0)) > 1: expected[name] = true
	check(not expected.is_empty(), label + " original clips declared")
	var seen := {}
	for tick in 750:
		u.idle_pose.tick(u,1.0/30.0)
		if u.idle_pose.frame < 0: continue
		var name: String = u.idle_pose.clip
		if not seen.has(name): seen[name] = {}
		seen[name][u.idle_pose.frame] = true
	for name in expected:
		check(seen.get(name,{}).size() == int(u._seq[name].per), label + " visits every frame of " + name)
	check(seen.size() == expected.size(),label + " uses correct terrain clips")
	u.idle_pose.reset(u)

func repeat_under_orders(id: String) -> void:
	var u = battle.spawn_unit(id,"ally",POINT)
	u.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	u.order_stop()
	u.fire_stance = "free"
	# Mobile guards remember an enemy inside sight even outside firing range.
	var enemy = battle.spawn_unit("HTNK","enemy", POINT + Vector2((u.attack_range + u.sight) * 0.5, 0))
	enemy.order_stop()
	var prior := ""
	var times: Array[float] = []
	var start_pos: Vector2 = u.position
	for tick in 1200:
		u._physics_process(1.0 / 30)
		if u.idle_pose.clip != prior and not u.idle_pose.clip.is_empty(): times.append(tick / 30.0)
		prior = u.idle_pose.clip
	check(times.size() >= 4 and u.attack_target == enemy and u.position == start_pos and enemy.hp == enemy.max_hp, id + " repeats idle while observing distant target without advancing or firing", times)
	for i in range(1,times.size()):
		check(times[i]-times[i-1] <= 9.05 and times[i]-times[i-1] >= 4.45,id+" native start-to-start cadence", times)
	enemy.position = POINT + Vector2(45,0)
	u._cd_timer = 0.0
	for tick in 15: u._physics_process(1.0 / 30)
	check(u.idle_pose.frame == -1 and enemy.hp < enemy.max_hp, id+" real gunfire interrupts idle")
	battle.units.erase(enemy)
	enemy.free()
	u.order_move(POINT + Vector2(90,0))
	await get_tree().physics_frame
	for tick in 180: u._physics_process(1.0 / 60)
	check(not u.has_move_order and u.position.distance_to(start_pos)>50, id+" completes ordinary move")
	var cycles := 0
	prior = ""
	for tick in 900:
		u._physics_process(1.0 / 30)
		if not u.idle_pose.clip.is_empty() and prior.is_empty(): cycles += 1
		prior = u.idle_pose.clip
	check(cycles >= 3,id+" idle resumes repeatedly after fighting and moving",cycles)
	battle.units.erase(u)
	u.free()

func draw_frame(u) -> int:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return u._art_frame

func render_arrival(id: String, stop_early: bool) -> void:
	var u = battle.spawn_unit(id,"ally",POINT)
	u.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	battle.camera.position = POINT
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	u.order_move(POINT+Vector2(120,0))
	await get_tree().physics_frame
	for step in 300:
		u._physics_process(1.0/60)
		if u._moving() and (stop_early or u.position.distance_to(u.move_target)<=u.ARRIVE_EPS): break
	var moving_frame := await draw_frame(u)
	var walk: Dictionary = u._seq.Walk
	var label := id + (" stop order" if stop_early else " arrival")
	check(not u.selected and not u.hovered and u._moving() and moving_frame>=int(walk.start) and moving_frame<int(walk.start)+int(walk.per)*int(walk.facings), label+" rendered walking without hover or selection")
	if stop_early: u.order_stop()
	u._physics_process(1.0/60)
	var guard := RA2Art.seq_frame(u._seq,"Guard",RA2Art.facing_index(u.hull_angle,8),0)
	var shown := await draw_frame(u)
	check(not u.has_move_order and not u._moving() and u.idle_pose.frame<0 and shown==guard, label+" first stationary draw returns to guard",[moving_frame,shown,guard])
	battle.units.erase(u)
	u.free()

func tesla_render() -> void:
	var u = battle.spawn_unit("SHK","ally",POINT)
	u.order_stop()
	u.fire_stance = "none"
	u.hold_position = true
	battle.clear_selection()
	battle.camera.position = POINT
	battle.camera.zoom = Iso.cam_zoom(2.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for step in 600:
		u._physics_process(1.0/60.0)
		if u.idle_pose.frame >= 0: break
	check(u.idle_pose.frame >= 0 and not u.selected and u.position == POINT, "unselected Tesla trooper naturally starts idle without moving")
	if DisplayServer.get_name() != "headless":
		var first := await draw_frame(u)
		check(first == u.idle_pose.frame, "renderer draws first native idle frame")
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("tesla-idle-first.png"))
		var center: Vector2 = u.get_global_transform_with_canvas().origin
		var region := Rect2i(Vector2i(center) - Vector2i(64,96), Vector2i(128,128))
		var rendered := {}
		for i in 15:
			var current := await draw_frame(u)
			rendered[current] = true
			var pixels := get_viewport().get_texture().get_image().get_region(region)
			pixels.save_png(output_dir.path_join("tesla-%02d.png" % i))
			for j in 10:
				u._physics_process(1.0/60.0)
				if u.idle_pose.frame != current: break
		check(rendered.size() == 15, "unselected renderer displays all 15 native idle frames without input")
	u.order_move(POINT+Vector2(200,0))
	u.idle_pose.tick(u,0.02)
	check(u.idle_pose.frame < 0, "move order interrupts idle before translation")
	u.order_stop()
	for step in 150: u.idle_pose.tick(u,0.1)
	u._fire_anim_time = 0
	u.idle_pose.tick(u,0.1)
	check(u.idle_pose.frame < 0,"gunfire has priority")
	for id in ["E1","GGI","JUMPJET"]:
		var other = battle.spawn_unit(id,"ally", POINT+Vector2(100,100))
		if id == "JUMPJET": other.logistics.air_lift = 1
		else: other.set_deployed(true)
		for i in 200: other.idle_pose.tick(other,0.1)
		check(other.idle_pose.frame < 0, id + " no standing idle while deployed or flying")
	var spy = battle.spawn_unit("SPY","ally",POINT)
	spy.special.disguise = "CLEG"
	for i in 100:
		spy.idle_pose.tick(spy,0.1)
		if spy.idle_pose.frame >= 0: break
	var look := AlliedAbilities.disguise_visual(spy)
	check(spy.idle_pose.appearance == "CLEG" and look.frame == spy.idle_pose.frame and look.frame >= 8 and look.frame < 38, "spy uses copied infantry artwork and its own native offsets")
	if DisplayServer.get_name() != "headless":
		for id in ["DLPH","SQD"]:
			var swimmer = battle.spawn_unit(id,"ally",POINT)
			swimmer.order_stop()
			swimmer.fire_stance = "none"
			swimmer.hold_position = true
			var frames_per_pose := 32 if id == "DLPH" else 16 # 60 simulation frames at YR IdleRate 8 / 4
			var per := int(swimmer._seq.Walk.per)
			var fac: int = swimmer._sprite_facing(swimmer._ra2, swimmer.hull_angle)
			# Sample inside a frame rather than on a floating-point tick boundary.
			for tick in 4: swimmer._physics_process(1.0/60.0)
			var valid := true
			for phase in range(0, per + 2):
				var shown := await draw_frame(swimmer)
				var sample := int(swimmer._anim * 60.0 / frames_per_pose)
				valid = valid and shown == RA2Art.seq_frame(swimmer._seq, "Walk", fac, sample)
				for tick in frames_per_pose: swimmer._physics_process(1.0/60.0)
			check(valid and not swimmer._moving(), id + " renderer wraps a full native swim cycle at its own idle rate")
			battle.units.erase(swimmer)
			swimmer.free()
		for id in ["SHK","E1"]: await draw_repeated_clips(id)

func draw_repeated_clips(id: String) -> void:
	var actor = battle.spawn_unit(id,"ally",POINT)
	actor.order_stop()
	actor.fire_stance = "none"
	var names: Array[String] = []
	var prior := ""
	var draws_match := true
	for tick in 1200:
		actor._physics_process(1.0/30.0)
		var current: String = actor.idle_pose.clip
		if not current.is_empty() and current != prior:
			names.append(current)
			draws_match = draws_match and await draw_frame(actor) == actor.idle_pose.frame
			if names.size() == 4: break
		prior = current
	check(draws_match and names.size() == 4 and names[0] != names[1] and names[0] == names[2] and names[1] == names[3],
		id + " renderer revisits both idle animations without reselection", names)
	battle.units.erase(actor)
	actor.free()
