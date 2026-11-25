extends "res://tests/selection_regression.gd"

const UNITS := ["ENGINEER", "JUMPJET", "CLEG", "SPY", "CCOMAND", "TANY",
	"AMCV", "CARRIER", "AEGIS", "LCRF", "SHAD", "DLPH", "SREF", "ORCA", "BEAG", "DEST", "CDEST", "HORNET"]
const INFANTRY := ["ENGINEER", "JUMPJET", "CLEG", "SPY", "CCOMAND", "TANY"]
const BUILDINGS := ["GAGAP", "GASAND", "GAWALL"]

func rendered() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func check_sheet(art: Dictionary, label: String) -> void:
	var texture: Texture2D = art.get("tex")
	check(texture != null, label + " texture imports")
	if texture == null:
		return
	var image := texture.get_image()
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	var count: int = int(art.get("facings", 8)) * int(art.get("poses", 1)) if art.kind == "vxl" else int(art.count)
	var valid := image != null and count > 0
	for frame in range(count):
		var rect := RA2Art.src_rect(art, frame)
		valid = valid and rect.has_area() and bounds.encloses(rect)
	check(valid, label + " every frame lies inside texture", count)

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(1, 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var actors: Array = []
	for id in UNITS:
		var unit = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		actors.append(unit)
		var label := mode + " " + str(id)
		check_sheet(unit._ra2, label)
		if str(unit._ra2.get("kind", "")) == "vxl":
			check_sheet(unit._ra2_shd, label + " shadow")
			check(RA2Art.frame_size(unit._ra2_shd) == RA2Art.frame_size(unit._ra2),
				label + " shadow shares body canvas")
		if id == "SREF":
			check_sheet(unit._ra2_tur, label + " turret")
			check(RA2Art.frame_size(unit._ra2_tur) == RA2Art.frame_size(unit._ra2),
				label + " turret shares body canvas")
		if id in INFANTRY:
			for action in ["Guard", "Walk", "FireUp", "Die1"]:
				var segment: Dictionary = unit._seq.get(action, {})
				var start := int(segment.get("start", -1))
				var frames := int(segment.get("per", 0)) * int(segment.get("facings", 1))
				check(start >= 0 and frames > 0 and start + frames <= int(unit._ra2.get("count", 0)) / 2,
					label + " " + action + " sequence uses visible frames")
	await rendered()
	# Put all units in a visible grid using the actual rendered anchor.
	for i in range(actors.size()):
		place_art_at(actors[i], Vector2(460 + (i % 5) * 150, 210 + (i / 5) * 150))
	for direction in range(8):
		for unit in actors:
			unit.hull_angle = float(direction) * TAU / 8.0
			unit.turret_angle = unit.hull_angle + PI / 2.0
			unit.queue_redraw()
		await rendered()
		if DisplayServer.get_name() != "headless":
			stage.get_texture().get_image().save_png(output_dir.path_join("%s-facing-%d.png" % [mode, direction]))
		for unit in actors:
			var label: String = mode + " " + unit.unit_id + " direction " + str(direction)
			check(unit._art_frame >= 0, label + " uses real draw path")
			check(has_pickable_pixel(unit), label + " visible body can be picked")
	for unit in actors:
		if unit.unit_id not in ["SHAD", "ORCA", "BEAG", "HORNET"]:
			continue
		unit.logistics.air_lift = 1.0
		unit._anim = 0.0
		unit.queue_redraw()
		await rendered()
		var ground: Rect2 = unit._shadow_draw_rect
		var first_frame: int = unit._art_frame
		if unit.unit_id == "SHAD":
			for pose in 2:
				unit._anim = float(pose) / 20.0 + 0.001
				unit.queue_redraw()
				await rendered()
				check(unit._art_frame / 32 == pose, mode + " SHAD original HVA rotor pose " + str(pose))
				check(unit._shadow_draw_rect.is_equal_approx(ground), mode + " SHAD stable canvas across rotor poses", [ground, unit._shadow_draw_rect])
				check(has_pickable_pixel(unit), mode + " SHAD animated rotor/body remains selectable")
		unit.logistics.air_lift = 0.0
		unit.queue_redraw()
		await rendered()
		# Subtracting then restoring the animated lift can round at float precision.
		check(unit._shadow_draw_rect.is_equal_approx(ground) and is_zero_approx(unit._art_lift),
			mode + " " + unit.unit_id + " landing moves aircraft but preserves ground shadow", [ground, unit._shadow_draw_rect, unit._art_lift])
		if unit.unit_id == "SHAD":
			check(unit._art_frame == first_frame, mode + " SHAD rotors stop when landed")
		unit.logistics.air_lift = 1.0
	# Drive the real renderer's animation state, not a replacement frame selector.
	for unit in actors:
		if unit.unit_id not in INFANTRY:
			continue
		var actions := ["Walk", "FireUp", "Die1"]
		if unit.unit_id == "JUMPJET": actions = ["Walk", "FireUp", "Fly", "FireFly", "Die1"]
		for action in actions:
			if unit.unit_id == "JUMPJET":
				unit.logistics.air_lift = 1.0 if action in ["Fly", "FireFly"] else 0.0
			unit.velocity = Vector2(20, 0) if action in ["Walk", "Fly"] else Vector2.ZERO
			unit._muzzle = 1.0 if action in ["FireUp", "FireFly"] else 0.0
			unit._dying = 1.0 if action == "Die1" else 0.0
			unit._walk_phase = 0.5
			unit._anim = 0.3
			unit.queue_redraw()
			await rendered()
			var seg: Dictionary = unit._seq.get(action, {})
			var start := int(seg.get("start", -1))
			var count := int(seg.get("per", 0)) * int(seg.get("facings", 1))
			check(unit._art_frame >= start and unit._art_frame < start + count,
				mode + " " + str(unit.unit_id) + " renderer consumes " + action)
		unit._dying = 0.0
	for unit in actors:
		battle.units.erase(unit)
		unit.free()
	# Restoring Die1 enables the existing delayed visual cleanup. Combat removal
	# and death notifications must still happen immediately and exactly once.
	for id in INFANTRY:
		var victim = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
		victim.process_mode = Node.PROCESS_MODE_DISABLED
		var deaths := [0]
		var on_death := func(dead_unit):
			if dead_unit == victim:
				deaths[0] += 1
		Events.unit_died.connect(on_death)
		victim._die()
		victim._die()
		check(deaths[0] == 1 and victim._dead, mode + " " + str(id) + " death notifies exactly once")
		check(not victim.is_in_group("combatants") and not victim.is_in_group("ally_targets"),
			mode + " " + str(id) + " death immediately removes combat membership")
		check(victim._dying > 0.0 and not victim.is_queued_for_deletion(),
			mode + " " + str(id) + " corpse remains only for death animation")
		Events.unit_died.disconnect(on_death)
		# v0.5.8 preserves the full original Die1 sequence; the old fixed 0.7s
		# expectation truncated longer deaths. Verify both sides of that deadline.
		var native_duration := maxf(1.0, float(victim._seq.Die1.per)) / 13.0
		check(is_equal_approx(victim._dying, native_duration), mode + " " + str(id) + " uses complete original death sequence")
		victim._physics_process(maxf(0.0, native_duration - 0.01))
		check(not victim.is_queued_for_deletion(), mode + " " + str(id) + " final death frame is not truncated")
		victim._physics_process(0.02)
		await get_tree().process_frame
		check(not is_instance_valid(victim), mode + " " + str(id) + " corpse is reclaimed after animation")
	for id in BUILDINGS:
		var building = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		building.process_mode = Node.PROCESS_MODE_DISABLED
		building._buildup_play = -1.0
		check_sheet(building._ra2, mode + " " + str(id))
		check(building.footprint_poly() == Building.placement_poly(building.data),
			mode + " " + str(id) + " real art uses shared footprint")
		building.queue_redraw()
		await rendered()
		if DisplayServer.get_name() != "headless":
			stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-" + str(id) + ".png"))
		check(has_pickable_pixel(building), mode + " " + str(id) + " visible building can be picked")
		battle.buildings.erase(building)
		building.free()
	screen.free()
	await get_tree().process_frame

func has_pickable_pixel(actor) -> bool:
	var center: Vector2 = stage.get_canvas_transform() * actor.art_center()
	var inverse := stage.get_canvas_transform().affine_inverse()
	for x in range(-45, 46, 3):
		for y in range(-45, 46, 3):
			var world := inverse * (center + Vector2(x, y))
			if actor.hit_test(world) and battle._pick_at(world) == actor:
				return true
	return false
