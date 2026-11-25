extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const ID:="bunker_optics"
const UNIT:="NABNKR"
const OLD_IDS:=["bunker_optics_1","bunker_optics_2","bunker_optics_3"]

static func base_cells() -> float:
	var half:=Building.foundation_half_for_data(GameData.get_building(UNIT))
	return float(preload("res://scripts/core/yr_death_rules.gd").data().combat.occupyweaponrange)+minf(half.x,half.y)/Building.BUILD_GRID

static func range_cells(rank:int) -> float:
	var cap:float=GameData.get_unit("GGI").deployed_weapon.range/Ra2Damage.PX_PER_CELL+P.number("mechanic/bunker_optics","extra_cells")
	return lerpf(base_cells(),cap,float(clampi(rank,0,3)+1)/4.0)

static func level(side:String) -> int:
	if not BattleRequest.extensions_enabled() or side!="ally":return 0
	if not BattleRequest.has_unit_talent(UNIT,ID,side):return 0
	return int(BattleRequest.talent_upgrade(UNIT,ID,side).get("value",1))

static func migrate(meta) -> bool:
	if meta.academy.get("bunker_optics_four_ranks",false):return false
	var selections:Dictionary=preload("res://scripts/rules/native_talent_migration.gd").ranks(meta,UNIT)
	# Three-rank talent saves advance one rank, preserving or improving paid range.
	if selections.has(ID):selections[ID]=clampi(int(selections[ID])+1,1,3)
	var highest:=0
	for i in OLD_IDS.size():
		if meta.technology_owned(OLD_IDS[i]):highest=i+1
	if highest>0 and not selections.has(ID):
		meta.owned_talent_points+=1
		if not meta.technology_active(OLD_IDS[highest-1]):
			meta.disabled_effects["talent/"+UNIT+"/"+ID]=true
	if highest>0:selections[ID]=maxi(int(selections.get(ID,0)),highest)
	if selections.has(ID):
		meta.unit_talents[UNIT]=selections
		meta.talent_slots[UNIT]=maxi(meta.talent_capacity(UNIT),1)
	meta.academy.bunker_optics_migrated=true
	meta.academy.bunker_optics_four_ranks=true
	return true
