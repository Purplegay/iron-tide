extends RefCounted

const JAM := "ap_sonar_jam"
const COVER := "ps_flank_cover"
const GROUP := &"flank_cover_carriers"
const RANGE := 5.0 * Ra2Damage.PX_PER_CELL

static func valid_ship(actor, target) -> bool:
	if not target is Unit or not AlliedAbilities.alive(target) or not target.is_naval or target.embarked_in != null:
		return false
	if BattleRequest.friendly(actor.side, target.side) or actor.position.distance_squared_to(target.position) > RANGE * RANGE:
		return false
	return actor._battle_world().actor_visible_to(actor.side, target)

static func sonar(actor, ability, target) -> bool:
	if not valid_ship(actor, target):
		return false
	var rank: int = actor._equipped_card_rank(JAM)
	target.special.sonar_reload_lock = maxf(target.special.get("sonar_reload_lock", 0.0), 2.0 + rank)
	ability.trigger_cooldown()
	return true

static func clock_rate(unit, delta: float) -> float:
	var left: float = unit.special.sonar_reload_lock
	var locked := minf(delta, left)
	left -= locked
	if left <= 0:
		unit.special.erase("sonar_reload_lock")
	else:
		unit.special.sonar_reload_lock = left
	return 1.0 - locked / maxf(delta, 0.000001)

static func divert(target, damage: float, source) -> float:
	if damage <= 0 or not target.is_inside_tree() or not target.get_tree().has_group(GROUP):
		return damage
	var nearest = null
	var distance := pow(2.0 * Ra2Damage.PX_PER_CELL, 2)
	for carrier in target.get_tree().get_nodes_in_group(GROUP):
		if carrier == target or carrier.side != target.side or carrier.passive.get("id") != COVER or not AlliedAbilities.alive(carrier) or carrier.embarked_in != null or carrier._battle_world() != target._battle_world():
			continue
		var gap: float = carrier.position.distance_squared_to(target.position)
		if gap <= distance:
			nearest = carrier
			distance = gap
	if nearest == null:
		return damage
	var rank: int = nearest._equipped_card_rank(COVER)
	var share := damage * [0.04, 0.06, 0.08, 0.10][rank] as float
	var paid := share * (1.0 - [0.05, 0.10, 0.15, 0.20][rank]) as float
	nearest.hp = maxf(0, nearest.hp - paid)
	nearest._hp_flash = 1.0
	nearest.queue_redraw()
	if nearest.hp <= 0:
		nearest._die(source)
	return damage - share

const POINT_CARDS := [JAM,"ap_ivan_trigger","ap_scout_flare"]
const ACTIVES := {JAM:"敌舰正在装填时施放。", "ap_extra_volley":"即将开火时施放。", "ap_chrono_return":"每秒检查一次，恢复剩余超过2秒且3格内至少有3名可攻击自己的敌人时返回。", "ap_ivan_trigger":"炸弹目标周围出现至少两名其他敌人时引爆。", "ap_scout_flare":"行进前方出现迷雾时施放。", "ap_carrier_reserve":"常规飞机已经出击且仍有目标时增派。"}

