extends RefCounted
## Explicit runtime schema; never deserialize executable Objects/resources from disk.
const Schema = preload("res://scripts/save/snapshot_schema.gd")
var records: Array = []
var objects: Array = []
var ids: Dictionary = {}
var error := ""

func register(object, kind: String) -> int:
	if ids.has(object): return ids[object]
	var id := objects.size()
	ids[object] = id
	objects.append(object)
	records.append({"kind": kind, "fields": {}})
	return id

func encode(value):
	if typeof(value) == TYPE_OBJECT:
		if not is_instance_valid(value): return null
		if value is WeakRef:
			return {"@weak": encode(value.get_ref())}
		if value is RandomNumberGenerator:
			return {"@rng": [value.seed, value.state]}
		if ids.has(value): return {"@ref": ids[value]}
		if value is Node: return null # A dead/removed actor cannot be resurrected by a target reference.
		var script = value.get_script()
		var kind: String = Schema.kind_for(script.resource_path if script != null else "")
		if kind.is_empty():
			error = "未登记的运行状态：" + value.get_class()
			return null
		return {"@ref": register(value, kind)}
	if value is Dictionary:
		var pairs: Array = []
		# Freed Node keys can break Dictionary's key-based iterator. Snapshot the
		# key array and omit invalid references, as decode already does for null keys.
		for key in value.keys():
			if typeof(key) == TYPE_OBJECT and not is_instance_valid(key): continue
			pairs.append([encode(key), encode(value[key])])
		return {"@dict": pairs}
	if value is Array:
		var result: Array = []
		for item in value: result.append(encode(item))
		return result
	return value

func decode(value):
	if value is Dictionary:
		if value.has("@ref"): return objects[value["@ref"]]
		if value.has("@weak"):
			var target = decode(value["@weak"])
			return weakref(target) if is_instance_valid(target) else null
		if value.has("@rng"):
			var rng := RandomNumberGenerator.new()
			rng.seed = value["@rng"][0]
			rng.state = value["@rng"][1]
			return rng
		var result := {}
		for pair in value["@dict"]:
			var key = decode(pair[0])
			if key != null: result[key] = decode(pair[1])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(decode(item))
		return result
	return value

func capture(world) -> Dictionary:
	# A codec may capture again after restore. Prior IDs belong to the previous graph.
	records=[];objects=[];ids={};error=""
	register(world, "battle")
	for actor in world.buildings + world.units:
		if world.actor_alive(actor): register(actor, "building" if actor is Building else "unit")
	for group in ["resource_nodes", "obstacles"]:
		for node in world.get_tree().get_nodes_in_group(group):
			if world.is_ancestor_of(node) and not node.is_queued_for_deletion():
				register(node, "ore" if group == "resource_nodes" else "obstacle")
	for shot in world.projectiles_root.get_children():
		if shot is Projectile and not shot.is_queued_for_deletion() and not shot._detonated:
			register(shot, "projectile")
	if is_instance_valid(world.fog): register(world.fog, "fog")
	if is_instance_valid(world.skirmish_ai): register(world.skirmish_ai, "ai")
	var index := 0
	while index < objects.size():
		var object = objects[index]
		var record: Dictionary = records[index]
		for field in Schema.fields(record.kind): record.fields[field] = encode(object.get(field))
		if object is Node2D:
			record["position"] = object.position
			record["visible"] = object.visible
			record["groups"] = Array(object.get_groups()).filter(func(g): return not str(g).begins_with("_"))
		if object is CollisionObject2D:
			record["collision"] = [object.collision_layer, object.collision_mask]
		if object is Unit: record["velocity"] = object.velocity
		index += 1
	# Runtime instance IDs are not portable between launches.
	var rally: Array = []
	for b in world.buildings:
		if ids.has(b) and world.rally_points.has(b.get_instance_id()):
			rally.append([ids[b], world.rally_points[b.get_instance_id()]])
	var firing: Array = []
	if world.fog != null:
		for old_id in world.fog.firing_positions:
			var actor = instance_from_id(old_id)
			firing.append([ids.get(actor, -1), world.fog.firing_positions[old_id].duplicate(true)])
	var context := {
		"mission_id": BattleRequest.mission_id, "skirmish": BattleRequest.skirmish,
		"config": BattleRequest.skirmish_config.duplicate(true), "mode": BattleRequest.rules_mode,
		"combat_context": BattleRequest.combat_context.duplicate(true),
		"camera": world.camera.position, "zoom": world.view_zoom,
		"iso": [Iso.K, Iso.MIRROR, Iso.USE_YAW], "collapsed": world.hud.unit_menu_collapsed,
		"gm": {}, "rally": rally, "firing": firing,
	}
	if world.fog != null:
		var remaining := {}
		for side in world.fog.sight_until:
			var cells := {}
			for cell_index in world.fog.sight_until[side]:
				var seconds: float = world.fog.sight_until[side][cell_index] - world.fog.sight_clock
				if seconds > 0.0: cells[cell_index] = seconds
			remaining[side] = cells
		context["death_sight"] = remaining
	if preload("res://scripts/world/native_maps.gd").has(world.map_layout()):
		context["native_map_sha"]=FileAccess.get_sha256("res://data/maps/%s.json"%world.map_layout())
	if context.mission_id == "yr_hollywood" and world.allied_state.get("hollywood", {}).get("briefing", false):
		var film = world.get_node_or_null("HollywoodFilm")
		if film != null and not film.is_queued_for_deletion():
			context["hollywood_briefing_clip"] = film.clip_id
	if context.mission_id == "yr_head_games" and world.allied_state.has("head_brief_stage"):
		var film = world.get_node_or_null("HollywoodFilm")
		if film != null and not film.is_queued_for_deletion() and film.clip_id in ["S07_F00E", "S07_P01E"]:
			context["head_briefing_clip"] = film.clip_id
		elif not world.allied_state.get("head_intro_done", true):
			context["head_briefing_clip"] = world.allied_state.get("head_resume_clip", "S07_P01E")
	for key in Schema.GM_FIELDS: context.gm[key] = GM.get(key)
	return {"records": records, "context": context, "special_rules": BattleSaves.digest(var_to_bytes(preload("res://scripts/world/special_rules.gd").data())),
		"death_rules": BattleSaves.digest(var_to_bytes(preload("res://scripts/core/yr_death_rules.gd").data()))}

