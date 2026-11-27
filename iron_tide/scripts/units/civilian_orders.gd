extends RefCounted
const Rules = preload("res://scripts/world/special_rules.gd")
const Sites = preload("res://scripts/world/civilian_sites.gd")

static func slots(building) -> int:
	return int(building.data.get("garrison_slots", 0))

static func civilian_garrison(building) -> bool:
	return building is Building and slots(building) > 0 and (building.building_id == "CAHSE01" or "civilian" in building.data.get("tags", []))

static func can_enter(unit, target) -> bool:
	if not target is Building or slots(target) == 0 or unit.embarked_in != null: return false
	var neutral_house: bool = civilian_garrison(target) and target.side == "neutral"
	if target.side != unit.side and not neutral_house: return false
	var native := preload("res://scripts/core/yr_death_rules.gd").type_data(unit.unit_id)
	var eligible := AlliedAbilities.infantry(unit) and (AlliedAbilities.flag(unit,"Occupier") or str(native.get("occupier","no")).to_lower() == "yes")
	if target.data.has("extra_power"):
		return AlliedAbilities.infantry(unit) and float(native.get("size",1)) <= float(target.data.size_limit) and target.is_operational() and target.special.get("occupants",[]).size() < slots(target)
	if target.building_id == "NATBNK": eligible = unit.unit_id == "LTNK" or unit.unit_id=="TTNK" and BattleRequest.mission_id=="yr_head_games"
	return eligible \
		and target.is_operational() and target.hp > target.max_hp * 0.25 and target.special.get("occupants", []).size() < slots(target)

static func can_repair(unit, target) -> bool:
	return unit.unit_id in ["ENGINEER", "SENGINEER", "YENGINEER"] and target is Building and target.building_id == "CABHUT" \
		and target.special.has("bridge_span") and not target.special.get("bridge_repaired", false)

static func enter(unit, target) -> void:
	if not can_enter(unit, target): return
	if target.side == "neutral": AlliedAbilities.change_side(target, unit.side)
	unit.order_stop()
	unit.set_stowed(target)
	if not target.special.has("occupants"): target.special.occupants = []
	target.special.occupants.append(unit)
	target.queue_redraw()
	unit.position = target.position
	target.battle._emit_selection()

static func withdraw(building, unit) -> void:
	if not AlliedAbilities.alive(building) or building.side != "ally" or building.battle.paused or building.battle.ended: return
	if not AlliedAbilities.alive(unit) or unit.embarked_in != building or not building.special.get("occupants", []).has(unit): return
	_evacuate(building, [unit], false)
	if unit.embarked_in == building:
		Events.emit_message("碉堡出口受阻，驻军仍在堡内")

static func evacuate(building, destroyed := false, report_blocked := false) -> void:
	_evacuate(building, building.special.get("occupants", []).duplicate(), destroyed)
	if report_blocked:
		var remaining: int = building.special.get("occupants", []).size()
		if remaining > 0:
			Events.emit_message("出口受阻，仍有 %d 名驻军等待撤出" % remaining)

static func _evacuate(building, leaving: Array, destroyed: bool) -> void:
	var occupants: Array = building.special.get("occupants", [])
	var released_occupant := false
	for unit in leaving:
		if not AlliedAbilities.alive(unit): occupants.erase(unit); continue
		var placed := false
		for ring in [20.0, 60.0, 110.0]:
			for i in 16:
				var direction := Vector2.from_angle(i * TAU / 16.0)
				var point: Vector2 = building.position + direction * (building.footprint_clearance(direction) + unit.radius + ring)
				if not preload("res://scripts/world/chronoshift.gd").landing_clear(building.battle, unit, point, [unit]): continue
				unit.position = point
				unit.set_stowed(null)
				unit.order_stop()
				occupants.erase(unit)
				placed = true
				released_occupant = true
				break
			if placed: break
		if not placed and destroyed:
			unit.hp = 0.0
			unit._die()
			occupants.erase(unit)
	if occupants.is_empty():
		building.attack_target = null
		ForceFire.clear(building)
	building.queue_redraw()
	if civilian_garrison(building) and occupants.is_empty() and not destroyed and building.side != "neutral":
		var announce: bool = released_occupant and building.side == "ally"
		AlliedAbilities.change_side(building, "neutral")
		if announce:
			Ra2Sfx.play_player_eva(building.battle, "EVA_StructureAbandoned")
	building.battle._emit_selection()

