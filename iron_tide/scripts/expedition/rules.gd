extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")
const Catalog=preload("res://scripts/expedition/catalog.gd")
const Milestones=preload("res://scripts/expedition/trait_milestones.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
const RelicEffects=preload("res://scripts/expedition/relic_effects.gd")
const Progress=preload("res://scripts/expedition/trait_progression.gd")
const CONVOY_SPEED := 0.65
const EMPTY_SPEED_CONTEXT:Dictionary={}

static func context() -> Dictionary:
	return BattleRequest.combat_context.get("expedition",{})

static func active() -> bool:
	return BattleRequest.extensions_enabled() and not context().is_empty()

static func rank(id:String) -> int:
	return int(context().get("buffs",{}).get(id,0)) if active() else 0

static func value(id:String) -> float:
	return rank(id)*float(Catalog.BUFFS.get(id,{}).get("value",0))

static func applies(id:String,unit_id:String) -> bool:
	var category:String=Catalog.BUFFS[id].group
	return category=="all" or category==Catalog.group(unit_id)

static func spawn_stats(unit) -> void:
	if unit.side!="ally" or not active():return
	var factors:Dictionary={"attack":1.0,"defense":1.0,"hp":1.0,"speed":1.0}
	for id:String in context().buffs:
		var spec:Dictionary=Catalog.BUFFS.get(id,{})
		if spec.has("stat") and applies(id,unit.unit_id):factors[spec.stat]+=value(id)
	var tags:=Army.tags(unit.unit_id,context())
	for key in ["infantry","vehicle","air","naval","special"]:
		if key in tags:factors.hp+=trait_value(key,"hp")
	if "mobile" in tags:factors.speed+=trait_value("mobile","speed")
	factors.speed=minf(1.30,factors.speed)
	unit.special.expedition_speed_factor=factors.speed
	unit.bonuses.attack_bonus*=factors.attack
	unit.bonuses.defense_bonus*=factors.defense
	unit.max_hp*=factors.hp
	unit.move_speed*=factors.speed

static func production_factor(side:String) -> float:
	if side!="ally" or not active():return 1.0
	return 1.0+value("production")+(0.20 if context().condition=="factory" else 0.0)

static func price_factor(id:String,side:String) -> float:
	if side!="ally" or not active() or not GameData.unit_index.has(id):return 1.0
	var discount:=0.01 if preload("res://scripts/expedition/research.gd").rank(context(),"factory")>=2 and GameData.unit_production_category(GameData.get_unit(id))=="infantry" else 0.0
	return maxf(0.5,1.0-value("logistics")-discount)

static func has_training_permit(id:String,side:String) -> bool:
	return side=="ally" and id in context().get("training_permits",[]) and active()

static func sync_training_permits(building) -> void:
	var counterpart:String={"GAPILE":"NAHAND","NAHAND":"GAPILE","GAWEAP":"NAWEAP","NAWEAP":"GAWEAP"}.get(building.building_id,"")
	if counterpart.is_empty():return
	for id:String in context().get("training_permits",[]):
		if GameData.get_unit(id).get("built_at","")!=counterpart:continue
		if has_training_permit(id,building.side):
			if id not in building.buildable:building.buildable.append(id)
		else:
			building.buildable.erase(id)

static func licensed_production(id: String, side: String) -> bool:
	return side == "ally" and active() and id in context().get("licenses", [])

static func block_reason(id:String,side:String) -> String:
	if not active():return ""
	if id.begins_with("R3"):return "红警3兵种不参与远征"
	if side!="ally":return ""
	if not id in context().licenses:return "需在远征奖励或商店获得该兵种许可"
	# An unlocked/licensed unit may be produced even when it is not in this
	# battle's expedition roster. active_roster controls carried/automatic forces,
	# not the factory's production catalogue.
	return ""

static func append_status(unit,entries:Array) -> void:
	if unit.side!="ally" or not active():return
	if eligible(unit):RelicEffects.append_status(unit,Army.tags(unit.unit_id,context()),entries)
	for track:String in Growth.TRACKS:
		var level:=Growth.actor_level(unit,track)
		if level>0:entries.append({"id":"expedition_growth_"+track,"kind":"expedition","name":"远征"+("攻击" if track=="atk" else "防御")+"等级","text":"每级对应局外 4 级，最高 5 级；与军衔、自带天赋独立。","icon":"attack" if track=="atk" else "guard","stacks":level,"limit":5,"left":0,"timed":false,"col":Color.GOLD})
	var tags:=Army.tags(unit.unit_id,context())
	if "support" not in tags:tags.append("support")
	for tag:String in tags:
		var count:=Milestones.stacks(tag)
		if count<=0:continue
		var spec:Dictionary=Army.TRAITS[tag]
		var detail:=Army.trait_detail(tag,count)
		entries.append({"id":"expedition_trait_"+tag,"kind":"expedition","name":str(spec.name),"text":detail,"icon":str(spec.icon),"stacks":count,"limit":9,"left":0,"timed":false,"col":Color.GOLD})
	for id:String in context().buffs:
		if not Catalog.BUFFS.has(id) or not applies(id,unit.unit_id):continue
		var spec:Dictionary=Catalog.BUFFS[id]
		entries.append({"id":"expedition_"+id,"kind":"expedition","name":"远征 · "+str(spec.name),"text":str(spec.desc),"icon":"guard" if spec.get("stat","")=="defense" else "rank","stacks":rank(id),"limit":3,"left":0,"timed":false,"col":Color.GOLD})

static func synergy(id:String) -> int:
	return mini(3,int(context().get("traits",{}).get(id,0))) if active() else 0

static func trait_value(id:String,stat:String) -> float:
	return Progress.value(id,stat,Milestones.stacks(id)) if active() else 0.0

static func eligible(unit) -> bool:
	return unit is Unit and unit.side=="ally" and active() and not unit.special.has("expansion_temporary") and not unit.special.has("furnace_flak_life") and not unit.special.has("expedition_mission_unit") and unit.logistics.carrier_owner==null

static func apply_variant(unit,spec:Dictionary) -> void:
	var before_attack:=Growth.actor_factor(unit,"atk")
	var before_defense:=Growth.actor_factor(unit,"def")
	unit.special.expedition_variant=spec.token
	unit.special.expedition_tier=int(spec.tier)
	unit.special.erase("expedition_native_rank")
	var attack_factor:=Growth.actor_factor(unit,"atk")/before_attack
	var defense_factor:=Growth.actor_factor(unit,"def")/before_defense
	unit.bonuses.attack_bonus*=attack_factor;unit._base_atk*=attack_factor
	unit.bonuses.defense_bonus*=defense_factor;unit._base_def*=defense_factor

static func clock(unit) -> float:
	var world=unit._battle_world() if unit is Unit else unit.battle
	return float(world.allied_state.get("expedition_task",{}).get("elapsed",0)) if is_instance_valid(world) else 0.0

static func tick_unit(unit,delta:float,medical:bool) -> void:
	if not eligible(unit):return
	var tags:=Army.tags(unit.unit_id,context())
	var moving:bool=unit.velocity.length_squared()>16.0
	var previous:Vector2=unit.special.get("expedition_last_position",unit.position)
	var distance:float=unit.position.distance_to(previous)
	unit.special.expedition_last_position=unit.position
	unit.special.expedition_still=0.0 if moving else float(unit.special.get("expedition_still",0))+delta
	unit.special.expedition_moving=float(unit.special.get("expedition_moving",0))+delta if moving else 0.0
	if distance<maxf(120,unit.move_speed*delta*1.5):unit.special.expedition_distance=float(unit.special.get("expedition_distance",0))+distance
	if float(unit.special.expedition_moving)>=2:unit.special.expedition_drive_until=clock(unit)+2.0
	var ammo:int=unit.logistics.ammo
	var reloaded:bool=unit.logistics.ammo_max>0 and ammo==unit.logistics.ammo_max and int(unit.special.get("expedition_ammo",ammo))<ammo
	if reloaded:unit.special.expedition_sortie=true
	unit.special.expedition_ammo=ammo
	Milestones.tick(unit,tags,clock(unit),delta,medical,reloaded)
	RelicEffects.tick(unit,clock(unit),reloaded)
	var idle:float=clock(unit)-float(unit.special.get("expedition_last_hit",-100))
	if "naval" in tags and synergy("naval")>=2 and idle>=8 and not is_instance_valid(unit.attack_target):unit.heal(unit.max_hp*([0.0,0.0,0.005,0.01][synergy("naval")])*delta)
	if medical and rank("field_medic")>0 and unit.hp<unit.max_hp*0.5:unit.heal(unit.max_hp*0.02*rank("field_medic"))
	var deployed:bool=unit._deployed
	var was:bool=unit.special.get("expedition_was_deployed",false)
	var specialization:String=context().get("specializations",{}).get(unit.unit_id,"")
	if deployed and not was:unit.special.expedition_deploy_since=clock(unit)
	if not deployed and was:
		unit.special.expedition_release_until=clock(unit)+4.0
		if specialization=="b":unit.special.expedition_release_shot=true
	unit.special.expedition_was_deployed=deployed
	if deployed and float(unit.special.expedition_still)>=3:
		var cooldown:float=unit.special.get("expedition_shield_cooldown",0)
		if clock(unit)>=cooldown and (specialization=="a" or rank("emergency_position")>0):
			unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*(0.08 if specialization=="a" else 0.05*rank("emergency_position")))
			unit.special.expedition_shield_cooldown=clock(unit)+20.0
	if specialization=="a" and unit.unit_id=="DESO" and deployed and idle>=3:unit.heal(unit.max_hp*0.005*delta)

