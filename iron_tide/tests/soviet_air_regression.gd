extends "res://tests/soviet_advanced_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var old := OS.get_environment("IRON_TIDE_PRE_AIR_SAVE")
	if not old.is_empty():
		var previous := BattleSaves.read_path(old)
		check(previous.ok, "previous Soviet match opens under new content hash", previous.get("message", ""))
	start_soviet("苏俄", "allied", "prebuilt")
	if not old.is_empty():
		var previous := BattleSaves.read_path(old)
		if previous.ok:
			BattleSaves.Snapshot.new().restore(battle, previous.snapshot)
			var barracks = actor("NAHAND","ally")
			check(actor("DOG","ally") != null and actor("SOV_DOG","ally") == null, "old Allied dog kept its identity")
			check(barracks != null and barracks.buildable.has("SOV_DOG"), "old Soviet barracks gains new product")
			await finish()
			start_soviet("苏俄", "allied", "prebuilt")
	await run_air()
	await check_kirov_crash()
	await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks, "failed":failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func run_air() -> void:
	var factory = actor("NAWEAP", "ally")
	if factory == null: factory = ready_building("NAWEAP", Vector2(1000,1250))
	var barracks = actor("NAHAND", "ally")
	if barracks == null: barracks = ready_building("NAHAND", Vector2(1300,1200))
	check(not factory.enqueue("ZEP") and not factory.enqueue("SCHP"), "lab required")
	ready_building("NARADR", Vector2(1300,1500))
	ready_building("NATECH", Vector2(1600,1500))
	var hud = screen.hud
	hud.select_prod_tab("vehicle")
	hud._refresh_production()
	check(hud._prod_buttons.has("HTNK") and not hud._prod_buttons.has("ZEP") and not hud._prod_buttons.has("SCHP"), "vehicle deck excludes Soviet aircraft")
	hud.select_prod_tab("air")
	hud._refresh_production()
	check(hud.prod_tab == "air" and hud._prod_buttons.has("ZEP") and hud._prod_buttons.has("SCHP") and not hud._prod_buttons.has("HTNK"), "dedicated Soviet air deck")
	for id in ["SOV_DOG", "ZEP", "SCHP"]:
		var builder = barracks if id == "SOV_DOG" else factory
		var funds: float = battle.funds
		if id == "SOV_DOG":
			check(builder.enqueue(id), "normal enqueue " + id)
		else:
			check(hud._producer_for(id) == factory, "air card resolves Soviet war factory")
			hud._prod_buttons[id].pressed.emit()
			check(builder.production == [id], "air card queues " + id)
		builder._process(180)
		check(actor(id, "ally") != null and is_equal_approx(funds - battle.funds, GameData.get_unit(id).cost), "created and paid " + id)
		check(RA2Art.has_art(id) and ResourceLoader.exists(GameData.ra2_cameo_path(id)), "native artwork " + id)
		var voice := Ra2Sfx.voice_id(GameData.get_unit(id), "select")
		check(not GameData.ra2_sound_files(voice).is_empty(), "selection speech " + id)
	check(GameData.get_unit("DOG").faction == "allied" and GameData.ra2_source_units.SOV_DOG.id == "DOG", "distinct dog identity")
	var chopper = actor("SCHP", "ally")
	var blimp = actor("ZEP", "ally")
	var dog = actor("SOV_DOG", "ally")
	if chopper == null or blimp == null or dog == null: return
	var damage = preload("res://scripts/units/vehicle_damage_particles.gd")
	check(RA2Art.fx("SGRYSMK1").get("count", 0) == 20, "original Kirov grey smoke atlas loaded")
	for pair in [[0.51,0],[0.5,1],[0.251,1],[0.25,2],[0.01,2]]:
		blimp.hp = blimp.max_hp * pair[0]
		check(damage.stage(blimp)==pair[1],"Kirov damage threshold "+str(pair[0]))
	blimp.heal(blimp.max_hp)
	check(damage.stage(blimp)==0,"repaired hull stops emitting damage particles")
	var clear := Vector2.ZERO
	for y in range(550, 1600, 80):
		for x in range(550, 1600, 80):
			if chopper.logistics.landing_clear(battle, Vector2(x,y), chopper.radius):
				clear = Vector2(x,y)
				break
		if clear != Vector2.ZERO: break
	chopper.position = factory.position
	check(not chopper.set_deployed(true, false), "building blocks deployment")
	chopper.position = clear
	chopper.logistics.air_lift = 1
	check(UnitSkillLayout.index(chopper, 2) >= 0 and chopper.deploy() and not chopper.logistics.can_start_volley(), "descent holds fire")
	chopper.logistics.tick(15)
	chopper.logistics.tick(0.2)
	check(is_equal_approx(chopper.logistics.SiegeChopper.duration(),6.6) and is_equal_approx(chopper.special.siege_progress,0.2/6.6),"11 deployment frames use YR SCHPDEPL Rate=100")
	check(chopper._ra2.get("key") == "SCHPDEPL" and not chopper.logistics.can_start_volley(), "unfold frames hold fire")
	chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
	check(chopper._ra2.get("key") == "SCHD" and chopper._ra2_tur.get("key") == "SCHD_tur" and chopper._active_weapon().name == "160mm" and chopper.logistics.can_start_volley(), "ground turret and artillery")
	var artillery_target = battle.spawn_unit("HTNK","enemy",clear + Vector2(420,0))
	check(aim(chopper, artillery_target), "long range artillery opens fire from the ground")
	chopper._cd_timer=0
	chopper.attack_target=artillery_target
	chopper.attack_ordered=true
	chopper.turret_angle=PI
	chopper._physics_process(1.0/60.0)
	check(absf(angle_difference(PI,chopper.turret_angle)) < 0.1 and not chopper._weapon_aligned(artillery_target),"ground turret turns at native ROT before firing sideways")
	check(not GameData.ra2_sound_files("SeigeChopperDeploy").is_empty() and Ra2Sfx._stream("yr_full/vchodepa.wav")!=null,"deployment uses original mechanical sample")
	check(chopper.deploy(), "fold accepted")
	chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
	chopper.logistics.tick(15)
	check(chopper._ra2.get("key") == "SCHP" and chopper.weapon.name == "BlackHawkCannon" and chopper.logistics.air_lift > 0.95, "airborne again with cannon")
	if DisplayServer.get_name() != "headless":
		dog.position = clear + Vector2(70,75)
		blimp.position = clear + Vector2(95, 15)
		blimp.logistics.air_lift = 1.0
		battle.camera.position = clear
		for zoom in [1.0, 2.0]:
			battle.camera.zoom = Iso.cam_zoom(zoom)
			battle.camera.reset_smoothing()
			battle.camera.force_update_scroll()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output_dir.path_join("air-%dx.png" % int(zoom)))
		battle.camera.position = blimp.art_center()
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		blimp.remove_meta(&"healing_indicator_visual")
		blimp._anim = 3.0
		var healthy: Image
		for percent in [100,45,15,100]:
			blimp.hp = blimp.max_hp * percent / 100.0
			blimp.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var center := Vector2i(blimp.get_canvas_transform()*blimp.art_center())
			var image := get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(140,100),Vector2i(280,185)))
			if healthy == null: healthy = image
			elif percent < 100:
				check(image.get_data() != healthy.get_data(), "damage changes the rendered airborne hull at %d percent" % percent)
			image.save_png(output_dir.path_join("kirov-%d.png" % percent))
	var target = battle.spawn_unit("E1","enemy",clear + Vector2(200,0))
	dog.position = target.position + Vector2(4,0)
	check(preload("res://scripts/units/dog_pounce.gd").start(dog,target,dog.weapon), "dog pounce begins")
	preload("res://scripts/units/dog_pounce.gd").tick(dog,0.01)
	check(target.hp <= 0, "contact kills infantry")
	var victim = battle.spawn_unit("MTNK","enemy",clear + Vector2(650,0)) # Separate bomb range from the dog and its later detection fixture.
	var at: Vector2 = victim.position
	blimp.position = at + Vector2(0,-25)
	blimp.logistics.air_lift = 1
	check(aim(blimp,victim), "blimp releases bomb on attack order")
	var bomb: Projectile
	for shot in blimp._pick_projectile_parent().get_children():
		if shot is Projectile and shot.splinters.has("bomb_drop"): bomb = shot
	check(bomb != null, "native bomb created")
	if bomb == null: return
	victim.position += Vector2(450,0)
	var mount_point:Vector2=blimp.position-Vector2.from_angle(blimp.hull_angle)*50.0*Ra2Damage.PX_PER_CELL/256.0
	var drop_lift:float=(750.0-140.0)*blimp.flight.HEIGHT_PIXEL
	check(bomb.global_position.is_equal_approx(mount_point+RA2Art.art_dir(Vector2.UP*drop_lift)), "bomb leaves the native gondola mount")
	bomb._physics_process(0.1)
	check(bomb.target_point.is_equal_approx(mount_point) and not bomb.is_queued_for_deletion(), "bomb fixed on release")
	var under_bay=battle.spawn_unit("HTNK","enemy",mount_point)
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.with_offense(Ra2Damage.target_damage(250,bomb.ra2_warhead,under_bay,0.0),bomb.attacker_bonus),under_bay.bonuses))
	bomb._physics_process(0.7)
	check(not bomb._detonated and bomb.target_point.is_equal_approx(mount_point),"bomb still falling after 24 rule ticks")
	bomb._physics_process(1.0)
	check(bomb._detonated and victim.hp == victim.max_hp, "escaped target avoids blast")
	check(is_equal_approx(under_bay.max_hp-under_bay.hp,expected),"bomb splashes actual ground contact with native armour ratio")
	var spy = battle.spawn_unit("SPY","enemy",dog.position + Vector2(10,0))
	spy.special.disguise = "E2"
	check(not AlliedAbilities.concealed(spy, "ally"), "Soviet dog detects disguise")
	var ally_dog = battle.spawn_unit("DOG", "ally", clear + Vector2(500,0))
	check(ally_dog.data.faction == "allied" and dog.data.faction == "soviet", "both kennel lineages in battle")
	chopper.position = clear
	check(chopper.set_deployed(true,false),"deployment starts on empty tile")
	var blocker=battle.spawn_unit("HTNK","enemy",clear)
	chopper.logistics.tick(0.2)
	check(not chopper._deployed and not chopper.special.has("siege_progress") and chopper.logistics.air_lift>0.95,"occupied landing spot cancels descent")
	blocker.position+=Vector2(240,0)
	check(chopper.set_deployed(true, false), "deployment for save")
	chopper.logistics.tick(15)
	chopper.logistics.tick(0.25)
	blimp._cd_timer=0.0
	check(aim(blimp,under_bay),"second bomb released before save")
	var falling:Projectile=blimp._pick_projectile_parent().get_child(-1)
	falling._physics_process(0.5)
	var fall_pos:=falling.global_position
	var released_at:=falling.target_point
	var saved := BattleSaves.save_slot(battle, "slot1")
	var disk := BattleSaves.read_slot("slot1")
	check(saved.ok and disk.ok, "both dogs and changing aircraft serialize")
	if not disk.ok: return
	BattleSaves.Snapshot.new().restore(battle, disk.snapshot)
	var saved_bomb:Projectile
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.splinters.has("drop_height") and not shot._detonated: saved_bomb=shot
	check(saved_bomb!=null and saved_bomb.global_position.is_equal_approx(fall_pos) and is_equal_approx(saved_bomb._arc_t,15.0),"falling bomb restores its vertical clock and position")
	if saved_bomb!=null:
		saved_bomb._physics_process(3.0)
		check(saved_bomb._detonated and saved_bomb.target_point.is_equal_approx(released_at),"restored bomb impacts original ground point")
	chopper = actor("SCHP","ally")
	check(actor("DOG","ally") != null and actor("SOV_DOG","ally") != null, "dog identities restored")
	check(chopper != null and chopper.special.has("siege_progress"), "deployment timer restored")
	if chopper != null:
		chopper.logistics.tick(chopper.logistics.SiegeChopper.duration())
		check(chopper._ra2.get("key") == "SCHD" and chopper._active_weapon().name == "160mm", "deployment resumes after loading")

