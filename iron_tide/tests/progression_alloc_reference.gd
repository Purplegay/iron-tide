extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Heroes=preload("res://scripts/units/expansion_heroes.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")
const Talents=preload("res://scripts/units/expansion_talents.gd")
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
const Visual=preload("res://scripts/units/expansion_visual.gd")
const Mirror=preload("res://scripts/units/mirror_fork.gd")

static func tick(unit: Unit,dt:float) -> bool:
	if not BattleRequest.extensions_enabled() or not AlliedAbilities.alive(unit) or unit.special.has("hero_wreck"):return false
	if R.temporary(unit):
		if Heroes.temporary_tick(unit,dt):return true
		if Cards.mine_tick(unit,dt):return true
	if not unit.special.has(R.KEY) and unit.unit_id not in ["E1","MTNK","HTNK","MGTK","TTNK","V3","HTK","DLPH","CARRIER","BEAG","DEST"] and not GameData.get_skill(unit.passive.get("id","")).get("expansion",false):return false
	var previous_arcs := int(unit.special.get(R.KEY,{}).get("arc_count",0))
	var idle := preload("res://scripts/units/unit_expansion_idle.gd").try_tick(unit,dt)
	if not idle:
		Cards.tick(unit,dt);Talents.tick(unit,dt)
		if Heroes.tick(unit,dt):return true
	unit._recompute_bonuses()
	# Idle bookkeeping has no animated overlay; normal movement, turning,
	# damage, selection and weapon animations keep their own redraw requests.
	# The fallback low-health smoke still needs its original continuous refresh.
	if not idle or previous_arcs > 0 or unit.hp < unit.max_hp * 0.42: unit.queue_redraw()
	return false

static func ready(unit,ab) -> bool:
	if not R.active(unit) or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.special.has("hero_wreck") or R.state(unit).has("succession"):return false
	if ab.id=="ap_north_twin" and AlliedAbilities.alive(R.state(unit).get("twin")):return not R.state(unit).has("swap_cd")
	if ab.id==Mirror.ID and Mirror.target(unit)!=null:return not unit.special.has("parasite")
	if ab.id=="ap_seismic_anchor" and not unit._deployed:return false
	return ab.ready()

static func cast(unit,ab,point:Vector2) -> bool:
	if not ready(unit,ab):return false
	return Heroes.cast(unit,ab,point) if ab.id in Heroes.ACTIVE else Cards.cast(unit,ab,point)

static func target_allowed(unit: Unit,target) -> bool:
	var s:Dictionary=unit.special.get(R.KEY,{})
	if s.has("succession") or s.has("rebirth_lock") or s.has("dive"):return false
	if s.has("taunt") and AlliedAbilities.alive(s.taunt) and not is_same(target,s.taunt):return false
	if is_instance_valid(target) and (target is Unit or target is Building):
		var t:Dictionary=target.special.get(R.KEY,{})
		if t.has("succession") or (t.has("dive") and not BattleRequest.friendly(unit.side,target.side)):return false
	return true

static func shot(unit,target,bonus:Dictionary) -> void:
	if not BattleRequest.extensions_enabled():return
	Talents.shot(unit,target,bonus)
	var s:=R.state(unit)
	bonus.expansion_origin=unit.position;bonus.expansion_volley=s.get("volley",0)
	if unit.passive.get("id")=="ps_north_echo":bonus.expansion_echo_weapon=R.weapon(unit).duplicate(true)
	if float(s.get("prism_damage",0))>0:
		bonus.expansion_prism_multiplier=1.0+s.prism_damage
		bonus.attack_bonus=float(bonus.get("attack_bonus",1))*bonus.expansion_prism_multiplier

static func modify_reload(unit,seconds:float) -> float:
	if not R.active(unit):return seconds
	return Talents.modify_reload(unit,Cards.modify_reload(unit,seconds))

