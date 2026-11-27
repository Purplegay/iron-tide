extends Node
## Dedicated automatic and quick slots plus ten manual slots; verified writes + previous backup.
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
const Schema = preload("res://scripts/save/snapshot_schema.gd")
const VERSION := 1
const DIRECTORY := "user://battles"
const SLOTS := [
	"auto", "quick", "slot1", "slot2", "slot3", "slot4", "slot5",
	"slot6", "slot7", "slot8", "slot9", "slot10",
]
const MAX_BYTES := 64 * 1024 * 1024
var pending: Dictionary = {}
var _content_hash := ""
var _field_types: Dictionary = {}
var _pre_auto_harvest_hash := ""

# Preserve the predecessor byte order and every unrelated catalog definition.
func pre_studio_catalog(current:Dictionary) -> Dictionary:
	var previous:=current.duplicate()
	for id in MetaProgress.Academy.Stars.IDS:previous.erase(id)
	previous.erase(MetaProgress.Academy.Stars.STUDIO)
	return previous

func pre_studio_hash(fields:Dictionary) -> String:
	return digest(var_to_bytes([fields,pre_studio_catalog(GameData.unit_index),pre_studio_catalog(GameData.building_index),GameData.ra2_general,GameData.allied_capabilities]))

# Exclude only the additive native Soviet pack from historical fingerprints.
func pre_soviet_catalog(current: Dictionary) -> Dictionary:
	var previous := pre_studio_catalog(current)
	for entry in GameData.raw_docs.get("yr_soviet.json", {}).get("units" if current.has("CMIN") else "buildings", []):
		previous.erase(entry.id)
	return previous

# v0.7's original factories only listed the first Soviet production batch.
func soviet_opening_hash(reinforcements := false, base_defenses := false, advanced := false, air := false, navy := false) -> String:
	var units := pre_studio_catalog(GameData.unit_index)
	var buildings := pre_studio_catalog(GameData.building_index)
	for bid in ["NAHAND","NAWEAP","NAYARD"]:
		buildings[bid] = buildings[bid].duplicate(true)
	for id in ["IVAN","CIVAN","TERROR","DESO","BORIS","DTRUCK","TTNK","SAPC","SQD","DRED","BPLN","DMISL","SPYP"]:
		units.erase(id)
		for bid in ["NAHAND","NAWEAP","NAYARD"]: buildings[bid].builds.erase(id)
	for bid in ["NANRCT","NAINDP","NAMISL","NAIRON"]: buildings.erase(bid)
	if navy: return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))
	units.erase("SUB")
	units.erase("HYD")
	buildings.erase("NAYARD")
	if air:
		return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))
	buildings.NAWEAP = buildings.NAWEAP.duplicate(true)
	buildings.NAHAND = buildings.NAHAND.duplicate(true)
	for id in ["SOV_DOG", "ZEP", "SCHP"]:
		if not units.has(id): continue
		buildings[units[id].built_at].builds.erase(id)
		units.erase(id)
	if advanced:
		return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))
	for id in ["APOC","DRON","V3","V3ROCKET"]:
		buildings.NAWEAP.builds.erase(id)
		units.erase(id)
	buildings.erase("NATECH")
	if base_defenses:
		return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))
	units.erase("SHK")
	for id in ["TESLA","NAFLAK","NABNKR","NAWALL"]: buildings.erase(id)
	buildings.NAHAND = buildings.NAHAND.duplicate(true)
	buildings.NAHAND.builds.erase("SHK")
	if reinforcements:
		return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))
	buildings.erase("NARADR")
	for id in ["NAHAND", "NAWEAP"]:
		buildings[id] = buildings[id].duplicate(true)
	for id in ["SENGINEER", "HTK", "FLAKT"]:
		var factory: String = units[id].built_at
		buildings[factory].builds.erase(id)
		units.erase(id)
	return digest(var_to_bytes([Schema.FIELDS, units, buildings, GameData.ra2_general, GameData.allied_capabilities]))

func pre_soviet_hash() -> String:
	return digest(var_to_bytes([Schema.FIELDS, pre_soviet_catalog(GameData.unit_index), pre_soviet_catalog(GameData.building_index), GameData.ra2_general, GameData.allied_capabilities]))

