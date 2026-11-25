extends "res://tests/ground_control_regression.gd"
const Access=preload("res://scripts/world/ai_base_access.gd")
const Blocked=preload("res://scripts/world/ai_blocked_route.gd")
# Local layout from slot3, 2026-11-13; no player save is read or written.
const BUILDINGS=[["NACNST", 7440.0, 5080.0], ["NAHAND", 7280.0, 5280.0], ["NAWEAP", 7440.0, 5320.0], ["NALASR", 7600.0, 5400.0], ["NALASR", 7280.0, 5440.0], ["NAFLAK", 7520.0, 5120.0], ["NARADR", 7440.0, 5160.0], ["TESLA", 7600.0, 5080.0], ["NAPOWR", 7600.0, 5000.0], ["NABNKR", 7360.0, 5200.0], ["NAWEAP", 7760.0, 5080.0], ["NAHAND", 7360.0, 5280.0], ["NAWEAP", 7440.0, 4800.0], ["NAYARD", 8040.0, 5120.0], ["NAREFN", 7080.0, 5640.0], ["NAPOWR", 7720.0, 4920.0], ["NAFLAK", 7400.0, 5120.0], ["NADEPT", 7560.0, 4880.0], ["NANRCT", 7640.0, 4760.0], ["NAINDP", 7280.0, 4760.0], ["NAIRON", 7440.0, 5480.0], ["NATECH", 7440.0, 4640.0], ["NAFLAK", 7440.0, 4920.0], ["NAFLAK", 7440.0, 4880.0], ["NAFLAK", 7920.0, 5080.0]]

func exercise(mode:String) -> void:
	BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","opening":"mcv","enemy_country":"苏俄","fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	for actor in battle.units+battle.buildings:actor.free()
	battle.units.clear();battle.buildings.clear();battle.invalidate_ai_population()
	var ai=battle.skirmish_ai
	ai.base_center=Vector2(7452.5,5087.5)
	var candidate=null
	for spec in BUILDINGS:
		var building=battle._place_building(spec[0],"enemy",Vector2(spec[1],spec[2]),true)
		building._buildup_play=-1
		if building.position==Vector2(7440,5320):candidate=building
	battle._refresh_pathing()
	var unit=battle.spawn_unit("TTNK","enemy",Vector2(7845.4419,5305.8130))
	activate(unit)
	unit.special.ai_campaign_role="attack"
	var goal:=Vector2(6320,2560)
	var used:Array[Vector2]=[]
	check(battle.resolve_move_slot(unit,goal,used,50.0).distance_to(unit.position)<Unit.ARRIVE_EPS,mode+" saved layout traps the attacker")
	var nav=battle.path_service
	var original:PackedFloat32Array=nav.cost.duplicate()
	var begin:=Time.get_ticks_usec()
	var opens:bool=Access.Routes.opens_route(nav,unit,goal,candidate)
	var probe_ms:float=(Time.get_ticks_usec()-begin)/1000.0
	check(opens and nav.cost==original,mode+" single redundant factory opens the route without mutating navigation")
	var patch:Dictionary=Access.Routes.removal_patch(nav,candidate)
	var terrain:PackedFloat32Array=nav.passages.terrain.duplicate()
	for point in patch: nav.passages.terrain[point.y*nav.cols+point.x]=-1.0
	check(not Access.Routes.opens_route(nav,unit,goal,candidate),mode+" impassable terrain underneath the factory rules out demolition")
	nav.passages.terrain=terrain
	var overlap=battle._place_building("NAWEAP","enemy",candidate.position,true)
	check(not Access.Routes.opens_route(nav,unit,goal,candidate),mode+" another building at the same location remains an obstruction")
	battle.buildings.erase(overlap);overlap.free();battle._refresh_pathing()
	battle.buildings.erase(candidate);battle._refresh_pathing()
	var exact:=true
	for y in nav.rows:
		for x in nav.cols:
			var point:=Vector2i(x,y)
			if not is_equal_approx(float(patch.get(point,original[y*nav.cols+x])),nav.cost[y*nav.cols+x]):exact=false
	check(exact,mode+" hypothetical removal exactly matches a full live terrain rebuild")
	check(not Access.placement_ok(battle,"enemy",candidate.data,candidate.position),mode+" AI refuses to rebuild the enclosure")
	battle.buildings.append(candidate);battle._refresh_pathing()
	Blocked.failed(battle,unit,goal,unit.position)
	check(Access.Routes.obstruction(ai,0)==null and Access.Routes.obstruction(ai,9)==null,mode+" transient blockage is not sold")
	var treasury:float=battle.funds_for("enemy")
	var sold=null
	for i in 30:
		var obstruction=Access.Routes.obstruction(ai,12+i*3)
		if obstruction!=null:
			sold=obstruction
			Access.sell_building(ai,obstruction,12+i*3)
			break
	check(sold!=null and sold.building_id=="NAWEAP",mode+" timed probe chooses an own redundant factory")
	if sold!=null:
		check(is_equal_approx(battle.funds_for("enemy"),treasury+GameData.ra2_refund(int(sold.data.cost))),mode+" recovered route uses normal sale refund")
		check(Access.Routes.obstruction(ai,15)==null,mode+" shared cooldown forbids a second sale")
	check(not Blocked.waiting(battle,unit),mode+" navigation change immediately releases the blocked-order retry")
	used.clear()
	check(battle.resolve_move_slot(unit,goal,used,50.0).distance_to(unit.position)>500,mode+" attacker now resolves a real distant destination")
	metrics.append({"mode":mode,"probe_ms":probe_ms,"patch_cells":patch.size()})
	await finish()
