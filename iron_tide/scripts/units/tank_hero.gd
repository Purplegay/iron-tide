extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Extension heroes. All persistent combat state lives in actor.special/allied_state.
const IDS := ["MTNK", "HTNK"]
const FACTORIES := {"GAWEAP":"MTNK", "NAWEAP":"HTNK"}
const CELL := 55.0
static var AIR_DAMAGE_SCALE:float:
	get:return P.number("hero/tank/survival","air_damage")
static var REVIVE_SECONDS:float:
	get:return P.number("hero/tank/command","revive_seconds")
static var WRECK_HEALTH:float:
	get:return P.number("hero/tank/command","wreck_health")
static var WRECK_START_FRACTION:float:
	get:return P.number("hero/tank/command","wreck_initial")
const Shield = preload("res://scripts/units/tank_hero_shield.gd")
const COMMAND_DEFAULT = [
	"自身射程内反潜；首次出场同时侦察每个敌对参战方的基地，半径 6 格、持续 5 秒，随后自然回雾",
	"每局仅一次：残骸上限为倒下前生命上限的 150%，初始 50% 血，15 秒内缓慢恢复至满血；受击会降低最终血量，被毁无法复活。15 秒后按剩余血量比例复活，永久生命上限 -50%、攻击力 -30%、移速 +15%、视野 +1 格；再次同时侦察每个敌对参战方的基地，半径 9 格（原 6 格 +3）、持续 10 秒",
	"射程内友军的基础行驶速度至少达到英雄自身速度；部署、冻结等行动限制仍然有效",
	"射程内已部署友军射程 +2 格，不包含自身；同类光环不叠加",
]
static var COMMAND:Array:
	get:return P.traits("hero/tank/command",COMMAND_DEFAULT)
const DEFENSE_DEFAULT = [
	Shield.DESCRIPTION,
	"恐怖机器人寄生伤害降低 90%，寄生不再使车体侧翻",
	"额外视野 +3 格",
	"免疫碾压；生化、辐射伤害降低 30%",
	"冻结改为移动与开火速度降低 50%，超时空军团兵不能擦除",
	"主炮可对空，对空伤害为正常的 50%；爆炸致命一击最多扣除 2/3 最大生命，低血量仍可能阵亡",
]
static var DEFENSE:Array:
	get:return P.traits("hero/tank/survival",DEFENSE_DEFAULT)

static func active(unit) -> bool:
	return unit.special.get("academy_hero","") in IDS

static func rank(unit,defense:=false) -> int:
	if not active(unit) or unit.special.has("hero_wreck"):return -1
	return int(unit.special.get("hero_survival_rank" if defense else "hero_command_rank",0))

static func cold(unit) -> bool:
	return rank(unit,true)>=4 and (float(unit.special.get("chrono_left",0))>0 or AlliedAbilities.alive(unit.special.get("temporal_by")))

static func speed(unit: Unit,base:float) -> float:
	var state: Dictionary=unit.special
	if state.has("hero_wreck") or unit._deployed:return 0.0
	var result := maxf(base,float(state.get("hero_speed_floor",0)))
	# This runs for every ordinary unit too. Resolve the same live hero gate
	# here instead of walking speed -> cold -> rank -> active on every tick.
	if state.get("academy_hero","") not in IDS or int(state.get("hero_survival_rank",0))<4:return result
	return result*(P.number("hero/tank/survival","frozen_speed") if float(state.get("chrono_left",0))>0 or AlliedAbilities.alive(state.get("temporal_by")) else 1.0)

static func defend(unit,damage:float,warhead:String,attack_type:String,source) -> float:
	var level:=rank(unit,true)
	if level<1:return damage
	var wh:=warhead.trim_prefix("YR_SOV_").trim_prefix("YR_CAP_")
	if wh=="Parasite" and is_instance_valid(source) and source==unit.special.get("parasite"):damage*=P.number("hero/tank/survival","parasite_damage")
	if level>=3 and wh in ["Gas","Virus","RadBeamWarhead","RadEruptionWarhead","RadSite"]:damage*=P.number("hero/tank/survival","toxic_damage")
	if level>=5 and damage>=unit.hp and (attack_type in ["explosion","explosive","shell","missile"] or wh in ["TerrorBombWH","CRTerrorBombWH","DemobombWH","HE","HowitzerWH","Nuke"]):damage=minf(damage,unit.max_hp*P.number("hero/tank/survival","lethal_cap"))
	return damage

