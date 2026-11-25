extends RefCounted
## Pending counts travel with battle.allied_state. Only the first settlement of a match is recorded.
const KEY := "player_production"
static func record(world,kind:String,id:String) -> void:
	if world.gm_unit_lab:return
	var counts:Dictionary=world.allied_state.get_or_add(KEY,{}).get_or_add(kind,{})
	counts[id]=int(counts.get(id,0))+1

static func settle(world,appearance_win:=false,persist:=true) -> PackedStringArray:
	var granted:=PackedStringArray()
	var counts:Dictionary=world.allied_state.get(KEY,{})
	if world.gm_unit_lab or world.match_id.is_empty():return granted
	var history:Dictionary=MetaProgress.stats.get_or_add(KEY,{})
	var settled:Dictionary=history.get_or_add("settled",{})
	if settled.has(world.match_id):return granted
	settled[world.match_id]=true
	MetaProgress.Academy.settled(MetaProgress, world, appearance_win)
	var faction:Dictionary=history.get_or_add("factions",{}).get_or_add(world.roster_faction(),{})
	faction["matches"]=int(faction.get("matches",0))+1
	for kind in counts:
		var totals:Dictionary=faction.get_or_add(kind,{})
		for id in counts[kind]:
			var row:Dictionary=totals.get_or_add(id,{"built":0,"matches":0})
			row.built+=int(counts[kind][id])
			row.matches+=1
	if appearance_win and not MetaProgress.settled_matches.has(world.match_id):
		MetaProgress.stats.appearance_wins=MetaProgress.appearance_wins()+1
		granted=MetaProgress.grant_win_milestones()
	if persist:MetaProgress.save()
	return granted

static func summary() -> String:
	var factions:Dictionary=MetaProgress.stats.get(KEY,{}).get("factions",{})
	if factions.is_empty():return "尚无已结算的对局。完成一局后，这里会按阵营列出主动建成数量和使用局数。"
	var lines:=PackedStringArray()
	for side in ["allied","soviet"]:
		if not factions.has(side):continue
		var data:Dictionary=factions[side]
		lines.append("%s · 已结算 %d 局"%["盟军" if side=="allied" else "苏联",data.matches])
		for kind in ["building","unit"]:
			var rows:Dictionary=data.get(kind,{})
			lines.append("建筑" if kind=="building" else "单位")
			if rows.is_empty():lines.append("　暂无建造记录")
			var ids:=rows.keys()
			ids.sort_custom(func(a,b):return rows[a].built>rows[b].built if rows[a].built!=rows[b].built else str(a)<str(b))
			for id in ids:
				var entry:=GameData.get_building(id) if kind=="building" else GameData.get_unit(id)
				lines.append("　%s　%d 个　·　%d 局"%[entry.get("name",id),rows[id].built,rows[id].matches])
	return "\n".join(lines)
