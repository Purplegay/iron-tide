extends "res://tests/bridge_sections_regression.gd"
const Art = preload("res://scripts/world/native_bridge_art.gd")
const CivilianSites = preload("res://scripts/world/civilian_sites.gd")

func exercise(mode: String) -> void:
	for layout in ["yr_isleland", "yr_crctbrd"]:
		BattleRequest.configure_skirmish(mode, {"map_layout": layout, "opening": "mcv", "fog_of_war": false})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		var ground: Ground
		for child in battle.get_children():
			if child is Ground: ground = child
		var original: Texture2D = ground._surface.texture
		check(ground.bridge_art.patches.is_empty(), layout + " intact bridge uses baked terrain")
		var initial_visual = battle.get_node_or_null("CivilianSiteVisual")
		check(initial_visual == null or not initial_visual.visible, layout + " no procedural deck over native terrain")
		for horizontal in [true, false]:
			prefix = mode + "/" + layout + "/horizontal=" + str(horizontal) + ": "
			check(choose_section(horizontal), prefix + " has test bridge")
			Bridges.damage_section(battle, section, Bridges.strength())
			check(ground.broken_bridges == [section], prefix + " only one section destroyed")
			check(ground.bridge_art.patches.size() == 1, prefix + " native damaged bridge patch exists")
			var broken_cells := {}
			var row := Native.data(layout)
			for cell in row.bridge_section_by_cell:
				if row.bridge_section_by_cell[cell] == section: broken_cells[cell] = true
			var edges := []
			for tile: Array in row.bridges:
				var key: String = ground.bridge_art.overlay_key(tile, broken_cells)
				if broken_cells.has(Vector2i(tile[0], tile[1])):
					check(key.is_empty(), prefix + " destroyed deck omitted")
				if key.begins_with("LOBRDG17:") or key.begins_with("LOBRDG18:") or key.begins_with("LOBRDG08:") or key.begins_with("LOBRDG09:"): edges.append(key)
			check(edges.size() == 2 and edges[0] != edges[1], prefix + " opposite native broken edges selected", edges)
			var patch: Dictionary = ground.bridge_art.patches[0]
			var image: Image = patch.texture.get_image()
			var scale := 24.0 / Native.CELL
			var region := Rect2i(patch.rect.position * scale, patch.rect.size * scale)
			check(image.get_data() != ground.bridge_art.ground.get_region(region).get_data(), prefix + " actual patch contains bridge pixels over terrain")
			if mode == MatchRules.RA2 and layout == "yr_isleland":
				image.save_png(output_dir.path_join("composed_bridge_" + str(horizontal) + ".png"))
			var draw_count := [0]
			ground.draw.connect(func(): draw_count[0] += 1, CONNECT_ONE_SHOT)
			ground.queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			check(draw_count[0] > 0, prefix + " real terrain draw executes")
			var codec = BattleSaves.Snapshot.new()
			var saved: Dictionary = codec.capture(battle)
			check(codec.error.is_empty(), prefix + " broken bridge save supported", codec.error)
			codec.restore(battle, bytes_to_var(var_to_bytes(saved)))
			check(ground.bridge_art.patches.size() == 1 and ground.broken_bridges == [section], prefix + " load recreates native damage visual")
			var hut
			for building in battle.buildings:
				if building.special.get("bridge_span") == span: hut = building; break
			check(hut != null, prefix + " repair hut found")
			CivilianSites.repair(hut)
			check(ground.bridge_art.patches.is_empty() and ground.broken_bridges.is_empty() and ground._surface.texture == original, prefix + " repair restores exact original terrain resource")
			check(not battle.get_node("CivilianSiteVisual").visible and battle.path_service.bridge_at(section.get_center()).has_area(), prefix + " repaired native deck remains unobscured and passable")
			Bridges.damage_section(battle, section, Bridges.strength())
			Bridges.damage_section(battle, adjacent[1], Bridges.strength())
			check(ground.broken_bridges.size() == 2 and ground.bridge_art.patches.size() == 1, prefix + " adjacent breaks share one composition")
			CivilianSites.repair(hut)
			check(ground.bridge_art.patches.is_empty(), prefix + " repeated repair removes all visual patches")
		for pair in [["LOBRDG19", true, false, "LOBRDG20"], ["LOBRDG21", false, true, "LOBRDG22"], ["LOBRDG23", true, false, "LOBRDG24"], ["LOBRDG25", false, true, "LOBRDG26"]]:
			check(Art.damaged_name(pair[0], pair[1], pair[2]) == pair[3], layout + " native damaged head " + pair[3])
		await finish()
