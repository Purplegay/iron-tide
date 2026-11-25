extends RefCounted
## Original art.ini: D idle, A extending, B working, C retracting.
## Reuse the saved building animation state/time; this never changes repair HP or cost.
const LAYERS := {"repair_extend": "specialanim", "repair_work": "specialanimtwo", "repair_retract": "specialanimthree"}

static func duration(building, kind: String) -> float:
	for layer in building._ra2_anim:
		if layer.kind == kind:
			var state: Dictionary = building._anim_layer(layer)
			return (state.loopEnd - state.loopStart + 1) * 60.0 / maxf(1.0, state.rate)
	return 0.01

static func tick(building) -> void:
	var extending := duration(building, "specialanim")
	var retracting := duration(building, "specialanimthree")
	if building._repair_active and building.is_operational():
		if building._anim_state == "repair_retract":
			var progress := 1.0 - clampf(building._anim_group_t / retracting, 0.0, 1.0)
			building._set_anim_state("repair_extend")
			building._anim_group_t = progress * extending
		elif building._anim_state not in ["repair_extend", "repair_work"]:
			building._set_anim_state("repair_extend")
		if building._anim_state == "repair_extend" and building._anim_group_t >= extending:
			var remaining: float = building._anim_group_t - extending
			building._set_anim_state("repair_work")
			building._anim_group_t = remaining
	else:
		if building._anim_state in ["repair_extend", "repair_work"]:
			var progress := clampf(building._anim_group_t / extending, 0.0, 1.0) if building._anim_state == "repair_extend" else 1.0
			building._set_anim_state("repair_retract")
			building._anim_group_t = (1.0 - progress) * retracting
		if building._anim_state != "repair_retract" or building._anim_group_t >= retracting:
			if building._anim_state != "idle": building._set_anim_state("idle")

static func visible(building, kind: String) -> bool:
	return kind == LAYERS.get(building._anim_state, "idleanim")

static func frame(building, state: Dictionary) -> int:
	var count := maxi(1, int(state.loopEnd - state.loopStart + 1))
	var index := int(building._anim_group_t * float(state.rate) / 60.0)
	return int(state.loopStart) + (posmod(index, count) if building._anim_state == "repair_work" else mini(count - 1, index))
