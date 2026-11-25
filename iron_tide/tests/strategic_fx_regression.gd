extends "res://tests/special_mechanics_regression.gd"
const Special = preload("res://scripts/units/soviet_specials.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		arena(mode)
		if battle.fog!=null: battle.fog.free();battle.fog=null
		check_silo_targeting()
		await finish()
		arena(mode)
		if battle.fog!=null: battle.fog.free();battle.fog=null
		await strategic()
		await finish()
		arena(mode)
		await bombs()
		await finish()
		arena(mode)
		radiation_steps()
		await finish()
	var f:=FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	f.close()
	Ra2Sfx.stop_all()
	get_tree().quit(0 if failed==0 else 1)

func photo(site: Vector2, slug: String) -> void:
	if DisplayServer.get_name()=="headless": return
	battle.camera.position=site
	battle.camera.zoom=Iso.cam_zoom(1.45)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.hp_overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(slug+".png"))

func hull_image(unit) -> Image:
	var center := Vector2i(unit.get_canvas_transform()*unit.art_center())
	return get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(12,12),Vector2i(24,24)))

func hull_luminance(image:Image) -> float:
	var total := 0.0
	for y in image.get_height():
		for x in image.get_width(): total += image.get_pixel(x,y).get_luminance()
	return total

func check_silo_targeting() -> void:
	var silo = add("NAMISL", "enemy", AIM)
	var tank = spawn("MTNK", "ally", AIM + Vector2(210, 0))
	battle.select_unit(tank, false)
	var rect := RA2Art.draw_rect(silo._ra2, silo.radius, [0], 0, Building.RA2_SPRITE_SCALE)
	var pad := rect.position + Vector2(65.5, 142.5)
	var roof := rect.position + Vector2(118.5, 74.5)
	var shell := rect.position + Vector2(118.5, 16.5)
	var collider: CollisionPolygon2D = silo.find_children("*", "CollisionPolygon2D", false, false)[0]
	check(Geometry2D.is_point_in_polygon(Building.art_to_ground(pad), collider.polygon), prefix + "silo side apron blocks units")
	check(not Geometry2D.is_point_in_polygon(Building.art_to_ground(roof), collider.polygon), prefix + "silo tower height adds no ground blocker")
	battle._refresh_pathing()
	var path = battle.path_service
	var cell: Vector2i = path._cell_of(AIM + Building.art_to_ground(pad))
	check(path.cost[cell.y * path.cols + cell.x] < 0, prefix + "path map includes silo side apron")
	for ratio in [1.0, 0.4]:
		silo.hp = silo.max_hp * ratio
		for pose in ["E", "F", "G", "H"]:
			silo.special.erase("sw_discharge_age")
			silo._sw_charge = {"E": 0.0, "F": silo.sw_recharge() - 59, "G": silo.sw_recharge(), "H": 0.0}[pose]
			if pose == "H": silo.special.sw_discharge_age = 0.0
			var active: Dictionary = silo._ra2_anim.filter(func(l): return silo._layer_visible(l.kind))[0]
			var state: Dictionary = silo._anim_layer(active)
			var art := RA2Art.art(state.image)
			var img := RA2Art.sprite_image(art)
			var src := Rect2i(RA2Art.src_rect(art, silo._anim_frame_for(active, state)))
			var matches := true
			# Sample the moving upper silhouette, including air between the open doors.
			for y in range(4, 106, 5):
				for x in range(55, 181, 5):
					var p := Vector2i(x, y)
					var at := AIM + RA2Art.art_dir(rect.position + Vector2(p) + Vector2(0.5, 0.5))
					if silo.hit_test(at) != (img.get_pixelv(src.position + p).a * 255 >= 20): matches = false
			check(state.image == "NAMISL_" + pose and matches, prefix + "visible silo silhouette " + pose + " health " + str(ratio))
			check(silo.hit_test(AIM + RA2Art.art_dir(pad)), prefix + "side apron targetable in " + pose)
			if pose == "E" or pose == "G":
				var point := AIM + RA2Art.art_dir(roof if pose == "E" else shell)
				check(battle.command_cursor.resolve(point) == "attack", prefix + "attack cursor on " + pose)
				tank.order_stop()
				battle._issue_order(point)
				check(tank.attack_target == silo, prefix + "right-click targets silo on " + pose)
	silo._fp_poly = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	var codec := Snapshot.new()
	codec.restore(battle, codec.capture(battle))
	var restored = battle.buildings.filter(func(b): return b.building_id == "NAMISL")[0]
	check(Geometry2D.is_point_in_polygon(Building.art_to_ground(pad), restored.footprint_poly()), prefix + "legacy footprint refreshed on load")
	battle.paused = false
	get_tree().paused = false

