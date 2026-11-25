extends "res://tests/selection_regression.gd"

const Indicator = preload("res://scripts/ui/healing_indicator.gd")
const Cooldown = preload("res://scripts/ui/attack_cooldown_indicator.gd")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000, "fog_of_war": true})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen); battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear(); battle.buildings.clear()
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	battle.water_rects.clear(); battle.path_service.set_water([]); battle._refresh_pathing()
	GM.infinite_funds = false; GM.god_mode = false
	var prefix := mode + ": "
	var u = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	u.order_stop(); u.process_mode = Node.PROCESS_MODE_DISABLED
	u.selected = true; u._cd_timer = 1.0
	battle.camera.position = u.position
	battle.camera.reset_smoothing()
	check(Indicator.alpha(u) == 0.0, prefix + "idle and selected units have no healing badge")
	u.heal(10)
	check(Indicator.alpha(u) == 0.0, prefix + "full health does not falsely announce healing")
	u.hp -= 100
	u.heal(0)
	check(Indicator.alpha(u) == 0.0, prefix + "zero healing has no badge")
	var before: float = u.hp
	u.heal(8)
	check(u.hp == before + 8 and Indicator.alpha(u) > 0.0, prefix + "actual healing preserves amount and emits badge")
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		Iso.apply_to(battle.camera, zoom); battle.camera.force_update_scroll()
		battle.fog.rebuild(); battle.hp_overlay.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center := Indicator.screen_center(u, battle.hp_overlay)
		check(center.distance_to(Cooldown.screen_center(u, battle.hp_overlay)) >= 17.0, prefix + "badge stays separate from attack ring at zoom " + str(zoom))
		var picture := stage.get_texture().get_image()
		var crop := picture.get_region(Rect2i(Vector2i(center) - Vector2i(8, 8), Vector2i(16, 16)))
		var green := 0
		for y in 16:
			for x in 16:
				var c := crop.get_pixel(x, y)
				if c.g > 0.8 and c.r < 0.6 and c.b < 0.65: green += 1
		check(green >= 50, prefix + "real green plus remains screen sized at zoom " + str(zoom), green)
		if zoom == 2.0: picture.save_png(output_dir.path_join(mode + "-healing.png"))
	u.selected = false
	check(Indicator.alpha(u) > 0.0, prefix + "healing remains visible without selection")
	battle.paused = true; Indicator.tick(u, 2.0)
	check(Indicator.alpha(u) > 0.0, prefix + "pause freezes visual duration")
	battle.paused = false; Indicator.tick(u, 1.0)
	check(Indicator.alpha(u) > 0.0 and Indicator.alpha(u) < 1.0, prefix + "completed healing fades")
	Indicator.tick(u, 0.2)
	check(Indicator.alpha(u) == 0.0, prefix + "badge disappears after healing ends")
	u.heal(1); u.hide(); Indicator.tick(u, 0.01); u.show()
	check(Indicator.alpha(u) == 0.0, prefix + "hidden unit does not replay stale healing")
	u.heal(1); u.embarked_in = u; Indicator.tick(u, 0.01); u.embarked_in = null
	check(Indicator.alpha(u) == 0.0, prefix + "embarked unit clears badge")
	var enemy = battle.spawn_unit("MTNK", "ally", Vector2(300, 300))
	AlliedAbilities.change_side(enemy, "enemy"); enemy.order_stop(); enemy.hp -= 20
	battle.fog.rebuild(); enemy.heal(5)
	check(not battle.actor_visible_to("ally", enemy) and Indicator.alpha(enemy) == 0.0 and not enemy.has_meta(Indicator.PULSE), prefix + "unseen enemy healing cannot leak through fog")
	var depot = battle._place_building("GADEPT", "ally", Vector2(1900, 1900), true)
	depot._buildup_play = -1.0
	battle.power_low = false
	u.position = RepairDock.pad(depot); u.hp = u.max_hp - 16
	check(u.order_repair(depot), prefix + "real depot repair order accepted")
	battle.funds = 0; depot._process_repair(1.0)
	check(u.hp == u.max_hp - 16 and Indicator.alpha(u) == 0.0, prefix + "unfunded repair has no false healing badge")
	battle.funds = 1000; depot._process_repair(1.0)
	check(u.hp == u.max_hp - 8 and Indicator.alpha(u) > 0.0, prefix + "paid depot repair uses actual heal feedback")
	check(is_equal_approx(battle.funds, 1000 - 8 * float(u.data.cost) * 0.15 / u.max_hp), prefix + "repair charge unchanged")
	Indicator.tick(u, 0.96); depot._process_repair(0.96)
	check(u.hp == u.max_hp and Indicator.alpha(u) > 0.0, prefix + "successive repair steps refresh feedback including final heal")
	Indicator.tick(u, 1.2)
	check(Indicator.alpha(u) == 0.0, prefix + "full repaired unit clears final pulse")
	for id in ["BORIS","TANY"]:
		var hero=battle.spawn_unit(id,"ally",Vector2(1200,1200))
		var max_health:float=hero.max_hp
		hero.hp-=8
		hero.attack_target=enemy
		hero._physics_process(0.95)
		check(hero.veteran_level==0 and hero.hp==max_health-8,prefix+id+" rookie waits for native self-heal interval")
		hero._physics_process(0.01)
		check(hero.hp==max_health-7 and Indicator.alpha(hero)>0,prefix+id+" rookie heals one HP without a kill or upgrade")
		hero._grant_veteran(2,false)
		hero.order_stop()
		hero.hp=hero.max_hp-4
		hero._physics_process(1.92)
		check(hero.hp==hero.max_hp-2,prefix+id+" elite does not stack two self-heals")
		hero._physics_process(4.8)
		check(hero.hp==hero.max_hp and not hero.special.has("hero_heal_elapsed"),prefix+id+" stops at full HP")
	var rookie=battle.spawn_unit("E1","ally",Vector2(1250,1250))
	rookie.hp-=9
	rookie._physics_process(1.92)
	check(rookie.hp==rookie.max_hp-9,prefix+" ordinary rookie receives no hero self-heal")
	screen.free(); Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	await get_tree().process_frame
	OS.delay_msec(150)
