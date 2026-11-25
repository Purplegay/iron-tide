extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")

static func eligible(world) -> bool:
	return BattleRequest.extensions_enabled() and Q.eligible(world,"ORCA") and BattleRequest.combat_context.get("expedition",{}).is_empty()

static func combat_target(target) -> bool:
	if not AlliedAbilities.alive(target) or R.temporary(target):return false
	if target is Building:return not target.weapon.is_empty()
	return target is Unit and not target.is_harvester and target.embarked_in==null and not target.weapon.is_empty() and float(target.weapon.get("damage",0))>0

static func contact(world,side:String,target) -> void:
	if side!="ally" or not eligible(world) or not combat_target(target) or target.side=="neutral" or BattleRequest.friendly(side,target.side):return
	if not target.special.has("peregrine_contact_id"):
		var serial:int=int(world.allied_state.get("peregrine_contact_serial",0))+1
		world.allied_state.peregrine_contact_serial=serial;target.special.peregrine_contact_id=serial
	Q.progress(world,"ORCA").get_or_add("targets",{})[str(target.special.peregrine_contact_id)]=true

static func filled(unit,normal_hit:bool) -> void:
	if unit.side=="ally" and normal_hit and eligible(R.world(unit)):Q.progress(R.world(unit),"ORCA").second+=1

static func prepare_death(target,source,bonus:Dictionary) -> void:
	target.special.erase("peregrine_killing_side")
	if not bonus.get("peregrine_direct",false):return
	if not bonus.get("peregrine_hunt",false):
		if not source is Projectile or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	if source is Projectile and source.target!=target:return
	target.special.peregrine_killing_side=str(bonus.get("peregrine_side",""))

static func killed(world,target) -> void:
	var side:String=target.special.get("peregrine_killing_side","")
	if side!="ally" or not eligible(world) or target.side=="neutral" or BattleRequest.friendly(side,target.side) or not Q.vehicle(target):return
	Q.progress(world,"ORCA").first+=1
