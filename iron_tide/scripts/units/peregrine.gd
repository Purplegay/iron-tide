extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## ORCA is the base chassis; the hero owns a separate ammunition lifecycle.
const KEY="peregrine"
const R=preload("res://scripts/units/expansion_rules.gd")
const Cycle=preload("res://scripts/units/expansion_2_aircraft.gd")
const Cards=preload("res://scripts/units/peregrine_cards.gd")
const Quests=preload("res://scripts/rules/peregrine_contracts.gd")
const Command=preload("res://scripts/units/peregrine_command.gd")
const Defense=preload("res://scripts/units/peregrine_defense.gd")
const Service=preload("res://scripts/units/peregrine_service.gd")
const TITLES=["王牌航线","滞空保障"]
const BASE_TEXT=["航拍落点：普通导弹命中后揭示固定落点周围 1 格，持续 3 秒。基础弹仓 4 发，空中每 8 秒自动补一发，不占机场位。","离场余速：真实打空弹仓后移动速度 +20%，持续 3 秒；每个补满周期一次，可叠加其他来源增益，不强迫移动。"]

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.unit_id=="ORCA" and unit.special.get("academy_hero")=="ORCA" and unit.special.has(KEY) and BattleRequest.extensions_enabled() and not R.temporary(unit)

static func eligible_owner(world,side:String) -> bool:
	if world==null or side!="ally":return false
	var country:String=str(BattleRequest.skirmish_config.get("country","美国"))
	var houses:Array=BattleRequest.skirmish_config.get("houses",[])
	if not houses.is_empty():country=str(houses[0].get("country",""))
	for row:Dictionary in GameData.ra2_countries:
		if str(row.id)==country or str(row.get("display",""))==country:return row.get("side","")=="allied"
	return false

static func promote(_meta,world,unit) -> void:
	if not BattleRequest.extensions_enabled() or not AlliedAbilities.alive(unit) or unit.unit_id!="ORCA" or R.temporary(unit):return
	if not eligible_owner(world,unit.side):return
	var deployed:Dictionary=world.allied_state.get_or_add("peregrine_deployed",{})
	if deployed.has(unit.side):return
	deployed[unit.side]=true
	if unit.side=="ally":world.allied_state.get_or_add("named_heroes",{})["ORCA"]=10
	unit.special.academy_hero="ORCA"
	unit.special.hero_command_rank=int(BattleRequest.combat_context.get("hero_escort_ranks",{}).get("ORCA",0)) if unit.side=="ally" else 0
	unit.special.hero_survival_rank=int(BattleRequest.combat_context.get("hero_survival_ranks",{}).get("ORCA",0)) if unit.side=="ally" else 0
	unit.display_name="英雄 · 游隼"
	unit.equip_hero_cards()
	var academy=MetaProgress.Academy
	var training:Dictionary=BattleRequest.combat_context.get("hero_training",{}) if unit.side=="ally" else {}
	var scale:float=BattleRequest.combat_context.get("hero_training_scale",1.0)
	unit._grant_veteran(int(GameData.ra2_veteran_rules().get("cap",2)),false)
	unit._base_max_hp*=1.0+.01*academy.training_percent("health",academy.training_rank(training,"ORCA","health"),scale)
	unit.max_hp=unit._base_max_hp;unit.hp=unit.max_hp
	unit._base_atk*=CombatMath.additional_growth_ratio(unit.bonuses,1.0+.01*academy.training_percent("firepower",academy.training_rank(training,"ORCA","firepower"),scale))
	unit.special[KEY]={"progress":0.0,"cycle":0,"empty_ready":true,"last_ready":true,"decoy_ready":true,"control_ready":true,"hits":false,"side":unit.side}
	unit.logistics.ammo_max=P.count("hero/ORCA/command","ammo_upgraded") if int(unit.special.hero_command_rank)>=1 else P.count("hero/ORCA/command","ammo_base")
	unit.logistics.ammo=unit.logistics.ammo_max
	restore(unit)
	unit._recompute_bonuses();unit._refresh_weapon_derived();unit.refresh_house_color()
	Cards.filled(unit)

