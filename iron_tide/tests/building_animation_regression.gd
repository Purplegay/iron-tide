extends "res://tests/selection_regression.gd"

const TARGETS := {
	"GAWEAP": ["GAWEAP_A", "GAWEAP_B"],
	"GAPOWR": ["GAPOWR_A"],
	"ATESLA": ["GAPRIS_A", "GAPRIS_B"],
	"GAREFN": ["GAREFNOR"],
	"GAAIRC": ["GAAIRC_A", "GAAIRC_B", "GAAIRC_C"],
	"GADEPT": ["GADEPT_A", "GADEPT_B", "GADEPT_C", "GADEPT_D"],
	"GATECH": ["GATECH_A"],
	"GAYARD": ["GAYARD_C", "GAYARD_D"],
	"GACSPH": ["GACSPH_E", "GACSPH_F", "GACSPH_G", "GACSPH_H"],
	"GAWEAT": ["GAWETH_E", "GAWETH_F", "GAWETH_G", "GAWETH_H"],
	"GASPYSAT": ["GASPST_A"]
}

func snapshot() -> Image:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode, {"map_size": 3200, "starting_funds": 10000})
	screen = load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	battle = screen.battle
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle.camera.position = Vector2(1600, 1600)
	battle.camera.zoom = Vector2(1, 0.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	await check_buildup_warmup(mode)
	await check_soviet_make_frames(mode)
	# This pixel-exact flash comparison needs identical scenery between captures.
	# The coastal water shader animates even when the scene is process-disabled.
	if battle._water_layer != null: battle._water_layer.hide()
	await check_construction_flash(mode)
	if battle._water_layer != null: battle._water_layer.show()
	await check_health_segments(mode)
	await check_factory_damage(mode)
	for id in TARGETS:
		var prefix := mode + " " + str(id) + ": "
		var b = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b._buildup_play = -1.0
		var layers: Array = b._ra2_anim.duplicate(true)
		check(b._ra2.get("tex") != null, prefix + "real body imports")
		check(b.footprint_poly() == Building.placement_poly(b.data), prefix + "visual body shares placement and physics geometry")
		for image_id in TARGETS[id]:
			var art := RA2Art.art(str(image_id))
			var texture: Texture2D = art.get("tex")
			check(texture != null and texture.get_image() != null, prefix + "layer imports " + str(image_id))
			check(RA2Art.frame_size(art) == RA2Art.frame_size(b._ra2), prefix + "layer canvas matches body " + str(image_id))
			for lay in layers:
				if str(lay.image) != image_id:
					continue
				for health in [1.0, 0.3]:
					b.hp = b.max_hp * health
					var st: Dictionary = b._anim_layer(lay)
					check(int(st.loopStart) >= 0 and int(st.loopEnd) < int(art.get("count", 0)),
						prefix + "healthy/damaged frame interval valid " + str(image_id) + " " + str(health))
		var states: Array[String] = ["normal"]
		if b._anim_kinds().has("specialanim"):
			states.append("special")
		for state in states:
			for health in [1.0, 0.3]:
				b.hp = b.max_hp * health
				b._anim_t = 1.2
				b._set_anim_state(b._base_anim_state(b._anim_kinds()))
				if state == "special":
					b.play_special()
				b._anim_group_t = 3.2
				b.queue_redraw()
				var with_layers := await snapshot()
				if with_layers != null:
					var filename := "%s-%s-%s-%d" % [mode, id, state, int(health * 100)]
					with_layers.save_png(output_dir.path_join(filename + ".png"))
					b._ra2_anim = []
					b.queue_redraw()
					var without_layers := await snapshot()
					b._ra2_anim = layers
					b.queue_redraw()
					var changed := 0
					# 受损建筑可能只剩几颗灯，逐像素计数，避免隔点采样漏掉细节。
					for x in range(400, 1200):
						for y in range(110, 650):
							if with_layers.get_pixel(x, y) != without_layers.get_pixel(x, y):
								changed += 1
					check(changed > 10, prefix + "real layers render " + state + " " + str(health), changed)
		if id == "GAYARD":
			await check_ship_production(b, prefix)
		if id == "GACSPH":
			await check_chronosphere_alignment(b, mode)
		if id == "GADEPT":
			await check_repair_arm(b, mode)
		if id == "GAWEAP":
			await check_factory_flag(b, mode)
		battle.buildings.erase(b)
		b.free()
		await get_tree().process_frame
	screen.free()
	await get_tree().process_frame

func check_factory_damage(mode: String) -> void:
	for id in ["GAWEAP", "NAWEAP", "NAREFN"]:
		var b = battle._place_building(id, "ally", Vector2(1600, 1600), true)
		b._buildup_play = -1.0
		b.process_mode = Node.PROCESS_MODE_DISABLED
		for health in [1.0, 0.51, 0.5, 0.25, 0.01, 0.51]:
			b.hp = b.max_hp * health
			var damaged: bool = health <= 0.5
			check(b._body_damage_frame() == int(damaged), "%s %s body at %.0f%%" % [mode, id, health * 100])
			for layer in b._ra2_anim:
				if not layer.has("dmg"): continue
				var expected: Dictionary = layer.dmg if damaged else layer
				var state: Dictionary = b._anim_layer(layer)
				check(state.image == expected.image and state.loopStart == expected.loopStart, "%s %s overlay %s matches body at %.0f%%" % [mode, id, layer.kind, health * 100])
				if id == "NAREFN":
					var visited := {}
					for step in 12:
						b._anim_t = (float(step) + 0.5) * 60.0 / float(state.rate)
						visited[b._anim_frame_for(layer, state)] = true
					var frames := visited.keys()
					frames.sort()
					check(frames == (range(3, 6) if damaged else range(3)), mode + " refinery lights stay on visible health frames")
			if id == "GAWEAP" and health == 0.01:
				b.queue_redraw()
				var picture := await snapshot()
				if picture != null: picture.save_png(output_dir.path_join(mode + "-damaged-war-factory.png"))
		battle.buildings.erase(b)
		b.free()

func check_factory_flag(b, mode: String) -> void:
	# Original GAWEAP_A SHP: 15 upright, 15 damaged, then 30 shadows.
	var layer: Dictionary = b._ra2_anim.filter(func(item): return item.image == "GAWEAP_A")[0]
	var original_zoom: Vector2 = battle.camera.zoom
	var original_position: Vector2 = battle.camera.position
	battle.camera.position = b.position + RA2Art.art_dir(Vector2(0, -100))
	battle.camera.zoom = Vector2(3, 1.5)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	for health in [1.0, 0.3]:
		b.hp = b.max_hp * health
		var state: Dictionary = b._anim_layer(layer)
		var frames: Array = []
		for step in 60:
			b._anim_t = step * 0.3 + 0.01
			var frame: int = b._anim_frame_for(layer, state)
			if not frames.has(frame): frames.append(frame)
		frames.sort()
		var expected := range(15) if health == 1.0 else range(15, 30)
		check(frames == expected, mode + " factory flag stays within original health segment " + str(health), frames)
		# This exact time previously displayed damaged frame 15 on a full-health factory.
		b._anim_t = 4.51
		b.queue_redraw()
		var picture := await snapshot()
		if picture != null: picture.save_png(output_dir.path_join("%s-factory-flag-%d.png" % [mode, int(health * 100)]))
	battle.camera.position = original_position
	battle.camera.zoom = original_zoom
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()

func check_repair_arm(b, mode: String) -> void:
	var original_zoom: Vector2 = battle.camera.zoom
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.force_update_scroll()
	var visibility: Dictionary = {}
	for unit in battle.units:
		visibility[unit] = unit.visible
		unit.visible = false
	for health in [1.0, 0.3]:
		b.hp = b.max_hp * health
		b._repair_active = false
		b._set_anim_state("idle")
		for phase in ["idle", "extend", "work", "retract", "finished"]:
			var expected := "idleanim"
			match phase:
				"extend":
					b._repair_active = true
					b._tick_anim_state(0.01)
					expected = "specialanim"
				"work":
					b._tick_anim_state(3.1)
					expected = "specialanimtwo"
				"retract":
					b._repair_active = false
					b._tick_anim_state(0.01)
					expected = "specialanimthree"
				"finished": b._tick_anim_state(3.1)
			var visible: Array = b._ra2_anim.filter(func(layer): return b._layer_visible(layer.kind))
			check(visible.size() == 1 and visible[0].kind == expected, "%s repair arm displays only %s health=%s" % [mode, phase, health], visible.map(func(layer): return layer.kind))
			b.queue_redraw()
			var picture := await snapshot()
			if picture != null and phase != "finished": picture.save_png(output_dir.path_join("%s-repair-arm-%s-%d.png" % [mode, phase, int(health * 100)]))
			if phase == "work":
				var layer: Dictionary = b._ra2_anim.filter(func(item): return item.kind == "specialanimtwo")[0]
				var state: Dictionary = b._anim_layer(layer)
				b._anim_group_t = 0.3
				var first: int = b._anim_frame_for(layer, state)
				b.play_special() # Repeated healing must not restart the arm extension.
				b._tick_anim_state(0.9)
				check(b._layer_visible("specialanimtwo") and b._anim_frame_for(layer, state) != first, mode + " repair working loop advances without restarting extension")
		for layer in b._ra2_anim:
			if layer.kind in ["specialanim", "specialanimthree"]:
				var state: Dictionary = b._anim_layer(layer)
				check(state.loopEnd - state.loopStart + 1 == 10, mode + " healthy and damaged extension/retraction each retain ten original frames", state)
	b.hp = b.max_hp
	for unit in visibility: unit.visible = visibility[unit]
	battle.camera.zoom = original_zoom
	battle.camera.force_update_scroll()

func check_chronosphere_alignment(b, mode: String) -> void:
	# Original GACSPH_E contains the front dome/base, absent from GACSPH.SHP.
	# These source-canvas points are in that front half, not in the rear supports.
	var original_zoom: Vector2 = battle.camera.zoom
	battle.camera.zoom = Vector2(2, 1)
	battle.camera.force_update_scroll()
	var visibility: Dictionary = {}
	for unit in battle.units:
		visibility[unit] = unit.visible
		unit.visible = false
	check(b._ra2.get("baked_layers", []).has("GACSPH_E") and not b._ra2_anim.any(func(layer): return layer.image == "GACSPH_E"), mode + " permanent dome is composed once including its shadow")
	check(b._ra2_anim.size() == 3, mode + " all three charge effect layers remain independent")
	for health in [1.0, 0.3]:
		b.hp = b.max_hp * health
		b.selected = true
		b.queue_redraw()
		var picture := await snapshot()
		if picture != null:
			picture.save_png(output_dir.path_join("%s-chronosphere-alignment-%d.png" % [mode, int(health * 100)]))
		var frame: int = b._body_damage_frame()
		var anchor := RA2Art.anchor(b._ra2, [frame])
		var base := Vector2(-anchor.x, b.radius * 0.35 - anchor.y)
		var dome := base + Vector2(160, 155)
		var pad := base + Vector2(150, 172)
		check(b.hit_test(b.position + RA2Art.art_dir(dome)), mode + " chronosphere front dome is clickable health=" + str(health))
		check(Geometry2D.is_point_in_polygon(pad, b._sel_poly), mode + " selection includes front foundation health=" + str(health))
		check(Geometry2D.is_point_in_polygon(Building.art_to_ground(pad), b.footprint_poly()), mode + " placement and physical footprint include front foundation health=" + str(health))
	b.selected = false
	b.hp = b.max_hp
	for unit in visibility: unit.visible = visibility[unit]
	battle.camera.zoom = original_zoom
	battle.camera.force_update_scroll()

func check_health_segments(mode: String) -> void:
	# Independent expected SHP segments from the locally inspected original artwork.
	var expected := {"GAPOWR": {"activeanim": [[0, 7], [8, 15]]},
		"ATESLA": {"specialanim": [[0, 9], [10, 19]], "activeanim": [[0, 8], [9, 17]]}}
	for id in expected:
		for side in ["ally", "enemy"]:
			var b = battle._place_building(id, side, Vector2(1600, 1600), true)
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b._buildup_play = -1.0
			for fraction in [1.0, 0.7, 0.3]:
				b.hp = b.max_hp * fraction
				for layer in b._ra2_anim:
					var prefix := "%s %s %s %s health=%s: " % [mode, id, side, layer.kind, fraction]
					var bounds: Array = expected[id][layer.kind][0 if fraction > 0.66 else 1]
					var state: Dictionary = b._anim_layer(layer)
					check(state.loopStart == bounds[0] and state.loopEnd == bounds[1], prefix + "source health interval", state)
					var valid := true
					var visited := {}
					for step in 3600:
						b._anim_t = float(step) / 30.0
						b._anim_group_t = float(step) / 30.0
						var frame: int = b._anim_frame_for(layer, state)
						valid = valid and frame >= bounds[0] and frame <= bounds[1] and frame < state.frames
						visited[frame] = true
					check(valid and visited.size() == bounds[1] - bounds[0] + 1, prefix + "two minutes never cross health or shadow segment", visited.keys())
			# A real attack triggers the tower's healthy special animation.
			if id == "ATESLA":
				b.hp = b.max_hp
				var target = battle.spawn_unit("MTNK", "enemy" if side == "ally" else "ally", b.position + Vector2(100, 0))
				target.process_mode = Node.PROCESS_MODE_DISABLED
				b.attack_target = target
				battle.power_low = false
				battle.enemy_power.low = false
				check(b._fire(), mode + side + " real prism weapon fires")
				check(b._anim_state == "special" and b._special_until > 0.0, mode + side + " actual prism attack starts charge visual")
				b._anim_group_t = 3.2
				for layer in b._ra2_anim:
					if layer.kind == "specialanim":
						check(b._anim_frame_for(layer, b._anim_layer(layer)) <= 9, mode + side + " late healthy charge cannot show damaged head")
				battle.units.erase(target)
				target.free()
			battle.buildings.erase(b)
			b.free()
	await get_tree().process_frame

func check_soviet_make_frames(mode: String) -> void:
	var native_counts := {"NAPOWR":26, "NANRCT":25, "NAINDP":26, "NAIRON":25, "NAMISL":26}
	for id in native_counts:
		var b = battle._place_building(id, "ally", battle.camera.position, true)
		var art: Dictionary = b._buildup_art
		var count: int = native_counts[id]
		check(art.count == count and art.rects.size() == count and art.detail.frames.size() == count,
			mode + " native and 2x construction body frames " + id)
		b._buildup_play = GameData.ra2_buildup_seconds() * 0.99
		b.queue_redraw()
		var rendered := await snapshot()
		if rendered != null:
			check(b._art_frame == count - 1 and b._art_source.key == art.key, mode + " final make frame " + id)
			if id == "NANRCT":
				var center: Vector2i = Vector2i(b.get_global_transform_with_canvas().origin)
				rendered.get_region(Rect2i(center - Vector2i(165,180), Vector2i(330,235))).save_png(output_dir.path_join(mode + "-reactor-built.png"))
		b._buildup_play = -1.0
		var sale = preload("res://scripts/buildings/building_sale_fx.gd").play(b)
		check(is_instance_valid(sale) and sale.start_frame == count - 1, mode + " sale starts from completed body " + id)
		if is_instance_valid(sale): sale.free()
		battle.buildings.erase(b)
		b.free()

func check_construction_flash(mode: String) -> void:
	for color_id in ["allied", "purple"]:
		HouseColor.set_player_id(color_id)
		var prefix: String = mode + " " + color_id + " completion: "
		var fixture = battle._place_building("GAPOWR", "ally", Vector2(2100, 1600), true)
		fixture._process(GameData.ra2_buildup_seconds())
		check(fixture._completion_flash_left == 0.0, prefix + "prebuilt map fixtures do not flash")
		var b = battle._place_building("GAPOWR", "ally", Vector2(1600, 1600), true, true)
		check(b._completion_flash_left == 0.0 and b._completion_flash_pending,
			prefix + "placed building waits for unfolding")
		var hp: float = b.hp
		var funds: float = battle.funds
		var house_material = b.material
		b._process(GameData.ra2_buildup_seconds())
		check(b._completion_flash_left > 0.0 and b._buildup_play < 0.0,
			prefix + "real buildup completion starts flash")
		var normal := await snapshot()
		b._tick_completion_flash(0.18)
		var bright := await snapshot()
		check(b.self_modulate.r > 1.5 and b.self_modulate.a == 1.0 and b.material == house_material,
			prefix + "brightness preserves opacity and house material")
		b._tick_completion_flash(0.18)
		check(is_equal_approx(b.self_modulate.r, 1.0), prefix + "first pulse returns to normal")
		b._tick_completion_flash(0.18)
		check(b.self_modulate.r > 1.5, prefix + "second pulse appears")
		b._tick_completion_flash(0.2)
		var restored := await snapshot()
		check(b.self_modulate == Color.WHITE and b._completion_flash_left == 0.0,
			prefix + "flash ends automatically")
		if normal != null:
			normal.save_png(output_dir.path_join(mode + "-" + color_id + "-completion-normal.png"))
			bright.save_png(output_dir.path_join(mode + "-" + color_id + "-completion-bright.png"))
			var changed := 0
			var mismatch := 0
			for x in range(450, 1100):
				for y in range(130, 580):
					if normal.get_pixel(x, y) != bright.get_pixel(x, y): changed += 1
					if normal.get_pixel(x, y) != restored.get_pixel(x, y): mismatch += 1
			check(changed > 100, prefix + "actual rendered building visibly flashes", changed)
			check(mismatch == 0, prefix + "rendered colors restore exactly", mismatch)
		b._process(0.1)
		check(b._completion_flash_left == 0.0 and b.hp == hp and battle.funds == funds,
			prefix + "completion does not retrigger or change health and payment")
		for actor in [fixture, b]:
			battle.buildings.erase(actor)
			actor.free()
	HouseColor.set_player_id("allied")
	var onsite = battle._place_building("GAPOWR", "ally", Vector2(1600, 1600), false, true)
	check(onsite.under_construction and onsite._completion_flash_left == 0.0, mode + " onsite construction waits")
	onsite.build_elapsed = onsite.build_total
	onsite._process(0.0)
	check(not onsite.under_construction and onsite._completion_flash_left > 0.0, mode + " onsite completion flashes")
	# The effect only changes local tint, never visibility controlled by fog.
	onsite.visible = false
	onsite._tick_completion_flash(0.18)
	check(not onsite.visible, mode + " hidden building remains hidden while flashing")
	onsite._dead = true
	onsite._tick_completion_flash(0.01)
	check(onsite.self_modulate == Color.WHITE, mode + " destruction clears highlight")
	battle.buildings.erase(onsite)
	onsite.free()

func check_ship_production(b, prefix: String) -> void:
	b.hp = b.max_hp
	b._anim_t = 123.0
	b._tick_anim_state(0.0)
	check(not b._layer_visible("productionanim"), prefix + "completion animation is hidden while idle")
	var path = battle.path_service
	var water: Array = path.water_rects.duplicate()
	var cost: PackedFloat32Array = path.water_cost.duplicate()
	path.water_rects.assign([Rect2(Vector2.ZERO, Vector2(battle.map_size, battle.map_size))])
	path.water_cost.fill(1.0)
	var lay: Dictionary = {}
	for candidate in b._ra2_anim:
		if candidate.kind == "productionanim":
			lay = candidate
	battle.funds = 10000
	battle.power_low = false
	var count: int = battle.units.size()
	# Advance wall-clock seconds using the same production rate as the live queue.
	var duration: float = GameData.ra2_build_time(GameData.get_unit("DEST")) / b.build_speed / b.production_work_rate("DEST")
	b.enqueue("DEST")
	b._process(duration * 0.5)
	check(not b._layer_visible("productionanim"), prefix + "queue does not prematurely show completion animation")
	b._process(duration)
	check(battle.units.size() == count + 1 and b.production.is_empty(), prefix + "actual naval production completes once")
	var st: Dictionary = b._anim_layer(lay)
	check(not b._layer_visible("idleanim") and b._layer_visible("activeanimthree"), prefix + "delivery replaces idle crane while lights remain visible")
	check(b._layer_visible("productionanim") and b._anim_frame_for(lay, st) == int(st.loopStart),
		prefix + "completion animation starts at its first frame")
	b.queue_redraw()
	var image := await snapshot()
	if image != null:
		image.save_png(output_dir.path_join(BattleRequest.rules_mode + "-ship-complete.png"))
	b._process(0.6)
	check(b._anim_frame_for(lay, st) > int(st.loopStart) and battle.units.size() == count + 1,
		prefix + "completion frames advance without spawning again")
	b.queue_redraw()
	image = await snapshot()
	if image != null:
		image.save_png(output_dir.path_join(BattleRequest.rules_mode + "-ship-complete-later.png"))
	var seconds := float(int(st.loopEnd) - int(st.loopStart) + 1) * 60.0 / maxf(1.0, float(st.rate))
	b._process(seconds + 0.1)
	check(not b._layer_visible("productionanim") and b._layer_visible("idleanim") and battle.units.size() == count + 1,
		prefix + "one-shot completion animation ends without another ship")
	b.enqueue("DEST")
	b._process(duration)
	check(b._layer_visible("productionanim") and b._anim_frame_for(lay, st) == int(st.loopStart),
		prefix + "next ship restarts its completion animation")
	path.water_rects.assign(water)
	path.water_cost = cost

func check_buildup_warmup(mode: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var warmup = battle.building_art_warmup
	var refinery = battle.buildings.filter(func(b): return b.building_id == "GAREFN")[0]
	var start: float = refinery._buildup_play
	# Let only the loader run. A draw after completion must not warm the test itself.
	warmup.process_mode = Node.PROCESS_MODE_ALWAYS
	for tick in 240:
		if warmup.jobs.is_empty(): break
		await get_tree().process_frame
	check(warmup.jobs.is_empty() and refinery._buildup_play == start and start >= 0.0,
		mode + ": regular textures prepared during buildup without advancing it")
	for id in ["GACNST","GAPOWR","GAPILE","GAREFN","GACNST_A","GAPOWR_A","GAPILE_A","GAREFNL1","GAREFNL2","GAREFNL3"]:
		var art: Dictionary = RA2Art._cache.get(id, {})
		var pages: Array = art.get("detail", {}).get("pages", [])
		check(not pages.is_empty() and RA2Art.ShpDetail._textures.has(RA2Art.ShpDetail.ROOT + str(pages[0].file)),
			mode + ": first regular detail page is resident for " + id)
