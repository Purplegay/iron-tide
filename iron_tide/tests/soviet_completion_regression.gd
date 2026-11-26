extends "res://tests/soviet_advanced_regression.gd"
const Special = preload("res://scripts/units/soviet_specials.gd")
const NewUnits := ["SAPC","SQD","DRED","TTNK","DTRUCK","IVAN","CIVAN","TERROR","DESO","BORIS"]
const NewBuildings := ["NANRCT","NAINDP","NAIRON","NAMISL"]

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var prior := OS.get_environment("IRON_TIDE_PRE_COMPLETION_SAVE")
	if not prior.is_empty():
		var legacy := BattleSaves.read_path(prior)
		check(legacy.ok, "actual v0.14.3.2 save accepted", legacy.get("message",""))
		if legacy.ok:
			start_soviet("苏俄","allied","prebuilt")
			BattleSaves.Snapshot.new().restore(battle,legacy.snapshot)
			get_tree().paused=false
			battle.paused=false
			var old_yard = actor("NAYARD","ally")
			check(old_yard != null and old_yard.buildable.has("DRED") and old_yard.production.has("SUB"), "old yard gains new ships and keeps its paid order")
			await finish()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		BattleRequest.configure_skirmish(mode,{"country":"苏俄","enemy_base":"allied","map_size":3200,"starting_funds":80000,"fog_of_war":false})
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		battle=screen.battle
		screen.process_mode=Node.PROCESS_MODE_DISABLED
		for b in battle.buildings: b._process(10)
		await exercise_completion(mode)
		await finish()
	var report := FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	report.close()
	get_tree().quit(0 if failed==0 else 1)

