extends Node
const Heroes=preload("res://scripts/expedition/heroes.gd")
class World extends RefCounted:
	var allied_state:Dictionary={}
var failures:=0
var checks:=0
func check(value:bool,text:String) -> void:
	checks+=1
	if not value:failures+=1;print("FAIL ",text)
func _ready() -> void:
	var world=World.new()
	var run:Dictionary={"hero":"E1","heroes":["E1","TANY"],"wounded_heroes":[],"hero_wounded":false,"survivors":[]}
	Heroes.update_wounded(run,world)
	check(run.wounded_heroes.is_empty(),"absent heroes without death events are not wounded")
	world.allied_state.expedition_hero_deaths=["TANY"]
	Heroes.update_wounded(run,world)
	check(run.wounded_heroes==["TANY"] and not run.hero_wounded,"real Tanya death requires rescue")
	world.allied_state.expedition_hero_deaths=[]
	Heroes.update_wounded(run,world)
	check(run.wounded_heroes==["TANY"],"pre-existing wound remains")
	run.survivors=[{"hero":"TANY"}]
	Heroes.update_wounded(run,world)
	check(run.wounded_heroes.is_empty(),"living or pending Tanya clears wound")
	run.survivors=[]
	world.allied_state.expedition_hero_deaths=["E1","E1"]
	Heroes.update_wounded(run,world)
	check(run.wounded_heroes==["E1"] and run.hero_wounded,"selected hero death is deduplicated and updates legacy flag")
	print("HERO WOUNDED EVENTS checks=",checks," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)
