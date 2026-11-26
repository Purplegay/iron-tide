extends Node
## Capture the current faction roster in a single offscreen Godot viewport.

const GROUPS := [
	["盟军  /  步兵", "E1 GGI ENGINEER DOG JUMPJET GHOST SNIPE SPY TANY CLEG CCOMAND PTROOP"],
	["盟军  /  装甲、航空与舰艇", "MTNK TNKD MGTK SREF FV BFRT ROBO CMIN AMCV SHAD ORCA BEAG AEGIS CARRIER DEST CDEST LCRF DLPH"],
	["苏联  /  步兵", "E2 SHK FLAKT SENGINEER SOV_DOG IVAN CIVAN DESO TERROR BORIS"],
	["苏联  /  装甲、航空与舰艇", "HTNK APOC HTK TTNK V3 DTRUCK DRON HARV SMCV SCHP ZEP BPLN SPYP SUB HYD DRED SAPC SQD"],
	["盟苏  /  换装、部署、舰载机与任务模型", "FV_tur1 FV_tur2 FV_tur3 CMON HORV SCHD V3WO DESTWO DREDWO ASW HORNET PDPLANE CARGOPLANE HOWI HIND VLAD XCOMET V3ROCKET DMISL SUBT ZBOMB"],
	["防御炮塔  /  独立旋转部件", "GTGCAN NASAM NALASR NAFLAK"],
	["尤里  /  好莱坞任务单位", "INIT YURI YENGINEER SLAV LTNK YTNK SMIN YAREFN YAGGUN"],
]
const TITLES := {
	"GGI":"重装大兵", "BFRT":"战斗要塞", "ROBO":"遥控坦克", "FV_tur1":"步战车 · 换装 1",
	"FV_tur2":"步战车 · 换装 2", "FV_tur3":"步战车 · 换装 3", "CMON":"超时空矿车 · 卸矿",
	"HORV":"武装矿车 · 卸矿", "SCHD":"武装直升机 · 部署", "V3WO":"V3 · 空架",
	"DESTWO":"驱逐舰 · 离舰", "DREDWO":"无畏舰 · 发射后", "ASW":"舰载反潜机", "HORNET":"舰载战机",
	"PDPLANE":"空降运输机", "CARGOPLANE":"货运飞机", "HOWI":"榴弹炮", "HIND":"雌鹿直升机",
	"VLAD":"旗舰", "XCOMET":"衍生模型", "SUBT":"鱼雷", "ZBOMB":"飞艇炸弹",
	"GTGCAN":"法国巨炮", "NASAM":"爱国者导弹", "NALASR":"哨戒炮", "NAFLAK":"防空炮",
}
const COLS := 10
const TILE := Vector2i(174, 101)
const MARGIN := 28
var names := TITLES.duplicate()
var surface := SubViewport.new()
var missing := PackedStringArray()
var font := SystemFont.new()

class Model extends Node2D:
	var layers: Array = []
	func _draw() -> void:
		for layer in layers:
			RA2Art.draw_sprite(self, layer.art, layer.target, layer.source, RA2Art.sprite_grade(layer.art))

func caption(content: String, at: Vector2, extent: Vector2, pixels: int, ink: Color, centered := false) -> void:
	var label := Label.new()
	label.text = content
	label.position = at
	label.size = extent
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", ink)
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surface.add_child(label)

