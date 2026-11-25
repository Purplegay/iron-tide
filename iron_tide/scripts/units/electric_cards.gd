extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Equipment cards tied to electric weapons, open-topped crews and aircraft sorties.
const CHAIN := "ap_tesla_chain"
const PULSE := "ap_shock_pulse"
const GUARD := "ps_grounding"
const STRIDE := "ps_aftercurrent"
const STATE := "electric_chain"
const CREW := "crew_coordination"

static func chain_rule(unit) -> Dictionary:
	var rank:=clampi(int(BattleRequest.combat_context.get("card_ranks",{}).get(CHAIN,0)) if unit.side=="ally" else 0,0,3)
	var card:=GameData.get_skill(CHAIN)
	return {"primary":1.0+float(card.primary_bonus_by_rank[rank]),"value":float(card.branch_by_rank[rank])}

static func primary_multiplier(unit,target) -> float:
	if not BattleRequest.extensions_enabled() or unit.unit_id!="SHK" or not unit.special.has(STATE) or not is_instance_valid(target) or target is ForceFirePoint or BattleRequest.friendly(target.side,unit.side):return 1.0
	if int(unit.special[STATE].get("remaining",0))<=0:return 1.0
	return float(unit.special[STATE].get("primary",1.0))

static func restore(unit) -> void:
	# Keep owned ranks and compatible cooldowns; retire the old generic equipment.
	for i in range(unit.skills.size()-1,-1,-1):
		var card_id:String=unit.skills[i].id
		if card_id not in [PULSE,CHAIN,"ap_focus_fire"]:continue
		if not UnitSkillLayout.compatible(unit.unit_id,card_id):
			unit.skills.remove_at(i);continue
		var ab:Ability=unit.skills[i]
		var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get(card_id,0) if unit.side=="ally" else 0
		ab.setup(GameData.get_skill(card_id),rank) # setup preserves remaining cooldown.
		if unit.side=="ally":ab.value*=BattleRequest.card_scale(card_id)
	if unit.special.has(STATE):
		var rule:=chain_rule(unit)
		unit.special[STATE].primary=rule.primary
		unit.special[STATE].value=rule.value
		unit.special[STATE].left=minf(float(unit.special[STATE].left),float(GameData.get_skill(CHAIN).duration))
	var id:String=unit.passive.get("id","")
	if id in [GUARD,STRIDE]:
		if UnitSkillLayout.compatible(unit.unit_id,id):
			unit.passive=GameData.get_skill(id).duplicate(true)
			if unit.side=="ally":unit.passive.value*=BattleRequest.card_scale(id)
		else:unit.passive={}
	var old_count:int=unit.buffs.size()
	unit.buffs=unit.buffs.filter(func(buff):return buff.kind not in ["electric_guard","electric_stride"])
	if unit.buffs.size()!=old_count:unit._recompute_bonuses()
	unit._has_active_skills=not unit.skills.is_empty()

static func tick(unit, delta: float) -> void:
	if unit.special.has(STATE):
		unit.special[STATE].left -= delta
		if unit.special[STATE].left <= 0: unit.special.erase(STATE)
	if unit.special.has(CREW):
		var rows:Dictionary=unit.special[CREW]
		for target in rows.keys():
			rows[target].left-=delta
			if not AlliedAbilities.alive(target) or rows[target].left<=0:rows.erase(target)
		if rows.is_empty():unit.special.erase(CREW)

static func crew_damage(gun,target,damage:float,bonus:Dictionary) -> float:
	if not BattleRequest.extensions_enabled() or bonus.get("equipment_secondary",false) or not is_instance_valid(gun) or not gun is Unit or not OpenTopped.active(gun):return damage
	var carrier=gun.embarked_in
	if carrier.unit_id!="BFRT" or carrier.passive.get("id")!=GUARD or BattleRequest.friendly(target.side,carrier.side) or not BattleRequest.is_house(target.side):return damage
	var rows:Dictionary=carrier.special.get_or_add(CREW,{})
	var row:Dictionary=rows.get(target,{})
	if not row.is_empty() and row.left>0:
		if row.cooling:return damage
		if is_instance_valid(row.first) and row.first!=gun and row.first.embarked_in==carrier:
			rows[target]={"first":null,"left":P.number("mechanic/electric","crew_cooldown"),"cooling":true}
			return damage+damage*float(carrier.passive.value)
	rows[target]={"first":gun,"left":P.number("mechanic/electric","crew_window"),"cooling":false}
	return damage

static func return_speed(unit) -> float:
	if not BattleRequest.extensions_enabled() or unit.unit_id not in ["ORCA","BEAG"] or unit.passive.get("id")!=STRIDE:return 1.0
	var logistics=unit.logistics
	if logistics.ammo!=0 or logistics.air_state!="returning" or logistics.air_lift<=0.1 or not AlliedAbilities.alive(logistics.home):return 1.0
	return 1.0+float(unit.passive.value)

