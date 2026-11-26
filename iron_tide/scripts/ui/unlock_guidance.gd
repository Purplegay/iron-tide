extends RefCounted
## Read-only projection of the current prerequisite rules, never a production gate.

var battle
var owned: Array = []
var preferences: Dictionary = {}
var _token_options: Dictionary = {}

func _init(match_battle, choices: Dictionary = {}) -> void:
	battle = match_battle
	owned = battle.owned_building_ids()
	preferences = choices.duplicate()

func _name(id: String) -> String:
	return GameData.prereq_name(id)

func _options(token: String) -> Array:
	if not GameData.RA2_TOKEN_TAGS.has(token):
		return [token]
	if _token_options.has(token): return _token_options[token]
	var result: Array = GameData.RA2_TOKEN_IDS.get(token, []).duplicate()
	for building in GameData.buildings:
		if GameData.supplies_prerequisite(str(building.id), token) and not result.has(building.id):
			result.append(building.id)
	var faction: String = battle.roster_faction()
	_token_options[token] = result.filter(func(id): return owned.has(id) or GameData.building_index.get(id, {}).get("faction", "") == faction)
	return _token_options[token]

func _status(id: String) -> String:
	if owned.has(id):
		return "已满足"
	for building in battle.buildings:
		if is_instance_valid(building) and building.side == "ally" and not building.is_dead() and building.building_id == id:
			return "施工中"
	if int(battle.struct_ready.get(id, 0)) > 0:
		return "待放置"
	var jobs: Array = battle.structure_jobs(battle.structure_category(id))
	for i in jobs.size():
		if str(jobs[i].id) == id:
			return "建造中" if i == 0 else "排队中"
	return "未建造"

func _row(token: String, satisfied: bool) -> String:
	var names := PackedStringArray()
	var status := "已满足" if satisfied else "未建造"
	for id in _options(token):
		names.append(_name(str(id)))
		if not satisfied and _status(str(id)) != "未建造":
			status = _status(str(id))
	return "[%s] %s%s" % [status, " / ".join(names), "（任一）" if names.size() > 1 else ""]

func _tokens(id: String) -> Array:
	var result: Array = []
	for token in GameData.production_prerequisites(id, battle.allied_state):
		var normalized := _display_token(id, str(token).strip_edges().to_upper())
		if not normalized.is_empty() and not result.has(normalized):
			result.append(normalized)
	return result

func _missing(id: String) -> Array:
	var result: Array = []
	for token in GameData.ra2_missing_prereqs(id, owned, battle.allied_state):
		var displayed := _display_token(id, str(token))
		if not result.has(displayed): result.append(displayed)
	return result

func _display_token(id: String, token: String) -> String:
	return token

func _producer(id: String) -> String:
	var producer := str(GameData.get_unit(id).get("built_at", ""))
	return producer

## A feasible dependency-first example, not a cheapest or fastest build order.
## Alternatives are tried independently so a cyclic branch cannot poison the plan.
func _plan_token(token: String, visiting: Array, plan: Array, contexts: Array) -> bool:
	var options := _options(token)
	for id in options:
		if owned.has(id):
			return true
	# An alternative cannot unlock a requirement by first needing that same
	# requirement through another building (e.g. satellite -> lab -> radar).
	var marker := "requirement:" + token
	if visiting.has(marker):
		return false
	var ordered: Array = []
	var preferred := str(preferences.get(token, ""))
	if options.has(preferred):
		ordered.append(preferred)
	for id in options:
		if _status(str(id)) != "未建造" and not ordered.has(id):
			ordered.append(id)
	for id in options:
		if not ordered.has(id):
			ordered.append(id)
	var ancestors: Array = visiting.duplicate()
	ancestors.append(marker)
	for id in ordered:
		var trial: Array = plan.duplicate()
		var trace: Array = contexts.duplicate(true)
		if _plan_candidate(str(id), ancestors, trial, trace):
			plan.assign(trial)
			if options.size() > 1:
				trace.append({"token": token, "ancestors": ancestors, "selected": str(id)})
			contexts.assign(trace)
			return true
	return false

func _plan_candidate(id: String, visiting: Array, plan: Array, contexts: Array) -> bool:
	if owned.has(id):
		return true
	if not GameData.mission_tech_block_reason(id).is_empty():
		return false
	if visiting.has(id) or not GameData.building_index.has(id) or not battle.country_block_reason(id).is_empty():
		return false
	if _status(id) == "未建造":
		var branch: Array = visiting.duplicate()
		branch.append(id)
		for pre in _missing(id):
			if not _plan_token(str(pre), branch, plan, contexts):
				return false
	if not plan.has(id):
		plan.append(id)
	return true

