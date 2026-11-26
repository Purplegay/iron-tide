extends RefCounted
## Hero equipment has its own durable slots; numeric training still uses the base unit ID.
static func migrate(meta) -> bool:
	var rows:Dictionary=meta.academy.get_or_add("hero_loadouts",{})
	var changed:=false
	for id in meta.Academy.HEROES:
		if not rows.has(id):
			rows[id]={"active":[""],"passive":""} if (id in meta.Academy.Commandos.IDS or id in ["ORCA","TTNK","FV","HARV"]) else meta.unit_loadout(id).duplicate(true)
			changed=true
	return changed

static func effective(meta,id:String) -> Dictionary:
	if id in meta.Academy.Stars.IDS:return {"active":[""],"passive":""}
	var fallback:Dictionary={} if (id in meta.Academy.Commandos.IDS or id in ["ORCA","TTNK","FV","HARV"]) else meta.unit_loadout(id)
	var row:Dictionary=UnitSkillLayout.normalize(id,meta.academy.get("hero_loadouts",{}).get(id,fallback),true)
	for i in row.active.size():
		if not meta.skill_unlocked(row.active[i]):row.active[i]=""
	if not meta.skill_unlocked(row.passive):row.passive=""
	return row

static func equip(meta,id:String,slot:String,skill:String) -> bool:
	if id in meta.Academy.Stars.IDS:return false
	if not meta.Academy.HEROES.has(id) or slot not in ["active","passive"]:return false
	if not meta.can_set_unit_skill(skill) or not UnitSkillLayout.compatible(id,skill,true):return false
	if slot=="active" and not UnitSkillLayout.equippable(id,skill,true):return false
	if slot=="passive" and not skill.is_empty() and GameData.get_skill(skill).get("type","")!="passive":return false
	var previous:Dictionary=meta.academy.duplicate(true)
	migrate(meta)
	var row:=effective(meta,id)
	if slot=="active":row.active=[skill]
	else:row.passive=skill
	meta.academy.hero_loadouts[id]=row
	if not meta.save():
		meta.academy=previous
		return false
	Events.meta_changed.emit()
	return true
