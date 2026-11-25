extends "res://tests/building_preview_regression.gd"

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 8000, "fog_of_war": false})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.process_mode = Node.PROCESS_MODE_ALWAYS
	battle.set_process(false)
	battle.set_physics_process(false)
	for child in battle.get_children(): child.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in battle.buildings + battle.units:
		if is_instance_valid(actor): actor.free()
	battle.buildings.clear()
	battle.units.clear()
	for group in ["obstacles", "resource_nodes"]:
		for actor in get_tree().get_nodes_in_group(group): actor.free()
	battle.path_service.set_water([])
	var anchor = battle._place_building("GAPOWR", "ally", Vector2(1520, 1600), true)
	anchor._buildup_play = -1.0
	anchor.process_mode = Node.PROCESS_MODE_DISABLED
	var extension = battle._place_building("GAWEAP", "ally", Vector2(1760, 1600), true)
	extension._buildup_play = -1.0
	extension.process_mode = Node.PROCESS_MODE_DISABLED
	var enemy = battle._place_building("GAPOWR", "enemy", Vector2(2400, 1600), true)
	enemy._buildup_play = -1.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var preview = battle.build_range_preview
	var prefix := mode + ": "
	for id in ["GAPOWR", "GAWEAP", "GAYARD"]:
		battle.path_service.set_water([Rect2(0, 0, 3200, 3200)] if id == "GAYARD" else [])
		battle.armed_build = id
		preview.update(battle)
		var data := GameData.get_building(id)
		var mismatches: Array = []
		var legal := 0
		var excluded := 0
		for x in range(800, 2801, 40):
			for y in range(800, 2401, 40):
				var position := Vector2(x, y)
				var result: Dictionary = battle.build_spot_ok(position, data, true)
				var shown: bool = preview.cells.has(Vector2i(x / 40, y / 40))
				if result.ok:
					legal += 1
					if not shown: mismatches.append([position, result])
				elif result.reason == "超出建造范围，请靠近己方建筑或盟友建造场":
					excluded += 1
					if shown: mismatches.append([position, result])
		check(mismatches.is_empty() and legal > 0 and excluded > 0, prefix + id + " overlay agrees with actual placement across 2091 grid centers", mismatches)
		var with_enemy: Dictionary = preview.cells.duplicate()
		enemy.hp = 0.0
		preview.update(battle)
		check(preview.cells == with_enemy, prefix + id + " enemy building does not extend range")
		enemy.hp = enemy.max_hp
		preview.update(battle)
		check(not battle.build_spot_ok(anchor.position, data, true).ok, prefix + id + " coverage never bypasses occupied footprint")
		check(not preview.edges.is_empty(), prefix + id + " visible outer boundary generated")
		var stored: Dictionary = preview.cells.duplicate()
		preview.update(battle)
		check(preview.cells == stored, prefix + id + " unchanged preview reuses geometry")
		if id == "GAPOWR":
			for zoom in [0.5, 1.0, 2.0]:
				await show_preview(mode + "-range-" + str(zoom), Vector2(1600, 1760), zoom)
		if id == "GAYARD":
			await show_preview(mode + "-shipyard-range", Vector2(1600, 1920), 1.0)
	await check_expansion(mode)
	# Selection of a different footprint changes coverage; removing a source shrinks it.
	battle.path_service.set_water([])
	battle.armed_build = "GAPOWR"
	preview.update(battle)
	var both: int = preview.cells.size()
	extension.under_construction = true
	preview.update(battle)
	check(preview.cells.size() < both, prefix + "unfinished source cannot extend construction territory")
	extension.under_construction = false
	preview.update(battle)
	check(preview.cells.size() == both, prefix + "completion immediately expands territory")
	check(battle.apply_building_action("sell", extension), prefix + "actual sale accepted")
	preview.update(battle)
	check(preview.cells.size() < both, prefix + "sale immediately removes extension area")
	# Map boundary clips centers by the proposed foundation, not just its anchor.
	anchor.position = Vector2(0, 0)
	preview.update(battle)
	var out_of_map := 0
	var local := Placement.aabb(Building.placement_poly(GameData.get_building("GAPOWR")))
	for cell in preview.cells:
		var bounds := Rect2(local.position + Vector2(cell) * 40, local.size)
		if bounds.position.x < 0 or bounds.position.y < 0 or bounds.end.x > 3200 or bounds.end.y > 3200: out_of_map += 1
	check(out_of_map == 0 and not preview.cells.is_empty(), prefix + "map edge only shows centers with complete footprint inside map")
	battle.armed_build = ""
	preview.update(battle)
	check(preview.cells.is_empty() and preview.edges.is_empty() and preview.expansion_cells.is_empty() and preview.expansion_edges.is_empty(), prefix + "cancel clears both overlays")
	await check_selected_base(mode)
	await check_yard_reach(mode)
	check_allied_placement(mode)
	battle.armed_build = "GAPOWR"
	battle.ended = true
	preview.update(battle)
	check(preview.cells.is_empty() and preview.expansion_cells.is_empty(), prefix + "battle end hides both construction overlays")
	screen.free()
	await get_tree().process_frame

