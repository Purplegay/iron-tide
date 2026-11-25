extends RefCounted
const Relics=preload("res://scripts/expedition/relics.gd")
const Milestones=preload("res://scripts/expedition/trait_milestones.gd")

static func has(id:String) -> bool:
	return Relics.owned(BattleRequest.combat_context.get("expedition",{}),id)

static func ready(unit,key:String,now:float,delay:float) -> bool:
	var field:="expedition_ultimate_cd_"+key
	if now<float(unit.special.get(field,0)):return false
	unit.special[field]=now+delay
	return true

static func shield(unit,fraction:float) -> void:
	unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*fraction)

static func tick(unit,now:float,reloaded:bool) -> void:
	if unit.unit_id in ["E1","GGI"] and has("bastion_heart") and unit._deployed and float(unit.special.get("expedition_still",0))>=3 and ready(unit,"bastion",now,12):shield(unit,0.15)
	if unit.unit_id=="MTNK" and has("grizzly_engine") and float(unit.special.get("expedition_moving",0))>=2 and ready(unit,"grizzly_load",now,10):unit.special.expedition_ultimate_grizzly=3
	if unit.unit_id=="HTNK" and has("rhino_siege") and float(unit.special.get("expedition_still",0))<3:
		unit.special.expedition_ultimate_siege_until=0.0
		unit.special.expedition_ultimate_siege_count=0
	if unit.unit_id in ["ORCA","BEAG"] and has("sky_cycle") and reloaded:unit.special.expedition_ultimate_sky=3

static func absorbed(unit,amount:float) -> void:
	if amount<=0 or unit.unit_id not in ["E1","GGI"] or not has("bastion_heart"):return
	unit.special.expedition_ultimate_bastion=minf(unit.max_hp*0.40,float(unit.special.get("expedition_ultimate_bastion",0))+amount)

static func impact(gun,target,now:float) -> float:
	var bonus:=0.0
	if has("sky_cycle") and now<float(target.special.get("expedition_ultimate_beacon_until",0)):bonus+=0.25
	if has("prism_matrix"):bonus+=prism(gun,target,now)
	if gun.unit_id in ["E1","GGI"] and gun._deployed and has("bastion_heart"):
		var stored:float=gun.special.get("expedition_ultimate_bastion",0)
		bonus+=minf(1.20,stored/gun.max_hp*3.0)
		gun.special.expedition_ultimate_bastion=0.0
		if stored>=gun.max_hp*0.40 and Milestones.stacks("fortify")>=9:shield(gun,0.10)
	if gun.unit_id=="MTNK" and has("grizzly_engine") and int(gun.special.get("expedition_ultimate_grizzly",0))>0 and ready(gun,"grizzly_shot",now,0.25):
		bonus+=0.25;gun.special.expedition_ultimate_grizzly-=1
		if gun.special.expedition_ultimate_grizzly==0:
			gun.heal(gun.max_hp*0.08)
			gun.special.erase("expedition_mobile_cd");gun.special.erase("expedition_relic_cd_drive")
			if Milestones.stacks("vehicle")>=9:gun.special.expedition_vehicle_rounds=3
	if gun.unit_id=="HTNK" and has("rhino_siege"):bonus+=siege(gun,target,now)
	if gun.unit_id in ["ORCA","BEAG"] and has("sky_cycle") and int(gun.special.get("expedition_ultimate_sky",0))>0 and ready(gun,"sky_shot",now,0.25):
		bonus+=0.35;gun.special.expedition_ultimate_sky-=1
		if gun.special.expedition_ultimate_sky==0:
			target.special.expedition_ultimate_beacon_until=now+6.0;shield(gun,0.25)
			if Milestones.stacks("air")>=9:gun.heal(gun.max_hp*0.10)
	if gun.unit_id in ["GHOST","TANY","BORIS"] and has("zero_warrant"):
		var primed:bool=now<float(gun.special.get("expedition_ultimate_execution_until",0))
		if primed or target.hp<target.max_hp*0.60:bonus+=0.50
		if primed:gun.special.expedition_ultimate_execution_until=0.0
	return bonus

static func prism(gun,target,now:float) -> float:
	var active:bool=now<float(target.special.get("expedition_ultimate_prism_until",0))
	var donors:Array=target.special.get("expedition_ultimate_prism_donors",[]) if active else []
	if gun.unit_id=="SREF":
		target.special.expedition_ultimate_prism_until=now+6.0
		if donors.size()>=3:
			target.special.expedition_ultimate_prism_donors=[]
			if Milestones.stacks("energy")>=9:target.special.expedition_overload_until=now+4.0
			return 1.20
	elif active and gun.unit_id not in donors and donors.size()<3:donors.append(gun.unit_id)
	target.special.expedition_ultimate_prism_donors=donors
	return 0.0

static func siege(gun,target,now:float) -> float:
	if float(gun.special.get("expedition_still",0))<3:return 0.0
	if now>=float(gun.special.get("expedition_ultimate_siege_until",0)) and ready(gun,"siege_hit",now,0.25):
		if now-float(gun.special.get("expedition_ultimate_siege_last",-100))>=5:gun.special.expedition_ultimate_siege_count=0
		gun.special.expedition_ultimate_siege_last=now
		gun.special.expedition_ultimate_siege_count=int(gun.special.get("expedition_ultimate_siege_count",0))+1
		if gun.special.expedition_ultimate_siege_count>=3:
			gun.special.expedition_ultimate_siege_count=0;gun.special.expedition_ultimate_siege_until=now+6.0
			if Milestones.stacks("artillery")>=9:gun.special.erase("expedition_milestone_artillery_shot")
	if now<float(gun.special.get("expedition_ultimate_siege_until",0)):
		target.special.expedition_suppressed_until=now+4.0
		return 0.40
	return 0.0

static func defeated(killer,now:float) -> void:
	if killer.unit_id not in ["GHOST","TANY","BORIS"] or not has("zero_warrant") or not ready(killer,"execution_kill",now,1):return
	killer.heal(killer.max_hp*0.10);shield(killer,0.15)
	killer.special.expedition_ultimate_execution_until=now+8.0
