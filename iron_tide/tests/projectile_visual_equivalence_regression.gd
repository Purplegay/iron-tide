extends "res://tests/base_recovery_regression.gd"
const Visual=preload("res://scripts/units/projectile_visual.gd")
const Reference=preload("res://tests/projectile_visual_reference.gd")
class Shot extends Node2D:
	var ra2_image: String
	var ra2_inviso:=false
	var is_sonic:=false
	var ra2_arcing:=false
	var ra2_homing:=true
	var _arc_z:=33.0
	var _arc_len:=400.0
	var _arc_from:=Vector2(100,100)
	var _arc_h:=90.0
	var target_point:=Vector2(500,100)
	var target=null
	var splinters:Dictionary={"visual_target_lift":17.0}
	var _trail:Array[Vector2]=[]

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for id in ["DRAGON","MEDUSA","none","","V3"]:
		for flags in 16:
			var old:=Shot.new();var current:=Shot.new()
			for shot in [old,current]:
				shot.ra2_image=id;shot.ra2_inviso=(flags&1)!=0;shot.is_sonic=(flags&2)!=0
				shot.ra2_arcing=(flags&4)!=0;shot.ra2_homing=(flags&8)!=0
				add_child(shot)
			for i in 28:
				var point:=Vector2(100+i*17,100+sin(i)*20) if i!=15 else Vector2(10000,10000)
				old.position=point;current.position=point
				Reference.record(old);Visual.record(current)
				check(old._trail==current._trail,"exact trail sequence including jumps "+str([id,flags,i]))
				check(Reference.visual_position(old)==Visual.visual_position(current),"exact visual position")
				check(Reference.lift_at(old,point)==Visual.lift_at(current,point),"exact ballistic lift")
			old.free();current.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