func check_expansion(mode: String) -> void:
	var preview = battle.build_range_preview
	for id in ["GAPOWR", "GAWEAP", "GAYARD"]:
		var prefix: String = mode + " " + id + " expansion: "
		battle.path_service.set_water([Rect2(0, 0, 3200, 3200)] if id == "GAYARD" else [])
		battle.armed_build = id
		battle.struct_ready[id] = 1
		preview.update(battle)
		var original: Dictionary = preview.cells.duplicate()
		var data := GameData.get_building(id)
		var spots: Array[Vector2] = []
		for cell in original:
			var position: Vector2 = Vector2(cell) * battle.BUILD_GRID
			if battle.build_spot_ok(position, data, true).ok:
				spots.append(position)
		check(spots.size() > 1, prefix + "legal positions available")
		if spots.size() < 2: continue
		battle.preview_override = spots[0]
		preview.update(battle)
		var predicted: Dictionary = preview.expansion_cells.duplicate()
		var adds_range: bool = preview.provides_range(data)
		check((not predicted.is_empty() and not preview.expansion_edges.is_empty()) if adds_range else (predicted.is_empty() and preview.expansion_edges.is_empty()), prefix + "prediction respects native BaseNormal")
		var overlapping := 0
		for cell in predicted:
			if original.has(cell): overlapping += 1
		check(overlapping == 0, prefix + "green region excludes existing coverage")
		battle.preview_override = spots[-1]
		preview.update(battle)
		check((preview.expansion_cells != predicted if adds_range else preview.expansion_cells.is_empty()) and preview.cells == original, prefix + "moving preview respects BaseNormal without granting territory")
		for zoom in [0.5, 1.0, 2.0]:
			await show_preview(mode + "-expansion-" + id + "-" + str(zoom), spots[0], zoom)
			check(preview.expansion_cells == predicted, prefix + "zoom preserves added world region")
		battle.preview_override = spots[0]
		# Real blockers must invalidate a cached prediction without moving the cursor.
		var blocker = battle._place_building(id, "enemy", spots[0], true)
		blocker.process_mode = Node.PROCESS_MODE_DISABLED
		preview.update(battle)
		check(preview.expansion_cells.is_empty() and preview.expansion_edges.is_empty(), prefix + "new obstruction at unchanged cursor clears prediction")
		battle.buildings.erase(blocker)
		blocker.free()
		preview.update(battle)
		check(preview.expansion_cells == predicted, prefix + "removing obstruction restores prediction")
		# Materialize the proposed foundation: unfinished buildings grant no range;
		# completion must produce precisely the previously predicted difference.
		var added = battle._place_building(id, "ally", spots[0], true)
		added.process_mode = Node.PROCESS_MODE_DISABLED
		added.under_construction = true
		preview.update(battle)
		check(preview.cells == original, prefix + "unfinished building does not activate predicted range")
		added.under_construction = false
		preview.update(battle)
		var actual: Dictionary = preview.cells.duplicate()
		for cell in original: actual.erase(cell)
		check(actual == predicted, prefix + "completed real building adds exactly predicted coverage")
		var rejected := 0
		for cell in predicted:
			var result: Dictionary = battle.build_spot_ok(Vector2(cell) * battle.BUILD_GRID, data, true)
			if result.reason == "超出建造范围，请靠近己方建筑或盟友建造场" or result.reason == "超出地图边界": rejected += 1
		check(rejected == 0, prefix + "new grid centers pass actual adjacency and map bounds")
		battle.buildings.erase(added)
		added.free()
		preview.update(battle)
		check(preview.cells == original and preview.expansion_cells == predicted, prefix + "removing source restores existing and predicted areas")
		for invalid in [Vector2.ZERO, Vector2(3000, 3000), Vector2(1520, 1600)]:
			battle.preview_override = invalid
			preview.update(battle)
			check(preview.expansion_cells.is_empty(), prefix + "invalid position never promises expansion " + str(invalid))
		battle.armed_build = ""
		preview.update(battle)
		check(preview.expansion_cells.is_empty() and preview.expansion_edges.is_empty(), prefix + "cancelling clears prediction")
		battle.struct_ready.erase(id)
	battle.preview_override = Vector2.INF