static func tick_building(building) -> void:
	if not building.special.has("occupants") or slots(building) == 0: return
	var old_count: int = building.special.occupants.size()
	building.special.occupants = building.special.get("occupants", []).filter(func(u): return AlliedAbilities.alive(u) and u.embarked_in == building)
	if building.special.occupants.is_empty():
		building.attack_target = null
		ForceFire.clear(building)
		if building.side != "neutral" and civilian_garrison(building): AlliedAbilities.change_side(building, "neutral")
	elif not building.data.has("extra_power") and building.hp <= building.max_hp * 0.25:
		evacuate(building)
		return
	if building.special.occupants.size() != old_count:
		if building.special.occupants.is_empty(): building.queue_redraw()
		if building.battle.selected_building == building: building.battle._emit_selection()

# YR OccupyWeaponRange is a base range. The original rule also credits the
# shooter's foundation. In continuous world space use half its narrower side.
static func bunker_range(building) -> float:
	var rules: Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().combat
	var half: Vector2 = building.foundation_half()
	var bonus := minf(half.x, half.y) / Building.BUILD_GRID
	var base := (float(rules.occupyweaponrange) + bonus) * Ra2Damage.PX_PER_CELL
	if building.building_id != "NABNKR" or building.battle == null: return base
	var level: int = building.battle.production_technology.bunker_level(building.side)
	if level == 0: return base
	var cap := float(GameData.get_unit("GGI").deployed_weapon.range) + 0.5 * Ra2Damage.PX_PER_CELL
	var tiers:=4.0 if BattleRequest.combat_context.get("bunker_talent_version",0)>=2 else 3.0
	return lerpf(base, cap, float(level) / tiers)

static func has_gunner(building, forced_target = null) -> bool:
	for u in building.special.get("occupants", []):
		if AlliedAbilities.alive(u) and u.embarked_in == building and u.fire_stance != "none":
			var gun := weapon(u)
			if not gun.is_empty() and (forced_target == null or ForceFire.weapon_reason(building.side,forced_target,gun).is_empty()): return true
	return false

static func weapon(unit) -> Dictionary:
	if unit.embarked_in.data.has("extra_power"): return {}
	if unit.embarked_in.building_id == "NATBNK":
		var gun: Dictionary = unit.data.get("elite_weapon" if unit.veteran_level >= 2 else "weapon", {}).duplicate()
		var settings: Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().combat
		gun.range += float(settings.bunkerweaponrangebonus) * Ra2Damage.PX_PER_CELL
		gun.damage *= float(settings.bunkerdamagemultiplier)
		gun.cooldown *= float(settings.bunkerrofmultiplier)
		return gun
	var key := "EliteOccupyWeapon" if unit.veteran_level >= 2 else "OccupyWeapon"
	var id := str(AlliedAbilities.source(unit).get(key, "UCPara"))
	if unit.embarked_in.data.has("garrison_weapons"):
		var weapon_id := str(preload("res://scripts/core/yr_death_rules.gd").type_data(unit.unit_id).get(key.to_lower(), id))
		var native: Dictionary = unit.embarked_in.data.garrison_weapons.get(weapon_id, {})
		if unit.unit_id=="INIT":
			native=AlliedAbilities.weapon("YR_HOL_UCElitePsychicJab" if unit.veteran_level>=2 else "YR_HOL_UCPsychicJab")
			native.projectile_speed=0.0 # InvisibleHigh, originating at the building fire port.
		if native.is_empty(): return {}
		var rules: Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().combat
		var adjusted := native.duplicate()
		adjusted.damage *= float(rules.occupydamagemultiplier)
		adjusted.cooldown *= float(rules.occupyrofmultiplier)
		adjusted.range = bunker_range(unit.embarked_in)
		return adjusted
	var raw: Dictionary = Rules.data().weapons.get(id, {})
	var w: Dictionary = unit.data.get("weapon", {}).duplicate(true)
	if raw.is_empty():
		return AlliedAbilities.weapon(id) if not GameData.ra2_weapon(id).is_empty() else w
	w.damage = float(raw.get("damage", 30))
	w.range = float(raw.get("range", 6)) * 55.0
	w.cooldown = float(raw.get("rof", 15)) / 15.0
	w.ra2_warhead = str(raw.get("warhead", "SA"))
	w.ra2_weapon_id = id
	w.projectile_speed = 0.0
	return w

