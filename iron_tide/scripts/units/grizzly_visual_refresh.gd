extends RefCounted
## Rigid voxel movement is a node transform, not a new sprite pose.
## Keep selection/glitter animation at 30 Hz; direction and combat changes are immediate.
static func eligible(unit: Unit) -> bool:
	if unit.unit_id != "MTNK": return rigid_vehicle(unit)
	if unit.unit_id!="MTNK" or unit._ra2.is_empty() or unit._dead or unit._dying>0 or unit.embarked_in!=null:return false
	if unit.special.has("academy_hero") or unit.hp<unit.max_hp or unit._muzzle>0 or unit._recoil>0.02 or unit._rock_t>0 or unit._stun_timer>0 or unit._hp_flash>0:return false
	for buff in unit.buffs:
		if buff.get("kind","")!="speed":return false
	for key in unit.special:
		if key not in ["cobalt_travel","reveal","hero_speed_floor","hero_range_aura","drive_reversal","formation_heading"]:return false
	return true

static func refresh(unit: Unit) -> bool:
	if not eligible(unit):return true
	# Frame selection is cheap and shares the exact renderer's facing conversion.
	if unit._sprite_facing(unit._ra2,unit.hull_angle)!=unit._art_frame:return true
	if not unit._ra2_tur.is_empty():
		var source:=RA2Art.src_rect(unit._ra2_tur,unit._sprite_facing(unit._ra2_tur,unit.turret_angle))
		if source!=unit._turret_draw_source:return true
	if unit.unit_id != "MTNK": return false
	return (Engine.get_physics_frames()+unit.get_instance_id())%2==0

# These states have no animated body overlay. Unknown state keeps full redraw.
const RIGID_VEHICLES := {"HTNK": true, "APOC": true, "HTK": true, "FV": true, "TTNK": true, "SREF": true}
const RIGID_STATE_KEYS := {
	"ai_campaign_role": true, "ai_access_moved": true, "ai_access_position": true, "ai_access_since": true,
	"ai_assembly_epoch": true, "ai_assembly_point": true, "ai_blocked_route": true, "ai_counterfire_resume": true,
	"ai_defense_goal": true, "ai_dispatch_pending": true, "ai_exchange_at": true, "ai_formation_batch": true,
	"ai_route_position": true, "ai_route_since": true, "ai_transport_reserved": true, "ai_wall_goal": true,
	"ai_wall_probe": true, "brutal_armor": true, "brutal_relief_at": true, "brutal_retry": true,
	"brutal_stall": true, "brutal_watch_pos": true, "drive_reversal": true, "escaped_crew": true,
	"hero_speed_floor": true, "hero_range_aura": true, "retaliation_origin": true, "retaliation_target": true,
	"reveal": true, "self_repair_timer": true, "shared_reload_duration": true, "formation_heading": true,
	"progression_v1": true,
}

static func rigid_vehicle(unit: Unit) -> bool:
	if not RIGID_VEHICLES.has(unit.unit_id): return false
	if unit.is_air or unit.is_naval or unit.is_harvester or unit.data.get("role") != "vehicle": return false
	if unit._ra2.get("kind") != "vxl" or int(unit._ra2.get("poses",1)) != 1 or unit._ra3_model != null: return false
	if unit._dead or unit._dying > 0.0 or unit.embarked_in != null: return false
	if unit._back_in or not unit._seq.is_empty() or unit.selected or unit.hovered or unit.hp < unit.max_hp * 0.42 or unit._muzzle > 0.0 or unit._recoil > 0.02 or unit._rock_t > 0.0 or unit._stun_timer > 0.0 or unit._hp_flash > 0.0: return false
	if unit._has_damage_particles and Unit.DamageParticles.stage(unit) > 0: return false
	if unit.tank_finish != null or unit.yr_finish != null or unit.casemate_thruster != null or unit.powered_unit.offline: return false
	if not unit.buffs.is_empty() or not unit.passive.is_empty() or not RIGID_STATE_KEYS.has_all(unit.special.keys()): return false
	var state:Dictionary=unit.special.get("progression_v1",{})
	if not preload("res://scripts/units/unit_expansion_idle.gd").INERT_KEYS.has_all(state.keys()) or float(state.get("prism_damage",0.0)) != 0.0 or int(state.get("arc_count",0)) != 0: return false
	return true
