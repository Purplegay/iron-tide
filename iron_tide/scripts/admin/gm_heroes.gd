extends RefCounted
const Academy=preload("res://scripts/rules/academy.gd")

static func unlock_all(meta) -> Dictionary:
	var previous:Dictionary=meta.academy.duplicate(true)
	var funds:Dictionary=meta.currency.duplicate(true)
	var cards:Array=meta.unlocked_skills.duplicate()
	var builds:Dictionary=meta.academy.get_or_add("hero_builds",{})
	var added:=0
	for id:String in Academy.HEROES:
		var requirement:=Academy.hero_requirement(id)
		var count:=int(builds.get(id,0))
		if count<requirement:
			builds[id]=requirement
			added+=1
	if not Academy.commit(meta,previous,funds,cards):
		return {"ok":false,"error":"英雄解锁失败，存档未写入，已恢复原进度。"}
	return {"ok":true,"total":Academy.HEROES.size(),"added":added}