func pre_auto_harvest_hash() -> String:
	if _pre_auto_harvest_hash.is_empty():
		var fields := pre_allied_fields()
		fields.unit.erase("auto_harvest_enabled")
		fields.unit.erase("auto_harvest_idle")
		_pre_auto_harvest_hash = digest(var_to_bytes([fields, pre_soviet_catalog(GameData.unit_index), pre_soviet_catalog(GameData.building_index), GameData.ra2_general]))
	return _pre_auto_harvest_hash

func pre_allied_fields() -> Dictionary:
	var fields := pre_force_fire_fields()
	fields.unit.erase("special")
	fields.building.erase("special")
	fields.projectile.erase("splinters")
	fields.battle.erase("allied_state")
	return fields

func pre_allied_hash() -> String:
	return digest(var_to_bytes([pre_allied_fields(), pre_soviet_catalog(GameData.unit_index), pre_soviet_catalog(GameData.building_index), GameData.ra2_general]))

func content_hash() -> String:
	if _content_hash.is_empty():
		_content_hash = digest(var_to_bytes([Schema.FIELDS, GameData.unit_index, GameData.building_index, GameData.ra2_general, GameData.allied_capabilities]))
	return _content_hash

func pre_airport_repair_hash(before_studio:=false) -> String:
	# Only the additive repair timer may differ; retain every roster/rule check.
	var fields := Schema.FIELDS.duplicate(true)
	fields.logistics.erase("airport_repair_elapsed")
	if before_studio:return pre_studio_hash(fields)
	return digest(var_to_bytes([fields,GameData.unit_index,GameData.building_index,GameData.ra2_general,GameData.allied_capabilities]))

func pre_whole_load_hash() -> String:
	# Exact predecessor: only CMIN's authored unload timer changed from 4 to 1.
	# Preserve all other schema, roster, prices and rules in the fingerprint.
	var units := pre_soviet_catalog(GameData.unit_index).duplicate(true)
	units["CMIN"]["harvester"]["unload_time"] = 4.0
	return digest(var_to_bytes([Schema.FIELDS, units, pre_soviet_catalog(GameData.building_index), GameData.ra2_general, GameData.allied_capabilities]))

func pre_force_fire_fields() -> Dictionary:
	var fields := Schema.FIELDS.duplicate(true)
	fields.erase("force_fire_point")
	return fields

func pre_force_fire_hash() -> String:
	# Only the new reference type is absent. All previous fields and game data
	# must still match; this does not bypass rule/content compatibility checks.
	return digest(var_to_bytes([pre_force_fire_fields(), pre_soviet_catalog(GameData.unit_index), pre_soviet_catalog(GameData.building_index), GameData.ra2_general, GameData.allied_capabilities]))

func pre_fortress_hashes() -> Dictionary:
	# Additive roster migration only. Existing units, buildings, rules and schema
	# must still match byte-for-byte; never bypass compatibility for other changes.
	var units := pre_soviet_catalog(GameData.unit_index).duplicate(true)
	units.erase("BFRT")
	var old_fields := pre_allied_fields()
	var result := {
		"current": digest(var_to_bytes([Schema.FIELDS, units, pre_soviet_catalog(GameData.building_index), GameData.ra2_general, GameData.allied_capabilities])),
		"before_force_fire": digest(var_to_bytes([pre_force_fire_fields(), units, pre_soviet_catalog(GameData.building_index), GameData.ra2_general, GameData.allied_capabilities])),
		"allied": digest(var_to_bytes([old_fields, units, pre_soviet_catalog(GameData.building_index), GameData.ra2_general]))}
	old_fields.unit.erase("auto_harvest_enabled")
	old_fields.unit.erase("auto_harvest_idle")
	result.harvest = digest(var_to_bytes([old_fields, units, pre_soviet_catalog(GameData.building_index), GameData.ra2_general]))
	return result

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func slot_path(slot: String) -> String:
	return DIRECTORY.path_join(slot + ".itsave") if slot in SLOTS else ""

