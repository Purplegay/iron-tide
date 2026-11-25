extends RefCounted
static func compatible(id: String, skill: String, hero := false) -> bool:
	if skill.is_empty():return true
	if GameData.get_skill(skill).get("hero_only", false) and not hero: return false
	return preload("res://scripts/rules/skill_scope.gd").compatible(id,GameData.get_skill(skill))

static func equippable(id: String, skill: String, hero := false) -> bool:
	return skill.is_empty() or (compatible(id, skill, hero) and skill != UnitSkillLayout.primary_id(id) and skill != "ap_deploy" and GameData.get_skill(skill).get("type", "") == "active")

