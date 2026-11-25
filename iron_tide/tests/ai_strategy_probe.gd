extends "res://scripts/world/house_ai.gd"
var granted:=0
func _hatch(_state:Dictionary,_buildings:Array)->void:
	granted+=1
func _form_wave(_state:Dictionary)->void:
	pass
