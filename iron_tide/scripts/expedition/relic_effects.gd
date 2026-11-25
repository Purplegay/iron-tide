extends RefCounted
const Relics=preload("res://scripts/expedition/relics.gd")
const Ultimate=preload("res://scripts/expedition/ultimate_relics.gd")

static func has(id:String) -> bool:
	return Relics.owned(BattleRequest.combat_context.get("expedition",{}),id)

static func ready(unit,key:String,now:float,cooldown:float) -> bool:
	var field:="expedition_relic_cd_"+key
	if now<float(unit.special.get(field,0)):return false
	unit.special[field]=now+cooldown
	return true

static func shield(unit,fraction:float) -> void:
	unit.special.expedition_shield=maxf(float(unit.special.get("expedition_shield",0)),unit.max_hp*fraction)

static func tick(unit,now:float,reloaded:bool) -> void:
	Ultimate.tick(unit,now,reloaded)
	var still:float=unit.special.get("expedition_still",0)
	if unit._deployed and still>=3:
		if unit.unit_id=="E1" and has("sandbag_standard") and ready(unit,"sandbag",now,15):shield(unit,0.12)
		if unit.unit_id=="SCHP" and has("rotor_workshop") and ready(unit,"rotor",now,5):
			unit.heal(unit.max_hp*0.04);shield(unit,0.06)
	if unit.is_air and reloaded and has("sortie_seal"):
		unit.heal(unit.max_hp*0.10)
		unit.special.expedition_relic_sortie=true

static func count_hit(unit,key:String,now:float,cap:int,cycle:bool) -> int:
	var field:="expedition_relic_count_"+key
	var last:float=unit.special.get(field+"_time",-100.0)
	if now-last<0.25:return 0
	var count:int=0 if now-last>=5 else int(unit.special.get(field,0))
	count=mini(cap,count+1)
	unit.special[field]=0 if cycle and count==cap else count
	unit.special[field+"_time"]=now
	return count

static func impact(gun,target,tags:Array,now:float) -> float:
	var bonus:=Ultimate.impact(gun,target,now)
	if has("prism_lens") and now<float(target.special.get("expedition_relic_prism_until",0)):bonus+=0.20
	if gun.unit_id=="SREF" and has("prism_lens"):target.special.expedition_relic_prism_until=now+4
	if gun.unit_id=="GGI" and gun._deployed and has("guardian_sight") and target is Unit and GameData.unit_production_category(target.data) in ["vehicle","naval"]:
		bonus+=0.30
		if ready(gun,"guardian",now,6):shield(gun,0.08)
	if gun.unit_id=="MTNK" and has("drive_flywheel") and float(gun.special.get("expedition_drive_until",0))>now and ready(gun,"drive",now,6):
		bonus+=0.35;gun.heal(gun.max_hp*0.05)
	if gun.unit_id=="HTNK" and has("rhino_drum"):
		count_hit(gun,"rhino",now,5,false)
		bonus+=0.08*int(gun.special.get("expedition_relic_count_rhino",0))
	if gun.unit_id in ["SHK","TTNK"] and has("tesla_coil") and count_hit(gun,"tesla",now,3,true)==3:
		bonus+=0.60;shield(gun,0.05)
	if gun.unit_id in ["GHOST","TANY","BORIS"] and has("commando_dogtag") and target.hp<target.max_hp*0.35:bonus+=0.25
	if has("shield_capacitor") and float(gun.special.get("expedition_shield",0))>0 and ready(gun,"capacitor",now,4):bonus+=0.20
	if has("redline_core") and gun.hp<gun.max_hp*0.4 and ready(gun,"redline",now,5):gun.heal(gun.max_hp*0.03)
	if "artillery" in tags and has("barrage_counter") and count_hit(gun,"barrage",now,3,true)==3:bonus+=0.35
	if "air" in tags and has("sortie_seal") and gun.special.get("expedition_relic_sortie",false):
		bonus+=0.40;gun.special.expedition_relic_sortie=false
	return bonus

static func reduction(unit) -> float:
	return 0.15 if has("redline_core") and unit.hp<unit.max_hp*0.4 else 0.0

static func defeated(killer,now:float) -> void:
	Ultimate.defeated(killer,now)
	if killer.unit_id in ["GHOST","TANY","BORIS"] and has("commando_dogtag") and ready(killer,"dogtag",now,3):killer.heal(killer.max_hp*0.08)

static func append_status(unit,tags:Array,entries:Array) -> void:
	for id:String in BattleRequest.combat_context.get("expedition",{}).get("relics",{}):
		if not has(id) or not Relics.applies(id,unit.unit_id,tags):continue
		var row:Dictionary=Relics.ITEMS[id]
		entries.append({"id":"expedition_relic_"+id,"kind":"expedition","name":Relics.grade(id)+" · "+str(row.name),"text":Relics.description(id),"icon":str(row.icon),"stacks":1,"limit":1,"left":0,"timed":false,"col":Relics.tint(id)})
