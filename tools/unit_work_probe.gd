extends RefCounted
# Diagnostic only. Counts are exact; nested timings sample entire unit updates.
# No actor references, gameplay RNG, timers or disk I/O are retained in hot paths.
static var enabled := false
static var actors: Dictionary = {}
static var current: Dictionary = {}
static var sequence := 0
const HOT_POINTS := {}
static var traces: Array = []
static var trace_counts: Dictionary = {}

class UpdateScope extends RefCounted:
	var owner: Script
	var previous: Dictionary
	var context: Dictionary
	func _init(actor, probe: Script):
		owner=probe
		previous = owner.current
		var id: int = actor.get_instance_id()
		var row: Dictionary = owner.actors.get_or_add(id, {"instance":id,"type":actor.unit_id,"side":actor.side,"updates":0,"timed_updates":0,"total_us":0,"total_all_us":0,"max_update_us":0,"max_update_frame":0,"hot":{},"states":{},"functions":{},"loops":{},"phases":{}})
		row.updates += 1
		owner.sequence += 1
		# Hash the invocation ordinal; never use the game's random stream.
		var sampled: bool = ((owner.sequence * 1103515245 + 12345) & 0x7fffffff) % 31 == 0
		var state: String = "dead" if actor._dead else ("embarked" if actor.embarked_in != null else ("repairing" if actor.repairing else ("harvesting" if actor.is_harvester else ("air_"+actor.logistics.air_state if actor.is_air else ("moving" if actor.has_move_order else ("target" if is_instance_valid(actor.attack_target) else "idle"))))))
		row.states[state] = int(row.states.get(state,0)) + 1
		context = {"row":row,"sampled":sampled,"stack":[],"phase":"entry","phase_start":Time.get_ticks_usec(),"start":Time.get_ticks_usec()}
		owner.current = context
		if sampled:
			row.timed_updates += 1
			context.start = Time.get_ticks_usec()
			context.phase_start = context.start
		owner.phase_count(context,"entry")
	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			var now := Time.get_ticks_usec()
			var elapsed := now-int(context.start)
			context.row.total_all_us += elapsed
			if elapsed > context.row.max_update_us:
				context.row.max_update_us=elapsed
				context.row.max_update_frame=Engine.get_physics_frames()
			if context.sampled: context.row.total_us += elapsed
			owner.finish_phase(context,now)
			owner.current = previous

class CallScope extends RefCounted:
	var context: Dictionary
	var row: Array
	var frame: Array
	var hot: Array
	func _init(ctx: Dictionary, stats: Array, hot_stats: Array):
		context=ctx;row=stats;hot=hot_stats
		frame=[Time.get_ticks_usec(),0]
		context.stack.append(frame)
	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			var elapsed := Time.get_ticks_usec()-int(frame[0])
			row[1]+=1;row[2]+=elapsed;row[3]+=maxi(0,elapsed-int(frame[1]));row[4]=maxi(row[4],elapsed)
			if not hot.is_empty():hot[0]+=1;hot[1]+=elapsed;hot[2]=maxi(hot[2],elapsed)
			context.stack.pop_back()
			if not context.stack.is_empty(): context.stack.back()[1]+=elapsed

class HotScope extends RefCounted:
	var row: Array
	var started: int
	func _init(stats:Array):
		row=stats;started=Time.get_ticks_usec()
	func _notification(what):
		if what==NOTIFICATION_PREDELETE:
			var elapsed:=Time.get_ticks_usec()-started
			row[0]+=1;row[1]+=elapsed;row[2]=maxi(row[2],elapsed)

static func begin(actor) -> RefCounted:
	return UpdateScope.new(actor,load("res://unit_work_probe.gd")) if enabled else null

static func call_point(id: int) -> RefCounted:
	if current.is_empty():return null
	var row: Array = current.row.functions.get_or_add(id,[0,0,0,0,0])
	row[0]+=1
	var hot: Array = []
	if HOT_POINTS.has(id):
		hot=current.row.hot.get_or_add(id,[0,0,0])
		if int(trace_counts.get(id,0))<3:
			trace_counts[id]=int(trace_counts.get(id,0))+1
			traces.append({"point":id,"actor":current.row.instance,"type":current.row.type,"frame":Engine.get_physics_frames(),"stack":get_stack()})
	if current.sampled:return CallScope.new(current,row,hot)
	return HotScope.new(hot) if not hot.is_empty() else null

static func loop_entry(id: int) -> void:
	if current.is_empty():return
	var row: Array = current.row.loops.get_or_add(id,[0,0])
	row[0]+=1

static func iteration(id: int) -> void:
	if current.is_empty():return
	var row: Array = current.row.loops.get_or_add(id,[0,0])
	row[1]+=1

static func phase_count(ctx:Dictionary,name:String) -> void:
	var row:Array=ctx.row.phases.get_or_add(name,[0,0,0,0])
	row[0]+=1

static func finish_phase(ctx:Dictionary,now:int) -> void:
	var row:Array=ctx.row.phases[ctx.phase]
	var elapsed:=now-int(ctx.phase_start)
	row[1]+=1;row[2]+=elapsed;row[3]=maxi(row[3],elapsed)

static func phase(name:String) -> void:
	if current.is_empty():return
	var now:=Time.get_ticks_usec()
	finish_phase(current,now)
	current.phase_start=now
	current.phase=name
	phase_count(current,name)

static func start() -> void:
	actors.clear();current={};sequence=0;traces.clear();trace_counts.clear();enabled=true

static func stop() -> Dictionary:
	enabled=false
	return {"actors":actors.values(),"traces":traces,"scope":"synchronous calls within Unit._physics_process; exact entries/iterations within declared coverage; unit and phase timings plus selected hot calls are full-timed; nested function self/inclusive CPU samples 1/31 updates; all timings include probe overhead"}
