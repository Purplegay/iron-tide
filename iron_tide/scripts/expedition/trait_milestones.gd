extends RefCounted

static func stacks(id:String) -> int:
	var context:Dictionary=BattleRequest.combat_context.get("expedition",{})
	return clampi(int(context.get("trait_buffs",{}).get(id,mini(3,int(context.get("traits",{}).get(id,0))))),0,9)

static func ready(unit,key:String,now:float,cooldown:float) -> bool:
	var field:="expedition_milestone_"+key
	if now<float(unit.special.get(field,0)):return false
	unit.special[field]=now+cooldown
	return true

static func shield(unit,key:String,now:float,fraction:float,cooldown:float) -> void:
	if ready(unit,key,now,cooldown):
		unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*fraction)

static func tick(unit,tags:Array,now:float,delta:float,medical:bool,reloaded:bool) -> void:
	if "vehicle" in tags and stacks("vehicle")>=3 and float(unit.special.get("expedition_moving",0))>=2 and unit.hp<unit.max_hp*0.5:
		var repair_time:=minf(delta,maxf(0,float(unit.special.expedition_moving)-2.0))
		unit.heal(minf(unit.max_hp*0.005*repair_time,unit.max_hp*0.5-unit.hp))
	if "naval" in tags and stacks("naval")>=3 and now-float(unit.special.get("expedition_last_hit",-100))>=8 and not is_instance_valid(unit.attack_target):shield(unit,"naval_reserve",now,0.08,20)
	if medical:
		if stacks("support")>=6:unit.heal(unit.max_hp*0.02)
		elif stacks("support")>=3 and unit.hp<unit.max_hp*0.5:unit.heal(minf(unit.max_hp*0.01,unit.max_hp*0.5-unit.hp))
		if "infantry" in tags and stacks("infantry")>=6:
			var overflow:=maxf(0.0,unit.hp+unit.max_hp*0.02-unit.max_hp)
			unit.heal(unit.max_hp*0.02)
			if stacks("infantry")>=9 and overflow>0:
				var current:float=unit.special.get("expedition_shield",0)
				unit.special.expedition_shield=maxf(current,minf(unit.max_hp*0.20,current+overflow))
		if stacks("support")>=9 and unit.hp>=unit.max_hp*0.90:unit.special.expedition_support_fire_until=now+5.0
	if "naval" in tags and stacks("naval")>=6:unit.heal(unit.max_hp*0.005*delta)
	if "air" in tags and reloaded:
		if stacks("air")>=3:unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*0.05)
		if stacks("air")>=6:unit.heal(unit.max_hp*0.15)
		if stacks("air")>=9:
			unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*0.20)
			unit.special.expedition_air_rounds=3
	var still:float=unit.special.get("expedition_still",0)
	if "vehicle" in tags and stacks("vehicle")>=6 and still>=4 and ready(unit,"vehicle",now,20):
		unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*0.10)
		if stacks("vehicle")>=9:unit.special.expedition_vehicle_rounds=3
	if "fortify" in tags and stacks("fortify")>=6 and still>=3:shield(unit,"fortify",now,0.10,20)
	if "mobile" in tags and stacks("mobile")>=9 and float(unit.special.get("expedition_moving",0))>=2:shield(unit,"mobile",now,0.15,20)

static func defend(unit,tags:Array,now:float) -> void:
	if "fortify" in tags and stacks("fortify")>=9 and float(unit.special.get("expedition_shield",0))>0 and ready(unit,"counter_charge",now,1):
		unit.special.expedition_counter_charges=mini(3,int(unit.special.get("expedition_counter_charges",0))+1)
	if "infantry" in tags and stacks("infantry")>=9 and unit.hp<unit.max_hp*0.4:shield(unit,"infantry",now,0.15,20)
	if "naval" in tags and stacks("naval")>=9 and unit.hp<unit.max_hp*0.5:shield(unit,"naval",now,0.20,30)
	if stacks("support")>=9 and unit.hp<unit.max_hp*0.5:shield(unit,"support",now,0.10,30)

static func impact(gun,target,tags:Array,now:float) -> float:
	var bonus:=0.0
	if now<float(target.special.get("expedition_overload_until",0)):bonus+=0.15
	elif now<float(target.special.get("expedition_exposed_until",0)):bonus+=0.10
	if "fortify" in tags and stacks("fortify")>=3 and float(gun.special.get("expedition_still",0))>=2 and ready(gun,"cover_fire",now,6):target.special.expedition_cover_until=now+2.0
	if stacks("support")>=9 and now<float(gun.special.get("expedition_support_fire_until",0)):bonus+=0.15
	if "vehicle" in tags and stacks("vehicle")>=9 and int(gun.special.get("expedition_vehicle_rounds",0))>0 and float(gun.special.get("expedition_moving",0))>=2 and ready(gun,"vehicle_round",now,0.25):
		bonus+=0.15;gun.special.expedition_vehicle_rounds-=1
	if "vehicle" in tags and stacks("vehicle")>=9 and float(gun.special.get("expedition_moving",0))>=2 and ready(gun,"vehicle_shot",now,6):bonus+=0.20
	if "air" in tags and stacks("air")>=9 and int(gun.special.get("expedition_air_rounds",0))>0 and ready(gun,"air_round",now,0.25):
		bonus+=0.20;gun.special.expedition_air_rounds-=1
	if "naval" in tags and stacks("naval")>=9 and float(gun.special.get("expedition_shield",0))>0 and ready(gun,"naval_counter",now,4):
		bonus+=0.20;gun.heal(gun.max_hp*0.02)
	if "fortify" in tags and stacks("fortify")>=9 and float(gun.special.get("expedition_still",0))>=5 and ready(gun,"fortify_shot",now,8):
		bonus+=0.40
		if int(gun.special.get("expedition_counter_charges",0))>=3:
			bonus+=0.60;gun.special.expedition_counter_charges=0
	if "energy" in tags and stacks("energy")>=6:shield(gun,"energy",now,0.08,6)
	if "artillery" in tags:
		if stacks("artillery")>=6 and target.hp>target.max_hp*0.75:bonus+=0.20
		if stacks("artillery")>=9 and now-float(target.special.get("expedition_first_mark",now))>=2 and ready(gun,"artillery_shot",now,10):
			bonus+=0.50;target.special.expedition_suppressed_until=now+4.0
	if "special" in tags:
		if stacks("special")>=3 and (target.special.has("expedition_objective") or target.hp<target.max_hp*0.35):shield(gun,"special_cover",now,0.05,6)
		if stacks("special")>=6 and (target.special.has("expedition_objective") or target.hp<target.max_hp*0.35) and ready(gun,"special_heal",now,6):gun.heal(gun.max_hp*0.05)
		if stacks("special")>=9 and target.hp<target.max_hp*0.35 and ready(gun,"special_shot",now,4):bonus+=0.40
	return bonus

static func defeated(killer,tags:Array,now:float) -> void:
	if "infantry" in tags and stacks("infantry")>=3 and ready(killer,"infantry_dressing",now,6):killer.heal(killer.max_hp*0.04)
	if "special" in tags and stacks("special")>=9:
		killer.special.erase("expedition_milestone_special_cover")
		killer.special.erase("expedition_milestone_special_heal")
		killer.special.erase("expedition_milestone_special_shot")
