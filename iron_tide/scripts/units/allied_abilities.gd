class_name AlliedAbilities
extends RefCounted
## Independent continuous-world adapters. Original parameters are exported locally.
## `special` is explicit saved state, including actor references, never node metadata.
const EMPTY_LOOKUP: Dictionary = {}
const STOLEN_LABS := {"GATECH": "RequiresStolenAlliedTech", "NATECH": "RequiresStolenSovietTech", "YATECH": "RequiresStolenThirdTech"}
# Both factories in a production category grant the same training benefit.
const TRAINING_SITES := {"GAPILE":"GAPILE", "NAHAND":"GAPILE", "GAWEAP":"GAWEAP", "NAWEAP":"GAWEAP", "YAWEAP":"GAWEAP", "YABRCK":"GAPILE"}
const STATUS_TIMERS := ["blackout", "reveal", "chrono_left"]
const SPY_REFINERIES := ["GAREFN", "NAREFN"]
const SPY_POWER := ["GAPOWR", "NAPOWR", "NANRCT", "YAPOWR"]
const ChronoFx = preload("res://scripts/world/chrono_miner_fx.gd")
const TemporalVisual = preload("res://scripts/units/temporal_visual.gd")

static func source(actor) -> Dictionary:
	# Callers legitimately pass buildings too (e.g. battle._capture_enemy_music_roster
	# iterates units + buildings). Buildings carry `building_id`, not `unit_id`.
	if actor is Building:
		return GameData.ra2_source_buildings.get(actor.building_id, EMPTY_LOOKUP).get("extra", {})
	var rows: Dictionary = GameData.allied_capabilities.get("units", EMPTY_LOOKUP)
	if rows.has(actor.unit_id): return rows[actor.unit_id]
	return GameData.ra2_source_units.get(actor.unit_id, EMPTY_LOOKUP).get("extra", {})

static func flag(unit, key: String) -> bool:
	if key=="ImmuneToPsionics" and unit.data.get("immune_to_psionics",false): return true
	return GameData._ra2_flag(source(unit).get(key, false))

static func alive(actor) -> bool:
	if not is_instance_valid(actor): return false
	if actor is Unit:
		var unit: Unit = actor
		return not unit.is_queued_for_deletion() and unit.hp > 0.0 and not unit._dead
	if actor is Building:
		var building: Building = actor
		return not building.is_queued_for_deletion() and building.hp > 0.0 and not building._dead
	return not actor.is_queued_for_deletion() and actor.hp > 0.0 and not actor._dead

static func infantry(actor) -> bool:
	return actor is Unit and actor.data.get("role", "") == "infantry"

static func infantry_teleporter(unit) -> bool:
	return infantry(unit) and flag(unit, "Teleporter")

static func weapon(name: String) -> Dictionary:
	if GameData.capability_weapon_cache.has(name): return GameData.capability_weapon_cache[name].duplicate()
	var id := "YR_CAP_" + name
	if GameData.ra2_weapon(id).is_empty(): id = name
	if GameData.ra2_weapon(id).is_empty(): return {}
	var result := GameData.spawned_weapon(id)
	var raw := GameData.ra2_weapon(id)
	result.min_range = GameData._num(raw.get("min_range")) * 55.0
	result.ra2_aa = GameData.ra2_projectile(str(result.ra2_projectile)).get("aa", false)
	result.attack_type = "rocket" if result.ra2_aa else "bullet"
	GameData.capability_weapon_cache[name] = result.duplicate()
	return result

static func effective_weapon(unit, target = null) -> Dictionary:
	return unit._effective_native_weapon(target)

static func is_repair_ifv(unit) -> bool:
	return unit.unit_id == "FV" and float(unit._active_weapon().get("damage", 0)) < 0.0

static func refresh_ifv_art(unit) -> void:
	if unit.unit_id != "FV": return
	preload("res://scripts/units/progression_expansion_2.gd").crew_changed(unit)
	var mode := 0
	if not unit.logistics.passengers.is_empty() and alive(unit.logistics.passengers[0]): mode = int(source(unit.logistics.passengers[0]).get("IFVMode", 0))
	var turret := 0
	var row := source(unit)
	for key in row:
		if str(key).ends_with("TurretWeapon") and int(row[key]) == mode:
			turret = int(row.get(str(key).trim_suffix("Weapon") + "Index", 0))
	var id := "FV_tur" + (str(turret) if turret > 0 else "")
	var art := RA2Art.art(id)
	if not art.is_empty():
		unit._ra2_tur = art
		if not art.has("img"):
			var pixels: Image = art.tex.get_image()
			if pixels.is_compressed(): pixels.decompress()
			art.img = pixels
	var descriptor := RA2Art.weapon_descriptor("FV_mode" + str(turret) if turret > 0 else "FV")
	if not descriptor.is_empty(): unit._weapon_art = descriptor
	unit.queue_redraw()

