extends "res://tests/base_recovery_regression.gd"
const Access=preload("res://scripts/world/ai_base_access.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for multiple in [false,true]: await exercise(multiple)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("BASE ACCESS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise(multiple: bool) -> void:
	var config={"map_layout":"yr_crctbrd","opening":"prebuilt","enemy_country":"美国","difficulty":2,"fog_of_war":false}
	if multiple: config.houses=[{"country":"美国","team":1},{"country":"美国","team":2,"difficulty":2},{"country":"苏俄","team":1}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false
	for unit in battle.units: unit.free()
	battle.units.clear()
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	for obstacle in get_tree().get_nodes_in_group("obstacles")+get_tree().get_nodes_in_group("native_ore_drills"): obstacle.free()
	battle.path_service.native_map_id=""
	battle.mission.map_layout="coast"
	battle.path_service._native_base.clear()
	battle.path_service.water_rects.clear()
	battle.path_service.bridge_decks.clear()
	battle._refresh_pathing()
	var ai=battle.house_controllers.enemy if multiple else battle.skirmish_ai
	var factory=battle._place_building("GAWEAP","enemy",Vector2(1200,1200),true)
	factory._buildup_play=-1
	var lane:Dictionary=Access.lanes(battle,"enemy")[0]
	check(Access.clear_without(battle,lane,null),"unobstructed factory has a real geometric exit")
	for id in ["GAPOWR","GATECH","GAPILL","GAWEAP","GAREFN"]:
		check(not Access.placement_ok(battle,"enemy",GameData.get_building(id),lane.start),id+" may not occupy an existing departure lane")
	check(Access.placement_ok(battle,"enemy",GameData.get_building("GAPOWR"),Vector2(2000,2000)),"clear distant building site is retained")
	var wall=battle._place_building("GAWALL","enemy",lane.start,true)
	check(not Access.clear_without(battle,lane,null) and Access.clear_without(battle,lane,wall),"single wall removal is proven to open the whole lane")
	check(Access.sellable(ai,wall) and not Access.sellable(ai,factory),"own wall eligible but last factory protected")
	var treasury:float=battle.funds_for("enemy")
	var refund:float=GameData.ra2_refund(int(wall.data.cost))
	factory.exit_blocked=true
	Access.inspect(ai,lane,0)
	Access.inspect(ai,lane,9)
	check(battle.actor_alive(wall),"transient blockage does not sell a building")
	Access.inspect(ai,lane,12)
	check(not battle.buildings.has(wall) and Access.clear_without(battle,lane,null),"persistent blocked exit sells only verified obstruction and refreshes navigation")
	check(is_equal_approx(battle.funds_for("enemy"),treasury+refund),"normal sale refund credited to the owning AI")
	check(ai.ai_state.access_sales==1,"one sale recorded")
	var second=battle._place_building("GAWALL","enemy",lane.start,true)
	var other=battle._place_building("GAWALL","enemy",lane.end,true)
	check(not Access.clear_without(battle,lane,second),"removing one obstacle cannot pretend to clear a second obstacle")
	other.retire_sold()
	battle.buildings.erase(other)
	battle._refresh_pathing()
	Access.inspect(ai,lane,13)
	Access.inspect(ai,lane,30)
	check(battle.actor_alive(second),"sale cooldown prevents cascading demolition")
	second.side="ally"
	check(not Access.sellable(ai,second),"player and allied ownership cannot be sold")
	second.retire_sold()
	battle.buildings.erase(second)
	battle._refresh_pathing()
	var power=battle._place_building("GAPOWR","enemy",Vector2(1800,1800),true)
	var yard=battle._place_building("GACNST","enemy",Vector2(2100,1800),true)
	var refinery=battle._place_building("GAREFN","enemy",Vector2(2400,1800),true)
	check(not Access.sellable(ai,power) and not Access.sellable(ai,yard) and not Access.sellable(ai,refinery),"power base and refinery remain protected")
	var extra=battle._place_building("GAWEAP","enemy",Vector2(2700,1800),true)
	check(Access.sellable(ai,extra),"duplicate production facility may be considered while the last is retained")
	var original:PackedFloat32Array=battle.path_service.passages.terrain.duplicate()
	var cell:Vector2i=battle.path_service._cell_of(lane.end)
	battle.path_service.passages.terrain[cell.y*battle.path_service.cols+cell.x]=-1.0
	check(not Access.clear_without(battle,lane,extra),"terrain obstruction cannot be repaired by selling unrelated buildings")
	battle.path_service.passages.terrain=original
	var soldier=battle.spawn_unit("MTNK","enemy",lane.start)
	var player=battle.spawn_unit("MTNK","ally",lane.start+Vector2(4,4))
	soldier.order_stop()
	player.order_stop()
	Access.inspect(ai,lane,100)
	check(not player.has_move_order,"factory clearance never commandeers player units")
	check(ai.ai_state.access_sales==1,"unit-only congestion never triggers demolition")
	route_probe(battle.path_service)
	# Feed the queued rally through the real dispatcher, independent of load throttling.
	for i in 30: battle.ai_dispatch.pump(battle)
	check(soldier.has_move_order or soldier.special.has("ai_assembly_retry"),"idle factory blocker receives a bounded parking attempt")
	var saved:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	check(BattleSaves.validate(saved).is_empty(),"inspection and sale timers serialize without runtime cache")
	await finish()

func route_probe(nav) -> void:
	# A one-cell gap connects both halves of an otherwise closed barrier.
	var original:PackedFloat32Array=nav.cost.duplicate()
	var mid:=Vector2i(30,30)
	for y in nav.rows:
		if y!=mid.y: nav.cost[y*nav.cols+mid.x]=-1.0
	nav.epoch+=1
	var footprint:=Rect2(Vector2(mid)*nav.cell+Vector2.ONE*4,Vector2.ONE*(nav.cell-8))
	check(not Access.Routes.placement_ok(nav,footprint),"new construction may not close the only ground passage")
	check(Access.Routes.placement_ok(nav,Rect2(footprint.position+Vector2(600,0),footprint.size)),"open area remains buildable beside an existing barrier")
	check(nav.cost[mid.y*nav.cols+mid.x]>=0,"hypothetical placement never changes the live navigation grid")
	nav.cost=original
	nav.epoch+=1
