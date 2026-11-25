extends RefCounted
const Scope = preload("res://scripts/rules/skill_scope.gd")
const RARITY := {"common":0,"rare":1,"epic":2,"legend":3,"ultimate":4}

static func roster() -> Array:
	var ids: Array = []
	for faction in ["allied","soviet"]:
		for id in GameData.faction_unit_catalog(faction,true):
			if GameData.building_index.has(str(GameData.unit_index[id].get("built_at",""))) and not ids.has(id): ids.append(id)
	for id in GameData.building_index:
		if Scope.defense(id) and not ids.has(id): ids.append(id)
	return ids

static func priority(meta, card: Dictionary) -> int:
	return (1000 if Scope.exclusive(card) else 0) + int(RARITY.get(card.get("rarity","common"),0))*100 + meta.Academy.card_rank(meta,str(card.id))

static func choose(meta, uid: String, slot: String, current: String, owned: Array) -> String:
	var selected := ""
	var best := -1
	for card: Dictionary in owned:
		var id := str(card.id)
		if card.get("type","") != slot or not UnitSkillLayout.compatible(uid,id): continue
		if slot == "active" and not UnitSkillLayout.equippable(uid,id): continue
		var score := priority(meta,card)
		if score > best or (score == best and (id == current or (selected != current and id < selected))):
			selected = id
			best = score
	return selected

static func plan(meta, ids: Array) -> Dictionary:
	var allowed := roster()
	var seen := {}
	var changes := {}
	var owned: Array = meta.owned_skills()
	for uid in ids:
		if not uid is String or not allowed.has(uid): return {"ok":false,"reason":"invalid_unit","changes":{}}
		if seen.has(uid): continue
		seen[uid] = true
		var previous: Dictionary = meta.unit_effective_loadout(uid)
		var row := {"active":[choose(meta,uid,"active",str(previous.active[0]),owned)],"passive":choose(meta,uid,"passive",str(previous.passive),owned)}
		if row != previous: changes[uid] = row
	return {"ok":true,"changes":changes,"total":seen.size()}
