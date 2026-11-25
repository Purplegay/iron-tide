extends RefCounted
const SovietSpecials=preload("res://scripts/units/soviet_specials.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const Talents=preload("res://scripts/units/convoy_talents.gd")
const Cards=preload("res://scripts/units/convoy_cards.gd")
const IDs=["FV","HARV"]
const CELL=55.0

static func match_valid(world) -> bool:
	return world!=null and BattleRequest.extensions_enabled() and MetaProgress.Academy.eligible(world) and BattleRequest.combat_context.get("expedition",{}).is_empty()

static func unlock(id:String) -> bool:
	var totals:Dictionary=MetaProgress.academy.get_or_add("hero_builds",{})
	if int(totals.get(id,0))>=1:return true
	totals[id]=1
	if MetaProgress.save():return true
	totals.erase(id)
	return false

static func boarded(u) -> void:
	if not AlliedAbilities.alive(u) or u.logistics.passengers.is_empty() or R.temporary(u):return
	var w=u._battle_world()
	if match_valid(w) and not u.special.has("convoy") and (u.side!="ally" or unlock("FV")):promote(u,w,MetaProgress)
	if not u.special.has("convoy"):return
	var s:Dictionary=u.special.convoy
	if u.special.hero_command_rank>=1 and not s.has("ride_cd"):
		u.add_buff("speed",3,.15,"搭顺风车");s.ride_cd=15.0

static func unloaded(u,p) -> void:
	if p.special.has("convoy_loan"):
		R.dissolve(p)
	elif u.special.hero_survival_rank>=2 and not p.buff_value("convoy_exit_cd")>0:
		p.add_buff("convoy_invulnerable",2,1,"安全下车")
		p.add_buff("convoy_exit_cd",20,1,"安全下车冷却")

static func collected(u) -> void:
	if u.side=="ally" and match_valid(u._battle_world()) and unlock("HARV"):u.special.erase("convoy_miner_hit")

static func promote(u,w,meta) -> bool:
	if not AlliedAbilities.alive(u) or u.unit_id not in IDs or R.temporary(u) or u.special.has("academy_hero") or w==null:return false
	var used:Dictionary=w.allied_state.get_or_add("convoy_deployed",{}).get_or_add(u.side,{})
	if used.has(u.unit_id):return false
	used[u.unit_id]=true
	if u.side=="ally":w.allied_state.get_or_add("named_heroes",{})[u.unit_id]=10
	var id:String=u.unit_id
	u.special.academy_hero=id
	var profile:Dictionary=BattleRequest.combat_context if u.side=="ally" else {}
	u.special.hero_command_rank=int(profile.get("hero_escort_ranks",{}).get(id,0))
	u.special.hero_survival_rank=int(profile.get("hero_survival_ranks",{}).get(id,0))
	u.special.convoy={"volume":100,"base_hold":u.cargo_cap,"position":u.position,"heading":u.hull_angle,"base_sight":u.sight}
	u.display_name="英雄 · "+str(MetaProgress.Academy.HEROES[id])
	var training:Dictionary=profile.get("hero_training",{})
	var scale:float=profile.get("hero_training_scale",MetaProgress.Academy.HERO_TRAINING_SCALE)
	var fraction:float=u.hp/maxf(1,u.max_hp)
	u._base_max_hp*=1+.01*MetaProgress.Academy.training_percent("health",MetaProgress.Academy.training_rank(training,id,"health"),scale)
	u.max_hp=u._base_max_hp;u.hp=u.max_hp*fraction
	u._base_atk*=CombatMath.additional_growth_ratio(u.bonuses,1+.01*MetaProgress.Academy.training_percent("firepower",MetaProgress.Academy.training_rank(training,id,"firepower"),scale))
	u.special.hero_skin=meta.academy.get("hero_skin",{}).get(id,false)
	if id=="HARV":
		if u.special.hero_command_rank>=1:
			u.special.convoy_double_hold=true
			u.cargo_cap*=2
		u._suspend_harvest()
	if id=="FV" and u.special.hero_command_rank>=4:u.add_to_group("convoy_observers")
	u.refresh_house_color()
	u.equip_hero_cards();u._refresh_weapon_derived();u._recompute_bonuses();u.queue_redraw()
	return true

static func idle_miner(u,dt:float) -> bool:
	if u.special.get("convoy_delivery",false):return false
	if u.harvest_state in ["to_base","unloading"] or u.cargo>=u.cargo_cap:
		if u.harvest_state!="idle":u._suspend_harvest()
		if u.cargo>=u.cargo_cap:return true
	if u.harvest_state in ["to_node","harvesting"]:
		var node=u.resource_node
		if is_instance_valid(node) and u._node_ok(node,.001) and u.special.convoy.get("mine_origin",u.position).distance_to(node.position)<=3*CELL:return false
		u._suspend_harvest()
	if u.hold_position or u.patrolling or not u.auto_harvest_enabled:return true
	u.auto_harvest_idle+=dt
	if u.auto_harvest_idle<2:return true
	u.auto_harvest_idle=0
	var node=u._ore_target(.001)
	if is_instance_valid(node) and node.position.distance_to(u.position)<=3*CELL:
		u.special.convoy.mine_origin=u.position
		u.order_harvest(node)
		return false
	u._claim_release()
	return true

static func spend(u,amount:float) -> float:
	var used:=minf(amount,u.cargo)
	if used<=0:return 0
	u.cargo_gems*=1.0-used/u.cargo
	u.cargo=maxf(0,u.cargo-used)
	return used

static func defeated(world,victim,source) -> void:
	var u=R.owner(source)
	if not u is Unit or not u.special.has("convoy") or u.unit_id!="HARV" or R.temporary(victim) or victim.side=="neutral" or BattleRequest.friendly(u.side,victim.side):return
	var s:Dictionary=u.special.convoy
	if u.special.hero_survival_rank>=3:s.volume=mini(500,int(s.volume)+20)
	if u.special.hero_command_rank>=2 and preload("res://scripts/rules/expansion_contracts.gd").vehicle(victim):
		u._collect_cargo(.05*float(s.base_hold))
	if u.special.hero_survival_rank>=5 and victim is Building and (victim.is_hq or victim.is_repair_depot() or victim.building_id in ["GATECH","NATECH","YATECH"]):
		var launch:Dictionary=SovietSpecials.launch_record(u,victim.position)
		launch.damage_scale*=.1;launch.no_radiation=true
		world.allied_state.get_or_add("soviet_nukes",[]).append(launch)
		preload("res://scripts/world/battle_music_director.gd").superweapon_used(world, u.side)
	u.queue_redraw()

static func crush(u,step:Vector2,dt:float) -> bool:
	var volume:int=u.special.convoy.volume
	if volume<200 or step.is_zero_approx():return false
	if volume>=500:OpenTopped.crush_contact(u,true)
	if volume>=300 and preload("res://scripts/units/ra3_apocalypse_crush.gd").contact(u,step,dt):return true
	var hit=u.move_with_traffic_exceptions(step,true)
	if hit!=null:
		var target=hit.get_collider()
		if target is Unit and target.is_prone() and not MetaProgress.Academy.crush_immune(target) and R.enemy(u,target):target.receive_hit(99999,"crush",{},u)
	return false

static func damaged(target,source,amount:float,bonus:Dictionary) -> void:
	var u=R.owner(source)
	if not u is Unit or u.unit_id not in IDs or amount<=0 or target.side=="neutral" or BattleRequest.friendly(u.side,target.side):return
	if not u.special.has("convoy"):
		if u.unit_id=="HARV" and u.side=="ally" and not R.temporary(u) and match_valid(u._battle_world()):u.special.convoy_miner_hit=true
		return
	if bonus.get("expansion_extra",false):return
	Cards.work(u,target,false,bonus)
	Talents.hit(u,target)

static func absorb(u,amount:float,source) -> float:
	if amount<=0:return amount
	var actor=R.owner(source)
	if not (actor is Unit or actor is Building) or BattleRequest.friendly(u.side,actor.side):return amount
	var s:Dictionary=u.special.convoy
	if u.unit_id=="FV":
		s.quiet=0.0
		if u.special.hero_command_rank>=5:
			if not s.has("guard_cd"):s.guard_cd=30.0;s.guard_time=10.0
			var age:=10.0-float(s.get("guard_time",0))
			return amount*(1.0-.9*(1.0-log(1.0+.3*age)/log(4.0)))
	elif u.special.hero_command_rank>=4 and s.base_hold>0:
		return amount-spend(u,.5*amount/u.max_hp*s.base_hold)*u.max_hp/s.base_hold
	return amount

static func fired(u,target,bonus:Dictionary,first:bool) -> void:
	if u.unit_id=="HARV" and u.velocity.length()<1 and (target is Building or not AlliedAbilities.infantry(target)):bonus.attack_bonus=float(bonus.get("attack_bonus",1))*1.1
	if first:
		u.special.convoy.volley=int(u.special.convoy.get("volley",0))+1
		Cards.fired(u)
		if u.unit_id=="HARV":Talents.split_fire(u,target)
	bonus.convoy_volley=u.special.convoy.get("volley",0)

static func tick(u,dt:float) -> void:
	var s:Dictionary=u.special.convoy
	for key in ["press_recoil","crew_flash","ride_cd","guard_cd","guard_time","lamp_cd","cleanse_cd","field_cd","mirror_cd","start_cd","repair_cd","rescue_time","projection_cd"]:
		R.timer(s,key,dt)
	Cards.tick(u,dt)
	Talents.tick(u,dt)

