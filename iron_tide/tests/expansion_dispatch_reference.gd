extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Second expansion. All state is snapshot-owned actor.special data.
const R=preload("res://scripts/units/expansion_rules.gd")
const Ground=preload("res://scripts/units/expansion_2_ground.gd")
const Soviet=preload("res://scripts/units/expansion_2_soviet.gd")
const Drone=preload("res://scripts/units/expansion_2_drone.gd")
const Infantry=preload("res://scripts/units/expansion_2_infantry.gd")
const Armor=preload("res://scripts/units/expansion_2_armor.gd")
const Naval=preload("res://scripts/units/expansion_2_naval.gd")
const Air=preload("res://scripts/units/expansion_2_air.gd")
const NavalFire=preload("res://scripts/units/expansion_2_naval_fire.gd")
const Submarine=preload("res://scripts/units/expansion_2_submarine.gd")
const Calibration=preload("res://scripts/units/expansion_2_calibration.gd")
const Convoy=preload("res://scripts/units/expansion_2_convoy.gd")
const Infiltration=preload("res://scripts/units/expansion_2_infiltration.gd")
const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
const Dread=preload("res://scripts/units/expansion_2_dread.gd")
const Overload=preload("res://scripts/units/expansion_2_overload.gd")
const Tractor=preload("res://scripts/units/expansion_2_tractor.gd")
const KEY:="progression_v2"
const ACTIVE:=["ap_anchor_pin","ap_observer_line","ap_battle_breather","ap_prism_cross","ap_flak_fan","ap_lure_pounce","ap_escort_water","ap_gun_ballast","ap_overload_seal","ap_tractor_warhead"]
const EMPTY:Dictionary={}

static func eligible(unit) -> bool:
	if Aircraft.eligible(unit) or Dread.enabled(unit):return true
	if unit.unit_id not in ["E1","E2","SNIPE","FLAKT","FV","GGI","SREF","MGTK","SHK","HTK","DRON","V3","APOC","JUMPJET","SHAD","SCHP","HYD","AEGIS","SUB","MTNK","HTNK","GHOST","TANY","BORIS"] and not unit.special.has(KEY):return false
	return R.active(unit) and (unit.special.has(KEY) or Infiltration.eligible(unit) or Calibration.equipped(unit) or Convoy.eligible(unit) or Submarine.eligible(unit) or NavalFire.eligible(unit) or Air.eligible(unit) or Ground.eligible(unit) or Soviet.eligible(unit) or Drone.enabled(unit) or Infantry.eligible(unit) or Armor.eligible(unit) or unit.passive.get("id")=="ps_module_shell" or (unit.unit_id=="E1" and R.talent_rank(unit,"position_rotation")>=0) or (unit.unit_id=="FV" and R.talent_rank(unit,"steady_seat")>=0))
