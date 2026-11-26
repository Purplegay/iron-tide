extends RefCounted

static func dinosaur(w):
	return w.units.filter(func(u):return w.actor_alive(u) and u.unit_id == "DNOA")[0]

static func run(t,w) -> void:
	var mission = w.Hollywood
	var state:Dictionary = w.allied_state.hollywood
	state.briefing = false
	var rex = dinosaur(w)
	var post:Vector2 = rex.position
	var boundary:Vector2 = mission.cell(128,130)
	var scout = w.spawn_unit("E1","ally",mission.cell(127,130))
	w.spawn_unit("INIT","enemy",boundary).set_fire_stance("none")
	mission.tick(w,0.01)
	t.check(rex.side == "neutral" and rex.fire_stance == "none" and not state.visited.has("恐龙片场"),"外围敌军与圈外盟军不惊醒霸王龙")
	scout.position = mission.cell(140,134)
	mission.tick(w,0.01)
	t.check(rex.side == "neutral","片场中心不冒充原图外围标记格")
	scout.position = mission.cell(127,130)
	w.neighborhood.relocate(scout)
	w.fog.reset_exploration("ally")
	var revealed_point:Vector2 = mission.cell(146,134)
	t.check(not w.position_explored_by("ally",revealed_point),"进入前航点另一侧仍有未探索地块")
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	var before:Dictionary = codec.capture(w)
	scout.set_fire_stance("none")
	scout.order_move(mission.cell(129,130))
	for step in 240:
		await w.get_tree().physics_frame
		if rex.side == "ally": break
	t.check(rex.side == "ally" and rex.special.get("rexy_guard_origin") == post and state.visited.has("恐龙片场"),"地面侦察触发原有霸王龙转为盟军并开始区域警戒")
	t.check(w.position_explored_by("ally",revealed_point),"发现事件揭开航点62周围的地图")
	rex.set_fire_stance("none")
	mission.tick(w,0.01)
	t.check(rex.fire_stance == "none" and not rex.special.has("rexy_guard_origin"),"重复进入保留玩家停火命令")
	codec.restore(w,before)
	w.paused = false
	w.get_tree().paused = false
	rex = dinosaur(w)
	state = w.allied_state.hollywood
	t.check(rex.side == "neutral" and not state.get("rexy_triggered",false),"发现前存档恢复为沉睡的中立霸王龙")
	var plane = w.spawn_unit("ORCA","ally",mission.cell(145,137))
	plane.position = mission.cell(144,137)
	mission.tick(w,0.01)
	t.check(plane.is_air and rex.side == "ally" and rex.is_in_group("allies"),"盟军飞越另一侧外围也能招募")
	var after:Dictionary = codec.capture(w)
	codec.restore(w,after)
	w.paused = false
	w.get_tree().paused = false
	rex = dinosaur(w)
	t.check(rex.side == "ally" and rex.fire_stance == "free" and rex.special.get("rexy_guard_origin") == post and w.allied_state.hollywood.get("rexy_triggered",false),"激活后恢复阵营、警戒位置和一次性触发状态")
	# Choose open ground connected to the dinosaur's actual post for the intruder.
	var approach := Vector2.INF
	for i in 16:
		var p:Vector2 = post + Vector2.RIGHT.rotated(i*TAU/16)*175.0
		if w.path_service.is_blocked(p) or w.in_water_world(p): continue
		var path:PackedVector2Array = w.path_for_unit(rex,p)
		if not path.is_empty() and path[-1].distance_to(p)<50:
			approach = p
			break
	t.check(approach.is_finite(),"片场警戒岗附近有可达的街道")
	if not approach.is_finite(): return
	var intruder = w.spawn_unit("INIT","enemy",approach)
	intruder.set_fire_stance("none")
	w.fog.rebuild()
	var hp:float = intruder.hp
	var walked := false
	for step in 420:
		await w.get_tree().physics_frame
		walked = walked or rex.position.distance_to(post)>20
		if not w.actor_alive(intruder) or intruder.hp < hp: break
	t.check(walked and (not w.actor_alive(intruder) or intruder.hp < hp),"霸王龙主动走出警戒岗并咬伤入侵者")
	if w.actor_alive(intruder): intruder._die()
	for step in 420:
		await w.get_tree().physics_frame
		if rex.position.distance_to(post)<=rex.ARRIVE_EPS+1: break
	t.check(rex.position.distance_to(post)<=rex.ARRIVE_EPS+1,"附近敌人消失后返回片场警戒岗")
	w.select_unit(rex,false)
	w._issue_order(approach)
	t.check(w.selected_units.has(rex) and rex.has_move_order and not rex.special.has("rexy_guard_origin"),"玩家选中霸王龙并下达新命令后接管行动")
	codec.restore(w,before)
	w.paused = false
	w.get_tree().paused = false
	dinosaur(w)._die(null,true)
	w.spawn_unit("E1","ally",boundary)
	mission.tick(w,0.01)
	t.check(w.allied_state.hollywood.get("rexy_triggered",false) and not w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="DNOA"),"发现前霸王龙已死亡时仍可发现片场且不会重生")
