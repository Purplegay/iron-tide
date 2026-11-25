extends Node2D
## Rebuilt from saved cloud deadlines; no gameplay state lives in rendering.
var world

static func sync(battle) -> void:
	var visual = battle.get_node_or_null("StormPresentation")
	if visual == null:
		visual = load("res://scripts/world/storm_presentation.gd").new()
		visual.name = "StormPresentation"
		visual.world = battle
		visual.z_index = DepthLayers.FX
		battle.add_child(visual)
	var lighting = visual.get_node_or_null("StormLighting")
	if lighting == null:
		lighting = CanvasModulate.new()
		lighting.name = "StormLighting"
		visual.add_child(lighting)
	var active := false
	for state in LightningStorm.storms(battle):
		if state.started: active = true
	# Generated maps lack original map [Lighting] values. Explicit visual adapter.
	lighting.color = Color(0.65, 0.69, 0.78) if active else Color.WHITE
	visual.queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	for state in LightningStorm.storms(world):
		for cloud in state.get("clouds", []):
			if not world.position_visible_to("ally", cloud.point): continue
			var art := RA2Art.fx(str(cloud.id))
			var texture: Texture2D = art.get("tex")
			if texture == null: continue
			var frame := mini(int(art.get("count", 1)) - 1, maxi(0, int((state.time - cloud.born) * float(art.get("fps", 6.25)))))
			var size: Vector2 = art.get("cell", Vector2.ZERO)
			draw_texture_rect_region(texture, Rect2(Iso.dir(cloud.point) + Vector2(0, -110) - size * 0.5, size), RA2Art.fx_rect(art, frame))
