extends "res://tests/soviet_advanced_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode, {"country":"苏俄","enemy_base":"allied","opening":"prebuilt","map_size":3200,"starting_funds":16000,"fog_of_war":false})
		screen = load("res://scenes/battle.tscn").instantiate()
		var naval_view:=SubViewport.new()
		naval_view.size=Vector2i(1600,900)
		naval_view.world_2d=World2D.new()
		naval_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(naval_view)
		naval_view.add_child(screen)
		battle = screen.battle
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		for b in battle.buildings: b._process(10)
		var old := OS.get_environment("IRON_TIDE_PRE_NAVY_SAVE")
		if mode == MatchRules.RA2 and not old.is_empty():
			var previous := BattleSaves.read_path(old)
			check(previous.ok, "v0.13 Soviet save opens", previous.get("message",""))
			if previous.ok:
				BattleSaves.Snapshot.new().restore(battle,previous.snapshot)
				get_tree().paused = false
				battle.paused = false
				check(actor("SUB","ally") != null and actor("NAWEAP","ally") != null, "legacy scenario submarine and factory restored")
				await finish()
				start_soviet("苏俄","allied","prebuilt")
		if screen.get_viewport()!=naval_view:screen.reparent(naval_view)
		await run_naval(mode)
		await finish()
		naval_view.free()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	file.close()
	get_tree().quit(0 if failed == 0 else 1)