func exercise_completion(mode: String) -> void:
	var prefix := mode + " Soviet: "
	battle.funds=100000
	var war=ready_building("NAWEAP",Vector2(500,1250))
	var barracks=ready_building("NAHAND",Vector2(500,1450))
	var radar=ready_building("NARADR",Vector2(750,1250))
	var power=ready_building("NANRCT",Vector2(1250,1250))
	var industry=ready_building("NAINDP",Vector2(1450,1250))
	var guide = preload("res://scripts/ui/unlock_guidance.gd").new(battle)
	check(not war.enqueue("SCHP") and war.queue_block_reason("SCHP").contains("作战实验室"),prefix+"industrial plant cannot replace lab for siege chopper")
	check(not guide._options("TECH").has("NAINDP") and guide.describe("SCHP").detail.contains("苏联作战实验室"),prefix+"unlock route lists real laboratory")
	ready_building("NATECH",Vector2(1000,1250))
	check(war.can_queue("SCHP"),prefix+"laboratory unlocks siege chopper at war factory")
	for row in GameData.raw_docs["yr_soviet.json"].buildings + GameData.raw_docs["yr_soviet.json"].units:
		if GameData.get_unit(row.id).is_empty() or GameData.unit_in_production_catalog(row.id):
			check(EntityDescription.DETAILS.has(row.id) and not EntityDescription.text(row).is_empty(),prefix+"specific description "+str(row.id))
	screen.hud.select_prod_tab("defense")
	battle.request_structure("NAWALL")
	screen.hud._update_production_live()
	var wall_card: Button = screen.hud._prod_buttons.NAWALL
	var wall_text := EntityDescription.text(GameData.get_building("NAWALL"))
	check(wall_card.tooltip_text.contains(wall_text) and wall_card.tooltip_text.contains("右键暂停"),prefix+"wall in production keeps description and pause hint")
	battle._tick_structure_queue(100.0)
	screen.hud._update_production_live()
	check(battle.struct_ready.has("NAWALL") and wall_card.tooltip_text.contains(wall_text) and wall_card.tooltip_text.contains("选址"),prefix+"ready wall keeps description and placement hint")
	battle.cancel_structure("NAWALL")
	var iron=ready_building("NAIRON",Vector2(1850,1250))
	var silo=ready_building("NAMISL",Vector2(2050,1250))
	battle.water_rects=[Rect2(2200,300,850,2300)]
	battle.path_service.set_water(battle.water_rects)
	var yard=ready_building("NAYARD",Vector2(2350,950))
	battle._refresh_pathing()
	battle._update_power()
	var producers={"NAWEAP":war,"NAHAND":barracks,"NAYARD":yard}
	for country in ["苏俄","古巴","利比亚","伊拉克"]:
		var choice := preload("res://scripts/ui/lobby_preferences.gd").normalize({"country":country})
		battle._countries.ally=GameData.ra2_country_id(country)
		check(choice.country==country and battle.roster_faction()=="soviet",prefix+"lobby keeps Soviet country "+country)
	var gates={"TTNK":"Russians","DTRUCK":"Africans","TERROR":"Confederation","DESO":"Arabs"}
	for id in NewBuildings+NewUnits:
		check(not GameData.get_entity(id).is_empty() and ResourceLoader.exists(GameData.ra2_cameo_path(id)) and RA2Art.has_art(id),prefix+"native body and cameo "+id)
	for id in NewUnits:
		var data:=GameData.get_unit(id)
		var producer=producers[data.built_at]
		if gates.has(id):
			battle._countries.ally="Americans"
			check(mode == MatchRules.EXTENDED or not producer.can_queue(id),prefix+"country lock "+id)
			battle._countries.ally=gates[id]
		if id=="CIVAN":
			check(not producer.can_queue(id),prefix+"stolen tech required")
			battle.allied_state["stolen_ally_RequiresStolenSovietTech"]=true
		check(producer.buildable.has(id) and producer.enqueue(id),prefix+"real factory queue "+id+" "+producer.queue_block_reason(id))
		if producer.production.has(id):
			var cash: float = battle.funds
			var price: float = battle.production_price(data,"ally")
			producer._process(200)
			var produced = actor(id,"ally")
			check(produced!=null and producer.production.is_empty() and is_equal_approx(cash-battle.funds,price),prefix+"paid production exits "+id,[producer.production, price, cash-battle.funds])
			if produced!=null:
				if produced._ra2.get("kind") == "vxl":
					check(produced._ra2.facings==32 and produced._ra2.has("detail_tex"),prefix+"32-facing 2x model "+id)
				else:
					check(not produced._seq.is_empty() and not produced._ra2.get("detail",{}).is_empty(),prefix+"SHP actions and detail atlas "+id)
				check(not GameData.ra2_sound_files(Ra2Sfx.voice_id(data,"select")).is_empty(),prefix+"native selection sound "+id)
				battle.units.erase(produced)
				produced.free()
	for id in ["DMISL","BPLN","SPYP"]:
		check(not GameData.unit_in_production_catalog(id) and RA2Art.has_art(id),prefix+"auxiliary excluded "+id)
	check(power.power==2000 and battle.production_price(GameData.get_unit("HTNK"),"ally")==675 and battle.production_price(GameData.get_unit("E2"),"ally")==100,prefix+"power and side discount")
	battle._countries.ally="Russians"
	var funds: float=battle.funds
	check(war.enqueue("TTNK"),prefix+"Tesla tank queued")
	war._process(0.5)
	industry.under_construction=true
	war._process(200)
	check(actor("TTNK","ally")!=null and is_equal_approx(funds-battle.funds,900),prefix+"locked industrial price survives plant shutdown")
	industry.under_construction=false
	check(not battle.limit_reason("NAINDP","ally").is_empty(),prefix+"single industrial plant")
	var target=battle.spawn_unit("HTNK","enemy",Vector2(1550,1800))
	target.order_stop()
	var ivan=battle.spawn_unit("IVAN","ally",target.position+Vector2(35,0))
	var hp: float=target.hp
	check(aim(ivan,target) and target.special.has("ivan_bomb") and target.hp==hp,prefix+"Ivan plants without direct damage")
	var saved:=BattleSaves.save_slot(battle,"slot2")
	check(saved.ok and BattleSaves.read_slot("slot2").ok,prefix+"armed bomb saves")
	target._physics_process(29.75)
	check(target.hp==hp and is_equal_approx(target.special.ivan_bomb.left,0.25),prefix+"last second of the fuse remains armed")
	target._physics_process(0.25)
	check(target.hp<hp and not target.special.has("ivan_bomb"),prefix+"delayed detonation")
	var victim=battle.spawn_unit("HTNK","enemy",Vector2(450,2350))
	var terror=battle.spawn_unit("TERROR","ally",victim.position+Vector2(12,0))
	check(aim(terror,victim) and terror._dead and victim.hp<victim.max_hp,prefix+"suicide blast")
	var deso=battle.spawn_unit("DESO","ally",Vector2(770,1950))
	var infantry=battle.spawn_unit("E2","enemy",deso.position+Vector2(105,45))
	check(deso.deploy(),prefix+"radiation deploy command")
	deso._cd_timer=0
	deso._physics_process(0.1)
	var field = battle.get_node("RadiationFields").get_child(0)
	check(field.mouse_filter == Control.MOUSE_FILTER_IGNORE and field.size == Vector2.ONE * deso.data.deployed_weapon.range * 2, prefix+"visual matches damage footprint")
	check(deso._fire_sequence()=="Deploy" and deso._fire_anim_time==0, prefix+"first dose plays native deploy sequence")
	Special.tick_world(battle,0.55)
	if DisplayServer.get_name() != "headless":
		battle.camera.position=deso.position
		battle.camera.zoom=Iso.cam_zoom(1.6)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		deso._physics_process(0.55)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center := Vector2i(deso.get_global_transform_with_canvas().origin)
		get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(376,215),Vector2i(752,430))).save_png(output_dir.path_join(mode+"-radiation.png"))
	var brightness: float = field.material.get_shader_parameter("strength")
	Special.tick_world(battle,float(Special.radiation_rules().level_delay)/Special.TPS)
	check(field.material.get_shader_parameter("strength") < brightness, prefix+"contamination fades with remaining dose")
	check(infantry.hp<infantry.max_hp and deso.hp==deso.max_hp,prefix+"deployed radiation and immunity")
	deso._cd_timer = 0
	deso._physics_process(0.1)
	check(deso._fire_sequence()=="DeployedFire" and battle.get_node("RadiationFields").get_child_count()==1, prefix+"repeated dose reuses field and plays native discharge")
	var boat=battle.spawn_unit("SAPC","ally",Vector2(2300,1500))
	var passenger=battle.spawn_unit("E2","ally",boat.position+Vector2(15,0))
	check(boat.is_amphibious and boat.logistics.capacity==12 and boat.logistics.can_board(passenger),prefix+"amphibious transport seats")
	var squid=battle.spawn_unit("SQD","ally",Vector2(2500,1700))
	var ship=battle.spawn_unit("DEST","enemy",squid.position+Vector2(35,0))
	check(aim(squid,ship) and ship.special.get("squid")==squid,prefix+"squid grips surface ship")
	check(not NavalContact.submerged(squid) and squid.embarked_in==ship and not RA2Art.fx(Special.grip_image(ship,squid)).is_empty(),prefix+" attacking squid switches from underwater body to visible grip on target")
	var directions := {}
	for i in 64:
		ship.hull_angle=i*TAU/64.0
		var image := Special.grip_image(ship,squid)
		directions[image]=not RA2Art.fx(image).is_empty()
	check(directions.size()==8 and not directions.values().has(false),prefix+"all eight native ship-facing grips load")
	ship._physics_process(0.1)
	check(ship.hp==ship.max_hp and ship._rock_t>0,prefix+"grab rocks hull before first squeeze damage")
	ship._physics_process(Special.squid_grip_seconds())
	check(ship.hp<ship.max_hp and ship.velocity==Vector2.ZERO,prefix+"grip damages and immobilizes")
	ship.receive_hit(1,"sonic")
	check(squid.embarked_in==null and not ship.special.has("squid"),prefix+"sonic hit frees ship")
	check(is_equal_approx(squid._stun_timer,10.0) and not aim(squid,ship),prefix+"sonic eviction prevents immediate re-grab")
	squid._physics_process(10.0)
	var sub=battle.spawn_unit("SUB","enemy",squid.position + Vector2.RIGHT*32.0)
	sub.special.erase("dive_remaining")
	check(aim(squid,sub) and sub.special.get("squid")==squid,prefix+"detected mechanical submarine can be gripped")
	sub.hp -= 10.0
	sub.heal(1.0)
	check(squid.embarked_in==sub,prefix+"self-heal does not evict squid")
	sub.heal(1.0,ship)
	check(squid.embarked_in==null and squid._stun_timer==10.0,prefix+"external repair releases squid")
	squid._physics_process(10.0)
	var dolphin=battle.spawn_unit("DLPH","enemy",squid.position + Vector2.RIGHT*32.0)
	squid._cd_timer=0
	check(aim(squid,dolphin) and squid.embarked_in==null and squid._weapon_for_target(dolphin).name=="SquidPunch",prefix+"organic naval target receives secondary punch")
	for rank in [0,2]:
		var gripped_ship=battle.spawn_unit("DEST","enemy",squid.position+Vector2(40,0))
		squid._grant_veteran(rank,false)
		squid._cd_timer=0
		check(aim(squid,gripped_ship),prefix+"squid grips at rank "+str(rank))
		gripped_ship.hp=gripped_ship.max_hp*(0.50 if rank==2 else 0.25)
		gripped_ship.special.iron_left=10.0
		Special.squeeze(gripped_ship,Special.squid_grip_seconds())
		check(not gripped_ship._dead,prefix+"iron curtain protects against culling")
		gripped_ship.special.erase("iron_left")
		Special.squeeze(gripped_ship,Special.squid_grip_seconds())
		check(gripped_ship._dead and squid.embarked_in==null,prefix+"native hull threshold sinks ship and frees squid")
	var trapped_ship=battle.spawn_unit("DRED","enemy",squid.position + Vector2.RIGHT*32.0)
	squid._cd_timer=0
	check(aim(squid,trapped_ship),prefix+"grip before external sinking")
	trapped_ship.receive_hit(trapped_ship.max_hp*10,"shell",{},target)
	check(trapped_ship._dead and squid._dead,prefix+"third-party sinking removes attached squid")
	for damage in [250.0,251.0]:
		var hunter=battle.spawn_unit("SQD","ally",Vector2(2400,1500))
		var vessel=battle.spawn_unit("DRED","enemy",hunter.position+Vector2.RIGHT*30)
		vessel.bonuses={}
		check(aim(hunter,vessel),prefix+"grip before suppression threshold "+str(damage))
		vessel.receive_hit(damage,"shell",{},target)
		vessel.hp=vessel.max_hp*0.25
		Special.squeeze(vessel,Special.squid_grip_seconds())
		check(vessel._dead and hunter._dead==(damage>250),prefix+"native suppression threshold "+str(damage))
	var dread=battle.spawn_unit("DRED","ally",Vector2(2300,2200))
	var building=ready_building("GAPOWR",Vector2(1750,2250))
	AlliedAbilities.change_side(building,"enemy")
	var border = battle.spawn_unit("HTNK","enemy",dread.position + Vector2(440,0))
	dread.attack_ordered = true
	dread.attack_target = border
	check(dread._weapon_target_valid(border),prefix+"DredLauncher inclusive eight-cell boundary")
	border.position.x -= 1
	var berth := preload("res://scripts/units/dread_missile.gd").firing_position(dread,border)
	check(berth.is_finite() and battle.on_water(berth) and berth.distance_to(border.position)>440,prefix+"ship can reposition outside blind zone on water")
	check(not dread._weapon_target_valid(border),prefix+"inside minimum range blocked")
	border.position = dread.position + Vector2(1375,0)
	check(dread._weapon_target_valid(border),prefix+"25-cell ship range")
	border.position.x += 1
	check(not dread._weapon_target_valid(border),prefix+"beyond base range blocked for unit")
	var old: Vector2 = building.position
	var reach := OpenTopped.command_range(dread,building)
	building.position = dread.position + Vector2(reach,0)
	dread.attack_target = building
	battle.select_unit(dread,false)
	var ring: Dictionary = preload("res://scripts/world/attack_range_preview.gd").ranges(battle)[0]
	check(reach > 1375 and ring.radius == reach and ring.minimum == 440 and dread._weapon_target_valid(building),prefix+"building foundation extends outer ring only")
	building.position.x += 1
	check(not dread._weapon_target_valid(building),prefix+"building just outside effective range")
	building.position = old
	check(aim(dread,building),prefix+"dread launches")
	check(battle.units.filter(func(u):return battle.actor_alive(u) and u.unit_id=="DMISL").size()==1,prefix+"one missile on first rail")
	dread._update_burst(0.2)
	dread._update_burst(0.2)
	var missiles=battle.units.filter(func(u):return battle.actor_alive(u) and u.unit_id=="DMISL")
	check(missiles.size()==2,prefix+"two real attackable missiles")
	if missiles.size()==2:
		Ra2Sfx._eva_last.erase("EVA_UNITLOST")
		missiles[0].receive_hit(10000)
		check(not Ra2Sfx._eva_last.has("EVA_UNITLOST"),prefix+"Dread missile interception is silent on the unit loss channel")
		hp=building.hp
		var shot = missiles[1]
		var start: Vector2 = shot.position
		var deck: float = shot.logistics.air_lift
		dread.order_stop()
		dread.set_fire_stance("none")
		dread._physics_process(1.0)
		shot._physics_process(1.0)
		check(shot.position.is_equal_approx(start) and is_equal_approx(deck,shot.logistics.air_lift) and shot.special.flight.pitch==0,prefix+"20-tick rack pause")
		shot._physics_process(4.4)
		check(shot.special.flight.pitch>0.7 and shot.logistics.air_lift>deck and shot.special.flight.phase=="boost",prefix+"tilts to 45 degrees before boost")
		var racks: Array = dread.special.missile_racks
		check(is_equal_approx(racks[0],65.0/15.0) and is_equal_approx(racks[1],80.0/15.0),prefix+"rack and departing round regenerate independently")
		var ring_state := preload("res://scripts/ui/attack_cooldown_indicator.gd").ordinary_slot(dread,dread.weapon,"hull")
		check(is_equal_approx(ring_state.fraction,65.0/160.0),prefix+"ring tracks earliest usable rail")
		dread._physics_process(64.0/15.0)
		check(dread._cd_timer>0 and dread._ra2.key=="DREDWO",prefix+"both rails empty before first refill")
		dread._physics_process(1.01/15.0)
		check(dread._cd_timer<=0 and racks[0]==0 and racks[1]>0 and dread._ra2.key=="DRED",prefix+"first rail refills independently")
		check(aim(dread,building) and dread._burst_left==0 and racks[0]>0 and racks[1]>0,prefix+"single refilled rail fires one missile")
		var phases := {}
		for step in 500:
			if not battle.actor_alive(shot): break
			shot._physics_process(0.1)
			phases[shot.special.flight.phase]=true
		check(phases.has("boost") and phases.has("cruise") and phases.has("dive"),prefix+"native non-lazy flight stages")
		check(missiles[0]._dead and building.hp<hp,prefix+"one interception, one payload lands")
	for heading in [0.0,PI/2.0,PI]:
		for distance in [440.0,1375.0]:
			var attacker = battle.spawn_unit("DMISL","ally",dread.position)
			var dest: Vector2 = dread.position + Vector2(distance,0)
			dread.hull_angle = heading
			attacker.special.flight = {"elapsed":0.0,"altitude":165.0,"aim":dest,"source":dread}
			var flight=preload("res://scripts/units/dread_missile.gd")
			flight.prepare(attacker,dread,1.0)
			var hit: bool = flight.advance(attacker,attacker.special.flight,90.0)
			check(hit and attacker.position.is_equal_approx(dest),prefix+"DMISL reaches aim across launch bearings and legal range "+str([heading,distance]))
			battle.units.erase(attacker)
			attacker.free()
	var anti_air=battle.spawn_unit("HYD","ally",dread.position)
	for id in ["DMISL","V3ROCKET"]:
		var hostile=battle.spawn_unit(id,"enemy",anti_air.position+Vector2.RIGHT*40.0)
		hostile.logistics.air_lift=50.0
		var credits:float=anti_air._vet_kills
		var kills_before:int=battle.kills
		var fired := false
		for volley in 10:
			if hostile._dead: break
			anti_air._cd_timer=0
			fired=aim(anti_air,hostile) or fired
			for round in anti_air._pick_projectile_parent().get_children():
				if round is Projectile and round.target==hostile:
					for tick in 120:
						if round.is_queued_for_deletion():break
						round._physics_process(1.0/60.0)
		check(fired and hostile._dead,prefix+id+" intercepted by actual Sea Scorpion fire")
		check(hostile._dead and battle.kills==kills_before and anti_air._vet_kills==credits,prefix+id+" interception gives no kills or veteran score")
	var boris=battle.spawn_unit("BORIS","ally",Vector2(1300,2000))
	var lab=ready_building("GATECH",Vector2(1500,2000))
	AlliedAbilities.change_side(lab,"enemy")
	var graphical := DisplayServer.get_name() != "headless"
	var before: Image
	var area := Rect2i()
	if graphical:
		battle.camera.position = lab.position
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center: Vector2 = lab.get_global_transform_with_canvas() * lab.to_local(lab.art_center())
		area = Rect2i(Vector2i(center)-Vector2i(60,50),Vector2i(120,100))
		before = get_viewport().get_texture().get_image().get_region(area)
	battle.clear_selection()
	battle.select_unit(boris,false)
	var select_voice:=Ra2Sfx.voice_id(boris.data,"select")
	var rifle_voice:=Ra2Sfx.voice_id(boris.data,"attack")
	var air_voice:=Ra2Sfx.voice_id(boris.data,"secondary_attack")
	Ra2Sfx._voice_lock.clear()
	battle._emit_selection()
	check(Ra2Sfx._voice_lock.has(select_voice),prefix+"selecting Boris plays his select acknowledgement")
	var soldier=battle.spawn_unit("E2","enemy",boris.position+Vector2(30,0))
	battle.force_attack(soldier)
	check(Ra2Sfx._voice_lock.has(rifle_voice) and not Ra2Sfx._voice_lock.has(air_voice),prefix+"AKM attack order uses standard acknowledgement")
	var comrade=battle.spawn_unit("E2","ally",boris.position+Vector2(25,15))
	battle.select_unit(comrade,true)
	var voices_before:=Ra2Sfx.a_voice_plays
	battle.force_attack(lab)
	var sample:=Ra2Sfx._stream("yr_full/iboraib.wav")
	check(Ra2Sfx.a_voice_plays==voices_before+1 and Ra2Sfx._voice_lock.has(air_voice) and sample!=null and Ra2Sfx._global_pool.any(func(player):return player.stream==sample and player.playing),prefix+"mixed group plays one global BorisAirstrikeVoice on designating a building")
	boris.order_move(boris.position+Vector2.RIGHT*70)
	check(not lab.special.has("airstrike_mark") and actor("BPLN","ally")==null,prefix+"move before firing the flare spawns no jets")
	check(aim(boris,lab),prefix+"Boris designates structure")
	var indicator = preload("res://scripts/ui/attack_cooldown_indicator.gd")
	check(indicator.state(boris).is_empty(), prefix+"active designation has no frozen reload ring")
	var lab_hp: float = lab.hp
	Special.tick_actor(lab, 2.0)
	check(lab.modulate.r > lab.modulate.g and lab.special.airstrike_mark.jets.size()==2 and lab.hp == lab_hp, prefix+"flare starts red designation and dispatches without damaging building")
	if graphical:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var after := get_viewport().get_texture().get_image().get_region(area)
		var red_pixels := 0
		for y in after.get_height():
			for x in after.get_width():
				var a := before.get_pixel(x,y)
				var b := after.get_pixel(x,y)
				if b.r-b.g > a.r-a.g+0.15: red_pixels += 1
		check(red_pixels > 100, prefix+"building pixels visibly turn red", red_pixels)
		var pose := RA2Art.seq_frame(boris._seq,"SecondaryFire",RA2Art.facing_index(boris.hull_angle,8),0)
		check(boris._art_frame == pose,prefix+"renderer holds native Boris designator pose")
	var cancelled_wing:Array=lab.special.airstrike_mark.jets.duplicate()
	boris.order_move(boris.position + Vector2(100,0))
	Special.tick_actor(lab, 3.0)
	var abort_count:=Ra2Sfx.a_plays
	for jet in cancelled_wing: jet._physics_process(0.1)
	check(Ra2Sfx.a_plays==abort_count+1 and Ra2Sfx._pool.any(func(channel):return channel.stream==Ra2Sfx._stream("yr_full/vmigdib.wav")),prefix+"cancelled pair plays one original mission-aborted radio")
	check(not lab.special.has("airstrike_mark") and lab.modulate == Color.WHITE and actor("BPLN","ally") == null, prefix+"moving cancels designation and clears tint")
	var rifle_victim = battle.spawn_unit("E2","enemy",boris.position+Vector2(45,0))
	var rifle_hp:float = rifle_victim.hp
	check(aim(boris,rifle_victim) and rifle_victim.hp < rifle_hp, prefix+"cancelled designation immediately fires AKM and damages infantry")
	check(not boris._try_fire_ready(),prefix+"AKM still has its own rate of fire")
	Special.advance_sortie_reload(boris,0.01)
	check(not boris.special.has("airstrike_wing") and is_equal_approx(boris.special.airstrike_cd,100.0/15),prefix+"ordinary airstrike begins 100-tick recharge on last departure")
	Special.advance_sortie_reload(boris, 50.0/15)
	var rings: Array = indicator.state(boris).get("mounts", [])
	check(rings.size() == 2 and rings[0].key == "hull" and rings[1].key == "airstrike" and is_equal_approx(rings[1].fraction, 0.5), prefix+"rifle and half-recharged airstrike have separate rings")
	Special.advance_sortie_reload(boris,50.01/15)
	boris._cd_timer = 0.0
	check(aim(boris,lab),prefix+"Boris can designate again")
	var alternate=ready_building("GAPOWR",Vector2(1530,1880))
	AlliedAbilities.change_side(alternate,"enemy")
	var assigned: Array = lab.special.airstrike_mark.jets.duplicate()
	battle.select_unit(boris,false)
	battle.force_attack(alternate)
	assigned[0]._physics_process(0.01)
	check(assigned[0].special.strike_run.target==alternate and not assigned[0].special.strike_run.outbound and alternate.special.airstrike_mark.jets==assigned and not lab.special.has("airstrike_mark"),prefix+"redirect same incoming jets before old building tick")
	battle.force_attack(lab)
	Special.tick_actor(alternate,0.01)
	check(lab.special.airstrike_mark.jets==assigned and not alternate.special.has("airstrike_mark"),prefix+"retarget back without doubling the wing")
	for radio in ["MIGMove","MIGMissionAborted"]:
		for clip in GameData.ra2_sound_files(radio):
			check(Ra2Sfx._stream(clip)!=null,prefix+"native MiG radio sample loads "+clip)
	assigned[0]._physics_process(1.5)
	check(not assigned[0].special.strike_run.has("radio_left") and Ra2Sfx._global_pool.any(func(channel):return channel.stream in [Ra2Sfx._stream("yr_full/vmigmoa.wav"),Ra2Sfx._stream("yr_full/vmigmob.wav")]),prefix+"wing gets one incoming radio after soundmd pre-delay")
	Special.tick_actor(lab,3.9)
	check(lab.special.airstrike_mark.jets.size()==2,prefix+"mark timer does not dispatch a second wing")
	Special.tick_actor(lab,0.11)
	var jets=battle.units.filter(func(u):return battle.actor_alive(u) and u.unit_id=="BPLN")
	check(jets.size()==2 and not barracks.can_queue("BORIS"),prefix+"MiG pair and unique hero")
	if jets.size()==2:
		check(jets[0].special.strike_run.ammo==1,prefix+"MiG has its original one-round sortie magazine")
		jets[0].position=lab.position+Vector2(30,0)
		var before_volley: int = battle.projectiles_root.get_child_count()
		jets[0]._physics_process(0.1)
		check(battle.projectiles_root.get_child_count()==before_volley+2,prefix+"Maverick3 fires both missiles in one update")
		var left = battle.projectiles_root.get_child(before_volley)
		var right = battle.projectiles_root.get_child(before_volley+1)
		check(is_equal_approx(left.position.distance_to(right.position),200.0*Ra2Damage.PX_PER_CELL/256.0) and left.base_damage==750 and right.target==lab,prefix+"two distinct native wing rails and ordinary warhead")
		jets[0]._physics_process(0.1)
		check(battle.projectiles_root.get_child_count()==before_volley+2,prefix+"outbound aircraft cannot repeat the salvo")
		check(jets[0].special.strike_run.outbound and jets[0].special.strike_run.ammo==0,prefix+"MiG expends its single sortie load and returns")
		Special.tick_actor(lab,0.1)
		check(lab.special.has("airstrike_mark"),prefix+"designation persists while second MiG approaches")
		boris.order_stop()
		jets[1].position = lab.position+Vector2(35,0)
		var shots: int = battle.projectiles_root.get_child_count()
		jets[1]._physics_process(0.1)
		Special.tick_actor(lab,0.1)
		check(not lab.special.has("airstrike_mark") and lab.modulate == Color.WHITE and jets[1].special.strike_run.outbound and battle.projectiles_root.get_child_count() == shots,prefix+"aborted wingman returns without firing")
	var elite_lab=ready_building("GATECH",Vector2(1600,1850))
	AlliedAbilities.change_side(elite_lab,"enemy")
	var returning_target = battle.spawn_unit("E2","enemy",boris.position+Vector2(50,0))
	boris.set_fire_stance("none")
	boris._physics_process(1.4) # Advance the rifle clock while the airstrike is still recharging.
	check(boris.special.airstrike_cd > 0 and boris._cd_timer <= 0, prefix+"strike recharge advances separately from rifle reload")
	var return_hp:float = returning_target.hp
	check(aim(boris,returning_target) and returning_target.hp < return_hp,prefix+"rifle damages infantry while dispatched airstrike is still recharging")
	check(not aim(boris,elite_lab),prefix+"switching to rifle cannot call a second strike early")
	for jet in jets:
		if battle.actor_alive(jet): jet._physics_process(60.0)
	Special.advance_sortie_reload(boris,0.01)
	Special.advance_sortie_reload(boris,100.01/15)
	boris._grant_veteran(2,false)
	boris._cd_timer=0
	check(aim(boris,elite_lab),prefix+"elite Boris designates")
	Special.tick_actor(elite_lab,4.1)
	var elite_jets=battle.units.filter(func(u):return battle.actor_alive(u) and u.unit_id=="BPLN" and u.veteran_level==2)
	check(elite_jets.size()==4,prefix+"elite calls four MiGs")
	if elite_jets.size()==4:
		var start_shots: int=battle.projectiles_root.get_child_count()
		for jet in elite_jets:
			jet.position=elite_lab.position+Vector2(490,0)
			jet._physics_process(0.01)
		check(battle.projectiles_root.get_child_count()==start_shots+8,prefix+"four elite pairs at native nine-cell range")
		var missile=battle.projectiles_root.get_child(-1)
		check(missile.base_damage==400 and missile.ra2_warhead=="YR_SOV_ORCAAP",prefix+"elite Maverick3E uses its own payload")
		Special.tick_actor(elite_lab,0.1)
		check(not boris.attack_ordered and boris.attack_target == null,prefix+"completed sortie releases the designator order")
	var doomed=ready_building("GAPOWR",Vector2(1550,1870))
	AlliedAbilities.change_side(doomed,"enemy")
	boris._cd_timer=0
	Special.advance_sortie_reload(boris,15.0)
	check(not aim(boris,doomed) and boris.special.has("airstrike_wing"),prefix+"outbound surviving MiGs prevent duplicate sortie")
	for index in elite_jets.size():
		var jet = elite_jets[index]
		# Each aircraft is one unit from a different edge, away from its entry point.
		var size:float = battle.map_size
		jet.position = [Vector2(1,300), Vector2(size-1,300), Vector2(300,1), Vector2(300,size-1)][index]
		jet._physics_process(0.1)
		check(not battle.actor_alive(jet),prefix+"returning MiG exits at nearby edge "+str(index))
		if index < elite_jets.size()-1:
			Special.advance_sortie_reload(boris,1.0)
			check(boris.special.has("airstrike_wing"),prefix+"wing still returning after exit "+str(index))
	Special.advance_sortie_reload(boris,0.01)
	check(is_equal_approx(boris.special.airstrike_cd,50.0/15),prefix+"elite 50-tick recharge starts after last plane returns")
	Special.advance_sortie_reload(boris,50.01/15)
	check(aim(boris,doomed),prefix+"designates second target")
	Special.tick_actor(doomed,4.1)
	var arriving = doomed.special.airstrike_mark.jets[0]
	arriving.position = doomed.position + Vector2(60,0)
	doomed.hp=0
	var prior_shots: int = battle.projectiles_root.get_child_count()
	arriving._physics_process(0.1)
	check(arriving.special.strike_run.outbound and battle.projectiles_root.get_child_count()==prior_shots,prefix+"destroyed target aborts before releasing the pair")
	var survivor=battle.spawn_unit("E2","enemy",boris.position+Vector2(35,0))
	var survivor_hp:float=survivor.hp
	battle.force_attack(survivor,true)
	var pending:int=boris.order_queue.size()
	boris._refresh_target()
	var advanced:bool=boris.attack_target == survivor
	for frame in 30:
		boris._physics_process(1.0 / 60.0)
		if survivor.hp < survivor_hp: break
	check(pending == 1 and advanced and survivor.hp < survivor_hp,prefix+"destroyed marked building advances to queued infantry and fires elite AKM after turning")
	boris.special.erase("airstrike_cd")
	boris._cd_timer = 5.0 # Legacy saves stored the airstrike wait on the rifle.
	Special.restore_boris_reload(boris)
	check(boris.special.get("airstrike_cd") == 5.0 and boris._cd_timer == 0.0,prefix+"legacy strike reload migrates off rifle")
	boris._cd_timer = 0.4
	Special.restore_boris_reload(boris)
	check(boris._cd_timer == 0.4 and boris.special.airstrike_cd == 5.0,prefix+"independent cooldowns survive another restore")
	iron._sw_charge=iron.sw_recharge()
	check(iron.fire_superweapon(war.position),prefix+"iron curtain fires")
	hp=war.hp
	war.receive_hit(1000)
	check(war.hp==hp and war.special.has("iron_left") and war.modulate.r<=0.51,prefix+"shield absorbs damage")
	Special.tick_actor(war,51)
	war.receive_hit(30)
	check(war.hp<hp and war.modulate==Color.WHITE,prefix+"shield clears tint and expires")
	silo._sw_charge=silo.sw_recharge()
	check(silo.fire_superweapon(lab.position) and silo._sw_charge==0,prefix+"nuclear launch spends charge")
	hp=lab.hp
	var nuclear_flight: Dictionary=battle.allied_state.soviet_nukes[0]
	check(Special.missile_pose(nuclear_flight).image=="NKMSLUP" and silo._layer_visible("superanimfour"),prefix+"carrier rises at firing silo and discharge layer plays")
	Special.tick_world(battle,nuclear_flight.rise+0.1)
	check(Special.missile_pose(nuclear_flight).image=="NKMSLDN" and Special.missile_pose(nuclear_flight).point==lab.position and lab.hp==hp,prefix+"warhead descends over target without early damage")
	Special.tick_world(battle,nuclear_flight.left+0.01)
	check(lab.hp<hp and not battle.allied_state.get("rad_sites",[]).is_empty(),prefix+"nuclear impact and radiation")
	radar._sw_charge=radar.sw_recharge()
	check(radar.fire_superweapon(Vector2(800,800)) and actor("SPYP","ally")!=null,prefix+"radar reconnaissance sortie")
	var bomb_target=ready_building("GAPOWR", Vector2(400,1000))
	var marker=battle.spawn_unit("IVAN","enemy",bomb_target.position + Vector2(40,0))
	marker._fire_shot(bomb_target)
	Special.tick_actor(bomb_target,7.0)
	var remaining: float = bomb_target.special.ivan_bomb.left
	var transport = battle.spawn_unit("SAPC","ally",Vector2(2500,1850))
	var conscript = battle.spawn_unit("E2","ally",transport.position+Vector2(10,0))
	check(conscript.logistics.request_board(transport), prefix+"normal landing craft boarding order")
	conscript.logistics.tick(0.1)
	check(conscript.embarked_in == transport and transport.logistics.passengers.has(conscript),prefix+"soldier actually boards")
	var timed_passenger = battle.spawn_unit("E2","ally",transport.position+Vector2(10,0))
	marker._fire_shot(timed_passenger)
	if timed_passenger.special.has("ivan_bomb"):
		timed_passenger.logistics.request_board(transport)
		timed_passenger.logistics.tick(0.1)
		timed_passenger._physics_process(1.0)
	check(timed_passenger.embarked_in == transport and is_equal_approx(float(timed_passenger.special.get("ivan_bomb",{}).get("left",-1)),29.0),prefix+"Ivan countdown continues aboard a landing craft")
	var hold=battle.spawn_unit("SQD","ally",Vector2(2450,1400))
	var captive=battle.spawn_unit("DEST","enemy",hold.position+Vector2(20,0))
	check(aim(hold,captive),prefix+"second squid grab before save")
	var checkpoint := BattleSaves.save_slot(battle,"slot3")
	var read := BattleSaves.read_slot("slot3")
	check(checkpoint.ok and read.ok,prefix+"support flights and radiation round trip")
	if read.ok:
		BattleSaves.Snapshot.new().restore(battle,read.snapshot)
		get_tree().paused=false
		battle.paused=false
		check(not battle.allied_state.get("rad_sites",[]).is_empty() and actor("SPYP","ally") != null,prefix+"restored hazard and scout")
		var armed=battle.buildings.filter(func(b):return battle.actor_alive(b) and b.special.has("ivan_bomb"))
		check(armed.size()==1 and is_equal_approx(armed[0].special.ivan_bomb.left,remaining),prefix+"bomb countdown restored")
		var trapped=battle.units.filter(func(u):return battle.actor_alive(u) and u.special.has("squid"))
		check(trapped.size()==1 and trapped[0].special.squid.embarked_in==trapped[0],prefix+"squid-host references restored")
		if armed.size()==1:
			var engineer=battle.spawn_unit("SENGINEER","ally",armed[0].position)
			engineer.position = AlliedAbilities.approach(engineer, armed[0])
			check(AlliedAbilities.use(engineer,"allied_engineer",armed[0]),prefix+"engineer accepts disarm order")
			AlliedAbilities.tick_action(engineer,0.1)
			check(not armed[0].special.has("ivan_bomb") and battle.actor_alive(engineer),prefix+"disarm preserves engineer and protected target")
	if DisplayServer.get_name()!="headless":
		await art_review(mode)
		screen.hud.select_prod_tab("naval")
		battle.camera.position=Vector2(2250,1700)
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join(mode+"-soviet.png"))

func art_review(mode: String) -> void:
	for zoom in [1.0,2.0]:
		for section in [["infantry","IVAN","CIVAN","TERROR","DESO","BORIS"],["vehicle","TTNK","DTRUCK"],["naval","SAPC","SQD","DRED"]]:
			var category: String=section[0]
			screen.hud.select_prod_tab(category)
			var center:=Vector2(2600,1650) if category=="naval" else Vector2(700,770)
			battle.camera.position=center
			battle.camera.zoom=Iso.cam_zoom(zoom)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			var models: Array=[]
			for i in range(1,section.size()):
				var position: Vector2=center+RA2Art.art_dir(Vector2((i-0.5*section.size())*100,0))
				models.append(battle.spawn_unit(section[i],"ally",position))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("%s-%s-%dx.png" % [mode,category,int(zoom)]))
			for model in models:
				battle.units.erase(model)
				model.free()