static func cast(actor, ability, point: Vector2, chosen = null) -> bool:
	var world = actor._battle_world()
	if world == null or not AlliedAbilities.alive(actor) or actor.embarked_in != null or actor._stun_timer > 0: return false
	if AlliedAbilities.frozen(actor) and (ability.id != "ap_chrono_return" or AlliedAbilities.alive(actor.special.get("temporal_by"))): return false
	var rank: int = actor._equipped_card_rank(ability.id)
	var target = chosen
	if point.is_finite() and target == null and ability.id in [JAM,"ap_ivan_trigger"]: target = world.support_order_target(point,false)
	match ability.id:
		JAM: return sonar(actor, ability, target)
		"ap_chrono_return":
			if not actor.special.has("return_window"): return false
			var origin: Vector2 = actor.special.return_origin
			if not actor.logistics.landing_clear(world,origin,actor.radius): return false
			actor.order_stop()
			actor.position = origin
			actor.reset_physics_interpolation()
			actor._last_water_pos = origin
			actor.special.erase("return_window")
			actor.special.erase("chrono_left")
		"ap_extra_volley":
			if actor.special.has("extra_volley"): return false
			actor.special.extra_volley = true
		"ap_ivan_trigger":
			if not AlliedAbilities.alive(target) or not world.actor_visible_to(actor.side,target): return false
			var bomb: Dictionary = target.special.get("ivan_bomb",{})
			if not is_same(bomb.get("owner"),actor): return false
			var fraction := clampf(float(bomb.left) / maxf(0.01,bomb.duration),0,1)
			preload("res://scripts/units/soviet_specials.gd").remove_bomb(target,true,1.0-fraction*(0.6-0.1*rank))
		"ap_scout_flare":
			if world.fog == null or not point.is_finite() or actor.position.distance_to(point)>6.01*Ra2Damage.PX_PER_CELL: return false
			world.fog._reveal(actor.side,point,2*Ra2Damage.PX_PER_CELL,4+rank)
		"ap_carrier_reserve":
			if actor.logistics.squadron.any(func(slot): return slot.has("reserve_left")): return false
			for i in 2: actor.logistics.squadron.append({"unit":null,"timer":0.0,"reserve_left":[10,13,16,20][rank]})
		_: return false
	ability.trigger_cooldown()
	return true

static func automatic(actor, ability, index: int) -> bool:
	const Auto = preload("res://scripts/units/auto_w.gd")
	match ability.id:
		JAM:
			var target = actor.attack_target
			return valid_ship(actor,target) and target._cd_timer>0 and not target.special.has("sonar_reload_lock") and sonar(actor,ability,target)
		"ap_ivan_trigger":
			var target = actor.attack_target
			if not AlliedAbilities.alive(target) or not is_same(target.special.get("ivan_bomb",{}).get("owner"),actor): return false
			if Auto.contacts(actor,target.position,Ra2Damage.PX_PER_CELL).size()>=3: return cast(actor,ability,target.position,target)
		"ap_chrono_return":
			if not actor.special.has("return_window") or float(actor.special.get("chrono_left",0))<=2: return false
			var frame := Engine.get_physics_frames()
			if frame<int(actor.get_meta("chrono_decision_frame",0)): return false
			actor.set_meta("chrono_decision_frame",frame+Engine.physics_ticks_per_second)
			var enemies := 0
			for enemy in Auto.contacts(actor,actor.position,3*Ra2Damage.PX_PER_CELL):
				if enemy is Unit and enemy._weapon_target_valid(actor): enemies+=1
			if enemies>=3: return actor.use_ability(index)
		"ap_extra_volley": return Auto.firing_soon(actor) and actor.use_ability(index)
		"ap_scout_flare":
			var world = actor._battle_world()
			if world.fog == null or not actor.has_move_order: return false
			var point: Vector2 = actor.position.move_toward(actor.move_target,6*Ra2Damage.PX_PER_CELL)
			return not world.fog.is_visible_at(actor.side,point) and actor.use_ability(index,point)
		"ap_carrier_reserve":
			return AlliedAbilities.alive(actor.attack_target) and actor.logistics.squadron.any(func(slot):return AlliedAbilities.alive(slot.unit) and slot.unit.embarked_in==null) and actor.use_ability(index)
	return false

static func rally(unit, delta:float) -> void:
	if not AlliedAbilities.alive(unit) or unit.embarked_in!=null:return
	var left:=float(unit.special.get("rally_wait",0.0))-delta
	unit.special.rally_wait=left
	if left>0:return
	unit.special.rally_wait=1.0
	var world=unit._battle_world()
	if world==null:return
	var ally=null
	var best:=pow(2*Ra2Damage.PX_PER_CELL,2)
	for other in world.units:
		if other==unit or other.side!=unit.side or not AlliedAbilities.alive(other) or other.embarked_in!=null:continue
		var gap:float=other.position.distance_squared_to(unit.position)
		if gap<=best:ally=other;best=gap
	if ally==null:unit.special.rally_alone=int(unit.special.get("rally_alone",0))+1
	else:
		if int(unit.special.get("rally_alone",0))>=8:
			unit.special.rally_block=true
			ally.special.rally_block=true
			unit.special.rally_wait=60-10*unit._equipped_card_rank("ps_rally_guard")
		unit.special.rally_alone=0

