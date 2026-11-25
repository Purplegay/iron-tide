extends RefCounted
## One FIFO per refinery. Weak references never keep dead miners alive.
var waiting: Array[WeakRef] = []
var departing: WeakRef

func prune(refinery) -> void:
	waiting = waiting.filter(func(ref):
		if ref == null: return false
		var miner = ref.get_ref()
		return is_instance_valid(miner) and not miner.is_queued_for_deletion() and not miner._dead \
			and miner.side == refinery.side and miner.embarked_in == null and not miner.has_move_order \
			and not miner.repairing and miner._dock_locked and miner._dock_home == refinery \
			and miner.harvest_state in ["to_base", "unloading"])
	if departing != null:
		var miner = departing.get_ref()
		if not is_instance_valid(miner) or miner.is_queued_for_deletion() or miner._dead or miner.embarked_in != null:
			departing = null
		else:
			var dock: Vector2 = refinery.refinery_dock_point(miner.radius)
			var stage: Vector2 = dock + refinery.refinery_dock_direction() * miner.DOCK_STAGE_BACK
			# Protect the entire reverse lane, accounting for the next vehicle's size.
			var next_radius: float = miner.radius if waiting.is_empty() else waiting[0].get_ref().radius
			var nearest := Geometry2D.get_closest_point_to_segment(miner.global_position, dock, stage)
			if miner.global_position.distance_to(nearest) > miner.radius + next_radius + 6.0:
				departing = null

func join(refinery, miner) -> void:
	prune(refinery)
	for ref in waiting:
		if ref.get_ref() == miner: return
	waiting.append(weakref(miner))

func index_of(refinery, miner) -> int:
	prune(refinery)
	for i in waiting.size():
		if waiting[i].get_ref() == miner: return i
	return -1

func can_enter(refinery, miner) -> bool:
	var index := index_of(refinery, miner)
	if index < 0 or departing != null: return false
	var front = waiting[0].get_ref()
	# A road miner on the far side of the map cannot use the berth yet.
	# Keep FIFO among arrivals and never interrupt reversing or unloading.
	if waiting.size()>1 and front._dock_phase==0 and front.harvest_state=="to_base" and not _arrived(front):
		for i in range(1,waiting.size()):
			if _arrived(waiting[i].get_ref()):
				var arrived: WeakRef = waiting.pop_at(i)
				waiting.push_front(arrived)
				break
	return waiting[0].get_ref() == miner

func _arrived(miner) -> bool:
	# Chrono miners can return from any distance once the lane is clear.
	return miner.unit_id=="CMIN" or miner.global_position.distance_to(miner._dock_stage()) <= miner.DOCK_STAGE_BACK*4.0

func release(refinery, miner) -> void:
	var was_front: bool = not waiting.is_empty() and waiting[0] != null and waiting[0].get_ref() == miner
	waiting = waiting.filter(func(ref): return ref != null and ref.get_ref() != miner)
	if was_front and not miner._dead:
		departing = weakref(miner)
	prune(refinery)

func waiting_point(refinery, miner) -> Vector2:
	var index := maxi(1, index_of(refinery, miner))
	return miner._dock_stage() + queue_offset(refinery.refinery_dock_direction(), miner.radius, index)

static func queue_offset(outward: Vector2, radius: float, index: int) -> Vector2:
	var tangent := Vector2(-outward.y, outward.x)
	var spacing := radius * 2.0 + 28.0
	return tangent * spacing + outward * spacing * (index - 1)

static func exit_distance(radius: float) -> float:
	return radius * 2.0 + 48.0

# A clear-looking tile can be outside the playable terrain on native maps.
# Keep the proven path, rather than accepting the end of a partial A* route.
func exit_route(refinery, miner, avoid: Vector2) -> PackedVector2Array:
	var outward: Vector2 = refinery.refinery_dock_direction()
	var stage: Vector2 = refinery.refinery_dock_point(miner.radius) + outward * miner.DOCK_STAGE_BACK
	var world = miner._battle_world()
	for ring in [1.0, 1.6, 2.2, 3.0]:
		for angle in [0.0, 0.55, -0.55, 1.1, -1.1, PI/2, -PI/2, 2.1, -2.1]:
			var goal: Vector2 = stage + outward.rotated(angle) * exit_distance(miner.radius) * ring
			if goal.distance_to(avoid) < miner.ARRIVE_EPS or world.path_service.is_blocked(goal): continue
			if not preload("res://scripts/world/economy_cycle.gd").miner_landing_clear(world, goal, miner.radius + 4.0, miner): continue
			var path: PackedVector2Array = world.path_for_unit(miner, goal)
			if path.size() >= 2 and path[-1].is_equal_approx(goal): return path
	return PackedVector2Array()
