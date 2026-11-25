extends Node2D
## Small rifle animations share a canvas; every shot keeps its own frame clock.
const NAME := "RifleAnimations"
var entries: Array[Entry] = []
var world: Node

class Entry extends RefCounted:
	var anim: Dictionary
	var point: Vector2
	var scale: float
	var age := 0.0
	var frame := 0
	var visible := true

static func supports(image: String) -> bool:
	return image in ["PIFF", "PIFFPIFF", "MGUN-N", "MGUN-NE", "MGUN-E", "MGUN-SE", "MGUN-S", "MGUN-SW", "MGUN-W", "MGUN-NW"]

static func emit(host: Node, point: Vector2, anim: Dictionary, scale: float, bright: bool) -> void:
	var key := NAME + ("Bright" if bright else "Normal")
	var batch = host.get_node_or_null(key)
	if batch == null:
		batch = load("res://scripts/core/rifle_fx_batch.gd").new()
		batch.name = key
		batch.z_as_relative = false
		batch.z_index = DepthLayers.FX + 1
		batch.add_to_group("per_piece_fog_visibility")
		if bright: batch.material = Ra2Fx.additive_material()
		batch.world = host
		while batch.world != null and not batch.world.has_method("position_visible_to"):
			batch.world = batch.world.get_parent()
		host.add_child(batch)
	var entry := Entry.new()
	entry.anim = anim
	entry.point = point
	entry.scale = scale
	entry.visible = batch.point_visible(point)
	batch.entries.append(entry)
	batch.set_process(true)
	batch.queue_redraw()

func point_visible(point: Vector2) -> bool:
	return not is_instance_valid(world) or world.position_visible_to("ally", to_global(point))

func _process(delta: float) -> void:
	var changed := false
	# Stable compaction preserves overlapping flashes' insertion order.
	var kept := 0
	for entry in entries:
		entry.age += delta
		var frame := floori(entry.age * maxf(1.0, float(entry.anim.get("fps", Ra2Fx.NOMINAL_FPS))))
		if frame >= int(entry.anim.get("count", 1)):
			changed = true
			continue
		var shown := point_visible(entry.point)
		changed = changed or frame != entry.frame or shown != entry.visible
		entry.frame = frame
		entry.visible = shown
		entries[kept] = entry
		kept += 1
	entries.resize(kept)
	if changed: queue_redraw()
	if entries.is_empty(): set_process(false)

func _draw() -> void:
	Iso.begin(self)
	for entry in entries:
		if not entry.visible: continue
		var size: Vector2 = entry.anim.cell * entry.scale
		draw_texture_rect_region(entry.anim.tex, Rect2(Iso.dir(entry.point) - size * 0.5, size), RA2Art.fx_rect(entry.anim, entry.frame))
