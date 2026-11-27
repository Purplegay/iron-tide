class_name HouseColor
extends RefCounted
## 阵营涂装（house color）中央工具。
##
## 背景：RA2 的房色（team color）是**构建期烘焙**进贴图的——ra2pipe/art_build.mjs 把
##   UNITTEM.PAL 的 16..31 号「房色阶」整体重映射成盟军蓝 #57a8ff 后离线出 PNG。
##   因此运行时改色只能「把色相 = 盟军蓝的像素换成目标色」——见 shaders/house_remap.gdshader。
##
## 本类负责：共享色板、玩家/电脑选色、自动避让、按色缓存 ShaderMaterial、给任意 CanvasItem 上色。
## 素材基准色固定为 BASE_HEX（盟军蓝）；目标色 == 基准色时不上 shader（零开销）。

const BASE_HEX := "#57a8ff"                                   # 素材烘焙色（ra2pipe SIDE_HOUSE_RGB）
const SHADER_PATH := "res://shaders/house_remap.gdshader"
const CLASH_DIST := 0.30                                      # 归一化 RGB 距离；低于此判为撞色

## 色板回退。稳定 id 供存档 / UI 使用。
const PALETTE: Array = [
	{"id": "allied", "name": "盟军蓝", "hex": "#57a8ff"},
	{"id": "red",    "name": "战火红", "hex": "#ff5b4a"},
	{"id": "yellow", "name": "旭日黄", "hex": "#ffd24a"},
	{"id": "green",  "name": "丛林绿", "hex": "#4ade80"},
	{"id": "purple", "name": "虫群紫", "hex": "#a56bff"},
	{"id": "cyan",   "name": "冰原青", "hex": "#22d3ee"},
	{"id": "orange", "name": "熔岩橙", "hex": "#ff8a3d"},
	{"id": "gray",   "name": "灰白",   "hex": "#cbd5e1"},
	{"id": "magenta", "name": "玫瑰红", "hex": "#e83e9a"},
	{"id": "teal",   "name": "深海青", "hex": "#008577"},
	{"id": "indigo", "name": "靛蓝",   "hex": "#3e42c4"},
	{"id": "brown",  "name": "铜棕",   "hex": "#946536"},
]

## 当前玩家涂装。player_id 为色板 id；player_hex 为对应 #RRGGBB（着色器用）。
static var player_id: String = "allied"
static var player_hex: String = BASE_HEX

static var _mat_cache: Dictionary = {}
static var _shader: Shader = null
static var _pal_loaded := false
static var _pal: Array = []


# ---------------------------------------------------------------- 色板查询

## 涂装色板。数据源优先取 data/factions.json 的 house_palette（单一事实源），
## 读不到时回落到本类内置 PALETTE。
static func palette() -> Array:
	if not _pal_loaded:
		_pal_loaded = true
		if FileAccess.file_exists("res://data/factions.json"):
			var f := FileAccess.open("res://data/factions.json", FileAccess.READ)
			if f != null:
				var d = JSON.parse_string(f.get_as_text())
				f.close()
				if d is Dictionary and (d as Dictionary).has("house_palette"):
					var hp = (d as Dictionary)["house_palette"]
					if hp is Array and (hp as Array).size() > 0:
						_pal = hp
	return _pal if not _pal.is_empty() else PALETTE


static func menu_picker() -> OptionButton:
	var picker := color_picker(player_id)
	picker.name = "HouseColorPicker"
	for i in picker.item_count: picker.set_item_text(i, "阵营色 · " + picker.get_item_text(i))
	picker.item_selected.connect(func(i:int):set_player(str(picker.get_item_metadata(i))))
	return picker

static func color_picker(selected_id: String, automatic := false) -> OptionButton:
	var picker := OptionButton.new()
	if automatic:
		picker.add_item("自动区分")
		picker.set_item_metadata(0, "auto")
	var colors := palette()
	for i in colors.size():
		var index := picker.item_count
		picker.add_item(str(colors[i].name))
		picker.set_item_metadata(index, colors[i].id)
		var chip:=GradientTexture2D.new()
		chip.width=18
		chip.height=14
		chip.gradient=Gradient.new()
		chip.gradient.colors=PackedColorArray([Color(colors[i].hex),Color(colors[i].hex)])
		picker.set_item_icon(index,chip)
		if colors[i].id == selected_id: picker.select(index)
	return picker

static func has_color(value: Variant) -> bool:
	if not value is String: return false
	for entry in palette():
		if entry.id == value: return true
	return false