static func late_impact(gun,target,tags:Array,now:float) -> float:
	var buffs:Dictionary=context().buffs
	var pursuit:=Milestones.stacks("pursuit") if "pursuit" in tags else 0
	var siege:=Milestones.stacks("siege_team") if "siege_team" in tags else 0
	var has_late_buff:bool=buffs.has("sight_memory") or buffs.has("pivot_sight") or buffs.has("shield_lens") or buffs.has("rescue_patch") or buffs.has("escort_plate")
	if pursuit+siege==0 and not has_late_buff:return 0.0
	var previous:int=gun.special.get("expedition_last_direct_target",0)
	var current:int=target.get_instance_id()
	var same:=previous==current
	var switched:=previous!=0 and not same
	gun.special.expedition_last_direct_target=current
	var bonus:=Progress.value("pursuit","hit",pursuit)+Progress.value("siege_team","hit",siege)
	if float(gun.special.get("expedition_shield",0))>0:bonus+=0.06*rank("shield_lens")
	if gun.hp<gun.max_hp*0.5 and rank("rescue_patch")>0 and Milestones.ready(gun,"rescue_patch",now,8):gun.heal(gun.max_hp*0.03*rank("rescue_patch"))
	if switched:
		bonus+=0.10*rank("pivot_sight")+(0.15 if pursuit>=3 else 0.0)
		if pursuit>=6:Milestones.shield(gun,"pursuit",now,0.08,6)
		if pursuit>=9:gun.special.expedition_pursuit_until=now+4
		if rank("escort_plate")>0:Milestones.shield(gun,"escort_plate",now,0.04*rank("escort_plate"),8)
	elif same:
		bonus+=0.05*rank("sight_memory")+(0.10 if siege>=3 else 0.0)
		if now<float(gun.special.get("expedition_pursuit_until",-1)):
			bonus+=0.35
			gun.special.erase("expedition_pursuit_until")
	if siege>=6:
		var hits:=1+int(gun.special.get("expedition_siege_hits",0)) if same else 1
		gun.special.expedition_siege_hits=hits%3
		if hits==3:
			gun.heal(gun.max_hp*0.06)
			if siege>=9 and target is Unit:target.special.expedition_suppressed_until=maxf(now+4,float(target.special.get("expedition_suppressed_until",0)))
	return bonus

