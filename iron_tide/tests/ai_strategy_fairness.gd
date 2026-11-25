extends Node
const Budget=preload("res://scripts/world/ai_strategy_budget.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String,details=null):
	checks.append({"passed":ok,"name":label,"details":details})
	if not ok:failed+=1;print("FAIL ",label," ",details)
func _ready():
	var sides:=["enemy","ai2","ai3","ai4","ai5"]
	var budget=Budget.new()
	var counts:={}
	for side in sides:counts[side]=0
	for frame in 100:
		var granted:=0
		for side in sides:
			if budget.claim(side,frame):counts[side]+=1;granted+=1
		check(granted==1,"one heavy decision per render "+str(frame))
	for side in sides:check(counts[side]>=19,"continuously due house cannot starve "+side,counts)
	budget=Budget.new()
	check(budget.claim("enemy",200),"first uncontended request remains immediate")
	check(not budget.claim("ai2",200) and not budget.claim("ai3",200),"contenders retain queue position")
	check(not budget.claim("enemy",201),"previous owner cannot overtake waiting houses")
	check(budget.claim("ai2",201) and budget.claim("ai2",201),"oldest request and synchronous same-house calls are admitted")
	budget.forget("ai3")
	check(budget.claim("enemy",202),"removed controller cannot block the queue")
	budget.forget("missing")
	check(budget.waiting.is_empty(),"forget is idempotent and grants leave no stale waiters")
	# A queued house may poll less often than the render loop. Keep its place
	# until its next poll, without allowing early callers to steal the slot.
	budget=Budget.new();budget.claim("enemy",300);budget.claim("ai2",300)
	check(not budget.claim("ai3",301) and not budget.claim("enemy",302),"slower poll retains oldest pending request")
	check(budget.claim("ai2",303) and budget.claim("ai3",304) and budget.claim("enemy",305),"sparse polling drains in request order")
	var stats:Dictionary=budget.diagnostics()
	check(stats.grants_by_house=={"enemy":2,"ai2":1,"ai3":1} and stats.pending_houses.is_empty(),"per-house grant counters count actual slots only")
	stats.grants_by_house.clear();stats.pending_houses.append("stale")
	check(budget.grants_by_house.size()==3 and budget.waiting.is_empty(),"diagnostic copy cannot mutate scheduler")
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"grants":counts},"\t"))
	get_tree().quit(0 if failed==0 else 1)