## Used only when choosing/starting a roster. Combat stores resolved IDs, not
## a per-frame colour search. Explicit duplicate choices remain user-owned.
static func roster_color_ids(rows: Array) -> Array:
	var result: Array = [player_id]
	var used: Array[Color] = [player_color()]
	var reserved: Array = [player_id]
	for i in range(1, rows.size()):
		var selected = rows[i].get("color", "auto")
		if has_color(selected):
			reserved.append(selected)
			used.append(Color(hex_of(selected)))
	for i in range(1, rows.size()):
		var selected = rows[i].get("color", "auto")
		if has_color(selected):
			result.append(selected)
			continue
		var best := "allied"
		var separation := -1.0
		for entry in palette():
			if entry.id in reserved or entry.id in result: continue
			var color := Color(entry.hex)
			var nearest := INF
			for other in used: nearest = minf(nearest, _dist(color, other))
			if nearest > separation:
				separation = nearest
				best = entry.id
		result.append(best)
		used.append(Color(hex_of(best)))
	return result

static func hex_of(id: String) -> String:
	for e in palette():
		if e["id"] == id:
			return e["hex"]
	return BASE_HEX


static func name_of(id: String) -> String:
	for e in palette():
		if e["id"] == id:
			return e["name"]
	return "未知"


static func player_color() -> Color:
	return Color(player_hex)


## 敌方颜色（D4=A 自动避让）：
##   若敌方阵营本色与玩家色差异足够大 → 保留阵营本色；
##   否则（撞色）→ 从色板中挑与玩家色 RGB 距离最大的一色。
static func enemy_color_for(faction_hex: String) -> Color:
	var p := player_color()
	var f := Color(faction_hex) if faction_hex != "" else Color("#ff5b4a")
	if _dist(p, f) >= CLASH_DIST:
		return f
	var best := f
	var bestd := -1.0
	for e in palette():
		var c := Color(e["hex"])
		var d := _dist(p, c)
		if d > bestd:
			bestd = d
			best = c
	return best


static func hollywood_enemy(side: String) -> bool:
	return side == "enemy" and not BattleRequest.skirmish and BattleRequest.mission_id == "yr_hollywood"


static func head_games() -> bool:
	return not BattleRequest.skirmish and BattleRequest.mission_id == "yr_head_games"

# Retail [Colors] is 8-bit HSV. The two controlled houses have their own purple ramps.
static func mission_color(side: String, wing := -1) -> Color:
	if side=="ally": return Color.from_hsv(0,230.0/255,1)
	if side=="neutral": return Color.from_hsv(0,0,131.0/255)
	var hue := 211 if wing==0 else 191 if wing==1 else 201
	return Color.from_hsv(hue/255.0,201.0/255,189.0/255)

static func color_for_side(side: String, faction_hex: String) -> Color:
	if BattleRequest.mission_id=="yr_time_shift" and not BattleRequest.skirmish:
		if side=="enemy":return Color.from_hsv(153.0/255,214.0/255,212.0/255)
		return mission_color(side)
	if head_games(): return mission_color(side)
	if hollywood_enemy(side):
		# rulesmd.ini [Colors] Purple uses 8-bit HSV.
		return Color.from_hsv(201.0 / 255, 201.0 / 255, 189.0 / 255)
	if side == "ally":
		return player_color()
	if BattleRequest.skirmish:
		var rows: Array = BattleRequest.skirmish_config.get("houses", [])
		var index: int = 1 if side == "enemy" else BattleRequest.house_teams.keys().find(side)
		if index >= 0 and index < rows.size() and has_color(rows[index].get("color")):
			return Color(hex_of(rows[index].color))
	if BattleRequest.house_teams.has(side):
		return seat_color(BattleRequest.house_teams.keys().find(side),true)
	return enemy_color_for(faction_hex)

static func seat_color(index: int, multi: bool, faction_hex := "#ff5b4a") -> Color:
	# Compatibility for battles saved before explicit roster colours existed.
	if index == 0: return player_color()
	if not multi: return enemy_color_for(faction_hex)
	var colors := [Color("#ff685c"),Color("#ffd24a"),Color("#45cea4"),Color("#b789ff"),Color("#eb98cf"),Color("#7cacf4"),Color("#ffa150"),Color("#97c153")]
	colors = colors.filter(func(c):return _dist(c,player_color())>0.35)
	return colors[(index-1) % colors.size()]


static func _dist(a: Color, b: Color) -> float:
	return sqrt((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b))


# ---------------------------------------------------------------- shader / 上色

static func shader_res() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH)
	return _shader


