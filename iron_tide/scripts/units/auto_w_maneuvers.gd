extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const P=preload("res://scripts/rules/progression_parameters.gd")
const Drone=preload("res://scripts/units/expansion_2_drone.gd")
const SUPPORTED=["ap_buoy","ap_lure_pounce","ap_battle_breather"]
const HINTS={
	"ap_buoy":"向投放范围内当前已发现的敌方潜艇投放，优先当前目标，其次最近目标；不读取未发现潜艇位置，不替换仍有效的浮标。",
	"ap_lure_pounce":"仅跟随明确的载具攻击命令，在接近目标、加速能及时发挥作用时开启；不自动挑选目标或改变路线。",
	"ap_battle_breather":"最近3秒受伤，正在按普通移动命令远离可见攻击者时加速撤退；攻击移动、继续交战、站立或部署时不触发。",
}

static func submarine(actor,target) -> bool:
	if not R.enemy(actor,target) or not NavalContact.underwater_type(target) or target.embarked_in!=null:return false
	var world=R.world(actor)
	# Visibility must be established before consulting a candidate's coordinates.
	if not world.actor_visible_to(actor.side,target,actor):return false
	return actor.position.distance_to(target.position)<=P.number("mechanic/faction","buoy_range") and world.on_water(target.position)

static func buoy(actor,index:int,contacts:Array) -> bool:
	if float(actor.special.get("buoy_left",0))>0:return false
	var target=actor.attack_target
	if not submarine(actor,target):
		target=null
		for candidate in contacts:
			if not submarine(actor,candidate):continue
			if target==null or actor.position.distance_squared_to(candidate.position)<actor.position.distance_squared_to(target.position):target=candidate
	return actor.use_ability(index,target.position) if target!=null else false

static func evaluate(actor,index:int,hurt:bool,contacts:Array) -> bool:
	match actor.ability_at(index).id:
		"ap_buoy":return buoy(actor,index,contacts)
		"ap_lure_pounce":
			if not actor.attack_ordered or actor.attack_move or not Drone.ready(actor):return false
			var reach:float=P.number("mechanic/drone_v2","guard_range")*R.CELL+actor.move_speed*(1.0+R.value(actor,Drone.ACTIVE,"speed"))*P.number("mechanic/drone_v2","pounce_duration")*.5
			return actor.use_ability(index) if actor.position.distance_to(actor.attack_target.position)<=reach else false
		"ap_battle_breather":
			if not hurt or actor.hp>=actor.max_hp or not actor.has_move_order or not actor._moving() or actor.attack_move or actor.attack_ordered or actor.is_deployed():return false
			if float(actor.special.get("progression_v2",{}).get("breather_left",0))>0:return false
			var attacker=actor.special.get("auto_w_attacker")
			if not R.enemy(actor,attacker) or not R.world(actor).actor_visible_to(actor.side,attacker):return false
			var away:Vector2=attacker.position.direction_to(actor.position)
			if away.is_zero_approx() or away.dot(actor.position.direction_to(actor.move_target))<=.25 or away.dot(actor.velocity.normalized())<=.25:return false
			return actor.use_ability(index)
	return false
