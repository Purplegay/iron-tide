extends "res://tests/cargo_query_actor.gd"
# Frozen pre-optimization target scan; no query-local passenger weapon reuse.
func _refresh_target() -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(2)
	if (_return_timer > 0.0 or special.has(preload("res://scripts/units/ai_counterfire.gd").RESUME)) and preload("res://scripts/units/ai_counterfire.gd").update(self): return
	if preload("res://scripts/units/ai_wall_clearance.gd").update(self): return
	if not str(special.get("action", "")).is_empty(): return
	if special.has("expansion_temporary") and preload("res://scripts/units/expansion_heroes.gd").follow_owner_target(self):return
	if special.has("commando_resume") and (not AlliedAbilities.alive(attack_target) or not _weapon_domain_valid(attack_target)):
		var resume: Vector2 = special.commando_resume
		order_move(resume, true)
	if (logistics.ammo_max > 0 or unit_id in ["CARRIER","V3"]) and not attack_ordered:
		attack_target = null
		return
	if weapon.is_empty() or (fire_stance == "none" and not attack_ordered):
		attack_target = null
		attack_ordered = false
		return
	# 玩家显式指定的目标：只要仍然有效就保持锁定（允许跨距离追击）
	if attack_ordered:
		var ot = attack_target
		if AlliedAbilities.alive(ot) and (ot.side != side or ForceFire.active(self, ot)) and attack_domain_valid(ot):
			return
		attack_ordered = false
		if not attack_move:
			# Target lost/dead: finish the explicit order instead of following its
			# old destination and silently turning the order into attack-move.
			_finish_target_order()
			return
	if special.has("finished_attack_route"):
		attack_target = null
		return
	if fire_stance == "return" and not attack_ordered and not attack_move and _return_timer <= 0.0:
		attack_target = null
		return
	if _burst_left > 0 and _weapon_target_valid(_burst_target):
		attack_target = _burst_target
		return
	# A wounded bystander inside the neutron sphere must not steal an active Flux focus.
	if unit_id==Ra3Expansion.FUTURE and special.has("phase_target") and is_same(attack_target,special.phase_target):
		var can_keep_focus:=fire_stance!="return" or attack_move or is_same(attack_target,special.get("retaliation_target"))
		if can_keep_focus and _weapon_target_valid(attack_target): return
	var best = null
	var best_score := -INF
	var group := BattleRequest.foes_group(side)
	var cover_world := _battle_world()
	if cover_world is Battle and _scan_grant_until < Engine.get_physics_frames() and not cover_world.ai_dispatch.allow_scan(cover_world,self):
		return
	_scan_grant_until = -1
	var check_cover: bool = cover_world is Battle and not cover_world.wall_cells.is_empty()
	# For a fixed-range weapon all candidate units share the same search distance.
	# Preserve per-target ranges for passengers, dedicated AA and naval weapons.
	var cargo_range := not logistics.passengers.is_empty() and AlliedAbilities.flag(self, "OpenTopped")
	var fixed_range := unit_id not in ["DRED", "DEST"] and not data.has("anti_air_weapon") and not cargo_range
	var outer_range := INF
	if cargo_range and unit_id=="BFRT":
		outer_range = OpenTopped.search_bound(self)
	elif fixed_range:
		outer_range = attack_range
	elif data.has("anti_air_weapon") and not cargo_range and unit_id not in ["DRED","DEST","SQD","BORIS"] and not CommandoCombat.handles(self):
		# Ordinary dual-weapon units select by target domain. Use the longer reach
		# only for rejection; candidate scoring still uses the actual weapon.
		var aa: Dictionary = data.elite_anti_air_weapon if veteran_level >= 2 else data.anti_air_weapon
		aa = OpenTopped.weapon(self,aa)
		var bonus := 0.0
		if special.has("academy_hero"): bonus += Ra2Damage.PX_PER_CELL
		if _deployed: bonus += maxf(0.0,float(special.get("hero_range_aura",0)))
		outer_range = maxf(float(_weapon_for_target(null).get("range",attack_range)),float(aa.get("range",0))+bonus)
	var search_limit := attack_range if hold_position or (fire_stance in ["defend","return"] and not attack_move) else maxf(sight,attack_range)
	var outer_limit := maxf(search_limit,outer_range)
	var outer_squared := outer_limit * outer_limit
	var retaliator = special.get("retaliation_target") if _return_timer > 0.0 else null
	var origin := global_position
	# Reuse the result slot, never target validity, across candidates. The range
	# query already visits every live passenger and checks the carrier weapon.
	var cargo_domain := [false] if cargo_range else []
	var local_search:bool=cover_world is Battle and cover_world.units.size()>=96 and outer_limit<cover_world.map_size and unit_id!="DLPH"
	var contacts:Array
	if local_search:
		var padding:float=maxf(cover_world.neighborhood.max_footprint,cover_world.neighborhood.max_unit_radius if unit_id=="DTRUCK" else 0.0)
		contacts=cover_world.neighborhood.nearby(origin,outer_limit+padding)
		if is_instance_valid(retaliator) and not contacts.has(retaliator):contacts.append(retaliator)
	else:
		contacts=get_tree().get_nodes_in_group(group)
	if unit_id=="DLPH":
		for host in get_tree().get_nodes_in_group("allies" if side=="ally" else "enemies"):
			if host is Unit and AlliedAbilities.alive(host.special.get("squid")):contacts.append(host.special.squid)
	preload("res://scripts/world/battle_call_counters.gd").iterations(2,contacts.size())
	# Resolve once only for weapons whose selection is independent of candidates.
	# This cache lives for this synchronous query, never across updates.
	var share_weapon := fixed_range and embarked_in == null and unit_id not in ["BORIS","SQD"] and not NATIVE_WEAPON_RESOLVERS.has(unit_id) and not special.has("academy_hero")
	var shared_weapon: Dictionary = {}
	for e in contacts:
		if not is_instance_valid(e) or (local_search and not e.is_in_group(group)): continue
		if is_finite(outer_limit) and not is_same(e,retaliator):
			var distance_sq := origin.distance_squared_to(e.global_position)
			if distance_sq > outer_squared:
				var padding := 0.0
				if e is Building: padding = e.footprint_radius()
				elif e is Unit and unit_id == "DTRUCK": padding = e.radius
				if distance_sq > (outer_limit + padding) * (outer_limit + padding): continue
		if e.is_queued_for_deletion() or e.get("hp") == null or float(e.hp) <= 0.0: continue
		if e is Unit and e.embarked_in!=null and not (unit_id=="DLPH" and NavalContact.grip_host(e)!=null):
			continue
		if not _automatic_target_allowed(e): continue
		if fire_stance == "return" and not attack_move and e != special.get("retaliation_target"): continue
		var d := CommandoCombat.distance_to(self, e)
		var candidate_weapon: Dictionary = {} if fixed_range else _weapon_for_target(e)
		var reach := attack_range if fixed_range else OpenTopped.command_range(self, e, candidate_weapon, cargo_domain)
		var search_range := reach if hold_position or (fire_stance in ["defend", "return"] and not attack_move) else maxf(sight, reach)
		if d < min_range or (d > search_range and not _can_pursue_attacker(e, reach)):
			continue
		if candidate_weapon.is_empty():
			if share_weapon and not shared_weapon.is_empty():
				candidate_weapon = shared_weapon
				preload("res://scripts/world/battle_call_counters.gd").iterations(69,1)
			else:
				candidate_weapon = _weapon_for_target(e)
				if share_weapon: shared_weapon = candidate_weapon
		var eligible: bool = cargo_domain[0] if cargo_range else _weapon_domain_valid(e, false, candidate_weapon)
		if not eligible:
			continue
		if check_cover and not CommandoCombat.building_c4(self, e) and WallArt.shot_blocked(cover_world, self, e, candidate_weapon): continue
		var score := TacticalTargeting.score(self, e, candidate_weapon, attack_target)
		if CommandoCombat.building_c4(self, e): score = 4.0 - d / maxf(1.0, sight)
		if score > best_score or (local_search and score==best_score and is_instance_valid(best) and best.is_greater_than(e)):
			best_score = score
			best = e
	attack_target = best
	if best == null and data.has("charge_weapon") and not has_move_order and not attack_ordered and not attack_move:
		var coil = preload("res://scripts/units/tesla_support.gd").nearby(self)
		if coil != null: AlliedAbilities.use(self, "tesla_charge", coil)

