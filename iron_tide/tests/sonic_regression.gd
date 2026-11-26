extends "res://tests/naval_regression.gd"

# Real actors and their receive_hit paths. Positions/radii are controlled so
# expected pulse counts below come from the fixture, not the implementation.
func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	GM.god_mode = false
	GM.one_shot_kill = false
	await shipyard_defense(mode)
	await gripping_contacts(mode)
	for side in ["ally", "enemy"]:
		for dt in [1.0 / 15.0, 1.0 / 60.0, 1.0 / 144.0, 2.0]:
			await corridor(mode, side, dt, false)
		await corridor(mode, side, 1.0 / 60.0, true)
		await changing_targets(mode, side)
		await collateral_and_kills(mode, side)
	if DisplayServer.get_name() != "headless":
		await capture_wave(mode)
		await check_wave_pixels(mode)
	screen.free()
	await get_tree().process_frame

func gripping_contacts(mode:String) -> void:
	var point:=Vector2(1800,1600)
	var allied_squid=actor("SQD","ally",point)
	var enemy_ship=actor("DEST","enemy",point)
	allied_squid._fire_shot(enemy_ship)
	var center:Vector2=battle.get_viewport().get_canvas_transform()*enemy_ship.art_center()
	battle._apply_selection(point,false,Rect2(center-Vector2(36,36),Vector2(72,72)))
	check(battle.selected_units.has(allied_squid) and allied_squid.embarked_in==enemy_ship,mode+" box selects own squid while its grip continues")
	battle.stop_selected()
	check(allied_squid.embarked_in==null and not enemy_ship.special.has("squid"),mode+" selected squid can disengage")
	remove_actor(allied_squid);remove_actor(enemy_ship)
	var dolphin=actor("DLPH","ally",point-Vector2(120,0))
	var ship=actor("DEST","ally",point)
	var squid=actor("SQD","enemy",point)
	squid._fire_shot(ship)
	dolphin.hull_angle=0;dolphin.turret_angle=0
	battle.select_unit(dolphin,false)
	battle._issue_order(ship.art_center())
	check(dolphin.attack_target==squid and dolphin._weapon_target_valid(squid),mode+" right click on held friendly ship orders attack on squid")
	dolphin.attack_ordered=false;dolphin.attack_target=null
	dolphin._refresh_target()
	check(dolphin.attack_target==squid,mode+" dolphin autonomously acquires attacking squid")
	var before:float=squid.hp
	if dolphin._try_fire_ready():
		var wave=dolphin._pick_projectile_parent().get_child(-1)
		finish_wave(wave,1.0/60)
		wave.free()
	check(squid.hp<before and squid.embarked_in==null and not ship.special.has("squid"),mode+" real sonic hit damages squid and frees host")
	remove_actor(squid);remove_actor(ship)
	var sub=actor("SUB","enemy",point)
	sub.special.erase("dive_remaining")
	dolphin._cd_timer=0;dolphin.order_stop();dolphin.hull_angle=0
	battle.force_attack(sub)
	before=sub.hp
	if dolphin._try_fire_ready():
		var wave=dolphin._pick_projectile_parent().get_child(-1)
		finish_wave(wave,1.0/60)
		wave.free()
	check(sub.hp<before,mode+" dolphin detects, targets and damages submerged Typhoon")
	remove_actor(sub);remove_actor(dolphin)
	await get_tree().process_frame

func fire_wave(source, aim):
	var holder: Node = source._pick_projectile_parent()
	var before := holder.get_children()
	source._fire_shot(aim)
	var shots := new_shots(holder, before)
	check(shots.size() == 1, "real dolphin fire creates one wave")
	return shots[0] if not shots.is_empty() else null

func fixture_actor(id: String, side: String):
	var u = actor(id, side, Vector2(1800, 1600))
	u.hp = 10000.0
	u.max_hp = 10000.0
	u.radius = 0.0
	return u

func place(u, wave, along: float, across: float = 0.0) -> void:
	u.global_position = wave.global_position + wave._heading * along + wave._heading.orthogonal() * across

