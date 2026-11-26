extends Node
const Dispatch = preload("res://scripts/world/ai_unit_dispatch.gd")
class Fixture:
	var skirmish := true
	var allied_state := {}
class Actor:
	var side := "enemy"
var count := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var d := Dispatch.new()
	var w := Fixture.new()
	var u := Actor.new()
	var a := Actor.new()
	var b := Actor.new()
	d.frame = Engine.get_process_frames()
	d.limit = 0
	for i in 20:
		check(d.defer_job(w,u,"operations",true), "saturated marker postponed")
		d.defer_job(w,u,"board",a)
		d.allow(w,u)
		d.allow_scan(w,u)
	var waiting: Dictionary = w.allied_state[Dispatch.WAITING]
	var entry: Dictionary = waiting[u]
	check(waiting.size()==1 and entry.jobs.size()==2,"one slot per unit and kind")
	check(entry.jobs.board==a and entry.scan and entry.path_tick==Engine.get_physics_frames(),"same payload and current path stamp")
	d.defer_job(w,u,"board",b)
	d.defer_job(w,u,"micro",0.5)
	d.defer_job(w,u,"micro",1.25)
	check(entry.jobs.board==b and entry.jobs.micro==1.25 and entry.jobs.operations,"changed target and elapsed replace only their kind")
	await get_tree().physics_frame
	d.frame = Engine.get_process_frames()
	check(not d.allow(w,u) and entry.path_tick==Engine.get_physics_frames(),"path request renews next physics step")
	d.limit = 1
	check(not d.defer_job(w,u,"board",b) and not entry.jobs.has("board") and entry.jobs.has("micro"),"grant consumes only its kind")
	check(d.allow_scan(w,u) and not entry.has("scan") and entry.has("path_tick"),"scan grant leaves other jobs untouched")
	print("Pending task merge: ",count," checks, ",failed," failures")
	get_tree().quit(0 if failed==0 else 1)