static func begin_wreck(unit) -> bool:
	if not active(unit):return false
	Shield.clear(unit)
	migrate_revival(unit)
	if unit.special.has("hero_wreck"):
		unit.special.erase("hero_wreck")
		return false
	if rank(unit)<1 or revival_used(unit):return false
	mark_revival_used(unit)
	unit.order_stop()
	unit.velocity=Vector2.ZERO
	Unit.SovietWeapons.cleanse(unit)
	var owner=unit.special.get("temporal_by")
	if AlliedAbilities.alive(owner):AlliedAbilities.release_temporal(owner)
	unit.special.hero_wreck={"left":REVIVE_SECONDS,"health":unit.max_hp,"name":unit.display_name,"sight":unit.sight,"rules":2}
	unit.max_hp*=WRECK_HEALTH
	unit.hp=unit.max_hp*WRECK_START_FRACTION
	unit.sight=0
	unit.move_speed=0
	unit.attack_range=0
	unit.modulate=Color(0.45,0.4,0.35)
	unit.display_name="%s · 复苏残骸" % unit.special.hero_wreck.name
	unit._refresh_weapon_derived()
	unit.queue_redraw()
	return true

static func tick(unit,delta:float) -> bool:
	if not active(unit):return false
	migrate_revival(unit)
	Shield.tick(unit,delta)
	if not unit.special.has("hero_wreck"):
		var slowed:=cold(unit)
		if slowed!=bool(unit.special.get("hero_cold",false)):
			unit.special.hero_cold=slowed
			unit._recompute_bonuses()
		return false
	var wreck:Dictionary=unit.special.hero_wreck
	unit.modulate=Color(0.45,0.4,0.35)
	# Fixed recovery budget: damage is never overwritten by a timer-derived HP.
	var recovery_time:=minf(maxf(delta,0),maxf(0,float(wreck.left)))
	unit.hp=minf(unit.max_hp,unit.hp+unit.max_hp*(1.0-WRECK_START_FRACTION)*recovery_time/REVIVE_SECONDS)
	wreck.left-=delta
	unit.display_name="%s · 复苏残骸 %d%% · %d 秒" % [wreck.name,roundi(unit.hp/unit.max_hp*100),ceili(maxf(0,wreck.left))]
	unit.velocity=Vector2.ZERO
	if wreck.left>0:return true
	var fraction:=clampf(unit.hp/unit.max_hp,0,1)
	unit.max_hp=wreck.health
	unit.hp=unit.max_hp*fraction
	unit.display_name=wreck.name
	unit.sight=wreck.sight
	unit.modulate=Color.WHITE
	unit.special.erase("hero_wreck")
	apply_rebirth(unit)
	unit.order_stop()
	unit._recompute_bonuses()
	unit._refresh_weapon_derived()
	var world=unit._battle_world()
	if world!=null:scout(unit,world,true)
	Effects.spawn_text(unit.art_center(),"复苏 · 本局已用",Color.CYAN)
	return true

static func revival_preview(progress:float) -> Dictionary:
	var recovery:=clampf(progress,0,1)
	return {
		"title":"每局一次 · %d%% 耐久残骸 · %d%% 血量开始恢复" % [roundi(WRECK_HEALTH*100),roundi(WRECK_START_FRACTION*100)],
		"fraction":lerpf(WRECK_START_FRACTION,1.0,recovery),
		"left":REVIVE_SECONDS*(1.0-recovery),
	}

static func revival_used(unit) -> bool:
	if unit.special.get("hero_revive_used",false):return true
	var world=unit._battle_world()
	return world!=null and world.allied_state.get("hero_revives_used",{}).has(unit.side+":"+unit.unit_id)