func fill(at: Vector2, extent: Vector2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = at
	panel.size = extent
	panel.color = color
	surface.add_child(panel)

func model_tile(id: String, top_left: Vector2, house: Color, defense: bool, hollywood: bool) -> void:
	var model := Model.new()
	model.material = HouseColor.material_for(house, HouseColor.PaintMode.NONE, 0, hollywood)
	model.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key := "FV" if id.begins_with("FV_tur") else id
	if defense:
		var descriptor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/bldturret/%s.json" % id))
		key = descriptor.image
	var body := RA2Art.art(key)
	var keys := [key]
	var turret := id if id.begins_with("FV_tur") else str(body.get("turret", ""))
	var mount := BuildingTurretArt.new()
	if id in ["YAREFN","YAGGUN"]:
		mount.setup(id)
		turret = mount.art.get("key", "")
		if turret.is_empty(): missing.append(id + " (turret)")
	if turret != "": keys.append(turret)
	var bounds := Rect2()
	for part in keys:
		var art := RA2Art.art(part)
		if art.is_empty():
			missing.append(part)
			continue
		var frame := 3 + int(art.get("facing_offset", 0))
		if art.kind == "shp": frame = maxi(0, RA2Art.seq_frame(RA2Art.seq(part), "Ready", 3, 0))
		var source := RA2Art.src_rect(art, frame)
		var offset: Array = art.get("draw_offset", [0, 0])
		var target := Rect2(Vector2(offset[0], offset[1]), source.size)
		if hollywood and art.kind == "vxl" and (not art.get("palette_lit", false) or not art.has("detail_tex") or RA2Art.sprite_grade(art) != Color.WHITE):
			missing.append(part + " (baked lighting)")
		if part == turret and not mount.art.is_empty():
			var anchor: Array = mount.origins[frame]
			target.position = RA2Art.frame_size(body) * 0.5 + mount.offset - Vector2(anchor[0],anchor[1])
		var visible := RA2Art.visible_sprite_rect(art, target, source)
		if not visible.has_area():
			missing.append(part + " (empty)")
			continue
		bounds = bounds.merge(visible) if bounds.has_area() else visible
		model.layers.append({"art":art, "target":target, "source":source})
	if bounds.has_area():
		var zoom := minf(2.0, minf((TILE.x - 10.0) / bounds.size.x, 69.0 / bounds.size.y))
		model.scale = Vector2.ONE * zoom
		model.position = (top_left + Vector2(TILE.x * 0.5, 37) - bounds.get_center() * zoom).round()
	surface.add_child(model)
	caption(names.get(id,id), top_left + Vector2(0,72), Vector2(TILE.x,25), 16, Color("#e8edf0"), true)

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	BattleRequest.skirmish = false
	BattleRequest.mission_id = "yr_hollywood"
	var soviet := {}
	for path in ["ra2_allied", "yr_soviet", "hollywood_cast", "hollywood_yuri"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % path))
		var units: Array = data.units.values() if data.units is Dictionary else data.units
		for unit in units:
			names[unit.id] = unit.name
			if path == "yr_soviet": soviet[unit.id] = true
		if path.begins_with("hollywood"):
			for site in data.buildings.values(): names[site.id] = site.name
	for id in "HORV SCHD V3WO DREDWO HIND VLAD XCOMET SUBT ZBOMB NAFLAK NALASR".split(" "): soviet[id] = true
	var height := 80
	for group in GROUPS:
		height += 45 + ceili(float(group[1].split(" ").size()) / COLS) * TILE.y
	surface.size = Vector2i(2 * MARGIN + COLS * TILE.x, height + MARGIN)
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(surface)
	fill(Vector2.ZERO, surface.size, Color("#20292f"))
	caption("IronTide  0.32    /    单位模型总览", Vector2(MARGIN,15), Vector2(800,50), 32, Color.WHITE)
	var y := 70
	var count := 0
	for group in GROUPS:
		var title: String = group[0]
		var ids: PackedStringArray = group[1].split(" ")
		caption(title, Vector2(MARGIN,y), Vector2(900,32), 21, Color("#b9c8d0"))
		y += 38
		for i in ids.size():
			var id := ids[i]
			var p := Vector2(MARGIN + (i % COLS) * TILE.x, y + floori(float(i) / COLS) * TILE.y)
			fill(p, TILE - Vector2i(3,3), Color("#3a464c"))
			var house := Color("#d83434") if soviet.has(id) else Color("#387ddd")
			var hollywood := title.begins_with("尤里")
			if hollywood: house = HouseColor.color_for_side("enemy", "")
			model_tile(id, p, house, title.begins_with("防御"), hollywood)
		count += ids.size()
		y += ceili(float(ids.size()) / COLS) * TILE.y + 7
	if not missing.is_empty():
		push_error("Missing gallery models: " + ", ".join(missing))
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if directory.is_empty(): directory = "user://"
	var output := directory.path_join("faction-roster.png")
	var result := surface.get_texture().get_image().save_png(output)
	print("Faction overview: %d entries, %s, %s" % [count, surface.size, output])
	get_tree().quit(0 if result == OK else 1)
