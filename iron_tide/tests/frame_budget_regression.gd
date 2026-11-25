extends "res://tests/ground_control_regression.gd"
const Fog = preload("res://scripts/world/fog_of_war.gd")

func exercise(mode: String) -> void:
	start(mode)
	check_radar_sources()
	check_building_footprints()
	check_alliance_masks(mode)
	check_live_speed(mode)
	check_native_weapon(mode)
	await finish()

func check_radar_sources() -> void:
	var old_fog=battle.fog
	var fog=Fog.new()
	fog.battle=battle
	fog.width=ceili(battle.map_size/Fog.CELL)
	var explored:=PackedByteArray()
	explored.resize(fog.width*fog.width)
	var visible_cells:=explored.duplicate()
	for i in explored.size():
		explored[i]=1 if i%3!=0 else 0
		visible_cells[i]=1 if i%5==0 else 0
	fog.explored_cells.ally=explored
	fog.visible_cells.ally=visible_cells
	var radar:=MiniMap.new()
	radar.battle=battle
	for i in 256:
		var ore=preload("res://scripts/world/resource_node.gd").new()
		ore.position=Vector2((i%17)*150-40,(i/17)*150-40)
		battle.add_child(ore)
		ore.amount=0 if i%4==0 else 6000
	for stage in ["mixed","visible","hidden","fog_off"]:
		battle.fog=null if stage=="fog_off" else fog
		if stage=="visible":fog.visible_cells.ally.fill(1)
		if stage=="hidden":fog.visible_cells.ally.fill(0)
		for scale_value in [0.05,0.1]:
			var projection:=Transform2D(0.3,Vector2.ONE*scale_value,0,Vector2(3,4))
			var expected:=[]
			for ore in get_tree().get_nodes_in_group("resource_nodes"):
				if not battle.position_explored_by("ally",ore.global_position):continue
				var seen:bool=battle.position_visible_to("ally",ore.global_position)
				if seen and ore.is_empty():continue
				var point:Vector2=projection*ore.global_position
				var found:=false
				for mark in expected:
					if point.distance_squared_to(mark.p)<25.0:
						mark.n+=1
						mark.seen=mark.seen or seen
						found=true
						break
				if not found:expected.append({"p":point,"n":1,"seen":seen})
			radar._refresh_ore_marks(projection)
			check(radar._ore_marks==expected,prefix+stage+" radar matches independent public-visibility/linear-cluster reference "+str(scale_value))
	radar.free()
	battle.fog=old_fog
	fog.free()

func check_alliance_masks(mode: String) -> void:
	var previous:Dictionary=BattleRequest.house_teams.duplicate()
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1,"ai3":2,"ai4":1,"ai5":2}
	var fog=Fog.new()
	fog.width=192
	for different in [false,true]:
		var visible_input:={}
		var explored_input:={}
		for side in BattleRequest.house_teams:
			var cells:=PackedByteArray()
			cells.resize(fog.width*fog.width)
			if different:cells[int(side.hash())%cells.size()]=1
			visible_input[side]=cells.duplicate()
			cells.fill(1)
			explored_input[side]=cells
		var times:=[]
		var reference:={}
		for round in 8:
			var timing:={}
			for optimized in ([false,true] if round%2==0 else [true,false]):
				fog.visible_cells=visible_input.duplicate(true)
				fog.explored_cells=explored_input.duplicate(true)
				fog._begin_live_masks()
				Fog.SightBatch.raster_disc(fog._live_masks[1],fog.width,Vector2(800,1200),500)
				Fog.SightBatch.raster_disc(fog._live_masks[2],fog.width,Vector2(1400,1200),500)
				var started:=Time.get_ticks_usec()
				if optimized:fog._apply_live_masks()
				else:
					for side in fog.visible_cells:
						var mask:Image=fog._live_masks[BattleRequest.house_teams[side]]
						for layer:Dictionary in [fog.visible_cells,fog.explored_cells]:
							var surface:=Image.create_from_data(fog.width,fog.width,false,Image.FORMAT_L8,layer[side])
							surface.blit_rect_mask(fog._white_cells,mask,Rect2i(0,0,fog.width,fog.width),Vector2i.ZERO)
							layer[side]=surface.get_data()
					fog._live_masks.clear()
				timing[str(optimized)]=Time.get_ticks_usec()-started
				var result:={"visible":fog.visible_cells.duplicate(true),"explored":fog.explored_cells.duplicate(true)}
				if reference.is_empty():reference=result
				check(result==reference,prefix+" alliance masks match per-observer reference "+str([different,round,optimized]))
			times.append(timing)
		fog.visible_cells.ally[0]=17
		check(fog.visible_cells.ai2[0]!=17 and fog.explored_cells.ally[0]!=17,prefix+" merged inputs do not alias observers or visibility layers")
		metrics.append({"case":"alliance_masks","mode":mode,"different":different,"times":times})
	fog.free()
	BattleRequest.house_teams=previous