func run_naval(mode: String) -> void:
	# Give the normal placement entry a contiguous waterway alongside a real owned factory.
	var anchor = ready_building("NAWEAP", Vector2(1500,1000))
	ready_building("NAREFN", Vector2(1050,1100))
	battle.water_rects = [Rect2(1599,250,1350,2200)]
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()
	var bd := GameData.get_building("NAYARD")
	check(bd.water_bound and bd.foundation == "4x4" and bd.hp == 1500 and bd.cost == 1000, mode + " native yard rules")
	check(not battle.build_spot_ok(Vector2(1400,800),bd,true).ok, mode + " dry site rejected")
	battle.request_structure("NAYARD")
	battle._tick_structure_queue(180)
	var spot := placement("NAYARD", "ally")
	check(spot.is_finite() and battle.struct_ready.has("NAYARD"), mode + " waterside footprint and construction ready", [spot,battle.struct_ready])
	if not spot.is_finite() or not battle.struct_ready.has("NAYARD"): return
	battle.request_structure("NAYARD")
	battle._try_place_building(spot)
	var yard = actor("NAYARD","ally")
	check(yard != null, mode + " placed Soviet yard")
	if yard == null:return
	yard._process(8)
	battle.select_building(yard)
	battle._emit_selection()
	check(screen.hud.prod_tab == "naval", mode + " selecting yard focuses naval tab")
	check(yard.buildable.has("SUB") and yard.buildable.has("HYD") and screen.hud._unit_catalog().has("SUB"), mode + " naval deck includes both native ships")
	check(not anchor.can_queue("SUB") and not yard.enqueue("HYD") and yard.queue_block_reason("HYD").contains("雷达"), mode + " correct producer and radar requirement", yard.queue_block_reason("HYD"))
	for id in ["SUB","HYD"]:
		if id == "HYD": ready_building("NARADR",Vector2(1300,1250))
		var funds: float = battle.funds
		check(yard.enqueue(id), mode + " accepted " + id)
		yard._process(180)
		var ship = actor(id,"ally")
		check(ship != null and is_equal_approx(funds-battle.funds, GameData.get_unit(id).cost), mode + " produced and paid " + id, [ship != null, funds-battle.funds, yard.production, yard.position, yard.production_paid, preload("res://scripts/buildings/production_exit.gd").point(yard,id)])
		if ship == null: return
		check(battle.in_water_world(ship.position) and not preload("res://scripts/buildings/production_exit.gd").near_footprint(yard,ship.position,ship.radius), mode + " clear water exit " + id)
		check(ResourceLoader.exists(GameData.ra2_cameo_path(id)) and RA2Art.art(id).facings == 32 and RA2Art.art(id).has("detail_tex"), mode + " portrait and 32 facing 2x hull " + id)
		check(not GameData.ra2_sound_files(Ra2Sfx.voice_id(ship.data,"select")).is_empty(), mode + " speech " + id)
		ship.position = Vector2(2400,900 if id == "SUB" else 1150)
	var squid = battle.spawn_unit("SQD", "ally", Vector2(2700, 1600))
	check(NavalContact.submerged(squid) and NavalContact.dive_fraction(squid) == 1.0, mode + " squid swims submerged from spawn")
	var grip_rules = preload("res://scripts/units/soviet_specials.gd")
	var sheet := RA2Art.fx("SQDG_NE")
	check(grip_rules.grip_frame(0.0, sheet) == 0 and grip_rules.grip_frame(2.0, sheet) == 9 and grip_rules.grip_frame(9.7, sheet) == 20, mode + " native grip intro, loop and release frames")
	var pivot := RA2Art.frame_size(squid._ra2) * 0.5
	check(RA2Art.anchor(squid._ra2,[0]) == pivot and RA2Art.anchor(squid._ra2,[140]) == pivot, mode + " squid headings share swimming pivot")
	squid.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().physics_frame
	await check_swim_timing(squid,mode)
	squid.order_move(squid.position + Vector2(100, 0))
	squid._physics_process(1.0/30.0)
	check(squid.has_move_order and NavalContact.dive_fraction(squid) == 1.0 and not battle.actor_visible_to("enemy", squid), mode + " swimming squid remains submerged and undetected")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = squid.position
		battle.camera.zoom = Iso.cam_zoom(1.6)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		squid.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(squid._art_frame >= 0 and squid._art_frame < 160 and not squid._shadow_draw_rect.has_area(), mode + " native squid swim frame without surface shadow")
		var center := Vector2i(squid.get_global_transform_with_canvas().origin)
		screen.get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(120,100),Vector2i(240,200))).save_png(output_dir.path_join(mode+"-squid.png"))
		await check_naval_paint(squid,squid,"swim")
		var victim=battle.spawn_unit("DEST","enemy",squid.position)
		preload("res://scripts/units/soviet_specials.gd").shoot(squid,victim,squid.weapon)
		victim.special.grip_age = 1.4
		victim.visible=true
		await check_naval_paint(squid,victim,"grip")
		preload("res://scripts/units/soviet_specials.gd").release_squid(victim)
		battle.units.erase(victim)
		victim.free()
	battle.units.erase(squid)
	squid.free()
	var sub = actor("SUB","ally")
	var hyd = actor("HYD","ally")
	sub.order_stop()
	check(not NavalContact.submerged(sub) and battle.actor_visible_to("enemy",sub), mode + " newly launched Typhoon is surfaced")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = sub.position
		battle.camera.zoom = Iso.cam_zoom(2.0)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-on-surface.png"))
		await check_naval_paint(sub,sub,mode+"-sub-surface")
	sub._physics_process(0.95)
	check(NavalContact.dive_fraction(sub) > 0.0 and NavalContact.dive_fraction(sub) < 1.0, mode + " hull fades during dive")
	if DisplayServer.get_name() != "headless":await check_naval_paint(sub,sub,mode+"-sub-diving")
	sub._physics_process(0.25)
	check(NavalContact.submerged(sub) and sub.visible and not battle.actor_visible_to("enemy",sub), mode + " owner retains submerged contact after 1.2 seconds")
	if DisplayServer.get_name() != "headless":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(not sub._shadow_draw_rect.has_area(), mode + " submerged voxel has no surface shadow")
		screen.get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-submerged.png"))
		await check_naval_paint(sub,sub,mode+"-sub-underwater")
	sub.receive_hit(1.0)
	check(not NavalContact.submerged(sub) and battle.actor_visible_to("enemy",sub), mode + " damage surfaces living submarine")
	sub._physics_process(1.21)
	check(NavalContact.submerged(sub), mode + " idle survivor dives again")
	var enemy = battle.spawn_unit("AEGIS","enemy",sub.position + Vector2(95,0))
	var plane = battle.spawn_unit("JUMPJET","enemy",hyd.position + Vector2(80,0))
	plane.logistics.air_lift = 1
	check(not battle.actor_visible_to("enemy",sub) and not sub.attack_domain_valid(plane) and not sub.attack_domain_valid(anchor), mode + " stealth and target domains")
	battle.clear_selection()
	battle.select_unit(sub, false)
	battle.force_attack(enemy)
	sub.hull_angle = PI
	sub.turret_angle = 0.0
	check(not sub._try_fire_ready() and not sub._weapon_aligned(enemy), mode + " stern cannot launch using turret facing")
	sub.hull_angle = PI / 2.0
	check(not sub._try_fire_ready(), mode + " broadside cannot launch")
	for tick in 360:
		sub._physics_process(1.0 / 60.0)
		if sub._cd_timer > 0.0: break
	check(sub._cd_timer > 0.0 and sub.hull_angle > 0.0 and sub.hull_angle < PI / 4.0, mode + " hull turns into torpedo launch sector")
	check(not NavalContact.submerged(sub) and NavalContact.dive_fraction(sub) > 0.99 and battle.actor_visible_to("enemy",sub),mode + " first fired torpedo surfaces and reveals launcher")
	NavalContact.tick(sub, 0.25)
	check(is_equal_approx(NavalContact.dive_fraction(sub), 0.5), mode + " halfway through surfacing the hull is still partially underwater")
	NavalContact.tick(sub, 0.25)
	check(is_zero_approx(NavalContact.dive_fraction(sub)), mode + " rising hull reaches surface")
	NavalContact.tick(sub, 2.0)
	check(not NavalContact.submerged(sub),mode + " stays surfaced between shots on an in-range ship")
	if DisplayServer.get_name() != "headless":
		sub.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(sub._shadow_draw_rect.has_area(), mode + " firing submarine draws surfaced hull shadow")
	var shots = battle.projectiles_root.get_children().filter(func(p):return p is Projectile and p.target == enemy)
	check(not shots.is_empty() and shots[0].ra2_image == "SUBT" and RA2Art.art("SUBT").get("facings") == 32 and shots[0].Visual.kind(shots[0]) == "wake",mode + " native torpedo body")
	if not shots.is_empty():
		check(shots[0]._heading.is_equal_approx(Vector2.from_angle(sub.hull_angle)), mode + " torpedo starts along bow before tracking")
		var hp: float = enemy.hp
		for i in 180:
			shots[0]._physics_process(1.0/60.0)
			if shots[0]._detonated:break
		check(enemy.hp < hp and battle.actor_visible_to("enemy",sub), mode + " torpedo damages ship while launcher is exposed")
	sub.order_stop()
	NavalContact.tick(sub, 0.95)
	check(NavalContact.dive_fraction(sub)>0 and NavalContact.dive_fraction(sub)<1,mode+" stopping fire starts the visible dive")
	NavalContact.tick(sub, 0.26)
	check(NavalContact.submerged(sub) and not battle.actor_visible_to("enemy",sub),mode+" silent launcher is concealed again")
	battle.spawn_unit("DEST","enemy",sub.position + Vector2(300,0))
	check(battle.actor_visible_to("enemy",sub),mode + " destroyer detects submerged Typhoon")
	check(hyd._weapon_for_target(enemy).name == "FlakTrackGun" and hyd._weapon_for_target(plane).name == "FlakWeapon" and aim(hyd,plane),mode + " flak switches to AAA and fires")
	hyd._cd_timer = 0.0
	check(aim(hyd,enemy), mode + " surface gun fires at ship")
	var hd_shots = battle.projectiles_root.get_children().filter(func(p): return p is Projectile and p.target == enemy and p.ra2_warhead == "YR_SOV_FlakTWH")
	if not hd_shots.is_empty():
		var hull: float = enemy.hp
		for i in 150:
			hd_shots[0]._physics_process(1.0/60.0)
			if hd_shots[0]._detonated: break
		check(enemy.hp < hull, mode + " surface round damages ship")
	check(not hd_shots.is_empty(), mode + " distinct anti-surface projectile")
	hyd.hp -= 25
	# Freeze callbacks, not physics membership: disabled CollisionObject2D nodes otherwise leave the space.
	# Keep the full isolated scene collision set for the real repair-access motion query.
	for body in screen.find_children("*","CollisionObject2D",true,false):body.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	check(PhysicsServer2D.body_get_space(hyd.get_rid()).is_valid(),mode+" repair query retains isolated physics body membership")
	check(hyd.order_repair(yard) and hyd.special.repair_entry.is_finite() and battle.in_water_world(hyd.special.repair_entry), mode + " damaged ship gets water repair approach", [hyd.can_repair_at(yard), yard.dock_point(hyd.position), yard.is_repair_depot(), yard.is_operational(), yard.footprint_rect(),yard.position,hyd.is_naval])
	var ground = battle.spawn_unit("HTNK","ally",anchor.position + Vector2(0,150))
	ground.hp -= 15
	check(not ground.can_repair_at(yard), mode + " tanks cannot use naval repair berth")
	hyd.process_mode = Node.PROCESS_MODE_ALWAYS
	hyd.set_physics_process(false)
	await get_tree().physics_frame
	hyd.position = hyd.special.get("repair_entry",hyd.position)
	for i in 480:
		hyd._physics_process(1.0/60.0)
		if hyd.position.distance_to(RepairDock.pad(yard)) <= 6.0: break
	var damaged: float = hyd.hp
	var money: float = battle.funds
	yard._process(1.5)
	check(hyd.hp > damaged and battle.funds < money, mode + " ship enters pad and receives paid repair", [hyd.position,RepairDock.pad(yard),hyd.special.get("repair_stage"),yard._repair_active])
	yard._process(0.05)
	check(yard._layer_visible("specialanim") and not yard._layer_visible("specialanimtwo") and not yard._layer_visible("specialanimthree") and yard._layer_visible("activeanimtwo"), mode + " single repair-arm phase with active crane")
	hyd._grant_veteran(2,false)
	check(hyd._weapon_for_target(plane).name == "FlakWeaponE" and hyd._weapon_for_target(enemy).name == "FlakTrackGunE", mode + " elite flak guns")
	check(yard.enqueue("SUB") and BattleSaves.save_slot(battle,"slot1").ok, mode + " paid naval queue saves")
	var loaded := BattleSaves.read_slot("slot1")
	if loaded.ok:
		BattleSaves.Snapshot.new().restore(battle,loaded.snapshot)
		get_tree().paused = false
		battle.paused = false
	yard = actor("NAYARD","ally")
	check(loaded.ok and yard.production.has("SUB") and actor("HYD","ally").veteran_level == 2, mode + " ship rank and yard order restored")
	if DisplayServer.get_name() != "headless":
		battle.select_building(yard)
		battle._emit_selection()
		var featured_sub = actor("SUB","ally")
		var berth := ProductionExit.water_berth(yard, featured_sub.radius, Vector2.UP, false)
		if berth.is_finite(): featured_sub.position = berth
		battle.camera.position = yard.position
		battle.camera.zoom = Iso.cam_zoom(1.5)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode + "-naval-yard.png"))

