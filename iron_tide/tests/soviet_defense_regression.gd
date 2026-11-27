extends "res://tests/soviet_opening_regression.gd"
const Support = preload("res://scripts/units/tesla_support.gd")
const Garrison = preload("res://scripts/units/civilian_orders.gd")

func ready_building(id: String, point: Vector2):
	var b = battle._place_building(id,"ally",point,true)
	b._buildup_play = -1
	return b

func scene_checks() -> void:
	start_soviet("苏俄","allied","prebuilt")
	screen.hud.prod_tab = "defense"
	var deck: Array = screen.hud._building_catalog()
	for id in ["NAFLAK","TESLA","NABNKR","NAWALL"]:
		check(deck.has(id) and ResourceLoader.exists(GameData.ra2_cameo_path(id)) and RA2Art.has_art(id), "defense tab, portrait and model " + id)
	battle.request_structure("TESLA")
	check(battle.struct_queue.is_empty(), "coil locked without Soviet radar")
	ready_building("NARADR",Vector2(850,1250))
	var barracks = actor("NAHAND","ally")
	var money: float = battle.funds
	check(barracks.enqueue("SHK"), "Tesla trooper barracks training")
	barracks._process(120)
	var trooper = actor("SHK","ally")
	check(trooper != null and is_equal_approx(money-battle.funds,500), "paid trooper produced")
	for id in ["TESLA","NAFLAK","NABNKR","NAWALL"]:
		money = battle.funds
		battle.request_structure(id)
		battle._tick_structure_queue(120)
		var where := placement(id,"ally")
		check(battle.struct_ready.has(id) and where.is_finite() and is_equal_approx(money-battle.funds, GameData.get_building(id).cost), "paid ready " + id)
		if where.is_finite() and battle.struct_ready.has(id):
			battle.request_structure(id)
			battle._try_place_building(where)
			var placed = actor(id,"ally")
			check(placed != null,"real placement " + id)
			if placed != null: placed._buildup_play = -1
	var coil = actor("TESLA","ally")
	var flak = actor("NAFLAK","ally")
	var bunker = actor("NABNKR","ally")
	if coil == null or trooper == null or flak == null or bunker == null: return
	# Keep the integration fixtures away from opening traffic and shoot at stationary targets.
	for fixture in battle.buildings.duplicate():
		if fixture.side == "neutral" and fixture.position.distance_to(Vector2(1375,1400)) < 400:
			battle.buildings.erase(fixture)
			fixture.free()
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.position.distance_to(Vector2(1375,1400)) < 360: node.free()
	coil.position = Vector2(1400,1250)
	flak.position = Vector2(1150,1450)
	bunker.position = Vector2(1600,1450)
	battle._refresh_pathing()
	ready_building("NAPOWR", Vector2(1000,1200))
	battle._update_power()
	trooper.position = coil.position - Vector2(80,0)
	trooper.order_stop()
	trooper._refresh_target()
	check(trooper.special.get("target") == coil, "idle trooper finds nearby friendly coil")
	trooper.order_stop()
	check(AlliedAbilities.default_order(trooper,coil)=="tesla_charge" and AlliedAbilities.use(trooper,"tesla_charge",coil),"friendly context command")
	trooper._cd_timer = 0
	var coil_hp: float = coil.hp
	AlliedAbilities.tick_action(trooper,0.1)
	Support.update_weapon(coil)
	check(coil.weapon.damage == 300 and coil.attack_range == 440 and coil.hp == coil_hp,"one charge increases output and range without friendly damage")
	var ground = battle.spawn_unit("HTNK","enemy",coil.position + Vector2(416,0))
	ground.order_stop()
	var plane = battle.spawn_unit("JUMPJET","enemy",flak.position + Vector2(100,0))
	plane.logistics.air_lift = 1.0
	check(not coil._valid_weapon_target(plane) and flak._valid_weapon_target(plane) and not flak._valid_weapon_target(ground),"ground-only coil and air-only flak")
	check(flak._turret_art.origins.size()==32 and flak._turret_art.muzzles.size()==32,"32-facing flak muzzle and turret")
	flak.attack_target=plane
	flak._turret_art.turn_toward(plane.position-flak.position,120,flak._turret_turn_speed)
	var air_hp: float = plane.hp
	check(flak._fire() and plane.hp < air_hp,"flak airburst damages airborne infantry")
	battle.select_building(coil)
	battle._emit_selection()
	battle._issue_order(ground.art_center())
	check(coil.attack_target == ground and not battle.rally_for(coil).is_finite(),"right click orders charged coil at extended range")
	check(battle.command_cursor.can_attack(ground) and not battle.command_cursor.can_attack(plane),"coil cursor rejects airborne target")
	coil._think = 0
	coil._cd = 0
	var hp: float = ground.hp
	coil._process(0.01)
	coil._process(1.7)
	check(ground.hp==hp and coil.special.has("coil_windup"),"original 28-tick firing delay")
	coil._process(0.2)
	check(ground.hp < hp and not coil.special.has("coil_windup"),"charged shot at eight-cell reach")
	var bolts: Array = battle.effects_root.get_children().filter(func(fx): return fx is Effects.ElectricBolt)
	check(bolts.size() >= 2, "trooper charge and overcharged attack both emit YR bolts")
	if bolts.size() >= 2:
		var shot: Effects.ElectricBolt = bolts.back()
		var supply: Effects.ElectricBolt = bolts[bolts.size() - 2]
		check(supply.color == Color8(252,252,84) and supply.to == shot.from and shot.from == Support.tip(coil), "charge arrives and discharge starts on same electrode")
		check(shot.to == ground.art_center() and shot.color == Color8(252,252,84), "overcharged bolt hits target with alternate palette")
		if DisplayServer.get_name() != "headless":
			battle.camera.position = coil.position.lerp(ground.position, 0.5)
			battle.camera.zoom = Iso.cam_zoom(1.5)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("coil-overcharged.png"))
		var path := shot.strands[0].duplicate()
		shot._process(1.0 / 15.0)
		check(shot.strands.size() == 3 and path.size() == 9 and path != shot.strands[0] and shot.strands[0] != shot.strands[1], "three distinct eight-segment filaments change on the next game tick")
		check(shot.strands.all(func(s): return s[0] == shot.to_local(shot.from) and s[-1] == shot.to_local(shot.to)), "all endpoints remain attached")
		shot._process(16.0 / 15.0)
		check(shot.is_queued_for_deletion(), "bolt expires after 17 simulation frames")
	var post = battle._place_building("NAPOWR","enemy",coil.position + Vector2(-210,0),true)
	post._buildup_play = -1
	battle.force_attack(ground)
	coil._cd = 0
	coil._process(0.1)
	coil._process(1.4)
	screen.hud.cmd_buttons.attack.pressed.emit()
	check(battle.command_mode == "attack","coil attack button enters A targeting mode")
	battle._issue_command_at(post.art_center())
	var post_hp: float = post.hp
	coil._process(0.05)
	battle.force_attack(plane)
	coil._process(0.8)
	check(coil.attack_target == post and post.hp == post_hp and coil.special.has("coil_windup"),"new ground target keeps focus and starts fresh windup")
	battle.force_attack(post)
	coil._process(1.1)
	check(post.hp < post_hp and coil.attack_target == post,"repeated order preserves windup and discharges into designated building")
	battle.stop_selected()
	check(coil.attack_target == null and not coil.special.has("coil_ordered_target"),"S cancels coil focus")
	battle.force_attack(ground)
	ground.position += Vector2(500,0)
	coil._process(0.3)
	check(coil.attack_target != ground and not coil.special.has("coil_ordered_target"),"out-of-range focus releases to ordinary targeting")
	ground.position = coil.position + Vector2(416,0)
	var normal := GameData.ra2_beam_spec(coil.data.weapon.ra2_weapon_id)
	check(normal.kind == "yr_bolt" and normal.color == Color8(80,80,252), "normal coil uses palette index 10")
	battle.power_low=true
	check(not coil.is_operational() and not flak.is_operational(),"one charger insufficient in blackout")
	check(not battle.command_cursor.can_attack(post),"low power coil with one charger rejects order")
	var chargers := [trooper]
	for i in 2:
		var u = battle.spawn_unit("SHK","ally",coil.position + Vector2(0,75-150*i))
		chargers.append(u)
		AlliedAbilities.use(u,"tesla_charge",coil)
		u._cd_timer=0
		AlliedAbilities.tick_action(u,0.1)
		Support.update_weapon(coil)
		check(coil.is_operational() and coil.weapon.damage == (200 if i==0 else 300),"low power charge count " + str(i+2))
		check(battle.command_cursor.can_attack(post) and battle.command_cursor.can_attack(ground) == (i == 1),"low power ordered range matches two and three charger tiers")
	chargers[1].order_stop()
	Support.update_weapon(coil)
	check(coil.weapon.damage==200 and Support.count(coil)==2,"stop removes exactly one charger")
	battle.power_low=false
	var garrisoned := []
	for i in 5:
		var port := Vector2.from_angle(i * TAU/5.0)
		var u = battle.spawn_unit("E2","ally",bunker.position + port * (bunker.footprint_clearance(port) - 2.0))
		check(AlliedAbilities.use(u,"allied_garrison",bunker),"enter bunker " + str(i))
		AlliedAbilities.tick_action(u,0.05)
		garrisoned.append(u)
	check(bunker.special.get("occupants",[]).size()==5 and bunker._body_damage_frame()==2,"five occupants and fortified sprite")
	var sixth = battle.spawn_unit("E2","ally",bunker.position+Vector2(110,0))
	check(not Garrison.can_enter(sixth,bunker) and not Garrison.can_enter(trooper,bunker),"full bunker refuses extra infantry")
	ground.position = bunker.position + Vector2(90,0)
	ground.hp=ground.max_hp
	var occupant = garrisoned[0]
	if occupant.embarked_in != bunker:
		check(false,"garrison command completes")
		return
	check(Garrison.weapon(occupant).name=="UCM1Carbine", "occupant uses native conscript garrison weapon")
	occupant._cd_timer=0
	hp=ground.hp
	Garrison.tick(occupant,0.1)
	check(ground.hp < hp, "garrison shoots nearby ground enemy")
	var flashes: Array = battle.effects_root.get_children().filter(func(fx): return fx is Ra2Fx and fx.anim.image == "UCCONS")
	check(flashes.size() == 1 and flashes[0].position.is_equal_approx(occupant._weapon_muzzle()) and flashes[0].anim.count == 4, "conscript fires original four-frame window flash at its port")
	if not flashes.is_empty():
		flashes[0]._process(1.0 / 15.0)
		check(flashes[0].frame == 1, "window flash advances to next SHP frame")
		if DisplayServer.get_name() != "headless":
			battle.camera.position = bunker.position
			battle.camera.zoom = Iso.cam_zoom(2.0)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("bunker-firing.png"))
		flashes[0]._process(0.3)
		check(flashes[0].is_queued_for_deletion(), "window flash ends after its shot")
	var status: Dictionary = BattleSaves.save_slot(battle,"slot1")
	check(status.ok and BattleSaves.read_slot("slot1").ok,"snapshot encodes live chargers and garrison")
	battle.select_building(bunker)
	battle._emit_selection()
	var overlay = preload("res://scripts/world/attack_range_preview.gd")
	var rings: Array = overlay.ranges(battle)
	check(rings.size() == 1 and rings[0].active and rings[0].radius == 330 and rings[0].center == bunker.position, "occupied 2x2 bunker displays six-cell ground range")
	var priority = battle.spawn_unit("HTNK","enemy",bunker.position + Vector2(185,0))
	var near_hp: float = ground.hp
	battle._issue_order(priority.art_center())
	check(bunker.attack_target == priority and not battle.rally_for(bunker).is_finite(),"right click targets enemy instead of setting bunker rally")
	check(battle.command_cursor.attack_cursor(priority) == "attack" and battle.command_cursor.attack_cursor(plane) == "blocked","bunker cursor distinguishes attackable ground units")
	for gunner in garrisoned:
		gunner._cd_timer = 0
		Garrison.tick(gunner,0.1)
	check(priority.hp < priority.max_hp and ground.hp == near_hp,"garrison focuses designated enemy over nearer ground target")
	var enemy_post = battle._place_building("NAPOWR","enemy",bunker.position + Vector2(0,230),true)
	screen.hud.cmd_buttons.attack.pressed.emit()
	check(battle.command_mode == "attack","bunker attack button arms target selection")
	battle._issue_command_at(enemy_post.art_center())
	occupant._cd_timer = 0
	Garrison.tick(occupant,0.1)
	check(bunker.attack_target == enemy_post and enemy_post.hp < enemy_post.max_hp,"aimed command orders gunners to shoot enemy building")
	battle.force_attack(plane)
	check(bunker.attack_target == enemy_post,"invalid air command preserves existing focus")
	battle.stop_selected()
	check(bunker.attack_target == null,"stop cancels garrison focus")
	battle.force_attack(priority)
	priority.position += Vector2(600,0)
	occupant._cd_timer = 0
	Garrison.tick(occupant,0.1)
	check(bunker.attack_target == null and ground.hp < near_hp,"gunners resume normal fire when focus leaves range")
	var spy = battle.spawn_unit("SPY","enemy",bunker.position + Vector2(150,100))
	battle.force_attack(spy)
	spy.special.disguise = "E2"
	occupant._cd_timer = 0
	Garrison.tick(occupant,0.1)
	check(bunker.attack_target == null and spy.hp == spy.max_hp and not battle.command_cursor.can_attack(spy),"gunners lose concealed target")
	ground.position = bunker.position + Vector2(330, 0)
	occupant._cd_timer = 0
	hp = ground.hp
	Garrison.tick(occupant,0.1)
	check(ground.hp < hp, "enemy on displayed outer boundary is hit")
	ground.position.x += 1
	occupant._cd_timer = 0
	hp = ground.hp
	Garrison.tick(occupant,0.1)
	check(ground.hp == hp, "enemy one pixel beyond range is untouched")
	var leaving = garrisoned[2]
	screen.hud.select_prod_tab("defense")
	var card: Button = screen.hud._prod_buttons.get("NABNKR")
	check(card != null and card.find_children("*", "Label", true, false).any(func(label): return label.text.contains("5人")), "build card shows bunker capacity before selection")
	var indicators = preload("res://scripts/ui/garrison_indicator.gd")
	check(screen.hud.ability_title.text.begins_with("驻军 5 / 5") and indicators.preview(bunker) == Vector2i(5, 5), "full bunker shows count and five occupied map pips")
	var portrait: Button = screen.hud.ability_box.get_node_or_null("Occupant%d" % leaving.get_instance_id())
	check(portrait != null and portrait.icon != null and screen.hud.ability_box.get_child_count() == 5, "one clickable portrait per live occupant")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = bunker.position
		battle.camera.zoom = Iso.cam_zoom(1.0)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		battle.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("bunker-range-and-occupants.png"))
	# HUD layout can rebuild its controls during the render frame.
	portrait = screen.hud.ability_box.get_node_or_null("Occupant%d" % leaving.get_instance_id())
	if is_instance_valid(portrait): portrait.pressed.emit()
	check(bunker.special.occupants == [garrisoned[0],garrisoned[1],garrisoned[3],garrisoned[4]] and leaving.embarked_in == null and leaving.visible, "clicking third portrait releases exactly that soldier")
	check(screen.hud.ability_box.get_child_count() == 4 and battle.selected_building == bunker, "remaining four portraits stay on selected bunker")
	check(screen.hud.ability_title.text.begins_with("驻军 4 / 5") and indicators.preview(bunker) == Vector2i(4, 5), "single withdrawal updates counter and empty pip")
	Garrison.withdraw(bunker, leaving)
	check(bunker.special.occupants.size() == 4, "stale single exit cannot evacuate remaining garrison")
	battle.deploy_selected()
	rings = overlay.ranges(battle)
	check(rings.size() == 1 and not rings[0].active and rings[0].radius == 330, "empty bunker previews inactive ground range")
	check(bunker.special.occupants.is_empty() and bunker.side=="ally" and occupant.embarked_in==null,"D evacuates without changing bunker ownership")
	check(screen.hud.ability_panel.visible and screen.hud.ability_title.text.begins_with("驻军 0 / 5") and indicators.preview(bunker) == Vector2i(0, 5), "empty bunker keeps capacity visible")
	battle.clear_selection()
	bunker.set_hovered(true)
	check(indicators.preview(bunker) == Vector2i(0, 5), "hover exposes capacity without selecting bunker")
	bunker.set_hovered(false)
	check(indicators.preview(bunker) == Vector2i.ZERO, "map pips hide when leaving unselected bunker")
	check(not Garrison.can_enter(trooper,bunker),"non-occupier denied even with free slots")
	battle.force_attack(ground)
	check(bunker.attack_target == null and battle.command_cursor.attack_cursor(ground) == "blocked","empty bunker cannot accept attack orders")
	var gi = battle.spawn_unit("E1", "ally", bunker.position)
	Garrison.enter(gi, bunker)
	gi._grant_veteran(2, false)
	ground.position = bunker.position + Vector2(100, 0)
	gi._cd_timer = 0.0
	Garrison.tick(gi, 0.1)
	check(battle.effects_root.get_children().any(func(fx): return fx is Ra2Fx and fx.anim.image == "UCFLASH" and fx.position.is_equal_approx(gi._weapon_muzzle())), "elite GI fires its own UCFLASH from the bunker")
	Garrison.withdraw(bunker, gi)
	Garrison.enter(sixth,bunker)
	bunker.hp = bunker.max_hp*0.2
	Garrison.tick_building(bunker)
	check(sixth.embarked_in==null and bunker.side=="ally" and bunker._body_damage_frame()==1,"damaged bunker evacuates and retains house")
	# The east coast is water. Exercise wall placement on the inland plain.
	var first = ready_building("NAWALL",Vector2(800,2000))
	var second = ready_building("NAWALL",first.position+Vector2(40,0))
	var other = battle._place_building("NAWALL","enemy",first.position-Vector2(40,0),true)
	var mask := WallArt.mask_at(first.position,"NAWALL","ally",battle.buildings)
	check(WallArt.supported(first.data,first._ra2) and mask==1 and WallArt.connected_component(first,battle.buildings).size()==2 and other!=second,"wall joins same-owner Soviet segments")
	# Two more straight cells bridge to an existing endpoint and charge exactly their cost.
	ready_building("NAPOWR",first.position+Vector2(100,100))
	for group in ["resource_nodes","obstacles"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.position.distance_to(first.position+Vector2(100,0)) < 95: node.free()
	var endpoint = ready_building("NAWALL",second.position + Vector2(120,0))
	var preview := WallArt.plan(battle,"NAWALL","ally",endpoint.position)
	money = battle.funds
	var added := WallArt.bridge(battle,endpoint)
	check(preview.points.size()==2 and added==2 and money-battle.funds==200,"wall preview equals paid connection")
	if DisplayServer.get_name() != "headless":
		battle.camera.position=coil.position+Vector2(20,110)
		battle.camera.zoom=Iso.cam_zoom(1.3)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		screen.hud.select_prod_tab("defense")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("soviet-defenses.png"))

	# Restore the saved fortified bunker before the evacuation and compare object links.
	var reopened := BattleSaves.read_slot("slot1")
	if reopened.ok:
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle,reopened.snapshot)
		bunker = actor("NABNKR","ally")
		coil = actor("TESLA","ally")
		check(bunker.special.occupants.size()==5 and bunker.special.occupants.all(func(u):return u.embarked_in==bunker), "restore five live garrison references")
		check(Support.count(coil)==2 and coil.special.tesla_chargers.all(func(u):return u.special.target==coil), "restore live charge assignments")
	await finish()
	start_soviet("美国","soviet","prebuilt")
	var ai = battle.skirmish_ai
	var ai_coil = battle._place_building("TESLA","enemy",Vector2(1000,900),true)
	var ai_bunker = battle._place_building("NABNKR","enemy",Vector2(1400,900),true)
	for b in [ai_coil,ai_bunker]: b._buildup_play=-1
	var support = battle.spawn_unit("SHK","enemy",ai_coil.position+Vector2(90,0))
	var recruit = battle.spawn_unit("E2","enemy",ai_bunker.position+Vector2(90,0))
	support.order_stop()
	recruit.order_stop()
	for i in 2: preload("res://scripts/world/skirmish_operations.gd").staff_soviet_defense(ai)
	check(support.special.get("target")==ai_coil and recruit.special.get("target")==ai_bunker, "AI issues native charge and garrison orders")
	check(not preload("res://scripts/world/skirmish_tactics.gd").fighter(battle,support), "assigned charger excluded from assault army")
	for version in ["V07","V08"]:
		var old_path := OS.get_environment("IRON_TIDE_"+version+"_SAVE")
		if old_path.is_empty(): continue
		var historic := BattleSaves.read_path(old_path)
		if not historic.ok: continue
		preload("res://scripts/save/battle_snapshot.gd").new().restore(battle,historic.snapshot)
		barracks = actor("NAHAND","ally")
		check(barracks != null and barracks.can_queue("SHK"), "existing barracks can produce new trooper after "+version+" restore")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for version in ["V07","V08"]:
		var path := OS.get_environment("IRON_TIDE_"+version+"_SAVE")
		if not path.is_empty(): check(BattleSaves.read_path(path).ok,"reads original " + version + " Soviet save")
	await scene_checks()
	await finish()
	var report:=FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	report.close()
	get_tree().quit(0 if failed==0 else 1)