func check_silo_opening(silo) -> void:
	var original_hp: float = silo.hp
	for ratio in [1.0,0.4]:
		silo.hp = original_hp * ratio
		var opening: Dictionary = silo._ra2_anim.filter(func(l): return l.kind == "superanimtwo")[0]
		var state: Dictionary = silo._anim_layer(opening)
		var art := RA2Art.art(state.image)
		var image: Image = art.tex.get_image()
		var apron: Image = silo._ra2.tex.get_image()
		var base := Rect2i(RA2Art.src_rect(silo._ra2,silo._body_damage_frame()))
		var complete := true
		var ordered := true
		for i in 16:
			silo._sw_charge = silo.sw_recharge() - 60 + (i + 0.5) * 60.0 / state.rate
			var frame: int = silo._anim_frame_for(opening,state)
			ordered = ordered and frame == state.loopStart + i and silo._ra2_anim.filter(func(l): return silo._layer_visible(l.kind)).size() == 1 and silo._layer_visible(opening.kind)
			var rect := Rect2i(RA2Art.src_rect(art,frame))
			for y in base.size.y:
				for x in base.size.x:
					var pos := Vector2i(x,y)
					if apron.get_pixelv(base.position+pos).a > 0.5 and image.get_pixelv(rect.position+pos).a < 0.5: complete = false
		check(ordered and complete,prefix+"all sixteen opening poses keep the apron registered on one canvas at HP "+str(ratio))
		silo._tick_superweapon(60)
		var ready: Dictionary = silo._ra2_anim.filter(func(l): return l.kind == "superanimthree")[0]
		var ready_state: Dictionary = silo._anim_layer(ready)
		var held := RA2Art.art(ready_state.image)
		var final_frame := Rect2i(RA2Art.src_rect(art,state.loopEnd))
		var held_frame := Rect2i(RA2Art.src_rect(held,ready_state.loopStart))
		var last := image.get_region(final_frame)
		var next: Image = held.tex.get_image().get_region(held_frame)
		var matches := true
		for y in last.get_height():
			for x in last.get_width():
				var a := last.get_pixel(x,y)
				var b := next.get_pixel(x,y)
				# Godot extends RGB into fully transparent atlas borders at import.
				if a.a != b.a or (a.a > 0 and a != b): matches = false
		check(silo._layer_visible(ready.kind) and matches,prefix+"fully open pose matches visible ready sprite pixel for pixel")
	silo.hp = original_hp

