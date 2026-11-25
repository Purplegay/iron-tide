extends RefCounted
## YR Explodes/DeathWeapon gates; bounded, non-recursive area damage dispatch.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Fx = preload("res://scripts/core/yr_death_fx.gd")
const KEY := "yr_death_blasts"

static func destroyed(actor) -> void:
	var id: String = actor.building_id if actor is Building else actor.unit_id
	var row := Rules.type_data(id)
	if row.is_empty() or actor.special.get("yr_death_resolved", false): return
	actor.special.yr_death_resolved = true
	var world = actor.battle if actor is Building else actor._battle_world()
	if world == null: return
	var explodes := Rules.flag(row, "explodes")
	if actor is Unit:
		var abilities: Array = Rules.names(row, "veteranabilities") if actor.veteran_level > 0 else []
		if actor.veteran_level > 1: abilities.append_array(Rules.names(row, "eliteabilities"))
		explodes = explodes or abilities.has("EXPLODES")
	explodes = explodes or bool(actor.special.get("yr_causes_death_weapon", false))
	if explodes:
		var weapon_id := str(row.get("deathweapon", row.get("primary", ""))).to_upper()
		var fallback := weapon_id.is_empty()
		if fallback: weapon_id = str(Rules.data().combat.get("deathweapon", "DefaultDeathWeapon")).to_upper()
		var weapon: Dictionary = Rules.data().weapons.get(weapon_id, {})
		var amount := float(row.get("strength", 0)) * 0.5 if fallback else float(weapon.get("damage", 0)) * float(row.get("deathweapondamagemodifier", 1))
		if not weapon.is_empty():
			var look:=Effects.Looks.current(actor) if id in ["TERROR","DTRUCK"] else ""
			queue_blast(world, actor.global_position, actor.side, amount, str(weapon.get("warhead", "")), str(weapon.get("report", "")), true, look, str(weapon.get("anim", "")))
	if id in ["DTRUCK", "NANRCT"] and explodes:
		var weapon: Dictionary = Rules.data().weapons["DEMOBOMB" if id == "DTRUCK" else "NUKEPAYLOAD"]
		preload("res://scripts/units/soviet_specials.gd").add_radiation(world, actor.position, Ra2Damage.cells(weapon.warhead), 100.0 if id == "DTRUCK" else 500.0, actor.side)
	if actor is Unit:
		preload("res://scripts/units/vehicle_crew.gd").eject(actor)
	preload("res://scripts/core/yr_vehicle_debris.gd").spawn(actor)

static func queue_blast(world, point: Vector2, side: String, damage: float, warhead: String, sound := "", show_impact := true, look := "", weapon_anim := "") -> void:
	if damage <= 0.0 or not Ra2Damage.has(warhead): return
	if not world.allied_state.has(KEY): world.allied_state[KEY] = []
	var blast := {"point": point, "side": side, "damage": damage, "warhead": warhead, "sound": sound, "show_impact": show_impact}
	if not weapon_anim.is_empty(): blast["weapon_anim"] = weapon_anim
	if not look.is_empty(): blast["look"] = look
	world.allied_state[KEY].append(blast)
	# Lethal damage can enqueue another death; no recursive chain and no lost tail.
	if not world.has_meta(KEY): drain(world)

static func drain(world) -> void:
	if world.has_meta(KEY): return
	world.set_meta(KEY, true)
	var queue: Array = world.allied_state.get(KEY, [])
	var budget := 64
	while not queue.is_empty() and budget > 0:
		var blast: Dictionary = queue.pop_front()
		budget -= 1
		apply_blast(world, blast)
	world.remove_meta(KEY)

static func apply_blast(world, blast: Dictionary) -> void:
	var point: Vector2 = blast.point
	var warhead := str(blast.warhead)
	preload("res://scripts/world/bridge_damage.gd").blast(world,point,float(blast.damage),warhead)
	# A dead origin cannot safely be a retaliation target or gain veterancy.
	# House ownership stays in the record; friendly fire follows the warhead.
	for target in world.units.duplicate() + world.buildings.duplicate():
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target._dead or target.hp <= 0.0: continue
		if target is Unit and (is_instance_valid(target.embarked_in) or target.is_air_target()): continue
		if BattleRequest.friendly(target.side,blast.side) and Ra2Damage._extra(warhead, "AffectsAllies").to_lower() in ["no", "false", "0"]: continue
		var distance: float = target.global_position.distance_to(point)
		if target is Building:
			distance = maxf(0.0, distance - target.footprint_clearance(target.global_position.direction_to(point)))
		if not Ra2Damage.in_spread(distance, warhead): continue
		var amount := Ra2Damage.target_damage(float(blast.damage), warhead, target, distance)
		if amount > 0.0: target.receive_hit(amount, "explosive", {}, null, warhead)
	if blast.get("show_impact", true) and world.position_visible_to("ally", point):
		if blast.has("weapon_anim"):
			Ra2Fx.play(world.effects_root, point, blast.weapon_anim)
		var animation := Ra2Damage.pick_impact_anim(warhead, float(blast.damage))
		if not animation.is_empty() and Fx.play(world, point, animation) == null:
			# Weapon effects such as CRIVEXP carry their Report in the combat FX atlas.
			Ra2Fx.play(world.effects_root, point, animation, 1.0, Ra2Damage.is_bright(warhead))
		if blast.get("look","")=="love_peace": Effects.Looks.impact(world.effects_root,point,"love_peace")
		if not str(blast.sound).is_empty(): Ra2Sfx.play(str(blast.sound), point)

static func tick(world) -> void:
	if world.paused or world.ended or world.get_tree().paused: return
	drain(world)
