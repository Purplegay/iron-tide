extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Mirror=preload("res://scripts/units/mirror_fork.gd")
const SUPPORTED=["ap_peregrine_hunt","ap_tracer_mark","ap_tidal_decoy","ap_seismic_anchor","ap_bomb_nests","ap_ink_mine","ap_mirror_fork","ap_watch_posts","ap_north_twin","ap_spine_crown","ap_anchor_pin","ap_flak_fan","ap_escort_water"]
const HINTS={
	"ap_peregrine_hunt":"已有射程内合法可见敌地面主目标且弹药至少2发时释放，不自动移动追击。",
	"ap_escort_water":"本人最近 2 秒实际受敌伤时施放；保护最近两艘合法友舰，同距优先受伤舰。保持当前指令。",
	"ap_flak_fan":"即将向射程内可见敌机开火时启用扇幕；不为对地攻击或乘客消耗技能。",
	"ap_anchor_pin":"已部署且即将向合法地面载具开火时，立即发射锚钉导弹；不为对空攻击消耗技能。",
	"ap_tracer_mark":"即将对可见地面载具开火，且没有待发曳光或同阵营有效标记时施放。",
	"ap_tidal_decoy":"最近 3 秒受伤且附近有可见海军威胁时施放；潜水期间不重复施放。",
	"ap_seismic_anchor":"已部署炮形态，当前有射程内可见地面目标时在目标处施放；不自动部署。",
	"ap_bomb_nests":"正在飞行，脚下附近有可见地面敌人时投放；停止攻击状态下不自动施放。",
	"ap_ink_mine":"未被巨型乌贼缠绕，附近有可见水面敌舰时在当前位置布雷。",
	"ap_mirror_fork":"即将开火，或最近受伤且正在移动时召唤镜像；再次 W 转移引爆保持手动。",
	"ap_watch_posts":"即将开火且附近没有存活哨位时召唤，不在赶路或空闲时消耗冷却。",
	"ap_north_twin":"即将开火且没有存活双星时召唤；再次 W 交换位置保持手动。",
	"ap_spine_crown":"当前有 6 格内可见地面目标，且装甲块已满或生命不低于 70% 时施放，低血量保留装甲。",
}

static func ground_target(actor,target,reach:float) -> bool:
	if not R.enemy(actor,target) or not (target is Unit or target is Building):return false
	if target is Unit and (target.is_air_target() or target.embarked_in!=null):return false
	return R.world(actor).actor_visible_to(actor.side,target) and actor.position.distance_to(R.point(actor,target))<=reach

static func evaluate(actor,index:int,hurt:bool,can_fire:bool,enemies:Array) -> bool:
	var ability:Ability=actor.ability_at(index)
	var id:=ability.id
	var state:Dictionary=actor.special.get(R.KEY,{})
	var target=actor.attack_target
	var offensive:bool=actor.fire_stance!="none" or actor.attack_ordered
	var trigger:=false
	match id:
		"ap_peregrine_hunt":
			if offensive and preload("res://scripts/units/peregrine_cards.gd").target_in_range(actor,target):return actor.use_ability(index,R.point(actor,target))
		"ap_escort_water":trigger=float(actor.special.get("progression_v2",{}).get("water_hit",0))>0
		"ap_flak_fan":
			trigger=can_fire and target is Unit and target.is_air_target() and not actor.special.get("progression_v2",{}).has("flak_arm")
		"ap_anchor_pin":
			# firing_soon already checks visibility and the target-specific deployed weapon range.
			trigger=can_fire and actor.is_deployed() and target is Unit and not target.is_air_target() and not AlliedAbilities.infantry(target) and not target.is_naval
		"ap_tracer_mark":
			if not can_fire or state.has("tracer_arm") or not target is Unit or AlliedAbilities.infantry(target) or target.is_air_target():return false
			var mark:Dictionary=target.special.get(R.KEY,{}).get("mark",{})
			trigger=mark.is_empty() or float(mark.get("left",0))<=0 or int(mark.get("charges",0))<=0 or mark.get("side")!=actor.side
		"ap_tidal_decoy":
			trigger=hurt and not state.has("dive") and enemies.any(func(e):return e is Unit and e.is_naval)
		"ap_seismic_anchor":
			if offensive and actor._deployed and not actor.special.has("siege_progress") and actor.logistics.air_lift<=.001 and ground_target(actor,target,actor.attack_range):return actor.use_ability(index,R.point(actor,target))
		"ap_bomb_nests":
			trigger=offensive and actor.is_air_target() and not state.has("nests") and enemies.any(func(e):return actor.position.distance_to(R.point(actor,e))<=R.CELL)
		"ap_ink_mine":
			trigger=offensive and not AlliedAbilities.alive(actor.special.get("squid")) and enemies.any(func(e):return e is Unit and e.is_naval and not NavalContact.submerged(e) and actor.position.distance_to(e.position)<=R.CELL)
		"ap_mirror_fork":
			trigger=Mirror.living(actor).is_empty() and (can_fire or (hurt and actor.has_move_order and actor._moving()))
		"ap_watch_posts":
			trigger=can_fire and not state.get("posts",[]).any(AlliedAbilities.alive)
		"ap_north_twin":
			trigger=can_fire and not AlliedAbilities.alive(state.get("twin"))
		"ap_spine_crown":
			var full:bool=actor.passive.get("id")=="ps_spine_scrap" and state.get("scrap",[]).size()>=int(R.value(actor,"ps_spine_scrap","count"))
			if offensive and not state.has("crown") and (full or actor.hp>=actor.max_hp*.7) and ground_target(actor,target,6*R.CELL):return actor.use_ability(index,R.point(actor,target))
	return actor.use_ability(index) if trigger else false
