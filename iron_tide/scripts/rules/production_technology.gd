extends RefCounted
## Match-local snapshot of permanent progression, plus explicit debug grants.
const REFINERY_MINER := "refinery_miner"
const STRUCTURE_QUEUE := "structure_queue"
const BUNKER_LEVELS := ["bunker_optics_1","bunker_optics_2","bunker_optics_3"]
const UNIT_QUEUE_LEVELS := ["unit_queue_1", "unit_queue_2", "unit_queue_3", "unit_queue_4", "unit_queue_5"]
const MINER_QUEUE := "refinery_miner_2"
const MINER_CAPACITY := 9
const UPGRADE_GROUPS := {
	"production_recipes": ["production_recipes", "production_recipes_2"],
	"repair_all": ["repair_all", "repair_auto"],
	REFINERY_MINER: [REFINERY_MINER, MINER_QUEUE],
	"superweapon_damage_1": preload("res://scripts/rules/superweapon_damage.gd").LEVELS,
	"structure_queue": [STRUCTURE_QUEUE, "structure_queue_2", "structure_queue_3"],
	"unit_queue_1": UNIT_QUEUE_LEVELS,
}
const NODES := {
	"production_recipes_2": {"name":"开局自动出兵", "requires": ["production_recipes"], "desc":"开局按预设自动排入单位订单，生产条件满足后继续补排。"},
	"superweapon_damage_1": {"name":"超级武器伤害 1","requires":[],"damage_percent":120},
	"superweapon_damage_2": {"name":"超级武器伤害 2","requires":["superweapon_damage_1"],"damage_percent":140},
	"superweapon_damage_3": {"name":"超级武器伤害 3","requires":["superweapon_damage_2"],"damage_percent":160},
	"superweapon_damage_4": {"name":"超级武器伤害 4","requires":["superweapon_damage_3"],"damage_percent":180},
	"superweapon_damage_5": {"name":"超级武器伤害 5","requires":["superweapon_damage_4"],"damage_percent":200},
	"superweapon_damage_6": {"name":"超级武器伤害 6","requires":["superweapon_damage_5"],"damage_percent":220},
	"superweapon_damage_7": {"name":"超级武器伤害 7","requires":["superweapon_damage_6"],"damage_percent":240},
	"superweapon_damage_8": {"name":"超级武器伤害 8","requires":["superweapon_damage_7"],"damage_percent":260},
	"superweapon_damage_9": {"name":"超级武器伤害 9","requires":["superweapon_damage_8"],"damage_percent":280},
	"superweapon_damage_10": {"name":"超级武器伤害 10","requires":["superweapon_damage_9"],"damage_percent":300},
	"superweapon_damage_11": {"name":"超级武器伤害 11","requires":["superweapon_damage_10"],"damage_percent":320},
	"superweapon_damage_12": {"name":"超级武器伤害 12","requires":["superweapon_damage_11"],"damage_percent":340},
	"superweapon_damage_13": {"name":"超级武器伤害 13","requires":["superweapon_damage_12"],"damage_percent":360},
	"superweapon_damage_14": {"name":"超级武器伤害 14","requires":["superweapon_damage_13"],"damage_percent":380},
	"superweapon_damage_15": {"name":"超级武器伤害 15","requires":["superweapon_damage_14"],"damage_percent":400},
	"superweapon_damage_16": {"name":"超级武器伤害 16","requires":["superweapon_damage_15"],"damage_percent":420},
	"superweapon_damage_17": {"name":"超级武器伤害 17","requires":["superweapon_damage_16"],"damage_percent":440},
	"superweapon_damage_18": {"name":"超级武器伤害 18","requires":["superweapon_damage_17"],"damage_percent":460},
	"superweapon_damage_19": {"name":"超级武器伤害 19","requires":["superweapon_damage_18"],"damage_percent":480},
	"superweapon_damage_20": {"name":"超级武器伤害 20","requires":["superweapon_damage_19"],"damage_percent":500},
	"joint_ra2_production": {"name":"空地并行生产","requires":[],"desc":"己方战车工厂的空军与载具独立排队、同时生产，可分别暂停和取消。保留各阵营、国家、科技前置与造价限制，不开放其他阵营单位。仅扩展模式生效。"},
	"auto_w": {"name":"自动战术施放 · Auto W","requires":[],"desc":"解锁局内 Auto W 开关：技能栏可单独调整，右侧指令甲板可全开／全关，包含后续生产单位并记住选择。仅新扩展对局生效。浮标只针对已发现潜艇，跃扑跟随明确攻击命令，换气用于受伤撤退；金鳞战垒姿态保持手动。"},
	"unit_queue_1": {"name":"单位预约 I","requires":[],"capacity":27},
	"unit_queue_2": {"name":"单位预约 II","requires":["unit_queue_1"],"capacity":36},
	"unit_queue_3": {"name":"单位预约 III","requires":["unit_queue_2"],"capacity":49},
	"unit_queue_4": {"name":"单位预约 IV","requires":["unit_queue_3"],"capacity":64},
	"unit_queue_5": {"name":"单位预约 V","requires":["unit_queue_4"],"capacity":81},
	"bunker_optics_1": {"name":"碉堡射程 I","requires":[],"desc":"苏联战斗碉堡永久提升一级对地射程。"},
	"bunker_optics_2": {"name":"碉堡射程 II","requires":["bunker_optics_1"],"desc":"进一步增加驻军射程，同时扩展有人值守时的视野。"},
	"bunker_optics_3": {"name":"碉堡射程 III","requires":["bunker_optics_2"],"desc":"满级对地射程 8.5 格，比部署的重装大兵远半格。"},
	"repair_auto": {"name":"自动抢修", "requires":["repair_all"], "desc":"持续维修新受损的己方建筑。再次点击关闭自动抢修。"},
	"production_recipes": {"name":"生产配方", "requires":[], "desc":"在单位生产页记录常用出兵顺序。研究后立即在扩展对局启用。整组下单时按顺序排入可生产的单位，跳过暂时造不了的单位，按生产进度付费。"},
	"repair_all": {"name": "一键维修", "requires": [], "desc": "解锁指令甲板上的一键维修，同时维修所有符合条件的受损己方建筑。按实际修复量支付局内资金。"},
	MINER_QUEUE: {"name": "矿车复数预约", "requires": [REFINERY_MINER], "desc": "每座矿场可预约多辆矿车，按顺序制造。"},
	REFINERY_MINER: {"name": "矿场矿车制造", "requires": [], "building": "GAREFN", "unit": "CMIN", "desc": "矿场可独立制造矿车，每座同时制造一辆，完成后自动采矿；仍需支付局内造价。战车工厂的矿车生产不受影响。"},
	"structure_queue_2": {"name": "建筑预约 II", "requires": [STRUCTURE_QUEUE], "desc": "建筑与防御队列各扩充到 18 项；仅扩展模式新对局生效。"},
	"structure_queue_3": {"name": "建筑预约 III", "requires": ["structure_queue_2"], "desc": "建筑与防御队列各扩充到 27 项；仅扩展模式新对局生效。"},
	STRUCTURE_QUEUE: {"name": "建筑预约", "requires": [], "desc": "建筑与防御各允许最多 9 项建造订单，已就绪建筑不阻塞后续生产。"},
}
static var _product_nodes_by_building: Dictionary = _index_product_nodes()
var unlocked: Dictionary = {}

