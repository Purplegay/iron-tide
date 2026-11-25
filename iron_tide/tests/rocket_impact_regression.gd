extends "res://tests/special_mechanics_regression.gd"
const Legacy = preload("res://tests/rocket_impact_reference.gd")
const Missiles = preload("res://scripts/units/soviet_advanced.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		arena(mode)
		battle.gm_unit_lab = true
		for i in 80: spawn("MTNK", "ally" if i % 2 == 0 else "enemy", Vector2(100 + i % 20 * 90, 100 + i / 20 * 90))
		var target = spawn("MTNK", "enemy", AIM)
		var friend = spawn("MTNK", "ally", AIM + Vector2(1, 0))
		var edge = spawn("MTNK", "enemy", AIM + Vector2(Ra2Damage.cells("AP") * 55.0, 0))
		var outside = spawn("MTNK", "enemy", edge.position + Vector2(0.01, 0))
		spawn("ORCA", "enemy", AIM)
		var building = add("GAPOWR", "enemy")
		building.position = AIM + Vector2(100, 0)
		var shot := Projectile.new()
		shot.setup(AIM - Vector2(200, 0), target, GameData.get_unit("FV").weapon, 50, {}, "ally")
		shot.ra2_inviso = false
		battle.projectiles_root.add_child(shot)
		for owner in ["ally", "enemy", "ai2"]:
			shot.owner_side = owner
			for wh in ["AP", "YR_SOV_V3WH", "", "RA3_UNKNOWN"]:
				shot.ra2_warhead = wh
				for forced in [false, true]:
					shot.splinters = {"force_fire":forced}
					for aoe in [0.0, 60.0, 6000.0]:
						shot.aoe = aoe
						compare(shot, mode + "/" + owner + "/" + wh + "/" + str(forced) + "/" + str(aoe))
		shot.ra2_warhead = "AP"; shot.aoe = 60; shot.owner_side = "ally"
		for flags in [{"drop_height":100}, {"bomb_drop":true}, {"flak_airburst":true}, {"hero_air_shell":true}, {"impact_air":true}]:
			shot.splinters = flags
			compare(shot, "special layer " + str(flags))
		shot.splinters = {"force_fire":true}
		friend.position = Vector2(500, 500)
		outside.position = AIM
		AlliedAbilities.change_side(outside, "ally")
		compare(shot, "movement across grid cells and capture")
		# World arrays can differ from tree order after capture or explicit reordering.
		battle.units.reverse()
		for point in [AIM, Vector2.ZERO, Vector2(256,256)]:
			var old: Array = (battle.units + battle.buildings).filter(func(a): return a.position.distance_to(point) <= Ra2Damage.cells("YR_SOV_V3WH") * 55.0)
			var current: Array = Missiles.impact_candidates(battle, point, "YR_SOV_V3WH").filter(func(a): return a.position.distance_to(point) <= Ra2Damage.cells("YR_SOV_V3WH") * 55.0)
			check(current == old, "V3 preserves world-list hit order " + str(point))
		battle.units.erase(target); target.free()
		compare(shot, "freed target uses stored impact layer")
		var ground := ForceFirePoint.new(); ground.position = AIM
		shot.target = ground; shot.ra2_warhead = ""; shot.aoe = 0
		compare(shot, "precise force-fire radius")
		shot.target = null
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)

func compare(shot, label: String) -> void:
	var expected := hits(shot, Legacy.impact_candidates(shot))
	var actual := hits(shot, ForceFire.impact_candidates(shot))
	check(actual == expected, "impact membership and order: " + label, {"expected":expected.size(),"actual":actual.size()})

func hits(shot, candidates: Array) -> Array:
	var result: Array = []
	for actor in candidates:
		if not is_instance_valid(actor) or not actor.has_method("receive_hit"): continue
		var distance: float = actor.global_position.distance_to(shot.target_point)
		if Ra2Damage.cells(shot.ra2_warhead) > 0:
			if shot.splinters.has("drop_height") and actor is Building:
				distance = maxf(0, distance - actor.footprint_clearance(actor.global_position.direction_to(shot.target_point)))
			if not Ra2Damage.in_spread(distance, shot.ra2_warhead): continue
		elif shot.aoe > 0.5:
			if distance > shot.aoe + shot._radius_of(actor): continue
		elif distance > maxf(1, shot._radius_of(actor)): continue
		result.append(actor)
	return result
