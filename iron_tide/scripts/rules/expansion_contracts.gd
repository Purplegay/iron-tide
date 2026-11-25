extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const GOALS={"FV":[2,3],"HARV":[12,3],"TTNK":[25.0,6000.0],"E1":[60.0,40.0],"MTNK":[20.0,25.0],"HTNK":[20.0,8000.0],"TANY":[60.0,8.0],"BORIS":[60.0,10.0],"ORCA":[20.0,12.0]}

static func purchase(meta,id:String) -> bool:
	var row:=Pool.for_hero(id)
	return not row.is_empty() and id!="E2" and Pool.purchase(meta,str(row.id))

static func cards() -> Dictionary:
	var result:Dictionary={}
	for row in Pool.entries():
		if row.hero_id!="E2":result[row.hero_id]=row.cards
	return result

static func eligible(world,id:String,settling:=false) -> bool:
	if id in ["ORCA","TTNK","FV","HARV"] and not BattleRequest.combat_context.get("expedition",{}).is_empty():return false
	return world!=null and MetaProgress.Academy.eligible(world) and BattleRequest.combat_context.get("hero_contracts",{}).has(id) and (settling or not MetaProgress.stats.get("player_production",{}).get("settled",{}).has(world.match_id))

static func progress(world,id:String) -> Dictionary:
	return world.allied_state.get_or_add("hero_contract_progress",{}).get_or_add(id,{"first":0.0,"second":0.0,"damage":0.0,"defenses":0})

static func vehicle(target) -> bool:
	return target is Unit and not R.temporary(target) and not target.is_harvester and not target.is_air_target() and not AlliedAbilities.infantry(target) and not target.is_naval and target.embarked_in==null and not target.weapon.is_empty()

static func killed(world,target,source) -> void:
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not (actor is Unit) or R.temporary(actor) or R.temporary(target) or target.side=="neutral" or BattleRequest.friendly(actor.side,target.side):return
	var hero:String=actor.special.get("academy_hero","")
	if eligible(world,hero):
		var p:=progress(world,hero)
		if hero=="E1" and AlliedAbilities.infantry(target):p.first+=1
		elif hero in ["MTNK","HTNK"] and vehicle(target):p.first+=1
		if hero=="HTNK" and target is Building and not target.weapon.is_empty():p.defenses+=1
	var leader=actor.special.get("initial_escort_owner")
	if AlliedAbilities.alive(leader) and eligible(world,"E1") and (vehicle(target) or AlliedAbilities.infantry(target)):
		progress(world,"E1").second+=1

static func damaged(target,source,amount:float) -> void:
	if amount<=0 or R.temporary(target):return
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not R.enemy(actor,target) or R.temporary(actor):return
	var world=R.world(target)
	var id:String=actor.special.get("academy_hero","")
	if eligible(world,id):progress(world,id).damage+=minf(target.hp,amount)
	if target.special.get("academy_hero")=="TTNK" and target.side=="ally" and eligible(world,"TTNK"):
		progress(world,"TTNK").second+=minf(target.hp,amount)
	if target.special.get("academy_hero")=="HTNK" and eligible(world,"HTNK"):
		progress(world,"HTNK").second+=minf(target.hp,amount)

static func healed(unit,actual:float) -> void:
	var world=R.world(unit)
	if actual>0 and unit.special.get("academy_hero")=="MTNK" and eligible(world,"MTNK") and unit.max_hp>0:
		progress(world,"MTNK").second+=actual/unit.max_hp*100.0

static func settle(meta,world,win:bool) -> void:
	if not BattleRequest.extensions_enabled() or BattleRequest.combat_context.get("hero_contracts",{}).is_empty():return
	if meta.academy.get("hero_contract_settled",{}).has(world.match_id):return
	meta.academy.get_or_add("hero_contract_settled",{})[world.match_id]=true
	for id in cards():
		if not eligible(world,id,true):continue
		var quest:Dictionary=meta.academy.get("hero_contracts",{}).get(id,{})
		if quest.is_empty() or quest.get("complete",false):continue
		var p:=progress(world,id)
		quest.first=minf(GOALS[id][0],float(quest.first)+float(p.first))
		if id=="FV":
			for flag in ["armed","repaired"]:
				if p.get(flag,false):quest[flag]=true
			quest.first=int(quest.get("armed",false))+int(quest.get("repaired",false))
			if win and BattleRequest.victory_difficulty()>=1 and p.get("armed_modes",{}).size()>=2:quest.win=true
		quest.second=minf(GOALS[id][1],float(quest.second)+float(p.second))
		var survivor=null
		for unit in world.units:
			if AlliedAbilities.alive(unit) and unit.special.get("academy_hero")==id and (id not in ["TANY","BORIS","ORCA","TTNK","FV","HARV"] or unit.side=="ally") and not unit.special.has("hero_wreck") and not R.state(unit).has("succession"):survivor=unit;break
		if win and BattleRequest.victory_difficulty()>=1 and survivor!=null:
			var valid:bool=(id=="MTNK" and p.first>=5) or (id=="HTNK" and p.defenses>=2)
			if id=="HARV":valid=p.get("delivered",false)
			if id=="TANY":valid=p.defenses>=1
			if id=="BORIS":valid=int(p.get("sorties",0))>=2
			if id=="TTNK":valid=p.first>=4
			if id=="ORCA":valid=p.get("targets",{}).size()>=3
			if id=="E1" and p.damage>0:
				var guards:=0
				for unit in world.units:
					if AlliedAbilities.alive(unit) and is_same(unit.special.get("initial_escort_owner"),survivor):guards+=1
				valid=guards>=2
			if valid:quest.win=true
		if quest.first>=GOALS[id][0] and quest.second>=GOALS[id][1] and quest.win:
			quest.complete=true
			for card in cards()[id]:
				if not meta.unlocked_skills.has(card):meta.unlocked_skills.append(card)