func strategic() -> void:
	var silo=add("NAMISL","ally",Vector2(1100,1100))
	var iron=add("NAIRON","ally",Vector2(1550,1150))
	var tank=spawn("HTNK","ally",Vector2(1520,1210))
	var target=add("GAWEAP","enemy",Vector2(1800,1750))
	battle.power_low=false
	check_silo_opening(silo)
	for b in [silo,iron]:
		b._sw_charge=b.sw_recharge()-60
		check(b._layer_visible("superanimtwo"),prefix+"uses charge-start layer "+b.building_id)
		b._sw_charge=b.sw_recharge()
		check(b._layer_visible("superanimthree"),prefix+"uses charged loop "+b.building_id)
	var walker=spawn("R3REAPER","ally",tank.position+Vector2(-50,0)) if BattleRequest.extensions_enabled() else null
	var walker_before: Image
	if walker!=null and DisplayServer.get_name()!="headless":
		walker.set_selected(true)
		await photo(walker.position,"reaper-before")
		walker_before = hull_image(walker)
	check(iron.fire_superweapon(tank.position) and tank.modulate.r<0.6,prefix+"shield immediately tints vehicle")
	await photo(tank.position,"iron-curtain")
	check(battle.effects_root.get_children().any(func(f): return f is Ra2Fx and f.anim.image=="IRONBLST"),prefix+"native cast animation")
	for protected_actor in [tank,iron,walker]:
		if protected_actor==null: continue
		var before:float=protected_actor.hp
		protected_actor.receive_hit(60)
		var effect=protected_actor.get_meta("iron_deflection",null)
		check(effect is Ra2Fx and effect.anim.image=="IRONFX" and effect.anim.sound=="IronCurtainDeflect" and effect.position.is_equal_approx(protected_actor.art_center()),prefix+"native impact flash at struck "+protected_actor.display_name)
		protected_actor.receive_hit(60)
		check(protected_actor.hp==before and protected_actor.get_meta("iron_deflection")==effect,prefix+"absorbed burst shares one deflection")
	if walker_before!=null:
		# Compare the protected model by itself after the one-shot cast and deflect FX.
		for effect in battle.effects_root.get_children():
			if effect is Ra2Fx: effect.hide()
		Special.tick_actor(walker,0.5)
		await photo(walker.position,"reaper-protected")
		var impact=walker.get_meta("iron_deflection")
		impact.show()
		impact._process(0.2)
		await photo(walker.position,"reaper-deflection")
		var center := Vector2i(walker.get_canvas_transform()*walker.art_center())
		get_viewport().get_texture().get_image().get_region(Rect2i(center-Vector2i(110,85),Vector2i(220,170))).save_png(output_dir.path_join("reaper-hit.png"))
		impact.queue_free()
		await get_tree().process_frame
		walker.receive_hit(25)
		var next = walker.get_meta("iron_deflection")
		check(is_instance_valid(next) and not next.is_queued_for_deletion(),prefix+"later hits renew the expired deflection")
		next.hide()
		await photo(walker.position,"reaper-protected")
		var dark := hull_image(walker)
		check(hull_luminance(dark)<hull_luminance(walker_before)*0.75,prefix+"selected 3D Reaper hull visibly darkens")
		Special.tick_actor(walker,51)
		await photo(walker.position,"reaper-expired")
		check(hull_luminance(hull_image(walker))>hull_luminance(dark)*1.35,prefix+"3D hull brightens when protection expires")
	check(silo.fire_superweapon(target.position),prefix+"silo launches")
	var launch:Dictionary=battle.allied_state.soviet_nukes[0]
	var old_pose:=Special.missile_pose({"point":target.position,"side":"ally","left":0.8})
	check(old_pose.image=="NKMSLDN" and old_pose.show,prefix+"pre-update pending impact stays compatible")
	Special.tick_world(battle,3.0)
	var pose:=Special.missile_pose(launch)
	check(pose.image=="NKMSLUP" and pose.point==silo.position and pose.lift>80,prefix+"native ascending missile and exhaust at source")
	await photo(silo.position,"nuke-ascent")
	var snapshot:=Snapshot.new().capture(battle)
	var remaining:float=launch.left
	Snapshot.new().restore(battle,snapshot)
	var restored=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(restored.modulate.r<0.6 and battle.paused,prefix+"shield tint visible on paused restore")
	launch=battle.allied_state.soviet_nukes[0]
	Special.tick_world(battle,4)
	check(is_equal_approx(remaining,launch.left),prefix+"paused save freezes airborne missile")
	battle.paused=false;get_tree().paused=false;battle.ended=false
	silo=battle.buildings.filter(func(b):return b.building_id=="NAMISL")[0]
	target=battle.buildings.filter(func(b):return b.building_id=="GAWEAP")[0]
	var hp:float=target.hp
	silo._die()
	Special.tick_world(battle,launch.left-0.35)
	pose=Special.missile_pose(launch)
	check(pose.point==target.position and pose.image=="NKMSLDN" and target.hp==hp,prefix+"silo destruction does not cancel payload")
	await photo(target.position,"nuke-descent")
	Special.tick_world(battle,0.36)
	var hit:float=target.hp
	Special.tick_world(battle,0.01)
	check(hit<hp and hit==target.hp and not battle.allied_state.has("soviet_nukes") and battle.allied_state.get("rad_sites",[]).size()==1,prefix+"single impact damage and native radiation")
	for id in ["NUKETO","NUKEPUFF","NUKEBALL","NUKEANIM","IRONBLST"]:
		check(not RA2Art.fx(id).is_empty(),prefix+"native FX "+id)

