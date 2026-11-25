extends RefCounted
## Future Tank timing authority: AlliedFutureTank.xml + Weapon_EP1.xml.
static func pending(actor) -> bool:
	var world=actor._battle_world()
	if world==null or world.cast_slot<0 or actor not in world.selected_units:return false
	var primary=world.selected_skill_unit()
	return is_instance_valid(primary) and primary.ability_at(world.cast_slot)!=null and primary.ability_at(world.cast_slot).id==Ra3Expansion.BEAM

static func prepare(actor, target) -> bool:
	if actor.unit_id!=Ra3Expansion.FUTURE:return true
	if pending(actor) or actor.special.has("ra3_riot_point") or actor.special.has("ra3_riot_approach"):return false
	if actor.special.get("ra3_pre_target")!=target:
		actor.special.ra3_pre_target=target
		actor.special.ra3_pre_left=0.1 # PER_TARGET PreAttackDelay, RA3 seconds.
		actor.special.ra3_pre_elapsed=0.0
		return false
	return float(actor.special.get("ra3_pre_left",0.0))<=0.0

static func tick(actor, delta: float) -> void:
	if actor.unit_id!=Ra3Expansion.FUTURE:return
	if AlliedAbilities.frozen(actor) or actor._stun_timer>0.0:return
	actor.special.ra3_just_built=maxf(0.0,float(actor.special.get("ra3_just_built",0.0))-delta)
	actor.special.ra3_attack_age=float(actor.special.get("ra3_attack_age",100.0))+delta
	if pending(actor):actor.special.ra3_aim_time=float(actor.special.get("ra3_aim_time",0.0))+delta
	elif not actor.special.has("ra3_riot_point") and not actor.special.has("ra3_riot_approach"):actor.special.erase("ra3_aim_time")
	var target=actor.special.get("ra3_pre_target")
	if target!=null and (not AlliedAbilities.alive(target) or actor.attack_target!=target or not actor._weapon_target_valid(target) or actor.fire_stance=="none"):
		actor.special.erase("ra3_pre_target");actor.special.erase("ra3_pre_left")
	if float(actor.special.get("ra3_pre_left",0.0))>0.0:
		actor.special.ra3_pre_left=maxf(0,float(actor.special.ra3_pre_left)-delta)
		actor.special.ra3_pre_elapsed=float(actor.special.get("ra3_pre_elapsed",0.0))+delta

static func fired(actor) -> void:
	actor.special.ra3_attack_age=0.0
	actor.special.ra3_attack_serial=int(actor.special.get("ra3_attack_serial",0))+1
	Ra2Sfx.play("RA3_EXP_ALL_FutureTank_PreFireChargeUp",actor.position)

static func desired(actor) -> String:
	var moving: bool=actor.velocity.length()>1.0
	if pending(actor) or actor.special.has("ra3_riot_point") or actor.special.has("ra3_riot_approach"):return "LASER_MOVING" if moving else "LASER"
	if float(actor.special.get("ra3_just_built",0.0))>0.0:return "XMOVA"
	if moving:return "MOVA"
	if float(actor.special.get("ra3_pre_left",0.0))>0.0:return "ATKG"
	if float(actor.special.get("ra3_attack_age",100.0))<5.0:return "ATKE" if int(actor.special.get("ra3_barrel",0))%2==0 else "ATKF"
	return "MOVA" if moving else ("AIDA" if actor.selected else "BIDA")
