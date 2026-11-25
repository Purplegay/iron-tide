# Frozen v0.30.46 function: independent before-change oracle.
extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Second=preload("res://scripts/units/progression_expansion_2.gd")
const EMPTY_STATE:Dictionary={}
static func speed(unit: Unit) -> float:
	if unit.special.has("leizhu_control") and preload("res://scripts/units/leizhu_command.gd").controlled(unit):return 0.0
	var s:Dictionary=unit.special.get(R.KEY,EMPTY_STATE)
	if s.has("move_lock"):return 0.0
	var multiplier:float=1.0+float(s.get("speed_bonus",0))
	if s.has("afterburn"):multiplier*=1.0+s.afterburn.speed
	if s.has("dive_boost"):multiplier*=1.0+R.talent(unit,"dive_momentum","speed")
	return multiplier*Second.speed(unit)