func bombs() -> void:
	var host=spawn("HTNK","enemy",Vector2(1200,1200))
	var ivan=spawn("CIVAN","ally",Vector2(950,1200))
	check(AlliedAbilities.teleport(ivan,host.position+Vector2(42,0)) and not Special.accepts_bomb(ivan,host),prefix+"chrono arrival recovery prevents planting")
	AlliedAbilities.tick_actor(ivan,50.0)
	check(Special.accepts_bomb(ivan,host),prefix+"chrono Ivan can plant after recovery")
	ivan._fire_shot(host)
	Special.tick_actor(host,1.0/15)
	check(host.special.has("ivan_bomb") and host.has_node("IvanTick") and not Special.accepts_bomb(ivan,host),prefix+"one charge and one attached ticking sound")
	check(Special.bomb_frame(30.0,13)==0 and Special.bomb_frame(29.4,13)==1 and Special.bomb_frame(1.0,13)>=10,prefix+"native eight-tick flicker and shortening fuse")
	await photo(host.position,"ivan-fuse")
	var neighbour=spawn("HTNK","enemy",host.position+Vector2(25,0))
	var hp:float=neighbour.hp
	host._die()
	check(not host.has_node("IvanTick") and not host.special.has("ivan_bomb") and neighbour.hp<hp,prefix+"carrier destroyed detonates once and removes ticking")
	var plain=spawn("IVAN","ally",Vector2(1800,1700))
	var carrier=spawn("BFRT","ally",plain.position)
	plain.set_stowed(carrier)
	check(not Special.accepts_bomb(plain,neighbour) and not plain._weapon_domain_valid(neighbour),prefix+"IvanBomber cannot plant from open-topped fortress")
	plain.set_stowed(null)
	var marked=spawn("HTNK","enemy",Vector2(1850,1750))
	plain._fire_shot(marked)
	var witness=spawn("HTNK","enemy",marked.position+Vector2(20,0))
	marked._die(null,true)
	check(witness.hp==witness.max_hp and not marked.special.has("ivan_bomb"),prefix+"temporal erasure removes without blast")

	# No unit death, weapon impact or nearby infantry can supply incidental audio.
	var site = add("GAPOWR", "enemy", Vector2(460, 680))
	var planter = spawn("IVAN", "ally", site.position + Vector2.RIGHT * 30)
	planter._fire_shot(site)
	planter.position = Vector2(2200, 2200)
	site.hp = 10000.0
	Special.tick_actor(site, 29.9)
	Ra2Sfx.stop_all()
	var plays: int = Ra2Sfx.a_plays
	var clip = Ra2Sfx._stream("gexpcraa.wav")
	Special.tick_actor(site, 0.11)
	var heard := Ra2Sfx._pool.any(func(p): return p.playing and p.stream == clip and p.global_position.is_equal_approx(site.global_position))
	check(site.hp > 0 and heard and Ra2Sfx.a_plays == plays + 1, prefix + "isolated timer expiry plays the original Ivan explosion once at the blast site")
	Special.tick_actor(site, 1.0)
	check(Ra2Sfx.a_plays == plays + 1, prefix + "spent charge does not replay its report")

func radiation_steps() -> void:
	var p:=Vector2(2100,1800)
	var deso=spawn("DESO","enemy",p)
	var victims:Array=[]
	for offset in [0,110,198,221]:
		var tank=spawn("MTNK","ally",p+Vector2(offset,0))
		tank.bonuses={}
		victims.append(tank)
	deso.set_deployed(true)
	deso._cd_timer=0
	deso._physics_process(1.0/60)
	var interval:float=Special.radiation_rules().interval
	var initial:Array=victims.map(func(t):return t.hp)
	Special.tick_world(battle,interval+0.000001)
	var damage:Array=[]
	for i in victims.size():damage.append(initial[i]-victims[i].hp)
	check(damage==[10.0,5.0,1.0,0.0],"deployed radiation damage at center, half, rim and outside",damage)
	for i in 4:Special.tick_world(battle,interval)
	check(initial[0]-victims[0].hp==50,"first five pulses retain full native intensity")
	Special.tick_world(battle,interval)
	check(initial[0]-victims[0].hp==58,"sixth pulse after first 90-tick decay deals eight")
	battle.allied_state.erase("rad_sites")
	Special.sync_radiation(battle)
	for u in victims+[deso]:
		battle.units.erase(u)
		u.free()
