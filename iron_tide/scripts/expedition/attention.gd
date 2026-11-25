extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")
const Growth=preload("res://scripts/expedition/growth.gd")

static func reward(run:Dictionary) -> bool:
	return run.get("phase","")=="reward" and not run.get("offers",[]).is_empty()

static func event(run:Dictionary) -> bool:
	return run.get("phase","")=="event" and not run.get("event",{}).get("resolved",false) and not run.get("event",{}).get("choices",[]).is_empty()

static func free_units(run:Dictionary) -> Array:
	var result:Array=[]
	if run.get("phase","")!="ready" or not Growth.free_available(run):return result
	for id:String in Army.available(run):
		if id in run.licenses and Growth.can_upgrade(run,id):result.append(id)
	return result

static func free_refills(run:Dictionary) -> Array:
	var result:Array=[]
	if run.get("phase", "") != "ready" or not run.get("repair_coupon", false):
		return result
	for id:String in Army.available(run):
		if id in run.licenses and Expedition.item_problem(run, {"kind":"reinforce", "id":id}).is_empty():
			result.append(id)
	return result

static func any(run:Dictionary) -> bool:
	return reward(run) or event(run) or not free_units(run).is_empty() or not free_refills(run).is_empty()

static func summary(run:Dictionary) -> String:
	if reward(run):return "额外 Buff 奖励待领取" if str(run.get("reward_round","")).begins_with("buff") else "本轮奖励待领取"
	if event(run):return "战后事件待选择"
	var reminders:=PackedStringArray()
	if not free_units(run).is_empty():reminders.append("免费强化")
	if not free_refills(run).is_empty():reminders.append("免费补员")
	if not reminders.is_empty():return "本关"+"、".join(reminders)+"待使用"
	return ""
