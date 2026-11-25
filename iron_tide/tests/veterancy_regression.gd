extends "res://tests/selection_regression.gd"

const RankIndicator = preload("res://scripts/ui/veterancy_indicator.gd")

func shoot(source, target) -> void:
	var host = source._pick_projectile_parent()
	var old: Array = host.get_children()
	target.hp = 1.0
	source._fire_shot(target)
	for shot in host.get_children():
		if old.has(shot) or not shot is Projectile: continue
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(1.0 / 60.0)
	check(target.hp <= 0.0, "actual weapon hit kills fixture")

func soldier(id: String, side: String, at: Vector2):
	var actor = battle.spawn_unit(id, side, at)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.bonuses = {}
	return actor

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	var prefix := mode + ": "
	var source = soldier("MTNK", "ally", Vector2(1600, 1600))
	var victim = soldier("MTNK", "enemy", Vector2(1700, 1600))
	var value: float = victim._vet_value
	await shoot(source, victim)
	check(source._vet_kills == value, prefix + "ordinary projectile credits shooter")
	var xp: float = source._vet_kills
	var building = battle._place_building("GAPOWR", "enemy", Vector2(1700, 1600), true)
	await shoot(source, building)
	check(source._vet_kills == xp + float(building.data.cost), prefix + "destroyed building credits its cost")
	xp = source._vet_kills
	building._die(source)
	victim._die(source)
	check(source._vet_kills == xp, prefix + "repeated death notification cannot credit twice")
	var friendly = soldier("MTNK", "ally", Vector2(1700, 1600))
	xp = source._vet_kills
	friendly.receive_hit(99999, "bullet", {}, source)
	check(source._vet_kills == xp and source.veteran_level == 0, prefix + "friendly direct kill gives no experience")
	battle.select_unit(source, false)
	battle._emit_selection()
	var hud = screen.hud
	var old_sig: String = hud._selection_signature()
	source._grant_veteran(1, false)
	check(hud._selection_signature() != old_sig, prefix + "rank changes invalidate selected unit stats")
	check(hud.get("sel_xp_label") != null, prefix + "selected unit has experience display")
	if source.has_method("veterancy_status"):
		await progression(mode)
	await rank_visuals(mode)
	screen.free()
	await get_tree().process_frame