static func mark_revival_used(unit) -> void:
	unit.special.hero_revive_used=true
	var world=unit._battle_world()
	if world!=null:world.allied_state.get_or_add("hero_revives_used",{})[unit.side+":"+unit.unit_id]=true

static func apply_rebirth(unit) -> void:
	if unit.special.get("hero_reborn",false):return
	unit.special.hero_reborn=true
	unit._base_max_hp*=P.number("hero/tank/command","rebirth_health")
	unit.max_hp*=P.number("hero/tank/command","rebirth_health")
	unit.hp=minf(unit.max_hp,unit.hp*P.number("hero/tank/command","rebirth_health"))
	unit._base_atk*=P.number("hero/tank/command","rebirth_attack")
	unit._base_speed*=P.number("hero/tank/command","rebirth_speed")
	unit.sight+=P.number("hero/tank/command","rebirth_sight")*CELL
	unit.display_name+=" · 复苏（本局已用）"
	unit._recompute_bonuses()

static func migrate_revival(unit) -> void:
	if unit.special.has("hero_wreck"):
		var wreck:Dictionary=unit.special.hero_wreck
		if int(wreck.get("rules",0))>=2:return
		var fraction:=clampf(unit.hp/maxf(unit.max_hp,1),0,1)
		unit.max_hp=float(wreck.health)*WRECK_HEALTH
		unit.hp=unit.max_hp*fraction
		wreck.rules=2
		mark_revival_used(unit)
	elif unit.special.has("hero_revive_cd"):
		# The old zero-valued cooldown also means this hero already revived.
		unit.special.erase("hero_revive_cd")
		mark_revival_used(unit)
		apply_rebirth(unit)

static func scout(unit, world, reborn := false) -> void:
	var radius := (P.number("hero/tank/command","revive_scout_radius") if reborn else P.number("hero/tank/command","scout_radius")) * CELL
	var duration := P.number("hero/tank/command","revive_scout_seconds") if reborn else P.number("hero/tank/command","scout_seconds")
	var revealed := {}
	var fallback := {}
	for building in world.buildings:
		if not world.actor_alive(building) or not BattleRequest.is_house(building.side) or BattleRequest.friendly(building.side, unit.side): continue
		if building.is_hq or building.building_id == "swarm_hive":
			mark_scout_site(world, unit.side, building.global_position, radius, duration)
			revealed[building.side] = true
		else:
			var tags: Array = building.data.get("tags", [])
			if not fallback.has(building.side) and not tags.has("civilian") and not tags.has("defense"):
				fallback[building.side] = building
	# A packed construction yard is still a base. Use its current position, and
	# keep the reveal stationary if the vehicle subsequently drives away.
	for vehicle in world.units:
		if not world.actor_alive(vehicle) or vehicle.embarked_in != null or revealed.has(vehicle.side): continue
		if not BattleRequest.is_house(vehicle.side) or BattleRequest.friendly(vehicle.side, unit.side): continue
		if vehicle.deploy_building_id() not in ["GACNST", "NACNST", "YACNST"]: continue
		mark_scout_site(world, unit.side, vehicle.global_position, radius, duration)
		revealed[vehicle.side] = true
	for side in fallback:
		if not revealed.has(side):
			mark_scout_site(world, unit.side, fallback[side].global_position, radius, duration)

static func mark_scout_site(world, observer: String, point: Vector2, radius: float, duration: float) -> void:
	if world.fog != null:
		world.fog._reveal(observer, point, radius, duration)
	if BattleRequest.friendly(observer, "ally"):
		# Store the surveyed point, not the vehicle. Loading resumes only the remaining time.
		var marks: Dictionary = world.allied_state.get_or_add("hero_scout_marks", {})
		marks[point] = maxf(duration, float(marks.get(point, 0.0)))