## 按目标色返回共享 ShaderMaterial；目标色 == 素材基准色时返回 null（不必上 shader）。
enum PaintMode { NONE, SQUID_BODY, SQUID_GRIP, SUB_HULL, NEUTRAL_OIL, NATIVE_MODEL, CITY_RED_RAMP, HOSPITAL_FACADE, SHOP_FACADE, HOSPITAL_BLUE_NEUTRAL, HOSPITAL_BLUE_FACADE }

static func material_for(target: Color, paint_mode := PaintMode.NONE, skin := 0, hollywood_paint := false) -> ShaderMaterial:
	var hex := "#" + target.to_html(false)
	if hex == BASE_HEX and paint_mode == PaintMode.NONE and skin == 0 and not hollywood_paint:
		return null
	var key := "%s:%d:%d:%d" % [hex,paint_mode,skin,int(hollywood_paint)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader_res()
	m.set_shader_parameter("base_color", Color(BASE_HEX))
	m.set_shader_parameter("target_color", target)
	m.set_shader_parameter("cos_tol", 0.995)
	m.set_shader_parameter("min_len", 0.10)
	m.set_shader_parameter("strength", 1.0)
	m.set_shader_parameter("paint_mode", paint_mode)
	m.set_shader_parameter("hollywood_paint", hollywood_paint)
	m.set_shader_parameter("unit_skin",skin)
	_mat_cache[key] = m
	return m


static func allied_first() -> bool:
	return not BattleRequest.skirmish and BattleRequest.mission_id=="yr_allied_first"

static func first_room_color(room: String) -> Color:
	var source: Dictionary = preload("res://data/ra2/allied_first_ai.json").data
	var hsv: Array = source.colors[source.rooms[room].color]
	return Color.from_hsv(float(hsv[0])/255,float(hsv[1])/255,float(hsv[2])/255)

static func allied_finale() -> bool:
	return not BattleRequest.skirmish and BattleRequest.mission_id=="yr_allied_finale"

static func finale_color(side: String, room: String, faction: String) -> Color:
	if side=="ally":
		# The captured Special house and player-built Soviet roster share a paint scheme.
		# Use the actor's own roster, never the currently selected command-deck tab.
		if room=="Special" or (room.is_empty() and faction=="soviet"): return Color.from_hsv(0,230.0/255,1)
		return Color.from_hsv(153.0/255,214.0/255,212.0/255)
	if side=="neutral": return Color.from_hsv(0,0,131.0/255)
	var hue: float = {"YuriCountry":211.0,"Yuri2":191.0}.get(room,201.0)
	return Color.from_hsv(hue/255.0,201.0/255,189.0/255)

## 新造对象和放置预览还没有原图房 ID，按实际制式解析房色。
static func player_building_preview_color(faction: String) -> Color:
	return finale_color("ally", "", faction) if allied_finale() else color_for_side("ally", "")

## 给一个 CanvasItem（单位/建筑）上色：设置其 material，并返回计算出的阵营色。
## `faction_hex` 为该对象所属阵营的本色（用于敌方避让判定）。
static func apply_to(node: CanvasItem, side: String, faction_hex: String) -> Color:
	var col := color_for_side(side, faction_hex)
	if allied_finale() and (node is Unit or node is Building):
		col = finale_color(side,str(node.special.get("allied_finale_room","")),node.faction)
	if allied_first() and (node is Unit or node is Building):
		var room: String = node.special.get("allied_first_room","")
		var rooms: Dictionary = preload("res://data/ra2/allied_first_ai.json").data.rooms
		if rooms.has(room):
			if side=="enemy" and room in ["PowerHouse","Neutral","BridgeHouse","Americans","Alliance","British"]: col=first_room_color("YuriCountry")
			elif side=="neutral": col=first_room_color("Neutral")
			elif side!="ally" or (room in ["Americans","Alliance","British"] and player_id=="allied"): col=first_room_color(room)
	if head_games() and (node is Unit or node is Building):
		col = mission_color(side,int(node.special.get("head_games_wing",-1)))
	if BattleRequest.mission_id=="yr_time_shift" and side=="enemy" and (node is Unit or node is Building) and (node.faction=="yuri" or node.special.get("yuri_power",false) or node.special.get("time_shift_native_house")=="YuriCountry"):col=mission_color("enemy")
	var mode := PaintMode.NONE
	if node is Building and BattleRequest.mission_id == "yr_allied_first" and not BattleRequest.skirmish and node.building_id.begins_with("CAPOWR0") and side == "neutral":
		col = Color.from_hsv(0.0, 0.0, 131.0/255.0)
	if node is Building and node.building_id == "CAOILD" and side == "neutral":
		col = Color.GRAY
		mode = PaintMode.NEUTRAL_OIL
	if node is Building and node.building_id == "CATHOSP":
		var art: Texture2D = node._ra2.get("tex")
		var city := art != null and art.resource_path.begins_with("res://assets/ra2/hollywood/city/")
		if side == "neutral":
			col = first_room_color("Neutral") if allied_first() else Color.GRAY
			mode = PaintMode.CITY_RED_RAMP if city else PaintMode.HOSPITAL_BLUE_NEUTRAL
		else:
			mode = PaintMode.HOSPITAL_FACADE if city else PaintMode.HOSPITAL_BLUE_FACADE
	if node is Building and node.building_id == "CAMACH" and side != "neutral":
		mode = PaintMode.SHOP_FACADE
	if node is Building and node.building_id == "CALA05" and side != "neutral":
		mode = PaintMode.CITY_RED_RAMP
	if node is Unit:
		match node.unit_id:
			"R3FUTURE": mode = PaintMode.NATIVE_MODEL
			"SQD": mode = PaintMode.SQUID_BODY
			"SUB", "DLPH": mode = PaintMode.SUB_HULL
	var skin := 0
	var casemate:=false
	if (node is Unit or node is Building) and side=="ally":
		var id:String=node.unit_id if node is Unit else node.building_id
		var style:Dictionary=node.cosmetic_outfit() if node is Unit else MetaProgress.cosmetic_style(id)
		casemate=id=="TNKD" and style.get("skin")=="casemate_frame"
		skin=MetaProgress.Cosmetics.SKIN_MATERIALS.get(style.get("skin","stock"),0)
	if node is Unit and node.special.get("hero_skin",false) and node.unit_id in ["MTNK","HTNK"]:
		skin=10 if node.unit_id=="MTNK" else 11
	node.material = material_for(col, mode, skin, hollywood_enemy(side))
	if node is Unit:
		if casemate:
			if node.casemate_thruster==null:node.casemate_thruster=preload("res://scripts/units/tnkd_exoframe.gd").new()
		else:node.casemate_thruster=null
		if skin in [4,5]:
			if node.tank_finish==null or node.tank_finish.skin!=skin:
				node.tank_finish=preload("res://scripts/units/tank_finish.gd").new(skin)
			node.material=node.material.duplicate()
		else:node.tank_finish=null
		if skin in [6,7,8,9]:
			if skin in [6,8]:node.material=node.material.duplicate()
			if node.yr_finish==null or node.yr_finish.skin!=skin:
				node.yr_finish=preload("res://scripts/units/yr_signature_finish.gd").new(skin,node.is_deployed())
			if skin in [6,8]:node.material.set_shader_parameter("signature_charge",node.yr_finish.stopped if skin==6 else maxf(node.yr_finish.charge,node.yr_finish.flash/0.32))
		else:node.yr_finish=null
		preload("res://scripts/units/night_hunter_skin.gd").configure(node,col)
		if preload("res://scripts/units/convoy_art.gd").handles(node):
			preload("res://scripts/units/convoy_art.gd").configure(node,col)
		elif preload("res://scripts/units/peregrine_art.gd").handles(node):
			preload("res://scripts/units/peregrine_art.gd").configure(node,col)
		else:
			preload("res://scripts/units/leizhu_art.gd").configure(node,col)
	return col


# ---------------------------------------------------------------- 全局同步

## 只设置玩家色（不落盘）。由 MetaProgress 载入 / 涂装页调用。
static func set_player_id(id: String) -> void:
	player_id = id if not palette().is_empty() else "allied"
	player_hex = hex_of(player_id)
	sync_hp()


## 设置玩家涂装（由涂装页调用）；会同步血条色并保存到 MetaProgress。
static func set_player(id: String) -> void:
	set_player_id(id)
	var loop := Engine.get_main_loop()
	if loop != null and loop is SceneTree:
		var mp := (loop as SceneTree).root.get_node_or_null("MetaProgress")
		if mp != null and mp.has_method("set_house_color"):
			mp.call("set_house_color", id)
	_sync_existing()


## 让血条色跟随阵营色（D3=A）。
static func sync_hp() -> void:
	HpBar.ally_fill = player_color()
	HpBar.enemy_fill = enemy_color_for("#ff5b4a")


## 已存在的对象重上色（用于涂装页即时预览 / 战斗内切换）。
static func _sync_existing() -> void:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	for n in (loop as SceneTree).get_nodes_in_group("house_colored"):
		if n is CanvasItem and n.has_method("refresh_house_color"):
			n.call("refresh_house_color")
