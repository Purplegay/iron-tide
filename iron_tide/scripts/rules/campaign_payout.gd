extends RefCounted

static func cleared(id: String) -> bool:
	return MetaProgress.stats.get("campaign_victories", {}).has(id)

static func amount(mission: Dictionary, repeat: bool) -> Dictionary:
	var base: Dictionary = mission.get("first_win_reward", {})
	var payout := {}
	for key in ["war_points", "credits", "diamonds"]:
		var value := int(base.get(key, 0))
		payout[key] = (0 if key == "diamonds" else floori(value * 0.05)) if repeat else value
	return payout

static func reward_row(parent: Control, title: String, payout: Dictionary, size: int, color: Color) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	parent.add_child(row)
	if not title.is_empty(): row.add_child(UiKit.make_label(title, size, color))
	for id in ["war_points", "credits", "diamonds"]:
		var text := "%s %d" % [MetaProgress.currency_name(id), payout.get(id, 0)]
		preload("res://scripts/ui/resource_cost_icon.gd").balance_label(row, id, text, size, color)

static func is_normal_win(result: Dictionary) -> bool:
	return result.win and not result.draw and not result.get("gm_forced", false)

static func settle(mission: Dictionary, result: Dictionary) -> Dictionary:
	var receipt: String = result.match_id
	if MetaProgress.settled_matches.has(receipt): return {"already_settled":true}
	MetaProgress.settled_matches[receipt] = true
	MetaProgress.stats.battles = int(MetaProgress.stats.get("battles",0)) + 1
	if not is_normal_win(result): return {}
	var wins: Dictionary = MetaProgress.stats.get_or_add("campaign_victories", {})
	var repeat := wins.has(mission.id)
	var payout := amount(mission, repeat)
	for key in payout:
		MetaProgress.currency[key] = MetaProgress.balance(key) + payout[key]
	wins[mission.id] = int(wins.get(mission.id,0)) + 1
	MetaProgress.stats.battles_won = int(MetaProgress.stats.get("battles_won",0)) + 1
	payout.first_win = not repeat
	return payout
