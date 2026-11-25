extends RefCounted
## Exact entry counts; sampled inclusive CPU timers. No game RNG, scene access or disk I/O here.
const POINTS := [
	{"name":"unit._physics_process","source":"res://scripts/units/unit.gd","stride":32,"func":"_physics_process"},
	{"name":"unit._process_combat","source":"res://scripts/units/unit.gd","stride":32,"func":"_process_combat"},
	{"name":"unit._refresh_target","source":"res://scripts/units/unit.gd","stride":16,"func":"_refresh_target","iteration_unit":"target candidates"},
	{"name":"unit._move_toward","source":"res://scripts/units/unit.gd","stride":32,"func":"_move_toward"},
	{"name":"unit._tick_skills","source":"res://scripts/units/unit.gd","stride":32,"func":"_tick_skills"},
	{"name":"unit._tick_path_stuck","source":"res://scripts/units/unit.gd","stride":32,"func":"_tick_path_stuck"},
	{"name":"unit._draw","source":"res://scripts/units/unit.gd","stride":32,"func":"_draw","iteration_unit":"body draw builds"},
	{"name":"building._process","source":"res://scripts/buildings/building.gd","stride":16,"func":"_process"},
	{"name":"building._acquire_target","source":"res://scripts/buildings/building.gd","stride":8,"func":"_acquire_target"},
	{"name":"building._draw","source":"res://scripts/buildings/building.gd","stride":16,"func":"_draw"},
	{"name":"battle._process","source":"res://scripts/world/battle.gd","stride":1,"func":"_process"},
	{"name":"battle._draw","source":"res://scripts/world/battle.gd","stride":1,"func":"_draw"},
	{"name":"battle._draw_hp_overlay","source":"res://scripts/world/battle.gd","stride":1,"func":"_draw_hp_overlay"},
	{"name":"battle.build_spot_ok","source":"res://scripts/world/battle.gd","stride":32,"func":"build_spot_ok"},
	{"name":"battle.path_for_unit","source":"res://scripts/world/battle.gd","stride":8,"func":"path_for_unit"},
	{"name":"house_ai._process","source":"res://scripts/world/house_ai.gd","stride":4,"func":"_process"},
	{"name":"house_ai.run_decisions","source":"res://scripts/world/house_ai.gd","stride":1,"func":"run_decisions"},
	{"name":"house_ai._manage_base","source":"res://scripts/world/house_ai.gd","stride":1,"func":"_manage_base"},
	{"name":"house_ai.building_site","source":"res://scripts/world/house_ai.gd","stride":1,"func":"building_site"},
	{"name":"skirmish_ai.run_decisions","source":"res://scripts/world/skirmish_ai.gd","stride":1,"func":"run_decisions"},
	{"name":"fog_of_war._process","source":"res://scripts/world/fog_of_war.gd","stride":4,"func":"_process"},
	{"name":"fog_of_war.rebuild","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"rebuild"},
	{"name":"fog_of_war._upload_mask","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_upload_mask"},
	{"name":"path_service.find_path","source":"res://scripts/world/path_service.gd","stride":1,"func":"find_path"},
	{"name":"path_service._build_zones","source":"res://scripts/world/path_service.gd","stride":1,"func":"_build_zones"},
	{"name":"vehicle_passages.route","source":"res://scripts/world/vehicle_passages.gd","stride":4,"func":"route"},
	{"name":"local_traffic.apply","source":"res://scripts/units/local_traffic.gd","stride":32,"func":"apply","iteration_unit":"avoidance candidates"},
	{"name":"unit_logistics.tick","source":"res://scripts/units/unit_logistics.gd","stride":32,"func":"tick"},
	{"name":"open_topped.tick","source":"res://scripts/units/open_topped.gd","stride":16,"func":"tick"},
	{"name":"auto_w.tick","source":"res://scripts/units/auto_w.gd","stride":32,"func":"tick"},
	{"name":"auto_w.evaluate","source":"res://scripts/units/auto_w.gd","stride":8,"func":"evaluate"},
	{"name":"repair_dock.tick","source":"res://scripts/buildings/repair_dock.gd","stride":8,"func":"tick"},
	{"name":"hud._process","source":"res://scripts/ui/hud.gd","stride":1,"func":"_process"},
	{"name":"hud._refresh_selection","source":"res://scripts/ui/hud.gd","stride":1,"func":"_refresh_selection"},
	{"name":"hud._refresh_strip_live","source":"res://scripts/ui/hud.gd","stride":4,"func":"_refresh_strip_live"},
	{"name":"minimap._draw","source":"res://scripts/ui/minimap.gd","stride":1,"func":"_draw"},
	{"name":"projectile._physics_process","source":"res://scripts/units/projectile.gd","stride":16,"func":"_physics_process"},
	{"name":"projectile._draw","source":"res://scripts/units/projectile.gd","stride":16,"func":"_draw"},
	{"name":"ra2_fx._process","source":"res://scripts/core/ra2_fx.gd","stride":32,"func":"_process"},
	{"name":"ra2_fx._draw","source":"res://scripts/core/ra2_fx.gd","stride":32,"func":"_draw"},
	{"name":"battle_neighborhood.nearby","source":"res://scripts/world/battle_neighborhood.gd","stride":64,"func":"nearby","iteration_unit":"spatial buckets visited"},
	{"name":"fog.expire_held","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_expire_held_sight","iteration_unit":"held-cell visits"},
	{"name":"fog.hold_vacated","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_hold_vacated_scouts","iteration_unit":"batched held-cell writes"},
	{"name":"fog.apply_masks","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_apply_live_masks"},
	{"name":"fog.sync_mask","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_sync_mask","iteration_unit":"individual mask-cell visits"},
	{"name":"fog.publish","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_publish_combat_sight","iteration_unit":"actor visits"},
	{"name":"fog.visual_fade","source":"res://scripts/world/fog_of_war.gd","stride":4,"func":"_advance_visual","iteration_unit":"fading-cell visits"},
	{"name":"unit.weapon_domain","source":"res://scripts/units/unit.gd","stride":32,"func":"_weapon_domain_valid"},
	{"name":"unit.weapon_target","source":"res://scripts/units/unit.gd","stride":32,"func":"_weapon_target_valid"},
	{"name":"building.unloading_miner","source":"res://scripts/buildings/building.gd","stride":8,"func":"unloading_miner","iteration_unit":"harvester candidates"},
	{"name":"path.bridge_at","source":"res://scripts/world/path_service.gd","stride":32,"func":"bridge_at","iteration_unit":"deck tests"},
	{"name":"battle.building_index","source":"res://scripts/world/battle.gd","stride":1,"func":"_buildings_for_side","iteration_unit":"index rebuild visits"},
	{"name":"battle.owned_buildings","source":"res://scripts/world/battle.gd","stride":8,"func":"owned_building_ids","iteration_unit":"prerequisite building candidates"},
	{"name":"unit.bridge_layers","source":"res://scripts/units/unit.gd","stride":32,"func":"_slide_across_bridge_layers","iteration_unit":"bridge layer candidates"},
	{"name":"bridge_traffic.sample","source":"res://scripts/world/bridge_traffic.gd","stride":16,"func":"sample","iteration_unit":"diagnostic actor samples"},
	{"name":"bridge_traffic.record","source":"res://scripts/world/bridge_traffic.gd","stride":64,"func":"record"},
	{"name":"unit.hit_test","source":"res://scripts/units/unit.gd","stride":64,"func":"hit_test","iteration_unit":"early broad-bound rejections"},
	{"name":"production_technology.block_reason","source":"res://scripts/rules/production_technology.gd","stride":32,"func":"block_reason","iteration_unit":"technology gate visits"},
	{"name":"battle.factory_speed","source":"res://scripts/world/battle.gd","stride":32,"func":"factory_speed_factor","iteration_unit":"operational eligibility checks"},
	{"name":"projectile.impact_candidates","source":"res://scripts/units/force_fire.gd","stride":8,"func":"impact_candidates","iteration_unit":"broad phase actor candidates"},
	{"name":"missile.impact","source":"res://scripts/units/soviet_advanced.gd","stride":8,"func":"fly","iteration_unit":"broad phase actor candidates"},
	{"name":"missile.advance","source":"res://scripts/units/dread_missile.gd","stride":16,"func":"advance","iteration_unit":"flight integration steps"},
	{"name":"projectile.trail_record","source":"res://scripts/units/projectile_visual.gd","stride":32,"func":"record","iteration_unit":"inserted trail points"},
	{"name":"projectile.trail_paint","source":"res://scripts/units/projectile_visual.gd","stride":32,"func":"paint_path","iteration_unit":"input trail points"},
	{"name":"projectile.explode","source":"res://scripts/units/projectile.gd","stride":8,"func":"_explode"},
	{"name":"path.nearest_walkable","source":"res://scripts/world/path_service.gd","stride":32,"func":"_nearest_walkable","iteration_unit":"candidate grid cells"},
	{"name":"path.bounded_search","source":"res://scripts/world/path_service.gd","stride":1,"func":"_bounded_grid_path","iteration_unit":"expanded grid cells"},
	{"name":"fog.live_mask_pool","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_begin_live_masks","iteration_unit":"allocated alliance images"},
	{"name":"repair.candidates","source":"res://scripts/buildings/repair_dock.gd","stride":32,"func":"candidates","iteration_unit":"repair membership actor visits"},
	{"name":"unit.search_weapon_reuse","source":"res://scripts/units/unit.gd","stride":1,"func":"_refresh_target","iteration_unit":"reused candidate weapon resolutions"},
	{"name":"unit.unchanged_turn","source":"res://scripts/units/unit.gd","stride":1,"func":"_limit_turn","iteration_unit":"unchanged ground angle pairs"},
	{"name":"fog.expiry_copy_avoided","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_expire_held_sight","iteration_unit":"unchanged observer entries not reassigned"},
	{"name":"local_traffic.request_yield","source":"res://scripts/units/local_traffic.gd","stride":32,"func":"request_yield","iteration_unit":"tested yield directions"},
	{"name":"open_topped.search_weapon_reuse","source":"res://scripts/units/open_topped.gd","stride":1,"func":"command_range","iteration_unit":"reused passenger weapon resolutions"},
	{"name":"open_topped.command_range","source":"res://scripts/units/open_topped.gd","stride":32,"func":"command_range","iteration_unit":"eligible passenger visits"},
	{"name":"open_topped.weapon","source":"res://scripts/units/open_topped.gd","stride":32,"func":"weapon"},
	{"name":"ai.bridge_worker_reserved","source":"res://scripts/world/ai_emergency_engineer.gd","stride":1,"func":"enqueue","iteration_unit":"paid bridge worker reservations"},
	{"name":"ai.blocked_route_wait","source":"res://scripts/world/ai_blocked_route.gd","stride":1,"func":"waiting","iteration_unit":"unreachable wave retries deferred"},
	{"name":"progression.player_infantry_idle","source":"res://scripts/units/unit_expansion_idle.gd","stride":1,"func":"try_tick","iteration_unit":"ordinary player infantry bookkeeping updates without effect-handler scans"},
	{"name":"auto_w.embarked_rejected","source":"res://scripts/units/auto_w.gd","stride":1,"func":"evaluate","iteration_unit":"cargo W checks rejected before loadout resolution"},
	{"name":"open_topped.redundant_domain_skipped","source":"res://scripts/units/open_topped.gd","stride":1,"func":"command_range","iteration_unit":"passenger domain checks unable to increase an already eligible range"},
	{"name":"production_inspector.inspect","source":"res://scripts/ui/production_inspector.gd","stride":1,"func":"inspect","iteration_unit":"retained description reuse"},
	{"name":"production_inspector.refresh","source":"res://scripts/ui/production_inspector.gd","stride":1,"func":"refresh","iteration_unit":"replaced description characters"},
	{"name":"fog.fire_held_cover","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_held_covers_firing","iteration_unit":"held cell deadline checks"},
	{"name":"fog.covered_fire_expiry","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_process","iteration_unit":"shot expiries already fully held"},
	{"name":"fog.live_scout_cover","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_scout_covers_firing","iteration_unit":"current scout candidates"},
	{"name":"fog.scouted_fire_expiry","source":"res://scripts/world/fog_of_war.gd","stride":1,"func":"_process","iteration_unit":"shot expiries contained in current scout sight"},
	{"name":"unit.extended_target_interval","source":"res://scripts/units/unit.gd","stride":1,"func":"_target_refresh_interval","iteration_unit":"large AI autonomous target scans scheduled at 0.64 simulation seconds"}
]
static var owner := 0
static var buckets: Array = []
static var paths: Dictionary = {}

class Scope extends RefCounted:
	var bucket: Array
	var started: int
	func _init(row: Array) -> void:
		bucket = row
		started = Time.get_ticks_usec()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			var elapsed := maxi(0, Time.get_ticks_usec()-started)
			bucket[1] += 1
			bucket[2] += elapsed
			bucket[3] = maxi(bucket[3],elapsed)

static func start(session: int) -> void:
	owner = session
	paths = {}
	reset()

static func reset() -> void:
	buckets = []
	for i in POINTS.size():
		# calls, timed calls, sampled total us, sampled max us, next sample, private PRNG
		buckets.append([0,0,0,0,1,104729+i*97,0])

static func stop(session: int) -> void:
	if owner == session: owner = 0

static func enter(index: int) -> RefCounted:
	if owner == 0: return null
	var row: Array = buckets[index]
	row[0] += 1
	if row[0] < row[4]: return null
	var stride: int = POINTS[index].stride
	# Jitter avoids repeatedly timing the same unit in a stable update order.
	# Never consume the gameplay random-number stream.
	row[5] = (int(row[5])*1103515245+12345)&0x7fffffff
	row[4] = row[0]+1+int(row[5])%maxi(1,stride*2-1)
	return Scope.new(row)

static func iterations(index: int, count: int) -> void:
	if owner != 0: buckets[index][6] += count

static func take(session: int) -> Array:
	if owner != session: return []
	var result: Array = []
	for i in buckets.size():
		var row: Array = buckets[i]
		if row[0] == 0 and row[6] == 0: continue
		var samples: int = row[1]
		var mean: float = float(row[2])/samples if samples>0 else 0.0
		result.append({"name":POINTS[i].name,"source":POINTS[i].source,"function":POINTS[i].func,
			"calls":row[0],"timed_calls":samples,"mean_sample_stride":POINTS[i].stride,
			"iterations":row[6],"iteration_unit":POINTS[i].get("iteration_unit",""),
			"sampled_total_ms":float(row[2])/1000.0,"sampled_mean_us":mean,
			"sampled_max_ms":float(row[3])/1000.0,"estimated_inclusive_ms":mean*int(row[0])/1000.0})
	reset()
	return result
