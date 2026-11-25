extends RefCounted
## Authored Iron Tide maps; not decoded RA2/YR maps. Coordinates are normalized.
const IDS := ["coast","crossings","strait","river_delta","lake_ring","island_cross","canal_city","twin_bays","ore_frontier","yr_isleland","yr_ice_age","yr_crctbrd","yr_deepfrze","yr_riverram","yr_mojosprt","yr_unrepent","yr_irvineca","yr_monsterm","yr_transylv","yr_highexpr","yr_moonpatr", "yr_hidvally", "yr_dunepatr", "yr_dryheat", "yr_groundze", "yr_fourcorners", "yr_tourofegypt", "yr_bayopigs", "yr_pacific", "yr_seaofiso", "yr_tsunami", "yr_potomac", "yr_amazon", "yr_lostlake", "yr_shrapnel", "yr_arena", "yr_oceansid", "yr_hills", "yr_valley", "yr_dustbowl", "yr_newhghts", "yr_hailmary", "yr_grinder"]
const NAMES := ["经典海岸","双桥争夺","隔海登陆","多桥河谷","环湖争夺","群岛登陆","运河城镇","双湾半岛","内陆矿区","尤复 · 陆中群岛","尤复 · 冰河世纪","尤复 · 电路板","尤复 · 深度冻结","尤复 · 狂暴河流","尤复 · 魔力之魂","尤复 · 不屈战区","尤复 · 尔湾战区","尤复 · 巨兽战区","尤复 · 古堡战区","尤复 · 高爆战区","尤复 · 月面战区", "尤复 · 隐秘山谷", "尤复 · 沙丘巡逻", "尤复 · 干热沙地", "尤复 · 零点城区", "尤复 · 四角战区", "尤复 · 埃及之旅", "红警2 · 猪湾", "红警2 · 太平洋高地", "红警2 · 隔绝之海", "红警2 · 海啸", "红警2 · 波托马克河", "红警2 · 亚马孙河谷", "红警2 · 失落之湖", "红警2 · 弹片山", "红警2 · 竞技场", "红警2 · 海滨", "红警2 · 丘陵", "红警2 · 宝石谷", "红警2 · 沙尘盆地", "红警2 · 新高地", "红警2 · 孤注一掷", "红警2 · 绞肉机"]
const MAPS := {
	"exp_plain":preload("res://scripts/expedition/maps.gd").PLAIN,
	"exp_fortress":preload("res://scripts/expedition/maps.gd").FORTRESS,
	"river_delta": {
		"desc":"三座桥连接两岸，支流分割侧翼；桥头民居和中立油井控制推进路线。",
		"water":[[0.44,0,0.12,1],[0.26,0.42,0.18,0.10],[0.56,0.48,0.18,0.10]],
		"bridges":[[0,0.28,true],[0,0.68,true],[0,0.84,false]],
		"houses":[[0.36,0.28],[0.64,0.28],[0.36,0.68],[0.64,0.68],[0.18,0.47],[0.82,0.53]],
		"oil":[[0.28,0.88],[0.72,0.10],[0.35,0.36],[0.65,0.63],[0.18,0.52]],
		"ore":[[0.11,0.70],[0.30,0.70],[0.18,0.34],[0.82,0.66]],
		"enemy_ore":[[0.89,0.28],[0.70,0.08]],"gems":[[0.34,0.18],[0.66,0.82]]},
	"lake_ring": {
		"desc":"中央大湖与南北水道，陆军可沿外环绕行或争夺跨湖桥；湖岸油井吸引海陆交火。",
		"water":[[0.35,0.34,0.30,0.32],[0.44,0.12,0.12,0.22],[0.44,0.66,0.12,0.22]],
		"bridges":[[0,0.42,true],[0,0.58,false]],
		"houses":[[0.26,0.42],[0.74,0.42],[0.26,0.58],[0.74,0.58],[0.50,0.07],[0.50,0.93]],
		"oil":[[0.28,0.88],[0.72,0.10],[0.24,0.50],[0.76,0.50],[0.60,0.84]],
		"ore":[[0.11,0.70],[0.30,0.70],[0.23,0.29],[0.77,0.71]],
		"enemy_ore":[[0.89,0.28],[0.70,0.08]],"gems":[[0.32,0.12],[0.68,0.88]]},
	"island_cross": {
		"desc":"十字海峡分成四块陆地；双方隔海开局，侧翼岛屿有油井和宝石，需空军或运输登陆。",
		"water":[[0.36,0,0.28,1],[0,0.40,0.36,0.20],[0.64,0.40,0.36,0.20]],
		"bridges":[],
		"houses":[[0.18,0.27],[0.27,0.27],[0.73,0.73],[0.82,0.73]],
		"oil":[[0.28,0.88],[0.72,0.10],[0.20,0.20],[0.80,0.80]],
		"ore":[[0.11,0.70],[0.28,0.66],[0.18,0.12],[0.82,0.88]],
		"enemy_ore":[[0.89,0.28],[0.70,0.08]],"gems":[[0.18,0.32],[0.82,0.68]]},
	"canal_city": {
		"desc":"双运河与四座桥分割城镇；可驻军建筑掩护桥头，中间岛带油井，海军可穿行桥下。",
		"water":[[0.34,0,0.10,1],[0.60,0,0.10,1],[0.44,0.46,0.16,0.08]],
		"bridges":[[0,0.34,true],[1,0.34,true],[0,0.66,true],[1,0.66,false]],
		"houses":[[0.25,0.34],[0.51,0.34],[0.78,0.40],[0.24,0.60],[0.51,0.66],[0.78,0.66],[0.51,0.22],[0.51,0.78]],
		"oil":[[0.25,0.90],[0.75,0.08],[0.51,0.40],[0.51,0.60],[0.84,0.54]],
		"ore":[[0.11,0.70],[0.25,0.65],[0.17,0.28],[0.84,0.74]],
		"enemy_ore":[[0.89,0.28],[0.75,0.07]],"gems":[[0.51,0.13],[0.51,0.87]]},
	"twin_bays": {
		"desc":"南北海湾夹出中央陆桥，右侧外海互通；中央城镇可驻军，陆军正面突破、舰队沿岸迂回。",
		"water":[[0.37,0,0.26,0.40],[0.37,0.60,0.26,0.40],[0.90,0,0.10,1],[0.63,0,0.27,0.08],[0.63,0.92,0.27,0.08]],
		"bridges":[],
		"houses":[[0.40,0.46],[0.50,0.46],[0.60,0.46],[0.40,0.55],[0.50,0.55],[0.60,0.55]],
		"oil":[[0.28,0.88],[0.71,0.15],[0.32,0.48],[0.68,0.52],[0.80,0.80]],
		"ore":[[0.11,0.70],[0.28,0.66],[0.18,0.28],[0.78,0.72]],
		"enemy_ore":[[0.82,0.34],[0.70,0.10]],"gems":[[0.47,0.50],[0.56,0.50]]},
	"ore_frontier": {
		"desc":"内陆多矿区与两座侧翼湖泊；中央宝石矿、民居和五处油井形成多条争夺线，偏重陆战。",
		"water":[[0.12,0.38,0.18,0.15],[0.70,0.47,0.18,0.15]],
		"bridges":[[0,0.45,true],[1,0.55,false]],
		"houses":[[0.38,0.40],[0.50,0.40],[0.62,0.40],[0.38,0.60],[0.50,0.60],[0.62,0.60]],
		"oil":[[0.28,0.88],[0.72,0.10],[0.35,0.50],[0.65,0.50],[0.50,0.72]],
		"ore":[[0.11,0.70],[0.30,0.70],[0.18,0.28],[0.82,0.72],[0.50,0.18],[0.50,0.82]],
		"enemy_ore":[[0.89,0.28],[0.70,0.08]],"gems":[[0.45,0.50],[0.55,0.50]]},
}