func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func save_slot(world, slot: String) -> Dictionary:
	if preload("res://scripts/expedition/rules.gd").active():return fail("远征使用独立存档，请点击「保存远征并返回」；战斗中每 30 秒自动保存")
	if slot_path(slot).is_empty(): return fail("无效存档槽位")
	if not is_instance_valid(world) or world.ended: return fail("对局已结束，不能保存")
	var codec := Snapshot.new()
	var snapshot := codec.capture(world)
	if not codec.error.is_empty(): return fail("保存失败：" + codec.error)
	var issue := validate(snapshot)
	if not issue.is_empty(): return fail("保存失败：" + issue)
	var bytes := var_to_bytes(snapshot)
	var envelope := {"version": VERSION, "content": content_hash(), "hash": digest(bytes), "payload": bytes,
		"title": str(world.mission.get("name", "对局")), "mode": BattleRequest.rules_mode,
		"time": Time.get_datetime_string_from_system(false, true), "funds": world.funds,
		"units": world.units.filter(func(u): return world.actor_alive(u)).size()}
	var serialized := pack_file(envelope)
	if serialized.size() > MAX_BYTES: return fail("存档过大，未覆盖原文件")
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK: return fail("无法创建存档目录")
	var path := slot_path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return fail("无法写入存档，请检查磁盘空间")
	file.store_buffer(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(temporary) != serialized: return fail("存档写入校验失败，原文件未变")
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if read_path(path).ok:
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK: return fail("无法更新存档备份")
			if DirAccess.rename_absolute(path, backup) != OK: return fail("无法替换旧存档")
		elif DirAccess.remove_absolute(path) != OK:
			return fail("无法替换损坏的存档")
	if DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, path)
		return fail("保存失败，已保留旧存档")
	return {"ok": true, "message": "已保存：" + label(slot), "path": path, "info": {"time":envelope.time,"mode":envelope.mode,"title":envelope.title,"funds":envelope.funds}}

func label(slot: String) -> String:
	if slot == "auto": return "自动存档"
	return "快速存档" if slot == "quick" else "手动存档 " + slot.trim_prefix("slot")

func read_slot(slot: String) -> Dictionary:
	var path := slot_path(slot)
	if path.is_empty(): return fail("无效存档槽位")
	var result := read_path(path)
	if not result.ok and FileAccess.file_exists(path + ".bak"):
		var backup := read_path(path + ".bak")
		if backup.ok:
			backup.info.title += "（上一份备份）"
			backup["from_backup"] = true
			return backup
	return result

func pack_file(envelope: Dictionary) -> PackedByteArray:
	var body := var_to_bytes(envelope)
	var bytes := "ITSAVE01".to_utf8_buffer()
	bytes.resize(16)
	bytes.encode_u64(8, body.size())
	bytes.append_array(digest(body).hex_decode())
	bytes.append_array(body)
	return bytes

func read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return fail("空存档")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return fail("存档无法读取或体积异常")
	var encoded := file.get_buffer(file.get_length())
	# Check length and outer checksum before invoking Variant's decoder, including truncation.
	if encoded.size() < 48 or encoded.slice(0, 8).get_string_from_utf8() != "ITSAVE01" or encoded.decode_u64(8) != encoded.size() - 48:
		return fail("存档已损坏或不完整")
	var body := encoded.slice(48)
	if digest(body).hex_decode() != encoded.slice(16, 48): return fail("存档文件校验失败")
	encoded = body
	if not encoded.has_encoded_var(0, false): return fail("存档已损坏或不完整")
	var envelope = bytes_to_var(encoded)
	if not envelope is Dictionary: return fail("存档已损坏")
	if envelope.get("version") != VERSION: return fail("存档版本或规则数据不兼容")
	var legacy := false
	var pre_allied := false
	var fingerprint= envelope.get("content")
	var current_schema:bool=fingerprint==content_hash() or fingerprint==pre_studio_hash(Schema.FIELDS)
	var pre_airport:bool=not current_schema and (fingerprint==pre_airport_repair_hash() or fingerprint==pre_airport_repair_hash(true))
	if not current_schema and not pre_airport:
		var before_fortress := pre_fortress_hashes()
		legacy = envelope.get("content") in [pre_auto_harvest_hash(), before_fortress.harvest]
		pre_allied = envelope.get("content") in [pre_allied_hash(), before_fortress.allied] or legacy
		if envelope.get("content") not in [soviet_opening_hash(true, true, true, true, true), soviet_opening_hash(true, true, true, true), soviet_opening_hash(true, true, true), soviet_opening_hash(true, true), soviet_opening_hash(true), soviet_opening_hash(), pre_soviet_hash(), pre_whole_load_hash(), pre_force_fire_hash(), before_fortress.current, before_fortress.before_force_fire] and not pre_allied:
			return fail("存档版本或规则数据不兼容")
	var bytes = envelope.get("payload")
	if not bytes is PackedByteArray or envelope.get("hash") != digest(bytes): return fail("存档校验失败，文件可能损坏")
	if not bytes.has_encoded_var(0, false): return fail("战场数据已损坏")
	var snapshot = bytes_to_var(bytes)
	if pre_airport and snapshot is Dictionary and snapshot.get("records") is Array:
		for record in snapshot.records:
			if record is Dictionary and record.get("kind") == "logistics" and record.get("fields") is Dictionary and not record.fields.has("airport_repair_elapsed"):
				record.fields["airport_repair_elapsed"] = 0.0
	if pre_allied and snapshot is Dictionary and snapshot.get("records") is Array:
		for record in snapshot.records:
			if not record is Dictionary or not record.get("fields") is Dictionary: continue
			if record.get("kind") in ["unit", "building"]: record.fields["special"] = {"@dict": []}
			if record.get("kind") == "projectile": record.fields["splinters"] = {"@dict": []}
			if record.get("kind") == "battle": record.fields["allied_state"] = {"@dict": []}
	if legacy and snapshot is Dictionary and snapshot.get("records") is Array:
		for record in snapshot.records:
			if record is Dictionary and record.get("kind") == "unit" and record.get("fields") is Dictionary:
				record.fields["auto_harvest_enabled"] = true
				record.fields["auto_harvest_idle"] = 0.0
	var issue := validate(snapshot)
	if not issue.is_empty(): return fail("存档无效：" + issue)
	return {"ok": true, "snapshot": snapshot, "info": envelope}