static func tick_scout_marks(world, delta: float) -> void:
	var marks: Dictionary = world.allied_state.get("hero_scout_marks", {})
	for point in marks.keys():
		marks[point] -= delta
		if marks[point] <= 0.0: marks.erase(point)
	if marks.is_empty(): world.allied_state.erase("hero_scout_marks")

static func tick_world(world,delta:float) -> void:
	if world.paused or world.ended or world.get_tree().paused:return
	if world.allied_state.has("hero_scout_marks"): tick_scout_marks(world, delta)
	world.allied_state.hero_tank_scan=float(world.allied_state.get("hero_tank_scan",0))-delta
	if world.allied_state.hero_tank_scan>0:return
	world.allied_state.hero_tank_scan=0.25
	if MetaProgress.Academy.eligible(world) and BattleRequest.extensions_enabled() and BattleRequest.combat_context.get("expedition",{}).is_empty():
		for factory in world.buildings:
			if not world.actor_alive(factory) or factory.side!="ally" or factory.under_construction or not FACTORIES.has(factory.building_id):continue
			var id:String=FACTORIES[factory.building_id]
			if world.allied_state.get("named_heroes",{}).has(id) or MetaProgress.Academy.hero_build_count(MetaProgress,id)<20:continue
			var point:Vector2=factory._spawn_point(id)
			if point==Vector2.INF:continue
			var hero=world.spawn_unit(id,"ally",point,factory)
			MetaProgress.Academy.promote(MetaProgress,world,id,hero)
			scout(hero,world)
	var deployed:Dictionary=world.allied_state.get("named_heroes",{})
	if not deployed.has("MTNK") and not deployed.has("HTNK"):return
	var heroes:Array=[]
	for unit in world.units:
		if world.actor_alive(unit) and active(unit) and not unit.is_in_group(NavalContact.sensor_group(unit.side)):unit.add_to_group(NavalContact.sensor_group(unit.side))
		if world.actor_alive(unit) and rank(unit)>=2 and unit.embarked_in==null:heroes.append(unit)
	for unit in world.units:
		if not world.actor_alive(unit):continue
		var floor_speed:=0.0
		var extra:=0.0
		for hero in heroes:
			if hero==unit or not BattleRequest.friendly(hero.side,unit.side) or unit.embarked_in!=null:continue
			if hero.position.distance_squared_to(unit.position)>hero.attack_range*hero.attack_range:continue
			# Never read another aura's raised speed: two heroes cannot amplify one another.
			var native:float=hero._base_speed*hero.buff_mult_scalar("speed")*(P.number("hero/tank/survival","frozen_speed") if cold(hero) else 1.0)
			native*=1.0+float(hero.special.get("slope_speed",0))
			floor_speed=maxf(floor_speed,native)
			if rank(hero)>=3 and unit._deployed:extra=P.number("hero/tank/command","range_aura")*CELL
		if not is_equal_approx(float(unit.special.get("hero_speed_floor",0)),floor_speed):
			if floor_speed>0:unit.special.hero_speed_floor=floor_speed
			else:unit.special.erase("hero_speed_floor")
			unit._recompute_bonuses()
		if not is_equal_approx(float(unit.special.get("hero_range_aura",0)),extra):
			if extra>0:unit.special.hero_range_aura=extra
			else:unit.special.erase("hero_range_aura")
			unit._refresh_weapon_derived()
	# Reaper's deployed form is a Building with a private Unit weapon mount.
	for building in world.buildings:
		if building.building_id!="R3REAPERTURRET" or not world.actor_alive(building):continue
		var extra:=0.0
		for hero in heroes:
			if rank(hero)>=3 and hero.side==building.side and hero.position.distance_squared_to(building.position)<=hero.attack_range*hero.attack_range:extra=P.number("hero/tank/command","range_aura")*CELL
		if is_equal_approx(float(building.special.get("hero_range_aura",0)),extra):continue
		if extra>0:building.special.hero_range_aura=extra
		else:building.special.erase("hero_range_aura")
		building.attack_range=float(building.weapon.get("range",0))+extra
		var mount=building.get_node_or_null("ReaperMount")
		if mount!=null:mount._refresh_weapon_derived()
