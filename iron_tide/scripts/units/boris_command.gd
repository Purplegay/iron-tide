extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const Sortie=preload("res://scripts/units/boris_sortie.gd")
const KEY="boris_command"
const WAVES="boris_command_waves"
const COMMAND_DEFAULT = [
	"前沿观察：本人视野增加 1 格，不增加步枪和空袭标定距离。",
	"步枪压制：连续三次步枪直击同一敌步兵或战斗地面载具，令其停止开火 1 秒、仍可移动；目标共用 8 秒间隔，不取消已发弹药。",
	"空地接力：本人米格第一枚炸弹实际命中后，落点 3 格内最近最多四名同方真实步兵各获得一次普通武器装填时长减半，资格保存 5 秒，每支编队一次。",
	"独立引导：米格出发后可离开标定位置移动、使用步枪；既定敌建筑回到迷雾仍可攻击，不揭雾。整队离场或被击落后才开始下一轮补充。",
	"集火口令：步枪命中敌作战单位后标记 4 秒，接下来最多三次同方非英雄步兵普通直击增伤 15%；间隔 12 秒，本人不消耗，不揭雾。",
	"双目标空袭：主编队照常轰炸，主建筑 3 格内最近合法可见副建筑额外受到原生数量一半（向下取整）的米格攻击。三星为主 4 副 2；无副目标不增派，共用校射、接力与整队冷却。"
]
static var COMMAND:Array:
	get:return P.traits("hero/BORIS/command",COMMAND_DEFAULT)

static func state(unit) -> Dictionary:
	if unit.special.has(KEY) and unit.special[KEY].side!=unit.side:unit.special.erase(KEY)
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.is_empty():return
	if unit.side!=s.side or not BattleRequest.extensions_enabled():unit.special.erase(KEY);return
	for key in ["suppressed","suppression_cd","focus_cd"]:R.timer(s,key,dt)
	for key in ["relay","focus"]:
		if not s.has(key):continue
		s[key].left-=dt
		if s[key].left<=0:s.erase(key)

static func suppressed(unit) -> bool:
	return BattleRequest.extensions_enabled() and float(unit.special.get(KEY,{}).get("suppressed",0))>0

static func direct(source,target,bonus:Dictionary) -> bool:
	if bonus.get("expansion_extra",false) or bonus.get("expansion_scatter",false) or bonus.get("equipment_secondary",false):return false
	return not source is Projectile or is_same(source.target,target)

static func combatant(target) -> bool:
	return target is Unit and R.active(target) and target.embarked_in==null and target.unit_id not in ["V3ROCKET","DMISL"] and (AlliedAbilities.infantry(target) or float(target.weapon.get("damage",0))>0)