func validate(snapshot) -> String:
	if not snapshot is Dictionary or not snapshot.get("records") is Array or not snapshot.get("context") is Dictionary: return "缺少战场数据"
	# Additive manifest: older saves have no special mechanics fingerprint.
	# New saves must match their rules, even when the main roster is unchanged.
	if snapshot.has("special_rules") and snapshot.special_rules != digest(var_to_bytes(preload("res://scripts/world/special_rules.gd").data())): return "特殊机制规则版本不一致"
	if snapshot.has("death_rules") and snapshot.death_rules != digest(var_to_bytes(preload("res://scripts/core/yr_death_rules.gd").data())): return "死亡与逃生规则版本不一致"
	var records: Array = snapshot.records
	if records.is_empty() or records.size() > 100000: return "实体数量异常"
	var context: Dictionary = snapshot.context
	for key in ["mission_id", "skirmish", "config", "mode", "combat_context", "camera", "zoom", "iso", "collapsed", "gm", "rally", "firing"]:
		if not context.has(key): return "缺少对局设置：" + key
	if context.mode not in [MatchRules.RA2, MatchRules.EXTENDED] or not context.config is Dictionary or not context.combat_context is Dictionary: return "对局模式无效"
	var native=preload("res://scripts/world/native_maps.gd")
	var native_id:=str(context.config.get("map_layout",""))
	if not context.skirmish and context.mission_id == "yr_hollywood": native_id="yr_all02umd"
	if not context.skirmish and context.mission_id == "yr_head_games": native_id="yr_sov07"
	if not context.skirmish and context.mission_id=="yr_time_shift":native_id="yr_sov01"
	if not context.skirmish and context.mission_id=="yr_allied_finale":native_id="yr_all07smd"
	if not context.skirmish and context.mission_id=="yr_allied_first":native_id="yr_all01umd"
	var native_sites:Dictionary=native.data(native_id).get("site_types",{}) if native.has(native_id) else {}
	if context.has("native_map_sha") and (not native.has(native_id) or context.native_map_sha!=FileAccess.get_sha256("res://data/maps/%s.json"%native_id)):
		return "原版地图导入数据已变化，无法按旧地形恢复"
	if not context.camera is Vector2 or not context.camera.is_finite() or not context.zoom is float or context.zoom <= 0.0 or context.zoom > 20.0: return "镜头数据无效"
	if not context.iso is Array or context.iso.size() != 3 or not context.iso[0] is float or context.iso[0] <= 0.0 or context.iso[0] > 2.0: return "视角数据无效"
	if not context.gm is Dictionary or not context.rally is Array or not context.firing is Array: return "辅助状态无效"
	if context.has("fog_buildings") and not preload("res://scripts/world/fog_building_memory.gd").valid(context.fog_buildings): return "建筑侦察记录无效"
	if not context.skirmish is bool or not context.mission_id is String or not context.collapsed is bool or not context.iso[1] is bool or not context.iso[2] is bool: return "设置类型无效"
	if not context.combat_context.get("bonuses") is Dictionary or not context.combat_context.get("unit_bonus") is Dictionary or not context.combat_context.get("loadouts") is Dictionary: return "缺少对局加成"
	for key in context.gm:
		if key not in Schema.GM_FIELDS or not context.gm[key] is bool: return "调试开关无效"
	var house_ids := ["ally","enemy"]
	var rows = context.config.get("houses",[])
	if not rows is Array: return "参战方无效"
	if not rows.is_empty():
		if not BattleRequest.Houses.valid(rows,native_id,context.mode == MatchRules.RA2): return "结盟组或出生点无效"
		for i in range(2,rows.size()): house_ids.append(BattleRequest.Houses.id(i))
	const Fog=preload("res://scripts/world/fog_of_war.gd")
	var max_sight_seconds:=Fog.EXPEDITION_INTEL_SIGHT_SECONDS if context.combat_context.has("expedition") else Fog.MAX_HELD_SIGHT_SECONDS
	var fog_count := 0
	var ai_count := 0
	for index in records.size():
		var record = records[index]
		if not record is Dictionary or not Schema.PATHS.has(record.get("kind", "")) or not record.get("fields") is Dictionary: return "实体格式无效"
		var kind: String = record.kind
		if (index == 0) != (kind == "battle"): return "战场根节点无效"
		if kind == "fog":
			fog_count += 1
			if context.has("death_sight"):
				var held = context.death_sight
				var width = record.fields.get("width", 0)
				if not held is Dictionary or not width is int: return "迷雾视野无效"
				if held.size() != house_ids.size(): return "迷雾阵营无效"
				for side in house_ids:
					if not held.get(side) is Dictionary: return "迷雾阵营无效"
					for cell_index in held[side]:
						var seconds = held[side][cell_index]
						if not cell_index is int or cell_index < 0 or cell_index >= width * width: return "迷雾位置无效"
						if not seconds is float or not is_finite(seconds) or seconds <= 0.0 or seconds > max_sight_seconds + 0.000001: return "迷雾时间无效"
		if kind == "ai": ai_count += 1
		if record.fields.size() != Schema.fields(kind).size(): return "实体字段版本不匹配：" + kind
		for field in Schema.fields(kind):
			if not record.fields.has(field) or not valid_value(record.fields[field], records.size(), 0): return "实体字段无效：" + field
			if not field_type_matches(kind, field, record.fields[field]): return "字段类型不兼容：" + field
		if kind in ["battle", "unit", "building", "ore", "obstacle", "projectile", "fog"]:
			if not record.get("position") is Vector2 or not record.position.is_finite() or not record.get("groups") is Array or not record.get("visible") is bool: return "实体位置无效"
		if kind in ["unit", "building"]:
			var id = record.fields.get("unit_id" if kind == "unit" else "building_id")
			var civilian: bool = kind == "building" and (id in ["CAHSE01", "CABHUT", "CAOILD"] or ((context.skirmish or context.mission_id in ["yr_hollywood","yr_head_games","yr_time_shift","yr_allied_finale","yr_allied_first"]) and native_sites.has(id)))
			var hollywood_fence:bool=kind=="building" and not context.skirmish and context.mission_id in ["yr_hollywood","yr_allied_first"] and id in ["CAFNCP","CAFNCB","CAFNCW"] and record.fields.side=="neutral"
			# Expedition rescue/escort NPCs are neutral units and must survive checkpoints.
			var neutral_actor: bool = record.fields.side == "neutral"
			if record.fields.side not in house_ids and not neutral_actor and not (civilian and record.fields.side == "neutral"): return "单位或阵营不兼容"
			if not civilian and not hollywood_fence and ((kind == "unit" and GameData.get_unit(str(id)).is_empty() and not ((context.mission_id=="yr_time_shift" or (context.mission_id=="yr_allied_first" and id in GameData.ALL01_SHARED_UNITS)) and preload("res://data/time_shift_assets.json").data.units.has(id))) or (kind == "building" and not GameData.building_index.has(id) and not (context.mission_id=="yr_time_shift" and (preload("res://data/time_shift_assets.json").data.defs.has(id) or GameData.hollywood_yuri.buildings.has(id))) and not (context.mission_id == "yr_allied_first" and id == "YAPPPT") and not ((context.mission_id == "yr_hollywood" and GameData.hollywood_yuri.buildings.has(id) or context.mission_id == "yr_head_games" and GameData.hollywood_yuri.buildings.has(id))))): return "单位或阵营不兼容"
			if not record.fields.data is Dictionary or not record.fields.data.has("@dict"): return "缺少实体定义"
		if kind in ["unit", "building", "obstacle"]:
			if not record.get("collision") is Array or record.collision.size() != 2: return "缺少碰撞状态"
	var skirmish: bool = context.skirmish == true
	var hollywood: bool = not skirmish and context.mission_id == "yr_hollywood"
	var expects_fog: bool = hollywood or context.mission_id in ["yr_head_games","yr_time_shift","yr_allied_finale","yr_allied_first"] or (skirmish and context.config.get("fog_of_war", false))
	# Earlier Hollywood snapshots contain neither the fog record nor its sight timers.
	var legacy_clear_map: bool = fog_count == 0 and (hollywood and not context.has("death_sight") or context.mission_id=="yr_head_games")
	if ai_count != (1 if skirmish and house_ids.size() == 2 else 0) or (not legacy_clear_map and fog_count != int(expects_fog)): return "地图状态不匹配"
	for pair in context.rally:
		if not pair is Array or pair.size() != 2 or not pair[0] is int or pair[0] < 1 or pair[0] >= records.size() or records[pair[0]].kind != "building" or not pair[1] is Vector2: return "集结点引用无效"
	for pair in context.firing:
		if not pair is Array or pair.size() != 2 or not pair[0] is int or pair[0] < -1 or pair[0] >= records.size() or not pair[1] is Dictionary: return "开火视野数据无效"
		if pair[1].get("side") not in house_ids or not pair[1].get("position") is Vector2 or not pair[1].get("remaining") is float: return "开火视野状态无效"
	return ""

