extends RefCounted
# Diagnostic-only, synchronous main-thread scopes. Never installed in player builds.
static var enabled := false
static var state := {"stack":[],"rows":{},"scope_errors":0,"probe_us":0,"reported_probe_us":0}

class Scope extends RefCounted:
	var shared: Dictionary
	var context: Dictionary
	var parent: Dictionary
	var row: Array
	func _init(key:String, storage:Dictionary) -> void:
		var entered := Time.get_ticks_usec()
		shared=storage
		row=shared.rows.get_or_add(key,[0,0,0,0,0])
		row[0]+=1
		parent=shared.stack.back() if not shared.stack.is_empty() else {}
		context={"start":0,"end":0,"children":0,"row":row,"probe_start":0,"probe_end":0}
		shared.stack.append(context)
		var ready := Time.get_ticks_usec()
		shared.probe_us += ready-entered
		context.start=ready
		context.probe_start=shared.probe_us
	func _notification(what:int) -> void:
		if what!=NOTIFICATION_PREDELETE:return
		var leaving:=Time.get_ticks_usec()
		var ended:=leaving
		var probe_end:int=shared.probe_us
		# GDScript can release a function's locals in declaration order, closing
		# its parent scope before the final phase. Clamp that phase to its parent
		# and settle the parent's self time when the phase destructor arrives.
		if not parent.is_empty() and parent.end>0:
			ended=mini(ended,parent.end)
			probe_end=parent.probe_end
		context.end=ended
		context.probe_end=probe_end
		# Nested scope bookkeeping is diagnostic work, not caller self time.
		var elapsed:=maxi(0,ended-int(context.start)-(probe_end-int(context.probe_start)))
		row[1]+=elapsed
		row[2]+=elapsed-int(context.children)
		row[3]=maxi(row[3],elapsed)
		if not parent.is_empty():
			parent.children+=elapsed
			if parent.end>0:parent.row[2]-=elapsed
		while not shared.stack.is_empty() and shared.stack.back().end>0:shared.stack.pop_back()
		shared.probe_us+=Time.get_ticks_usec()-leaving

static func enter(key:String) -> RefCounted:
	return Scope.new(key,state) if enabled else null

static func iterations(key:String,count:int) -> void:
	if enabled:state.rows.get_or_add(key,[0,0,0,0,0])[4]+=count

static func start() -> void:
	state={"stack":[],"rows":{},"scope_errors":0,"probe_us":0,"reported_probe_us":0}
	enabled=true

static func take() -> Dictionary:
	var result:Dictionary=state.rows
	# A frame boundary must not bisect a synchronous measured call.
	if not state.stack.is_empty():state.scope_errors+=1
	state.rows={}
	var overhead:int=state.probe_us-state.reported_probe_us
	state.reported_probe_us=state.probe_us
	return {"points":result,"scope_errors":state.scope_errors,"scope_bookkeeping_us":overhead}
