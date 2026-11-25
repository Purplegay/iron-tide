extends RefCounted
const Tech = preload("res://scripts/rules/joint_ra2_production.gd")
const KEY := "parallel_production"

static func enabled(b) -> bool:
	return b.building_id in Tech.FACTORIES and Tech.active(b.side)

static func lane(uid: String) -> String:
	return "air" if GameData.get_unit(uid).get("tags",[]).has("air") else "vehicle"

static func empty_state() -> Dictionary:
	return {"progress":0.0,"paid":0.0,"paused":false,"blocked":false}

static func legacy_state(b) -> Dictionary:
	var value := {"progress":b.progress,"paid":b.production_paid,"paused":bool(b.special.get("production_paused",false)),"blocked":b.exit_blocked}
	if b.special.has("unit_price"): value.price = b.special.unit_price
	return value

static func prepare(b) -> void:
	if b.special.has(KEY) or not enabled(b): return
	var values := {}
	if not b.production.is_empty(): values[lane(str(b.production[0]))] = legacy_state(b)
	b.special[KEY] = values

static func head(b, uid := "") -> int:
	if b.production.is_empty(): return -1
	if uid.is_empty() or not enabled(b): return 0
	for i in b.production.size():
		if lane(str(b.production[i])) == lane(uid): return i
	return -1

static func category_head(b, category: String) -> String:
	for uid in b.production:
		if not enabled(b) or category not in ["air","vehicle"] or lane(str(uid)) == category: return str(uid)
	return ""

static func state(b, uid := "") -> Dictionary:
	prepare(b)
	if not b.special.has(KEY): return legacy_state(b)
	if uid.is_empty(): uid = str(b.production[0]) if not b.production.is_empty() else ""
	return b.special[KEY].get(lane(uid),empty_state())

static func write_legacy(b, value: Dictionary) -> void:
	b.progress = float(value.progress)
	b.production_paid = float(value.paid)
	b.exit_blocked = bool(value.blocked)
	if value.paused: b.special.production_paused = true
	else: b.special.erase("production_paused")
	if value.has("price"): b.special.unit_price = value.price
	else: b.special.erase("unit_price")

static func store(b, uid: String, value: Dictionary) -> void:
	if b.special.has(KEY):
		b.special[KEY][lane(uid)] = value
		sync(b)
	else: write_legacy(b,value)

static func sync(b) -> void:
	if not b.special.has(KEY): return
	write_legacy(b, state(b) if not b.production.is_empty() else empty_state())

static func count(b, uid: String) -> int:
	if not enabled(b): return b.production.size()
	var total := 0
	for item in b.production:
		if lane(str(item)) == lane(uid): total += 1
	return total

static func stored_head(b, uid: String) -> int:
	if not b.special.has(KEY): return head(b,uid)
	for i in b.production.size():
		if lane(str(b.production[i])) == lane(uid): return i
	return -1

static func total_paid(b) -> float:
	if not b.special.has(KEY): return b.production_paid
	var total := 0.0
	for value: Dictionary in b.special[KEY].values(): total += float(value.paid)
	return total
