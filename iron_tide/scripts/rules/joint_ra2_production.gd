extends RefCounted
## Keep the purchased ID for compatibility; it now grants parallel queues only.
const ID := "joint_ra2_production"
const FACTORIES := ["GAWEAP", "NAWEAP"]

static func active(side: String = "ally") -> bool:
	return side == "ally" and BattleRequest.extensions_enabled() and BattleRequest.combat_context.get("technologies", []).has(ID)

static func sync_catalog(building) -> void:
	if building.building_id not in FACTORIES: return
	# Old snapshots include the mistakenly merged menu. Remove only foreign products.
	for id in building.buildable.duplicate():
		var producer: String = GameData.get_unit(str(id)).get("built_at", "")
		if producer in FACTORIES and producer != building.building_id and not preload("res://scripts/expedition/rules.gd").has_training_permit(str(id),building.side):
			building.buildable.erase(id)
	for i in range(building.production.size()-1,-1,-1):
		var producer: String = GameData.get_unit(str(building.production[i])).get("built_at", "")
		if producer in FACTORIES and producer != building.building_id and not preload("res://scripts/expedition/rules.gd").has_training_permit(str(building.production[i]),building.side):
			building.cancel_at(i)
