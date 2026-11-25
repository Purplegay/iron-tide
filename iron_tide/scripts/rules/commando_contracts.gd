extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Breach=preload("res://scripts/units/tanya_breach.gd")
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
const HIT="commando_kill_hit"
const PASSIVE="ps_tanya_rhythm"

static func hero_id(source) -> String:
	if is_instance_valid(source) and source is Projectile and source.attacker_bonus.get("boris_mig",false):return "BORIS"
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not actor is Unit:return ""
	if actor.special.has(Breach.PAYLOAD):return str(actor.special[Breach.PAYLOAD].hero)
	return str(actor.special.get("academy_hero",""))

static func prepare_death(target,source,bonus:Dictionary) -> void:
	preload("res://scripts/rules/leizhu_contracts.gd").prepare_death(target,source,bonus)
	preload("res://scripts/rules/peregrine_contracts.gd").prepare_death(target,source,bonus)
	if hero_id(source) not in ["TANY","BORIS"]:return
	target.special[HIT]={"weapon":str(bonus.get("impact_weapon","")),"extra":bool(bonus.get("expansion_extra",false)),"effect":str(bonus.get("commando_effect","")),"boris_mig":bool(bonus.get("boris_mig",false))}

static func killed(world,target,source) -> void:
	preload("res://scripts/rules/leizhu_contracts.gd").killed(world,target)
	preload("res://scripts/rules/peregrine_contracts.gd").killed(world,target)
	if BattleRequest.extensions_enabled() and hero_id(source)=="BORIS":
		boris_killed(world,target,source);return
	if not BattleRequest.extensions_enabled() or hero_id(source)!="TANY" or R.temporary(target):return
	var actor=R.owner(source)
	if actor.side!="ally" or target.side=="neutral" or BattleRequest.friendly(actor.side,target.side):return
	var bomb:bool=actor.special.has(Breach.PAYLOAD)
	var owner=actor.special[Breach.PAYLOAD].get("owner") if bomb else actor
	var hit:Dictionary=target.special.get(HIT,{})
	var native_c4:bool=target is Building and target.special.get("yr_c4_death",false) and not target.special.get("c4_secondary",false) and not bomb
	var rifle:bool=target is Unit and AlliedAbilities.infantry(target) and not hit.get("extra",true) and str(hit.get("weapon","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_") in ["DoublePistols","DoublePistolsE"]
	var charge_building:bool=target is Building and bomb and hit.get("effect","")=="breach"
	if Contracts.eligible(world,"TANY") and BattleRequest.combat_context.get("expedition",{}).is_empty():
		var p:=Contracts.progress(world,"TANY")
		if rifle:p.first+=1
		if native_c4:p.second+=1
		if target is Building and not target.weapon.is_empty() and (native_c4 or charge_building or not hit.get("extra",true)):p.defenses+=1
	if native_c4:preload("res://scripts/units/tanya_operations.gd").c4_destroyed(owner,target)
	if (rifle or native_c4 or charge_building) and AlliedAbilities.alive(owner) and owner.side=="ally" and owner.special.get("academy_hero")=="TANY" and owner.passive.get("id")==PASSIVE:
		var s:Dictionary=owner.special.get("commando_hero_v2",{})
		if s.is_empty() or s.has("rhythm_cd"):return
		s.rhythm_left=R.value(owner,PASSIVE,"life");s.rhythm_cd=8.0
		s.rhythm_defense=R.value(owner,PASSIVE,"defense")
		owner._recompute_bonuses();owner.queue_redraw()

static func boris_killed(world,target,source) -> void:
	if not Contracts.eligible(world,"BORIS") or R.temporary(target) or not BattleRequest.combat_context.get("expedition",{}).is_empty():return
	var actor=R.owner(source)
	var side:String=source.owner_side if source is Projectile else (actor.side if is_instance_valid(actor) else "")
	if side!="ally" or target.side=="neutral" or BattleRequest.friendly(side,target.side):return
	var hit:Dictionary=target.special.get(HIT,{})
	var p:=Contracts.progress(world,"BORIS")
	var weapon:=str(hit.get("weapon","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	if target is Unit and AlliedAbilities.infantry(target) and not hit.get("extra",true) and weapon in ["AKM","AKME"]:p.first+=1
	if target is Building and hit.get("boris_mig",false):p.second+=1