static func candidates(unit, center: Vector2, radius: float, skip = null) -> Array:
	var world = unit.battle if unit is Building else unit._battle_world()
	var result: Array = []
	if world == null: return result
	for actor in world.units + world.buildings:
		if not AlliedAbilities.alive(actor) or actor == skip or not BattleRequest.is_house(actor.side) or BattleRequest.friendly(actor.side,unit.side): continue
		if actor is Unit and (actor.is_air_target() or actor.embarked_in != null): continue
		if not world.actor_visible_to(unit.side, actor): continue
		var point: Vector2 = actor.closest_footprint_point(center) if actor is Building else actor.global_position
		if point.distance_squared_to(center) <= radius * radius: result.append(actor)
	result.sort_custom(func(a,b):
		var da: float = a.global_position.distance_squared_to(center)
		var db: float = b.global_position.distance_squared_to(center)
		return a.get_instance_id() < b.get_instance_id() if is_equal_approx(da,db) else da < db)
	return result

static func hit(unit, target, weapon: Dictionary, origin: Vector2,beam_seconds:=0.18, reference_weapon:Dictionary={}) -> void:
	if not AlliedAbilities.alive(target): return
	var world = unit.battle if unit is Building else unit._battle_world()
	if world != null:
		world.reveal_attack(unit, target)
		if world.actor_visible_to("ally",target) or world.actor_visible_to("ally",unit):
			Effects.spawn_beam(origin,Effects.hit_position(target),Color.SKY_BLUE,"tesla",2.2,beam_seconds)
	var damage := CombatMath.full_damage(weapon,target.armor,unit.bonuses,null,target.ra2_armor,0.0,target)
	var bonus:Dictionary=unit.bonuses.duplicate()
	bonus.equipment_secondary=true
	if CombatMath.FinalDamage.active():bonus=CombatMath.FinalDamage.packet(bonus,CombatMath.FinalDamage.weapon_reference(reference_weapon if not reference_weapon.is_empty() else weapon,target,bonus))
	target.receive_hit(damage,"tesla",bonus,unit,str(weapon.get("ra2_warhead","")))

static func cast(unit, ab: Ability) -> bool:
	if not BattleRequest.extensions_enabled() or not AlliedAbilities.alive(unit) or AlliedAbilities.frozen(unit): return false
	if unit is Building:
		if unit.building_id!="TESLA" or ab.id!=PULSE or not unit.is_operational():return false
		preload("res://scripts/units/tesla_support.gd").update_weapon(unit)
	elif unit.embarked_in != null or unit._stun_timer > 0 or unit.repairing: return false
	if ab.id == CHAIN:
		if unit.unit_id != "SHK": return false
		var rule:=chain_rule(unit)
		unit.special[STATE] = {"left":ab.duration,"remaining":P.count("mechanic/electric","shots"),"value":rule.value,"primary":rule.primary}
		return true
	var id:String=unit.building_id if unit is Building else unit.unit_id
	if ab.id != PULSE or not UnitSkillLayout.compatible(id,PULSE): return false
	if unit is Unit and not unit.power_disabled_reason().is_empty():return false
	var weapon: Dictionary = GameData.get_unit("SHK").weapon.duplicate()
	var native:Dictionary=unit.weapon if unit is Building else unit._active_weapon()
	weapon.damage = maxf(0.0,float(native.get("damage",0.0))) * clampf(ab.value,0.0,1.0)
	var reference_weapon:=weapon.duplicate()
	reference_weapon.damage=maxf(0.0,float(native.get("damage",0.0)))
	preload("res://scripts/core/shock_pulse.gd").spawn(unit,ab.radius)
	Ra2Sfx.play_weapon(weapon,unit.global_position)
	for target in candidates(unit,unit.global_position,ab.radius):
		if not AlliedAbilities.alive(unit): break
		hit(unit,target,weapon,unit._weapon_muzzle(),0.38,reference_weapon)
		if AlliedAbilities.alive(target) and target is Unit: target.add_buff("electric_slow",ab.duration,P.number("mechanic/electric","slow"))
	return true

static func chain_hit(unit, target) -> void:
	if not BattleRequest.extensions_enabled() or unit.unit_id != "SHK" or not unit.special.has(STATE) or not is_instance_valid(target) or target is ForceFirePoint or BattleRequest.friendly(target.side,unit.side): return
	var state: Dictionary = unit.special[STATE]
	var center: Vector2 = target.global_position
	var origin := Effects.hit_position(target)
	var weapon: Dictionary = unit._active_weapon().duplicate()
	var reference_weapon:=weapon.duplicate()
	# Apply the card's primary increase once, then branch fraction. Reserve remains primary-only.
	var primary:float=float(state.get("primary",1.0)) if int(state.remaining)>0 else 1.0
	weapon.damage = float(weapon.damage) * primary * float(state.value)
	state.remaining = maxi(0,int(state.remaining)-1)
	var neighbors := candidates(unit,center,P.number("mechanic/electric","branch_range")*Ra2Damage.PX_PER_CELL,target)
	for i in mini(P.count("mechanic/electric","branches"),neighbors.size()):
		if not AlliedAbilities.alive(unit): break
		hit(unit,neighbors[i],weapon,origin,0.18,reference_weapon)
