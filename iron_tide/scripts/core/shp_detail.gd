extends RefCounted
const EMPTY_STATE:Dictionary={}
## Offline palette-preserving 2x frames. Logical geometry stays in native pixels.
const ROOT := "res://assets/ra2/detail/"
const CACHE_BYTES := 64 * 1024 * 1024
static var _textures: Dictionary = {}
static var _bytes := 0

static func manifest(id: String, native_size: Vector2) -> Dictionary:
	var path := ROOT + id + ".json"
	if not FileAccess.file_exists(path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("method", "") != "palette-edge-2x":
		push_error("Invalid SHP detail manifest: " + id)
		return {}
	var size: Array = data.get("source_size", [])
	if size.size() != 2 or Vector2(size[0], size[1]) != native_size:
		push_error("Stale SHP detail size: " + id)
		return {}
	var lookup := {}
	for entry in data.frames:
		var source: Array = entry.source
		lookup[Vector4i(source[0], source[1], source[2], source[3])] = entry
	data["lookup"] = lookup
	return data

static func clear_cache() -> void:
	_textures.clear()
	_bytes = 0

static func page_texture(page: Dictionary, loaded: Texture2D = null) -> Texture2D:
	var path: String = ROOT + str(page.file)
	if _textures.has(path): return _textures[path]
	if not ResourceLoader.exists(path):
		push_error("Missing SHP detail page: " + path)
		return null
	var texture := loaded if loaded != null else load(path) as Texture2D
	if texture == null or texture.get_size() != Vector2(page.width, page.height):
		push_error("Invalid SHP detail page size: " + path)
		return null
	var bytes := texture.get_width() * texture.get_height() * 4
	while not _textures.is_empty() and _bytes + bytes > CACHE_BYTES:
		var key = _textures.keys()[0]
		var old: Texture2D = _textures[key]
		_bytes -= old.get_width() * old.get_height() * 4
		_textures.erase(key)
	_textures[path] = texture
	_bytes += bytes
	return texture

static func draw(canvas: CanvasItem, art: Dictionary, target: Rect2, source: Rect2, tint: Color, waterline := INF) -> bool:
	var detail: Dictionary = art.get("detail", EMPTY_STATE)
	if detail.is_empty(): return false
	var key := Vector4i(source.position.x, source.position.y, source.size.x, source.size.y)
	var entry: Dictionary = detail.lookup.get(key, EMPTY_STATE)
	if entry.is_empty(): return false
	if int(entry.page) < 0: return true
	var page: Dictionary = detail.pages[int(entry.page)]
	var refs: Dictionary = canvas.get_meta("shp_detail_textures", {})
	var texture: Texture2D = refs.get(page.file)
	if texture == null:
		var previous: Dictionary = canvas.get_meta("shp_detail_previous", EMPTY_STATE)
		texture = previous.get(page.file)
		if texture == null:
			texture = page_texture(page)
	if texture == null: return false
	# Rendering commands do not keep Texture2D alive. Actors retain every page
	# used by their draw list, including when the shared cache evicts a page.
	refs[page.file] = texture
	if not canvas.has_meta("shp_detail_textures"):
		canvas.set_meta("shp_detail_textures", refs)
	var crop: Array = entry.crop
	var uv: Array = entry.rect
	var ratio := target.size / source.size
	var destination := Rect2(target.position + Vector2(crop[0], crop[1]) * ratio, Vector2(crop[2], crop[3]) * ratio)
	draw_region(canvas,texture,destination,Rect2(uv[0],uv[1],uv[2],uv[3]),tint,waterline)
	return true

static func draw_region(canvas:CanvasItem,texture:Texture2D,dest:Rect2,uv:Rect2,tint:Color,waterline:float) -> void:
	if canvas.has_meta("time_fracture") and tint.r>0.1:
		preload("res://scripts/core/yr_signature_fx.gd").ghosts(canvas,texture,dest,uv,canvas.get_meta("time_fracture"))
	if tint.r+tint.g+tint.b>0.01:
		preload("res://scripts/ui/unit_selection_outline.gd").capture(canvas,texture,dest,uv,tint.a)
	if waterline>=dest.end.y:
		canvas.draw_texture_rect_region(texture,dest,uv,tint)
		return
	# Split the final atlas region, so native and 2x artwork use the same waterline.
	var dry:=clampf((waterline-dest.position.y)/dest.size.y,0.0,1.0)
	var dry_dest:=Vector2(dest.size.x,dest.size.y*dry)
	var dry_uv:=Vector2(uv.size.x,uv.size.y*dry)
	if dry>0:canvas.draw_texture_rect_region(texture,Rect2(dest.position,dry_dest),Rect2(uv.position,dry_uv),tint)
	var wet_dest:=Rect2(dest.position+Vector2.DOWN*dry_dest.y,Vector2(dest.size.x,dest.size.y-dry_dest.y))
	var wet_uv:=Rect2(uv.position+Vector2.DOWN*dry_uv.y,Vector2(uv.size.x,uv.size.y-dry_uv.y))
	canvas.draw_texture_rect_region(texture,wet_dest,wet_uv,tint*Color(0.62,0.86,0.95,0.61))