static func impact(target,source,damage:float,attack_type:String) -> float:
	if not active() or damage<=0:return damage
	if target.special.get("expedition_protected",false):return 0.0
	var gun=source.shooter() if is_instance_valid(source) and source is Projectile else source
	if attack_type in ["crush","radiation","temporal"]:return damage
	if gun is Unit and gun.side!="ally" and target.side=="ally":
		if clock(gun)<float(gun.special.get("expedition_suppressed_until",0)):damage*=0.80
		elif clock(gun)<float(gun.special.get("expedition_cover_until",0)):damage*=0.90
	if not eligible(gun) or BattleRequest.friendly(gun.side,target.side):return damage
	var tags:=Army.tags(gun.unit_id,context())
	var now:=clock(gun)
	var bonus:=Milestones.impact(gun,target,tags,now)
	bonus+=late_impact(gun,target,tags,now)
	bonus+=RelicEffects.impact(gun,target,tags,now)
	if "fortify" in tags and float(gun.special.get("expedition_still",0))>=2:bonus+=trait_value("fortify","hit")
	if ("mobile" in tags and synergy("mobile")>=2) or rank("mobile_magazine")>0:
		var rapid:bool="mobile" in tags and Milestones.stacks("mobile")>=9
		if float(gun.special.get("expedition_distance",0))>=(110 if rapid else 165) and now>=float(gun.special.get("expedition_mobile_cd",0)):
			bonus+=(trait_value("mobile","march") if "mobile" in tags else 0.0)+0.10*rank("mobile_magazine")
			if "mobile" in tags and Milestones.stacks("mobile")>=3:gun.special.expedition_shield=maxf(float(gun.special.get("expedition_shield",0)),gun.max_hp*0.05)
			if "mobile" in tags and Milestones.stacks("mobile")>=6:gun.heal(gun.max_hp*0.05)
			gun.special.expedition_distance=0.0;gun.special.expedition_mobile_cd=now+(4.0 if rapid else 8.0)
	if "air" in tags and synergy("air")>=3 and gun.special.get("expedition_sortie",false):
		bonus+=0.20;gun.special.expedition_sortie=false
	var previous:String=target.special.get("expedition_mark_type","")
	var different:bool=not previous.is_empty() and previous!=gun.unit_id and now-float(target.special.get("expedition_mark_time",-100))<=4
	if "energy" in tags:
		bonus+=trait_value("energy","hit")
		if different and now>=float(target.special.get("expedition_energy_cd",0)):
			bonus+=[0.0,0.0,0.15,0.25][synergy("energy")];target.special.expedition_energy_cd=now+4
			if Milestones.stacks("energy")>=3:gun.heal(gun.max_hp*0.03)
			if Milestones.stacks("energy")>=9:
				bonus+=0.40;target.special.expedition_overload_until=now+4.0
	if different and rank("crossfire")>0 and now>=float(target.special.get("expedition_crossfire_cd",0)):
		bonus+=0.10*rank("crossfire");target.special.expedition_crossfire_cd=now+4
	if "artillery" in tags:
		bonus+=trait_value("artillery","hit")
		if synergy("artillery")>=2 and now-float(target.special.get("expedition_first_mark",now))>=2 and now>=float(target.special.get("expedition_artillery_cd",0)):
			bonus+=[0.0,0.0,0.20,0.30][synergy("artillery")];target.special.expedition_artillery_cd=now+6
			if Milestones.stacks("artillery")>=3:target.special.expedition_exposed_until=now+3.0
	if "special" in tags and target.special.has("expedition_objective"):bonus+=trait_value("special","hit")
	if target.special.has("expedition_objective"):bonus+=0.10*rank("breach_tools")
	if target.hp<target.max_hp*0.35:bonus+=0.08*rank("execution_plan")
	if gun.hp<gun.max_hp*0.4:bonus+=0.08*rank("last_stand")
	if context().get("specializations",{}).get(gun.unit_id,"")=="b" and gun.special.get("expedition_release_shot",false):
		bonus+=0.20;gun.special.expedition_release_shot=false
	target.special.expedition_mark_type=gun.unit_id
	target.special.expedition_mark_time=now
	if not target.special.has("expedition_first_mark"):target.special.expedition_first_mark=now
	if gun.unit_id in Army.SCHOOLS.special and rank("hunter_protocol")>0 and target.hp>target.max_hp*0.9:bonus+=0.15*rank("hunter_protocol")
	return damage*(1.0+bonus)

