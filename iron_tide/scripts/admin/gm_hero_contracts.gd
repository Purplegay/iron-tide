extends RefCounted
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")
const Academy=preload("res://scripts/rules/academy.gd")

static func complete(meta) -> Dictionary:
	var entries:=Pool.entries()
	if entries.is_empty(): return {"ok":false,"error":"当前未配置英雄契约。"}
	# Validate the entire configured batch before modifying progression.
	for row in entries:
		if row.hero_id!="E2" and not Contracts.GOALS.has(row.hero_id):
			return {"ok":false,"error":"英雄契约 %s 缺少任务目标配置。"%row.name}
		for card in row.cards:
			if GameData.get_skill(card).is_empty(): return {"ok":false,"error":"英雄契约奖励 %s 不存在。"%card}
	var previous:Dictionary=meta.academy.duplicate(true)
	var funds:Dictionary=meta.currency.duplicate(true)
	var skills:Array=meta.unlocked_skills.duplicate()
	var added:=0
	for row in entries:
		Pool.grant(meta,str(row.id))
		if row.hero_id=="E2":
			var tasks:Dictionary=meta.academy.get_or_add("furnace_tasks",{})
			tasks.takedown=true
			tasks.damage=maxf(10000.0,float(tasks.get("damage",0)))
			tasks.peace=true
			meta.academy.furnace_complete=true
		else:
			var tasks:Dictionary=meta.academy.hero_contracts[row.hero_id]
			tasks.first=maxf(float(tasks.get("first",0)),Contracts.GOALS[row.hero_id][0])
			tasks.second=maxf(float(tasks.get("second",0)),Contracts.GOALS[row.hero_id][1])
			tasks.win=true
			tasks.complete=true
		for card in row.cards:
			if not meta.unlocked_skills.has(card):
				meta.unlocked_skills.append(card)
				added+=1
	if not Academy.commit(meta,previous,funds,skills):
		return {"ok":false,"error":"英雄契约完成失败，存档未写入，已恢复原进度。"}
	return {"ok":true,"contracts":entries.size(),"rewards":Pool.reward_count(),"added":added}
