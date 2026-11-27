extends Node
const ReferenceExtra := [26.0, 66.0, 106.0]
var failed := 0
var checks: Array = []

func check(label: String, ok: bool) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failed += 1

func reference_exit(b: Building, uid: String) -> Vector2:
	var data := GameData.get_unit(uid)
	var hull := maxf(1.0, float(data.get("radius", 8.0)))
	for extra in ReferenceExtra:
		for i in 24:
			var d := Vector2.DOWN.rotated(TAU * float(i) / 24.0)
			var p := b.global_position + d * (b.footprint_clearance(d) + float(extra) + hull)
			if b._exit_position_clear(p, hull, false, false): return p
	return Vector2.INF

func _ready() -> void:
	var out := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	var w := Battle.new()
	w.map_size = 1800.0
	w.path_service = PathService.new()
	w.path_service.configure(1800.0)
	var size: int = w.path_service.cols * w.path_service.rows
	w.path_service.cost.resize(size)
	var b := Building.new()
	b.battle = w
	b.building_id = "NAHAND"
	b.position = Vector2(900,900)
	b.radius = 35.0
	check("legacy path fixture",not ProductionExit.supported(b))
	w.path_service.cost.fill(-1.0)
	check("first blocked search",b._spawn_point("E2") == Vector2.INF)
	check("blocked repeat retains answer",b._spawn_point("E2") == Vector2.INF)
	check("a grid rejection was retained",b._legacy_exit_blockers[0].is_finite())
	w.path_service.cost.fill(1.0)
	var expected := reference_exit(b,"E2")
	check("opens immediately without requiring epoch change",expected.is_finite() and b._spawn_point("E2") == expected)
	var blocker := Unit.new()
	blocker.position = expected
	blocker.radius = 30.0
	blocker.hp = 100.0
	w.units.append(blocker)
	var alternate := reference_exit(b,"E2")
	check("living unit changes the selected exit",alternate.is_finite() and alternate != expected and b._spawn_point("E2") == alternate)
	blocker.position += Vector2(500,0)
	check("vacated first exit immediately preferred", b._spawn_point("E2") == expected)
	w.path_service.cost.fill(-1.0)
	b._spawn_point("E2")
	b._spawn_point("E2")
	check("cell indices recorded after a retry", b._legacy_exit_cells[0] >= 0)
	var prior_size: float = w.path_service.cell
	w.path_service.configure(1800.0, prior_size * 1.25)
	w.path_service.cost.resize(w.path_service.cols * w.path_service.rows)
	w.path_service.cost.fill(1.0)
	check("grid shape change reuses no stale index", b._spawn_point("E2") == reference_exit(b,"E2") and b._legacy_exit_cell_size == w.path_service.cell and b._legacy_exit_cell_size != prior_size)
	for pos in [Vector2(2,2),Vector2(900,700),Vector2(1799,1799)]:
		b.position = pos
		for hull in ["E2","TTNK"]:
			check("moved producer and product radius "+str([pos,hull]),b._spawn_point(hull) == reference_exit(b,hull))
	b.free();w.units.clear();blocker.free();w.path_service.free();w.free()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