static func _index_product_nodes() -> Dictionary:
	var result: Dictionary = {}
	for id in NODES:
		var building_id: String = NODES[id].get("building", "")
		if not result.has(building_id): result[building_id] = []
		result[building_id].append(id)
	for ids: Array in result.values(): ids.make_read_only()
	result.make_read_only()
	return result

func is_unlocked(id: String, side: String) -> bool:
	if id == "production_recipes" and side == "ally":
		return BattleRequest.extensions_enabled() and MetaProgress.technology_active(id)
	# The existing debug default was authorized for refinery miners only.
	return NODES.has(id) and ((id == REFINERY_MINER and GM.unlock_production_tech and (side!="ally" or not BattleRequest.combat_context.get("refinery_miner_disabled",false))) or unlocked.get(side, []).has(id))

func unlock(id: String, side: String) -> bool:
	if not NODES.has(id) or side not in ["ally", "enemy"]:
		return false
	for dependency in NODES[id].requires:
		if not unlocked.get(side, []).has(dependency):
			return false
	if not unlocked.has(side):
		unlocked[side] = []
	if not unlocked[side].has(id):
		unlocked[side].append(id)
	return true

func bunker_level(side: String) -> int:
	if not BattleRequest.extensions_enabled():return 0
	if BattleRequest.combat_context.get("bunker_talent_version",0)>=1:
		return preload("res://scripts/rules/bunker_talent.gd").level(side)
	# Older battles retain their frozen research snapshot.
	for i in range(BUNKER_LEVELS.size()-1,-1,-1):
		if is_unlocked(BUNKER_LEVELS[i], side): return i+1
	return 0

func unit_capacity(side: String) -> int:
	for i in range(UNIT_QUEUE_LEVELS.size()-1,-1,-1):
		var id:String=UNIT_QUEUE_LEVELS[i]
		if is_unlocked(id,side):return NODES[id].capacity
	return 9

func structure_capacity(side: String) -> int:
	if is_unlocked("structure_queue_3", side): return 27
	if is_unlocked("structure_queue_2", side): return 18
	return 9 if is_unlocked(STRUCTURE_QUEUE, side) else 1

func block_reason(building_id: String, uid: String, side: String) -> String:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(57)
	if building_id == "NAREFN" and uid == "HARV" and not is_unlocked(REFINERY_MINER, side):
		return "需要科技：" + str(NODES[REFINERY_MINER].name)
	for id in _product_nodes_by_building.get(building_id, []):
		preload("res://scripts/world/battle_call_counters.gd").iterations(57, 1)
		var node: Dictionary = NODES[id]
		if node.get("building", "") == building_id and node.get("unit", "") == uid and not is_unlocked(id, side):
			return "需要科技：" + str(node.name)
	return ""
