extends "res://tests/base_recovery_regression.gd"
const Dust=preload("res://scripts/units/tank_finish_dust.gd")
const Finish=preload("res://scripts/units/tank_finish.gd")

class Actor extends Node2D:
	var _dead:=false
	var embarked_in=null
	var move_speed:=100.0
	var radius:=18.0
	var special:Dictionary={}

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	Dust.cache.clear()
	for radius in [12.0,18.0,26.0]:
		for index in Dust.FRAMES:
			var particles:=0
			var age:float=(index+0.25)*TAU/Dust.FRAMES/Dust.SPEED
			for behind in [false,true]:
				var mesh=Dust.mesh(radius,age,behind)
				check(is_same(mesh,Dust.mesh(radius,age,behind)),"shared dust geometry",[radius,index,behind])
				var arrays=mesh.surface_get_arrays(0)
				var points=arrays[Mesh.ARRAY_VERTEX]
				var indices=arrays[Mesh.ARRAY_INDEX]
				var vertices_per_particle:=8+1+Dust.SIDES*2
				particles+=points.size()/vertices_per_particle
				var valid:bool=points.size()%vertices_per_particle==0 and arrays[Mesh.ARRAY_COLOR].size()==points.size()
				for point in points:valid=valid and point.is_finite() and point.length()<radius*2.3+4
				for vertex in indices:valid=valid and vertex>=0 and vertex<points.size()
				check(valid,"finite geometry and bounded indices",[radius,index,behind])
			check(particles==24,"front and back retain all dust particles",[radius,index,particles])
	check(Dust.frame(TAU/Dust.SPEED)==Dust.frame(0),"dust cycle wraps")
	check(Dust.cache[1800].size()==Dust.FRAMES*2,"bounded phase cache")
	var actor:=Actor.new();add_child(actor)
	var finish=Finish.new(5)
	finish.tick(actor,0.1)
	check(finish.dust==0,"stationary spawn has no dust")
	for i in 10:
		actor.position.x+=5
		finish.tick(actor,0.1)
	check(is_equal_approx(finish.dust,1),"moving dust grows fully")
	finish.tick(actor,0.2)
	check(finish.dust>0 and finish.dust<1,"stopping fades rather than snaps")
	finish.tick(actor,1)
	check(finish.dust==0,"stopped dust clears")
	actor.position.x+=1000;finish.tick(actor,0.1)
	check(finish.dust==0,"teleport does not emit driving dust")
	finish.shell_hit();finish.tick(actor,0.1)
	check(finish.wall>0,"shell hit still flashes armor")
	finish.tick(actor,1)
	check(finish.wall==0,"armor flash clears")
	actor.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
