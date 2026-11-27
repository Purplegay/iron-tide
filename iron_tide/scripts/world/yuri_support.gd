extends RefCounted

const MindLink = preload("res://scripts/core/yr_mind_control_link.gd")

static func clone_infantry(world, factory, unit) -> void:
	if not AlliedAbilities.infantry(unit) or unit.unit_id in GameData.UNIQUE_HERO_TYPES: return
	var owner: String = cloning_house(world, factory)
	for vat in world._warm_owner_buildings(factory.side):
		if not is_instance_valid(vat) or vat.building_id != "NACLON" or vat.side != factory.side or not vat.is_operational(): continue
		# Campaigns can represent multiple distinct houses on the same combat side.
		if cloning_house(world, vat) != owner: continue
		var exit: Vector2 = vat._spawn_point(unit.unit_id)
		if exit.is_finite() and world.spawn_unit(unit.unit_id, factory.side, exit, vat, true) != null:
			Ra2Sfx.play("CloningVatsCreate", vat.position)

static func cloning_house(world, building) -> String:
	if building.side == "enemy":
		match world.mission.get("id", ""):
			"yr_hollywood": return str(building.special.get("hollywood_house", ""))
			"yr_allied_first": return str(building.special.get("allied_first_room", ""))
			"yr_allied_finale": return str(building.special.get("allied_finale_room", ""))
	return world.economy_owner(building)

const SENSOR_RANGE := 15.0 * 55.0

static func senses(sensor, point: Vector2) -> bool:
	return sensor.is_operational() and sensor.position.distance_squared_to(point) <= SENSOR_RANGE * SENSOR_RANGE

static func reveals(world, observer: String, point: Vector2) -> bool:
	for sensor in world.get_tree().get_nodes_in_group(&"psychic_sensors"):
		if world.is_ancestor_of(sensor) and BattleRequest.friendly(sensor.side,observer) and senses(sensor,point): return true
	return false

static func active_beacons(world) -> Dictionary:
	var beacons := {}
	if world.mission.get("id") == "yr_head_games":
		for site in world.buildings:
			if not world.actor_alive(site) or not site.special.has("head_games_beacon"): continue
			var wing: int = site.special.head_games_beacon
			if not world.allied_state.has("head_games_freed_%d" % wing): beacons[wing] = site
	return beacons

static func control_source(target, beacons: Dictionary):
	var source = target.special.get("controller")
	if not AlliedAbilities.alive(source): source = target.special.get("dominator_source")
	if not AlliedAbilities.alive(source): source = beacons.get(target.special.get("head_games_wing", -1))
	if AlliedAbilities.alive(source) and source.side == target.side: return source
	return null

static func visible_control_source(world, target, beacons: Dictionary):
	var source = control_source(target, beacons)
	if source == null or (source is Unit and source.embarked_in != null) or (target is Unit and target.embarked_in != null): return null
	# Keep the control relation visible without selection or the retail attack-line timeout.
	if not world.actor_visible_to("ally", source) or not world.actor_visible_to("ally", target): return null
	return source

static func draw_control(world, overlay, target, beacons: Dictionary) -> void:
	var source = visible_control_source(world, target, beacons)
	if source == null: return
	# Mission beacons and the permanent dominator use project-specific links, not CaptureManager.
	var managed: bool = source == target.special.get("controller")
	MindLink.draw_link(overlay, MindLink.endpoints(source, target, managed), source._col, Time.get_ticks_msec())

static func draw_orders(world, overlay) -> void:
	for sensor in world.get_tree().get_nodes_in_group(&"psychic_sensors"):
		if not world.is_ancestor_of(sensor) or not BattleRequest.friendly(sensor.side,"ally") or not sensor.is_operational(): continue
		for unit in world.neighborhood.nearby(sensor.position,SENSOR_RANGE):
			if not unit is Unit or not world.actor_alive(unit) or BattleRequest.friendly(unit.side,"ally") or not senses(sensor,unit.position): continue
			if unit.embarked_in != null or not world.actor_visible_to("ally",unit): continue
			var target = unit.attack_target
			if not world.actor_alive(target) or not BattleRequest.friendly(target.side,"ally"): continue
			overlay.draw_line(Iso.dir(unit.position), Iso.dir(target.position), Color(0.92,0.38,0.93,0.7), 1.5)

static func launch(source, point: Vector2) -> bool:
	var world = source.battle
	if source.sw_type() == "PsychicReveal":
		if not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point): return false
		if world.fog != null: world.fog._reveal(source.side,point,825.0,5.0)
		Events.emit_radar_ping(point,"friendly_support")
		return true
	if not preload("res://scripts/units/soviet_specials.gd").can_aim_at(source, point): return false
	if source.sw_type() == "GeneticConverter":
		for victim in world.units.duplicate():
			if not world.actor_alive(victim) or victim.embarked_in != null or not AlliedAbilities.infantry(victim): continue
			if victim.position.distance_to(point) > 275 or victim.unit_id == "BRUTE": continue
			var pos: Vector2 = victim.position
			AlliedAbilities.consume(victim)
			world.spawn_unit("BRUTE", source.side, pos)
	else:
		for victim in world.units.duplicate():
			if not world.actor_alive(victim) or victim.embarked_in != null or victim.is_air or victim.position.distance_to(point) > 55: continue
			if not BattleRequest.friendly(source.side,victim.side) and not AlliedAbilities.flag(victim,"ImmuneToPsionics"):
				AlliedAbilities.change_side(victim,source.side)
				victim.special.dominator_source = source
		for site in world.buildings.duplicate():
			if world.actor_alive(site) and site.position.distance_to(point) <= 385:
				site.receive_hit(1000, "shell", {}, source)
	Events.emit_radar_ping(point, "alert")
	return true
