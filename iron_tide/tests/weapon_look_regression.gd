extends "res://tests/naval_regression.gd"
const Garrison=preload("res://scripts/units/civilian_orders.gd")

func exercise_mode(mode:String) -> void:
	var original:=MetaProgress.unit_cosmetics.duplicate(true)
	var original_owned:=MetaProgress.owned_cosmetics.duplicate()
	for value in Effects.Looks.CHOICES.values()+["winter","night_shift","ice","wine","star","crystal","angel","demon"]:
		MetaProgress.owned_cosmetics[value]=true
	var shop=load("res://scenes/paint.tscn").instantiate()
	stage.add_child(shop)
	shop.series.select(2);shop._list_units()
	shop._select_unit("NABNKR")
	var picker:OptionButton=shop.slots.find_child("weapon_fx",true,false)
	picker.select(1);picker.item_selected.emit(1)
	check(shop.fx_host.get_child_count()==1 and shop.fx_host.get_child(0).style=="cyber_hit",mode+" workshop plays selected bunker impact")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var crop:=Rect2i(shop.fx_strip.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,stage.size))
	if crop.has_area():stage.get_texture().get_image().get_region(crop).save_png(output_dir.path_join(mode+"-bunker.png"))
	picker.select(0);picker.item_selected.emit(0)
	check(shop.fx_button.disabled and not MetaProgress.cosmetic_style("NABNKR").has("weapon_fx"),mode+" selecting stock clears the override")
	shop.series.select(1);shop._list_units()
	for id in ["TERROR","DTRUCK"]:
		shop._select_unit(id)
		picker=shop.slots.find_child("weapon_fx",true,false)
		picker.select(1);picker.item_selected.emit(1)
		shop.fx_button.pressed.emit()
		var sample=shop.fx_host.get_child(0)
		check(sample.style=="love_peace" and shop.fx_host.get_child_count()==1,mode+" "+id+" workshop heart burst")
		sample.age=0.44;sample.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if id=="TERROR" and mode==MatchRules.RA2:
			var rect:=Rect2i(shop.fx_strip.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,stage.size))
			stage.get_texture().get_image().get_region(rect).save_png(output_dir.path_join("love-peace-preview.png"))
		sample.set_process(false)
		sample._process(0.93)
		check(not sample.is_queued_for_deletion(),mode+" "+id+" burst survives to show its final heart")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if id=="TERROR" and mode==MatchRules.RA2:
			var rect:=Rect2i(shop.fx_strip.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,stage.size))
			stage.get_texture().get_image().get_region(rect).save_png(output_dir.path_join("love-peace-finale.png"))
		sample._process(0.50)
		check(sample.is_queued_for_deletion(),mode+" "+id+" final heart expires")

	for id in ["NAFLAK","HTK","HYD"]:
		shop.series.select(2 if id=="NAFLAK" else 1);shop._list_units()
		var listed:=false
		for i in shop.units.item_count:
			if shop.units.get_item_metadata(i)==id:
				shop.units.select(i);shop.units.item_selected.emit(i)
				listed=true
				break
		check(listed,mode+" workshop lists "+id)
		picker=shop.slots.find_child("weapon_fx",true,false)
		picker.select(1);picker.item_selected.emit(1)
		check(shop.fx_host.get_child(0).style=="pixel_blast",mode+" "+id+" previews same infantry BLAST")
	shop.series.select(0);shop._list_units()
	shop._select_unit("R3APOC")
	picker=shop.slots.find_child("weapon_fx",true,false)
	picker.select(1);picker.item_selected.emit(1)
	shop.fx_button.pressed.emit()
	var samples=shop.fx_host.get_children()
	check(samples.size()==2 and samples[0].muzzle and not samples[1].muzzle,mode+" Apocalypse workshop previews both events")
	for sample in samples:
		sample.age=0.07 if sample.muzzle else 0.15
		sample.set_process(false);sample.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if mode==MatchRules.EXTENDED:
		var rect:=Rect2i(shop.fx_strip.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,stage.size))
		stage.get_texture().get_image().get_region(rect).save_png(output_dir.path_join("blue-arc.png"))
	shop.series.select(1);shop._list_units();shop._select_unit("SREF")
	picker=shop.slots.find_child("weapon_fx",true,false)
	picker.select(1);picker.item_selected.emit(1)
	for hue in ["prism_blue","prism_red"]:
		if hue=="prism_red":shop.fx_button.pressed.emit()
		var rays=shop.fx_host.get_children()
		check(rays.size()==3 and rays.filter(func(ray):return ray.branch).size()==2 and rays.all(func(ray):return ray.look==hue),mode+" duplex workshop previews both split rays "+hue)
	shop.free()
	BattleRequest.configure_skirmish(mode,{"map_size":3200,"starting_funds":9000})
	screen=load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen);battle=screen.battle
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	GM.god_mode=false;GM.one_shot_kill=false
	var at:=Vector2(1600,1600)
	var tank=actor("MTNK","enemy",at)
	var neighbor=actor("MTNK","enemy",at+Vector2(35,5))
	var plane=actor("JUMPJET","enemy",at+Vector2(5,0))
	plane.logistics.air_lift=50
	for victim in [tank,neighbor,plane]:victim.hp=100000;victim.max_hp=100000
	check_signature_weapons(tank,plane,mode)
	var ship=actor("DEST","enemy",at+Vector2(0,110))
	ship.hp=100000;ship.max_hp=100000
	for entry in ["TTNK","SHK","SREF","FLAKT","HTK","HTK_ground","HYD","HYD_ground","HYD_surface","NABNKR"]:
		var id:String=str(entry).get_slice("_",0)
		var u=actor("E2" if id=="NABNKR" else id,"ally",at-Vector2(175,0))
		var target=plane if entry in ["FLAKT","HTK","HYD"] else tank
		if entry=="HYD_surface":target=ship
		var bunker
		if id=="NABNKR":
			bunker=battle._place_building("NABNKR","ally",u.position,true)
			bunker._buildup_play=-1.0
			Garrison.enter(u,bunker)
			check(u.embarked_in==bunker,mode+" gunner actually enters bunker")
		u.attack_target=target;u.attack_ordered=true
		for rank in [0,2]:
			u._grant_veteran(rank,false)
			var baseline:=0.0
			for volley in 3:
				var style:String=Effects.Looks.CHOICES[id] if volley>0 else "stock"
				MetaProgress.set_cosmetic(id,"weapon_fx",style)
				var first:int=battle.effects_root.get_child_count()
				var aim_point:=Vector2.INF
				var projectiles:Node=u._pick_projectile_parent()
				var start:int=projectiles.get_child_count()
				var hp:float=target.hp
				seed(96)
				u._fire_shot(target)
				for i in range(start,projectiles.get_child_count()):
					var shot=projectiles.get_child(i)
					if shot is Projectile:
						aim_point=shot.target_point+RA2Art.art_dir(Vector2.UP*float(shot.splinters.visual_target_lift))
						for tick in 300:
							if shot.is_queued_for_deletion():break
							shot._physics_process(1.0/60)
				var observed:=[]
				for i in range(first,battle.effects_root.get_child_count()):
					var fx=battle.effects_root.get_child(i)
					if fx is Effects.Beam:observed.append(fx.look)
					if fx.get_script()==Effects.Looks:
						observed.append(fx.style)
						if id in ["FLAKT","HTK","HYD"]:check(fx.position.is_equal_approx(aim_point) if aim_point.is_finite() else fx.position.is_equal_approx(Effects.hit_position(target)),mode+" "+entry+" flak burst at impact")
				if volley==0:
					baseline=hp-target.hp
					check(baseline>0 and observed.all(func(x):return x==""),mode+" "+id+" stock hits without cosmetic")
				else:
					var expected:String=("prism_blue" if volley==1 else "prism_red") if id=="SREF" else style
					check(expected in observed and is_equal_approx(hp-target.hp,baseline),mode+" "+id+" rank "+str(rank)+" real hit uses selected visual with stock damage",[observed,hp-target.hp,baseline])
					if id=="SREF":
						check(observed.count(expected)>1 and not observed.has("prism_blue" if volley==2 else "prism_red"),mode+" same colour on secondary prism rays",observed)
		if id=="NABNKR":
			Garrison.withdraw(bunker,u)
			check(Effects.Looks.current(u)=="",mode+" infantry outside bunker does not inherit hit marker")
		if id=="SHK":check_trooper_emitter(u,target,mode)
		remove_actor(u)
	MetaProgress.set_cosmetic("TTNK","weapon_fx","spectrum")
	var hostile=actor("TTNK","enemy",at)
	check(Effects.Looks.current(hostile)=="",mode+" enemy uses its original weapon art")
	if mode==MatchRules.EXTENDED:
		await check_apocalypse_look(tank)
		MetaProgress.set_cosmetic("R3TESLA","weapon_fx","spectrum")
		var r3=actor("R3TESLA","ally",at-Vector2(100,0))
		r3.special.ra3_barrel=0
		for rank in [0,3]:
			r3._grant_veteran(rank,false)
			var line=preload("res://scripts/units/ra3_tank_beam.gd").spawn(r3,tank,false)
			check(r3.veteran_level==rank and is_instance_valid(line) and not line.layers.is_empty() and line.layers.all(func(row):return row.line.texture==Effects.Looks.SPECTRUM),mode+" RA3 Tesla rank "+str(rank)+" uses equipped spectrum texture")
	MetaProgress.set_cosmetic("TESLA","weapon_fx","spectrum")
	var coil=battle._place_building("TESLA","ally",at-Vector2(130,0),true)
	coil._buildup_play=-1.0
	coil.attack_target=tank
	var begin:int=battle.effects_root.get_child_count()
	coil._fire()
	var found:=false
	for i in range(begin,battle.effects_root.get_child_count()):
		var effect=battle.effects_root.get_child(i)
		if effect is Effects.ElectricBolt and effect.look=="spectrum":found=true
	check(found,mode+" shore coil uses selected bolt")
	var flak=battle._place_building("NAFLAK","ally",at-Vector2(130,0),true)
	flak._buildup_play=-1
	flak.attack_target=plane
	flak._turret_art.turn_toward(plane.position-flak.position,120,flak._turret_turn_speed)
	var stock_damage:=0.0
	for style in ["stock","pixel_blast"]:
		MetaProgress.set_cosmetic("NAFLAK","weapon_fx",style)
		var first:int=battle.effects_root.get_child_count()
		var hp:float=plane.hp
		var start:int=battle.projectiles_root.get_child_count()
		seed(96)
		check(flak._fire(),mode+" flak cannon fires at airborne target")
		var contact:=Vector2.INF
		for shot in battle.projectiles_root.get_children().slice(start):
			if shot is Projectile:
				contact=shot.target_point+RA2Art.art_dir(Vector2.UP*float(shot.splinters.visual_target_lift))
		var bursts:=0
		for fx in battle.effects_root.get_children().slice(first):
			if fx.get_script()==Effects.Looks and fx.style=="pixel_blast" and fx.position.is_equal_approx(contact):bursts+=1
		if style=="stock":stock_damage=hp-plane.hp
		check(stock_damage>0 and is_equal_approx(hp-plane.hp,stock_damage) and bursts==int(style=="pixel_blast"),mode+" flak cannon "+style+" airburst at aircraft altitude with stock damage")
	var paratrooper=battle.spawn_unit("E1","enemy",plane.position)
	paratrooper.hp=10000
	flak.attack_target=paratrooper
	for height in [120.0,42.0]:
		paratrooper.special.para_height=height
		paratrooper.special.para_age=0.0
		var expected:Vector2=paratrooper.position+RA2Art.art_dir(Vector2.UP*height)
		check(Effects.hit_position(paratrooper).is_equal_approx(expected),mode+" hit text follows descending infantry")
		for style in ["stock","pixel_blast"]:
			MetaProgress.set_cosmetic("NAFLAK","weapon_fx",style)
			var start:int=battle.projectiles_root.get_child_count()
			var first:int=battle.effects_root.get_child_count()
			check(flak._fire(),mode+" flak fires at parachute "+style)
			var raised:=false
			for shot in battle.projectiles_root.get_children().slice(start):
				if shot is Projectile:
					var contact:Vector2=shot.target_point+RA2Art.art_dir(Vector2.UP*height)
					raised=is_equal_approx(shot.splinters.visual_target_lift,height) and battle.effects_root.get_children().slice(first).any(func(fx):return fx is Node2D and fx.position.is_equal_approx(contact) and (style=="stock" or fx.get_script()==Effects.Looks))
			check(raised,mode+" real flak impact uses parachute height "+style+" "+str(height))
	paratrooper.special.erase("para_height")
	check(Effects.hit_position(paratrooper)==paratrooper.position,mode+" landed infantry uses ground hit position")
	check_suicide_looks(mode)
	await check_tank_emitter(mode)
	screen.free()
	MetaProgress.owned_cosmetics=original_owned
	MetaProgress.unit_cosmetics=original
	MetaProgress.save()
	await get_tree().process_frame