func finish_wave(wave, dt: float) -> void:
	for i in 400:
		if wave.is_queued_for_deletion():
			break
		wave._physics_process(dt)

func corridor(mode: String, side: String, dt: float, elite: bool) -> void:
	var label := "%s %s dt=%s elite=%s: " % [mode, side, dt, elite]
	var other := "enemy" if side == "ally" else "ally"
	var source = fixture_actor("DLPH", side)
	source.position = Vector2(1600, 1600)
	if elite:
		source._grant_veteran(2, false)
		source.bonuses = {} # Isolate ElitePrimary's AmbientDamage from FIREPOWER.
	var source_hp: float = source.hp
	var aim = fixture_actor("DEST", other)
	var wave = fire_wave(source, aim)
	if wave == null:
		remove_actor(source)
		remove_actor(aim)
		return
	var start: Vector2 = wave.position
	var heading: Vector2 = wave._heading
	var actors := [aim]
	var cases := [
		["DEST", other, 82.5, 0.0, 16, "near"],
		["DEST", other, 247.5, 0.0, 6, "behind original target"],
		["DEST", other, 165.0, 50.0, 0, "outside wave"],
		["DEST", other, 380.0, 0.0, 0, "beyond range"],
		["DEST", other, -40.0, 0.0, 0, "behind shooter"],
		["DEST", side, 82.5, 0.0, 16, "friendly collateral"],
		["DLPH", side, 82.5, 0.0, 0, "friendly same type immune"],
		["DLPH", other, 82.5, 0.0, 16, "enemy same type vulnerable"],
		["ORCA", other, 82.5, 0.0, 0, "airborne excluded"],
		["MTNK", other, 82.5, 0.0, 16, "ground collateral"],
		["DEST", other, 82.5, 14.0, 16, "wave edge"],
		["DEST", other, 82.5, 14.1, 0, "outside edge"],
		["DEST", other, 82.5, 0.0, 0, "stowed excluded"],
		["ORCA", other, 82.5, 0.0, 16, "landed collateral"]]
	place(aim, wave, 165.0)
	for item in cases:
		var u = fixture_actor(item[0], item[1])
		# Explicit heavy armor gives independent 80% expectation for each case.
		u.ra2_armor = "heavy"
		place(u, wave, item[2], item[3])
		if item[5] == "stowed excluded":
			u.set_stowed(source)
		elif item[5] == "landed collateral":
			u.logistics.air_lift = 0.0
		actors.append(u)
	aim.ra2_armor = "heavy"
	finish_wave(wave, dt)
	var per_pulse := 12.0 if elite else 8.0 # 15 or 10 AmbientDamage * 80%.
	check(aim.hp == 10000.0 - 11.0 * per_pulse, label + "aim uses ambient only, no extra impact damage", aim.hp)
	for i in cases.size():
		check(actors[i + 1].hp == 10000.0 - float(cases[i][4]) * per_pulse,
			label + cases[i][5], actors[i + 1].hp)
	check(source.hp == source_hp, label + "shooter immune", source.hp)
	check(wave.is_queued_for_deletion(), label + "wave is released after its trailing edge reaches the target")
	check(wave.position.distance_to(start + heading * 330.0) < 0.01, label + "range clamps to six cells")
	var hp_before: float = aim.hp
	wave._physics_process(2.0)
	check(aim.hp == hp_before, label + "finished wave cannot damage again")
	wave.free()
	for u in actors:
		remove_actor(u)
	remove_actor(source)
	await get_tree().process_frame

