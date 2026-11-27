extends RefCounted

const SEGMENTS := 32
const HEIGHT := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
const LEPTON := Ra2Damage.PX_PER_CELL / 256.0
const ARCH_LEPTONS := 512.0
const TARGET_OFFSET := 70.0 # TechnoTypeClass::LeptonMindControlOffset default (0x710D28).
const PHASE_COUNT := 64
const PALETTE_LIMIT := 16
static var _arc_offsets := _make_arc_offsets()
static var _house_palettes: Dictionary[Color, PackedColorArray] = {}
# artmd [MIND] AlternateFLH0..4. The capture manager calls GetFLH(-1 - index % 5).
const MASTERMIND_FLH := [Vector3(0,25,90), Vector3(0,-25,90), Vector3(-50,25,90), Vector3(-50,-25,90), Vector3(-25,0,90)]

static func endpoints(source, target, managed: bool) -> PackedVector2Array:
	if not managed: return PackedVector2Array([Iso.dir(source.art_center()), Iso.dir(target.art_center())])
	var from: Vector2 = Iso.dir(source.global_position)
	if source is Unit:
		var height: float = source._visual_lift()
		if source.unit_id == "MIND":
			var index: int = source.special.get("mind_links", []).find(target)
			var flh: Vector3 = MASTERMIND_FLH[maxi(0, index) % MASTERMIND_FLH.size()]
			from += Iso.dir(Vector2(flh.x, flh.y).rotated(source.hull_angle) * LEPTON)
			height += flh.z * HEIGHT
		from.y -= height
	else:
		from = Iso.dir(source.art_center())
	var to := Iso.dir(target.global_position)
	if target is Unit: to.y -= target._visual_lift()
	to.y -= TARGET_OFFSET * HEIGHT
	return PackedVector2Array([from, to])

# Steam gamemd 704E40: interpolate XYZ in 32 steps, then add 512*(1-((i-16)/16)^2) to Z.
static func point(from: Vector2, to: Vector2, i: int) -> Vector2:
	var t := float(i) / SEGMENTS
	return from.lerp(to, t) + _arc_offsets[i]

static func _make_arc_offsets() -> PackedVector2Array:
	var offsets := PackedVector2Array()
	for i in range(SEGMENTS + 1):
		var centered := 2.0 * (float(i) / SEGMENTS) - 1.0
		offsets.append(Vector2.UP * (ARCH_LEPTONS * HEIGHT * (1.0 - centered * centered)))
	return offsets

# 70519A / 6612C0: 16 ms per phase step, half the loop tints from house RGB toward white.
static func segment_color(base: Color, i: int, clock_msec: int) -> Color:
	var phase := (i * 8 - ((clock_msec >> 4) << 3)) & 0x1f8
	return base.lerp(Color.WHITE, float(phase) / 256.0) if phase <= 0xf8 else base

# A packed slice moves the 32-color window through the 64-entry wrapped palette.
# Cache only immutable arithmetic keyed by the actual house color, never endpoints or visibility.
static func link_colors(base: Color, clock_msec: int) -> PackedColorArray:
	var palette: PackedColorArray = _house_palettes.get(base, PackedColorArray())
	if palette.is_empty():
		if _house_palettes.size() >= PALETTE_LIMIT: _house_palettes.clear()
		palette.resize(PHASE_COUNT + SEGMENTS - 1)
		for i in range(PHASE_COUNT): palette[i] = segment_color(base, i, 0)
		for i in range(SEGMENTS - 1): palette[PHASE_COUNT + i] = palette[i]
		_house_palettes[base] = palette
	var first := (1 - (clock_msec >> 4)) & (PHASE_COUNT - 1)
	return palette.slice(first, first + SEGMENTS)

static func link_segments(ends: PackedVector2Array) -> PackedVector2Array:
	var lines := PackedVector2Array()
	lines.resize(SEGMENTS * 2)
	var from := ends[0]
	var to := ends[1]
	var previous := from
	for i in range(1, SEGMENTS + 1):
		var next := point(from, to, i)
		lines[2 * (i - 1)] = previous
		lines[2 * i - 1] = next
		previous = next
	return lines

static func draw_link(overlay: Node2D, ends: PackedVector2Array, base: Color, clock_msec: int) -> void:
	overlay.draw_multiline_colors(link_segments(ends), link_colors(base, clock_msec), -1.0)
	for end in ends: overlay.draw_rect(Rect2(end - Vector2(2, 2), Vector2(3, 3)), base)