func falling_hull():
	for shot in battle.projectiles_root.get_children():
		if shot is Projectile and shot.splinters.has("kirov_crash") and not shot.is_queued_for_deletion(): return shot
	return null

func check_kirov_crash() -> void:
	battle.paused = false
	get_tree().paused = false
	var point := Vector2(2050,1700)
	var blimp = battle.spawn_unit("ZEP","ally",point)
	blimp.logistics.air_lift = 1.0
	blimp.velocity = Vector2(25,0)
	blimp._grant_veteran(2,false)
	var crash_damage:=CombatMath.with_offense(250.0,blimp.bonuses)
	var lift: float = blimp._visual_lift()
	var heading:float=blimp.hull_angle
	blimp.receive_hit(100000)
	var wreck = falling_hull()
	check(wreck != null and blimp._dead and is_equal_approx(wreck.splinters.height,lift),"lethal hit creates a hull at actual flight height")
	if wreck == null: return
	check(wreck.splinters.warhead=="YR_SOV_KTSTLEXP" and is_equal_approx(wreck.splinters.damage,crash_damage),"elite crash preserves elite warhead and firepower")
	wreck._physics_process(0.65)
	var mid: float = wreck.splinters.height
	var at: Vector2 = wreck.position
	check(mid > 0 and mid < lift and at.is_equal_approx(point) and is_equal_approx(angle_difference(heading,wreck.splinters.heading),-deg_to_rad(58.5)),"hull rotates and descends over its crash site")
	if DisplayServer.get_name() != "headless":
		battle.camera.position = at
		battle.camera.zoom = Iso.cam_zoom(1.5)
		battle.camera.reset_smoothing()
		battle.camera.force_update_scroll()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center := Vector2i(wreck.get_global_transform_with_canvas().origin)
		get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(155,195),Vector2i(310,265))).save_png(output_dir.path_join("kirov-falling.png"))
	battle.paused = true
	wreck._physics_process(10.0)
	check(wreck.position==at and wreck.splinters.height==mid,"pause freezes wreck")
	battle.paused = false
	var saved := BattleSaves.save_slot(battle,"slot2")
	var disk := BattleSaves.read_slot("slot2")
	check(saved.ok and disk.ok,"save crash in flight")
	if not disk.ok: return
	BattleSaves.Snapshot.new().restore(battle,disk.snapshot)
	battle.paused=false
	get_tree().paused=false
	wreck=falling_hull()
	check(wreck!=null and is_equal_approx(wreck.splinters.height,mid),"restored hull resumes at saved height")
	if wreck==null: return
	var near = battle.spawn_unit("HTNK","enemy",point+Vector2(21,0))
	var far = battle.spawn_unit("HTNK","enemy",point+Vector2(500,0))
	var plane = battle.spawn_unit("ZEP","enemy",near.position)
	plane.logistics.air_lift=1.0
	var building = battle._place_building("GAPOWR","ally",point+Vector2(40,0),true)
	wreck._physics_process(0.1)
	check(near.hp==near.max_hp and building.hp==building.max_hp,"no ground blast before contact")
	wreck._physics_process(10.0)
	check(wreck._detonated and wreck.is_queued_for_deletion() and near.hp<near.max_hp and building.hp<building.max_hp,"contact damages nearby armour and building")
	check(far.hp==far.max_hp and plane.hp==plane.max_hp,"impact excludes out of range and airborne targets")
	var after: float=near.hp
	wreck._physics_process(1.0)
	check(near.hp==after,"touchdown resolves only once")
	plane._die(null,true)
	check(falling_hull()==null,"temporal erasure spawns no wreck")
	var water:=Vector2(2300,1000)
	battle.water_rects=[Rect2(water-Vector2(200,200),Vector2(400,400))]
	battle.path_service.set_water(battle.water_rects)
	if battle.fog!=null: battle.fog.free();battle.fog=null
	var naval_blimp=battle.spawn_unit("ZEP","ally",water)
	naval_blimp.logistics.air_lift=1.0
	naval_blimp.receive_hit(100000)
	var water_wreck=falling_hull()
	var ship=battle.spawn_unit("HYD","enemy",water)
	if water_wreck!=null:
		water_wreck._physics_process(8.0)
	var splash_files:Array=GameData.ra2_sound_files("ExplosionWaterLarge")
	var water_audio:=false
	for clip in splash_files:
		var sample:=Ra2Sfx._stream(clip)
		if sample!=null and Ra2Sfx._pool.any(func(channel):return channel.stream==sample):water_audio=true
	check(water_wreck!=null and water_wreck._detonated and ship.hp<ship.max_hp and water_audio,"ordinary crash at sea damages surface ships and plays original water impact",[water_wreck!=null,ship.hp,ship.max_hp,water_audio,splash_files,battle.in_water_world(water),battle.paused,battle.ended])