static func restore(unit) -> void:
	if not active(unit):return
	if unit.peregrine_fx==null:unit.peregrine_fx=preload("res://scripts/units/peregrine_visual.gd").new()
	Command.install(unit)
	unit.logistics.home=null;unit.logistics.dock_slot=-1
	unit.logistics.air_state="flying"
	unit.flight.jumpjet=true;unit.flight.balloon=true;unit.flight.landable=false
	unit.flight.horizontal_speed=float(unit.data.get("speed",unit._base_speed))
	Service.restore(unit)

static func tick(unit,dt:float) -> bool:
	if not active(unit):return false
	var s:Dictionary=unit.special[KEY]
	Defense.tick(unit,dt)
	R.timer(s,"empty_speed",dt)
	if Service.tick(unit,dt):return true
	if s.get("side",unit.side)!=unit.side or unit.passive.get("id")!=Cards.PASSIVE:s.erase("rearm_shield")
	s.side=unit.side
	if not AlliedAbilities.alive(unit) or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.special.has("hero_wreck"):return true
	if unit.logistics.ammo>=unit.logistics.ammo_max:s.progress=0.0;return false
	var seconds:float=maxf(.1,((P.number("hero/ORCA/command","reload_base"))-clampi(int(unit.special.get("hero_command_rank",0)),0,5)*P.number("hero/ORCA/command","reload_per_rank"))*Cards.reload_factor(unit))
	s.progress=float(s.get("progress",0))+maxf(0,dt)/seconds
	while s.progress>=1.0-0.000001 and unit.logistics.ammo<unit.logistics.ammo_max:
		s.progress=maxf(0,float(s.progress)-1.0)
		var previous:int=unit.logistics.ammo
		unit.logistics.ammo+=1
		if unit.logistics.ammo==unit.logistics.ammo_max:
			Quests.filled(unit,bool(s.get("normal_hit",false)));Cards.filled(unit);Defense.filled(unit)
			s.progress=0.0;s.cycle=int(s.cycle)+1;s.empty_ready=true;s.last_ready=true;s.hits=false;s.normal_hit=false
			Cycle.refill_complete(unit,previous,unit.logistics.ammo,unit.logistics.ammo_max)
	unit.queue_redraw()
	return false

static func spent(unit,before:int,after:int,normal:=true) -> void:
	if not active(unit) or before<=after:return
	Command.spent(unit,before,after,normal)
	var s:Dictionary=unit.special[KEY]
	if after==0 and s.get("empty_ready",false):
		s.empty_ready=false;s.empty_speed=P.number("hero/ORCA/survival","empty_seconds")
		unit._recompute_bonuses()

static func speed_bonus(unit) -> float:
	return P.number("hero/ORCA/survival","empty_speed") if active(unit) and float(unit.special[KEY].get("empty_speed",0))>0 else 0.0

static func hit(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not source is Projectile or source.target!=target or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	var unit=source.shooter()
	if not active(unit) or unit.side!=source.owner_side or not bonus.get("peregrine_normal",false) or source.splinters.get("peregrine_contact",false):return
	source.splinters.peregrine_contact=true
	var world=R.world(unit)
	if world.fog!=null:world.fog._reveal(unit.side,source.target_point,P.number("hero/ORCA/command","reveal_radius")*R.CELL,P.number("hero/ORCA/command","reveal_seconds"))
	if R.enemy(unit,target) and Quests.combat_target(target):
		unit.special[KEY].hits=true;unit.special[KEY].normal_hit=true
		Quests.contact(world,unit.side,target)

static func entries(unit) -> Array:
	if not active(unit):return []
	var V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY]
	var row=V.row("游隼 · 空中补弹",0,false,"reload")
	row.text="弹药 %d/%d · 补弹 %.0f%% · 补满周期 %d · 不占机场位"%[unit.logistics.ammo,unit.logistics.ammo_max,float(s.get("progress",0))*100,int(s.cycle)]
	var out:Array=[row]
	out.append_array(Defense.entries(unit))
	out.append_array(Service.entries(unit))
	if unit.passive.get("id")==Cards.PASSIVE:
		var shield=V.row("空中整备",0,false,"guard")
		shield.text="护盾 %.0f / %.0f · 机场联动%s"%[float(s.get("rearm_shield",0)),unit.max_hp*R.value(unit,Cards.PASSIVE,"cap"),"生效" if Cards.parked(unit) else "未生效"]
		out.append(shield)
	if s.has("empty_speed"):out.append(V.row("离场余速 · 移速 +20%",s.empty_speed,false,"speed"))
	return out