static func rifle_hit(target,source,amount:float,bonus:Dictionary) -> void:
	var unit=R.owner(source)
	if amount<=0 or Sortie.rank(unit)<1 or not R.enemy(unit,target) or not direct(source,target,bonus):return
	var weapon:=str(bonus.get("impact_weapon","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	if weapon not in ["AKM","AKME"]:return
	var s:=state(unit)
	if not combatant(target):s.erase("streak_target");s.erase("streak");return
	s.streak=int(s.get("streak",0))+1 if is_same(s.get("streak_target"),target) else 1
	s.streak_target=target
	if target.is_air_target() or target.is_naval:s.streak=0
	if s.streak>=P.count("hero/BORIS/command","rifle_hits"):
		s.streak=0
		var victim:=state(target)
		if not victim.has("suppression_cd"):
			victim.suppressed=P.number("hero/BORIS/command","suppress_seconds");victim.suppression_cd=P.number("hero/BORIS/command","suppress_cooldown")
			target._cancel_burst();target.queue_redraw()
	if Sortie.rank(unit)>=4 and not s.has("focus_cd"):
		state(target).focus={"left":P.number("hero/BORIS/command","focus_seconds"),"charges":P.count("hero/BORIS/command","focus_charges"),"side":unit.side,"owner":unit}
		s.focus_cd=P.number("hero/BORIS/command","focus_cooldown");target.queue_redraw()

static func modify_reload(unit,seconds:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("relay") or s.side!=unit.side or not AlliedAbilities.infantry(unit):return seconds
	if unit.unit_id=="BORIS" and unit.attack_target is Building:return seconds
	s.erase("relay");unit.queue_redraw()
	return seconds*P.number("hero/BORIS/command","relay_reload")

static func impact(target,source,amount:float,bonus:Dictionary) -> float:
	if amount<=0:return amount
	rifle_hit(target,source,amount,bonus)
	if bonus.has("boris_wave"):relay(target,source,bonus)
	if not target is Unit or not target.special.has(KEY):return amount
	var s:Dictionary=target.special[KEY]
	if not s.has("focus") or s.side!=target.side or not direct(source,target,bonus):return amount
	var actor=R.owner(source)
	if not actor is Unit or not R.active(actor) or not AlliedAbilities.infantry(actor) or actor.special.has("academy_hero") or actor.side!=s.focus.side or not R.enemy(actor,target):return amount
	if not bonus.has("expansion_origin") or bonus.get("boris_mig",false):return amount
	s.focus.charges-=1
	if s.focus.charges<=0:s.erase("focus")
	target.queue_redraw()
	return amount*P.number("hero/BORIS/command","focus_damage")

static func dispatched(unit,jets:Array) -> void:
	var relay_enabled:=Sortie.rank(unit)>=2
	var supply_enabled:=preload("res://scripts/units/boris_radio.gd").rank(unit)>=3
	if (not relay_enabled and not supply_enabled) or jets.is_empty():return
	var world=R.world(unit)
	var serial:=int(world.allied_state.get("boris_wave_serial",0))+1
	world.allied_state.boris_wave_serial=serial
	world.allied_state.get_or_add(WAVES,[]).append({"id":serial,"side":unit.side,"jets":jets,"shots":[],"relayed":false,"relay_enabled":relay_enabled,"supply_enabled":supply_enabled,"supplied":false})
	for jet in jets:jet.special.strike_run.boris_wave=serial

static func prepare_mig(shot,jet) -> void:
	var serial:=int(jet.special.strike_run.get("boris_wave",0))
	if serial==0:return
	shot.attacker_bonus.boris_wave=serial
	for wave in R.world(jet).allied_state.get(WAVES,[]):
		if wave.id==serial:wave.shots.append(shot);return

static func relay(target,source,bonus:Dictionary) -> void:
	if not source is Projectile or not AlliedAbilities.alive(target):return
	var world=R.world(target)
	for wave in world.allied_state.get(WAVES,[]):
		if wave.id!=bonus.boris_wave:continue
		if wave.relayed or not wave.relay_enabled:return
		if wave.side!=source.owner_side or target.side=="neutral" or BattleRequest.friendly(wave.side,target.side) or world.house_defeated(wave.side):return
		wave.relayed=true
		var candidates:Array=[]
		for unit in world.units:
			if not R.active(unit) or unit.side!=wave.side or not AlliedAbilities.infantry(unit) or unit.embarked_in!=null:continue
			if unit.position.distance_to(source.target_point)<=P.number("hero/BORIS/command","relay_radius")*R.CELL:candidates.append(unit)
		candidates.sort_custom(func(a,b):return a.position.distance_squared_to(source.target_point)<b.position.distance_squared_to(source.target_point))
		for unit in candidates.slice(0,P.count("hero/BORIS/command","relay_targets")):state(unit).relay={"left":P.number("hero/BORIS/command","relay_seconds")};unit.queue_redraw()
		return

static func world_tick(world) -> void:
	if not world.allied_state.has(WAVES):return
	var waves:Array=world.allied_state[WAVES]
	for wave in waves.duplicate():
		var flying:bool=wave.jets.any(func(jet):return AlliedAbilities.alive(jet))
		var ammunition:bool=wave.shots.any(func(shot):return is_instance_valid(shot) and not shot.is_queued_for_deletion())
		if world.house_defeated(wave.side) or (not flying and not ammunition):waves.erase(wave)
	if waves.is_empty():world.allied_state.erase(WAVES)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[]
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("suppressed"):rows.append(V.row("步枪压制 · 停止开火，可移动",s.suppressed,true,"hourglass"))
	if s.has("relay"):rows.append(V.row("空地接力 · 下次普通装填减半",s.relay.left,false,"reload"))
	if s.has("focus"):rows.append(V.row("集火口令 · 剩余 %d 次直击增伤"%s.focus.charges,s.focus.left,true,"focus"))
	if s.has("focus_cd"):rows.append(V.row("集火口令冷却",s.focus_cd,false,"reload"))
	if Sortie.independent(unit) and unit.special.has("airstrike_wing"):
		var count:=0
		for jet in unit.special.airstrike_wing:
			if AlliedAbilities.alive(jet):count+=1
		rows.append(V.row("独立引导 · 剩余 %d 架占用本轮"%count,0,false,"air"))
	return rows
