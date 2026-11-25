extends "res://scripts/world/house_ai.gd"
var decision_calls:=0
var advanced:=0.0
func run_decisions(delta:float,_nbuild:int=0)->void:
	decision_calls+=1
	advanced+=delta
