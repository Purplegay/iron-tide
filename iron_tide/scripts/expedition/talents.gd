extends RefCounted

static func options(id:String) -> Dictionary:
	return MetaProgress.talent_options(id)

static func freeze(context:Dictionary) -> void:
	freeze_unlocks(context)
	var rows:Dictionary={}
	for id:String in GameData.meta_config.get("unit_talents",{}):
		if not GameData.unit_index.has(id):continue
		var ranks:Dictionary={}
		for key:String in options(id):ranks[key]=MetaProgress.talent_rank(id,key,MetaProgress.unit_talents) if key in MetaProgress.selected_talents(id,MetaProgress.unit_talents) else 0
		rows[id]=ranks
	context.unit_talents=rows

static func freeze_unlocks(context:Dictionary) -> void:
	if context.has("expedition_unlocked_talents"):return
	var unlocked:Dictionary={}
	for id:String in MetaProgress.unit_talents:
		unlocked[id]=MetaProgress.selected_talents(id,MetaProgress.unit_talents).duplicate()
	context.expedition_unlocked_talents=unlocked

static func all_unlocked(run:Dictionary,id:String) -> bool:
	var choices:=options(id)
	if choices.is_empty():return false
	var unlocked:Array=run.get("frozen",{}).get("expedition_unlocked_talents",{}).get(id,[])
	for key:String in choices:
		if key not in unlocked and rank(run,id,key)<=0:return false
	return true

static func rank(run:Dictionary,id:String,key:String) -> int:
	var outside:int=run.get("frozen",{}).get("unit_talents",{}).get(id,{}).get(key,0)
	var floor_rank:int=run.get("native_talents",{}).get(id,0)
	return maxi(outside,maxi(floor_rank,int(run.get("native_levels",{}).get(id,{}).get(key,0))))

static func minimum(run:Dictionary,id:String) -> int:
	if options(id).is_empty():return -1
	var level:=3
	for key:String in options(id):level=mini(level,rank(run,id,key))
	return level

static func targets(run:Dictionary,id:String) -> Dictionary:
	var result:Dictionary={}
	for key:String in options(id):result[key]=mini(3,rank(run,id,key)+1)
	return result

static func can_gain(run:Dictionary,item:Dictionary) -> bool:
	for key:String in options(item.id):
		if int(item.get("talent_targets",{}).get(key,item.get("rank",0)))>rank(run,item.id,key):return true
	return false

static func grant(run:Dictionary,item:Dictionary) -> void:
	var levels:Dictionary=run.get_or_add("native_levels",{}).get_or_add(item.id,{})
	for key:String in options(item.id):levels[key]=maxi(rank(run,item.id,key),mini(3,int(item.get("talent_targets",{}).get(key,item.get("rank",0)))))

static func apply(run:Dictionary,context:Dictionary) -> void:
	var rows:Dictionary=context.get_or_add("unit_talents",{})
	for id:String in GameData.meta_config.get("unit_talents",{}):
		if not GameData.unit_index.has(id):continue
		var ranks:Dictionary={}
		for key:String in options(id):ranks[key]=rank(run,id,key)
		rows[id]=ranks

static func summary(run:Dictionary,id:String) -> String:
	var lines:=PackedStringArray()
	for key:String in options(id):lines.append("%s %d / 3 级"%[options(id)[key].get("name",key),rank(run,id,key)])
	return "全部天赋：\n"+"\n".join(lines) if not lines.is_empty() else "该兵种没有可升级天赋"

static func valid(run:Dictionary) -> bool:
	var rows:Variant=run.get("native_levels",{})
	if not rows is Dictionary:return false
	for id in rows:
		if not rows[id] is Dictionary:return false
		for key in rows[id]:
			if not options(id).has(key) or not rows[id][key] is int or rows[id][key]<0 or rows[id][key]>3:return false
	return true
