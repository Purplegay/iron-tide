extends RefCounted

const Book = preload("res://scripts/units/yuriko_school.gd")
const Bonds = preload("res://scripts/units/yuriko_bonds.gd")
const Dot = preload("res://scripts/ui/attention_dot.gd")

static func episode(ep:Dictionary) -> bool:
	return Book.available(ep) and not MetaProgress.yuriko_school.get("read",{}).has(ep.id)

static func replies() -> bool:
	var state:=MetaProgress.yuriko_school
	for id:String in Bonds.GIFTS:
		for index in mini(2,int(state.get("given",{}).get(id,0))):
			var key:="first" if index==0 else "again"
			if not state.get("reply_read",{}).has(id+"/"+key):return true
	return false

static func section(tab:int) -> bool:
	match tab:
		0:return Book.episodes.any(func(ep):return ep.kind=="chapter" and episode(ep)) or Bonds.stories.any(episode) or section(6)
		1:return Book.episodes.any(func(ep):return ep.kind!="chapter" and episode(ep))
		4:return section(6) or replies()
		6:return Book.affinity_stories.any(episode)
	return false

static func mark_entry(entry:Button) -> void:
	Dot.mark(entry,Book.met() and (section(0) or section(1) or replies()),"有未读手记或赠礼回应")
