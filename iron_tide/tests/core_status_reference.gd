extends AlliedAbilities
static func original_tick_actor(actor, delta: float) -> void:
	if actor is Unit:
		if actor.unit_id == Ra3Mirage.ID or actor.has_meta(Ra3Mirage.CloakVisual.STATE) or actor.get_tree().has_group(Ra3Mirage.SOURCE_GROUP):
			Ra3Mirage.tick(actor, delta)
		if Ra3Expansion.handles(actor): Ra3Expansion.tick(actor, delta)
	if not alive(actor): return
	var state: Dictionary=actor.special
	if state.has("c4_left") or frozen(actor) or alive(state.get("controlled")): actor.queue_redraw()
	for key in STATUS_TIMERS:
		if state.has(key):
			var before: float = state[key]
			state[key] = maxf(0.0, before - delta)
			if before > 0.0 and state[key] == 0.0: actor.queue_redraw()
	if actor is Unit and actor.unit_id == "MGTK": update_mirage_tree(actor)
	if state.has("c4_left"):
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
		var original: String = state.get("original_side", actor.side)
		state.erase("controller")
		state.erase("original_side")
		change_side(actor, original)
		state=actor.special
	if state.has("temporal_by"):
		var owner = state.temporal_by
		if not alive(owner) or owner.special.get("temporal_target") != actor:
			state.erase("temporal_by")
	if state.has("temporal_by") or state.has("c4_left") or actor.has_meta(TemporalVisual.STATE) or actor.has_meta("time_fracture"):
		TemporalVisual.sync(actor)

