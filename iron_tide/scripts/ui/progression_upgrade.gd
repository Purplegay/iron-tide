extends Control
## Read-only upgrade availability; refreshed by progression events, never polled.
const Academy=preload("res://scripts/rules/academy.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
const AutoSkills=preload("res://scripts/rules/auto_skill_loadout.gd")

static func skill_slots(unit_id:String,is_hero:=false,owned:Variant=null) -> Dictionary:
	var pending:={"active":false,"passive":false}
	if is_hero:
		if not Academy.HEROES.has(unit_id) or Academy.hero_build_count(MetaProgress,unit_id)<Academy.hero_requirement(unit_id):return pending
	elif not GameData.unit_index.has(unit_id) and not preload("res://scripts/rules/skill_scope.gd").defense(unit_id):return pending
	var loadout:=Loadouts.effective(MetaProgress,unit_id) if is_hero else MetaProgress.unit_effective_loadout(unit_id)
	if owned==null:owned=MetaProgress.owned_skills()
	for entry:Dictionary in owned:
		var kind:=str(entry.get("type",""))
		if kind not in pending or pending[kind]:continue
		var current:=str(loadout.active[0]) if kind=="active" else str(loadout.passive)
		if not current.is_empty():continue
		var id:=str(entry.id)
		if not UnitSkillLayout.compatible(unit_id,id,is_hero):continue
		if kind=="active" and not UnitSkillLayout.equippable(unit_id,id,is_hero):continue
		pending[kind]=true
	return pending

static func skills(unit_id:String,is_hero:=false) -> bool:
	var pending:=skill_slots(unit_id,is_hero)
	return pending.active or pending.passive

static func any_unit_skills() -> bool:
	var owned:=MetaProgress.owned_skills()
	for unit_id:String in AutoSkills.roster():
		var pending:=skill_slots(unit_id,false,owned)
		if pending.active or pending.passive:return true
	return false

static func card(id:String) -> bool:
	if id not in MetaProgress.unlocked_skills:return false
	var cost:=Academy.card_upgrade_cost(id,Academy.card_rank(MetaProgress,id))
	return cost>0 and MetaProgress.balance("cores")>=cost

static func talent(unit_id:String,id:String) -> bool:
	var cost:=MetaProgress.talent_upgrade_cost(unit_id,id)
	return cost>0 and MetaProgress.balance("cores")>=cost

static func unit_talents(unit_id:String) -> bool:
	for id:String in MetaProgress.talent_options(unit_id):
		if talent(unit_id,id) or talent_unlock(unit_id,id):return true
	return false

static func talent_unlock(unit_id:String,id:String) -> bool:
	var offer:=MetaProgress.talent_unlock_quote(unit_id,id)
	return not offer.is_empty() and MetaProgress.balance(offer.currency)>=float(offer.cost)

static func legend_unlock(id:String) -> bool:
	if MetaProgress.skill_unlocked(id):return false
	var definition:=GameData.get_skill(id)
	if definition.get("rarity","")!="legend":return false
	var cost:=int(Academy.EXCHANGE.get("legend",0))
	return cost>0 and int(MetaProgress.academy.get("card_shards",0))>=cost and MetaProgress.skill_draw_candidates().has(definition)

static func hero_talent(id:String,track:String) -> bool:
	if not Academy.HEROES.has(id) or Academy.hero_build_count(MetaProgress,id)<Academy.hero_requirement(id):return false
	var key:="hero_escort_ranks" if track=="escort" else "hero_survival_ranks"
	var cost:=Academy.hero_talent_cost(track,int(MetaProgress.academy.get(key,{}).get(id,0)),id)
	return cost>0 and MetaProgress.balance("cores")>=cost

static func hero(id:String) -> bool:
	if skills(id,true):return true
	if hero_talent(id,"escort") or hero_talent(id,"survival"):return true
	for card_id:String in Pool.for_hero(id).get("cards",[]):
		if card(card_id):return true
	return false

static func pool_upgrade_names() -> PackedStringArray:
	var rewards := {}
	for contract:Dictionary in Pool.entries():
		for id:String in contract.cards:
			rewards[id] = true
	var names := PackedStringArray()
	for id:String in MetaProgress.unlocked_skills:
		if not rewards.has(id) and card(id):
			names.append(str(GameData.get_skill(id).get("name", id)))
	return names

static func any_card() -> bool:
	if not pool_upgrade_names().is_empty():return true
	for entry:Dictionary in MetaProgress.skill_draw_candidates():
		if legend_unlock(str(entry.id)):return true
	return false

static func any_hero() -> bool:
	for id:String in Academy.HEROES:
		if hero(id):return true
	return false

static func any_unit_talent() -> bool:
	for id:String in GameData.meta_config.get("unit_talents",{}):
		if unit_talents(id):return true
	return false

static func mark(control:Control,available:bool) -> void:
	var dot:=control.get_node_or_null("UpgradeDot")
	if dot==null:
		if not available:return
		dot=load("res://scripts/ui/progression_upgrade.gd").new()
		dot.name="UpgradeDot"
		dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		control.add_child(dot)
		dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left=-14;dot.offset_right=-2;dot.offset_top=2;dot.offset_bottom=14
	dot.visible=available

func _draw() -> void:
	draw_circle(Vector2(6,6),5.5,Color("#341217"))
	draw_circle(Vector2(6,6),4,Color("#ff4359"))
