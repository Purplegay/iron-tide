extends Node2D
## LeaveRubble uses the original final visible SHP frame, never reverse buildup.
## Cosmetic persistent terrain: no combat actor, production, selection or blocker.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
var world
var art: Dictionary = {}
var rubble_texture: Texture2D
var radius := 38.0
var frame := 0
var knowledge: Dictionary = {}

static func leave(building) -> void:
	if building.under_construction or not Rules.flag(Rules.type_data(building.building_id), "leaverubble"): return
	var source: Dictionary = building._ra2
	if source.is_empty() or int(source.get("count", 0)) < 6: return
	var world = building.battle
	if not world.allied_state.has("building_rubble"): world.allied_state.building_rubble = []
	world.allied_state.building_rubble.append({"id":building.building_id, "point":building.position, "radius":building.radius,
		"seen":world.position_visible_to("ally", building.position)})
	restore(world)

static func restore(world) -> void:
	for node in world.get_tree().get_nodes_in_group("yr_building_rubble"):
		if node.world == world: node.free()
	for row in world.allied_state.get("building_rubble", []):
		var source := RA2Art.art(str(row.id))
		if source.is_empty(): continue
		var node = load("res://scripts/buildings/building_rubble.gd").new()
		node.world = world; node.art = source; node.radius = float(row.radius)
		if row.id == "CAOILD":
			var map := preload("res://scripts/world/native_maps.gd").data(world.map_layout())
			var theater := str(map.get("theater", "urban")).left(3).to_lower()
			node.rubble_texture = load("res://assets/ra2/shp/CAOILD_RUBBLE_%s.png" % theater)
		node.knowledge = row
		node.frame = int(source.get("count", 2)) / 2 - 1
		node.position = row.point
		node.z_as_relative = false; node.z_index = DepthLayers.DECAL
		world.add_child(node); node.add_to_group("yr_building_rubble")
		node._process(0.0)

func _process(_delta: float) -> void:
	# An unseen destruction must not reveal a new ruin through explored fog.
	if world.position_visible_to("ally", position): knowledge.seen = true
	visible = bool(knowledge.get("seen", false)) and world.position_explored_by("ally", position)

func _draw() -> void:
	Iso.begin(self)
	var anchor := RA2Art.anchor(art, [0])
	var base := Vector2(-anchor.x, radius * 0.35 - anchor.y)
	if rubble_texture != null:
		draw_texture(rubble_texture, base)
		return
	RA2Art.draw_sprite(self, art, Rect2(base, RA2Art.frame_size(art)), RA2Art.src_rect(art, frame))