func check_selected_base(mode: String) -> void:
	var base = battle._place_building("GACNST", "ally", Vector2(1600, 1600), true)
	base._buildup_play = -1.0
	base.process_mode = Node.PROCESS_MODE_DISABLED
	var preview = battle.build_range_preview
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(1, 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	get_window().focus_entered.emit()
	await get_tree().process_frame
	get_window().focus_entered.emit()
	check(battle.world_input_enabled(), mode + " base-click focus precondition")
	var point: Vector2 = stage.get_canvas_transform() * base.art_center()
	await mouse_button(point, true)
	await mouse_button(point, false)
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	check(battle.selected_building == base and battle.armed_build.is_empty(), mode + " real base click selects without arming construction", {"focused": battle.world_input_enabled(), "point": point, "armed": battle.armed_build, "selected": str(battle.selected_building)})
	check(not preview.cells.is_empty() and not preview.edges.is_empty(), mode + " selection redraw displays construction territory without placement mode")
	var normal: Dictionary = preview.cells.duplicate()
	for zoom in [0.5, 1.0, 2.0]:
		await show_preview(mode + "-selected-base-range-" + str(zoom), Vector2(1600, 1600), zoom)
		check(preview.cells == normal, mode + " zoom preserves selected base world territory")
	battle.armed_build = "GAYARD"
	preview.update(battle)
	check(preview.cells.size() > normal.size(), mode + " shipyard placement replaces selected base range with naval range")
	battle.armed_build = ""
	preview.update(battle)
	check(preview.cells == normal, mode + " cancelling placement restores selected base territory")
	for state in ["enemy", "unfinished", "dead"]:
		base.side = "enemy" if state == "enemy" else "ally"
		base.under_construction = state == "unfinished"
		base.hp = 0.0 if state == "dead" else base.max_hp
		preview.update(battle)
		check(preview.cells.is_empty(), mode + " selected " + state + " base cannot show friendly territory")
	base.side = "ally"
	base.under_construction = false
	base.hp = base.max_hp
	var unit = battle.spawn_unit("E1", "ally", Vector2(1800, 1700))
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_unit(unit, false)
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " selecting a unit hides base territory")
	var outer: Vector2 = base.global_position
	for cell in normal:
		var cell_center: Vector2 = Vector2(cell) * battle.BUILD_GRID
		if cell_center.y == outer.y and cell_center.x > outer.x: outer = cell_center
	var ordinary = battle._place_building("GAPOWR", "ally", outer, true)
	ordinary.process_mode = Node.PROCESS_MODE_DISABLED
	battle.select_building(ordinary)
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " ordinary building selection does not show base territory")
	battle.select_building(base)
	preview.update(battle)
	check(preview.cells.size() > normal.size(), mode + " additional friendly building expands territory")
	battle.clear_selection()
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " clear selection hides base territory")

