extends "res://tests/ground_control_regression.gd"
const Bridges = preload("res://scripts/world/bridge_damage.gd")
const Native = preload("res://scripts/world/native_maps.gd")

func exercise(mode: String) -> void:
	for layout in ["yr_crctbrd","river_delta"]:
		prefix = mode + "/" + layout + ": "
		BattleRequest.configure_skirmish(mode,{"map_layout":layout,"opening":"mcv","fog_of_war":false})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		var span: Rect2 = Native.data(layout).bridge_decks[0] if Native.has(layout) else battle.allied_state.repaired_bridges[0]
		var section := Bridges.section_at(battle,span.get_center())
		var center := section.get_center()
		check(not battle.path_service.is_blocked(center),prefix+"intact bridge carries land units")
		var mcv = battle.spawn_unit("AMCV","ally",center)
		activate(mcv)
		var deploy: Dictionary = battle.construction_deploy_check(mcv)
		check(not deploy.ok and str(deploy.reason).contains("桥面"),prefix+"MCV bridge deployment rejected",deploy)
		var before: int = battle.buildings.size()
		check(not mcv.deploy() and battle.buildings.size()==before and not mcv._dead,prefix+"rejected deployment preserves MCV and buildings")
		for owner in ["ally","enemy"]:
			var site: Dictionary = battle.build_spot_ok(center,GameData.get_building("GAPOWR"),true,owner)
			check(not site.ok and str(site.reason).contains("桥面"),prefix+owner+" cannot place structure on deck",site)
		var edge_poly := PackedVector2Array([Vector2.ZERO,Vector2(30,0),Vector2(30,30),Vector2(0,30)])
		check(Bridges.overlaps(battle,edge_poly,span.position-Vector2(15,15)),prefix+"partial footprint overlap rejected")
		check(not Bridges.overlaps(battle,edge_poly,span.position-Vector2(60,60)),prefix+"nearby non-bridge footprint unaffected")
		mcv.position = center+Vector2(-span.size.x-300,0)
		var tank = battle.spawn_unit("MTNK","ally",mcv.position+Vector2(0,100))
		activate(tank)
		battle.select_unit(tank,false)
		check(ForceFire.issue(battle,center)==1,prefix+"real Ctrl-fire command accepts bridge coordinate")
		var target = tank.attack_target
		var weapon: Dictionary = tank._weapon_for_target(target)
		var initial := Bridges.strength()
		var per: float = float(weapon.damage)
		fire(target,weapon,tank)
		check(is_equal_approx(Bridges.health(battle,section),initial-per),prefix+"shell impact reduces bridge health exactly once",Bridges.health(battle,section))
		var codec = BattleSaves.Snapshot.new()
		var saved: Dictionary = codec.capture(battle)
		check(codec.error.is_empty(),prefix+"damaged bridge snapshot serializes",codec.error)
		codec.restore(battle,bytes_to_var(var_to_bytes(saved)))
		check(is_equal_approx(Bridges.health(battle,section),initial-per),prefix+"partial damage survives restore")
		var victim = battle.spawn_unit("MTNK","ally",center)
		var air = battle.spawn_unit("ZEP","ally",center)
		activate(victim)
		activate(air)
		# Deterministic real projectile impacts; no replacement damage implementation.
		var point := ForceFirePoint.new()
		point.global_position = center
		var shooter = battle.spawn_unit("MTNK","ally",center+Vector2(-span.size.x-300,100))
		point.receive_hit(10.0,"energy",{},shooter)
		check(is_equal_approx(Bridges.health(battle,section),initial-per-10.0),prefix+"instant ground hit damages bridge")
		point.receive_hit(-100.0,"energy",{},shooter)
		check(is_equal_approx(Bridges.health(battle,section),initial-per-10.0),prefix+"healing cannot repair bridge by firing")
		for i in ceili(initial/per): fire(point,weapon,null)
		check(Bridges.health(battle,section)==0.0 and not battle.path_service.bridge_at(center).has_area(),prefix+"hit section destroyed and removed from active deck")
		check(battle.path_service.is_blocked(center),prefix+"destroyed crossing blocks land traffic")
		check(victim._dead and not air._dead,prefix+"collapse removes unsupported ground unit and preserves aircraft")
		if Native.has(layout):
			check(battle.path_service.in_naval_water(center) and not battle.path_service.is_blocked(center,true),prefix+"destroyed low bridge opens naval water")
			var preserved := true
			for cell in Native.data(layout).bridge_base:
				var bank := (Vector2(cell)+Vector2.ONE*0.5)*Native.CELL
				if span.has_point(bank) and int(Native.data(layout).bridge_base[cell]) == 1:
					preserved = preserved and battle.path_service.native_flags(bank) == 1
			check(preserved,prefix+"collapse preserves original land at bridge approaches")
			var fresh := PathService.new()
			fresh.native_map_id = layout
			fresh.configure(battle.map_size,Native.CELL)
			check(not fresh.is_blocked(center),prefix+"destruction does not mutate shared map cache")
			fresh.free()
		var dead_save: Dictionary = codec.capture(battle)
		codec.restore(battle,bytes_to_var(var_to_bytes(dead_save)))
		check(battle.path_service.is_blocked(center) and not battle.path_service.bridge_at(center).has_area(),prefix+"destroyed section survives save restore")
		if not Native.has(layout):
			for hut in battle.buildings:
				if hut.special.get("bridge_span") == span:
					preload("res://scripts/world/civilian_sites.gd").repair(hut)
					break
			check(not battle.path_service.is_blocked(center) and Bridges.health(battle,section)==initial,prefix+"engineer repair restores crossing and health")
		await finish()

func fire(target, weapon: Dictionary, source) -> void:
	var shot := Projectile.new()
	shot.setup(target.global_position+Vector2(-80,0),target,weapon,float(weapon.damage),{},"ally",source)
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	battle.add_child(shot)
	shot._explode()
