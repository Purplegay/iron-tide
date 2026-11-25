extends Node
## Load the normal SHP layers while the construction animation is playing.
## Only the main thread touches the regular art caches. Each battle owns one queue.
const Detail = preload("res://scripts/core/shp_detail.gd")
var jobs: Dictionary = {}
var loading := ""

func _ready() -> void:
	set_process(false)

## An infantry type may first become visible well after the save has loaded.
## Prepare its shared grade during loading and stream the initial detail page.
func prepare_infantry(units: Array) -> void:
	var prepared := {}
	for unit in units:
		if not is_instance_valid(unit) or prepared.has(unit.unit_id): continue
		var art: Dictionary = unit._ra2
		if art.get("kind") != "shp" or not unit._seq.has("Guard"): continue
		prepared[unit.unit_id] = true
		RA2Art.sprite_grade(art)
		_queue_page(art, RA2Art.seq_frame(unit._seq, "Guard", 0, 0))
	# Stream additional pages only for SHP artwork present in this battle.
	var queued_art := {}
	for unit in units:
		if not is_instance_valid(unit) or queued_art.has(unit.unit_id): continue
		queued_art[unit.unit_id] = true
		var art: Dictionary = unit._ra2
		for page in art.get("detail", {}).get("pages", []):
			var path := Detail.ROOT + str(page.file)
			if not Detail._textures.has(path): jobs[path] = {"page": page}
	set_process(not jobs.is_empty() or not loading.is_empty())

func prepare(building) -> void:
	if building._ra2.get("kind") != "shp": return
	var body: Dictionary = building._ra2
	var body_frame: int = building._body_damage_frame()
	_queue_page(body, body_frame)
	var stages := int(body.get("dmg", 1))
	if stages >= 2 and int(body.get("count", 0)) == 2 * stages:
		_queue_page(body, body_frame + stages)
	for layer in building._ra2_anim:
		var kind := str(layer.get("kind", ""))
		if not (kind.begins_with("activeanim") or kind.begins_with("idleanim")): continue
		var state: Dictionary = building._anim_layer(layer)
		var id := str(state.image)
		if id.is_empty(): continue
		var path := RA2Art.SHP_DIR + id + ".png"
		var spans: Array = jobs.get(path, {}).get("spans", [])
		var normal := Vector2i(int(state.loopStart), int(state.loopEnd))
		if not spans.has(normal): spans.append(normal)
		if state.shadow:
			var shadow := normal + Vector2i.ONE * int(state.frames)
			if not spans.has(shadow): spans.append(shadow)
		jobs[path] = {"id": id, "spans": spans}
	set_process(not jobs.is_empty())

func _queue_page(art: Dictionary, frame: int) -> void:
	var detail: Dictionary = art.get("detail", {})
	if detail.is_empty() or frame < 0 or frame >= int(art.get("count", 0)): return
	var rect := Rect2i(RA2Art.src_rect(art, frame))
	var entry: Dictionary = detail.lookup.get(Vector4i(rect.position.x, rect.position.y, rect.size.x, rect.size.y), {})
	var index := int(entry.get("page", -1))
	if index < 0: return
	var page: Dictionary = detail.pages[index]
	var path := Detail.ROOT + str(page.file)
	if not Detail._textures.has(path): jobs[path] = {"page": page}

func _process(_delta: float) -> void:
	if loading.is_empty():
		if jobs.is_empty():
			set_process(false)
			return
		var path: String = jobs.keys()[0]
		if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path, "Texture2D") != OK:
			jobs.erase(path)
			return
		loading = path
	if ResourceLoader.load_threaded_get_status(loading) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	var texture := ResourceLoader.load_threaded_get(loading) as Texture2D
	var job: Dictionary = jobs[loading]
	jobs.erase(loading)
	loading = ""
	if texture == null: return
	if job.has("page"):
		Detail.page_texture(job.page, texture)
	else:
		# Holding the resource here lets art() parse the normal metadata using
		# the already loaded texture, including the native fallback atlas.
		var art := RA2Art.art(job.id)
		for span: Vector2i in job.spans:
			for frame in range(maxi(0, span.x), mini(int(art.get("count", 0)), span.y + 1)):
				_queue_page(art, frame)

func _exit_tree() -> void:
	# Balance the single outstanding request if the player leaves during buildup.
	if not loading.is_empty(): ResourceLoader.load_threaded_get(loading)