func check_building_footprints() -> void:
	var fog=Fog.new()
	fog.battle=battle
	var building=battle._place_building("GAPOWR","enemy",Vector2(1200,1200),true)
	var old_mirror := Iso.MIRROR
	for width_value in [60,80]:
		fog.width=width_value
		for offset in [Vector2.ZERO,Vector2.ZERO,Vector2(25,40),Vector2(-1199,-1199)]:
			Iso.MIRROR = not Iso.MIRROR
			building.position=Vector2(1200,1200)+offset
			for observer in ["ally","enemy"]:
				var cells:=PackedByteArray()
				cells.resize(fog.width*fog.width)
				fog.visible_cells[observer]=cells.duplicate()
				fog.explored_cells[observer]=cells.duplicate()
				fog.sight_until[observer]={}
				fog._held_buildings[observer]={}
				var projection:=Transform2D(Iso.dir(Vector2.RIGHT),Iso.dir(Vector2.DOWN),Vector2.ZERO)
				var rect:Rect2=building.combat_sight_rect()
				var margin:Vector2=(projection.x.abs()+projection.y.abs())*Fog.CELL
				rect=Rect2(rect.position-margin,rect.size+2.0*margin)
				for y in fog.width:
					for x in fog.width:
						var point:Vector2=(Vector2(x,y)+Vector2(0.5,0.5))*Fog.CELL
						if rect.has_point(projection*(point-building.global_position)):cells[y*fog.width+x]=1
				fog._hold_building(observer,building,3.0)
				check(fog.visible_cells[observer]==cells and fog.explored_cells[observer]==cells,prefix+" building cache matches independent full-grid projection "+str([width_value,offset,observer]))
				fog._held_buildings[observer].clear()
				fog.sight_clock+=1.0
				fog._hold_building(observer,building,3.0)
				var refreshed:=true
				for deadline in fog.sight_until[observer].values():refreshed=refreshed and deadline==fog.sight_clock+3.0
				check(refreshed,prefix+" cached geometry still renews live observer deadlines")
	Iso.MIRROR = old_mirror
	fog.free()

func check_live_speed(mode: String) -> void:
	var actor=battle.spawn_unit("MTNK","ally",Vector2(1100,1100))
	var owner=battle.spawn_unit("CLEG","enemy",Vector2(1200,1100))
	activate(actor)
	activate(owner)
	var mismatches:=[]
	var cases:=0
	for hero in ["","MTNK","HTNK","E1"]:
		for rank in [-1,0,3,4,5]:
			for variant in 8:
				actor.special={"academy_hero":hero,"hero_survival_rank":rank}
				actor._deployed=variant==1
				if variant==2:actor.special.hero_wreck={}
				if variant==3:actor.special.hero_speed_floor=180.0
				if variant==4:actor.special.chrono_left=1.0
				if variant in [5,6]:actor.special.temporal_by=owner
				owner.hp=0.0 if variant==6 else owner.max_hp
				if variant==7:actor.special.chrono_left=0.0
				for base in [-1.0,0.0,120.0,220.0]:
					var expected:=0.0 if actor.special.has("hero_wreck") or actor._deployed else maxf(base,float(actor.special.get("hero_speed_floor",0)))*(0.5 if Unit.TankHero.cold(actor) else 1.0)
					var actual:float=Unit.TankHero.speed(actor,base)
					if expected!=actual:mismatches.append([hero,rank,variant,base,expected,actual])
					cases+=1
	check(mismatches.is_empty(),prefix+" live speed formula matches original for every state",mismatches)
	metrics.append({"case":"live_speed","mode":mode,"cases":cases})

func native_weapon_reference(unit, target = null) -> Dictionary:
	if unit.embarked_in is Building: return preload("res://scripts/units/civilian_orders.gd").weapon(unit)
	if CommandoCombat.handles(unit): return CommandoCombat.weapon_for(unit, target)
	if unit.unit_id == "FV" and not unit.logistics.passengers.is_empty():
		var passenger = unit.logistics.passengers[0]
		if AlliedAbilities.alive(passenger):
			var mode := int(AlliedAbilities.source(passenger).get("IFVMode", 0))
			var key := ("EliteWeapon" if unit.veteran_level >= 2 else "Weapon") + str(mode + 1)
			return AlliedAbilities.weapon(str(AlliedAbilities.source(unit).get(key, "HoverMissile")))
	if unit.unit_id in ["CLEG", "PTROOP"]:
		return AlliedAbilities.weapon(str(AlliedAbilities.source(unit).get("ElitePrimary" if unit.veteran_level >= 2 else "Primary", "")))
	if unit.unit_id == "MGTK" and unit.veteran_level >= 2:
		return AlliedAbilities.weapon("MirageGunE")
	return {}


func check_native_weapon(mode: String) -> void:
	var enemy=battle.spawn_unit("HTNK","enemy",Vector2(1600,1600))
	var passenger=battle.spawn_unit("E1","ally",Vector2(1600,1500))
	var building=battle._place_building("GAPOWR","enemy",Vector2(1800,1800),true)
	var mismatches:=[]
	var cases:=0
	for id in ["MTNK","E1","FV","CLEG","PTROOP","MGTK","GHOST","TANY","CCOMAND"]:
		var unit=battle.spawn_unit(id,"ally",Vector2(1400,1400))
		for rank in [0,1,2]:
			unit.veteran_level=rank
			for state in 4:
				unit.embarked_in=building if state==3 else null
				unit.logistics.passengers=[passenger] if state in [1,2] else []
				passenger.hp=0 if state==2 else passenger.max_hp
				for target in [null,enemy,building]:
					if native_weapon_reference(unit,target)!=unit._effective_native_weapon(target):mismatches.append([id,rank,state,str(target)])
					cases+=1
		unit.embarked_in=null
		unit.logistics.passengers=[]
		unit.free()
	check(mismatches.is_empty(),prefix+" direct unit weapon resolver matches former static helper",mismatches)
	var tank=battle.spawn_unit("MTNK","ally",Vector2(1400,1400))
	var timings:=[]
	for round in 8:
		var row:={}
		for optimized in ([false,true] if round%2==0 else [true,false]):
			var started:=Time.get_ticks_usec()
			for i in 20000:
				if optimized:tank._effective_native_weapon(enemy)
				else:native_weapon_reference(tank,enemy)
			row[str(optimized)]=Time.get_ticks_usec()-started
		timings.append(row)
	metrics.append({"case":"native_weapon","mode":mode,"states":cases,"calls_per_round":20000,"times":timings})