static func defend(unit,damage:float) -> float:
	if not eligible(unit) or damage<=0:return damage
	var tags:=Army.tags(unit.unit_id,context())
	var now:=clock(unit)
	Milestones.defend(unit,tags,now)
	unit.special.expedition_last_hit=now
	var reduction:=RelicEffects.reduction(unit)
	if "vehicle" in tags and float(unit.special.get("expedition_drive_until",0))>now:reduction+=trait_value("vehicle","reduction")
	if "fortify" in tags and float(unit.special.get("expedition_still",0))>=2:reduction+=trait_value("fortify","reduction")
	if unit.hp<unit.max_hp*0.4:reduction+=0.06*rank("last_stand")
	if rank("emergency_position")>0 and unit._deployed:reduction+=0.04*rank("emergency_position")
	if context().get("specializations",{}).get(unit.unit_id,"")=="b" and float(unit.special.get("expedition_release_until",0))>now:reduction+=0.15
	if "vehicle" in tags and synergy("vehicle")>=3 and not unit.special.get("expedition_first_shield",false):
		unit.special.expedition_first_shield=true
		unit.special.expedition_shield=float(unit.special.get("expedition_shield",0))+unit.max_hp*0.10
	return damage*(1.0-minf(0.35,reduction))

static func absorb(unit,damage:float) -> float:
	if not eligible(unit) or damage<=0:return damage
	var shield:float=unit.special.get("expedition_shield",0)
	var taken:=minf(shield,damage)
	unit.special.expedition_shield=shield-taken
	RelicEffects.Ultimate.absorbed(unit,taken)
	return damage-taken

