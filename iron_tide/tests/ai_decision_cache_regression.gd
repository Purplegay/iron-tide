extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	check_strategy_budget()
	check_geometry()
	start(MatchRules.EXTENDED)
	var definitions := [GameData.get_building("GAPOWR").duplicate(true),GameData.get_building("GAWEAP").duplicate(true)]
	var changed: Dictionary = definitions[0].duplicate(true)
	changed.radius = 135.0
	definitions.append(changed)
	var placement_mismatches := 0
	for data in definitions:
		for i in 48:
			var point: Vector2 = battle.snap_build_pos(Vector2(650+(i%8)*65,650+(i/8)*65))
			battle.ai_prerequisite_scan = false
			var fresh: Dictionary = battle.build_spot_ok(point,data,true,"enemy")
			battle.ai_prerequisite_scan = true
			var reused: Dictionary = battle.build_spot_ok(point,data,true,"enemy")
			if fresh != reused: placement_mismatches+=1
	check(placement_mismatches==0,"144 live placements match fresh geometry, including changed same-ID definition",placement_mismatches)
	battle.ai_prerequisite_scan = false
	battle.clear_ai_decision_cache()
	var tank := GameData.get_unit("HTNK")
	var infantry := GameData.get_unit("E2")
	var normal: float = battle.production_price(tank,"enemy")
	battle.ai_prerequisite_scan = true
	check(battle.production_price(tank,"enemy")==normal,"No industrial plant: unchanged vehicle price")
	var plant = battle._place_building("NAINDP","enemy",Vector2(1500,1200),true)
	plant._buildup_play = -1.0
	plant.powered = false
	check(not battle.ai_scan_prices.has("enemy"),"Placement invalidates same-decision procurement cache")
	var discounted: float = floorf(normal*float(plant.data.vehicle_cost_factor))
	check(battle.production_price(tank,"enemy")==discounted,"Newly placed operational industrial plant discounts next purchase")
	check(battle.production_price(tank,"enemy")==discounted,"Repeated vehicle purchase retains exact discount")
	check(battle.production_price(infantry,"enemy")==float(infantry.cost),"Vehicle discount never applies to infantry")
	check(battle.production_price(tank,"ally")==normal,"Independent player economy retains full price")
	battle.ai_prerequisite_scan = false
	battle.clear_ai_decision_cache()
	plant.under_construction = true
	battle.ai_prerequisite_scan = true
	check(battle.production_price(tank,"enemy")==normal,"Next decision rechecks operational plant state")
	battle.ai_prerequisite_scan = false
	battle.clear_ai_decision_cache()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func check_geometry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 920736
	var mismatches := 0
	var polygons := [PackedVector2Array([Vector2(-60,-40),Vector2(60,-40),Vector2(60,40),Vector2(-60,40)]),PackedVector2Array([Vector2(0,-70),Vector2(90,0),Vector2(0,70),Vector2(-90,0)])]
	for poly in polygons:
		for i in 4000:
			var offset := Vector2(rng.randf_range(-200,200),rng.randf_range(-200,200))
			var center := offset+Vector2(rng.randf_range(-160,160),rng.randf_range(-160,160))
			var radius := rng.randf_range(1,50)
			var exact := Placement.circle_hits_poly(poly,center,radius,offset)
			var broad := Placement.circle_hits_rect(Placement.aabb(poly,offset),center,radius)
			if exact and not broad: mismatches+=1
	check(mismatches==0,"8000 deterministic circles retain all precise footprint collisions",mismatches)
	var rect := Rect2(-10,-10,20,20)
	check(Placement.circle_hits_rect(rect,Vector2(15,0),5),"Circle touching right boundary remains a collision")
	check(not Placement.circle_hits_rect(rect,Vector2(15.01,0),5),"Separated circle rejected before polygon work")

func check_strategy_budget() -> void:
	var budget = preload("res://scripts/world/ai_strategy_budget.gd").new()
	check(budget.claim("enemy",10),"First due house gets strategy frame")
	check(not budget.claim("ai2",10) and not budget.claim("ai3",10),"Other due houses remain pending on same rendered frame")
	check(budget.claim("enemy",10),"Same house may finish its own synchronous decision")
	check(budget.claim("ai2",11) and not budget.claim("ai3",11) and budget.claim("ai3",12),"Pending houses advance next frames without losing their due work")
	check(budget.deferred==3,"Deferred strategy frames recorded for diagnostics")
