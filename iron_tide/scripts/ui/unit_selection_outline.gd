extends Node2D
## Selection and attack-target silhouettes under the actual art.
## SDK defines SELECTED separately from HOVER_SELECT/HOVER_ATTACK. Color/width
## below are the Godot adaptation, not recovered SAGE rendering constants.
const OUTLINE_SHADER = preload("res://shaders/selection_outline.gdshader")
const COLOR := Color(0.55, 1.0, 0.64, 0.95)
const ATTACK_COLOR := Color(1.0, 0.22, 0.12, 1.0)
const ATTACK_META := &"attack_target_outline"
const FRIEND_COLOR := Color.WHITE
const OWN_COLOR := Color(1.0, 0.85, 0.1, 1.0)
const FRIEND_META := &"friendly_outline"
const SCREEN_WIDTH := 1.5
var recording := false
var used := 0
var width := SCREEN_WIDTH
var color := COLOR

class Layer extends Node2D:
	var texture: Texture2D
	var destination := Rect2()
	var last_source := Rect2()
	var last_border := 0.0
	var last_alpha := 0.0
	var last_color := Color.TRANSPARENT
	func _draw() -> void:
		if texture != null: draw_texture_rect(texture, destination, false)

static func eligible(actor) -> bool:
	if not (actor is Unit or actor is Building) or actor._dead or actor.hp<=0.0 or not actor.is_visible_in_tree(): return false
	if actor is Unit and (actor.embarked_in != null or actor.unit_id in ["V3ROCKET", "DMISL", "CMISL"]): return false
	return actor.has_meta(ATTACK_META) or actor.has_meta(FRIEND_META) or (actor is Unit and actor.selected)

static func clear(actor) -> void:
	if actor is Unit and actor._ra3_model!=null:actor._ra3_model.release_body_mask()
	var outline = actor.get_node_or_null("SelectionOutline")
	if outline != null and (outline.visible or outline.recording):
		outline.recording = false
		outline.visible = false
		# Release animated SHP pages/viewport textures when deselected or destroyed.
		for child in outline.get_children():
			child.texture = null
			child.material.set_shader_parameter("silhouette_texture", null)
			child.visible = false

static func begin(actor) -> void:
	if not eligible(actor): clear(actor); return
	var outline = actor.get_node_or_null("SelectionOutline")
	if outline == null:
		outline = load("res://scripts/ui/unit_selection_outline.gd").new()
		outline.name = "SelectionOutline"
		outline.show_behind_parent = true
		actor.add_child(outline)
	outline.visible = true; outline.recording = true; outline.used = 0
	outline.color = COLOR
	if actor.has_meta(ATTACK_META):
		outline.color = ATTACK_COLOR
	elif actor.has_meta(FRIEND_META):
		outline.color = OWN_COLOR if actor.side == "ally" else FRIEND_COLOR
	var pose: Transform2D = actor.body_draw_transform() if actor is Unit else Transform2D(Iso.eff_angle(),Iso.up(),0.0,Vector2.ZERO)
	outline.transform = pose
	var transform: Transform2D = actor.get_global_transform_with_canvas() * pose
	outline.width = SCREEN_WIDTH / maxf(0.1, transform.x.length())

static func capture(actor: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, alpha := 1.0) -> void:
	if not eligible(actor): return
	var outline = actor.get_node_or_null("SelectionOutline")
	if outline == null or not outline.recording or not eligible(actor) or texture == null or alpha <= 0.01 or not source.has_area() or not destination.has_area(): return
	var layer: Layer
	if outline.used == outline.get_child_count():
		layer = Layer.new()
		var shader := ShaderMaterial.new(); shader.shader = OUTLINE_SHADER
		shader.set_shader_parameter("outline_color", COLOR)
		layer.material = shader
		outline.add_child(layer)
	else: layer = outline.get_child(outline.used)
	outline.used += 1
	layer.visible = true
	if layer.last_color != outline.color:
		layer.material.set_shader_parameter("outline_color",outline.color)
		layer.last_color = outline.color
	var expanded := destination.grow(outline.width)
	if layer.texture == texture and layer.destination == expanded and layer.last_source == source and layer.last_border == outline.width and layer.last_alpha == alpha:
		return
	var changed_texture := layer.texture != texture
	if changed_texture or layer.last_source != source:
		var size := texture.get_size()
		layer.material.set_shader_parameter("source_region", Vector4(source.position.x / size.x, source.position.y / size.y, source.size.x / size.x, source.size.y / size.y))
		if changed_texture:
			layer.material.set_shader_parameter("silhouette_texture", texture)
			layer.material.set_shader_parameter("texel_size", Vector2.ONE / size)
	if layer.last_border != outline.width:
		layer.material.set_shader_parameter("border", outline.width)
	if layer.last_border != outline.width or layer.destination.size != expanded.size:
		layer.material.set_shader_parameter("logical_size", destination.size)
	if layer.last_alpha != alpha:
		layer.material.set_shader_parameter("opacity", clampf(alpha, 0.0, 1.0))
	if changed_texture or layer.destination != expanded: layer.queue_redraw()
	layer.texture = texture
	layer.destination = expanded
	layer.last_source = source
	layer.last_border = outline.width
	layer.last_alpha = alpha

static func end(actor) -> void:
	var outline = actor.get_node_or_null("SelectionOutline")
	if outline == null: return
	outline.recording = false
	for i in range(outline.used, outline.get_child_count()):
		var layer = outline.get_child(i)
		layer.visible = false; layer.texture = null
		layer.material.set_shader_parameter("silhouette_texture", null)
	outline.visible = outline.used > 0 and eligible(actor)