static func install(unit) -> void:
	# Membership follows immutable unit capabilities; allegiance, life and range
	# are still checked live. Avoid scanning every tank for every hidden target.
	if flag(unit, "DetectDisguise"): unit.add_to_group("disguise_detectors")
	if infantry(unit): unit.add_to_group("disguise_contact_infantry")
	if unit.unit_id == "MGTK": update_mirage_tree(unit)
	# Also normalize legacy saved ability arrays; C4 remains an attack behavior.
	unit.skills = unit.skills.filter(func(ability): return ability.id != "allied_c4")
	# GI/GGI already expose an innate deployment toggle. Old loadouts and
	# snapshots may still contain the equivalent extension ability; normalize
	# the runtime list without changing stored loadouts or other skill state.
	# The SEAL used to receive this extension ability despite having no deploy command.
	if unit.unit_id in ["E1", "GGI", "GHOST"]:
		unit.skills = unit.skills.filter(func(ability): return ability.id != "ap_deploy")
	var definitions: Array = []
	if unit.data.has("soviet_ra3"):
		definitions.append(["soviet_"+unit.unit_id.to_lower(),preload("res://scripts/units/ra3_soviet.gd").LABELS[unit.unit_id],unit.data.desc,unit.unit_id=="R3REAPER"])
	if Ra3Mirage.handles(unit): definitions.append(["ra3_field", "幻影场", "开启后停火，隐藏附近友方地面部队。", false])
	if unit.unit_id == Ra3Expansion.FUTURE: definitions.append(["ra3_riot", "暴乱光束", "指定位置，准备后双束交叉扫射。", true])
	if unit.unit_id == Ra3Expansion.HARBINGER: definitions.append(["ra3_gunship", "切换武器", "切换对撞炮与前部机炮。", false])
	match unit.unit_id:
		"E1": definitions = [["deploy", "卧倒据守", "部署机枪，固定射击；再次点击起身。", false]]
		"ENGINEER", "SENGINEER", "YENGINEER": definitions = [["engineer", "工程作业", "选择敌方可占领建筑、己方受损建筑，或断桥的维修小屋。到达后占领或完全修复，消耗工程师。可拆除己方目标上的 C4。"+("右键己方游隼迫降机体，连续维修 5 秒提前救起，此项不消耗工程师。" if BattleRequest.extensions_enabled() else ""), true]]
		"SPY": definitions = [["disguise", "伪装", "选择敌方步兵复制外观；警犬和识破伪装单位能发现间谍。", true], ["infiltrate", "渗透", "进入敌方矿场窃款、电厂断电、兵营或战车工厂获得训练；渗透作战实验室窃取对应阵营科技，空指部清除敌方地图探索，超武建筑重置充能。", true]]
		"FV": definitions = [["unload", "卸下乘员", "卸下乘员并恢复导弹。步兵右键登车，按乘员类型切换武器；工程师变为维修车。", false]]
	if infantry_teleporter(unit):
		definitions.append(["chrono", "超时空移动", "选择空闲地面传送；距离越远，抵达后恢复所需时间越长。", true])
	if unit.unit_id == "PTROOP":
		definitions.append(["release", "解除控制", "释放当前心灵控制的单位。心控者死亡也会解除控制。", false])
	if unit.unit_id == "MGTK":
		definitions.append(["mirage", "静止伪装", "开关自动伪装；静止时伪装，移动、开火或受伤后显形。", false])
	var native: Array[Ability] = []
	for row in definitions:
		var id: String = "allied_" + row[0]
		var exists := false
		for current in unit.skills:
			if current.id == id: exists = true
		if exists: continue
		var ability := Ability.new()
		ability.setup({"id": id, "name": row[1], "desc": row[2], "effect": id, "radius": 1.0 if row[3] else 0.0, "target": "enemies"})
		if id==Ra3Expansion.BEAM: ability.radius=preload("res://scripts/units/ra3_riot.gd").range_limit()
		if id=="allied_soviet_r3reaper":ability.radius=300.0
		native.append(ability)
	unit.skills = native + unit.skills
	unit._has_active_skills = not unit.skills.is_empty()

static func info(unit, ability) -> Dictionary:
	if ability.id == "allied_special" and unit.unit_id == "SCHP":
		return {"id": ability.id, "name": "收炮起飞" if unit.is_deployed() else "部署火炮",
			"desc": "部署后原地使用火炮；收炮起飞后恢复移动。降落需要空地，展开或收起期间不能再次切换。",
			"ready": unit.ability_ready(UnitSkillLayout.index(unit, 2)), "cd_left": 0.0, "cooldown": 0.0,
			"cd_frac": 0.0, "active": unit.is_deployed(), "toggle": true, "glyph": "deploy"}
	if ability.id == "allied_special" and not unit.deploy_building_id().is_empty():
		return {"id":ability.id,"name":"选址展开","desc":"左键选择可达的地基，基地车驶至指定位置后展开。点击已选基地车可原地展开。","ready":unit.ability_ready(UnitSkillLayout.index(unit,2)), "icon":GameData.ra2_cameo_path(unit.unit_id)}

	if ability.id.begins_with("allied_soviet_"):return preload("res://scripts/units/ra3_soviet.gd").ability(unit)
	if ability.id in [Ra3Expansion.BEAM, Ra3Expansion.TOGGLE]: return Ra3Expansion.info(unit)
	if ability.id == Ra3Mirage.SKILL: return Ra3Mirage.info(unit)
	var active: bool = unit._deployed if ability.id == "allied_deploy" else bool(unit.special.get("mirage_enabled", true)) if ability.id == "allied_mirage" else false
	return {"id": ability.id, "name": ("起身" if active else "卧倒据守") if ability.id == "allied_deploy" else ability.display_name,
		"desc": ability.desc, "ready": alive(unit) and unit.embarked_in == null and not frozen(unit) and unit._stun_timer <= 0.0,
		"cd_left": 0.0, "cooldown": 0.0, "cd_frac": 0.0, "active": active, "toggle": ability.id in ["allied_deploy", "allied_mirage"],
		"glyph": "deploy" if ability.id == "allied_deploy" else "repair" if ability.id == "allied_engineer" else "attack"}

