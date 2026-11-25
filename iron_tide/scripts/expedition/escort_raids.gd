extends RefCounted
## Serializable ambush schedule lives in expedition_task; no live references in saves.
const Rules=preload("res://scripts/expedition/rules.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const WARNING := 5.0
const FIRST_WARNING_AT := 60.0
const FIRST_WARNING := 10.0
const INTERVAL := 40.0

static func target(tasks):
	for n in 3:
		if n in tasks.state.arrived:continue
		var truck=tasks.actor("convoy"+str(n))
		if truck!=null:return truck
	return null

static func tick(tasks, delta:float) -> void:
	var s:Dictionary=tasks.state
	var world=tasks.world
	var truck=target(tasks)
	if truck==null:return
	# Retarget surviving raiders so a paused or moving convoy cannot evade the raid by leaving a fixed point.
	s.escort_retarget=float(s.get("escort_retarget",0.0))-delta
	if s.escort_retarget<=0:
		s.escort_retarget=3.0
		for unit in world.units:
			if not world.actor_alive(unit) or not unit.special.get("expedition_escort_raider",false) or BattleRequest.friendly("ally",unit.side):continue
			if not unit.has_move_order or unit.move_target.distance_to(truck.position)>100.0:unit.order_move(truck.position,true)
	var pending:Dictionary=s.get("escort_pending",{})
	if not pending.is_empty():
		if float(s.elapsed)<float(pending.due):return
		var roster:=Campaign.wave_units(s.stage,Rules.context().get("elite",false),"",true)
		for index in roster.size():
			var desired:Vector2=pending.position+Vector2.RIGHT.rotated(TAU*index/roster.size())*65.0
			var at:Vector2=tasks.ground(desired)
			if not at.is_finite() or at.distance_to(desired)>220.0:continue
			var unit=world.spawn_unit(roster[index],"enemy",at)
			if unit==null:continue
			unit.special.expedition_escort_raider=true
			preload("res://scripts/world/chrono_miner_fx.gd").spawn(world,at,"WARPOUT")
			unit.order_move(truck.position,true)
		s.escort_raids=int(s.get("escort_raids",0))+1
		s.erase("escort_pending")
		s.escort_next_raid=float(s.elapsed)+INTERVAL
		Events.emit_message("超时空敌军已抵达，正在袭击车队！",Color.ORANGE_RED)
		return
	if float(s.elapsed)<float(s.get("escort_next_raid",FIRST_WARNING_AT)):return
	var forward:Vector2=truck.position.direction_to(s.points[2])
	if forward==Vector2.ZERO:forward=Vector2.RIGHT
	var raid_index:=int(s.get("escort_raids",0))
	for attempt in 12:
		var desired:Vector2=truck.position+forward.rotated((1 if raid_index%2==0 else -1)*(0.5+attempt*0.45))*520.0
		var at:Vector2=tasks.ground(desired)
		if not at.is_finite() or at.distance_to(desired)>160.0:continue
		var safe:=true
		for n in 3:
			var convoy=tasks.actor("convoy"+str(n))
			if convoy!=null and at.distance_to(convoy.position)<350.0:safe=false
		if not safe:continue
		var warning := FIRST_WARNING if raid_index==0 else WARNING
		s.escort_pending={"position":at,"due":float(s.elapsed)+warning}
		Events.emit_message("超时空侵袭预警：%d 秒后敌军将在车队附近抵达！"%int(warning),Color.ORANGE_RED)
		return
	# A constrained bridge/shore may offer no safe landing; retry later, never spawn on the convoy.
	s.escort_next_raid=float(s.elapsed)+5.0
