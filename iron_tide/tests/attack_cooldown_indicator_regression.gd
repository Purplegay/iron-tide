extends "res://tests/selection_regression.gd"

const Indicator = preload("res://scripts/ui/attack_cooldown_indicator.gd")

func capture_ring(unit, name: String = "") -> Image:
	if DisplayServer.get_name()=="headless":return null
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := stage.get_texture().get_image()
	if not name.is_empty(): picture.save_png(output_dir.path_join(name + ".png"))
	var center: Vector2 = Indicator.screen_center(unit, battle.hp_overlay)
	return picture.get_region(Rect2i(Vector2i(center) - Vector2i(10, 10), Vector2i(20, 20)))

func colored_pixels(picture: Image, expected: Color) -> int:
	var count := 0
	for y in picture.get_height():
		for x in picture.get_width():
			var c := picture.get_pixel(x, y)
			if maxf(absf(c.r-expected.r),maxf(absf(c.g-expected.g),absf(c.b-expected.b)))<0.18:count+=1
	return count

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	var prefix := mode + ": "
	var u = battle.spawn_unit("MTNK", "ally", Vector2(1600, 1600))
	var target = battle.spawn_unit("MTNK", "enemy", Vector2(1720, 1600))
	battle.camera.position = u.global_position
	Iso.apply_to(battle.camera, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	u.bonuses = {}
	u.order_stop()
	u.attack_target = target
	u.turret_angle = 0.0
	u.hull_angle = 0.0
	u.aim_dir = Vector2.RIGHT
	check(Indicator.state(u).is_empty(), prefix + "idle unselected unit has no clutter")
	u.selected = true
	check(Indicator.state(u).left == 0.0, prefix + "selected ready unit shows zero cooldown")
	check(u._try_fire_ready(), prefix + "real attack starts timer")
	var total: float = u._cd_timer
	check(total > 0.0 and is_equal_approx(Indicator.state(u).fraction, 1.0), prefix + "actual shot starts full cooldown ring")
	var full := await capture_ring(u, mode + "-full")
	u.attack_target = null
	u._think_timer = 1000.0
	u.process_mode = Node.PROCESS_MODE_ALWAYS
	u.set_process(false)
	u.set_physics_process(false)
	u._physics_process(total * 0.5)
	check(is_equal_approx(Indicator.state(u).fraction, 0.5), prefix + "real physics countdown produces half ring")
	var half := await capture_ring(u, mode + "-half")
	if full!=null:check(colored_pixels(full, Indicator.state(u).color) > colored_pixels(half, Indicator.state(u).color) + 15 and colored_pixels(half, Indicator.state(u).color) > 15, prefix + "rendered arc shrinks visibly")
	var left: float = u._cd_timer
	await capture_ring(u)
	check(u._cd_timer == left, prefix + "redrawing frozen world does not advance combat")
	u.selected = false
	check(not Indicator.state(u).is_empty(), prefix + "active cooldown remains visible without selection")
	u._physics_process(total)
	check(Indicator.state(u).is_empty(), prefix + "unselected finished cooldown hides automatically")
	u.selected = true
	var ready := await capture_ring(u, mode + "-ready")
	if ready!=null:check(colored_pixels(ready, Indicator.state(u).color) > 25, prefix + "selected ready ring uses its weapon color")
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		Iso.apply_to(battle.camera, zoom)
		battle.camera.force_update_scroll()
		var picture := await capture_ring(u)
		if picture!=null:check(colored_pixels(picture, Indicator.state(u).color) > 25, prefix + "screen sized circle stays readable at zoom " + str(zoom))
	var timer_before: float = u._cd_timer
	var hp_before: float = target.hp
	for i in 20: Indicator.state(u)
	check(u._cd_timer == timer_before and target.hp == hp_before, prefix + "indicator queries cannot alter timer or damage")
	u.bonuses["veteran_rof"] = 0.6
	u.buffs = [{"kind": "cooldown", "value": 0.25, "left": 5.0}]
	u._cd_timer = CombatMath.veteran_cooldown(u.cooldown, u.bonuses) * 0.75 * 0.5
	check(is_equal_approx(Indicator.state(u).fraction, 0.5), prefix + "veteran and cooldown buff modifiers match actual firing formula")
	u.embarked_in = target
	check(Indicator.state(u).is_empty(), prefix + "embarked unit never leaks a ring")
	u.embarked_in = null
	u.hp = 0.0
	check(Indicator.state(u).is_empty(), prefix + "dead unit hides ring")
	u.hp = u.max_hp
	u.hide()
	check(Indicator.state(u).is_empty(), prefix + "hidden unit hides ring")
	target.selected = true
	target._cd_timer = 1.0
	check(Indicator.state(target).is_empty(), prefix + "enemy cooldown not exposed")
	var miner = battle.spawn_unit("CMIN", "ally", Vector2(1800, 1600))
	miner.selected = true
	check(Indicator.state(miner).is_empty(), prefix + "unarmed miner has no attack ring")
	exercise_domain_slots()
	await exercise_building(mode)
	screen.free()
	await get_tree().process_frame

func exercise_building(mode: String) -> void:
	var prefix := mode + " building: "
	battle.power_low = false
	var b = battle._place_building("GTGCAN", "ally", Vector2(2100, 2100), true)
	b._buildup_play = -1.0
	b._think = 1000.0
	var target = battle.spawn_unit("MTNK", "enemy", b.position + Vector2(400, 0))
	b.attack_target = target
	b._turret_art.angle = 0.0
	battle.camera.position = b.position
	Iso.apply_to(battle.camera, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	check(Indicator.state(b).is_empty(), prefix + "idle unselected defense hides ring")
	b.selected = true
	check(Indicator.state(b).left == 0.0, prefix + "selected operational defense ready")
	b._process(0.01)
	check(b._cd > 0.0 and is_equal_approx(Indicator.state(b).fraction, 1.0), prefix + "real defense shot starts full ring")
	var full := await capture_ring(b, mode + "-building-full")
	b.attack_target = null
	var duration: float = b.cooldown
	b._process(duration * 0.5)
	check(is_equal_approx(Indicator.state(b).fraction, 0.5), prefix + "real building countdown reaches half")
	var half := await capture_ring(b, mode + "-building-half")
	if full!=null:check(colored_pixels(full, Indicator.state(b).color) > colored_pixels(half, Indicator.state(b).color) + 15 and colored_pixels(half, Indicator.state(b).color) > 15, prefix + "building arc visibly shrinks")
	var left: float = b._cd
	battle.power_low = true
	b._process(duration)
	check(b._cd == left and is_equal_approx(Indicator.state(b).fraction, 0.5), prefix + "power loss freezes displayed cooldown with real timer")
	battle.power_low = false
	b.selected = false
	check(not Indicator.state(b).is_empty(), prefix + "cooling defense visible without selection")
	b._process(duration)
	check(Indicator.state(b).is_empty(), prefix + "finished unselected defense hides ring")
	b.selected = true
	for zoom in [0.5, 1.0, 2.0, 4.0]:
		Iso.apply_to(battle.camera, zoom)
		battle.camera.force_update_scroll()
		var ready := await capture_ring(b, mode + "-building-ready" if zoom == 1.0 else "")
		if ready!=null:check(colored_pixels(ready, Indicator.state(b).color) > 25, prefix + "ready ring readable at zoom " + str(zoom))
	var hp: float = target.hp
	await capture_ring(b)
	check(b._cd == 0.0 and target.hp == hp, prefix + "rendering cannot advance combat")
	battle.power_low = true
	check(Indicator.state(b).is_empty(), prefix + "offline defense never advertises ready")
	battle.power_low = false
	b._prism_offline = 1.0
	check(Indicator.state(b).is_empty(), prefix + "support-disabled defense never advertises ready")
	b._prism_offline = 0.0
	b.under_construction = true
	check(Indicator.state(b).is_empty(), prefix + "unfinished defense hides ring")
	b.under_construction = false
	b.side = "enemy"
	check(Indicator.state(b).is_empty(), prefix + "enemy defense cooldown remains private")
	b.side = "ally"
	b.hide()
	check(Indicator.state(b).is_empty(), prefix + "hidden defense hides ring")
	b.show()
	b.hp = 0.0
	check(Indicator.state(b).is_empty(), prefix + "destroyed defense hides ring")
	var refinery = battle._place_building("GAREFN", "ally", Vector2(2300, 2100), true)
	refinery._buildup_play = -1.0
	refinery.selected = true
	check(Indicator.state(refinery).is_empty(), prefix + "unarmed building has no attack ring")

func exercise_domain_slots() -> void:
	var origin:=Vector2(1500,1600)
	var ground=battle.spawn_unit("MTNK","enemy",origin+Vector2(100,0))
	var air=battle.spawn_unit("JUMPJET","enemy",origin+Vector2(100,0))
	air.logistics.air_lift=1.0
	for id in ["APOC","FLAKT","HTK","HYD"]:
		var unit=battle.spawn_unit(id,"ally",origin)
		unit.set_selected(true);unit.attack_ordered=true;unit.hull_angle=0;unit.turret_angle=0
		unit.attack_target=air;unit._refresh_weapon_derived()
		if id!="APOC":
			var info:=Indicator.state(unit)
			check(info.has("left") and not info.has("mounts"),"single flak barrel retains one ring "+id)
			continue
		var ready:Array=Indicator.state(unit).mounts
		check(ready.size()==2 and ready[0].key=="ground" and ready[1].key=="air" and ready[0].color!=ready[1].color,"distinct ground and AA slots "+id)
		check(unit._try_fire_ready(),"AA attack starts shared reload "+id)
		var duration:float=unit._cd_timer
		unit._cd_timer=duration*0.5
		unit.attack_target=ground;unit._refresh_weapon_derived()
		var rings:Array=Indicator.state(unit).mounts
		check(is_equal_approx(rings[0].fraction,0.5) and rings[0].fraction==rings[1].fraction and rings[0].left==rings[1].left,"retargeting preserves both fractions and original AA interval "+id)
		check(not unit._try_fire_ready(),"switch to ground cannot bypass shared reload "+id)
		unit._cancel_burst();unit._cd_timer=0
		check(unit._try_fire_ready() and is_equal_approx(Indicator.state(unit).mounts[1].fraction,1.0),"ground volley also starts both circles "+id)
		unit.set_selected(false);unit._cd_timer=0
		check(Indicator.state(unit).is_empty(),"unselected ready unit hides both circles "+id)