static func use(unit, id: String, target = null, point := Vector2.INF) -> bool:
	if preload("res://scripts/units/tanya_talents.gd").locked(unit):return false
	if unit.data.has("soviet_ra3") and id=="allied_soviet_"+unit.unit_id.to_lower():return preload("res://scripts/units/ra3_soviet.gd").use(unit,point)
	if id in [Ra3Expansion.BEAM, Ra3Expansion.TOGGLE]: return Ra3Expansion.use(unit, point)
	if id == Ra3Mirage.SKILL: return Ra3Mirage.toggle(unit)
	if not alive(unit) or unit.embarked_in != null or unit._stun_timer > 0.0 or frozen(unit): return false
	if id == "allied_engineer" and alive(target) and preload("res://scripts/units/civilian_orders.gd").can_repair(unit,target): id = "allied_bridge"
	match id:
		"ivan_bridge":
			if not can_order(unit, target, id): return false
			unit.order_move(approach(unit, target), true)
			unit.attack_target = target
			unit.attack_ordered = true
			unit.attack_move = false
			return true
		"allied_special": return unit.deploy()
		"allied_deploy": return unit.deploy()
		"allied_unload": return unit.logistics.request_unload()
		"allied_release":
			release_control(unit)
			return true
		"allied_mirage":
			unit.special.mirage_enabled = not bool(unit.special.get("mirage_enabled", true))
			unit.special.reveal = 1.0
			update_mirage_tree(unit)
			return true
		"allied_chrono": return teleport(unit, point)
		"allied_disguise":
			if not can_order(unit, target, id): return false
			unit.order_stop()
			unit.special.disguise = target.unit_id
			if unit.side == "ally": Events.emit_message("伪装：" + target.display_name, Color(0.7, 0.95, 1.0))
			Ra2Sfx.play_voice(unit.data, "attack", unit.global_position, 250)
			unit.queue_redraw()
			return true
	if not can_order(unit, target, id): return false
	var explicit_c4:bool=id=="allied_c4" and unit.attack_ordered
	unit.order_move(approach(unit, target))
	if explicit_c4:unit.special.c4_explicit=true
	unit.attack_target = null
	unit.special.action = id
	unit.special.target = target
	Ra2Sfx.play_voice(unit.data, "attack" if id == "allied_c4" else "move", unit.global_position, 250)
	return true

static func can_order(unit, target, id: String) -> bool:
	return _valid_order_pair(unit, target, id) and _action_allowed(unit, target, id)

static func _valid_order_pair(unit, target, action := "") -> bool:
	if not alive(unit) or not alive(target) or unit == target: return false
	var world = unit._battle_world()
	if world == null: return false
	if action == "allied_engineer" and unit.unit_id == "YENGINEER" and unit.side == "enemy" and world.mission.get("id") == "yr_time_shift" and unit.special.get("shift_plant") == target:
		return true
	return world.actor_visible_to(unit.side, target)

static func _action_allowed(unit, target, id: String) -> bool:
	if id=="allied_c4" and target is Building and target.is_protected_mission_plant(): return false
	if target.special.get("expedition_protected",false) and id in ["allied_engineer","allied_c4","allied_infiltrate"]:return false
	match id:
		"ivan_bridge":
			return unit.unit_id in ["IVAN", "CIVAN"] and target is Building and target.special.get("bridge_repaired", false) and preload("res://scripts/units/soviet_specials.gd").accepts_bomb(unit, target)
		"tesla_charge": return preload("res://scripts/units/tesla_support.gd").accepts(unit,target)
		"yuri_recycle": return target is Building and target.building_id == "YAGRND" and target.side == unit.side and target.battle.skirmish and target.is_operational() and unit.embarked_in == null and not unit.is_air and not unit.is_naval and unit.logistics.passengers.is_empty()
		"allied_garrison": return preload("res://scripts/units/civilian_orders.gd").can_enter(unit, target)
		"allied_bridge": return preload("res://scripts/units/civilian_orders.gd").can_repair(unit, target)
		"allied_disguise":
			return unit.unit_id == "SPY" and unit.embarked_in == null and unit._stun_timer <= 0.0 and not frozen(unit) \
				and infantry(target) and not BattleRequest.friendly(target.side,unit.side) and target.embarked_in == null
		"allied_engineer":
			if unit.unit_id not in ["ENGINEER", "SENGINEER", "YENGINEER"]: return false
			if preload("res://scripts/units/peregrine_service.gd").engineer_allowed(unit,target):return true
			if preload("res://scripts/units/civilian_orders.gd").can_repair(unit,target): return true
			if BattleRequest.friendly(target.side,unit.side) and (target.special.has("c4_left") or target.special.has("ivan_bomb")): return true
			if not target is Building or target.under_construction: return false
			if preload("res://scripts/units/civilian_orders.gd").civilian_garrison(target) and target.side in [unit.side, "neutral"]: return target.hp < target.max_hp
			if BattleRequest.friendly(target.side,unit.side): return target.hp < target.max_hp
			var row: Dictionary = GameData.ra2_source_buildings.get(target.building_id, {})
			if target.data.get("hollywood_art", false) and not target.data.has("capturable") and not row.has("capturable"):
				var native := preload("res://scripts/core/yr_death_rules.gd")
				return native.flag(native.type_data(target.building_id), "capturable")
			return target.data.get("capturable", row.get("capturable", false)) == true
		"allied_c4":
			return CommandoCombat.building_c4(unit, target) and (unit.fire_stance != "none" or unit.attack_ordered or unit.special.get("c4_explicit",false))
		"allied_infiltrate":
			return unit.unit_id == "SPY" and target is Building and not BattleRequest.friendly(target.side,unit.side) and not target.under_construction and (target.special.has("hollywood_plant") or target.building_id in SPY_POWER or target.building_id in SPY_REFINERIES or TRAINING_SITES.has(target.building_id) or STOLEN_LABS.has(target.building_id) or preload("res://scripts/units/spy_operations.gd").supported(target))
		"allied_repair":
			return is_repair_ifv(unit) and target is Unit and not infantry(target) and not target.is_air and BattleRequest.friendly(target.side,unit.side) and target.hp < target.max_hp and target.embarked_in == null
	return false

static func default_order(unit, target) -> String:
	if not _valid_order_pair(unit, target): return ""
	for action in ["yuri_recycle", "ivan_bridge", "tesla_charge", "allied_garrison", "allied_bridge", "allied_engineer", "allied_infiltrate", "allied_repair"]:
		if _action_allowed(unit, target, action): return action
	return ""

