extends RefCounted
const TRACKS := {"atk":"attack_bonus","def":"defense_bonus"}
const CAP := 5
const LEVEL_SCALE := 4
const PRICE := 25
const RELIC := "field_manual"
const RELIC_NAME := "战地教范"
const RELIC_PRICE := 40

static func freeze(frozen:Dictionary) -> void:
	frozen.expedition_unit_levels=MetaProgress.unit_levels.duplicate(true)
	frozen.expedition_growth_disabled={}
	frozen.expedition_growth_rates={}
	for track:String in TRACKS:
		frozen.expedition_growth_rates[track]=float(MetaProgress.get_unit_track(track).effect_per_level)

static func folded(raw_level:int) -> int:
	return clampi(roundi(float(raw_level)/LEVEL_SCALE),0,CAP)

static func source_level(run:Dictionary,id:String,track:String) -> int:
	var frozen:Dictionary=run.get("frozen",{})
	if frozen.has("expedition_unit_levels"):
		return clampi(int(frozen.expedition_unit_levels.get(id,{}).get(track,0)),0,20)
	var bonus:float=frozen.get("unit_bonus",{}).get(id,{}).get(TRACKS[track],1.0)
	return clampi(roundi((bonus-1.0)/maxf(rate(run,track),0.000001)),0,20)

static func rate(run:Dictionary,track:String) -> float:
	return float(run.get("frozen",{}).get("expedition_growth_rates",{}).get(track,MetaProgress.get_unit_track(track).effect_per_level))

static func starting_level(run:Dictionary,id:String) -> int:
	return folded(mini(source_level(run,id,"atk"),source_level(run,id,"def")))

static func level(run:Dictionary,id:String,track:String) -> int:
	return int(run.get("unit_growth",{}).get(id,{}).get(track,starting_level(run,id)))

static func upgrade_problem(run:Dictionary,id:String) -> String:
	var owned:bool=id in run.licenses
	for squad:Dictionary in run.get("special_squads",[]):
		if squad.id==id and int(squad.get("count",0))>0:owned=true;break
	if not owned:return "尚未持有该兵种"
	for track:String in TRACKS:
		if level(run,id,track)<CAP:return ""
	return "攻防已满 5 级"

static func can_upgrade(run:Dictionary,id:String) -> bool:
	return upgrade_problem(run,id).is_empty()

static func upgrade(run:Dictionary,id:String) -> void:
	var levels:Dictionary={}
	for track:String in TRACKS:
		levels[track]=mini(CAP,level(run,id,track)+1)
	run.get_or_add("unit_growth",{})[id]=levels

static func promote(run:Dictionary,id:String,quality:int) -> void:
	var levels:Dictionary={}
	for track:String in TRACKS:
		levels[track]=maxi(level(run,id,track),special_level(quality))
	run.get_or_add("unit_growth",{})[id]=levels

static func special_level(quality:int) -> int:
	return [0,1,3,5][clampi(quality,0,3)]

static func free_available(run:Dictionary) -> bool:
	return run.get("relics",{}).get(RELIC,false) and int(run.get("free_upgrade_stage",0))!=int(run.stage)

static func price(run:Dictionary) -> int:
	return 0 if free_available(run) else PRICE

static func apply_context(run:Dictionary,context:Dictionary) -> void:
	context.expedition.unit_growth={}
	context.expedition.growth_rates={}
	for track:String in TRACKS:context.expedition.growth_rates[track]=rate(run,track)
	for id:String in context.unit_bonus:
		var levels:Dictionary={}
		for track:String in TRACKS:
			levels[track]=level(run,id,track)
			context.unit_bonus[id][TRACKS[track]]=1.0+levels[track]*LEVEL_SCALE*rate(run,track)
		context.expedition.unit_growth[id]=levels

static func actor_level(unit,track:String) -> int:
	var context:Dictionary=BattleRequest.combat_context.get("expedition",{})
	var base:int=context.get("unit_growth",{}).get(unit.unit_id,{}).get(track,0)
	return maxi(base,special_level(int(unit.special.get("expedition_tier",0))))

static func actor_factor(unit,track:String) -> float:
	var context:Dictionary=BattleRequest.combat_context.get("expedition",{})
	return 1.0+actor_level(unit,track)*LEVEL_SCALE*float(context.get("growth_rates",{}).get(track,MetaProgress.get_unit_track(track).effect_per_level))

static func valid(run:Dictionary) -> bool:
	var rows:Variant=run.get("unit_growth",{})
	if not rows is Dictionary:return false
	for id in rows:
		if not GameData.unit_index.has(id) or not rows[id] is Dictionary:return false
		for track in rows[id]:
			if not TRACKS.has(track) or not rows[id][track] is int or rows[id][track]<0 or rows[id][track]>CAP:return false
	var relics:Variant=run.get("relics",{})
	if not relics is Dictionary:return false
	for id in relics:
		if not preload("res://scripts/expedition/relics.gd").ITEMS.has(id) or not relics[id] is bool:return false
	var used:Variant=run.get("free_upgrade_stage",0)
	return used is int and used>=0 and used<=int(run.stage)