func changing_targets(mode: String, side: String) -> void:
	var other := "enemy" if side == "ally" else "ally"
	var source = fixture_actor("DLPH", side)
	source.position = Vector2(1600, 1600)
	source.bonuses = {"attack_bonus": 1.5}
	var aim = fixture_actor("DEST", other)
	var wave = fire_wave(source, aim)
	if wave == null:
		remove_actor(source)
		remove_actor(aim)
		return
	var origin: Vector2 = wave.position
	var heading: Vector2 = wave._heading
	source.bonuses["attack_bonus"] = 9.0 # In-flight offense is a launch snapshot.
	var mover = fixture_actor("DEST", other)
	mover.ra2_armor = "heavy"
	mover.bonuses = {"defense_bonus": 2.0}
	place(mover, wave, 82.5)
	for i in 10:
		wave._physics_process(1.0 / 15.0)
	check(mover.hp == 10000.0 - 6.0 * 6.0, mode + side + ": offense/armor/defense apply once per pulse", mover.hp)
	mover.position += heading.orthogonal() * 100.0
	var survivor = fixture_actor("DEST", other)
	survivor.ra2_armor = "heavy"
	survivor.position = origin + heading * 247.5
	# Removing both aim and shooter must not bend, cancel or invalidate the wave.
	remove_actor(aim)
	remove_actor(source)
	finish_wave(wave, 1.0 / 60.0)
	check(mover.hp == 9964.0, mode + side + ": leaving corridor stops damage")
	check(survivor.hp == 10000.0 - 6.0 * 12.0, mode + side + ": wave survives shooter and aim removal", survivor.hp)
	wave.free()
	remove_actor(mover)
	remove_actor(survivor)
	await get_tree().process_frame

func collateral_and_kills(mode: String, side: String) -> void:
	var label := mode + side + ": "
	var other := "enemy" if side == "ally" else "ally"
	var source = fixture_actor("DLPH", side)
	source.position = Vector2(1600, 1600)
	source._vet_need = 100000.0
	var aim = fixture_actor("DEST", other)
	var friendly = fixture_actor("DEST", side)
	var hostile = fixture_actor("DEST", other)
	var hull = fixture_actor("DEST", other)
	var b = battle._place_building("GAPOWR", other, Vector2(1800, 1600), true)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.bonuses = {}
	b.ra2_armor = "wood"
	b.radius = 0.0
	b.hp = 10000.0
	b.max_hp = 10000.0
	var wave = fire_wave(source, aim)
	if wave == null:
		for u in [source, aim, friendly, hostile, hull]:
			remove_actor(u)
		battle.buildings.erase(b)
		b.free()
		return
	place(aim, wave, 165.0, 100.0)
	place(friendly, wave, 82.5)
	place(hostile, wave, 82.5)
	place(hull, wave, 82.5, 33.0)
	hull.radius = 20.0 # Center misses; hull edge intersects the 14 px corridor.
	hull.ra2_armor = "heavy"
	place(b, wave, 82.5)
	friendly.hp = 1.0
	hostile.hp = 1.0
	var kill_value: float = hostile._vet_value
	# Even an accidentally duplicated combat-group registration hits once/tick.
	b.add_to_group("enemy_targets" if side == "ally" else "ally_targets")
	finish_wave(wave, 1.0 / 60.0)
	check(friendly.hp == 0.0 and hostile.hp == 0.0, label + "collateral and hostile kills settle")
	check(source._vet_kills == kill_value, label + "only hostile kill grants experience, once", source._vet_kills)
	check(b.hp == 9840.0, label + "building gets wood armor damage once per pulse", b.hp)
	check(hull.hp < 10000.0, label + "hull intersection counts even with center outside")
	wave.free()
	for u in [friendly, hostile, hull]:
		remove_actor(u)
	battle.buildings.erase(b)
	b.free()
	# Optional data guard and zero ambient damage use the same production path.
	var raw: Dictionary = GameData.ra2_weapons["soniczap"]
	var old_ambient = raw["ambient_damage"]
	var wh_extra: Dictionary = GameData.ra2_warheads["sonicwarhead"]["extra"]
	var had_allies: bool = wh_extra.has("AffectsAllies")
	var old_allies = wh_extra.get("AffectsAllies")
	wh_extra["AffectsAllies"] = "no"
	GameData.rebuild_static_combat_rules()
	friendly = fixture_actor("DEST", side)
	for ambient in [10.0, 0.0]:
		raw["ambient_damage"] = ambient
		aim.position = source.position + Vector2(200, 0)
		aim.hp = 10000.0
		aim.ra2_armor = "heavy"
		wave = fire_wave(source, aim)
		if wave == null:
			continue
		place(aim, wave, 82.5)
		place(friendly, wave, 82.5)
		finish_wave(wave, 2.0)
		check(friendly.hp == 10000.0, label + "AffectsAllies=no protects other friendly types")
		check(aim.hp == (9872.0 if ambient > 0.0 else 10000.0),
			label + "ambient value is used without fallback to Damage", aim.hp)
		wave.free()
	raw["ambient_damage"] = old_ambient
	if had_allies:
		wh_extra["AffectsAllies"] = old_allies
	else:
		wh_extra.erase("AffectsAllies")
	GameData.rebuild_static_combat_rules()
	for u in [source, aim, friendly]:
		remove_actor(u)
	await get_tree().process_frame

