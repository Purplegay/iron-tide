extends "res://tests/base_recovery_regression.gd"

const RangePreview = preload("res://scripts/world/build_range_preview.gd")
const Tech = preload("res://scripts/rules/production_technology.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
var source: Dictionary

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	source = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/yr_baseline_source.json"))
	await get_tree().process_frame
	GM.god_mode = false
	GM.infinite_funds = false
	MetaProgress.reset_save()
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		for id in source.entities:
			var raw: Dictionary = source.entities[id]
			var data: Dictionary = GameData.get_entity(id)
			check(float(data.hp) == float(raw.get("strength", 1)), prefix + id + " native HP")
			check(float(data.cost) == float(raw.get("cost", 0)), prefix + id + " native price")
			check(str(data.ra2_armor) == str(raw.get("armor", "none")), prefix + id + " native armor")
			var seconds := float(raw.get("cost", 0)) * float(source.general.buildspeed) * 60.0 / 1000.0 * float(raw.get("buildtimemultiplier", 1))
			if str(raw.get("wall", "no")) == "yes": seconds /= float(source.general.wallbuildspeedcoefficient)
			check(is_equal_approx(GameData.ra2_build_time(data), maxf(1.0, seconds)), prefix + id + " native production duration")
			if GameData.is_building(id):
				check(RangePreview.provides_range(data) == (str(raw.get("basenormal", "yes")) != "no"), prefix + id + " native range source flag")
				check(is_equal_approx(RangePreview.adjacency_distance(battle, data), float(raw.get("adjacent", 2)) * 55.0), prefix + id + " native adjacency distance")
		await range_and_walls(mode)
		await stance(mode)
		await progression(mode)
		await finish()
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failed": failed, "source": source.source}, "  "))
	f.close()
	print("YR_BASELINE checks=", checks.size(), " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)

func range_and_walls(mode: String) -> void:
	var before: int = RangePreview.adjacency_sources(battle).size()
	for id in ["GAPILL", "ATESLA", "GAWALL", "GAYARD"]:
		var b = battle._place_building(id, "ally", Vector2(1800, 1800), true)
		b._buildup_play = -1.0
		check(RangePreview.adjacency_sources(battle).size() == before, prefix + id + " cannot extend territory")
		battle.buildings.erase(b)
		b.free()
	var yard = battle._player_hq()
	battle.select_building(yard)
	battle.armed_build = ""
	battle.build_range_preview.update(battle)
	var broad: int = battle.build_range_preview.cells.size()
	var points: Dictionary = RangePreview.coverage(battle, RangePreview.adjacency_sources(battle), Rect2(), 80.0)
	check(broad > points.size(), prefix + "selected base includes real proposed footprint")
	battle.armed_build = "GAWALL"
	battle.preview_override = yard.global_position + Vector2(200, 0)
	battle.build_range_preview.update(battle)
	check(battle.build_range_preview.expansion_cells.is_empty(), prefix + "wall never advertises expansion")
	# Build an open, legal wall corridor beside one native base source.
	var plant = battle._place_building("GAPOWR", "ally", Vector2(1200, 1200), true)
	plant._buildup_play = -1.0
	check(plant.max_hp == 750.0, prefix + "spawned plant consumes original Strength without hidden multiplier")
	var origin := Vector2(1200, 1440)
	var end = battle._place_building("GAWALL", "ally", origin + Vector2(160, 0), true)
	end._buildup_play = -1.0
	battle.funds = 1000.0
	var proposed := WallArt.plan(battle, "GAWALL", "ally", origin)
	check(proposed.points.size() == 3 and proposed.cost == 300.0, prefix + "ready wall predicts three paid connecting cells", proposed)
	battle.struct_ready.GAWALL = 1
	battle.armed_build = "GAWALL"
	battle.preview_override = origin
	await capture(mode + "-wall-ready", origin)
	var count: int = battle.buildings.size()
	battle._try_place_building(origin)
	check(battle.buildings.size() == count + 4 and battle.funds == 700.0 and not battle.struct_ready.has("GAWALL"), prefix + "placement exactly matches preview count and price")
	for point in proposed.points:
		check(battle.buildings.any(func(b): return b.building_id == "GAWALL" and b.global_position == point), prefix + "preview cell actually filled " + str(point))
	# Budget limits preview before payment, rather than quietly building a different line.
	var origin2 := Vector2(1200, 1520)
	var end2 = battle._place_building("GAWALL", "ally", origin2 + Vector2(160, 0), true)
	end2._buildup_play = -1.0
	battle.funds = 150.0
	proposed = WallArt.plan(battle, "GAWALL", "ally", origin2)
	check(proposed.points.size() == 1 and proposed.cost == 100 and not proposed.blocked.is_empty(), prefix + "insufficient funds visibly limits automatic fill", proposed)
	battle.armed_build = ""
	battle.preview_override = Vector2.INF
	var buildings: Array = screen.hud._building_catalog()
	check(buildings.find("GAPOWR") < buildings.find("GAPILE") and buildings.find("GAPILE") < buildings.find("GAREFN"), prefix + "sidebar follows power barracks refinery order")
	check(GameData.catalog_sorted(["MGTK", "MTNK", "CMIN", "FV"], "unit") == ["CMIN", "MTNK", "FV", "MGTK"], prefix + "vehicle roster follows native progression")

func stance(mode: String) -> void:
	# Isolate target-policy choices from the starting enemy base's buildings.
	for b in battle.buildings.duplicate():
		if b.side == "enemy":
			battle.buildings.erase(b)
			b.free()
	var unit = battle.spawn_unit("MTNK", "ally", Vector2(1200, 800))
	check(unit.max_hp == 300.0, prefix + "spawned vehicle consumes original Strength")
	var attacker = battle.spawn_unit("MTNK", "enemy", Vector2(1320, 800))
	var bystander = battle.spawn_unit("E1", "enemy", Vector2(1250, 800))
	check(unit.fire_stance == "defend", prefix + "new friendly units default to mobile-target defense")
	unit.set_fire_stance("return")
	unit._refresh_target()
	check(unit.attack_target == null, prefix + "idle ignores nearby enemies")
	unit.receive_hit(1.0, "shell", {}, attacker)
	unit._refresh_target()
	check(unit.attack_target == attacker, prefix + "return fire targets attacker rather than nearby bystander")
	attacker.global_position = Vector2(2200, 800)
	unit._refresh_target()
	check(unit.attack_target == null and not unit.has_move_order, prefix + "return fire never pursues distant attacker")
	battle.select_unit(unit, false)
	battle._emit_selection()
	check(screen.hud.cmd_buttons.has("guard"), prefix + "explicit guard command exists")
	screen.hud.cmd_buttons.guard.pressed.emit()
	unit._refresh_target()
	check(unit.fire_stance == "free" and unit.hold_position and unit.attack_target == bystander, prefix + "actual guard button enables bounded proactive fire", {"stance": unit.fire_stance, "hold": unit.hold_position, "target": str(unit.attack_target)})
	check(screen.hud.cmd_buttons.guard.get_children().any(func(c): return c is TextureRect and c.texture.resource_path.ends_with("guard.png")), prefix + "guard button consumes original Yuri icon")
	await capture(mode + "-guard", unit.position)
	unit.order_stop()
	unit._refresh_target()
	check(unit.fire_stance == "defend" and unit.attack_target == bystander, prefix + "stop restores automatic defense without pursuit")
	battle.force_attack(bystander)
	check(unit.attack_ordered and unit._weapon_target_valid(bystander), prefix + "manual attack bypasses idle retaliation timer")
	unit.order_stop()
	unit.order_move(Vector2(1400, 800), true)
	unit._refresh_target()
	check(unit.attack_target == bystander and unit._weapon_target_valid(bystander), prefix + "explicit attack-move still acquires and can fire", {"target": str(unit.attack_target), "move": unit.attack_move, "valid": unit._weapon_target_valid(bystander)})
	unit.order_guard()
	check(BattleSaves.save_slot(battle, "slot1").ok, prefix + "guard state writes to real save")
	var saved := BattleSaves.read_slot("slot1")
	check(saved.ok, prefix + "guard save validates")
	Snapshot.new().restore(battle, saved.snapshot)
	get_tree().paused = false
	battle.paused = false
	unit = battle.units.filter(func(u): return u.side == "ally" and u.unit_id == "MTNK")[0]
	check(unit.fire_stance == "free" and unit.hold_position, prefix + "load preserves explicitly selected guard")

func progression(mode: String) -> void:
	var tech = Tech.new()
	check(tech.structure_capacity("ally") == 1, prefix + "unresearched structure capacity is one")
	check(not tech.unlock("structure_queue_3", "ally"), prefix + "capacity tiers enforce prerequisites")
	for pair in [["structure_queue", 9], ["structure_queue_2", 18], ["structure_queue_3", 27]]:
		check(tech.unlock(pair[0], "ally") and tech.structure_capacity("ally") == pair[1], prefix + "tier capacity " + str(pair[1]))
	MetaProgress.unlocked_technologies.clear()
	MetaProgress.grant("credits", 9000)
	for id in ["structure_queue", "structure_queue_2", "structure_queue_3"]:
		check(MetaProgress.research_technology(id), prefix + "durable research " + id)
	var funds := MetaProgress.balance("credits")
	check(not MetaProgress.research_technology("structure_queue_3") and MetaProgress.balance("credits") == funds, prefix + "duplicate purchase cannot spend")
	MetaProgress.unlocked_technologies.clear()
	MetaProgress.load_save()
	check(MetaProgress.technology_owned("structure_queue_3"), prefix + "capacity upgrade survives disk reload")
	battle.production_technology = tech
	battle.struct_queue.clear()
	battle.struct_ready.clear()
	battle.struct_ready.GAPOWR = 27
	check(not battle.structure_queue_block_reason("GAPILE").is_empty(), prefix + "ready buildings consume finite capacity")
	battle.struct_ready.GAPOWR = 26
	check(battle.structure_queue_block_reason("GAPILE").is_empty(), prefix + "one available slot accepts next building")
	check(battle.structure_queue_block_reason("GAWALL").is_empty(), prefix + "defense capacity remains independent")
	var ui = load("res://scripts/ui/technology_tree.gd").new()
	add_child(ui)
	check(ui.cards.has("structure_queue_2") and ui.cards.has("structure_queue_3"), prefix + "permanent upgrade UI exposes both new tiers")
	ui.free()

func capture(label: String, pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless": return
	battle.camera.position = pos
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	battle.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