func progression(mode: String) -> void:
	var prefix := mode + ": "
	var source = soldier("MTNK", "ally", Vector2(2100, 1600))
	var hud = screen.hud
	battle.select_unit(source, false)
	battle._emit_selection()
	var threshold: float = float(GameData.get_unit("MTNK").cost) * float(GameData.ra2_veteran_rules().ratio)
	check(source.veterancy_status().required == threshold and source.veteran_level == 0, prefix + "new unit threshold uses actual rules and own cost")
	check("Lv.1" in hud.sel_rank_label.text and "新兵" in hud.sel_rank_label.text, prefix + "new unit shows level and recruit rank")
	var label_id: int = hud.sel_xp_label.get_instance_id()
	for i in 6:
		var target = soldier("MTNK", "enemy", Vector2(2200, 1600))
		await shoot(source, target)
		hud._refresh_selection_live()
		if i == 0:
			check(hud.sel_xp_label.get_instance_id() == label_id and "700 / 2100" in hud.sel_xp_label.text,
				prefix + "experience updates without reselecting or rebuilding panel")
			check(is_equal_approx(hud.sel_xp_bar.value, 100.0 / 3.0), prefix + "experience bar matches real progress")
		hud._process(0.0)
		var expected := mini(2, (i + 1) / 3)
		check(source.veteran_level == expected, prefix + "real projectile kill " + str(i + 1) + " grants correct rank")
		check(hud.sel_rank_icon.visible == (expected > 0) and hud.sel_rank_icon.texture == HpBar.rank_texture(expected), prefix + "selected details consume original rank icon")
		check(int(hud._strip_icons[0].icon.veteran_rank) == expected, prefix + "roster badge tracks rank " + str(i + 1))
		if i in [0, 2, 5]:
			battle.camera.position = source.position
			battle.camera.force_update_scroll()
			source.queue_redraw()
			battle.hp_overlay.queue_redraw()
			for frame in 3: await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-rank-" + str(expected) + ".png"))
	check(source.veterancy_status().maxed and hud.sel_xp_bar.value == 100.0 and "最高军衔" in hud.sel_xp_label.text,
		prefix + "elite shows full capped experience instead of a nonexistent next level")
	check("Lv.3" in hud.sel_rank_label.text and "精英" in hud.sel_rank_label.text, prefix + "promotion title updates without reselecting")
	check(source._active_weapon() == source.data.elite_weapon and source.bonuses.has("veteran_attack"), prefix + "elite weapon and combat bonus are applied")
	var capped_xp: float = source._vet_kills
	source.credit_kill(999999)
	check(source._vet_kills == capped_xp and source.veteran_level == 2, prefix + "elite cannot overflow into extra ranks")
	var recruit = soldier("MTNK", "enemy", Vector2(2300, 1600))
	var prey = soldier("MTNK", "ally", Vector2(2400, 1600))
	await shoot(recruit, prey)
	check(recruit._vet_kills == 700.0, prefix + "opponent gets the same projectile experience")
	recruit.credit_kill(threshold - 700.0 + 125.0, "ally")
	check(recruit.veteran_level == 1 and recruit._vet_kills == 125.0, prefix + "promotion preserves excess experience")
	var miner = soldier("CMIN", "ally", Vector2(2100, 1800))
	miner.credit_kill(99999, "enemy")
	battle.select_unit(miner, false)
	battle._emit_selection()
	check(not miner.veterancy_status().enabled and miner.veteran_level == 0 and not hud.sel_xp_bar.visible,
		prefix + "nontrainable unit does not gain ranks or show misleading progress")
	var dead_source = soldier("MTNK", "ally", Vector2(2100, 2000))
	var delayed = Projectile.new()
	battle.projectiles_root.add_child(delayed)
	delayed.setup(dead_source.position, recruit, dead_source.weapon, 1.0, {}, "ally", dead_source)
	dead_source.hp = 0.0
	delayed.credit_kill(700, "enemy")
	check(dead_source._vet_kills == 0.0, prefix + "dead shooter cannot gain posthumous experience")
	dead_source.free()
	delayed.credit_kill(700, "enemy")
	check(delayed._credit_source.get_ref() == null, prefix + "projectile does not retain deleted shooter")
	delayed.free()

func rank_photo(unit, name: String) -> Image:
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := stage.get_texture().get_image()
	picture.save_png(output_dir.path_join(name + ".png"))
	var center: Vector2 = RankIndicator.screen_center(unit, battle.hp_overlay)
	# Keep the normal graded screenshot above; compare original pixels before
	# the existing world color-grading pass, which deliberately changes RGB.
	var grade = battle._post_layer
	var was_visible: bool = grade.visible
	grade.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var ungraded := stage.get_texture().get_image()
	grade.visible = was_visible
	return ungraded.get_region(Rect2i(Vector2i(center) - Vector2i(12, 9), Vector2i(24, 18)))

func native_rank_matches(picture: Image, rank: int) -> bool:
	var texture: Texture2D = load("res://assets/ra2/pips/" + ("veteran.png" if rank == 1 else "elite.png"))
	var native := texture.get_image()
	var center := Vector2i(12, 9) - Vector2i(native.get_width() / 2, native.get_height() / 2)
	# Crop origin truncates the projected center; odd-sized sprites floor it separately.
	# Allow that one-pixel rounding while checking every opaque original pixel.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var matched := 0
			var wrong := 0
			for y in native.get_height():
				for x in native.get_width():
					var expected := native.get_pixel(x,y)
					if expected.a < 0.9: continue
					var actual := picture.get_pixel(x + center.x + dx,y + center.y + dy)
					if absf(actual.r - expected.r) > 0.08 or absf(actual.g - expected.g) > 0.08 or absf(actual.b - expected.b) > 0.08: wrong += 1
					matched += 1
			if wrong == 0 and matched > 10: return true
	return false

