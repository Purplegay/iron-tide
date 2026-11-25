extends Node
const Technology = preload("res://scripts/rules/production_technology.gd")
var checks: Array = []
var failed := 0

# Independent original full traversal; includes the original empty-key behavior.
func original(technology, building_id: String, uid: String, side: String) -> String:
	if building_id == "NAREFN" and uid == "HARV" and not technology.is_unlocked(Technology.REFINERY_MINER, side):
		return "需要科技：" + str(Technology.NODES[Technology.REFINERY_MINER].name)
	for id in Technology.NODES:
		var node: Dictionary = Technology.NODES[id]
		if node.get("building", "") == building_id and node.get("unit", "") == uid and not technology.is_unlocked(id, side):
			return "需要科技：" + str(node.name)
	return ""

func _ready() -> void:
	var output := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	var old_debug = GM.unlock_production_tech
	var old_context = BattleRequest.combat_context.duplicate(true)
	var technology = Technology.new()
	var buildings: Array = GameData.building_index.keys()
	buildings.append_array(["", "unknown"])
	var units: Array = GameData.unit_index.keys()
	units.append_array(["", "unknown"])
	var cases := 0
	var mismatch: Array = []
	for debug in [false, true]:
		GM.unlock_production_tech = debug
		for disabled in [false, true]:
			BattleRequest.combat_context.refinery_miner_disabled = disabled
			for unlocked in [[], Technology.NODES.keys(), [Technology.REFINERY_MINER], ["auto_w"]]:
				technology.unlocked = {"ally": unlocked, "enemy": unlocked, "ai2": unlocked}
				for side in ["ally", "enemy", "ai2", "neutral"]:
					for building_id in buildings:
						for uid in units:
							cases += 1
							if technology.block_reason(building_id, uid, side) != original(technology, building_id, uid, side):
								failed += 1
								if mismatch.size() < 10: mismatch.append([building_id, uid, side, debug, disabled, unlocked])
	checks.append({"name":"all catalog products, live unlock state, debug and refinery override match original", "passed":failed == 0, "cases":cases, "mismatches":mismatch})
	GM.unlock_production_tech = old_debug
	BattleRequest.combat_context = old_context
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	get_tree().quit(0 if failed == 0 else 1)
