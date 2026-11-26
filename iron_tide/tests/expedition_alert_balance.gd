extends Node
const Alert = preload("res://scripts/expedition/red_alert.gd")
const Plan = preload("res://scripts/expedition/reinforcement_plan.gd")
var allied_state := {}
var units := []
var ended := false
var paused := false
var failures := 0
var checks := 0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",label)
class Tank extends Unit:
	func _refresh_veteran_bonuses(_announce:bool) -> void: pass
	func add_buff(_kind:String,_duration:float,_value:float,_name:String="") -> void: pass
	func clear_buff(_kind:String) -> void: pass
func actor_alive(unit) -> bool: return is_instance_valid(unit)
func tank(label:String,rank:int,xp:float) -> Tank:
	var unit:=Tank.new()
	unit.unit_id="MTNK"
	unit.side="ally"
	unit.veteran_level=rank
	unit._vet_kills=xp
	unit.special={Plan.MEMBER:true,"expedition_variant":label}
	units.append(unit)
	return unit
func _ready() -> void:
	BattleRequest.combat_context={"expedition":{"stage":1}}
	var run := {"stage":1,"active_roster":["MTNK"],"survivors":[{"id":"MTNK","rank":2,"xp":17.0}],"heroes":["TANY"],"relics":{"red_alert_warrant":true,"alert_array":true},"relic_levels":{}}
	for level in range(5):
		run.relic_levels.alert_array=level
		Alert.setup(self,run,false)
		var s:=Alert.state(self)
		var expected:float=[49000,46550,44100,41650,41650][level]
		check(is_equal_approx(Alert.threshold(s),expected) and is_equal_approx(s.threat,expected/2) and s.charge==0,"half at level %d"%level)
	check(not Alert.activate(self),"half cannot activate")
	run.red_alert_charge=1
	Alert.setup(self,run,false)
	Expedition.state={"catalog":["MTNK"]}
	var rookie:=tank("rookie",0,13.0)
	tank("elite",2,17.0)
	check(Alert.activate(self),"carried charge activates")
	tank("during",1,22.0)
	Alert.tick(self,1.0)
	check(rookie.veteran_level==2,"actual promotion to native cap")
	Alert.tick(self,Alert.DURATION)
	tank("after",0,31.0)
	Alert.setup(self,run,true)
	allied_state.expedition_reinforcement_plan=[{"id":"MTNK","rank":2,"xp":43.0,"variant":"pending"}]
	var rows:=Expedition.collect(self,false)
	var ranks:={}
	for row:Dictionary in rows: ranks[row.variant]=[row.rank,row.xp]
	check(ranks.get("rookie")==[1,0.0],"activated promotion carries one star")
	check(ranks.get("elite")==[2,17.0],"already elite preserves rank and xp")
	check(ranks.get("during")==[1,0.0],"promoted on later tick")
	check(ranks.get("after")==[0,31.0],"missed alert preserves rank and xp")
	check(ranks.get("pending")==[2,43.0],"pending preserves rank and xp")
	run.survivors=rows
	run.alert_one_star=true # obsolete flag in older saves
	var plan:=Plan.build(run)
	check(plan.any(func(r):return r.hero=="TANY" and r.rank==0),"fresh hero ignores obsolete global flag")
	for unit in units:unit.free()
	print("ALERT CHECKS ",checks," FAILURES ",failures)
	get_tree().quit(int(failures>0))
