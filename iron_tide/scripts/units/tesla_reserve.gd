extends RefCounted
## Extension-only talent. Store simulation time in the ordinary battle snapshot.
const ID := "tesla_reserve"
const STACKS := "tesla_reserve_stacks"
const CLOCK := "tesla_reserve_clock"

static func enabled(unit) -> bool:
	return unit.unit_id == "SHK" and Unit.YRTalents.enabled(unit, ID)

static func rule(unit) -> Dictionary:
	var definition: Dictionary = MetaProgress.talent_options("SHK")[ID]
	var rank := MetaProgress.talent_rank("SHK", ID, BattleRequest.combat_context.get("unit_talents", {}))
	return {"interval": float(definition.intervals[rank]), "limit": int(definition.stack_limits[rank]),
		"damage": float(definition.base if rank == 0 else definition.ranks[rank-1].value) * 0.01}

static func tick(unit, delta: float) -> void:
	if not enabled(unit) or not AlliedAbilities.alive(unit) or AlliedAbilities.frozen(unit) or delta <= 0: return
	var config := rule(unit)
	var stacks := int(unit.special.get(STACKS, 0))
	if stacks >= config.limit: return
	var elapsed := float(unit.special.get(CLOCK, 0.0)) + delta
	var added := floori((elapsed + 0.000001) / config.interval)
	stacks = mini(config.limit, stacks + added)
	unit.special[STACKS] = stacks
	if added>0:unit.queue_redraw()
	# Full reserves cannot bank time for another discharge.
	unit.special[CLOCK] = 0.0 if stacks == config.limit else maxf(0.0, elapsed - added * config.interval)

static func discharge(unit) -> float:
	if not enabled(unit): return 1.0
	var config := rule(unit)
	var stacks := clampi(int(unit.special.get(STACKS, 0)), 0, config.limit)
	unit.special.erase(STACKS)
	unit.special.erase(CLOCK)
	unit.queue_redraw()
	return 1.0 + stacks * config.damage

static func caption(unit) -> String:
	if not enabled(unit): return ""
	var config := rule(unit)
	var stacks := int(unit.special.get(STACKS, 0))
	var text := "蓄电 %d/%d · 下次攻击 +%d%%" % [stacks, config.limit, roundi(stacks * config.damage * 100)]
	if stacks < config.limit: text += " · 下一层 %.1f 秒" % maxf(0.0, config.interval - float(unit.special.get(CLOCK, 0)))
	return text
