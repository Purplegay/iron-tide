extends RefCounted
## Local numeric overrides. Gameplay definitions retain identity; saves never touch packaged data.
const STORE:="user://progression_tuning.json"
const Fields=preload("res://scripts/admin/progression_tuning_fields.gd")
var records:Dictionary={}
var patches:Dictionary={}
var loaded:=false
var warning:=""

func install(data) -> void:
	records.clear()
	for card:Dictionary in data.skills:
		register("skill/"+str(card.id),card,"技能",str(card.get("allowed_units",[])))
	for unit:String in data.meta_config.get("unit_talents",{}):
		for id:String in data.meta_config.unit_talents[unit]:
			register("talent/"+unit+"/"+id,data.meta_config.unit_talents[unit][id],"天赋",unit)
	var parameters=preload("res://scripts/rules/progression_parameters.gd")
	parameters.reset()
	for key:String in parameters.groups():
		var row:Dictionary=parameters.groups()[key]
		register(key,row,row.kind,row.unit)
		records[key].base=parameters.original(key)
	if not loaded:
		loaded=true
		if FileAccess.file_exists(STORE):
			var parsed=JSON.parse_string(FileAccess.get_file_as_string(STORE))
			if parsed is Dictionary and parsed.get("version")==1 and parsed.get("patches") is Dictionary:patches=parsed.patches
			else:warning="本机调参文件格式错误，已使用原值；保存前请检查备份。"
	var valid:Dictionary={}
	for key in patches:
		var error:=validate(str(key),patches[key])
		if error.is_empty():
			valid[key]=patches[key];write_values(key,patches[key])
		else:warning="部分旧调参不再适用，已跳过："+error
	patches=valid

func register(key:String,definition:Dictionary,kind:String,unit:String) -> void:
	records[key]={"key":key,"name":definition.get("name",key),"kind":kind,"unit":unit,"live":definition,"base":definition.duplicate(true)}

func fields(key:String) -> Array:
	return Fields.collect(records[key].base) if records.has(key) else []

func values(key:String) -> Dictionary:
	var result:Dictionary={}
	for field:Dictionary in fields(key):result[field.path]=Fields.read(records[key].live,field.path)
	return result

func validate(key:String,edits:Variant) -> String:
	if not records.has(key) or not edits is Dictionary:return "未知项目或数值格式错误："+key
	var known:Dictionary={}
	for field:Dictionary in fields(key):known[field.path]=field
	for path in edits:
		if not known.has(path):return "不可编辑的参数："+str(path)
		var value=edits[path]
		if not (value is float or value is int) or not is_finite(float(value)):return "请输入有限数值："+str(path)
		var field:Dictionary=known[path]
		if value<field.minimum or value>field.maximum:return "超出允许范围："+str(path)
		if field.integer and not is_equal_approx(float(value),roundf(value)):return "次数必须为整数："+str(path)
	return ""

func write_values(key:String,edits:Dictionary) -> void:
	var record:Dictionary=records[key]
	for field:Dictionary in fields(key):Fields.write(record.live,field.path,edits.get(field.path,field.value))
	if record.kind=="天赋":sync_talent_display(record)
	if record.kind=="技能":
		if record.live.get("expansion",false):record.live.desc=preload("res://scripts/rules/expansion_catalog.gd").description(record.live,0)
		elif record.live.has("rank_text"):record.live.desc=preload("res://scripts/rules/academy.gd").skill_description(record.live,0)

func sync_talent_display(record:Dictionary) -> void:
	var base:Dictionary=record.base
	if not base.has("values") or not base.has("base") or base.get("ranks",[]).size()!=3:return
	var labels:Array=[base.base]
	for rank:Dictionary in base.ranks:labels.append(rank.get("value",0))
	for key:String in base.values:
		var original:Array=base.values[key]
		if original.size()!=4:continue
		for scale in [1.0,100.0]:
			var matches:=true
			for i in 4:matches=matches and is_equal_approx(float(original[i])*scale,float(labels[i]))
			if not matches:continue
			record.live.base=float(record.live.values[key][0])*scale
			for i in 3:record.live.ranks[i].value=float(record.live.values[key][i+1])*scale
			return

func apply(key:String,edits:Dictionary) -> String:
	var error:=validate(key,edits)
	if not error.is_empty():return error
	var delta:Dictionary={}
	for field:Dictionary in fields(key):
		var value:float=edits.get(field.path,field.value)
		if value!=float(field.value):delta[field.path]=value
	write_values(key,delta)
	if delta.is_empty():patches.erase(key)
	else:patches[key]=delta
	refresh_units(key)
	Events.meta_changed.emit()
	return ""

func save() -> String:
	var file:=FileAccess.open(STORE+".tmp",FileAccess.WRITE)
	if file==null:return "保存失败：无法写入本机调参文件"
	file.store_string(JSON.stringify({"version":1,"patches":patches},"  "));file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:return "保存失败：写入未完成"
	var path:=ProjectSettings.globalize_path(STORE)
	if FileAccess.file_exists(STORE) and DirAccess.copy_absolute(path,path+".bak")!=OK:return "保存失败：无法备份原文件"
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "保存失败：无法替换原文件"
	return ""

func refresh_units(key:String) -> void:
	if not GM.has_battle_tools():return
	var world=GM._hooks.unit_tools.get_object()
	if not is_instance_valid(world) or not "units" in world:return
	var record:Dictionary=records[key]
	if record.kind!="技能":return # Talent consumers read GameData on use; spawn-time traits apply to new units.
	var definition:Dictionary=record.live
	for unit in world.units:
		if not is_instance_valid(unit) or unit.hp<=0:continue
		var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get(definition.id,0) if unit.side=="ally" else 0
		for ability in unit.skills:
			if ability.id!=definition.id:continue
			ability.setup(definition,rank) # Keeps cd_left / active_left and the original Ability object.
			if unit.side=="ally":
				if ability.effect_has("stun"):ability.duration*=BattleRequest.card_scale(ability.id)
				else:ability.value*=BattleRequest.card_scale(ability.id)
		if unit.passive.get("id")==definition.id:
			var attack:float=unit.bonuses.attack_bonus;var defense:float=unit.bonuses.defense_bonus;var speed:float=unit.move_speed
			unit._apply_passive(true)
			unit.passive=definition.duplicate(true)
			if unit.side=="ally":unit.passive.value=float(definition.get("value",0))*BattleRequest.card_scale(definition.id)
			unit._apply_passive()
			unit._base_atk*=float(unit.bonuses.attack_bonus)/maxf(.0001,attack)
			unit._base_def*=float(unit.bonuses.defense_bonus)/maxf(.0001,defense)
			unit._base_speed*=unit.move_speed/maxf(.0001,speed)
		unit.queue_redraw()
