extends RefCounted
## One paid bridge-repair worker may exceed the ordinary AI population by one.
## Actor references and the reservation live in the existing snapshot graph.
const KEY := "bridge_worker_reservation"
const IDS := ["ENGINEER","SENGINEER"]

static func clean(world,side:String) -> void:
	var state:Dictionary=world.ai_decisions(side)
	var ticket:Dictionary=state.get(KEY,{})
	if ticket.is_empty():return
	var worker=ticket.get("worker")
	if world.actor_alive(worker) and worker.side==side:return
	var line=ticket.get("producer")
	if world.actor_alive(line) and line.side==side and line.production.has(ticket.id):return
	state.erase(KEY)

static func permits(world,side:String,id:String,producer,reserve_orders:bool) -> bool:
	if id not in IDS or not BattleRequest.is_ai_house(side) or not world.actor_alive(producer) or producer.side!=side:return false
	var ticket:Dictionary=world.ai_decisions(side).get(KEY,{})
	if ticket.get("producer")!=producer or ticket.get("id")!=id or world.actor_alive(ticket.get("worker")):return false
	# A second copy in this or another queue never inherits the reservation.
	if reserve_orders and producer.production.has(id):return false
	var living:int=world.ai_living_count(side)
	var count:int=living+int(world._queued_by_house.get(side,0)) if reserve_orders else living
	return count<world.AI_UNIT_LIMIT+1

static func enqueue(world,line,id:String,hut) -> bool:
	if id not in IDS or not BattleRequest.is_ai_house(line.side) or not line.production.is_empty():return false
	if not world.actor_alive(hut) or hut.special.get("bridge_repaired",true):return false
	clean(world,line.side)
	var state:Dictionary=world.ai_decisions(line.side)
	if state.has(KEY):return false
	state[KEY]={"producer":line,"id":id,"target":hut}
	if line.enqueue(id):
		preload("res://scripts/world/battle_call_counters.gd").iterations(76,1)
		return true
	state.erase(KEY)
	return false

static func spawned(world,unit,producer) -> void:
	if unit.unit_id not in IDS or not BattleRequest.is_ai_house(unit.side):return
	var ticket:Dictionary=world.ai_decisions(unit.side).get(KEY,{})
	if ticket.get("producer")!=producer or ticket.get("id")!=unit.unit_id or world.actor_alive(ticket.get("worker")):return
	ticket.worker=unit
	unit.special.ai_bridge_repair_worker=true

static func cancelled(world,line,id:String) -> void:
	if id not in IDS or not BattleRequest.is_ai_house(line.side):return
	var state:Dictionary=world.ai_decisions(line.side)
	var ticket:Dictionary=state.get(KEY,{})
	if ticket.get("producer")==line and not line.production.has(id) and not world.actor_alive(ticket.get("worker")):state.erase(KEY)