func field_type_matches(kind: String, field: String, value) -> bool:
	if not _field_types.has(kind):
		var types := {}
		for property in load(Schema.PATHS[kind]).get_script_property_list(): types[property.name] = property.type
		_field_types[kind] = types
	var type: int = _field_types[kind].get(field, TYPE_NIL)
	if type == TYPE_NIL: return true # Deliberately untyped actor references/flow state.
	if type == TYPE_OBJECT: return value == null or (value is Dictionary and (value.has("@ref") or value.has("@weak") or value.has("@rng")))
	if type == TYPE_DICTIONARY: return value is Dictionary and value.has("@dict")
	return typeof(value) == type

func valid_value(value, count: int, depth: int) -> bool:
	if depth > 40: return false
	if value is Object or value is Callable or value is Signal: return false
	if value is Array:
		for item in value:
			if not valid_value(item, count, depth + 1): return false
	elif value is Dictionary:
		if value.size() != 1: return false
		if value.has("@ref"): return value["@ref"] is int and value["@ref"] >= 0 and value["@ref"] < count
		if value.has("@weak"): return value["@weak"] == null or (value["@weak"] is Dictionary and value["@weak"].has("@ref") and valid_value(value["@weak"], count, depth + 1))
		if value.has("@rng"): return value["@rng"] is Array and value["@rng"].size() == 2 and value["@rng"][0] is int and value["@rng"][1] is int
		if not value.get("@dict") is Array: return false
		for pair in value["@dict"]:
			if not pair is Array or pair.size() != 2 or not valid_value(pair, count, depth + 1): return false
	return true

func prepare_load(slot: String) -> Dictionary:
	var result := read_slot(slot)
	if not result.ok: return result
	pending = result.snapshot
	var context: Dictionary = pending.context
	BattleRequest.mission_id = context.mission_id
	BattleRequest.skirmish = context.skirmish
	BattleRequest.skirmish_config = context.config.duplicate(true)
	BattleRequest.rules_mode = context.mode
	BattleRequest.combat_context = context.combat_context.duplicate(true)
	for key in context.gm: GM.set(key, context.gm[key])
	return {"ok": true, "message": "正在读取存档"}

func load_into_scene(slot: String) -> Dictionary:
	# Validate fully before leaving the live battle. No defeat/reward is triggered.
	var result := prepare_load(slot)
	if not result.ok: return result
	get_tree().paused = false
	BattleClock.leave_battle()
	var err := get_tree().change_scene_to_file("res://scenes/battle.tscn")
	if err != OK:
		pending = {}
		return fail("无法打开战场场景")
	return result

func restore_pending(world) -> void:
	if pending.is_empty(): return
	Snapshot.new().restore(world, pending)
	pending = {}