func check_trooper_emitter(trooper:Unit,target:Unit,mode:String) -> void:
	var sprite:Image=trooper._ra2.img
	var cell:=RA2Art.draw_rect(trooper._ra2,trooper.radius,range(8))
	for look in ["stock","spectrum"]:
		MetaProgress.set_cosmetic("SHK","weapon_fx",look)
		var tested:Dictionary={}
		for i in 8:
			trooper.hull_angle=Iso.eff_angle()+i*TAU/8
			trooper.aim_dir=Vector2.from_angle(trooper.hull_angle)
			target.position=trooper.position+trooper.aim_dir*120
			var first:int=battle.effects_root.get_child_count()
			trooper._fire_shot(target)
			var facing:=RA2Art.facing_index(trooper.hull_angle,8)
			var frame:=RA2Art.seq_frame(trooper._seq,"FireUp",facing,0)
			var source:=RA2Art.src_rect(trooper._ra2,frame)
			for j in range(first,battle.effects_root.get_child_count()):
				var bolt=battle.effects_root.get_child(j)
				if not bolt is Effects.ElectricBolt:continue
				var pixel:=Vector2i((Iso.dir(bolt.from-trooper.position)-cell.position).floor())
				if not Rect2i(Vector2i.ZERO,Vector2i(cell.size)).has_point(pixel):continue
				var c:=sprite.get_pixelv(Vector2i(source.position)+pixel)
				if c.a>0.9 and is_equal_approx(c.r,c.g) and c.b-c.r>0.14:
					tested[facing]=true
		check(tested.size()==8,mode+" "+look+" emitted bolts start on the violet SHP electrode in all eight facings",tested.keys())

