extends RefCounted

const KEY := "opening_order_plans"

const FILE := "user://opening_order_plans.cfg"

static func _load_book(path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return {}
	var value = cfg.get_value("opening", "book", {})
	if not value is Dictionary or not value.get("plans") is Array or not value.get("selected") is int:
		return {}
	if value.selected < 0 or value.selected >= value.plans.size():
		return {}
	for plan in value.plans:
		if not plan is Dictionary or not plan.get("name") is String or not plan.get("orders") is Array:
			return {}
		for order in plan.orders:
			if not order is String: return {}
	return value

static func _replace(path: String, book: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("opening", "book", book)
	var temp := path + ".%d.tmp" % OS.get_process_id()
	return cfg.save(temp) == OK and _load_book(temp) == book and DirAccess.rename_absolute(temp, path) == OK

static func persist(book: Dictionary) -> bool:
	var previous := _load_book(FILE)
	if not previous.is_empty():
		if not _replace(FILE + ".bak", previous): return false
	elif _load_book(FILE + ".bak").is_empty():
		if not _replace(FILE + ".bak", book): return false
	return _replace(FILE, book)

static func current(profile: Dictionary) -> Dictionary:
	for path in [FILE, FILE + ".bak"]:
		var saved := _load_book(path)
		if not saved.is_empty(): return saved
	var legacy := read(profile)
	if profile.has(KEY) or profile.has("opening_orders"):
		legacy.selected = int(legacy.selected)
		if not persist(legacy): push_warning("开局出兵方案迁移失败，下次读取时重试。")
	return legacy

static func read(profile: Dictionary) -> Dictionary:
	if profile.has(KEY):
		return profile[KEY].duplicate(true)
	var old: Dictionary = profile.get("opening_orders", {})
	var orders: Array = old.get("allied", []).duplicate()
	orders.append_array(old.get("soviet", []))
	return {"selected":0, "plans":[{"name":"1", "orders":orders}]}

static func selected_orders(profile: Dictionary) -> Array:
	var book := read(profile)
	return book.plans[book.selected].orders.duplicate()

static func submit(world) -> void:
	var waiting: Array = []
	for id: String in world.allied_state.opening_orders_pending:
		var producer: String = GameData.get_unit(id).get("built_at", "")
		var chosen = null
		for factory in world.buildings:
			if not world.actor_alive(factory) or factory.side != "ally" or id not in factory.buildable:
				continue
			if not factory.queue_block_reason(id).is_empty():
				continue
			if chosen == null:
				chosen = factory
			elif (factory.building_id == producer) != (chosen.building_id == producer):
				if factory.building_id == producer: chosen = factory
			elif factory.production.size() < chosen.production.size():
				chosen = factory
		if chosen == null or not chosen.enqueue(id): waiting.append(id)
	if waiting.is_empty(): world.allied_state.erase("opening_orders_pending")
	else: world.allied_state.opening_orders_pending = waiting