static func approach(unit, target) -> Vector2:
	var direction: Vector2 = target.global_position.direction_to(unit.global_position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var reach: float = target.footprint_clearance(direction) if target is Building else target.radius
	return target.global_position + direction * (reach + unit.radius + 10.0)

static func cancel(unit) -> void:
	unit.special.erase("convoy_press_order")
	if unit.special.has("convoy"):unit.special.convoy.erase("press")
	unit.special.erase("leizhu_court_order")
	unit.special.erase("peregrine_hunt_order")
	unit.special.erase("walker_approach")
	preload("res://scripts/units/ra3_riot.gd").cancel_approach(unit)
	unit.special.erase("pounce")
	ForceFire.clear(unit)
	CommandoCombat.cancel_entry(unit)
	unit.special.erase("action")
	unit.special.erase("target")
	unit.special.erase("c4_resume")
	unit.special.erase("c4_explicit")
	unit.special.erase("commando_resume")
	release_temporal(unit)

static func consume(unit) -> void:
	# Entering a building consumes the actor without death audio, kill credit or unit-lost.
	unit._dead = true
	unit.hp = 0.0
	unit._battle_world().selected_units.erase(unit)
	for group in ["combatants", "ground_units", "allies", "enemies", "ally_targets", "enemy_targets"]:
		unit.remove_from_group(group)
	unit.hide()
	unit.queue_free()

static func change_side(actor, owner: String, refresh_world := true) -> void:
	if actor.side == owner: return
	actor.special.erase("dominator_source")
	var world = actor._battle_world() if actor is Unit else actor.battle
	if actor is Building:
		if actor.data.has("garrison_slots") and not actor.special.get("occupants", []).is_empty():
			preload("res://scripts/units/civilian_orders.gd").evacuate(actor,true)
		if actor.side=="enemy" and world.mission.get("id")=="yr_head_games" and actor.building_id in ["NACNST","GACNST","YACNST"]:
			world.allied_state["s07_no_yard_%d"%int(actor.special.get("head_games_wing",-1))]=true
		actor.special.has_been_captured = true
		if owner != "enemy" and world.mission.get("id") == "yr_time_shift" and actor.building_id in world.TimeShift.POWER_PLANTS:
			actor.special.erase("yuri_power")
		while not actor.production.is_empty(): actor.cancel_at(0)
		actor.set_repairing(false)
	else:
		actor.order_stop()
		for passenger in actor.logistics.passengers:
			if alive(passenger):
				passenger.side = owner
				preload("res://scripts/expedition/elite_tactics.gd").ownership_changed(passenger)
				passenger.refresh_house_color()
	actor.side = owner
	preload("res://scripts/expedition/elite_tactics.gd").ownership_changed(actor)
	if actor is Building:
		world.invalidate_building_membership()
		preload("res://scripts/rules/joint_ra2_production.gd").sync_catalog(actor)
		preload("res://scripts/expedition/rules.gd").sync_training_permits(actor)
	if world is Battle: world.invalidate_ai_population()
	BattleRequest.sync_house_groups(actor)
	preload("res://scripts/world/brutal_three.gd").grant(actor)
	if actor is Building: SupportSystems.join_charge(actor)
	if actor is Building and actor.building_id == "CAOILD" and (owner in ["ally", "enemy"] or BattleRequest.house_teams.has(owner)):
		if BattleRequest.is_ai_house(owner) and actor.position == world.allied_state.get("oil_mid_point", Vector2.INF):
			world.ai_decisions(owner).erase("oil_engineer_losses")
			world.ai_decisions(owner).erase("oil_retry_left")
		if not actor.special.get("oil_claimed", false):
			actor.special.oil_claimed = true
			world.credit_side(owner, float(actor.data.oil_startup))
		if owner == "ally":
			Ra2Sfx.play_player_eva(world, "EVA_OilRefineryCaptured")
			Events.emit_message("已占领科技钻油井，可在附近建造")
	actor.attack_target = null
	for group in ["allies", "enemies", "ally_targets", "enemy_targets"]: actor.remove_from_group(group)
	if (owner in ["ally", "enemy"] or BattleRequest.house_teams.has(owner)):
		actor.add_to_group("enemy_targets" if owner == "ally" else "ally_targets")
		actor.add_to_group("allies" if owner == "ally" else "enemies")
	if actor is Building:
		actor.remove_from_group("ally_buildings"); actor.remove_from_group("enemy_buildings")
		if (owner in ["ally", "enemy"] or BattleRequest.house_teams.has(owner)): actor.add_to_group("ally_buildings" if owner == "ally" else "enemy_buildings")
	if actor is Unit and is_instance_valid(world.skirmish_ai):
		world.skirmish_ai._army.erase(actor)
		if owner == "enemy" and not actor.is_harvester and actor.deploy_building_id().is_empty(): world.skirmish_ai._army.append(actor)
	actor.refresh_house_color()
	actor.set_selected(false)
	world.selected_units.erase(actor)
	if world.selected_building == actor: world.selected_building = null
	if refresh_world:
		refresh_after_side_changes(world)

static func refresh_after_side_changes(world) -> void:
	world._update_power()
	world._emit_selection()
	Events.production_queue_changed.emit()

static func tick_action(unit, delta: float) -> bool:
	var target = unit.special.get("target")
	var action: String = unit.special.get("action", "")
	if action.is_empty(): return false
	if action == "allied_c4": return CommandoCombat.tick_c4(unit, delta)
	if not can_order(unit, target, action): cancel(unit); return false
	if action=="allied_engineer" and target is Unit and target.special.has("peregrine") and target.special.has("hero_wreck"):
		return preload("res://scripts/units/peregrine_service.gd").engineer_tick(unit,target,delta)
	if action == "tesla_charge":
		preload("res://scripts/units/tesla_support.gd").tick(unit,target,delta)
		return true
	var destination := approach(unit, target)
	var reach: float = unit.attack_range if action == "allied_repair" else unit.radius + 24.0
	var distance: float = unit.global_position.distance_to(target.global_position) if action == "allied_repair" else unit.global_position.distance_to(destination)
	if distance > reach:
		# The navigation grid can end outside the exact building approach point.
		# Hand off only the final nearby segment to physical movement, otherwise
		# the unit keeps steering back to that already-reached grid waypoint.
		var final_entry_step: bool = (action == "allied_engineer" and target is Building or action in ["allied_infiltrate", "allied_garrison", "allied_bridge"]) and distance <= PathService.CELL * 2.0 \
			and unit._path_pts.size() >= 2 and unit._path_i >= unit._path_pts.size() - 1 \
			and (unit.position.distance_to(unit._path_pts[-1]) <= reach or distance < unit._path_pts[-1].distance_to(destination))
		if final_entry_step: unit._move_toward(destination, delta, false)
		else: unit._go_to(destination, delta, 4.0)
		unit._face_if_moving()
		unit._move_water_safe()
		return true
	if action in ["allied_infiltrate", "allied_garrison", "allied_bridge"] and not enter_infiltration_target(unit, target, delta):
		return true
	unit.velocity = Vector2.ZERO
	unit.has_move_order = false
	if action == "yuri_recycle":
		var salvage: int = int(preload("res://scripts/core/yr_death_rules.gd").type_data(unit.unit_id).get("soylent",unit.data.get("cost",0)/2))
		target.battle.credit_side(unit.side,salvage)
		target.play_special()
		consume(unit)
		return true
	if action == "allied_garrison":
		preload("res://scripts/units/civilian_orders.gd").enter(unit, target)
		return true
	if action == "allied_bridge":
		preload("res://scripts/world/civilian_sites.gd").repair(target)
		consume(unit)
		return true
	if action == "allied_repair":
		unit.special.repair_left = float(unit.special.get("repair_left", 0.0)) - delta
		if unit.special.repair_left <= 0.0:
			var w: Dictionary = unit._active_weapon()
			preload("res://scripts/units/soviet_advanced.gd").cleanse(target, true)
			target.heal(absf(float(w.damage)), unit)
			unit.special.repair_left = float(w.cooldown)
			Ra2Sfx.play_weapon(w, unit.global_position)
			Effects.spawn_beam(unit._weapon_muzzle(), target.global_position, Color(0.7, 0.9, 1), "tesla", 1.4, 0.25)
		return true
	if action == "allied_engineer":
		if BattleRequest.friendly(target.side,unit.side) and target.special.has("ivan_bomb"):
			preload("res://scripts/units/soviet_specials.gd").remove_bomb(target,false)
			cancel(unit)
			Effects.spawn_text(target.global_position, "已拆除伊文炸弹", Color.LIGHT_GREEN)
			return true
		if BattleRequest.friendly(target.side,unit.side) and target.special.has("c4_left"):
			target.special.erase("c4_left"); target.special.erase("c4_owner")
			target.special.erase("c4_secondary");target.special.erase("c4_side")
			TemporalVisual.sync(target)
			cancel(unit)
			Effects.spawn_text(target.global_position, "已拆除 C4", Color(0.5, 1, 0.8))
			return true
		if BattleRequest.friendly(target.side,unit.side) or preload("res://scripts/units/civilian_orders.gd").civilian_garrison(target): target.hp = target.max_hp; target.queue_redraw()
		else:
			# Credit the mission's power contest only when the engineer finishes entering.
			if unit.unit_id == "YENGINEER" and unit.side == "enemy" and unit.special.get("shift_plant") == target:
				target.special.yuri_power = true
			change_side(target, unit.side)
	elif action == "allied_infiltrate":
		resolve_infiltration(unit, target)
		return true
	consume(unit)
	return true

static func resolve_infiltration(unit, target) -> void:
	var world = unit._battle_world()
	var thief: String = unit.side
	var victim: String = target.side
	var id: String = target.building_id
	var at: Vector2 = target.global_position
	# Finish the order before synchronous HUD/economy listeners can run it twice.
	cancel(unit)
	consume(unit)
	if target.special.has("hollywood_plant") and thief == "ally": target.special.hollywood_infiltrated = true
	if id in SPY_REFINERIES:
		var percent := clampf(float(GameData.allied_capabilities.get("general", {}).get("SpyMoneyStealPercent", 0.5)), 0.0, 1.0)
		world.transfer_spy_funds(victim, thief, percent, at)
	elif id in SPY_POWER:
		world.allied_state["blackout_" + victim] = float(GameData.allied_capabilities.get("general", {}).get("SpyPowerBlackout", 1000)) / 15.0
	elif STOLEN_LABS.has(id):
		world.allied_state["stolen_" + thief + "_" + str(STOLEN_LABS[id])] = true
		Events.production_queue_changed.emit()
		if thief == "ally":
			Events.emit_message("实验室渗透成功：已窃取科技，前往兵营查看解锁单位。", Color(0.5, 1.0, 0.75))
	elif TRAINING_SITES.has(id):
		world.allied_state["training_" + thief + "_" + str(TRAINING_SITES[id])] = true
	else:
		preload("res://scripts/units/spy_operations.gd").resolve(world, target, victim)

static func enter_infiltration_target(unit, target, delta: float) -> bool:
	var footprint: PackedVector2Array = target.footprint_poly()
	if Geometry2D.is_point_in_polygon(unit.global_position - target.global_position, footprint): return true
	var direction: Vector2 = target.global_position.direction_to(unit.global_position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var point: Vector2 = target.global_position + direction * maxf(0.0, target.footprint_clearance(direction) - 8.0)
	var motion: Vector2 = unit.global_position.direction_to(point) * minf(unit.move_speed * delta, unit.global_position.distance_to(point))
	if not unit._domain_ok(unit.global_position + motion):
		unit.velocity = Vector2.ZERO
		return false
	unit._face(point)
	unit.velocity = motion / maxf(delta, 0.001)
	# Enter only the assigned building. Walls, other structures and units keep
	# their real collisions; no exception or entry-stage state survives a tick.
	var already_excluded: bool = unit.get_collision_exceptions().has(target)
	if not already_excluded: unit.add_collision_exception_with(target)
	unit.move_with_traffic_exceptions(motion)
	if not already_excluded: unit.remove_collision_exception_with(target)
	return Geometry2D.is_point_in_polygon(unit.global_position - target.global_position, footprint)

static func tick_actor(actor, delta: float) -> void:
	if actor is Unit:
		var unit: Unit = actor
		if unit.unit_id == Ra3Mirage.ID or unit.has_meta(Ra3Mirage.CloakVisual.STATE) or unit.get_tree().has_group(Ra3Mirage.SOURCE_GROUP):
			Ra3Mirage.tick(unit, delta)
		if unit.unit_id in [Ra3Expansion.FUTURE, Ra3Expansion.HARBINGER]: Ra3Expansion.tick(unit, delta)
	if not alive(actor): return
	var state: Dictionary=actor.special
	if state.has("c4_left") or ((state.has("chrono_left") or state.has("temporal_by")) and frozen(actor)): actor.queue_redraw()
	for key in STATUS_TIMERS:
		if state.has(key):
			var before: float = state[key]
			state[key] = maxf(0.0, before - delta)
			if before > 0.0 and state[key] == 0.0: actor.queue_redraw()
	if actor is Unit and actor.unit_id == "MGTK": update_mirage_tree(actor)
	if state.has("c4_left"):
		if state.get("c4_secondary",false) and not preload("res://scripts/units/tanya_operations.gd").chain_valid(actor):
			for key in ["c4_left","c4_owner","c4_secondary","c4_side"]:state.erase(key)
			TemporalVisual.sync(actor);return
		state.c4_left -= delta
		if state.c4_left <= 0.0:
			var owner = state.get("c4_owner")
			state.yr_c4_death = true
			state.erase("c4_left")
			state.erase("c4_owner")
			TemporalVisual.sync(actor)
			actor.hp = 0.0
			actor._die(owner)
			return
	if state.has("controller") and not alive(state.controller):
		_clear_mind_control(actor)
		state=actor.special
	if state.has("temporal_by"):
		var owner = state.temporal_by
		if not alive(owner) or owner.special.get("temporal_target") != actor:
			state.erase("temporal_by")
	if state.has("temporal_by") or state.has("c4_left") or actor.has_meta(TemporalVisual.STATE) or actor.has_meta("time_fracture"):
		TemporalVisual.sync(actor)

static func frozen(actor) -> bool:
	# Most actors never carry either state; avoid a null actor validity call on
	# every movement, range and target check. Active effects still resolve live.
	var state: Dictionary = actor.special
	if not state.has("chrono_left") and not state.has("temporal_by"): return false
	if float(state.get("chrono_left", 0.0)) <= 0.0 and not alive(state.get("temporal_by")): return false
	return Unit.TankHero.rank(actor,true) < 4

static func teleport(unit, point: Vector2) -> bool:
	var world = unit._battle_world()
	if not infantry_teleporter(unit) or not point.is_finite() or world == null or not unit.logistics.landing_clear(world, point, unit.radius): return false
	var distance: float = unit.global_position.distance_to(point)
	var rules: Dictionary = GameData.allied_capabilities.get("general", {})
	unit.order_stop()
	ChronoFx.spawn(world, unit.global_position, "WARPOUT")
	ChronoFx.spawn(world, point, "WARPOUT")
	if unit.unit_id == "CIVAN":
		var native := source(unit)
		Ra2Sfx.play(str(native.get("ChronoOutSound","")),unit.global_position)
		Ra2Sfx.play(str(native.get("ChronoInSound","")),point)
	if unit.unit_id == "CLEG" and UnitSkillLayout.find(unit, "ap_chrono_return") >= 0:
		unit.special.return_origin = unit.global_position
		unit.special.return_window = 6.0
	unit.global_position = point
	unit.reset_physics_interpolation()
	unit._last_water_pos = point
	# World cell = 55; original cell = 256 leptons, original rules clock = 15 Hz.
	unit.special.chrono_left = maxf(float(rules.get("ChronoMinimumDelay", 16)), distance / 55.0 * 256.0 / maxf(1.0, float(rules.get("ChronoDistanceFactor", 48)))) / 15.0
	if unit.unit_id == "CLEG": unit.special.chrono_left /= Unit.Training.timing_scale(unit)
	Ra2Sfx.play_voice(unit.data, "move", point, 250)
	return true

static func valid_weapon_target(unit: Unit, target, w: Dictionary, ordinary_visibility := false) -> bool:
	if Ra3Mirage.field_active(unit): return false
	if not alive(target) or float(w.get("damage", 0)) < 0.0 or frozen(unit): return false
	if unit.unit_id in ["SPY", "ENGINEER", "SENGINEER", "YENGINEER"]: return false
	if alive(target.special.get("temporal_by")) and target.special.temporal_by != unit and Unit.TankHero.rank(target,true)<4: return false
	if unit.unit_id in ["DOG", "SOV_DOG", "SNIPE"] and not infantry(target): return false
	var flags: Dictionary = GameData.warhead_combat_rule(str(w.get("ra2_warhead", "")))
	var mind_control: bool = flags.get("mind_control", false)
	var temporal: bool = flags.get("temporal", false)
	if (mind_control or temporal) and target.special.get("expedition_protected",false):return false
	if target is ForceFirePoint and (mind_control or temporal): return false
	if unit.unit_id in ["VIRUS","TELE","CAOS"] and not preload("res://scripts/units/head_games_weapons.gd").eligible(unit,target): return false
	if mind_control:
		if BattleRequest.friendly(target.side,unit.side): return false
		if not (target is Unit or unit.unit_id=="YURIPR" and target is Building): return false
		if target is Unit and target.is_air or flag(target,"ImmuneToPsionics") or target.special.has("controller"): return false
		if unit.unit_id!="MIND" and alive(unit.special.get("controlled")): return false
	if temporal:
		if target is Unit and (target.is_air or GameData.unit_blocks_warp(target.unit_id)): return false
	if not ordinary_visibility and target is Unit and concealed(target, unit.side) and not (unit.attack_ordered and unit.attack_target == target): return false
	return true

static func special_shot(unit, target, w: Dictionary) -> bool:
	if unit.unit_id in ["TELE","CAOS","DISK","VIRUS"] and preload("res://scripts/units/head_games_weapons.gd").shot(unit,target,w): return true
	if preload("res://scripts/units/dog_pounce.gd").start(unit, target, w): return true
	var flags: Dictionary = GameData.warhead_combat_rule(str(w.get("ra2_warhead", "")))
	if flags.get("mind_control", false):
		if not valid_weapon_target(unit, target, w): return true
		if unit.unit_id=="MIND": unit.special.get_or_add("mind_links",[]).append(target)
		unit.special.controlled = target
		apply_mind_control(unit, target)
		if unit.unit_id == "YURI":
			Ra2Fx.play_impact(Effects._host(), w.ra2_warhead, w.damage, Effects.hit_position(target))
		else:
			Effects.spawn_beam(unit.global_position, target.global_position, Color(0.85, 0.35, 1), "laser", 2.0, 0.8)
		return true
	if flags.get("temporal", false):
		if not valid_weapon_target(unit, target, w): return true
		release_temporal(unit)
		unit.special.temporal_target = target
		var book:Dictionary=unit.special.get(Unit.YRTalents.BOOK,{})
		unit.special.temporal_work = float(book.work) if not book.is_empty() and is_same(book.target,target) and book.left>0 else 0.0
		unit.special.erase(Unit.YRTalents.BOOK)
		if Effects.Looks.current(unit)=="time_fracture":unit.special.temporal_skin="time_fracture"
		target.special.temporal_by = unit
		TemporalVisual.sync(target)
		return true
	return false

# Retail rules define these sounds separately from weapon Reports; both are Type=global.
static func apply_mind_control(controller, target) -> void:
	target.special.original_side = target.side
	target.special.controller = controller
	change_side(target, controller.side)
	Ra2Sfx.play("YuriMindControl")

static func _clear_mind_control(target) -> void:
	var original: String = target.special.get("original_side", target.side)
	target.special.erase("controller")
	target.special.erase("original_side")
	if target.side == original: return
	change_side(target, original)
	Ra2Sfx.play("MindCleared")

static func release_control(unit) -> void:
	if unit.special.has("mind_links"):
		for link in unit.special.mind_links:
			if alive(link) and link.special.get("controller")==unit:
				_clear_mind_control(link)
		unit.special.erase("mind_links")
	var target = unit.special.get("controlled")
	unit.special.erase("controlled")
	unit.special.erase("control_line_left")
	if alive(target) and target.special.get("controller") == unit:
		_clear_mind_control(target)

static func release_temporal(unit) -> void:
	var target = unit.special.get("temporal_target")
	if is_instance_valid(target) and target.special.get("temporal_by") == unit:
		if alive(target):Unit.YRTalents.remember(unit,target)
		target.special.erase("temporal_by")
		TemporalVisual.sync(target)
	unit.special.erase("temporal_target"); unit.special.erase("temporal_work"); unit.special.erase("temporal_skin")

static func channel(unit, delta: float) -> bool:
	var target = unit.special.get("temporal_target")
	if target == null: return false
	if not alive(target) or unit.attack_target != target or unit._stun_timer > 0.0 \
			or (unit.embarked_in != null and not OpenTopped.active(unit)) or not unit._weapon_target_valid(target) \
			or (OpenTopped.active(unit) and unit.global_position.distance_to(target.global_position) > float(unit.embarked_in.data.open_topped.warp_distance)):
		release_temporal(unit)
		return false
	unit.velocity = Vector2.ZERO
	unit.special.temporal_work = 0.0 if Unit.TankHero.rank(target,true)>=4 else float(unit.special.get("temporal_work", 0.0)) + TemporalVisual.erase_rate(unit) * delta
	TemporalVisual.sync(target)
	unit.special.channel_fx = float(unit.special.get("channel_fx", 0.0)) - delta
	if unit.special.channel_fx <= 0.0:
		unit.special.channel_fx = 0.15
		var look:String=unit.special.get("temporal_skin","")
		var aim:Vector2=target.art_center() if look=="time_fracture" else target.global_position
		Effects.spawn_beam(unit._weapon_muzzle(),aim,TemporalVisual.BEAM_COLOR,"laser",2.0,0.2,look)
	if unit.special.temporal_work >= target.max_hp:
		if unit.special.get("temporal_skin")=="time_fracture":
			Effects.Looks.Signature.spawn(Effects._host(),target.art_center(),"chrono_seam")
		release_temporal(unit)
		target.hp = 0.0
		target._die(unit, true)
	return true

static func concealed(unit: Unit, observer: String) -> bool:
	if unit.special.has("contact_reporters") and Unit.FactionCards.contact_exposes(unit,observer):return false
	if preload("res://scripts/units/expansion_2_infiltration.gd").hidden(unit):return preload("res://scripts/units/tanya_operations.gd").concealed(unit,observer)
	if preload("res://scripts/units/tanya_talents.gd").hidden(unit):return preload("res://scripts/units/tanya_operations.gd").concealed(unit,observer)
	if unit.side != observer and unit.special.has("echo_cloaked"): return not preload("res://scripts/units/tanya_operations.gd").detects(unit._battle_world(),observer,unit)
	if not BattleRequest.friendly(unit.side,observer) and float(unit.special.get("progression_v1",{}).get("dive_cloak",0))>0:return not preload("res://scripts/units/tanya_operations.gd").detects(unit._battle_world(),observer,unit)
	if Ra3Mirage.field_conceals(unit, observer): return not preload("res://scripts/units/tanya_operations.gd").detects(unit._battle_world(),observer,unit)
	if unit.side == observer or float(unit.special.get("reveal", 0.0)) > 0.0: return false
	var hidden: bool = Ra3Mirage.disguised(unit) or unit.special.has("disguise") or unit.unit_id == "MGTK" and mirage_at_rest(unit)
	if not hidden: return false
	var world = unit._battle_world()
	if world == null: return false
	if preload("res://scripts/units/tanya_operations.gd").detects(world,observer,unit):return false
	if unit.get_tree().has_group(&"psychic_sensors") and preload("res://scripts/world/yuri_support.gd").reveals(world,observer,unit.position): return false
	for other in unit.get_tree().get_nodes_in_group("disguise_detectors"):
		if other.side != observer or other.embarked_in != null or not alive(other) or not world.is_ancestor_of(other): continue
		if other.sight > 0.0 and other.global_position.distance_squared_to(unit.global_position) <= other.sight * other.sight: return false
	if unit.unit_id == "MGTK":
		# Contact exposure is local; keep group/owner/liveness checks live.
		var contacts: Array = world.neighborhood.nearby(unit.global_position, 55.0) if world is Battle else unit.get_tree().get_nodes_in_group("disguise_contact_infantry")
		for other in contacts:
			if not is_instance_valid(other) or not other.is_in_group("disguise_contact_infantry") or other.is_in_group("disguise_detectors"): continue
			if other.side != observer or other.embarked_in != null or not alive(other) or not world.is_ancestor_of(other): continue
			if other.global_position.distance_squared_to(unit.global_position) <= 55.0 * 55.0: return false
	return true

static func mirage_at_rest(unit: Unit) -> bool:
	return unit.special.get("mirage_enabled", true) and unit.velocity.length() < 1.0 and not unit.has_move_order

static func update_mirage_tree(unit) -> void:
	# Keep this tank's chosen tree across movement and reveal; re-rolling every
	# time it stops made the disguise visibly jump between unrelated trees.
	if not mirage_at_rest(unit) or float(unit.special.get("reveal", 0)) > 0:
		return
	if not unit.special.has("mirage_tree"):
		var rules: Dictionary = preload("res://scripts/world/special_rules.gd").data().general
		var trees := str(rules.defaultmiragedisguises).split(",", false)
		unit.special.mirage_tree = trees[randi_range(0, trees.size() - 1)].strip_edges()
		unit.queue_redraw()

static func draw_disguise(unit) -> bool:
	var visual := disguise_visual(unit)
	if visual.is_empty(): return false
	var rect := RA2Art.draw_rect(visual.art, unit.radius, visual.anchors, 0.0, unit.RA2_SPRITE_SCALE)
	unit.draw_body_sprite(visual.art, rect, RA2Art.src_rect(visual.art, visual.frame), Color(1, 1, 1, Ra3Mirage.CloakVisual.opacity(unit)))
	return true

static func disguise_visual(unit) -> Dictionary:
	if unit._dead or float(unit.special.get("reveal", 0.0)) > 0.0: return {}
	var id: String = unit.special.get("disguise", "")
	if unit.unit_id == "MGTK" and mirage_at_rest(unit): id = unit.special.get("mirage_tree", "")
	if Ra3Mirage.disguised(unit): id = "TREE01"
	if id.is_empty(): return {}
	var art := RA2Art.art(id)
	if art.is_empty(): return {}
	if unit.unit_id == "MGTK" or id == "TREE01": return {"art": art, "anchors": [0], "frame": 0}
	var sequence := RA2Art.seq(id)
	var facing := RA2Art.facing_index(unit.hull_angle, 8)
	var frame := maxi(0, RA2Art.seq_frame(sequence, "Walk" if unit.velocity.length() > 4.0 else "Guard", facing, int(unit._walk_phase * 6.0)))
	if unit.idle_pose != null and unit.idle_pose.appearance == id and unit.idle_pose.frame >= 0 and not unit._moving():
		frame = unit.idle_pose.frame
	return {"art": art, "anchors": range(8), "frame": frame}

static func draw_status(unit) -> void:
	preload("res://scripts/units/soviet_specials.gd").draw_status(unit)
	var label := ""
	var color := Color(0.55, 0.85, 1)
	if float(unit.special.get("chrono_left", 0.0)) > 0.0: label = "恢复 %.1fs" % unit.special.chrono_left
	if alive(unit.special.get("temporal_by")): label = "超时空抹除"; color = Color(0.7, 0.9, 1)
	var controller = unit.special.get("controller")
	if alive(controller):
		label = "心灵控制"
		color = Color(0.9, 0.5, 1)
		var art := RA2Art.fx("MINDANIM")
		if unit is Unit and not art.is_empty():
			var rect := RA2Art.fx_rect(art,int(unit._anim*float(art.fps))%int(art.count))
			unit.draw_texture_rect_region(art.tex,Rect2(Vector2(-rect.size.x*0.5,-unit.radius*2-rect.size.y),rect.size),rect)
	if unit is Building and not label.is_empty(): unit.draw_string(ThemeDB.fallback_font, Vector2(-25, -unit.radius * 2.8 - 35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
