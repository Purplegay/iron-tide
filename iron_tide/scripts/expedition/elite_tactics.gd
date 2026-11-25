extends RefCounted
const ITEMS := {
	"armor_column":{"name":"装甲纵队","desc":"任务增援波额外加入 1 辆重型坦克；敌方载具生命 +15%","counter":"携带反装甲火力，利用地形集中拦截","group":"vehicle","hp":1.15},
	"rapid_raiders":{"name":"快速突击","desc":"任务增援波额外加入 2 名步兵；敌方作战步兵移速 +12%","counter":"保护后勤与任务目标，用范围火力封锁通路","group":"infantry","speed":1.12},
	"entrenched":{"name":"坚固阵地","desc":"敌方防御建筑生命 +20%","counter":"优先远程拆除防御，再接近任务目标","group":"building","hp":1.20}
}

static func select_for(stage:int,seed_value:int) -> String:
	return ITEMS.keys()[posmod(stage+seed_value,ITEMS.size())]

static func current() -> String:
	return str(BattleRequest.combat_context.get("expedition",{}).get("elite_tactic",""))

static func apply(actor,id:String) -> void:
	if id.is_empty() or not ITEMS.has(id) or not BattleRequest.is_ai_house(actor.side) or BattleRequest.friendly("ally",actor.side) or actor.special.get("expedition_elite_applied",false):return
	var spec:Dictionary=ITEMS[id]
	if actor is Building:
		if spec.group!="building" or actor.weapon.is_empty():return
	elif actor is Unit:
		if spec.group!=GameData.unit_production_category(actor.data) or actor.is_harvester:return
	else:return
	actor.special.expedition_elite_applied=true
	actor.special.expedition_elite_tactic=id
	if spec.has("hp"):
		var fraction:float=actor.hp/maxf(1.0,actor.max_hp)
		actor.max_hp*=float(spec.hp);actor.hp=actor.max_hp*fraction
		if actor is Unit:actor._base_max_hp*=float(spec.hp)
	if spec.has("speed"):
		actor.move_speed*=float(spec.speed)
		actor._base_speed*=float(spec.speed)

static func ownership_changed(actor) -> void:
	if BattleRequest.is_ai_house(actor.side) and not BattleRequest.friendly("ally",actor.side):
		apply(actor,current())
		return
	if not actor.special.get("expedition_elite_applied",false):return
	var id:=str(actor.special.get("expedition_elite_tactic",current()))
	var spec:Dictionary=ITEMS.get(id,{})
	if spec.has("hp"):
		var fraction:float=actor.hp/maxf(1.0,actor.max_hp)
		actor.max_hp/=float(spec.hp);actor.hp=actor.max_hp*fraction
		if actor is Unit:actor._base_max_hp/=float(spec.hp)
	if spec.has("speed") and actor is Unit:
		actor.move_speed/=float(spec.speed);actor._base_speed/=float(spec.speed)
	actor.special.erase("expedition_elite_applied")
	actor.special.erase("expedition_elite_tactic")

static func preview(id:String) -> String:
	if not ITEMS.has(id):return ""
	return "精英战术 · %s\n%s\n应对：%s\n精英胜利额外 +100 补给"%[ITEMS[id].name,ITEMS[id].desc,ITEMS[id].counter]
