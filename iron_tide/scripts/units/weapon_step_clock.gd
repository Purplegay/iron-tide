extends RefCounted
## Per-step clocks only; movement, target acquisition and abilities stay at 15 Hz.
## Snapshots live on the Unit and are never written into battle saves.

static func capture(actor: Unit) -> Dictionary:
	var group := "ra3_mounts" if actor.unit_id == Ra3Expansion.HARBINGER else "soviet_mounts"
	var field := "remaining" if group == "ra3_mounts" else "left"
	var values := {}
	for key in actor.special.get(group, {}):
		var left := float(actor.special[group][key][field])
		values[key] = left
	var result := {"group":group,"field":field,"values":values}
	if actor.special.has("tesla_charge_up"):
		result.charge_target = actor.special.tesla_charge_up.target
		result.charge_age = actor.special.tesla_charge_up.age
	return result

static func restore(actor: Unit, snapshot: Dictionary) -> void:
	var mounts: Dictionary = actor.special.get(snapshot.group, {})
	for key in snapshot.values:
		if mounts.has(key): mounts[key][snapshot.field] = snapshot.values[key]
	if snapshot.has("charge_age") and actor.special.has("tesla_charge_up") and actor.special.tesla_charge_up.target == snapshot.charge_target:
		actor.special.tesla_charge_up.age = snapshot.charge_age

static func advance(actor: Unit, delta: float) -> void:
	var group := "ra3_mounts" if actor.unit_id == Ra3Expansion.HARBINGER else "soviet_mounts"
	var field := "remaining" if group == "ra3_mounts" else "left"
	for mount: Dictionary in actor.special.get(group, {}).values():
		mount[field] = maxf(0.0, float(mount[field]) - delta)
	if actor.special.has("tesla_charge_up"):
		var charge: Dictionary = actor.special.tesla_charge_up
		charge.age = minf(Ra3Expansion.tesla_balance.heroic_charge_seconds, float(charge.age) + delta)
