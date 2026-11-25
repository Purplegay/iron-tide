extends Node
const Mail=preload("res://scripts/expedition/cycle_letters.gd")
const Missions=preload("res://scripts/expedition/field_missions.gd")
var errors:Array=[]
func check(value:bool,label:String) -> void:
	if not value:errors.append(label)
class ProbeUnit extends RefCounted:
	var position:=Vector2.ZERO
	var hp:=50.0
	var max_hp:=100.0
	var special:={}
	var data:Dictionary
	var unit_id:String
	func _init(id:String):
		unit_id=id;data=GameData.unit_index[id]
	func heal(amount:float):hp=minf(max_hp,hp+amount)

class Probe extends RefCounted:
	var world:={"units":[]}
	func near(a:Vector2,b:Vector2) -> bool:return a.distance_to(b)<150
	func operable(_u) -> bool:return true
	func finish(o:Dictionary,_text:String):o.done=true

func check_actions() -> void:
	for kind:String in Missions.Assign.BOOK:
		var m:=Probe.new()
		var a:=ProbeUnit.new("ENGINEER")
		var b:=ProbeUnit.new("MTNK" if GameData.unit_index.has("MTNK") else "HTNK")
		var c:=ProbeUnit.new("E1")
		var home:=Vector2.ZERO
		var away:=Vector2(1000,0)
		var off:=Vector2(2000,0)
		var o:={"id":"field1","kind":kind,"position":home,"station":away,"progress":0.0,"done":false,"phase":"open"}
		var d:={"supplies":0}
		m.world.units=[a,b,c];a.position=off;b.position=off;c.position=off
		Missions.Assign.update(m,o,d,1);check(not o.done,"empty "+kind)
		a.position=home
		match kind:
			"muster":b.position=home;c.position=home
			"mixed","fieldshop":b.position=home
			"survey","courier":
				Missions.Assign.update(m,o,d,1);a.position=away
				if kind=="courier":Missions.Assign.update(m,o,d,1);a.position=home
			"relay_pair":b.position=away
			"handoff","evac":
				Missions.Assign.update(m,o,d,1);a.position=off
				if kind=="handoff":Missions.Assign.update(m,o,d,1);b.position=home
			"shuttle":b.position=away;Missions.Assign.update(m,o,d,1);b.position=home
		Missions.Assign.update(m,o,d,8)
		check(o.done and (d.get("kits",0)==1 if kind=="fieldshop" else d.supplies==35),"finish "+kind)

func check_missing_requirements() -> void:
	for kind:String in ["triage","muster","relay_pair","mixed","fieldshop","handoff","shuttle"]:
		var m:=Probe.new()
		var u:=ProbeUnit.new("E1")
		u.hp=u.max_hp
		var d:={"supplies":0}
		var o:={"kind":kind,"position":Vector2.ZERO,"station":Vector2(1000,0),"phase":"open","id":"f1","done":false,"failed":false,"progress":0.0}
		var time:=6 if kind=="triage" else 12
		Missions.Assign.update(m,o,d,60)
		check(not o.done,"no ground units "+kind)
		m.world.units=[u]
		Missions.Assign.update(m,o,d,time-1)
		check(not o.done and Missions.Assign.hint(o).contains("秒"),"timer hint "+kind)
		u.position=Vector2(900,0);Missions.Assign.update(m,o,d,1)
		check(o.service_time==0,"reset "+kind)
		u.position=Vector2.ZERO;Missions.Assign.update(m,o,d,time)
		Missions.Assign.update(m,o,d,time)
		check(o.done and (d.get("kits",0)==1 if kind=="fieldshop" else d.supplies==35),"single award "+kind)

func _ready() -> void:
	check_missing_requirements()
	check_actions()
	check_cargo_frequency()
	check(Missions.names().size()+Missions.BASIC_NAMES.size()==20,"20 missions")
	check(Mail.cycle({"expedition:a:30":{},"expedition:b:12":{}},30)==2,"clear receipts")
	var budgets:=[]
	for n in range(1,6):
		var history:=[]
		var covered:=0
		for stage in range(1,31):
			var field=preload("res://scripts/expedition/field_operations.gd")
			var arrival:int=field.available_arrival(stage,history)
			var slots:=Missions.Assign.slots(arrival)
			for offered in [0,arrival]:
				var plan:=Missions.Assign.slots(offered)
				check(plan==([0,1] if offered>0 else [1]),"each stage offers a field job alongside any rescue")
			if not slots.is_empty():covered+=1
			check(slots.has(1),"rescue patrol remains available")
			check(slots.has(0)==(arrival>0),"offer matches remaining support dates")
			if slots.has(0):history.append({"stage":arrival})
		check(covered==30,"all 30 stages offer optional field jobs")
		for due in range(6,25):
			if due%5!=0:check({"stage":due} in history,"earned ally on stage %d"%due)
		budgets.append(history.size())
		for id:String in Mail.MAIL:
			check(Mail.letters(id,n,{}).is_empty(),"unknown")
			check(Mail.letters(id,n,{"rescued":true}).size()==n-1,"mail")
			check(Mail.letters(id,n,{"rescued":true,"joint_record":{}}).size()==n-1+int(n>=2),"postscript")
	print("CYCLE_REGRESSION budgets=",budgets," errors=",errors)
	get_tree().quit(0 if errors.is_empty() else 1)

func check_cargo_frequency() -> void:
	var campaign := preload("res://scripts/expedition/campaign.gd")
	for cycle in range(1,6):
		var counts := {"fuel":0,"box":0}
		for seed_value in range(1,33):
			var run := {"seed":seed_value,"cycle":cycle,"history":[]}
			for stage in range(1,31):
				run.stage = stage
				var routes: Array = campaign.routes(run)
				var route: Dictionary = routes[(seed_value + stage) % routes.size()]
				var kind := Missions.candidate(seed_value,stage,route,cycle)
				if counts.has(kind):
					counts[kind] += 1
					check(route.task!="escort" and (kind!="box" or stage<30),"cargo matches the main objective")
				run.history.append({"map":route.map,"stage":stage})
		for kind: String in counts:
			check(counts[kind]>=3*32,"at least three %s offers per run on average in cycle %d" % [kind,cycle])
