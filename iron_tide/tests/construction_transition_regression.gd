extends "res://tests/base_recovery_regression.gd"

const Transition = preload("res://scripts/world/construction_transition.gd")
const Repack = preload("res://scripts/world/construction_repack.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	Events.unit_died.connect(func(_unit): deaths += 1)
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		await transition_round_trip(mode)
	await transition_round_trip(MatchRules.RA2, "SMCV")
	for id in ["AMCV","SMCV"]: await site_skill(id)
	var report := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  "))
	report.close()
	print("CONSTRUCTION_TRANSITION checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func site_skill(id: String) -> void:
	start(MatchRules.EXTENDED)
	var mcv = battle.spawn_unit(id,"ally",Vector2(1200,1200))
	mcv.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var goal: Vector2 = battle.snap_build_pos(mcv.position+Vector2(180,0))
	battle.select_unit(mcv,false)
	battle._emit_selection()
	await get_tree().physics_frame
	var icon: Dictionary = UnitSkillLayout.info(mcv,2)
	check(icon.name=="选址展开" and not icon.icon.is_empty(),id+" E skill supplies native yard icon")
	check(battle.request_ability(UnitSkillLayout.index(mcv,2))==1 and battle.command_mode=="mcv_site",id+" E enters site picker")
	battle._issue_command_at(Vector2.ZERO)
	check(battle.command_mode=="mcv_site" and not mcv.has_move_order,id+" invalid foundation keeps picker active")
	battle._issue_command_at(goal)
	check(mcv.has_move_order and mcv.special.get("mcv_deploy_at")==goal and battle.command_mode.is_empty(),id+" valid click orders movement")
	mcv.order_stop()
	check(not mcv.special.has("mcv_deploy_at"),id+" stop cancels remote deployment")
	battle.request_ability(UnitSkillLayout.index(mcv,2))
	battle._issue_command_at(goal)
	for i in 1500:
		if not battle.actor_alive(mcv): break
		mcv._physics_process(1.0/60)
	var yard=battle.selected_building
	check(is_instance_valid(yard) and yard.position==goal,id+" moves and deploys on exact confirmed grid")
	if is_instance_valid(yard):
		yard._process(8)
		var fold=battle.hud.ability_box.get_node_or_null("RepackSkill")
		check(is_instance_valid(fold),id+" yard exposes pack skill when selected")
		if is_instance_valid(fold): fold.pressed.emit()
		check(not battle.selected_units.is_empty() and battle.selected_units[0].unit_id==id,id+" pack skill returns same faction MCV")
		if not battle.selected_units.is_empty():
			var returned=battle.selected_units[0]
			Transition.tick(returned,8)
			battle._window_focused=true
			battle._last_click_unit=null
			check(battle.pointer_deploy_target(returned.art_center())==returned and battle.command_cursor.resolve(returned.art_center())=="deploy",id+" hover on selected MCV offers in-place deployment")
			var ground_click: Vector2 = returned.art_center()
			battle._apply_selection(ground_click,false,Rect2(battle.get_canvas_transform()*ground_click,Vector2.ZERO))
			check(is_instance_valid(battle.selected_building) and battle.selected_building.position==goal,id+" selected-vehicle click deploys in place")
	await finish()

var tested_mcv := "AMCV"

func transition_round_trip(mode: String, id := "AMCV") -> void:
	tested_mcv = id
	start(mode)
	mode += "-" + id
	var origin := Vector2(1213, 1191)
	var mcv = battle.spawn_unit(id, "ally", origin)
	var vehicle_radius: float = mcv.radius
	mcv.hp = mcv.max_hp * 0.4
	battle.select_unit(mcv, false)
	battle._emit_selection()
	var funds: float = battle.funds
	var count: int = battle.buildings.size()
	var died := deaths
	var status: Dictionary = battle.construction_deploy_check(mcv)
	check(status.ok and status.position != origin, prefix + "off-grid fixture passes real placement check")
	check(mcv.deploy(), prefix + "real deploy consumes vehicle")
	var yard = battle.selected_building
	check(yard != null and battle.buildings.size() == count + 1, prefix + "exactly one completed yard receives selection")
	if yard == null:
		await finish()
		return
	check(yard.global_position == status.position and is_equal_approx(yard.hp / yard.max_hp, 0.4), prefix + "legal grid position and health retained")
	var duration := GameData.ra2_buildup_seconds()
	var art: Dictionary = yard._buildup_art
	check(not art.is_empty() and int(art.count) > 2, prefix + "native construction sequence available")
	var initial: Vector2 = Transition.deployment_shift(yard)
	var base := Vector2(-RA2Art.anchor(art, [int(art.count) - 1]).x,
		yard.radius * 0.35 - RA2Art.anchor(art, [int(art.count) - 1]).y)
	var expected := Iso.dir(origin - yard.global_position) + Vector2(0, vehicle_radius * 0.35)
	var actual := base + initial + RA2Art.anchor(art, [0])
	check(actual.distance_to(expected) < 0.001, prefix + "first make frame ground anchor equals original vehicle anchor", {"actual": str(actual), "expected": str(expected), "offset": str(initial)})
	check(not Repack.check(battle, yard).ok, prefix + "cannot reverse while still unfolding")
	await capture(mode + "-unfold-start", yard)
	yard._process(duration * 0.5)
	check(Transition.deployment_shift(yard).is_equal_approx(initial * 0.5), prefix + "midpoint smoothly settles halfway to grid")
	await capture(mode + "-unfold-middle", yard)
	var yard_position: Vector2 = yard.global_position
	var midpoint: float = yard._buildup_play
	restore_disk()
	yard = find_yard(yard_position)
	check(yard != null and is_equal_approx(yard._buildup_play, midpoint) and Transition.deployment_shift(yard).is_equal_approx(initial * 0.5), prefix + "disk load retains unfolding frame and visual offset")
	yard._process(duration)
	check(yard._buildup_play < 0.0 and Transition.deployment_shift(yard) == Vector2.ZERO, prefix + "completed yard has no lingering render offset")
	await capture(mode + "-unfold-finish", yard)
	battle.select_building(yard)
	battle._emit_selection()
	check(Repack.execute(battle, yard), prefix + "real repack starts reversed make sequence")
	mcv = battle.selected_units[0]
	check(Transition.active(mcv) and Transition.repack_frame(mcv) == int(art.count) - 1, prefix + "fold begins at final native frame")
	check(mcv.global_position == yard_position and is_equal_approx(mcv.hp / mcv.max_hp, 0.4), prefix + "fold retains ground position and health")
	var visual: Dictionary = Transition.repack_visual(mcv)
	check(visual.base.is_equal_approx(base), prefix + "fold first frame shares completed building anchor")
	check(not battle.construction_deploy_check(mcv).ok and not mcv.deploy(), prefix + "repeated D cannot overlap conversion")
	await capture(mode + "-fold-start", mcv)
	var target := yard_position + Vector2(300, 0)
	mcv.order_move(target)
	battle.paused = true
	mcv._physics_process(duration * 0.25)
	check(float(mcv.special.mcv_repack_left) == duration, prefix + "paused fold cannot advance")
	battle.paused = false
	mcv._physics_process(duration * 0.5)
	check(mcv.global_position == yard_position and mcv.velocity == Vector2.ZERO and mcv.has_move_order and mcv.move_target == target, prefix + "move order waits without sliding during fold")
	check(Transition.repack_frame(mcv) > 0 and Transition.repack_frame(mcv) < int(art.count) - 1, prefix + "reverse sequence reaches intermediate frame")
	await capture(mode + "-fold-middle", mcv)
	var remaining: float = mcv.special.mcv_repack_left
	restore_disk()
	mcv = find_mcv()
	check(mcv != null and is_equal_approx(mcv.special.mcv_repack_left, remaining) and mcv.has_move_order and mcv.move_target == target, prefix + "disk load retains fold progress and queued movement")
	mcv._physics_process(remaining - duration * 0.001)
	visual = Transition.repack_visual(mcv)
	check(Transition.repack_frame(mcv) == 0, prefix + "reverse reaches native vehicle frame before completion")
	check((visual.base + RA2Art.anchor(art, [0])).distance_to(Vector2(0, vehicle_radius * 0.35)) < 0.01, prefix + "last fold frame aligns with vehicle ground anchor")
	await capture(mode + "-fold-last-frame", mcv)
	mcv._physics_process(duration)
	check(not Transition.active(mcv) and Transition.repack_visual(mcv).is_empty(), prefix + "completed fold restores normal vehicle renderer")
	check(mcv.has_move_order and mcv.move_target == target, prefix + "completion keeps queued destination")
	check(battle.construction_deploy_check(mcv).ok, prefix + "redeploy unlocked after fold completion")
	check(battle.funds == funds and deaths == died, prefix + "round trip creates no refund, charge or death")
	await capture(mode + "-fold-finish", mcv)
	mcv.process_mode = Node.PROCESS_MODE_ALWAYS
	mcv.set_process(false)
	mcv.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for tick in 30: mcv._physics_process(1.0 / 60.0)
	check(mcv.global_position.distance_to(yard_position) > 0.1, prefix + "queued movement actually resumes after fold")
	var legacy = battle.spawn_unit("AMCV", "ally", Vector2(1800, 1800))
	check(not Transition.active(legacy) and Transition.repack_visual(legacy).is_empty(), prefix + "ordinary and legacy vehicles require no transition metadata")
	await finish()

func restore_disk() -> void:
	var saved: Dictionary = BattleSaves.save_slot(battle, "slot1")
	check(saved.ok, prefix + "intermediate state writes through real save slot")
	var loaded: Dictionary = BattleSaves.read_slot("slot1")
	check(loaded.ok, prefix + "intermediate disk save validates")
	if not loaded.ok: return
	Snapshot.new().restore(battle, loaded.snapshot)
	check(battle.paused and get_tree().paused, prefix + "restore respects paused scene entry")
	get_tree().paused = false
	battle.paused = false

func find_yard(pos: Vector2):
	for actor in battle.buildings:
		if actor.is_hq and actor.global_position == pos: return actor
	return null

func find_mcv():
	for actor in battle.units:
		if actor.unit_id == tested_mcv: return actor
	return null

func capture(label: String, actor) -> void:
	actor.queue_redraw()
	battle.camera.position = actor.global_position
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	if battle.fog != null: battle.fog.rebuild()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	# Validate actual visible pixels rather than the empty center of a frame.
	var found := false
	for dx in range(-140, 141, 10):
		for dy in range(-180, 61, 10):
			var point: Vector2 = actor.global_position + RA2Art.art_dir(Vector2(dx, dy))
			if actor.hit_test(point): found = true
	check(found, prefix + label + " animated actor remains selectable")
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