func apply_fields(object, fields: Dictionary) -> void:
	for key in fields:
		var value = decode(fields[key])
		var current = object.get(key)
		if current is Array and value is Array and current.is_typed():
			var typed: Array = current.duplicate()
			typed.assign(value)
			value = typed
		object.set(key, value)

func restore(world, snapshot: Dictionary) -> void:
	var layout: String = world.map_layout()
	var native: bool = preload("res://scripts/world/native_maps.gd").has(layout)
	if native: BattleRequest.combat_context.native_ore_map = layout
	records = snapshot.records
	objects.resize(records.size())
	objects[0] = world
	world.cancel_pointer_gestures()
	world.clear_selection()
	Ra3Wreck.clear(world)
	if is_instance_valid(world._post_layer): world._post_layer.clear_exposure()
	for fx in world.get_tree().get_nodes_in_group("ra3_crash_fx"):
		if world.is_ancestor_of(fx):fx.free()
	for fx in world.get_tree().get_nodes_in_group("ra3_future_beams"):
		if world.is_ancestor_of(fx):fx.free()
	for fx in world.get_tree().get_nodes_in_group("reaper_particles"):
		if world.is_ancestor_of(fx):fx.free()
	for fx in world.get_tree().get_nodes_in_group("ra3_gunship_impacts"):
		if world.is_ancestor_of(fx):fx.free()
	for fx in world.get_tree().get_nodes_in_group("ra3_gunship_tracers"):
		if world.is_ancestor_of(fx):fx.free()
	for fx in world.get_tree().get_nodes_in_group("ra3_gunship_bullet_hits"):
		if world.is_ancestor_of(fx):fx.free()
	var tracks = world.get_node_or_null("VehicleTracks")
	if tracks != null: tracks.free() # Cosmetic marks belong to the previous world state.
	# Remove generated actors without death/production/settlement side effects.
	for actor in world.units + world.buildings:
		if is_instance_valid(actor): actor.free()
	world.units.clear()
	world.buildings.clear()
	for group in ["resource_nodes", "obstacles"]:
		for node in world.get_tree().get_nodes_in_group(group):
			if world.is_ancestor_of(node): node.free()
	for host in [world.projectiles_root, world.effects_root]:
		for child in host.get_children(): child.free()
	for index in range(1, records.size()):
		var kind: String = records[index].kind
		if kind == "fog": objects[index] = world.fog
		elif kind == "ai": objects[index] = world.skirmish_ai
		else: objects[index] = load(Schema.PATHS[kind]).new()
	# Initialize physics/art from saved unit definitions, then resolve every cross-reference.
	for index in range(1, records.size()):
		var record: Dictionary = records[index]
		var object = objects[index]
		if record.kind in ["unit", "building"]:
			var data: Dictionary = decode(record.fields.data)
			var side: String = record.fields.side
			if record.kind == "unit": object.setup(data, side, record.position)
			else: object.setup(data, side, record.position, world, true)
		if record.kind == "ore": object.resource_kind = record.fields.resource_kind
		if record.kind == "obstacle": object.radius = record.fields.radius
		if record.kind in ["unit", "building", "ore", "obstacle", "projectile"]:
			object.position = record.position
			var host = world.projectiles_root if record.kind == "projectile" else world
			if record.kind == "unit" and record.fields.side != "ally": host = world.enemy_root
			host.add_child(object)
	for index in records.size(): apply_fields(objects[index], records[index].fields)
	world.units = world.units.filter(func(u): return is_instance_valid(u))
	world.buildings = world.buildings.filter(func(b): return is_instance_valid(b))
	if is_instance_valid(world.skirmish_ai):
		world.skirmish_ai.tuning = GameData.skirmish_ai_tuning(world.skirmish_ai.difficulty)
		world.skirmish_ai._build_unit_pool()
	LightningStorm.restore(world)
	if not world.allied_state.get("yr_vehicle_debris", []).is_empty(): preload("res://scripts/core/yr_vehicle_debris.gd").restore(world)
	for index in range(1, records.size()):
		var record: Dictionary = records[index]
		var object = objects[index]
		if object is Node2D:
			object.position = record.position
			object.visible = record.visible
			for group in object.get_groups(): object.remove_from_group(group)
			for group in record.groups: object.add_to_group(group)
			object.queue_redraw()
		if object is CollisionObject2D:
			object.collision_layer = record.collision[0]
			object.collision_mask = record.collision[1]
		if object is Unit or object is Building:
			GameData.apply_hollywood_fx(object.data)
			if world.mission.get("id")=="yr_head_games": object.refresh_house_color()
		if object is Unit:
			if world.mission.get("id") == "yr_hollywood" and object.side == "enemy" and object.special.has("hollywood_house") and object.unit_id in preload("res://scripts/world/hollywood_bases.gd").RESIDENTS:
				object.side = "neutral"
				object.set_fire_stance("none")
				object.refresh_house_color()
			if object.side == "neutral":
				BattleRequest.sync_unit_target_groups(object, false)
			# setup() used the base unit outfit before the saved hero identity was restored.
			if object.special.has("academy_hero") or object.special.get("convoy_projected_skin",false): object.refresh_house_color()
			if object.unit_id=="YURIKO":
				object.yuriko_model.sync_actor(object,0.0)
				if world.actor_alive(object) and world.allied_state.get("yuriko_summoned",false) and (object.special.has("psi_support_left") or object.side=="ally"):
					world.yuriko_support=object
					object.special.get_or_add("psi_support_left",preload("res://scripts/units/yuriko.gd").deployment_duration(world))
			if object.special.has("psi_holder") or object.special.has("psi_flight"):preload("res://scripts/units/yuriko.gd").apply_lift_material(object)
			if object.special.has("psi_original_side"):preload("res://scripts/units/yuriko.gd").guard_marker(world,object)
			if object.special.has("peregrine"):preload("res://scripts/units/peregrine.gd").restore(object)
			# Older saves predate the scene group used for cloak-source lookup.
			if object.unit_id == Ra3Mirage.ID and not object.is_in_group(Ra3Mirage.SOURCE_GROUP):
				object.add_to_group(Ra3Mirage.SOURCE_GROUP)
			# Older saves may contain colliding passengers after a promotion.
			# Transport membership wins over that stale physical-state snapshot;
			# avoid set_stowed(), which would reset restored targets and reloads.
			if is_instance_valid(object.embarked_in):
				object.collision_layer = 0
				object.collision_mask = 0
			if object.unit_id == "SCHP": object.logistics.SiegeChopper.sync_collision(object)
			Ra3Mirage.restore_native_rules(object)
			if object.special.has("echo_cloaked") and not object.special.has("echo_bonus_left"):
				if object.special.has("echo_bonus"):
					object.special.echo_bonus_left=float(GameData.get_skill("ap_decoy").echo_seconds)
				else:object.special.erase("echo_cloaked")
			if object.ensure_source_veterancy(): object._refresh_veteran_bonuses(false)
			if object.unit_id=="R3TESLA":object._vet_need=Ra3Expansion.rank_requirement(object)
			object.logistics.ensure_squadron() # Pre-ASW destroyers saved an empty hangar.
			object.logistics.sync_deck_art()
			if object.unit_id in ["V3", "DRED"]: preload("res://scripts/units/soviet_advanced.gd").sync_rack(object)
			object.ensure_auto_harvest_skill()
			# Older extension saves could freeze SEALs in a deployed stance.
			if object.unit_id == "GHOST" and object.is_deployed():
				object._deployed = false
				object.crushable = object._mv("crushable", false) == true
				object._recompute_bonuses()
			AlliedAbilities.install(object)
			UnitSkillLayout.ensure(object)
			preload("res://scripts/units/electric_cards.gd").restore(object)
			if object.unit_id == "FV":
				object.logistics.capacity = 1
				object.logistics.size_limit = 1
			object._refresh_weapon_derived()
			if object.unit_id == "BORIS": preload("res://scripts/units/soviet_specials.gd").restore_boris_reload(object)
			AlliedAbilities.refresh_ifv_art(object)
			object.velocity = record.velocity
			object.path_field = null
			object._path_epoch = -1
		if object is Building:
			preload("res://scripts/buildings/tesla_pulse.gd").configure(object)
			if object.building_id == "CAOILD": object.refresh_house_color()
			preload("res://scripts/world/american_paradrop.gd").configure(object)
			world.Hollywood.configure_facility(object)
			if object.building_id == "GAYARD" and not object._is_repair:
				# Older saves carry both the previous tags and the derived capability.
				object._is_repair = GameData.get_building("GAYARD").tags.has("repair")
				if object._is_repair and not object.data.tags.has("repair"): object.data.tags.append("repair")
			if object.building_id == "GATECH" and object.superweapon.is_empty():
				object.superweapon = GameData.get_building("GATECH").superweapon
				object.data.superweapon = object.superweapon
			if object.building_id == "CAHSE01":
				preload("res://scripts/world/civilian_sites.gd").configure_house(object.data)
			# Older saves serialize the factory menu. Add products introduced after
			# that match without replacing its paid queue or captured ownership.
			if object.building_id in ["NAHAND","NAWEAP","NAYARD"]:
				for id in GameData.get_building(object.building_id).builds:
					if not object.buildable.has(id): object.buildable.append(id)
					if not object.data.builds.has(id): object.data.builds.append(id)
			if world.mission.get("id")=="yr_head_games" and GameData.HEAD_PRODUCTS.has(object.building_id):
				for product in GameData.units_from_building("yuri",object.building_id):
					if not object.buildable.has(product.id): object.buildable.append(product.id)
			if object.building_id=="NAWEAP" and BattleRequest.extensions_enabled():
				for data in GameData.units_from_building("soviet","NAWEAP"):
					if data.has("soviet_ra3") and not object.buildable.has(data.id):object.buildable.append(data.id)
			object._turret_art.setup(object.building_id)
			if object.building_id=="YAGGUN":
				object._turret_art.spin_pose=int(object.special.get("barrel_phase",0))
				# Old saves retain the building's weapon definitions. Refresh only
				# the projectile IDs so ownership, damage and reload are untouched.
				var retail: Dictionary = GameData.get_building("YAGGUN")
				var projectiles := {}
				for gun in retail.guns: projectiles[gun.ra2_weapon_id] = gun.ra2_projectile
				for gun in object.data.get("guns", []) + [object.data.weapon, object.weapon]:
					var id: String = gun.get("ra2_weapon_id", "")
					if projectiles.has(id): gun.ra2_projectile = projectiles[id]
			preload("res://scripts/rules/joint_ra2_production.gd").sync_catalog(object)
			preload("res://scripts/expedition/rules.gd").sync_training_permits(object)
			object.apply_mission_production_limits()
			# Foundation geometry is derived, not saved gameplay state. Field coverage
			# could mutate the serialized array into world coordinates. Rebuild it to
			# match the collision polygon created by setup(), also for ordinary buildings.
			object._fp_poly = Building.placement_poly(object.data)
			object._depth_anchor_ok = false
		if object is Obstacle: object._poly.polygon = object._pts
	if native:
		var old_ore_rules: bool = not world.allied_state.has("native_ore_version")
		if old_ore_rules:
			for node in world.get_tree().get_nodes_in_group("resource_nodes"):
				if node.get_parent() != world: continue
				node.amount = clampf(floorf(node.amount), 0, 12)
				node.max_amount = 12
				node.regen_rate = 0
				node.depleted = node.amount <= 0
			for miner in world.units:
				if not miner.is_harvester: continue
				if BattleRequest.extensions_enabled() and miner.unit_id == "CMIN":
					miner.cargo /= 25
					miner.cargo_gems /= 25
				var old_rate: float = float(miner.data.harvester.income_per_sec) if BattleRequest.extensions_enabled() else float(GameData.ra2_economy.adapter.harvest_units_per_second)
				miner.harvest_rate /= old_rate
				miner.cargo_cap = float(GameData.ra2_economy.storage.get(miner.unit_id, miner.cargo_cap))
			world.ore_growth_elapsed = 0
			world.allied_state.native_ore_version = 1
		preload("res://scripts/world/native_ore.gd").install_drills(world)
		world._refresh_pathing()
	var context: Dictionary = snapshot.context
	world.rally_points.clear()
	for pair in context.rally: world.rally_points[objects[pair[0]].get_instance_id()] = pair[1]
	preload("res://scripts/world/civilian_sites.gd").restore_crossings(world)
	preload("res://scripts/world/native_maps.gd").recover_low_bridge_ships(world)
	if world.mission.get("id")=="yr_head_games": world.HeadGames.recover_entry(world)
	if world.mission.get("id")=="yr_head_games":
		for id in ["CATRAN01","CATRAN02"]:
			var lamp=world.get_node_or_null("TransylvaniaLights/"+id)
			if lamp:lamp.visible=not world.allied_state.get("s07_dark_"+id,false)
	for child in world.get_children():
		if child is WaterLayer: child.rects = world.water_rects; child.queue_redraw()
	preload("res://scripts/world/storm_presentation.gd").sync(world)
	preload("res://scripts/units/soviet_specials.gd").sync_radiation(world)
	for actor in world.units + world.buildings:
		if actor.special.has("iron_left") or actor.special.has("airstrike_mark"):
			preload("res://scripts/units/soviet_specials.gd").sync_tint(actor)
	world._update_power()
	# Older saves may contain independent countdowns. Adopt the active provider's saved charge once.
	for building in world.buildings:
		if SupportSystems.shared_charge(building) and SupportSystems.charge_controller(building)==building:
			SupportSystems.sync_charge(building)
	if world.allied_state.has("time_shift"):
		var phase:int=world.allied_state.time_shift.phase
		world.TimeShift.bounds(world,1 if phase==3 else 2 if phase==4 else 0,phase in [1,2])
		world.TimeShift.sync_crossing_visual(world, world.allied_state.time_shift)
	world._update_depth_order()
	if world.fog != null:
		world.fog._scouts.clear()
		world.fog.sight_clock = 0.0
		world.fog.sight_until = context.get("death_sight", {"ally": {}, "enemy": {}}).duplicate(true)
		world.fog.firing_positions.clear()
		for i in context.firing.size():
			var pair: Array = context.firing[i]
			var key: int = objects[pair[0]].get_instance_id() if pair[0] >= 0 else -i - 1
			world.fog.firing_positions[key] = pair[1]
		world.fog.mask_image = null
		world.fog.texture = null
		world.fog.rebuild()
	# Restore world tokens before returning to the paused battle; no talent time advances.
	for unit in world.units:
		if unit.special.get("academy_hero")=="FV":
			if unit.special.hero_command_rank>=4:unit.add_to_group("convoy_observers")
			if unit.special.convoy.has("lamp"):unit.add_to_group("convoy_lamps")
		if unit.special.get("progression_v1",{}).has("capacitor"):
			preload("res://scripts/units/ground_capacitor_token.gd").sync(unit)
	Iso.K = context.iso[0]
	Iso.MIRROR = context.iso[1]
	Iso.USE_YAW = context.iso[2]
	Iso.apply_to(world.camera, context.zoom)
	world.camera.position = context.camera
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	# Panel layout is a local preference, not part of rewinding a battle.
	world.hud._restore_panel_preferences()
	world._emit_selection()
	Events.funds_changed.emit(world.funds)
	world.invalidate_ai_population()
	world.refresh_control_group_badges()
	if context.mission_id == "yr_hollywood" and world.allied_state.get("hollywood", {}).get("briefing", false):
		var clip: String = context.get("hollywood_briefing_clip", "")
		if clip in ["A02_F00E", "A02_P01E", "A02_P02E"]:
			world.allied_state.hollywood.resume_briefing_clip = clip
	if context.mission_id == "yr_head_games" and world.allied_state.has("head_brief_stage"):
		var clip = context.get("head_briefing_clip", "")
		if clip in ["S07_F00E", "S07_P01E"]:
			world.allied_state.head_resume_clip = clip
	world.hud.pause_after_load()
	Ra2Sfx.stop_all()