func capture_wave(mode: String) -> void:
	for effect in battle.effects_root.get_children():
		effect.free()
	var sea:Rect2=battle.water_rects[0]
	for rect:Rect2 in battle.water_rects:
		if rect.get_area()>sea.get_area():sea=rect
	var mid:=sea.position+sea.size*Vector2(0.5,0.35)
	var axis:=Vector2.RIGHT if sea.size.x>=sea.size.y else Vector2.DOWN
	battle.camera.position = mid
	battle.camera.zoom = Iso.cam_zoom(2.5)
	battle.camera.rotation = Iso.cam_angle()
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var source = actor("DLPH", "ally", mid-axis*130)
	check(not NavalContact.submerged(source),mode+" newly spawned dolphin starts at surface")
	NavalContact.tick(source,NavalContact.dive_delay())
	check(NavalContact.submerged(source) and NavalContact.dive_fraction(source)==1,mode+" idle dolphin dives")
	var aim = actor("DEST", "enemy", mid+axis*130)
	source.hull_angle = source.position.angle_to_point(aim.position)
	var wave = fire_wave(source, aim)
	if wave != null:
		check(NavalContact.submerged(source) and is_equal_approx(wave.splinters.sonic_mouth_depth,NavalContact.DIVE_DEPTH_PIXELS),mode+" SonicZap fires from underwater without surfacing")
		wave._physics_process(16.0 / 15.0)
		wave.queue_redraw()
		source.queue_redraw()
		aim.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var bounds:=Rect2i(Vector2i(source.get_global_transform_with_canvas().origin),Vector2i.ONE)
		bounds=bounds.expand(Vector2i(aim.get_global_transform_with_canvas().origin)).grow(110)
		var img:Image=stage.get_texture().get_image()
		var result := img.get_region(bounds.intersection(Rect2i(Vector2i.ZERO,img.get_size()))).save_png(output_dir.path_join(mode + "-sonic-corridor.png"))
		check(result == OK, mode + ": rendered corridor capture")
		wave.free()
		check(int(RA2Art.fx("WAKE1").get("count",0))==15,mode+" original fifteen-frame waterline wake loaded")
		source.order_stop()
		source.set_fire_stance("none")
		source._fire_anim_time=-1.0
		source._muzzle=0.0
		source.receive_hit(5.0)
		check(not NavalContact.submerged(source),mode+" damaging hit reveals the dolphin")
		var capture:=mode==MatchRules.EXTENDED and OS.get_environment("IRON_TIDE_CAPTURE_BREACH")=="1"
		for step in 31:
			if step>0:source._physics_process(1.0/20.0)
			if capture or step in [0,5,10,16,24]:
				await draw_frame(source)
				var depth:=NavalContact.dive_fraction(source)
				check(is_equal_approx(source._art_lift,-NavalContact.DIVE_DEPTH_PIXELS*depth) and not source._shadow_draw_rect.has_area(),mode+" waterline and hull follow depth at step "+str(step))
				if capture:
					var center:=Vector2i(source.get_global_transform_with_canvas().origin)
					stage.get_texture().get_image().get_region(Rect2i(center-Vector2i(88,74),Vector2i(176,136))).save_png(output_dir.path_join("breach-%02d.png"%step))
			if step==5:check(is_equal_approx(NavalContact.dive_fraction(source),0.5),mode+" dolphin rises halfway through the surface transition")
		check(NavalContact.submerged(source),mode+" dolphin dives again after contact ends")
	remove_actor(source)
	remove_actor(aim)

