extends RefCounted
## New content stays marked until actually acquired, never until merely viewed.
const MARK:="新！ "

static func card(id:String) -> bool:
	var definition:=GameData.get_skill(id)
	return definition.get("expansion2",false) and definition.get("unlock","")=="gacha" and not MetaProgress.skill_unlocked(id)

static func talent(unit_id:String,id:String) -> bool:
	return MetaProgress.talent_options(unit_id).get(id,{}).get("expansion2",false) and id not in MetaProgress.selected_talents(unit_id,MetaProgress.unit_talents)

static func unit_talents(unit_id:String) -> bool:
	for id:String in MetaProgress.talent_options(unit_id):
		if talent(unit_id,id):return true
	return false

static func card_name(id:String) -> String:
	return (MARK if card(id) else "")+str(GameData.get_skill(id).get("name",id))

static func talent_name(unit_id:String,id:String) -> String:
	return (MARK if talent(unit_id,id) else "")+str(MetaProgress.talent_options(unit_id).get(id,{}).get("name",id))
