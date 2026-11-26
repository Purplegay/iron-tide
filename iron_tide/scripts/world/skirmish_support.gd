extends RefCounted
const Shift = preload("res://scripts/world/chronoshift.gd")
const Ops = preload("res://scripts/world/skirmish_operations.gd")

static func consider(ai, launcher, visible: Array) -> void:
	var world = ai.battle
	match launcher.sw_type():
		"AmerParaDrop", "ParaDrop":
			for target in visible:
				if not target is Building or target.data.get("tags",[]).has("civilian"): continue
				for i in 8:
					var at: Vector2 = target.position + Vector2.from_angle(i * TAU / 8.0) * 230
					if world.position_visible_to(ai.house_id, at) and launcher.fire_superweapon(at): return
		"PsychicDominator", "GeneticConverter":
			for target in visible:
				if launcher.sw_type() == "GeneticConverter" and not AlliedAbilities.infantry(target): continue
				if launcher.fire_superweapon(target.position): return
		"SpyPlane", "PsychicReveal":
			if world.fog == null: return
			var goal:Vector2=ai.objective()
			for point in [goal, world.allied_state.get("oil_mid_point",goal), (goal+ai.base_center)*0.5]:
				if not world.position_visible_to(ai.house_id, point):
					launcher.fire_superweapon(point)
					return
		"ForceShield":
			for site in world.buildings:
				if not world.actor_alive(site) or site.side != ai.house_id or site.under_construction: continue
				if not (site.is_hq or site.is_refinery() or not site.buildable.is_empty() or not site.superweapon.is_empty()): continue
				if site.hp >= site.max_hp * 0.75 or site.special.has("force_shield_left") or site.special.has("iron_left"): continue
				if visible.any(func(attacker): return attacker.attack_target == site):
					launcher.fire_superweapon(site.position)
					return
		"ChronoSphere":
			send_armour(ai, launcher, visible)

static func send_armour(ai, launcher, visible: Array) -> void:
	var world = ai.battle
	for target in visible:
		if not target is Building or target.data.get("tags", []).has("civilian"): continue
		for tank in world.units:
			if not armour(world, tank,ai.house_id) or tank.position.distance_to(target.position) < 600: continue
			var group := Shift.actors(world, tank.position, ai.house_id)
			if group.is_empty() or not group.all(func(u): return armour(world, u,ai.house_id)): continue
			for i in 8:
				var direction: Vector2 = target.position.direction_to(tank.position).rotated(i * TAU / 8)
				var drop: Vector2 = target.position + direction * (target.footprint_clearance(direction) + 150)
				if not world.position_visible_to(ai.house_id, drop): continue
				if not group.all(func(u): return Shift.landing_clear(world, u, drop + u.position - tank.position, group)): continue
				if launcher.fire_superweapon(drop, tank.position):
					for unit in group:
						ai._army.erase(unit)
						Ops.order_attack(unit, target)
					return

static func armour(world, unit, owner := "enemy") -> bool:
	return world.actor_alive(unit) and unit.side == owner and unit.embarked_in == null and not unit.is_air and not unit.is_naval and not unit.is_harvester and not AlliedAbilities.infantry(unit) and not AlliedAbilities.flag(unit, "Organic") and not unit.weapon.is_empty() and unit.deploy_building_id().is_empty() and not unit.is_deployed() and not unit.repairing and not unit.special.has("ai_oil_post")