func check_yard_reach(mode: String) -> void:
	# A lone, real construction yard, so nearby starter buildings cannot mask reach.
	battle.clear_selection()
	for actor in battle.buildings + battle.units:
		if is_instance_valid(actor): actor.free()
	battle.buildings.clear()
	battle.units.clear()
	battle.path_service.set_water([])
	var base = battle._place_building("GACNST", "ally", Vector2(1600, 1600), true)
	base._buildup_play = -1.0
	base.process_mode = Node.PROCESS_MODE_DISABLED
	var preview = battle.build_range_preview
	var data := GameData.get_building("GAPOWR")
	var source_rect := Placement.aabb(battle.footprint_of(base), base.position)
	var local := Placement.aabb(Building.placement_poly(data))
	var expected_distance := 660.0 if mode == MatchRules.EXTENDED else 110.0
	check(is_equal_approx(preview.source_distance(battle, data, base.data), expected_distance), mode + " yard exact reach in world grid units")
	check(preview.source_distance(battle, data, data) == 110.0, mode + " ordinary power plant never inherits yard bonus")
	check(preview.source_distance(battle, GameData.get_building("GAYARD"), base.data) == 660.0, mode + " native shipyard Adjacent is preserved")
	battle.armed_build = ""
	battle.select_building(base)
	preview.update(battle)
	var selected_cells: Dictionary = preview.cells.duplicate()
	battle.armed_build = "GAPOWR"
	preview.update(battle)
	check(preview.cells == selected_cells, mode + " selected yard preview equals actual power-plant placement envelope")
	var far_spot := Vector2.INF
	var mismatch := 0
	var boundary_legal := 0
	var boundary_rejected := 0
	for x in range(720, 2481, 40):
		for y in range(720, 2481, 40):
			var pos := Vector2(x, y)
			var gap := Placement.aabb_gap(Rect2(local.position + pos, local.size), source_rect)
			var expected := gap <= expected_distance
			var shown: bool = preview.cells.has(Vector2i(x / 40, y / 40))
			var result: Dictionary = battle.build_spot_ok(pos, data, true)
			if shown != expected or (result.ok and not expected) or (result.reason == "超出建造范围，请靠近己方建筑或盟友建造场" and expected): mismatch += 1
			if gap > 440.0 and gap <= 660.0 and result.ok: far_spot = pos
			if gap <= expected_distance and gap > expected_distance - 40.0 and result.ok: boundary_legal += 1
			if gap > expected_distance and gap < expected_distance + 40.0 and not result.ok: boundary_rejected += 1
	check(mismatch == 0 and boundary_legal > 0 and boundary_rejected > 0, mode + " 2025 centers independently match exact distance, overlay and real placement", mismatch)
	check(far_spot.is_finite() == (mode == MatchRules.EXTENDED), mode + " extension grants real new build space; RA2 remains unchanged")
	# The extra region belongs to an operational friendly yard, not the player forever.
	base.under_construction = true
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " unfinished yard grants no territory")
	base.under_construction = false
	base.hp = 0
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " destroyed yard immediately loses territory")
	base.hp = base.max_hp
	base.side = "enemy"
	preview.update(battle)
	check(preview.cells.is_empty(), mode + " captured-away yard immediately loses ally territory")
	check(preview.allows_placement(battle, Rect2(local.position + Vector2(1600, 1880), local.size), data, "enemy") == (mode == MatchRules.EXTENDED), mode + " same reach rule applies to actual owner")
	base.side = "ally"
	for id in ["GAPILL", "ATESLA", "GAWALL", "GAYARD"]:
		preview.update(battle)
		var before: Dictionary = preview.cells.duplicate()
		var extra = battle._place_building(id, "ally", Vector2(2400, 2400), true)
		extra.process_mode = Node.PROCESS_MODE_DISABLED
		preview.update(battle)
		check(preview.cells == before, mode + " non-BaseNormal never extends range: " + id)
		battle.buildings.erase(extra)
		extra.free()
	if far_spot.is_finite():
		await show_preview(mode + "-yard-twelve-cells", Vector2(1600, 1920), 0.75)
		battle.preview_override = far_spot
		battle.struct_ready.GAPOWR = 1
		preview.update(battle)
		var before: Dictionary = preview.cells.duplicate()
		var predicted: Dictionary = preview.expansion_cells.duplicate()
		var count: int = battle.buildings.size()
		battle._try_place_building(far_spot)
		check(battle.buildings.size() == count + 1 and not battle.struct_ready.has("GAPOWR"), mode + " actual ready building can be placed in added region")
		var added = battle.buildings[-1]
		check(added.position == far_spot, mode + " placed foundation matches chosen far grid center")
		check(not added.under_construction, mode + " fully paid ready building is already complete")
		# Separately exercise an unfinished foundation; ready placements finish instantly.
		added.under_construction = true
		battle.armed_build = "GAPOWR"
		preview.update(battle)
		check(preview.cells == before, mode + " unfinished new plant does not grant prediction early")
		added.under_construction = false
		preview.update(battle)
		var gained: Dictionary = preview.cells.duplicate()
		for cell in before: gained.erase(cell)
		check(gained == predicted, mode + " green prediction remains exact beside enlarged yard")
		battle.buildings.erase(added)
		added.free()
	battle.armed_build = ""
	battle.preview_override = Vector2.INF
	battle.select_building(base)
	await show_preview(mode + "-yard-selected", Vector2(1600, 1600), 0.75)
	var fog = preload("res://scripts/world/fog_of_war.gd").new()
	battle.fog = fog
	battle.add_child(fog)
	fog.setup(battle)
	var yard_sight: float = fog.vision_radius(base)
	check(battle.ConstructionRepack.execute(battle, base), mode + " repack selected yard")
	var mcv = battle.selected_mcv()
	if is_instance_valid(mcv):
		preview.update(battle)
		check(preview.cells == selected_cells if mode == MatchRules.EXTENDED else preview.cells.is_empty(), mode + " packed territory at former yard")
		mcv.position = Vector2(640, 640)
		fog._process(10.0)
		fog.rebuild()
		var site := Vector2(1200, 640)
		check(is_equal_approx(fog.vision_radius(mcv), yard_sight) and battle.position_visible_to("ally", site), mode + " packed vehicle reveals distant new site")
		preview.update(battle)
		check(preview.cells.has(Vector2i(site / battle.BUILD_GRID)) == (mode == MatchRules.EXTENDED) and not preview.cells.has(Vector2i(40,40)), mode + " mobile preview follows vehicle")
		check(battle.build_spot_ok(site, data, true).ok == (mode == MatchRules.EXTENDED), mode + " actual mobile build check in fog")
		battle.units.erase(mcv)
		battle.clear_selection()
		mcv.free()
	battle.fog = null
	fog.free()

