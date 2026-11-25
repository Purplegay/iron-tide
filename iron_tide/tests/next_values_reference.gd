extends RefCounted

const KEY="progression_v1"
const CELL=55.0

static func state(actor) -> Dictionary:
	var special: Dictionary = actor.special
	return special[KEY] if special.has(KEY) else special.get_or_add(KEY,{})

static func active(actor) -> bool:
	return BattleRequest.extensions_enabled() and AlliedAbilities.alive(actor) and not temporary(actor)

static func temporary(actor) -> bool:
	return is_instance_valid(actor) and actor.special.has("expansion_temporary")

static func rank(actor,id:String) -> int:
	return clampi(int(BattleRequest.combat_context.get("card_ranks",{}).get(id,0)) if actor.side=="ally" else 0,0,3)

static func value(actor,id:String,key:String) -> float:
	return float(GameData.get_skill(id).get("values",{}).get(key,[0,0,0,0])[rank(actor,id)])

static func talent_rank(actor,id:String) -> int:
	if not active(actor) or not BattleRequest.has_unit_talent(actor.unit_id,id,actor.side):return -1
	return MetaProgress.talent_rank(actor.unit_id,id,BattleRequest.combat_context.get("unit_talents",{}))

static func talent(actor,id:String,key:String) -> float:
	var level:=talent_rank(actor,id)
	if level<0:return 0.0
	return float(GameData.meta_config.unit_talents[actor.unit_id][id].values[key][level])

static func world(actor):
	return actor.battle if actor is Building else actor._battle_world()

static func owner(source):
	if not is_instance_valid(source):return null
	return source.shooter() if source is Projectile else source

static func enemy(actor,target) -> bool:
	if not is_instance_valid(actor) or not (actor is Unit or actor is Building):return false
	return AlliedAbilities.alive(target) and target.side!="neutral" and not BattleRequest.friendly(actor.side,target.side)

static func weapon(actor) -> Dictionary:
	return actor.weapon if actor is Building else actor._active_weapon()

static func hit(actor,target,factor:float,point:=Vector2.INF,base:Dictionary={}) -> void:
	if not enemy(actor,target):return
	var w:Dictionary=(weapon(actor) if base.is_empty() else base).duplicate(true)
	w.damage=float(w.get("damage",0))*factor
	var bonus:Dictionary=actor.bonuses.duplicate(true)
	bonus.expansion_extra=true
	bonus.reference_weapon=w.duplicate(true)
	var damage:=CombatMath.full_damage(w,target.armor,bonus,null,target.ra2_armor,0.0,target)
	target.receive_hit(damage,str(w.get("attack_type","shell")),bonus,actor,str(w.get("ra2_warhead","")))
	if point.is_finite():Effects.spawn_beam(point,Effects.hit_position(target),Color.CYAN,"laser",1.5,.15)

static func point(actor,target) -> Vector2:
	return target.closest_footprint_point(actor.position) if target is Building else target.position

static func area(actor,at:Vector2,radius:float,factor:float,slow:=0.0,seconds:=0.0,base:Dictionary={}) -> void:
	var battle=world(actor)
	if battle==null:return
	for target in battle.units+battle.buildings:
		if not enemy(actor,target):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null):continue
		var where:Vector2=target.closest_footprint_point(at) if target is Building else target.position
		if where.distance_to(at)>radius:continue
		if factor>0:hit(actor,target,factor,Vector2.INF,base)
		if AlliedAbilities.alive(target) and target is Unit and slow>0:
			target.add_buff("electric_slow",seconds,slow,"区域减速")

static func label(actor,text:String) -> void:
	# Persistent effects are represented by the shared status markers and HUD.
	actor.queue_redraw()

static func timer(s:Dictionary,key:String,delta:float) -> void:
	if s.has(key):
		s[key]=maxf(0,float(s[key])-delta)
		if s[key]<=0:s.erase(key)

static func summon(actor,id:String,at:Vector2,kind:String,life:float,hp:float,damage:float):
	var battle=world(actor)
	if battle==null:return null
	var open:Vector2=at if kind in ["bait","ink"] and battle.path_service.in_naval_water(at) else preload("res://scripts/world/american_paradrop.gd").open_ground(battle,at)
	if kind in ["bait","ink"] and not battle.path_service.in_naval_water(open):return null
	if not open.is_finite():return null
	var unit=battle.spawn_unit(id,actor.side,open)
	if unit==null:return null
	unit.special.expansion_temporary={"owner":actor,"kind":kind,"left":life,"origin":open}
	unit.special.erase("academy_hero")
	unit.skills.clear();unit.passive={};unit.buffs.clear()
	unit.data=unit.data.duplicate(true)
	unit.data.cost=0
	unit.max_hp=actor.max_hp*hp;unit.hp=unit.max_hp
	unit._base_max_hp=unit.max_hp
	if kind in ["post","twin","mirror"]:
		unit.weapon=actor._active_weapon().duplicate(true)
		unit.bonuses=actor.bonuses.duplicate(true)
	unit._base_atk=actor._base_atk*damage
	unit._recompute_bonuses()
	unit._refresh_weapon_derived()
	unit.logistics.capacity=0
	unit._vet_value=0
	unit.sight=0
	for group in ["allied_sonar_sensors","enemy_sonar_sensors"]:unit.remove_from_group(group)
	if kind in ["post","reserve","bait","ink","nest"]:
		unit._base_speed=0;unit.move_speed=0
		unit.attack_range=actor.attack_range
		unit.collision_layer=0;unit.collision_mask=0
	unit.display_name={"post":"守夜哨像","reserve":"备用哨像","twin":"时差车","mirror":"折光镜像"}.get(kind,kind)
	if kind in ["reserve","bait","ink","nest"]:unit.weapon={};unit.fire_stance="none"
	return unit

static func dissolve(unit) -> void:
	if not is_instance_valid(unit):return
	if unit.special.get("expansion_temporary",{}).get("kind")=="twin":Effects.spawn_impact(unit.position,Color.CYAN,26)
	unit.hp=0;unit._dead=true
	unit.queue_free()