static func speed_factor(unit:Unit) -> float:
	# Enemy houses never consume expedition bonuses; read live context once.
	if unit.side!="ally" or not BattleRequest.extensions_enabled():return 1.0
	var expedition:Dictionary=BattleRequest.combat_context.get("expedition",EMPTY_SPEED_CONTEXT)
	if expedition.is_empty():return 1.0
	if unit.special.get("expedition_convoy",false):return 0.0 if unit.special.get("expedition_convoy_paused",false) else CONVOY_SPEED
	var extra:=0.0
	if unit.is_air and synergy("air")>=2 and not is_instance_valid(unit.attack_target) and unit.logistics.air_state in ["returning","flying"]:extra+=0.10
	if expedition.get("specializations",EMPTY_SPEED_CONTEXT).get(unit.unit_id,"")=="b" and float(unit.special.get("expedition_release_until",0))>clock(unit):extra+=0.15
	var current:float=unit.special.get("expedition_speed_factor",1.0)
	return minf(1.3,current+extra)/maxf(1.0,current)

static func defeated(world,victim,killer) -> void:
	if not active() or world==null:return
	if world.allied_state.has("expedition_tally") and killer is Unit and is_instance_valid(killer) and killer.side=="ally" and BattleRequest.is_house(victim.side) and not BattleRequest.friendly("ally",victim.side) and not AlliedAbilities.flag(victim,"DontScore"):
		var scorers: Dictionary = world.allied_state.expedition_tally.scorers
		scorers[killer.unit_id] = int(scorers.get(killer.unit_id,0))+1
	if eligible(victim) and "infantry" in Army.tags(victim.unit_id,context()):world.allied_state.expedition_rally_until=clock(victim)+10.0
	if eligible(killer) and BattleRequest.is_house(victim.side) and not BattleRequest.friendly(killer.side,victim.side):RelicEffects.defeated(killer,clock(killer))
	if eligible(killer) and BattleRequest.is_house(victim.side) and not BattleRequest.friendly(killer.side,victim.side):Milestones.defeated(killer,Army.tags(killer.unit_id,context()),clock(killer))
	if not eligible(killer) or victim.side!="enemy" or synergy("infantry")<2:return
	if "infantry" not in Army.tags(killer.unit_id,context()):return
	var now:=clock(killer)
	if now>=float(world.allied_state.get("expedition_rally_until",0)) or now<float(killer.special.get("expedition_rally_cd",0)):return
	killer.heal(killer.max_hp*0.05)
	killer.special.expedition_rally_cd=now+15.0
	world.allied_state.expedition_rally_until=0.0
