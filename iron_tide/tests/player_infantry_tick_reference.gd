extends RefCounted
# Frozen pre-change tick; player actors always take the original three handlers.
const EMPTY_STATE: Dictionary = {}
const R=preload("res://scripts/units/expansion_rules.gd")
const Heroes=preload("res://scripts/units/expansion_heroes.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")
const Talents=preload("res://scripts/units/expansion_talents.gd")

static func tick(unit: Unit,dt:float) -> bool:
	if not BattleRequest.extensions_enabled() or not AlliedAbilities.alive(unit) or unit.special.has("hero_wreck"):return false
	if R.temporary(unit):
		if Heroes.temporary_tick(unit,dt):return true
		if Cards.mine_tick(unit,dt):return true
	if not unit.special.has(R.KEY) and unit.unit_id not in ["E1","MTNK","HTNK","MGTK","TTNK","V3","HTK","DLPH","CARRIER","BEAG","DEST"] and not GameData.get_skill(unit.passive.get("id","")).get("expansion",false):return false
	var previous_arcs := int(unit.special.get(R.KEY,EMPTY_STATE).get("arc_count",0))
	var idle := preload("res://tests/unit_idle_iteration_reference.gd").try_tick(unit,dt)
	if not idle:
		Cards.tick(unit,dt);Talents.tick(unit,dt)
		if Heroes.tick(unit,dt):return true
	unit._recompute_bonuses()
	# Idle bookkeeping has no animated overlay; normal movement, turning,
	# damage, selection and weapon animations keep their own redraw requests.
	# The fallback low-health smoke still needs its original continuous refresh.
	if not idle or previous_arcs > 0 or unit.hp < unit.max_hp * 0.42: unit.queue_redraw()
	return false

