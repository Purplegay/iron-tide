extends RefCounted
## Shared card eligibility and visual taxonomy; never infer permissions from icons.
const LABELS={"vehicle":"地面载具","air":"飞机","infantry":"步兵","defense":"防御建筑","naval":"海军","electric":"电磁","hightech":"高科技","antiair":"防空","explosive":"爆破","heavy":"重装","tactics":"战术"}
const RARITY_COLORS={"ultimate":Color("#ffe397"),"legend":Color("#ffd166"),"epic":Color("#c58aff"),"rare":Color("#70b7ff"),"common":Color("#ffffff")}

static func exclusive(card:Dictionary) -> bool:
	return card.get("allowed_units",[]).size()==1

static func group(card:Dictionary) -> String:
	if exclusive(card):return "专属"
	return "多单位" if not card.get("allowed_units",[]).is_empty() else "通用"

static func rarity_color(card:Dictionary) -> Color:
	return RARITY_COLORS.get(card.get("rarity","common"),Color.WHITE)

static func defense(id:String) -> bool:
	if not GameData.building_index.has(id):return false
	var row:Dictionary=GameData.building_index[id]
	return GameData.building_production_category(id)=="defense" and (not row.get("weapon",{}).is_empty() or row.has("garrison_weapons") or row.has("charged_weapon") or id=="NABNKR") and id!="R3REAPERTURRET"

static func category(id:String) -> String:
	if GameData.building_index.has(id):return "defense" if defense(id) else "building"
	if not GameData.unit_index.has(id):return ""
	var row:Dictionary=GameData.unit_index[id]
	# Flight wins over the factory/barracks production tab (Rocketeer, choppers).
	if row.get("tags",[]).has("air") or row.get("role","")=="air":return "air"
	return GameData.unit_production_category(row)

static func compatible(id:String,card:Dictionary) -> bool:
	if id in card.get("excluded_units",[]):return false
	if card.get("requires_direct_weapon",false) and GameData.unit_index.get(id,{}).get("weapon",{}).is_empty():return false
	var allowed:Array=card.get("allowed_units",[])
	if not allowed.is_empty():return id in allowed
	var kinds:Array=card.get("allowed_categories",[])
	if not kinds.is_empty():return category(id) in kinds
	return not GameData.building_index.has(id)

static func description(card:Dictionary) -> String:
	if card.has("scope_note"):return "适用："+str(card.scope_note)
	var names:=PackedStringArray()
	for kind in card.get("allowed_categories",[]):names.append(str(LABELS.get(kind,kind)))
	if not names.is_empty():return "适用："+"／".join(names)
	if not card.get("allowed_units",[]).is_empty():return "适用："+str(card.get("units","指定兵种"))
	return ""