func check_allied_placement(mode: String) -> void:
	var original := BattleRequest.house_teams.duplicate()
	BattleRequest.house_teams = {"ally":1, "ai2":1, "enemy":2}
	var preview = battle.build_range_preview
	var data := GameData.get_building("GAPOWR")
	var ally_yard = battle._place_building("NACNST", "ai2", Vector2(640,640), true)
	var point: Vector2 = Vector2.INF
	battle.armed_build = "GAPOWR"
	battle.struct_ready.GAPOWR = 1
	preview.update(battle)
	for cell in preview.cells:
		var pos: Vector2 = Vector2(cell)*battle.BUILD_GRID
		if pos.distance_to(ally_yard.position)<240 and battle.build_spot_ok(pos,data,true).ok:
			point = pos
			break
	check(point.is_finite(),mode+" player can place beside allied Soviet yard")
	if point.is_finite():
		ally_yard.under_construction = true
		preview.update(battle)
		check(not battle.build_spot_ok(point,data,true).ok and not preview.cells.has(Vector2i(point/battle.BUILD_GRID)),mode+" unfinished allied yard grants no territory")
		ally_yard.under_construction = false
		BattleRequest.house_teams.ai2 = 2
		preview.update(battle)
		check(not battle.build_spot_ok(point,data,true).ok and not preview.cells.has(Vector2i(point/battle.BUILD_GRID)),mode+" hostile yard removed from overlay and placement")
		BattleRequest.house_teams.ai2 = 1
		battle._try_place_building(point)
		check(battle.buildings.any(func(b):return b.building_id=="GAPOWR" and b.side=="ally" and b.position==point) and not battle.struct_ready.has("GAPOWR"),mode+" normal placement uses player's ready order and ownership")
	for id in ["GACNST","GAPOWR","CAOILD","GAWALL"]:
		var building
		if id == "CAOILD":
			building = preload("res://scripts/world/civilian_sites.gd").create(battle,id,Vector2(2640,600))
			AlliedAbilities.change_side(building,"ai2")
		else:
			building = battle._place_building(id,"ai2",Vector2(2640,600),true)
		check(preview.usable_source(building,"ally")==(id=="GACNST"),mode+" allied source eligibility "+id)
		battle.buildings.erase(building)
		building.free()
	BattleRequest.house_teams = original
