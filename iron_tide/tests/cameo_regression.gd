extends "res://tests/hud_identity_regression.gd"

const RESTORED := {
	"JUMPJET": "JJETICON", "CARRIER": "CARRICON", "DEST": "desticon",
	"AEGIS": "AGISICON", "LCRF": "LANDICON", "SHAD": "SHADICON",
	"DLPH": "DLPHICON", "ORCA": "FALCICON", "BEAG": "BEAGICON",
	"GAYARD": "ayaricon", "GACSPH": "csphicon", "GAWEAT": "wethicon"
}

func expect_icon(root: Node, id: String, expected: String, label: String) -> void:
	var icon = find_icon(root, id) if root != null else null
	check(icon != null and icon.cameo_texture != null and icon.cameo_texture.resource_path == expected,
		label + ": " + id, expected)

func exercise_additional_input(mode: String, soldier, peer, tank) -> void:
	await super.exercise_additional_input(mode, soldier, peer, tank)
	var hud = screen.hud
	for building in battle.buildings:
		building.cancel_queue()
	for bid in ["GAYARD", "GAAIRC", "GATECH", "GAWEAP"]:
		var facility = battle._place_building(bid, "ally", Vector2(2500, 2500), true)
		facility.process_mode = Node.PROCESS_MODE_DISABLED
		facility._buildup_play = -1.0
	for id in RESTORED:
		# Korea replaces the Harrier with the Black Eagle.
		battle._countries.ally = "Alliance" if id == "BEAG" else "Americans"
		var expected: String = "res://assets/ra2/cameo/%s.png" % RESTORED[id]
		check(GameData.ra2_cameo_path(id) == expected and ResourceLoader.exists(expected),
			mode + ": restored source mapping " + id)
		var data := GameData.get_entity(id)
		var unit_data := GameData.get_unit(id)
		var actor
		var producer
		if not unit_data.is_empty():
			actor = battle.spawn_unit(id, "ally", Vector2(1600, 1600))
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			battle.select_unit(actor, false)
			battle._emit_selection()
			hud.select_prod_tab(hud._unit_cat(data))
			producer = hud._producer_for(id)
			if producer != null: hud._factories.choose(producer)
			check(producer != null and producer.enqueue(id), mode + ": restored unit enters actual producer " + id)
		else:
			actor = battle._place_building(id, "ally", Vector2(2100, 2100), true)
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			battle.select_building(actor)
			battle._emit_selection()
			hud.select_prod_tab("building")
			if not hud._prod_buttons.has(id):
				hud.select_prod_tab("defense")
		hud._refresh_production()
		await settle_icons()
		expect_icon(hud._prod_buttons.get(id), id, expected, mode + ": production card")
		expect_icon(hud.sel_strip_box, id, expected, mode + ": selection strip")
		if not unit_data.is_empty():
			check(find_icon(hud.sel_box, id) == null, mode + ": details avoid duplicating the roster portrait " + id)
			expect_icon(hud._queue_host, id, expected, mode + ": production queue")
			if producer != null:
				producer.cancel_queue()
		battle.clear_selection()
		battle.units.erase(actor)
		battle.buildings.erase(actor)
		actor.free()
	# Original data has no cameo for these two entries; do not mislabel borrowed artwork.
	for id in ["CDEST", "GACNST"]:
		check(GameData.ra2_cameo_path(id).is_empty(), mode + ": unmapped identity retains fallback " + id)
	await gallery(mode)

func gallery(mode: String) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 140)
	panel.size = Vector2(760, 400)
	screen.overlay_layer.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for id in RESTORED:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(168, 110)
		grid.add_child(box)
		var icon := UnitIcon.new()
		icon.setup(GameData.get_entity(id), Color.CORNFLOWER_BLUE)
		icon.show_status = false
		icon.custom_minimum_size = Vector2(100, 80)
		box.add_child(icon)
		var label := Label.new()
		label.text = "%s · %s" % [id, GameData.get_entity(id).get("name", "")]
		label.add_theme_font_size_override("font_size", 12)
		box.add_child(label)
	await settle_icons()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode + "-restored-cameos.png"))
	panel.queue_free()
