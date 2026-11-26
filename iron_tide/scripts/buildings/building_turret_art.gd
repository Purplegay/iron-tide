class_name BuildingTurretArt
extends RefCounted
## Shared turret pose: advanced by Building's tick, read by drawing and firing.

var art: Dictionary = {}
var origins: Array = []
var muzzles: Array = []
var offset := Vector2.ZERO
var angle := 0.0
var facing_offset := 0
var frame := -1
var rect := Rect2()
var visible := false
var image: Image
var recoil: Dictionary = {}
var recoil_texture: Texture2D
var recoil_art: Dictionary = {}
var recoil_image: Image
var _recoil_elapsed := -1.0
var drawn_source := Rect2()
var drawn_image: Image
var gatling: Dictionary = {}
var spin_pose := 0

func setup(id: String) -> void:
	var path := "res://assets/ra2/bldturret/" + id + ".json"
	if not FileAccess.file_exists(path):
		return
	var descriptor = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not descriptor is Dictionary:
		return
	art = RA2Art.art(str(descriptor.get("image", "")))
	origins = descriptor.get("origins", [])
	if descriptor.has("stages"): gatling = descriptor
	muzzles = descriptor.get("muzzles", [])
	recoil = descriptor.get("recoil", {})
	if not recoil.is_empty():
		recoil_texture = load(str(recoil.image)) as Texture2D
		if recoil_texture != null:
			recoil_art = {"tex": recoil_texture}
			if recoil.has("detail_image"):
				var detail := load(str(recoil.detail_image)) as Texture2D
				if detail != null and detail.get_size() == recoil_texture.get_size() * 2.0:
					recoil_art["detail_tex"] = detail
					recoil_art["detail_scale"] = 2.0
				else: push_error("Invalid defense recoil detail: " + id)
			recoil_image = recoil_texture.get_image()
			if recoil_image.is_compressed():
				recoil_image.decompress()
	facing_offset = int(descriptor.get("facing_offset", 0))
	var p: Array = descriptor.get("offset", [0, 0])
	offset = Vector2(float(p[0]), float(p[1]))
	var texture: Texture2D = art.get("tex")
	if texture != null:
		image = texture.get_image()
		if image.is_compressed():
			image.decompress()

func turn_toward(direction: Vector2, delta: float, degrees_per_second: float) -> void:
	if direction.is_zero_approx():
		return
	var step := deg_to_rad(degrees_per_second) * maxf(0.0, delta)
	angle = wrapf(angle + clampf(angle_difference(angle, direction.angle()), -step, step), -PI, PI)

func aligned(direction: Vector2) -> bool:
	return not direction.is_zero_approx() and absf(angle_difference(angle, direction.angle())) <= deg_to_rad(2.0)

func facing() -> int:
	var count := int(art.get("facings", 0))
	return posmod(RA2Art.facing_index(angle, count) + facing_offset, count) if count > 0 else -1

func start_recoil() -> void:
	if not recoil.is_empty() and recoil_texture != null:
		_recoil_elapsed = 0.0

func advance_recoil(delta: float) -> bool:
	var previous := recoil_pose()
	if _recoil_elapsed >= 0.0:
		_recoil_elapsed += maxf(0.0, delta)
		var duration := float(recoil.compress_seconds) + float(recoil.hold_seconds) + float(recoil.recover_seconds)
		if _recoil_elapsed >= duration:
			_recoil_elapsed = -1.0
	return recoil_pose() != previous

func recoil_pose() -> int:
	if _recoil_elapsed < 0.0 or recoil.is_empty() or recoil_texture == null:
		return 0
	var compress := float(recoil.compress_seconds)
	var recover_start := compress + float(recoil.hold_seconds)
	var amount := 1.0
	if _recoil_elapsed < compress:
		amount = _recoil_elapsed / maxf(0.001, compress)
	elif _recoil_elapsed > recover_start:
		amount = 1.0 - (_recoil_elapsed - recover_start) / maxf(0.001, float(recoil.recover_seconds))
	return clampi(roundi(amount * int(recoil.steps)), 0, int(recoil.steps))

func _pose_origins() -> Array:
	var pose := recoil_pose()
	return recoil.poses[pose - 1].origins if pose > 0 else origins

func muzzle_point(base: Vector2, body_size: Vector2, scale: float) -> Vector2:
	var f := facing() + spin_pose * int(art.get("facings",0))
	if f < 0 or f >= muzzles.size() or f >= origins.size():
		return Vector2.INF
	var pose := recoil_pose()
	var points: Array = recoil.poses[pose - 1].muzzles if pose > 0 else muzzles
	var anchors := _pose_origins()
	var origin := Vector2(float(anchors[f][0]), float(anchors[f][1]))
	var muzzle := Vector2(float(points[f][0]), float(points[f][1]))
	return base + (body_size * 0.5 + offset - origin + muzzle) * scale

func draw_on(canvas: CanvasItem, base: Vector2, body_size: Vector2, scale: float, tint := Color.WHITE) -> void:
	var texture: Texture2D = art.get("tex")
	if texture == null or origins.size() < int(art.get("facings", 0)):
		return
	frame = facing() + spin_pose * int(art.facings)
	var pose := recoil_pose()
	var anchors := _pose_origins()
	var origin := Vector2(float(anchors[frame][0]), float(anchors[frame][1]))
	rect = Rect2(base + (body_size * 0.5 + offset - origin) * scale, RA2Art.frame_size(art) * scale)
	drawn_source = RA2Art.src_rect(art, frame)
	drawn_image = image
	var drawing_art := art
	if pose > 0:
		texture = recoil_texture
		drawing_art = recoil_art
		drawn_image = recoil_image
		drawn_source.position.y += (pose - 1) * (drawn_source.size.y + RA2Art.VXL_PAD)
	RA2Art.draw_sprite(canvas, drawing_art, rect, drawn_source, RA2Art.sprite_grade(art) * tint)
	visible = true

func hit_test(local_art_point: Vector2) -> bool:
	if not visible or drawn_image == null or not rect.has_point(local_art_point):
		return false
	var source := drawn_source
	var pixel := Vector2i(source.position + (local_art_point - rect.position) / rect.size * source.size)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= drawn_image.get_width() or pixel.y >= drawn_image.get_height():
		return false
	return drawn_image.get_pixelv(pixel).a * 255.0 >= 20.0
