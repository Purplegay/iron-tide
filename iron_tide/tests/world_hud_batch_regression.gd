extends "res://tests/base_recovery_regression.gd"
const Bars = preload("res://scripts/ui/world_health_bars.gd")
const Rings = preload("res://scripts/ui/world_cooldown_rings.gd")
const Cooldowns = preload("res://scripts/ui/attack_cooldown_indicator.gd")

class Sample extends Node2D:
	var batched := false
	var bars: MultiMeshInstance2D
	var rings: MultiMeshInstance2D
	func _ready() -> void:
		if batched:
			bars = Bars.new()
			rings = Rings.new()
			add_child(bars)
			add_child(rings)
	func _draw() -> void:
		if batched:
			bars.begin()
			bars.transform = Transform2D.IDENTITY
			rings.begin(self)
			HpBar.world_batch = bars
		for row in 8:
			var fraction := float(row + 1) / 8.0
			var at := Vector2(18, 20 + row * 32)
			var color := Color(0.3, 0.8, 1) if row % 2 == 0 else Color(1, 0.3, 0.2)
			HpBar.draw_bar(self, Rect2(at, Vector2(116, 6)), fraction, color, 0,
				minf(1, fraction + 0.1), 0, 0, HpBar.rim_for("enemy" if row % 2 else "ally"))
			var info := Cooldowns.slot("test", 1.0 - fraction, 1.0, color)
			var center := at + Vector2(140, 3)
			if batched: rings.append(center, 6, info)
			else: Cooldowns.paint_ring(self, center, 6, info)
		if batched:
			HpBar.world_batch = null
			bars.finish()
			rings.finish()

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty(): get_tree().quit(2); return
	check(Cooldowns.mount_offset(5, 6) == Vector2(28, 14), "six independent weapon rings retain two rows")
	if DisplayServer.get_name() != "headless":
		var views: Array[SubViewport] = []
		for method in 2:
			var view := SubViewport.new()
			view.size = Vector2i(190, 285)
			view.transparent_bg = true
			view.world_2d = World2D.new()
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(view)
			var sample := Sample.new()
			sample.batched = method == 1
			view.add_child(sample)
			views.append(view)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var reference := views[0].get_texture().get_image()
		var actual := views[1].get_texture().get_image()
		reference.save_png(output_dir.path_join("reference.png"))
		actual.save_png(output_dir.path_join("batched.png"))
		var error := 0.0
		var pixels := 0
		for y in reference.get_height():
			for x in reference.get_width():
				var a := reference.get_pixel(x,y)
				var b := actual.get_pixel(x,y)
				if a.a < 0.02 and b.a < 0.02: continue
				error += (absf(a.r*a.a-b.r*b.a)+absf(a.g*a.a-b.g*b.a)+absf(a.b*a.a-b.b*b.a)+absf(a.a-b.a))/4
				pixels += 1
		check(error / maxf(1,pixels) < 0.01, "bar/ring coverage and colors match immediate-mode reference", error / maxf(1,pixels))
		var sample = views[1].get_child(0)
		check(sample.bars.used == 8 and sample.rings.used == 8, "all bars and all cooldown rings submitted")
		check(sample.rings.multimesh.get_instance_custom_data(7).b == 1.0, "ready ring remains ready")
		check(is_equal_approx(sample.rings.multimesh.get_instance_custom_data(3).g, 0.5), "half reload retains exact progress")
		sample.bars.begin()
		sample.bars.finish()
		sample.rings.begin(sample)
		sample.rings.finish()
		check(sample.bars.multimesh.visible_instance_count == 0 and sample.rings.multimesh.visible_instance_count == 0, "empty frame clears previous instances")
		for view in views: view.free()
	check(HpBar.world_batch == null and Cooldowns.world_batch == null, "batch context cannot leak to menu or next battle")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)