static func impact(target,source,amount:float,bonus:Dictionary) -> float:
	var actor=R.owner(source)
	if not BattleRequest.extensions_enabled() or not is_instance_valid(actor) or not (actor is Unit or actor is Building):return amount
	var extra:bool=bonus.get("expansion_extra",false)
	if source is Projectile and source.target!=target and not source.is_sonic:extra=true
	var damage:=Cards.impact(actor,target,amount,extra)
	if target is Unit and Cards.passive(target)=="ps_formation_cover" and target.is_air_target():
		var count:=0
		for neighbor in R.world(target).units:
			if neighbor!=target and AlliedAbilities.alive(neighbor) and neighbor.unit_id in ["ORCA","BEAG"] and neighbor.is_air_target() and neighbor.side==target.side and neighbor.position.distance_to(target.position)<=2.5*R.CELL:count+=1
		R.state(target).cover=mini(count,4);damage*=1.0-mini(count,4)*R.value(target,"ps_formation_cover","defense")
	return damage

static func damaged(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not BattleRequest.extensions_enabled():return
	Contracts.damaged(target,source,amount)
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not (actor is Unit or actor is Building):return
	var s:=R.state(actor)
	if is_same(s.get("taunt"),target):s.erase("taunt");R.label(actor,"嘲讽解除")
	var extra:bool=bonus.get("expansion_extra",false) or (source is Projectile and source.target!=target)
	if actor is Unit:
		if bonus.has("expansion_origin"):s.shot_origin=bonus.expansion_origin
		Heroes.hit(actor,target,extra,bonus.get("expansion_echo_weapon",{}));Talents.hit(actor,target,extra)

static func before_death(unit,killer) -> bool:
	if R.temporary(unit):
		if unit.special.expansion_temporary.kind=="mirror":Mirror.detonate(unit)
		else:R.dissolve(unit)
		return true
	if not BattleRequest.extensions_enabled():return false
	Mirror.clear(unit)
	if not unit.special.get("house_eliminated",false) and Heroes.pending_death(unit):return true
	var state:=R.state(unit)
	R.dissolve(state.get("twin"));state.erase("twin")
	state.erase("echoes");state.erase("scrap");state.erase("nests");state.erase("crown")
	Talents.missile_destroyed(unit,killer)
	return false

static func killed(world,target,source) -> void:
	if world==null or not BattleRequest.extensions_enabled():return
	Contracts.killed(world,target,source);Cards.killed(world,target,source)

static func speed(unit: Unit) -> float:
	var s:Dictionary=unit.special.get(R.KEY,{})
	if s.has("move_lock"):return 0.0
	var multiplier:float=1.0+float(s.get("speed_bonus",0))
	if s.has("afterburn"):multiplier*=1.0+s.afterburn.speed
	if s.has("dive_boost"):multiplier*=1.0+R.talent(unit,"dive_momentum","speed")
	return multiplier

static func info(unit,ab) -> Dictionary:
	var s:=R.state(unit)
	if ab.id==Mirror.ID:
		var chosen=Mirror.target(unit)
		var active:bool=chosen!=null
		var description:=MetaProgress.Academy.skill_description(GameData.get_skill(ab.id),R.rank(unit,ab.id))
		if active:description+="\n再次按 W：转移至血量较高的镜像，获得 %.0f 护盾；引爆两辆镜像。"%chosen.hp
		return {"id":ab.id,"name":"转移并引爆" if active else ab.display_name,"desc":description,"ready":ready(unit,ab),"cd_left":0.0 if active else ab.cd_left,"cooldown":ab.cooldown,"cd_frac":0.0 if active else ab.cd_frac(),"active":active,"active_frame":active}
	var twin:bool=ab.id=="ap_north_twin" and AlliedAbilities.alive(s.get("twin"))
	var left:float=float(s.get("swap_cd",0)) if twin else ab.cd_left
	var duration:float=R.value(unit,ab.id,"swap") if twin else ab.cooldown
	var result:Dictionary={"id":ab.id,"name":"交换 · 双星易位" if twin else ab.display_name,"desc":MetaProgress.Academy.skill_description(GameData.get_skill(ab.id),R.rank(unit,ab.id))+("\n交换 %.2fs；下次召唤 %.1fs"%[left,ab.cd_left] if twin else ""),"ready":ready(unit,ab),"cd_left":left,"cooldown":duration,"cd_frac":left/maxf(.01,duration),"active":twin}
	if ab.id=="ap_north_twin":result.active_frame=twin
	return result

static func contact(target,source) -> void:
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not (actor is Unit or actor is Building):return
	var s:Dictionary=actor.special.get(R.KEY,{})
	if is_same(s.get("taunt"),target):s.erase("taunt");R.label(actor,"嘲讽解除")
