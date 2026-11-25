extends Node

func _ready() -> void:
	var baked = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/building_frame_bounds.json"))
	var failed := 0
	var frames := 0
	for id in baked:
		var art := RA2Art.art(id)
		var image := RA2Art.sprite_image(art)
		for i in baked[id].size():
			var rect := Rect2i(RA2Art.src_rect(art, i))
			var actual := image.get_region(rect).get_used_rect()
			if art.body_frame_bounds[rect] != Rect2(actual):
				if failed < 4: print("FAIL bounds ", id, " frame ", i)
				failed += 1
			frames += 1
	var img := Image.create_empty(16, 6, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 5, Color(1, 1, 1, 15.0 / 255))
	img.set_pixel(2, 1, Color(1, 1, 1, 16.0 / 255))
	img.set_pixel(8 + 6, 3, Color.WHITE)
	var sample := {"kind": "shp", "img": img, "tex": ImageTexture.create_from_image(img),
		"rects": [{"x": 0, "y": 0, "w": 8, "h": 6}, {"x": 8, "y": 0, "w": 8, "h": 6}]}
	if RA2Art.anchor(sample, [0, 1]) != Vector2(4.5, 4) or RA2Art.anchor(sample, [0]) != Vector2(2.5, 2):
		print("FAIL alpha threshold or merged anchor")
		failed += 1
	print("BOUNDS frames=", frames, " failed=", failed)
	get_tree().quit(0 if failed == 0 else 1)