static func custom(id:String) -> bool:
	return MAPS.has(id)

static func points(id:String,key:String,size:float) -> Array:
	var result:Array=[]
	for point:Array in MAPS.get(id,{}).get(key,[]):result.append(Vector2(point[0],point[1])*size)
	return result

static func water(id:String,size:float) -> Array:
	var result:Array=[]
	for r:Array in MAPS[id].water:result.append(Rect2(r[0]*size,r[1]*size,r[2]*size,r[3]*size))
	return result

static func bridges(id:String,size:float) -> Array:
	var result:Array=[]
	var lakes:=water(id,size)
	for entry:Array in MAPS[id].bridges:
		var lake:Rect2=lakes[entry[0]]
		result.append({"span":Rect2(lake.position.x-20,entry[1]*size-60,lake.size.x+40,120),"intact":entry[2]})
	return result

static func reserve(world,point:Vector2) -> bool:
	for entry:Dictionary in bridges(world.map_layout(),world.map_size):
		var span:Rect2=entry.span
		if span.grow(100).has_point(point):return true
		for end in [span.position.x-85,span.end.x+85]:
			if point.distance_to(Vector2(end,span.get_center().y+66))<130:return true
	return false

static func start(id:String,size:float,enemy:=false) -> Vector2:
	if MAPS.get(id,{}).has("start"):
		var point:Array=MAPS[id]["enemy_start" if enemy else "start"]
		return Vector2(point[0],point[1])*size
	if id=="ore_frontier":return Vector2(0.78 if enemy else 0.22,0.16 if enemy else 0.80)*size
	var shores:Dictionary={"river_delta":[0.44,0.56],"lake_ring":[0.44,0.56],"island_cross":[0.36,0.64],"canal_city":[0.34,0.70],"twin_bays":[0.37,0.63]}
	return Vector2(float(shores[id][1 if enemy else 0])*size+(300 if enemy else -300),size*(0.16 if enemy else 0.80))
