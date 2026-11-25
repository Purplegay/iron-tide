extends RefCounted
## Shared numeric authority for code-defined progression effects; no profile ownership state.
static var catalog:Dictionary={}
static var defaults:Dictionary={}

static func groups() -> Dictionary:
	if catalog.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression_parameters.json"))
		assert(parsed is Dictionary,"Missing progression parameter catalog")
		catalog=parsed
		defaults=parsed.duplicate(true)
	return catalog

static func original(group:String) -> Dictionary:
	groups()
	return defaults[group].duplicate(true)

static func reset() -> void:
	groups()
	for key:String in catalog:
		catalog[key].values=defaults[key].values.duplicate(true)

static func changed(group:String) -> String:
	var row:Dictionary=groups()[group]
	var lines:=PackedStringArray()
	for key:String in row.values:
		if float(row.values[key])!=float(defaults[group].values[key]):
			lines.append("%s：%s" % [row.parameter_fields[key].label,str(row.values[key])])
	return "；".join(lines)

static func related(id:String) -> Array[String]:
	var result:Array[String]=[]
	for key:String in groups():
		if id in catalog[key].get("related",[]) or (id.begins_with("native_") and key=="mechanic/native_training"):result.append(key)
	return result

static func describe(id:String,text:String) -> String:
	var changes:=PackedStringArray()
	for key:String in related(id):
		var value:=changed(key)
		if not value.is_empty():changes.append(value)
	if changes.is_empty():return text
	return "GM 当前调整（优先于原说明数值）：\n"+"\n".join(changes)+"\n原机制说明：\n"+text

static func traits(group:String,base:Array) -> Array:
	var edits:=changed(group)
	if edits.is_empty():return base
	var result:=base.duplicate()
	# The baseline explains unlock conditions; current field names carry their own level.
	result[0]="GM 当前调整（以下原说明的对应数值以此为准）："+edits+"\n原机制："+str(result[0])
	return result

static func number(group:String,key:String) -> float:
	return float(groups()[group].values[key])

static func count(group:String,key:String) -> int:
	return int(groups()[group].values[key])

static func summary(group:String) -> String:
	var row:Dictionary=groups()[group]
	var lines:=PackedStringArray()
	for key:String in row.values:
		lines.append("%s：%s" % [row.parameter_fields[key].label,str(row.values[key])])
	return "\n".join(lines)
