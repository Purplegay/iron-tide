extends RefCounted
## The native make sequence starts as an MCV and ends as the construction yard.
## Persist only data in the actors' existing special dictionaries.

static func arrive(vehicle) -> bool:
	var world = vehicle._battle_world()
	var goal: Vector2 = vehicle.special.mcv_deploy_at
	if world.paused or world.ended or world.get_tree().paused: return false
	if vehicle.side != "ally" or vehicle.attack_ordered:
		vehicle.special.erase("mcv_deploy_at")
		return false
	if world.snap_build_pos(vehicle.position) == goal and vehicle.position.distance_to(goal) <= maxf(vehicle.ARRIVE_EPS, 12.0):
		vehicle.special.erase("mcv_deploy_at")
		return vehicle.deploy()
	if not vehicle.has_move_order:
		vehicle.special.erase("mcv_deploy_at")
		if vehicle.side == "ally": Events.emit_message("展开指令已结束：基地车未到达所选位置")
	return false

static func deploying(building, vehicle, origin: Vector2) -> void:
	transfer_objective(vehicle,building)
	if building._buildup_art.is_empty(): return
	var art: Dictionary = building._buildup_art
	var last := RA2Art.anchor(art, [int(art.count) - 1])
	var first := RA2Art.anchor(art, [0])
	building.special.native_make_speed = Unit.Training.timing_scale(vehicle)
	building.special.mcv_make_radius = vehicle.radius
	building.special.mcv_make_shift = Iso.dir(origin - building.global_position) \
		+ last - first + Vector2(0, (vehicle.radius - building.radius) * 0.35)

static func deployment_shift(building) -> Vector2:
	if building._buildup_play < 0.0: return Vector2.ZERO
	var progress: float = clampf(building._buildup_play / maxf(0.01, GameData.ra2_buildup_seconds()), 0, 1)
	# Settle onto the valid grid foundation smoothly, without changing collision.
	return Vector2(building.special.get("mcv_make_shift", Vector2.ZERO)) * (1.0 - smoothstep(0.0, 1.0, progress))

static func repacking(vehicle, building) -> void:
	transfer_objective(building,vehicle)
	if building._buildup_art.is_empty(): return
	vehicle.special.mcv_repack_image = str(building.data.get("buildup", ""))
	vehicle.special.mcv_repack_radius = building.radius
	vehicle.special.mcv_repack_left = GameData.ra2_buildup_seconds()

static func transfer_objective(source,target) -> void:
	if source.special.get("expedition_objective","")!="defense":return
	target.special.expedition_objective="defense"
	target.special.expedition_objective_name="防线指挥所 / 基地车"

static func active(vehicle) -> bool:
	return float(vehicle.special.get("mcv_repack_left", 0.0)) > 0.0

static func tick(vehicle, delta: float) -> bool:
	if not active(vehicle):
		if vehicle.special.erase("mcv_resume_path") and vehicle.has_move_order:
			vehicle._repath_now()
		return false
	var world = vehicle._battle_world()
	if is_instance_valid(world) and (world.paused or world.ended or world.get_tree().paused): return true
	vehicle.velocity = Vector2.ZERO
	vehicle.special.mcv_repack_left = maxf(0.0, float(vehicle.special.mcv_repack_left) - delta * Unit.Training.timing_scale(vehicle))
	if not active(vehicle) and vehicle.has_move_order:
		vehicle.special.mcv_resume_path = true
	vehicle.queue_redraw()
	return true # Orders can be queued, but movement starts after the fold completes.

static func repack_frame(vehicle) -> int:
	var art := RA2Art.art(str(vehicle.special.get("mcv_repack_image", "")))
	var count := int(art.get("count", 0))
	var fraction := float(vehicle.special.get("mcv_repack_left", 0.0)) / maxf(0.01, GameData.ra2_buildup_seconds())
	return clampi(int(ceil(fraction * count)) - 1, 0, maxi(0, count - 1))

static func repack_visual(vehicle) -> Dictionary:
	if not active(vehicle): return {}
	var art := RA2Art.art(str(vehicle.special.get("mcv_repack_image", "")))
	if art.is_empty() or art.get("tex") == null: return {}
	var count := int(art.get("count", 0))
	var last := RA2Art.anchor(art, [count - 1])
	var first := RA2Art.anchor(art, [0])
	var radius := float(vehicle.special.get("mcv_repack_radius", vehicle.radius))
	var progress := 1.0 - float(vehicle.special.mcv_repack_left) / maxf(0.01, GameData.ra2_buildup_seconds())
	var shift := (last - first + Vector2(0, (vehicle.radius - radius) * 0.35)) * smoothstep(0.0, 1.0, progress)
	var base := Vector2(-last.x, radius * 0.35 - last.y) + shift
	return {"art": art, "base": base, "shift": shift, "radius": radius,
		"anchors": [count - 1], "frame": repack_frame(vehicle), "progress": progress}

static func draw_repack(vehicle) -> bool:
	var visual := repack_visual(vehicle)
	if visual.is_empty(): return false
	var radius: float = visual.radius
	var shadow_radius := lerpf(radius, vehicle.radius, visual.progress)
	var ground: Vector2 = visual.base + RA2Art.anchor(visual.art, [visual.frame])
	Iso.shadow(vehicle, ground + Vector2(shadow_radius * 0.34, -shadow_radius * 0.15), shadow_radius * 0.85, 0.30)
	vehicle.draw_body_sprite(visual.art, Rect2(visual.base, RA2Art.frame_size(visual.art)),
		RA2Art.src_rect(visual.art, visual.frame))
	return true