func check_tank_emitter(mode:String) -> void:
	var tank:Unit=actor("TTNK","ally",Vector2(2180,1800))
	var target=ForceFirePoint.new()
	target.global_position=tank.position+Vector2(125,0)
	tank.order_target(target,true,false)
	tank.hull_angle=0
	var art:=tank._ra2_tur
	var cell:=RA2Art.draw_rect(tank._ra2,tank.radius,range(32))
	var origins:Array=tank._weapon_art.get("origins",[])
	check(origins.size()==32,mode+" Tesla tank has turret origins for all 32 facings")
	if origins.size()!=32:return
	battle.camera.position=tank.position
	battle.camera.zoom=Iso.cam_zoom(2.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for look in ["stock","spectrum"]:
		MetaProgress.set_cosmetic("TTNK","weapon_fx",look)
		tank._grant_veteran(2 if look=="spectrum" else 0,false)
		var seen:Dictionary={}
		for i in 32:
			tank.turret_angle=Iso.eff_angle()-PI/2+i*TAU/32
			tank.aim_dir=Vector2.from_angle(tank.turret_angle)
			target.global_position=tank.position+125*tank.aim_dir
			var first:int=battle.effects_root.get_child_count()
			tank._fire_shot(target)
			var frame:=tank._sprite_facing(art,tank.turret_angle)
			var az:=PI/4-frame*TAU/32
			var forward:=60.0*Ra2Damage.PX_PER_CELL/256.0
			var height:=100.0*Ra2Damage.PX_PER_CELL/256.0
			var origin:=Vector2(origins[frame][0],origins[frame][1])
			var expected:=origin+Vector2(-forward*sin(az),forward*cos(az)*0.5-height*sqrt(0.75))
			for fx in battle.effects_root.get_children().slice(first):
				if fx is Effects.ElectricBolt and fx.look==("" if look=="stock" else look):
					var actual:=Iso.dir(fx.from-tank.position)-cell.position
					var source:=RA2Art.src_rect(art,frame)
					var pixel:=Vector2i(source.position+actual.floor())
					var atlas:Image=art.img
					if actual.distance_to(expected)<7.0 and atlas.get_pixelv(pixel).a>=0.75:seen[frame]=true
			if i==0 and look=="spectrum" and mode==MatchRules.RA2:
				tank.queue_redraw()
				await RenderingServer.frame_post_draw
				var pos:=tank.get_global_transform_with_canvas().origin
				var crop:=Rect2i(Vector2i(pos)-Vector2i(135,240),Vector2i(270,290)).intersection(Rect2i(Vector2i.ZERO,stage.size))
				if crop.has_area():stage.get_texture().get_image().get_region(crop).save_png(output_dir.path_join("tesla-tank-shot.png"))
			for fx in battle.effects_root.get_children().slice(first):fx.free()
		check(seen.size()==32,mode+" "+look+" actual bolts follow the native turret FLH with a fixed hull",seen.keys())

func check_suicide_looks(mode:String) -> void:
	var point:=Vector2(1580,1220)
	var victim=actor("MTNK","enemy",point+Vector2(12,0))
	victim.hp=100000;victim.max_hp=100000
	for id in ["TERROR","DTRUCK"]:
		var baseline:=0.0
		for style in ["stock","love_peace"]:
			point+=Vector2(85,0)
			victim.position=point+Vector2(12,0)
			var bomber=actor(id,"ally",point)
			MetaProgress.set_cosmetic(id,"weapon_fx",style)
			var first:int=battle.effects_root.get_child_count()
			var hp:float=victim.hp
			bomber.attack_target=victim
			bomber._fire_shot(victim)
			var bursts:=0
			for fx in battle.effects_root.get_children().slice(first):
				if fx.get_script()==Effects.Looks and fx.style=="love_peace" and fx.position==point:bursts+=1
			if style=="stock":baseline=hp-victim.hp
			check(bomber._dead and baseline>0 and is_equal_approx(hp-victim.hp,baseline) and bursts==int(style=="love_peace"),mode+" "+id+" "+style+" detonates once at bomber with stock area damage")
			if id=="DTRUCK":check(battle.allied_state.get("rad_sites",[]).any(func(site):return site.point==point and site.level==100),mode+" "+style+" truck leaves radiation")
	remove_actor(victim)

func check_apocalypse_look(victim:Unit) -> void:
	const Soviet=preload("res://scripts/units/ra3_soviet.gd")
	var apoc:Unit=actor("R3APOC","ally",victim.position-Vector2(95,0))
	apoc.attack_target=victim;apoc.attack_ordered=true
	apoc.hull_angle=0;apoc.turret_angle=0
	for rank in [0,3]:
		apoc._grant_veteran(rank,false)
		var baseline:=0.0
		for look in ["stock",Effects.Looks.BlueArc.ID]:
			apoc.special.soviet_mounts={}
			for barrel in 2:
				MetaProgress.set_cosmetic("R3APOC","weapon_fx",look)
				var first:int=battle.effects_root.get_child_count()
				if not Soviet.fire(apoc):
					check(false,"Apocalypse failed to fire");return
				if look==Effects.Looks.BlueArc.ID:
					var muzzle_nodes=battle.effects_root.get_children().slice(first)
					check(muzzle_nodes.all(func(fx):return not fx.is_in_group("reaper_particles")),"equipped blue muzzle replaces stock yellow flash at rank %d barrel %d"%[rank,barrel+1])
				var shot=battle.projectiles_root.get_children().back()
				var socket:Vector2=apoc._ra3_model.bone_world("FX_MUZZLEFLASH%02d"%(barrel+1))
				var hp:=victim.hp
				var contact:Vector2=shot.target_point if rank==3 else victim.art_center()
				MetaProgress.set_cosmetic("R3APOC","weapon_fx","stock")
				Soviet.advance(shot,shot.splinters.duration)
				var sparks:=0
				var swirls:=0
				for fx in battle.effects_root.get_children().slice(first):
					if fx.get_script()!=Effects.Looks.BlueArc:continue
					if fx.muzzle and fx.position.distance_to(socket)<0.1:sparks+=1
					if not fx.muzzle and fx.position.distance_to(contact)<0.1:
						swirls+=1
						var ground:Vector2=shot.target_point if rank==3 else victim.global_position
						check(fx.ground_wave.global_position.distance_to(ground)<0.1 and not fx.ground_wave.visible,"warp begins at ground contact and waits for the recoil")
						fx.age=fx.IMPACT_LIFE*0.6
						fx._update_ground_wave()
						check(fx.ground_copy==battle.get_node("BlueArcGroundCopy") and fx.ground_copy.visible and fx.ground_wave.visible and fx.ground_wave.z_index<DepthLayers.entity_z(ground,battle.map_size),"both barrels use the shared terrain capture below actors")
						check(is_equal_approx(fx.ground_wave.scale.x * fx.GROUND_NORMAL.get_width() / 2.0,60.0),"ground wave reaches 60 world units")
						var rise: float = fx.ground_wave.material.get_shader_parameter("rise")
						var fire: float = fx.ground_wave.material.get_shader_parameter("flame")
						check(is_equal_approx(rise*fx.GROUND_RADIUS,44.0) and fx.ground_wave.offset.y<0 and fire>0.9,"heat rises above a bright fixed ground ring")
						fx.age=fx.WARP_LIFE-0.10
						fx._update_ground_wave()
						var fading: float = fx.ground_wave.material.get_shader_parameter("flame")
						check(fx.ground_wave.visible and fading>0 and fading<fire,"blue flames fade while the ground swirl lingers")
						fx.age=fx.WARP_LIFE
						fx._update_ground_wave()
						check(not fx.ground_wave.visible,"terrain restored at the end of the swirl")
				if look=="stock":baseline=hp-victim.hp
				var count:=int(look!="stock")
				check(sparks==count and swirls==count and baseline>0 and is_equal_approx(hp-victim.hp,baseline),
					"Apocalypse rank %d barrel %d %s muzzle, single impact and damage" % [rank,barrel+1,look])
				Soviet.tick(apoc,apoc._cd_timer+0.01)
	var target_building = battle._place_building("GAPILE","enemy",victim.position+Vector2(20,0),true)
	MetaProgress.set_cosmetic("R3APOC","weapon_fx",Effects.Looks.BlueArc.ID)
	apoc.attack_target = target_building
	for rank in [0,3]:
		apoc._grant_veteran(rank,false)
		apoc.special.soviet_mounts = {}
		var first: int = battle.effects_root.get_child_count()
		if not Soviet.fire(apoc):
			check(false,"blue shell should fire at barracks"); continue
		var shot = battle.projectiles_root.get_children().back()
		Soviet.advance(shot,shot.splinters.duration)
		var contacts: Array = battle.effects_root.get_children().slice(first).filter(func(fx):return fx.get_script()==Effects.Looks.BlueArc and not fx.muzzle)
		check(contacts.size()==1,"one building contact at rank "+str(rank))
		if contacts.size()==1:
			var fx=contacts.front()
			var edge: Vector2=target_building.closest_footprint_point(apoc.global_position)
			check(fx.position.is_equal_approx(edge) and fx.ground_wave.global_position.is_equal_approx(edge) and edge.distance_to(target_building.art_center())>1.0,"building arcs and swirl meet the incoming foundation edge")
			check(not fx.z_as_relative and fx.z_index<target_building.z_index,"building occludes the ground burst")
			if rank==0: await check_facade_refraction(target_building,fx)
	target_building.queue_free()
	remove_actor(apoc)

func check_facade_refraction(building,fx) -> void:
	# Other test volleys remain frozen in this diagnostic scene.
	var hidden: Array[CanvasItem]=[]
	for item in battle.effects_root.get_children()+battle.projectiles_root.get_children()+battle.units:
		if is_instance_valid(item) and item is CanvasItem and item!=fx and item.visible:
			hidden.append(item)
			item.hide()
	var camera_pos: Vector2=battle.camera.position
	var zoom: Vector2=battle.camera.zoom
	battle.camera.position=fx.global_position
	battle.camera.zoom=Iso.cam_zoom(2.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	building._buildup_play=-1.0
	building.queue_redraw()
	fx.age=0.98
	fx._update_ground_wave()
	fx.queue_redraw()
	var point: Vector2=fx.get_global_transform_with_canvas().origin
	var crop:=Rect2i(Vector2i(point)-Vector2i(160,160),Vector2i(320,230)).intersection(Rect2i(Vector2i.ZERO,stage.size))
	check(crop.has_area(),"building impact is inside capture viewport")
	if crop.has_area():
		var frames: Array[Image]=[]
		for step in 3:
			building.visible=step!=0
			fx.heat_wave.visible=step==2
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			frames.append(stage.get_texture().get_image().get_region(crop))
		var changed:=0
		for y in crop.size.y:
			for x in crop.size.x:
				var facade:=frames[1].get_pixel(x,y)
				# Count only pixels visibly contributed by the building.
				if facade!=frames[0].get_pixel(x,y) and facade!=frames[2].get_pixel(x,y):
					changed+=1
		check(changed>100,"heat refracts rendered building pixels while ground fire stays on",[changed])
		print("FACADE_CHANGED ",changed)
		frames[1].save_png(output_dir.path_join("facade-before.png"))
		frames[2].save_png(output_dir.path_join("facade-after.png"))
	for item in hidden:
		if is_instance_valid(item): item.show()
	battle.camera.position=camera_pos
	battle.camera.zoom=zoom
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()

func check_signature_weapons(victim:Unit,plane:Unit,mode:String) -> void:
	var start:=victim.position-Vector2(130,0)
	var apoc:Unit=actor("APOC","ally",start)
	MetaProgress.set_cosmetic("APOC","weapon_fx","molten_duet")
	for rank in [0,2]:
		apoc._grant_veteran(rank,false)
		apoc.attack_target=victim
		var burst:=int(apoc._active_weapon().burst)
		for i in burst:
			apoc._burst_left=burst-i
			apoc._fire_shot(victim)
			var shot=battle.projectiles_root.get_children().back()
			var expected:="molten_red" if i%2==0 else "molten_gold"
			check(shot.splinters.get("weapon_look")==expected,mode+" actual ground barrel sequence "+expected)
			var first:int=battle.effects_root.get_child_count()
			shot._explode()
			check(battle.effects_root.get_children().slice(first).any(func(fx):return fx.get("event")==expected),mode+" in-flight choice reaches impact")
	apoc.attack_target=plane
	apoc._fire_shot(plane)
	check(not battle.projectiles_root.get_children().back().splinters.has("weapon_look"),mode+" AA missiles retain their own art")
	remove_actor(apoc)
	var legion:Unit=actor("CLEG","ally",start)
	MetaProgress.set_cosmetic("CLEG","weapon_fx","time_fracture")
	legion.attack_target=victim
	legion._fire_shot(victim)
	AlliedAbilities.channel(legion,0.25)
	check(victim.has_meta("time_fracture") and is_equal_approx(victim.get_meta("time_fracture",0.0),float(legion.special.temporal_work)/victim.max_hp),mode+" ghost offsets follow real erasure work")
	var clock=victim.get_node_or_null("EraseClock")
	check(clock!=null and clock.event=="chrono_live" and is_equal_approx(clock.seconds_left,(victim.max_hp-float(legion.special.temporal_work))/(float(legion._active_weapon().damage)*15.0)),mode+" clock follows remaining game seconds")
	AlliedAbilities.release_temporal(legion)
	check(victim.get_node_or_null("EraseClock")==null and not battle.effects_root.get_children().any(func(fx):return fx.get("event")=="chrono_seam"),mode+" interrupted channel leaves no victory clock")
	check(not victim.has_meta("time_fracture"),mode+" interrupted channel clears ghosts")
	var spare=actor("MTNK","enemy",start+Vector2(80,0))
	legion.attack_target=spare
	legion._fire_shot(spare)
	AlliedAbilities.channel(legion,100.0)
	check(spare._dead and battle.effects_root.get_children().any(func(fx):return fx.get("event")=="chrono_seam"),mode+" completed erasure leaves a seam")
	remove_actor(legion)
	for launcher_id in ["V3","DRED"]:
		var launcher=actor(launcher_id,"ally",victim.position-Vector2(580,0))
		MetaProgress.set_cosmetic(launcher_id,"weapon_fx","reentry")
		launcher.attack_target=victim
		launcher._fire_shot(victim)
		var missile:Unit=battle.units.back()
		check(missile.special.flight.get("weapon_look")=="reentry",mode+" missile snapshots paid skin "+launcher_id)
		var first:int=battle.effects_root.get_child_count()
		for i in 1500:
			if missile._dead or missile.is_queued_for_deletion():break
			launcher.SovietWeapons.fly(missile,1.0/15)
		var events:Array=battle.effects_root.get_children().slice(first)
		check(events.any(func(fx):return fx.get("event")=="meteor_smoke") and events.any(func(fx):return fx.get("event")=="meteor_dust"),mode+" flight and landing effects "+launcher_id,[missile.special.get("flight",{}).get("phase",""),missile.position,events.size()])
		remove_actor(launcher)