static func visible_enemy(building, target) -> bool:
	if not building.battle.actor_alive(target) or BattleRequest.friendly(building.side, target.side) or target.side == "neutral": return false
	if target is Unit and (NavalContact.underwater_type(target) or AlliedAbilities.concealed(target, building.side)): return false
	return building.battle.actor_visible_to(building.side, target)

static func order_block_reason(building, target, forced := false) -> String:
	if not building.is_operational() or AlliedAbilities.frozen(building): return "%s尚不能开火" % building.display_name
	if not has_gunner(building): return "需要可开火的驻军，先让步兵进驻"
	if forced:
		if not building.battle.actor_alive(target) or target == building: return "目标无效"
		if not target is ForceFirePoint and not building.battle.actor_visible_to(building.side,target): return "目标不在视野中"
		if target is Unit and (NavalContact.underwater_type(target) or AlliedAbilities.concealed(target,building.side)): return "驻军无法攻击该目标"
	elif not visible_enemy(building, target):
		return "请选择可见的敌方目标"
	if target is Building and float(target.special.get("force_shield_left", 0.0)) > 0.0: return "目标受力场护盾保护"
	if target is Unit and target.is_air_target(): return "驻军只能攻击地面目标"
	var distance: float = building.position.distance_to(target.position)
	if target is Building: distance -= target.footprint_clearance(target.position.direction_to(building.position))
	var reach := bunker_range(building)
	if building.building_id == "NATBNK": reach = float(weapon(building.special.occupants[0]).range)
	if distance > reach: return "目标超出驻军射程"
	if forced and not has_gunner(building,target): return "驻军武器对该目标无效"
	return ""

static func tick(unit, delta: float) -> void:
	var building = unit.embarked_in
	if not AlliedAbilities.alive(building): return
	unit.position = building.position
	if building.data.has("extra_power"): return
	unit._cd_timer -= delta
	unit._think_timer -= delta
	AlliedAbilities.tick_actor(unit, delta)
	if not AlliedAbilities.alive(unit) or not building.is_operational() or unit.fire_stance == "none": return
	if unit._cd_timer > 0:
		if building.building_id=="NATBNK":
			var tracking=building.attack_target if AlliedAbilities.alive(building.attack_target) else unit.attack_target
			if AlliedAbilities.alive(tracking): unit.HollywoodTurrets.aim_in_bunker(unit,tracking,delta)
		return
	# No target and no acquisition due: avoid rebuilding the garrison weapon
	# and querying bunker technology for every idle occupant on every tick.
	if not is_instance_valid(building.attack_target) and unit._think_timer>0.0:return
	var w := weapon(unit)
	if w.is_empty(): return
	var target = building.attack_target
	if not is_instance_valid(target) or not order_block_reason(building, target, ForceFire.active(building,target)).is_empty():
		ForceFire.clear(building)
		building.attack_target = null
		target = null
		# Empty bunkers used to scan every actor for every occupant, every tick.
		# Retain the ordinary acquisition cadence; a manual building target above
		# bypasses this wait. Reload and damage still use simulation time unchanged.
		if unit._think_timer>0.0: return
		unit._think_timer=unit.TARGET_REFRESH
		var distance := float(w.get("range", 330.0))
		var world=building.battle
		var candidates:Array=world.neighborhood.nearby(unit.position,distance) if world.units.size()>=96 else world.units
		for actor in candidates:
			if not is_instance_valid(actor) or not actor is Unit: continue
			var d: float = unit.position.distance_to(actor.position)
			if d <= distance and not actor.is_air_target() and visible_enemy(building, actor) and not WallArt.shot_blocked(building.battle, building, actor, w): distance = d; target = actor
	if target != null:
		if ForceFire.active(building,target) and not ForceFire.weapon_reason(building.side,target,w).is_empty(): return
		if WallArt.shot_blocked(building.battle, building, target, w): return
		# Only empty searches back off. A ready gun with an enemy keeps its
		# original fire cadence, including weapons faster than TARGET_REFRESH.
		unit._think_timer=0.0
		unit.attack_target = target
		if building.building_id=="NATBNK" and not unit.HollywoodTurrets.aim_in_bunker(unit,target,delta): return
		unit._fire_shot(target)
		unit._cd_timer = float(w.get("cooldown", 1.0))*preload("res://scripts/buildings/tesla_pulse.gd").reload_multiplier(building)
		unit.special.garrison_reload_duration=unit._cd_timer