func _alternatives(contexts: Array) -> Array:
	var groups := {}
	var labels := {"RADAR": "雷达科技", "PROC": "矿石精炼", "POWER": "供电",
		"TECH": "实验室", "BARRACKS": "兵营"}
	for context in contexts:
		var token := str(context.token)
		if not groups.has(token):
			groups[token] = {"token": token, "name": str(labels.get(token, token)),
				"selected": str(context.selected), "options": []}
			for id in _options(token):
				groups[token].options.append({"id": str(id), "name": _name(str(id)),
					"state": _status(str(id)), "can_choose": true, "reason": ""})
		for option in groups[token].options:
			var feasible := _plan_candidate(str(option.id), context.ancestors, [], [])
			option.can_choose = bool(option.can_choose) and feasible
			if not feasible:
				var reason: String = battle.country_block_reason(str(option.id))
				option.reason = reason if not reason.is_empty() else "前置科技也依赖此条件，当前无法独立解锁"
	return groups.values()

func describe(id: String) -> Dictionary:
	if not GameData.is_ra2(id):
		return {"detail": "", "summary": ""}
	var mission_reason := GameData.mission_product_block_reason(id, owned)
	if not mission_reason.is_empty():
		return {"detail": "解锁条件\n" + mission_reason, "summary": mission_reason, "restriction": mission_reason}
	if not GameData.get_unit(id).is_empty():
		var roster_reason := GameData.unit_production_block_reason(id, battle.allied_state)
		if not roster_reason.is_empty():
			return {"detail": "解锁条件\n" + roster_reason, "summary": "无法仅靠建造前置建筑解锁", "restriction": roster_reason}
	var country: String = battle.country_block_reason(id)
	if not country.is_empty():
		return {"detail": "解锁条件\n" + country + "\n本局无法通过建造解锁，请在开局选择对应国家。",
			"summary": "本局无法通过建造解锁", "restriction": country}
	var lines := PackedStringArray(["解锁条件"])
	var missing := _missing(id)
	for token in _tokens(id):
		lines.append(_row(str(token), not missing.has(token)))
	var producer := _producer(id)
	if not producer.is_empty() and not _tokens(id).has(producer):
		lines.append(_row(producer, owned.has(producer)) + "（生产建筑）")
		if not owned.has(producer):
			missing.push_front(producer)
	if missing.is_empty():
		lines.append("科技条件已满足")
		return {"detail": "\n".join(lines), "summary": ""}
	var plan: Array = []
	var contexts: Array = []
	var feasible := true
	for token in missing:
		if not _plan_token(str(token), [id], plan, contexts):
			feasible = false
	var alternatives := _alternatives(contexts) if feasible else []
	var notices := PackedStringArray()
	for group in alternatives:
		var preferred := str(preferences.get(group.token, ""))
		if not preferred.is_empty() and preferred != str(group.selected):
			notices.append("所选%s当前不可用，改用%s" % [_name(preferred), _name(str(group.selected))])
	var steps := PackedStringArray()
	var navigation: Array = []
	for bid in plan:
		var state := _status(str(bid))
		var data: Dictionary = GameData.get_building(str(bid))
		navigation.append({"id": str(bid), "name": _name(str(bid)), "state": state,
			"can_locate": not data.get("tags", []).has("hq") and float(data.get("cost", 0)) > 0})
		var action := "建造"
		match state:
			"待放置": action = "放置"
			"施工中": action = "等待施工完成："
			"建造中": action = "等待建造并放置："
			"排队中": action = "等待排队建造并放置："
		if data.get("tags", []).has("hq"):
			action = "恢复"
			lines.append("恢复建造场：选中基地车，在空地按 J 展开；没有基地车时，需保有战车工厂和维修厂才能生产。")
		steps.append(action + _name(str(bid)))
	var summary := ""
	if feasible and not steps.is_empty():
		summary = "解锁顺序：" + " → ".join(steps)
		lines.append("参考建造顺序（任选一条可行科技路线）\n" + " → ".join(steps))
	else:
		lines.append("当前目录无法给出完整路线，请检查缺失条件。")
	if not notices.is_empty():
		lines.append("；".join(notices))
	return {"detail": "\n".join(lines), "summary": summary, "steps": navigation if feasible else [],
		"alternatives": alternatives, "notice": "；".join(notices)}
