extends RefCounted
## UI preferences only; never alter progression or battle saves.
const PATH := "user://progression_bookmarks.cfg"
var config := ConfigFile.new()
var bound: Dictionary = {}
var pending: Dictionary = {}
var generation := 0

func _init() -> void:
	if config.load(PATH) != OK: config = ConfigFile.new()

func get_value(key:String, fallback:Variant) -> Variant:
	return config.get_value("selection",key,fallback)

func set_value(key:String, value:Variant) -> void:
	config.set_value("selection",key,value)

func remember(view:ScrollContainer, exiting:=false) -> void:
	if not is_instance_valid(view) or (not exiting and not view.is_visible_in_tree()):return
	var id:=view.get_instance_id()
	if bound.has(id) and not pending.has(id):
		config.set_value("scroll",bound[id],view.scroll_vertical)

func restore(view:ScrollContainer,key:String) -> void:
	if not is_instance_valid(view) or not view.is_visible_in_tree():return
	var id:=view.get_instance_id()
	bound[id]=key
	generation+=1
	var ticket:=generation
	pending[id]=ticket
	# Containers need two layout passes after rebuilt children and visibility changes.
	for frame in 2:
		if not is_instance_valid(view) or not view.is_inside_tree():return
		await view.get_tree().process_frame
	if not is_instance_valid(view) or pending.get(id)!=ticket:return
	var raw:Variant=config.get_value("scroll",key,0)
	var offset:=maxi(0,int(raw)) if raw is int or raw is float else 0
	view.scroll_vertical=offset # ScrollContainer clamps to its current range.
	pending.erase(id)

func save() -> void:
	var error:=config.save(PATH+".tmp")
	if error==OK:error=DirAccess.rename_absolute(PATH+".tmp",PATH)
	if error!=OK:push_warning("无法保存养成页面位置："+error_string(error))
