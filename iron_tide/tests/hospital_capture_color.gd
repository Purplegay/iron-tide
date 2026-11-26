extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	print("HOSPITAL ", ok, " ", label)
	if not ok: failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_user_data_dir().contains("IT-Hospital-Color"):
		push_error("医院回归需要隔离用户目录：" + OS.get_user_data_dir())
		get_tree().quit(2)
		return
	HouseColor.set_player_id("red")
	BattleRequest.configure_skirmish(MatchRules.RA2, {"map_layout":"yr_hidvally", "country":"苏俄", "fog_of_war":false})
	var screen := load("res://scenes/battle.tscn").instantiate() as Node
	add_child(screen)
	var world = screen.battle
	var sites: Array = world.buildings.filter(func(b): return b.building_id == "CATHOSP")
	check(sites.size() == 2, "隐秘山谷载入两座科技医院")
	if sites.is_empty():
		get_tree().quit(failures)
		return
	var hospital: Building = sites[0]
	var art: Texture2D = hospital._ra2.tex
	check(hospital.side == "neutral" and art.resource_path.ends_with("/shp/CATHOSP.png"), "中立医院实际使用通用贴图")
	check(hospital.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.HOSPITAL_BLUE_NEUTRAL, "中立医院使用专用房色模式")
	var source := art.get_image()
	var frame := Rect2i(0, 0, int(hospital._ra2.cell[0]), int(hospital._ra2.cell[1]))
	var preview := SubViewport.new()
	preview.size = frame.size
	preview.transparent_bg = true
	add_child(preview)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = art
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(sprite)
	await verify_pixels(preview, sprite, source, hospital.material, Color.GRAY, "中立灰")
	if not is_instance_valid(hospital) or hospital.side != "neutral":
		check(false, "医院在测试占领前仍应中立")
		get_tree().quit(failures)
		return
	var engineer = world.spawn_unit("SENGINEER", "ally", hospital.position + Vector2(160, 120))
	check(engineer.order_interaction("allied_engineer", hospital, false), "苏军工程师接受正式占领命令")
	engineer.position = AlliedAbilities.approach(engineer, hospital)
	AlliedAbilities.tick_action(engineer, 1.0)
	check(hospital.side == "ally" and not world.actor_alive(engineer), "进门后医院换边并消耗工程师")
	var red := Color(HouseColor.hex_of("red"))
	check(hospital.material.get_shader_parameter("paint_mode") == HouseColor.PaintMode.HOSPITAL_BLUE_FACADE and hospital.material.get_shader_parameter("target_color").is_equal_approx(red), "占领同一步应用苏军阵营色")
	await verify_pixels(preview, sprite, source, hospital.material, red, "苏军红")
	get_tree().quit(int(failures > 0))

func verify_pixels(preview: SubViewport, sprite: Sprite2D, source: Image, material: ShaderMaterial, color: Color, label: String) -> void:
	sprite.material = material
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var rendered := preview.get_texture().get_image()
	var base := Color(HouseColor.BASE_HEX)
	var base_rgb := Vector3(base.r, base.g, base.b)
	var ramp := 0
	var wrong := 0
	var signs := 0
	var wrong_signs := 0
	for y in preview.size.y:
		for x in preview.size.x:
			var p := source.get_pixel(x, y)
			if p.a8 != 255: continue
			var rgb := Vector3(p.r, p.g, p.b)
			var out := rendered.get_pixel(x, y)
			if rgb.length() > 0.10 and rgb.normalized().dot(base_rgb.normalized()) >= 0.995:
				var expected := color * (rgb.dot(base_rgb) / base_rgb.length_squared())
				ramp += 1
				if pixel_delta(out, expected) > 4: wrong += 1
			elif p.r > p.g * 1.7 and p.r > p.b * 1.7 and p.r8 > 0:
				signs += 1
				if pixel_delta(out, p) > 4: wrong_signs += 1
	check(ramp > 100 and wrong == 0, "%s：%d 房色像素，%d 超差" % [label, ramp, wrong])
	check(signs > 0 and wrong_signs == 0, "%s：%d 原有红色细节，%d 超差" % [label, signs, wrong_signs])
	var path := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if not path.is_empty():
		rendered.get_region(Rect2i(135, 80, 260, 208)).save_png(path.path_join("neutral.png" if color == Color.GRAY else "captured.png"))

func pixel_delta(a: Color, b: Color) -> int:
	return absi(a.r8 - b.r8) + absi(a.g8 - b.g8) + absi(a.b8 - b.b8)
