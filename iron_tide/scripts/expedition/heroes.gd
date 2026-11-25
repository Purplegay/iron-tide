extends RefCounted

const OFFER_CHANCE := 0.25
const RESCUE_COST := 60

static func owned(run:Dictionary) -> Array:
	if run.has("heroes"):return run.heroes.duplicate()
	var selected:String=run.get("hero","")
	return [] if selected.is_empty() else [selected]

static func wounded(run:Dictionary) -> Array:
	if run.has("wounded_heroes"):return run.wounded_heroes.duplicate()
	var selected:String=run.get("hero","")
	return [selected] if not selected.is_empty() and run.get("hero_wounded",false) else []

static func available(run:Dictionary) -> Array:
	var result:Array=[]
	var faction:=GameData.ra2_country_side(str(run.country))
	for id:String in MetaProgress.Academy.HEROES:
		if (id in MetaProgress.Academy.Commandos.IDS or id in ["ORCA","TTNK","FV","HARV"]) and int(run.get("stage",1))<5:continue
		if GameData.get_unit(id).get("faction","")==faction and id not in owned(run):result.append(id)
	return result

static func recruit(run:Dictionary,id:String) -> bool:
	if id not in available(run):return false
	run.heroes=owned(run)
	run.wounded_heroes=wounded(run)
	run.heroes.append(id)
	return true

static func update_wounded(run:Dictionary,world=null) -> void:
	run.heroes=owned(run)
	if world==null:
		run.wounded_heroes=run.heroes.duplicate()
	else:
		# Absence is not proof of death: chrono arrivals may still be pending.
		run.wounded_heroes=wounded(run)
		for id in world.allied_state.get("expedition_hero_deaths",[]):
			if id in run.heroes and id not in run.wounded_heroes:run.wounded_heroes.append(id)
	for unit:Dictionary in run.survivors:run.wounded_heroes.erase(str(unit.get("hero","")))
	run.hero_wounded=str(run.get("hero","")) in run.wounded_heroes

static func valid(run:Dictionary) -> bool:
	for field:String in ["heroes","wounded_heroes"]:
		if run.has(field) and not run[field] is Array:return false
	var seen:Array=[]
	for id in owned(run):
		if not id is String or not MetaProgress.Academy.HEROES.has(id) or id in seen:return false
		if GameData.get_unit(id).get("faction","")!=GameData.ra2_country_side(str(run.country)):return false
		seen.append(id)
	var injuries:Array=[]
	for id in wounded(run):
		if id not in seen or id in injuries:return false
		injuries.append(id)
	var selected:String=run.get("hero","")
	return (selected.is_empty() or selected in seen) and bool(run.get("hero_wounded",false))==(selected in injuries)
