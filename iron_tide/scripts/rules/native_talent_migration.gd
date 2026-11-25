extends RefCounted
const Training=preload("res://scripts/rules/skill_training.gd")
const SPLIT:="reaper_split_fire"

static func folded_rank(level:int) -> int:
	return 1 if level<=6 else 2 if level<=13 else 3

static func ranks(meta,id:String) -> Dictionary:
	var result:Dictionary={}
	var old=meta.unit_talents.get(id,{})
	for talent in meta.selected_talents(id,meta.unit_talents):
		result[talent]=int(old.get(talent,0)) if old is Dictionary else 0
	return result

static func apply(meta) -> bool:
	var changed:=false
	var reaper:=ranks(meta,"R3REAPER")
	if reaper.has(SPLIT):
		if not meta.unlocked_skills.has(SPLIT):meta.unlocked_skills.append(SPLIT)
		var levels:Dictionary=meta.academy.get_or_add("levels",{})
		levels[SPLIT]=maxi(int(levels.get(SPLIT,0)),clampi(int(reaper[SPLIT]),0,3))
		reaper.erase(SPLIT);meta.unit_talents.R3REAPER=reaper
		meta.disabled_effects.erase("talent/R3REAPER/"+SPLIT)
		changed=true # Frees the allocation point; paid slots stay available.
	var old_track:Dictionary=meta.get_unit_track("skill")
	for id in meta.unit_levels.keys():
		var row:Dictionary=meta.unit_levels[id]
		if not row.has("skill"):continue
		var level:=clampi(int(row.skill),0,20)
		var talent:=Training.talent_id(id)
		if level>0 and not talent.is_empty():
			var selections:=ranks(meta,id)
			if not selections.has(talent):meta.owned_talent_points+=1
			selections[talent]=maxi(int(selections.get(talent,0)),folded_rank(level))
			meta.unit_talents[id]=selections
			meta.talent_slots[id]=maxi(int(meta.talent_slots.get(id,0)),selections.size())
			if not meta.effect_enabled("track","skill",id):meta.disabled_effects["talent/"+id+"/"+talent]=true
		elif level>0:
			var refund:=0.0
			for i in level:refund+=floorf(float(old_track.get("cost_base",500))*pow(float(old_track.get("cost_growth",1.35)),i))
			meta.currency.credits=meta.balance("credits")+refund
		row.erase("skill")
		meta.disabled_effects.erase("track/"+id+"/skill")
		changed=true
	return changed