# Real Compatibility renderer and real projectile draw on two known backgrounds.
func check_wave_pixels(mode: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(viewport.size)
	viewport.add_child(backdrop)
	var field := Node2D.new()
	field.transform = Transform2D(Iso.eff_angle(), Iso.up(), 0, Vector2.ZERO).affine_inverse()
	field.position = Vector2(20, 32)
	viewport.add_child(field)
	var shot := preload("res://scripts/units/projectile.gd").new()
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	field.add_child(shot)
	shot.is_sonic = true
	shot._sonic_origin = shot.global_position
	shot.target_point = shot._sonic_origin + Vector2.from_angle(Iso.eff_angle()) * 200.0
	shot._sonic_elapsed = 10.0 / 15.0
	for base: Color in [Color("#524d42"), Color("#294d84")]:
		backdrop.color = base
		await draw_frame(shot)
		var frame := viewport.get_texture().get_image()
		var sample := frame.get_pixel(120, 29)
		check(absf(sample.r-base.r) < 0.025 and sample.g > base.g+0.08 and sample.b > base.b+0.06,
			mode+" native sonic leaves red intact and brightens background green/blue", sample)
		check(frame.get_pixel(60, 29) == frame.get_pixel(180, 29) and absf(frame.get_pixel(60, 29).g-base.g)<0.01,
			mode+" pixels before and after the travelling band keep the backdrop")
	viewport.free()

func shipyard_defense(mode: String) -> void:
	var sea:Rect2=battle.water_rects[0]
	for rect:Rect2 in battle.water_rects:
		if rect.get_area()>sea.get_area():sea=rect
	var at:=sea.get_center()
	var axis:=Vector2.RIGHT if sea.size.x>=sea.size.y else Vector2.DOWN
	var yard=battle._place_building("NAYARD","ally",at-axis*160,true)
	var coil=battle._place_building("TESLA","ally",at-axis*210,true)
	var dolphin=actor("DLPH","enemy",at)
	dolphin.special.erase("dive_remaining")
	dolphin.hull_angle=dolphin.position.angle_to_point(yard.position)
	dolphin.attack_target=yard
	dolphin.attack_ordered=true
	var sub=actor("SUB","ally",at+axis*430)
	if battle.fog!=null:battle.fog.rebuild()
	var wave=fire_wave(dolphin,yard)
	var yard_hp:float=yard.hp
	if wave!=null:
		finish_wave(wave,1.5)
		wave.free()
	check(yard.hp<yard_hp and NavalContact.submerged(dolphin),mode+" sonar wave damages the yard without surfacing")
	check(not battle.actor_visible_to("ally",dolphin),mode+" shipyard under fire does not expose the dolphin beyond Typhoon sonar")
	sub.position=at+axis*220
	sub.hull_angle=sub.position.angle_to_point(at)
	sub.turret_angle=sub.hull_angle
	battle.camera.position=at
	battle.camera.force_update_scroll()
	if battle.fog!=null:battle.fog.rebuild()
	await draw_frame(dolphin)
	battle.select_unit(sub,false)
	var contact=battle._pick_enemy_at(dolphin.art_center())
	check(battle.actor_visible_to("ally",dolphin) and contact==dolphin,mode+" Typhoon sonar gives a clickable enemy dolphin")
	check(not coil._valid_weapon_target(dolphin),mode+" shore coil lacks an underwater weapon even with shared sonar")
	battle.force_attack(contact)
	var holder:Node=sub._pick_projectile_parent()
	var before:=holder.get_children()
	var hp:float=dolphin.hp
	check(sub.attack_target==dolphin and sub._try_fire_ready(),mode+" explicit Typhoon attack launches against the raiding dolphin")
	for torpedo in new_shots(holder,before):
		for tick in 300:
			if torpedo.is_queued_for_deletion():break
			torpedo._physics_process(1.0/60.0)
		torpedo.free()
	check(dolphin.hp<hp,mode+" Typhoon torpedo hits the attacking dolphin")
	remove_actor(sub)
	remove_actor(dolphin)
	for building in [coil,yard]:
		battle.buildings.erase(building)
		building.free()
