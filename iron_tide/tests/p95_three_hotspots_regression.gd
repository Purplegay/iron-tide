extends Node

const HouseAI = preload("res://scripts/world/house_ai.gd")
const Warmup = preload("res://scripts/buildings/building_art_warmup.gd")
const Detail = preload("res://scripts/core/shp_detail.gd")

class TestLine:
	var buildable: Array[String] = []
	var allowed: Dictionary = {}
	func can_queue(uid: String) -> bool:
		return allowed.get(uid, true)

class TestUnit:
	var unit_id := "E1"
	var _ra2: Dictionary = {}
	var _seq: Dictionary = {}

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var ai := HouseAI.new()
	ai.battle = Battle.new()
	var line := TestLine.new()
	line.buildable.assign(["ENGINEER", "E1", "GGI", "MTNK", "APOC"])
	var baseline := []
	for counts in [{}, {"E1": 2, "MTNK": 4}]:
		for budget in [100.0, 900.0, 5000.0]:
			baseline.append(ai.choose_combat_unit(line, budget, counts, [], {}, {}))
	var shared := {}
	var index := 0
	for counts in [{}, {"E1": 2, "MTNK": 4}]:
		for budget in [100.0, 900.0, 5000.0]:
			check(ai.choose_combat_unit(line, budget, counts, [], {}, shared) == baseline[index], "AI shared product facts change selection")
			index += 1
	line.allowed["MTNK"] = false
	check(ai.choose_combat_unit(line, 5000.0, {}, [], {}, shared) == ai.choose_combat_unit(line, 5000.0, {}, [], {}, {}), "AI live queue eligibility must override shared facts")
	ai.battle.free()
	ai.free()

	var warmup := Warmup.new()
	add_child(warmup)
	var u := TestUnit.new()
	var page := {"file": "p95-test.png", "width": 16, "height": 16}
	var art := {"kind": "shp", "count": 1, "rects": [{"x": 0, "y": 0, "w": 16, "h": 16}], "detail": {"lookup": {Vector4i(0, 0, 16, 16): {"page": 0}}, "pages": [page]}}
	u._ra2 = art
	warmup.prepare_infantry([u, u])
	check(warmup.jobs.size() == 1 and warmup.jobs.has(Detail.ROOT + "p95-test.png"), "Infantry current page must be queued once")
	warmup.prepare_infantry([u])
	check(warmup.jobs.size() == 1, "Repeat warmup must not requeue page")
	warmup.set_process(false)
	warmup.free()
	print("P95 three hotspots checks: ", index + 3, " failed: ", failed)
	get_tree().quit(0 if failed == 0 else 1)
