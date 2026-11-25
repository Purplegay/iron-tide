extends Node

func _ready() -> void:
	call_deferred("verify")

func fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)

func verify() -> void:
	var school = preload("res://scenes/yuriko_school.tscn").instantiate()
	add_child(school)
	school.hub(2)
	for btn in school.find_children("*", "Button", true, false):
		if btn.text == "观看技能与等级演示":
			btn.pressed.emit()
			break
	var demo = school.get_child(-1)
	if not demo is PopupPanel:
		fail("missing demo")
		return
	demo.ability.select(1)
	demo.ability.item_selected.emit(1)
	for rank in 3:
		demo.level.select(rank)
		demo.level.item_selected.emit(rank)
		demo._process(1.6)
		if demo.preview.get_child_count() != 3 + 2 * rank:
			fail("incorrect guard count")
			return
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 80)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var marker = demo.preview.get_child(0)
	marker.reparent(vp, false)
	marker.position = Vector2(90, 45)
	marker.preview_head = Vector2(10, 35)
	var pixels := PackedByteArray()
	for frame in 90:
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		if image.get_used_rect().size.x < 60:
			fail("missing visible marker or link")
			return
		if frame > 0 and pixels != image.get_data():
			fail("stationary marker pixels changed")
			return
		pixels = image.get_data()
	print("PASS school demo 3/5/7 guards; 90 identical visible frames")
	get_tree().quit()
