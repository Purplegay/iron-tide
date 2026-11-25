extends RefCounted
## Three native WeaponSlotTurrets. All state is in the serialized special map.
const Aim = preload("res://scripts/units/ra3_gunship_aim.gd")
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func active(actor) -> Array:
	return ["front"] if actor.special.get("ra3_gun_mode", false) else ["side", "rear"]

static func states(actor) -> Dictionary:
	if not actor.special.has("ra3_mounts"):
		var all := {}
		for key in ["front", "side", "rear"]:
			var old_key := "gun" if key == "front" else "cannon"
			var old: Dictionary = actor.special.get("ra3_magazines", {}).get(old_key, {})
			var current: bool = key in active(actor)
			all[key] = {"used":int(actor.special.get("ra3_clip", 0)) if current else int(old.get("used", 0)),
				"remaining":maxf(0.0, actor._cd_timer) if current else float(old.get("remaining", 0.0)), "target":null, "flash":0.0}
		actor.special.ra3_mounts = all
	return actor.special.ra3_mounts

static func choose(actor, key: String):
	var state: Dictionary = states(actor)[key]
	var assigned = actor.attack_target
	if not AlliedAbilities.alive(assigned): return null
	# The nose gun retains its target for the clip; side cannons reacquire per shot.
	if key == "front" and int(state.used) > 0 and actor._weapon_target_valid(state.target): return state.target
	if actor._weapon_target_valid(assigned) and Aim.in_arc(actor, assigned, key): return assigned
	if actor._weapon_target_valid(state.target) and Aim.in_arc(actor, state.target, key): return state.target
	var best = null
	var distance := INF
	var world=actor._battle_world()
	# Gunship uses center distance and one target-independent weapon range.
	# Keep units-before-buildings order and strict ties; no cached target decisions.
	var fixed_range:bool=actor.unit_id==Ra3Expansion.HARBINGER and actor.is_air and not actor.data.has("anti_air_weapon") and not actor.data.has("special_weapon")
	for population in [world.units,world.buildings]:
		for target in population:
			if not is_instance_valid(target):continue
			if fixed_range:
				var reach:float=maxf(0.0,actor.global_position.distance_to(target.global_position))
				if reach>actor.attack_range or reach<actor.min_range:continue
			if not Aim.in_arc(actor,target,key) or not actor._weapon_target_valid(target):continue
			if not world.actor_visible_to(actor.side,target):continue
			var d:float=actor.position.distance_squared_to(target.position)
			if d<distance:best=target;distance=d
	return best

static func tick(actor, delta: float) -> void:
	var all := states(actor)
	for key in all:
		all[key].remaining = maxf(0.0, float(all[key].remaining) - delta)
		all[key].flash = maxf(0.0, float(all[key].flash) - delta)
		all[key].target = choose(actor, key) if key in active(actor) else null
	Aim.tick(actor, delta)
	refresh_display(actor)

static func refresh_display(actor) -> void:
	var remaining := INF
	for key in active(actor): remaining = minf(remaining, float(states(actor)[key].remaining))
	actor._cd_timer = remaining
	actor.special.ra3_clip = int(states(actor)[active(actor)[0]].used)

static func try_fire(actor) -> bool:
	if not AlliedAbilities.alive(actor) or AlliedAbilities.frozen(actor) or actor._stun_timer > 0.0 or actor.embarked_in != null: return false
	if actor.fire_stance == "none" or actor.repairing: return false
	if not actor.logistics.can_start_volley():return false
	var fired := false
	for key in active(actor):
		var state: Dictionary = states(actor)[key]
		state.target = choose(actor, key)
		if float(state.remaining) > 0.000001 or not actor._weapon_target_valid(state.target): continue
		if not Aim.ready(actor, state.target, key): continue
		fire(actor, state.target, key); fired = true
	refresh_display(actor)
	return fired

static func fire_direct(actor, target) -> void:
	for key in active(actor): fire(actor, target, key)
	refresh_display(actor)

static func fire(actor, target, key: String) -> void:
	var gun := key == "front"
	var state: Dictionary = states(actor)[key]
	state.target = target; state.flash = 0.5
	actor.special.ra3_fire_anim = 0.5
	actor.special.ra3_barrel = 1 if key == "rear" else 0
	actor._muzzle = 0.09; actor.special.reveal = 2.0
	actor._battle_world().reveal_attack(actor, target)
	if actor._ra3_model != null: actor._ra3_model._sample()
	var template: Dictionary = rules.mounts[key].weapon
	var scatter := Vector2.ZERO if gun else Vector2.from_angle(randf()*TAU)*sqrt(randf())*float(template.attrs.ScatterRadius)*1.5
	var shot := Ra3Expansion.make_shot(actor, target, target.position + scatter, "gun" if gun else "shell")
	if not gun: preload("res://scripts/units/ra3_gunship_shell.gd").setup(shot, actor, key, scatter)
	else: preload("res://scripts/units/ra3_gunship_tracer.gd").spawn(actor, target.position)
	Ra2Sfx.play("RA3_EXP_ALL_Gunship_MachineGunWeaponFire" if gun else "RA3_EXP_ALL_Gunship_ColliderCannonWeaponFire", actor.position)
	state.used = int(state.used) + 1
	if int(state.used) >= int(template.attrs.ClipSize):state.used = 0
	state.duration = interval(actor,key,state.used)
	state.remaining = state.duration

static func interval(actor,key:String,used:int) -> float:
	var template:Dictionary=rules.mounts[key].weapon
	var duration := 0.0
	var reload := 0.0
	for child: Dictionary in template.children:
		if child.type == "FiringDuration": duration = Ra3Expansion.RIOT.seconds(child.attrs.MinSeconds)
		if child.type == "ClipReloadTime": reload = Ra3Expansion.RIOT.seconds(child.attrs.MinSeconds)
	var shot:=duration / (1.2 if actor.veteran_level >= 3 else 1.0) * (1.0-clampf(actor.buff_value("cooldown"),0,0.85))
	return shot + (reload if used==0 else 0.0)
