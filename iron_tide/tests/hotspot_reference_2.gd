# Frozen v0.30.46 function: independent before-change oracle.
extends "res://scripts/expedition/rules.gd"
static func speed_factor(unit) -> float:
	if not active() or unit.side!="ally":return 1.0
	if unit.special.get("expedition_convoy",false):return 0.0 if unit.special.get("expedition_convoy_paused",false) else CONVOY_SPEED
	var extra:=0.0
	if unit.is_air and synergy("air")>=2 and not is_instance_valid(unit.attack_target) and unit.logistics.air_state in ["returning","flying"]:extra+=0.10
	if context().get("specializations",{}).get(unit.unit_id,"")=="b" and float(unit.special.get("expedition_release_until",0))>clock(unit):extra+=0.15
	var current:float=unit.special.get("expedition_speed_factor",1.0)
	return minf(1.3,current+extra)/maxf(1.0,current)