func check_swim_timing(squid,mode:String) -> void:
	var origin:Vector2=squid.position
	squid.order_stop()
	squid.set_fire_stance("none")
	battle.camera.position=origin
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var initial:float=squid._walk_phase
	for speed in [0.0,45.0,120.0,0.0]:
		var before:float=squid._walk_phase
		for i in 60:
			squid.velocity=Vector2(speed,0)
			squid._physics_process(1.0/60)
		var frames:=fposmod(float(squid._walk_phase)-before,1.0)*int(squid._seq.Walk.per)
		check(absf(frames-(3.75 if speed==0 else 7.5))<0.001,mode+" tentacle cycle continues at native idle/swim rate at speed "+str(speed),frames)
		if DisplayServer.get_name()!="headless":
			squid.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var facing:int=squid._sprite_facing(squid._ra2,squid.hull_angle)
			var expected:=RA2Art.seq_frame(squid._seq,"Walk",facing,int(float(squid._walk_phase)*squid._seq.Walk.per))
			check(squid._art_frame==expected,mode+" rendered tentacles use the continuous swim frame",[squid._art_frame,expected])
	squid._walk_phase=initial
	squid.position=origin
	squid.order_stop()

func check_naval_paint(unit,carrier,label:String) -> void:
	var saved := HouseColor.player_hex
	var samples: Array[Image] = []
	var host_material = carrier.material
	for paint in ["#ff3828","#32ff50"]:
		HouseColor.player_hex=paint
		unit.refresh_house_color()
		carrier.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center := Vector2i(carrier.get_global_transform_with_canvas().origin)
		var crop:Image = screen.get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(115,110),Vector2i(230,220)))
		samples.append(crop)
		crop.save_png(output_dir.path_join(label+"-"+str(samples.size())+".png"))
	var changed := 0
	for y in samples[0].get_height():
		for x in samples[0].get_width():
			var a := samples[0].get_pixel(x,y)
			var b := samples[1].get_pixel(x,y)
			if a.r-b.r>0.08 and b.g-a.g>0.08 and a.r>maxf(a.g,a.b) and b.g>maxf(b.r,b.b): changed+=1
	# At this zoom the submerged Typhoon has a broad painted stripe; a few
	# surviving edge pixels must not count as a successful remap.
	var required:=200 if unit.unit_id=="SUB" else 12
	check(changed>required,"actual "+label+" pixels show owner colour",changed)
	if label=="grip":
		var grip = carrier.get_node("SquidGrip")
		var art := RA2Art.fx(preload("res://scripts/units/soviet_specials.gd").grip_image(carrier, unit))
		var bounds := RA2Art.visible_sprite_rect(art, Rect2(-art.cell * 0.5, art.cell), grip.region_rect)
		var projected: Rect2 = Transform2D(Iso.eff_angle(), Iso.up(), 0, Vector2.ZERO).affine_inverse() * grip.transform * bounds
		check(carrier._body_bounds.has_point(projected.get_center()), "gripping tentacles stay centered on visible hull")
		check(carrier.material==host_material and carrier.get_node("SquidGrip").material==HouseColor.material_for(unit._col,HouseColor.PaintMode.SQUID_GRIP),"grip uses attacker colour independently of ship")
	HouseColor.player_hex=saved
	unit.refresh_house_color()
