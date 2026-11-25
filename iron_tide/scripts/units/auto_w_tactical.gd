extends RefCounted
## Uses the current visible target only; never creates movement or deployment orders.
const R=preload("res://scripts/units/expansion_rules.gd")
const P=preload("res://scripts/rules/progression_parameters.gd")
const Overload=preload("res://scripts/units/expansion_2_overload.gd")
const Tractor=preload("res://scripts/units/expansion_2_tractor.gd")
const SUPPORTED=["ap_tanya_breach","ap_boris_corridor","ap_leizhu_court","ap_prism_cross","ap_overload_seal","ap_tractor_warhead","ap_gun_ballast","ap_observer_line"]
const HINTS={
	"ap_tanya_breach":"停稳且没有移动命令时，向技能范围内当前可见、停稳的地面目标投掷；不预测移动目标或自动追击。",
	"ap_boris_corridor":"停稳且没有移动命令时，向当前可见、停稳的地面目标呼叫走廊；全部落点必须合法，不自动追击。",
	"ap_leizhu_court":"停稳且没有移动命令时，围绕技能范围内当前可见、停稳的地面目标布置电庭；全部电极落点必须合法。",
	"ap_prism_cross":"停稳且没有移动命令时，向射程内当前可见、停稳的地面目标释放十字；不预测移动目标。",
	"ap_overload_seal":"停稳时，对当前可见、正在瞄准我方单位的武装载具或防御建筑施加封条；不重复覆盖现有封条。",
	"ap_tractor_warhead":"停稳且即将对可见地面目标开火时装填牵引弹头；直升机须已部署，不自动切换形态。",
	"ap_gun_ballast":"没有移动命令、舰船停稳、生命至少70%，且即将向可见目标开火时压舱；不改变航路。",
	"ap_observer_line":"没有移动命令、停稳且即将向可见目标开火时开始观察；观察有效期间不重复施放。",
}

static func stationary(actor) -> bool:
	return actor is Building or (actor is Unit and not actor.has_move_order and not actor._moving() and actor.velocity.length_squared()<=1)

static func ground_target(actor,target,reach:float) -> bool:
	if not R.enemy(actor,target) or R.temporary(target):return false
	if target is Unit and (target.is_air_target() or target.is_naval or target.embarked_in!=null or target.special.has("para_height") or AlliedAbilities.concealed(target,actor.side)):return false
	return R.world(actor).actor_visible_to(actor.side,target) and actor.position.distance_to(R.point(actor,target))<=reach

static func evaluate(actor,index:int,can_fire:bool) -> bool:
	if not stationary(actor) or (actor.fire_stance=="none" and not actor.attack_ordered):return false
	var id:String=actor.ability_at(index).id
	var target=actor.attack_target
	var state:Dictionary=actor.special.get("progression_v2",{})
	match id:
		"ap_gun_ballast":
			return actor.use_ability(index) if can_fire and actor.hp>=actor.max_hp*.7 else false
		"ap_observer_line":
			return actor.use_ability(index) if can_fire and not state.has("observer_left") else false
		"ap_tractor_warhead":
			return actor.use_ability(index) if can_fire and Tractor.ready(actor) and ground_target(actor,target,actor.attack_range) else false
		"ap_overload_seal":
			if not Overload.available(actor,target):return false
			var victim=target.attack_target
			if not AlliedAbilities.alive(victim) or not BattleRequest.friendly(actor.side,victim.side):return false
			if target is Building and not target.is_operational():return false
			if target is Unit and (target._stun_timer>0 or AlliedAbilities.frozen(target) or (target.fire_stance=="none" and not target.attack_ordered)):return false
			return actor.use_ability(index)
	var reach:float=actor.attack_range
	match id:
		"ap_tanya_breach":reach=P.number("mechanic/ap_tanya_breach","cast_range")*R.CELL
		"ap_boris_corridor":reach=P.number("mechanic/ap_boris_corridor","range")*R.CELL
		"ap_leizhu_court":reach=P.number("mechanic/ap_leizhu_court","range")*R.CELL
	if not ground_target(actor,target,reach) or not stationary(target):return false
	return actor.use_ability(index,R.point(actor,target))
