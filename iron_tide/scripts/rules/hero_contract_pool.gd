extends RefCounted

static func rules() -> Dictionary:
	return GameData.skill_draw_rules().get("hero_contracts",{})

static func entries() -> Array:
	return rules().get("entries",[])

static func entry(id:String) -> Dictionary:
	for row in entries():
		if row.id==id:return row
	return {}

static func for_hero(id:String) -> Dictionary:
	for row in entries():
		if row.hero_id==id:return row
	return {}

static func chance() -> float:
	return clampf(float(rules().get("chance",0)),0,1)

static func cost() -> int:
	return int(rules().get("exchange_cost",500))

static func owned(meta,row:Dictionary) -> bool:
	if row.hero_id=="E2":return bool(meta.academy.get("furnace_contract",false))
	return meta.academy.get("hero_contracts",{}).has(row.hero_id)

static func candidates(meta) -> Array:
	var result:Array=[]
	for row in entries():
		if not owned(meta,row):result.append(row)
	return result

static func owned_count(meta) -> int:
	return entries().size()-candidates(meta).size()

static func reward_count() -> int:
	var ids:Array=[]
	for row in entries():
		for id in row.cards:
			if not ids.has(id):ids.append(id)
	return ids.size()

static func grant(meta,id:String) -> bool:
	var row:=entry(id)
	if row.is_empty() or owned(meta,row):return false
	if row.hero_id=="E2":meta.academy.furnace_contract=true
	else:meta.academy.get_or_add("hero_contracts",{})[row.hero_id]={"first":0.0,"second":0.0,"win":false,"complete":false}
	return true

static func draw(meta) -> String:
	var available:=candidates(meta)
	if available.is_empty() or randf()>=chance():return ""
	var selected:Dictionary=available.pick_random()
	if not grant(meta,str(selected.id)):return ""
	return str(selected.id)

static func purchase(meta,id:String) -> bool:
	var before:Dictionary=meta.academy.duplicate(true)
	if int(meta.academy.get("card_shards",0))<cost() or not grant(meta,id):return false
	meta.academy.card_shards=int(meta.academy.get("card_shards",0))-cost()
	return meta.Academy.commit(meta,before,meta.currency.duplicate(true),meta.unlocked_skills.duplicate())

static func summary(meta) -> String:
	var count:=candidates(meta).size()
	var text:="英雄契约：有未获得契约时，每抽总概率 %s%%，命中后等概率选取；已获得不再参与。"%String.num(chance()*100,2)
	if count>0:text+="当前 %d 个待获得，每个约 %s%%。"%[count,String.num(chance()*100/count,4)]
	else:text+="已全部获得，后续仅抽取常规卡。"
	return text

static func description(meta,id:String) -> String:
	var row:=entry(id)
	if row.is_empty():return ""
	var text:="%s：%s；也可用 %d 兑换碎片开启。"%[row.name,"已获得，不再参与抽取" if owned(meta,row) else "参与英雄契约共享 %s%% 抽取"%String.num(chance()*100,2),cost()]
	if not owned(meta,row):text+="当前单个概率约 %s%%。"%String.num(chance()*100/maxi(1,candidates(meta).size()),4)
	return text