func rank_visuals(mode: String) -> void:
	var label := mode + " rank visual: "
	var unit = soldier("MTNK", "ally", Vector2(2100, 2400))
	battle.selected_units.clear()
	unit.selected = false
	unit.set_fire_stance("none")
	battle.camera.position = unit.position
	Iso.apply_to(battle.camera, 1.0)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	check(RankIndicator.state(unit).is_empty(), label + "recruit has no false rank badge")
	unit.credit_kill(unit._vet_need, "enemy")
	check(unit.veteran_level == 1 and RankIndicator.state(unit).flash == 1.0,
		label + "actual experience promotion triggers flash on full-health unselected veteran")
	unit._physics_process(0.5)
	check(RankIndicator.state(unit).flash < 1.0 and RankIndicator.state(unit).flash > 0.0,
		label + "real physics countdown advances promotion flash")
	if DisplayServer.get_name() != "headless": await rank_photo(unit, mode + "-promotion")
	unit._physics_process(1.0)
	check(not unit.has_meta(RankIndicator.PROMOTION) and RankIndicator.state(unit).rank == 1,
		label + "flash expires while permanent badge remains")
	var veteran_image: Image
	if DisplayServer.get_name() != "headless":
		veteran_image = await rank_photo(unit, mode + "-veteran-unselected")
		check(native_rank_matches(veteran_image, 1), label + "unselected veteran renders original PIPS 14 pixels")
	unit.credit_kill(unit._vet_need, "enemy")
	check(RankIndicator.state(unit).rank == 2 and RankIndicator.state(unit).flash == 1.0,
		label + "elite promotion retriggers once at the real rank threshold")
	unit._physics_process(1.3)
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		Iso.apply_to(battle.camera, zoom)
		battle.camera.force_update_scroll()
		if DisplayServer.get_name() != "headless":
			var pixels := await rank_photo(unit, mode + "-elite-zoom-" + str(zoom))
			check(native_rank_matches(pixels, 2), label + "elite renders original PIPS 15 pixels at zoom " + str(zoom))
	var before: Array = [unit.hp, unit._vet_kills, unit.bonuses.duplicate(true), unit._active_weapon().duplicate(true)]
	for i in 20: RankIndicator.state(unit)
	check(before == [unit.hp, unit._vet_kills, unit.bonuses, unit._active_weapon()], label + "visual reads never change stats or weapon")
	unit.hide()
	check(RankIndicator.state(unit).is_empty(), label + "hidden unit has no badge")
	unit.show()
	unit.embarked_in = battle
	check(RankIndicator.state(unit).is_empty(), label + "cargo has no floating badge")
	unit.embarked_in = null
	unit.hp = 0
	check(RankIndicator.state(unit).is_empty(), label + "dead unit has no badge")
	unit.hp = unit.max_hp
	var plane = soldier("ORCA", "ally", unit.position)
	plane._grant_veteran(2, false)
	check(RankIndicator.state(plane).rank == 2 and RankIndicator.state(plane).flash == 0.0,
		label + "silent restored rank has badge without replaying promotion")
	Iso.apply_to(battle.camera, 1.0)
	battle.camera.force_update_scroll()
	plane.logistics.air_lift = 0.0
	var ground: Vector2 = RankIndicator.screen_center(plane, battle.hp_overlay)
	plane.logistics.air_lift = 1.0
	var air: Vector2 = RankIndicator.screen_center(plane, battle.hp_overlay)
	check(is_equal_approx(ground.y - air.y, plane._visual_lift()) and is_equal_approx(ground.x, air.x),
		label + "aircraft badge follows actual flight height")
	var enemy = soldier("MTNK", "enemy", Vector2(3000, 3000))
	battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog)
	battle.fog.setup(battle)
	enemy._grant_veteran(1, true)
	check(not battle.actor_visible_to("ally", enemy) and RankIndicator.state(enemy).is_empty() and not enemy.has_meta(RankIndicator.PROMOTION),
		label + "fog blocks enemy promotion flash and rank intelligence")
