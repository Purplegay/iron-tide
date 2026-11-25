extends RefCounted
## Building W adapter. Persist only rank/cooldown in the existing special map.
const ID := "ap_shock_pulse"
const STATE := "tesla_pulse"
const Cards=preload("res://scripts/units/electric_cards.gd")

static func configure(building) -> void:
	if building.side!="ally" or not BattleRequest.extensions_enabled():return
	var loadout:=BattleRequest.unit_loadout(building.building_id)
	if loadout.passive=="ps_armor_plating":
		building.special.card_armor=float(GameData.get_skill("ps_armor_plating").value)*BattleRequest.card_scale("ps_armor_plating")
		building.special.card_armor_rank=int(BattleRequest.combat_context.get("card_ranks",{}).get("ps_armor_plating",0))
	if building.special.has(STATE):return
	var skill:String=str(loadout.active[0])
	if skill not in [ID,"ap_focus_fire"]:return
	building.special[STATE]={"id":skill,"rank":int(BattleRequest.combat_context.get("card_ranks",{}).get(skill,0)),"left":0.0,"active":0.0}

static func card_id(building) -> String:
	return str(building.special.get(STATE,{}).get("id",ID))

static func reload_multiplier(building) -> float:
	var factor := 1.0-clampf(ability(building).value,0,0.85) if available(building) and card_id(building)=="ap_focus_fire" and float(building.special[STATE].get("active",0))>0 else 1.0
	return factor * (0.8 if BattleRequest.brutal_house(building.side) else 1.0)

static func reload_duration(building) -> float:
	# Preserve the native charge-up, which is a separate firing phase.
	return maxf(0.0,building.cooldown-float(building.data.get("fire_delay",0)))*reload_multiplier(building)

static func available(building) -> bool:
	return is_instance_valid(building) and building is Building and building.side=="ally" and not building.is_dead() and BattleRequest.extensions_enabled() and building.special.has(STATE)

static func ability(building) -> Ability:
	var result:=Ability.new()
	result.setup(GameData.get_skill(card_id(building)),clampi(int(building.special[STATE].rank),0,3))
	result.value*=BattleRequest.card_scale(result.id)
	result.cd_left=float(building.special[STATE].left)
	result.active_left=float(building.special[STATE].get("active",0))
	return result

static func ready(building) -> bool:
	return available(building) and building.is_operational() and building.special[STATE].left<=0 and building.battle!=null and not building.battle.paused and not building.battle.ended and not building.get_tree().paused

static func use(building) -> bool:
	if not ready(building):return false
	var ab:=ability(building)
	if ab.id=="ap_focus_fire":building.special[STATE].active=ab.duration
	elif not Cards.cast(building,ab):return false
	building.special[STATE].left=ab.cooldown
	return true

static func tick(building,delta:float) -> void:
	if not available(building) or building.battle==null or building.battle.paused or building.battle.ended or building.get_tree().paused:return
	building.special[STATE].left=maxf(0,float(building.special[STATE].left)-delta)
	building.special[STATE].active=maxf(0,float(building.special[STATE].get("active",0))-delta)
	preload("res://scripts/units/auto_w.gd").tick(building,delta)
