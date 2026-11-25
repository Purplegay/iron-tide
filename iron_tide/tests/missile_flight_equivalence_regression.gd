extends "res://tests/base_recovery_regression.gd"
const Flight=preload("res://scripts/units/dread_missile.gd")
const Reference=preload("res://tests/missile_flight_reference.gd")
class Missile extends Node2D:
	var unit_id: String
	var hull_angle:=0.0
	var logistics:Dictionary={"air_lift":0.0}
	var special:Dictionary={}
	func _battle_world():return null

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for id in ["V3ROCKET","DMISL"]:
		for delta in [1.0/60.0,1.0/15.0,0.2]:
			var source:=Unit.new();source.unit_id="V3" if id=="V3ROCKET" else "DRED";source.hp=100
			source.position=Vector2(100,100);source.hull_angle=0.2
			var old:=Missile.new();var current:=Missile.new()
			for shot in [old,current]:
				shot.unit_id=id
				shot.special.flight={"elapsed":0.0,"source":source,"aim":Vector2(1100,300),"altitude":300.0}
				Flight.prepare(shot,source,1.0)
			var finished:=false
			var rules:Dictionary=Flight.Native.data().general
			var acceleration_key: String="v3rocketacceleration" if id=="V3ROCKET" else "dmislacceleration"
			var original_acceleration=rules.get(acceleration_key)
			for step in 3000:
				if step==50:rules[acceleration_key]=1.3
				var expected:=Reference.advance(old,old.special.flight,delta)
				var actual:=Flight.advance(current,current.special.flight,delta)
				check(expected==actual and old.position==current.position and old.hull_angle==current.hull_angle and old.logistics==current.logistics and old.special.flight==current.special.flight,"exact missile integration "+str([id,delta,step]))
				if expected or actual:finished=true;break
			check(finished,"flight reaches impact "+str([id,delta]))
			if original_acceleration==null:rules.erase(acceleration_key)
			else:rules[acceleration_key]=original_acceleration
			old.free();current.free();source.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
