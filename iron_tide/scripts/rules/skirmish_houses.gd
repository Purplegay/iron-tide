extends RefCounted
## The first two identities also occur in legacy saves. A house owns assets;
## its team only determines diplomacy, shared sight and the match result.
const Maps = preload("res://scripts/world/native_maps.gd")
const Preferences = preload("res://scripts/ui/lobby_preferences.gd")
const COMMANDERS := {
	"allied":["里德","莫罗","韩星","瓦格纳","柯林斯","黎安","海斯","沈舟"],
	"soviet":["罗曼诺娃","格里申","奥尔洛夫","扎赫拉","科瓦奇","伊萨克","罗哈斯","米拉"],
	"yuri":["尤里指挥官"],
	"swarm":["灰刺","蚀月","赤颚","幽鸣","黑棘","白翅","织雾","空壳"]}

static func commander_name(row:Dictionary,index:int) -> String:
	if not str(row.get("commander","")).is_empty():return str(row.commander).get_slice(" · ",0)
	var names:Array=COMMANDERS[Preferences.enemy_base_for(str(row.get("country","美国")))]
	return names[posmod(int(row.get("seat",index))-1,names.size())]

static func commander_label(row:Dictionary,index:int) -> String:
	return "%s · 电脑 %d"%[commander_name(row,index),int(row.get("seat",index))]

static func capacity(layout: String) -> int:
	return Maps.data(layout).starts.size() if Maps.has(layout) else 2

static func id(index: int) -> String:
	return "ally" if index == 0 else ("enemy" if index == 1 else "ai%d" % index)

static func valid(rows: Variant, layout: String, classic: bool) -> bool:
	if not rows is Array or rows.size() < 2 or rows.size() > capacity(layout): return false
	var teams := {}
	var seats := {}
	var spawns := {}
	for i in rows.size():
		var row = rows[i]
		if not row is Dictionary or not row.get("team") is int or row.team < 1 or row.team > capacity(layout): return false
		if row.get("country") not in Preferences.OPTIONS.enemy_country: return false
		if row.has("color") and (not row.color is String or (row.color != "auto" and not HouseColor.has_color(row.color))): return false
		if row.country == "虫群巢穴" and (classic or i == 0): return false
		var seat = row.get("seat",i)
		if not seat is int or seat < 0 or seat >= capacity(layout) or seats.has(seat) or (i < 2 and seat != i): return false
		var spawn = row.get("spawn",seat)
		if not spawn is int or spawn < 0 or spawn >= capacity(layout) or spawns.has(spawn): return false
		if row.has("difficulty") and (i==0 or not row.difficulty is int or row.difficulty<0 or row.difficulty>=GameData.DIFFICULTY_NAMES.size()): return false
		spawns[spawn]=true
		seats[seat] = true
		teams[row.team] = true
	return teams.size() > 1

# Opening teams determine the reward even when a computer is eliminated before victory.
static func victory_reward(rows: Array, fallback: int) -> Dictionary:
	if rows.size() < 3: return {}
	var allies := 0
	var strongest_ally := -1
	var weakest_enemy := GameData.DIFFICULTY_NAMES.size()
	for i in range(1, rows.size()):
		var difficulty := int(rows[i].get("difficulty", fallback))
		if rows[i].team == rows[0].team:
			allies += 1
			strongest_ally = maxi(strongest_ally, difficulty)
		else:
			weakest_enemy = mini(weakest_enemy, difficulty)
	if allies == 0 or weakest_enemy == GameData.DIFFICULTY_NAMES.size(): return {}
	var discount := mini(30, allies * 10)
	var gap := maxi(0, weakest_enemy - strongest_ally)
	var correction := mini(discount, gap * 5)
	return {"allies": allies, "discount": discount, "gap": gap, "correction": correction, "percent": 100 - discount + correction}

static func reward_description(adjustment: Dictionary) -> String:
	return "%d 家电脑盟友 −%d%%，越级补正 +%d%%，胜利收益 %d%%" % [
		adjustment.allies, adjustment.discount, adjustment.correction, adjustment.percent]

static var start_cache := {}
static func starts(layout: String, size:=3200.0) -> Array[Vector2]:
	if not Maps.has(layout):
		var result:Array[Vector2]=[]
		var custom=preload("res://scripts/world/skirmish_maps.gd")
		if custom.custom(layout):
			result.assign([custom.start(layout,size),custom.start(layout,size,true)])
		else:
			result.assign([Vector2(0.5 if layout=="coast" else 0.22,0.80)*size,Vector2(0.5 if layout=="coast" else 0.78,0.16)*size])
		return result
	if start_cache.has(layout): return start_cache[layout]
	var points: Array[Vector2] = []
	for row in Maps.data(layout).starts:
		points.append(Maps._spawn_clear(layout, Vector2(row[1],row[2]) * Maps.CELL))
	# Preserve the duel's first two starting areas when adding more players.
	var result: Array[Vector2] = [points.pop_front()]
	while not points.is_empty():
		var best := 0
		var spread := -1.0
		for i in points.size():
			var nearest := INF
			for chosen in result: nearest = minf(nearest, chosen.distance_squared_to(points[i]))
			if nearest > spread:
				spread = nearest
				best = i
		result.append(points.pop_at(best))
	start_cache[layout]=result
	return result
