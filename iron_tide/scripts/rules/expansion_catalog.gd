extends RefCounted

static func install(data) -> void:
	for path in ["progression_expansion.json","progression_expansion_2.json","progression_expansion_2_heroes.json","convoy_heroes.json"]:
		install_pack(data,data._load_json(path))

static func install_pack(data,pack:Dictionary) -> void:
	for row in pack.get("hero_contracts",[]):
		var entries:Array=data.skill_draw.get("hero_contracts",{}).get("entries",[])
		if not entries.any(func(existing):return existing.id==row.id):entries.append(row)
	for card in pack.get("skills",[]):
		card.expansion_template=card.desc
		card.desc=description(card,0)
		data.skills.append(card)
		data.skill_index[card.id]=card
	for id in pack.get("unit_talents",{}):
		var rows:Dictionary=data.meta_config.unit_talents.get_or_add(id,{})
		for key in pack.unit_talents[id]:
			if not rows.has(key) and (rows.size()<2 or id=="V3"): rows[key]=pack.unit_talents[id][key]

static func description(card:Dictionary,rank:int) -> String:
	var text:String=card.get("expansion_template",card.desc)
	for key in card.get("values",{}):
		var value:float=card.values[key][clampi(rank,0,3)]
		text=text.replace("{"+key+"}",String.num(value,2).trim_suffix("0").trim_suffix("."))
		text=text.replace("{"+key+"_pct}",String.num(value*100,1).trim_suffix(".0"))
	if card.type=="active":text+=" 冷却%s秒。"%Ability.cooldown_text(Ability.cooldown_at_rank(card,rank))
	return "Lv.%d　%s"%[rank,text]
