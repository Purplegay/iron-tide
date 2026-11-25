extends RefCounted
## The score observes combat events and saves its simulation-time windows with the battle.
const KEY := "battle_music_director"
const LOSS_WINDOW := 20.0
const PUSH_WINDOW := 120.0
const YURIKO_KILLS := 10
const QUIET_WINDOW := 20.0

static func yuriko_quiet(score: Dictionary) -> bool:
	return score.has("yuriko_last_contact") and float(score.time) - float(score.yuriko_last_contact) >= QUIET_WINDOW

static func state(world) -> Dictionary:
	return world.allied_state.get_or_add(KEY, {
		"time": 0.0, "entered": 0.0, "last_advantage_exit": -PUSH_WINDOW,
		"advantage": false, "structures": [], "family": "battle",
	})

static func begin(world, restored: bool) -> void:
	if not restored: world.allied_state.erase(KEY)
	var score := state(world)
	if restored and (score.has("yuriko_kills") or score.has("yuriko_last_contact")) and preload("res://scripts/units/yuriko.gd").hero(world) == null:
		clear_yuriko_score(score)
	var mood := str(score.get("mood", "victory" if score.advantage else "battle"))
	Music.set_meta("director_state", score)
	Music.set_context("results" if world.ended else "battle", world.roster_faction("ally"),
		not score.get("engaged", false), score.get("map_track", ""), score.get("combat_id", ""), mood, yuriko_quiet(score))
	if world.ended: return
	score.combat_id = Music.combat_id
	score.map_track = Music.exploration_id
	score.mood = mood
	Music.uprising_triggered = score.family == "uprising"

static func superweapon_used(world, side: String) -> void:
	if world.ended or Music.context != "battle" or side == "neutral": return
	if side != "ally" and BattleRequest.friendly("ally", side): return
	Music.play_cue("superweapon_used" if side == "ally" else "enemy_superweapon")
	engage(state(world))

static func exchange(world, attacker, target) -> void:
	var score = world.allied_state.get(KEY)
	if score == null: return
	if not Music.exploring:
		var last_contact = score.get("yuriko_last_contact")
		if last_contact == null or last_contact == score.time: return
	if not (attacker is Unit or attacker is Building) or not (target is Unit or target is Building): return
	if attacker.side != "ally" and target.side != "ally": return
	if attacker.side == "neutral" or target.side == "neutral" or BattleRequest.friendly(attacker.side, target.side): return
	engage(score)

static func engage(score: Dictionary) -> void:
	score.engaged = true
	Music.engage()
	if score.has("yuriko_last_contact"):
		score.yuriko_last_contact = score.time
		Music.set_yuriko_quiet(false)

static func trigger_uprising(world) -> void:
	if world.ended: return
	var score := state(world)
	if score.family == "uprising": return
	score.family = "uprising"
	Music.uprising_triggered = true
	if score.get("engaged", false) and score.get("mood", "battle") == "battle" and Music.cue.is_empty():
		Music.play_cue("uprising")

static func clear_yuriko_score(score: Dictionary) -> void:
	score.erase("yuriko_kills")
	score.erase("yuriko_last_contact")

static func yuriko_departed(world) -> void:
	clear_yuriko_score(state(world))
	Music.end_yuriko_music()

static func death(world, victim, killer) -> void:
	if not is_instance_valid(world) or world.ended or victim.side == "neutral": return
	if victim is Unit and victim.unit_id == "YURIKO" and victim.side == "ally":
		yuriko_departed(world)
	if not is_instance_valid(killer): return
	var attacker_side: String
	if killer is Projectile: attacker_side = killer.owner_side
	elif killer is Unit or killer is Building: attacker_side = killer.side
	else: return
	if attacker_side == "neutral" or BattleRequest.friendly(attacker_side, victim.side): return
	if attacker_side != "ally" and victim.side != "ally": return
	if victim.special.get("house_eliminated", false) or victim.special.has("expansion_temporary"): return
	var score := state(world)
	if victim is Building:
		var tags: Array = victim.data.get("tags", [])
		if "defense" in tags or "wall" in tags or "civilian" in tags: return
		var structures: Array = score.structures if attacker_side == "ally" else score.get_or_add("lost_structures", [])
		structures.append(score.time)
	elif victim is Unit and victim.unit_id not in world.SUPPORT_FLIGHTS and not AlliedAbilities.flag(victim, "DontScore"):
		var events: Array = score.get_or_add("losses" if victim.side == "ally" else "kills", [])
		events.append(score.time)
		if attacker_side == "ally" and not score.has("yuriko_last_contact"):
			var source = killer.shooter() if killer is Projectile else killer
			if is_instance_valid(source) and source is Unit and source.unit_id == "YURIKO" and world.actor_alive(source):
				score.yuriko_kills = int(score.get("yuriko_kills", 0)) + 1
				if score.yuriko_kills == YURIKO_KILLS:
					score.yuriko_last_contact = score.time if score.get("engaged", false) else float(score.time) - QUIET_WINDOW
					Music.set_yuriko_quiet(yuriko_quiet(score))

static func trim_window(events: Array, cutoff: float) -> void:
	while not events.is_empty() and float(events[0]) < cutoff:
		events.pop_front()

static func tick(world, delta: float) -> void:
	if world.ended or world.paused or Music.context != "battle": return
	var score := state(world)
	score.time = float(score.time) + delta
	var now: float = score.time
	var losses: Array = score.get_or_add("losses", [])
	var kills: Array = score.get_or_add("kills", [])
	trim_window(losses, now - LOSS_WINDOW)
	trim_window(kills, now - LOSS_WINDOW)
	trim_window(score.structures, now - PUSH_WINDOW)
	var lost_structures: Array = score.get_or_add("lost_structures", [])
	trim_window(lost_structures, now - PUSH_WINDOW)
	if score.has("yuriko_last_contact"): Music.set_yuriko_quiet(yuriko_quiet(score))
	if not score.get("engaged", false): return
	var mood := str(score.get("mood", "battle"))
	var next := "battle"
	if (losses.size() >= 3 and 2 * kills.size() <= losses.size()) or (lost_structures.size() >= 5 and lost_structures.size() > score.structures.size()):
		next = "disadvantage"
	elif mood == "victory" and now - float(score.entered) < PUSH_WINDOW:
		next = "victory"
	elif mood != "victory" and now - float(score.entered) >= LOSS_WINDOW and now - float(score.last_advantage_exit) >= PUSH_WINDOW and score.structures.size() >= 5:
		next = "victory"
	if next == mood: return
	if mood == "victory": score.last_advantage_exit = now
	score.mood = next
	score.advantage = next == "victory"
	score.entered = now
	Music.set_battle_stage(next)