static func fleet_setup(unit) -> void:
	var id:String={"LCRF":"fleet_cannon","SAPC":"fleet_rockets","FV":"fv_intercept"}.get(unit.unit_id,"")
	if id.is_empty() or not BattleRequest.has_unit_talent(unit.unit_id,id,unit.side):return
	var value:=Unit.YRTalents.value(unit,id)
	unit.special.fleet_talent=value
	if id=="fv_intercept":
		unit.add_to_group("fleet_interceptors")
		return
	var src:=GameData.get_unit("HTNK" if id=="fleet_cannon" else "V3")
	var gun:=AlliedAbilities.weapon("M60" if id=="fleet_cannon" else "HoverMissile")
	if gun.is_empty():gun=src.get("weapon",{}).duplicate(true)
	gun.damage=18 if id=="fleet_cannon" else 30
	gun.cooldown=2.0 if id=="fleet_cannon" else 4.0
	gun.range=4.0*Ra2Damage.PX_PER_CELL
	gun.burst=int(value) if id=="fleet_cannon" else 1
	gun.ra2_aa=false
	unit.weapon=gun
	unit._ra2_weapon_override=gun
	unit.attack_range=gun.range
	unit.cooldown=gun.cooldown
	unit.can_hit_air=false
	unit.special.fleet_ammo=int(value)

static func fleet_tick(unit,delta:float) -> void:
	if unit.unit_id=="FV":
		if unit.special.has("intercept_left"):unit.special.intercept_left=maxf(0,unit.special.intercept_left-delta)
	elif unit.unit_id=="SAPC" and unit._moving():
		unit.special.fleet_travel=float(unit.special.get("fleet_travel",0))+delta
		if unit.special.fleet_travel>=2:
			unit.special.fleet_travel-=2
			unit.special.fleet_ammo=mini(int(unit.special.fleet_talent),int(unit.special.fleet_ammo)+1)

static func intercept(shot,target) -> bool:
	if not shot.is_inside_tree() or not shot.get_tree().has_group("fleet_interceptors") or BattleRequest.friendly(shot.owner_side,target.side):return false
	for guard in shot.get_tree().get_nodes_in_group("fleet_interceptors"):
		if guard.side!=target.side or not AlliedAbilities.alive(guard) or guard.embarked_in!=null or float(guard.special.get("intercept_left",0))>0:continue
		if guard.position.distance_to(shot.position)>2*Ra2Damage.PX_PER_CELL or guard.position.distance_to(target.position)>2*Ra2Damage.PX_PER_CELL:continue
		guard.special.intercept_left=guard.special.fleet_talent
		Effects.spawn_impact(shot.global_position,Color.LIGHT_CYAN,9)
		shot.queue_free()
		return true
	return false

static func cluster(missile,owner,state:Dictionary) -> void:
	var world=missile._battle_world()
	var nearby:Array=[]
	for unit in world.units:
		if not AlliedAbilities.alive(unit) or BattleRequest.friendly(unit.side,missile.side) or unit.is_air_target() or unit.embarked_in!=null:continue
		if unit.position.distance_to(missile.position)<=2*Ra2Damage.PX_PER_CELL:nearby.append(unit)
	nearby.sort_custom(func(a,b):return a.position.distance_squared_to(missile.position)<b.position.distance_squared_to(missile.position))
	if nearby.size()<2:return
	for i in range(1,mini(nearby.size(),4)):
		var target=nearby[i]
		var damage:=Ra2Damage.target_damage(float(state.damage)*(.15+.05*int(state.cluster_rank)),state.warhead,target,0.0)
		target.receive_hit(CombatMath.with_offense(damage,state.bonus),"rocket",state.bonus,owner,state.warhead)
		Effects.spawn_impact(target.global_position,Color.ORANGE,12)
