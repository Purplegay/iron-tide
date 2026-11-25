extends RefCounted
const PressureDemo=preload("res://scripts/ui/depth_pressure_demo.gd")
const ObserverDemo=preload("res://scripts/ui/observer_line_demo.gd")
const AircraftDemo=preload("res://scripts/ui/aircraft_cycle_demo.gd")
const HuntDemo=preload("res://scripts/ui/split_hunt_demo.gd")
const HostDemo=preload("res://scripts/ui/host_hunt_demo.gd")
const ArmorDemo=preload("res://scripts/ui/anchor_armor_demo.gd")
const ReserveDemo=preload("res://scripts/ui/reserve_transfer_demo.gd")
const NavalDemo=preload("res://scripts/ui/naval_support_demo.gd")
const ForkDemo=preload("res://scripts/ui/wake_fork_demo.gd")
const GaugeDemo=preload("res://scripts/ui/intercept_ranging_demo.gd")
const SovietDemo=preload("res://scripts/ui/electric_flak_demo.gd")
const IfvDemo=preload("res://scripts/ui/ifv_crew_demo.gd")
const PounceDemo=preload("res://scripts/ui/lure_pounce_demo.gd")
const CrossfireDemo=preload("res://scripts/ui/crossfire_demo.gd")
const TractorDemo=preload("res://scripts/ui/tractor_warhead_demo.gd")
const SealDemo=preload("res://scripts/ui/overload_seal_demo.gd")
const ArchiveDemo=preload("res://scripts/ui/ballistic_archive_demo.gd")
const BurnDemo=preload("res://scripts/ui/burning_payload_demo.gd")
const AirDemo=preload("res://scripts/ui/air_observation_demo.gd")
const RotationDemo=preload("res://scripts/ui/position_rotation_demo.gd")
const EvacDemo=preload("res://scripts/ui/evacuation_escort_demo.gd")
const ConvoyDemo=preload("res://scripts/ui/convoy_repair_demo.gd")
const MirageDemo=preload("res://scripts/ui/mirage_gap_demo.gd")
const RangingDemo=preload("res://scripts/ui/armor_ranging_demo.gd")
const PrismGuardDemo=preload("res://scripts/ui/prism_guard_demo.gd")
const RelocateDemo=preload("res://scripts/ui/sniper_relocate_demo.gd")
const AdvanceDemo=preload("res://scripts/ui/alternate_advance_demo.gd")
const LauncherDemo=preload("res://scripts/ui/launcher_protection_demo.gd")
const CalibrationDemo=preload("res://scripts/ui/impact_calibration_demo.gd")
const InfantryWDemo=preload("res://scripts/ui/infantry_w_demo.gd")
const ShardDemo=preload("res://scripts/ui/following_shard_demo.gd")
## Read-only timelines use the same rank tables; no live player state is changed.
const TALENTS:=["position_rotation","steady_seat","armor_ranging","prism_guard","host_hunt","sniper_relocate","alternate_advance","reserve_transfer","following_shard","launch_bulkhead","split_hunt","hover_sighting","intercept_ranging","wake_fork","full_sortie","escort_magazine"]

static func dread_departure() -> float:
	const N=preload("res://scripts/world/special_rules.gd")
	return (N.general("DMislPauseFrames",0)+N.general("DMislTiltFrames",60))/15.0

static func v3_departure() -> float:
	const N=preload("res://scripts/world/special_rules.gd")
	return (N.general("V3RocketPauseFrames",0)+N.general("V3RocketTiltFrames",60))/15.0

static func duration(id:String) -> float:
	if id=="ap_escort_water":return preload("res://scripts/ui/naval_support_demo.gd").water_duration()
	if id=="ap_observer_line":return ObserverDemo.LENGTH
	if id in ["ap_anchor_pin","ap_battle_breather"]:return InfantryWDemo.duration(id)
	if id=="ps_impact_calibration":return CalibrationDemo.LENGTH
	if id in ["launch_bulkhead","escort_magazine"]:return LauncherDemo.duration(id)
	if id=="sniper_relocate":return RelocateDemo.LENGTH
	if id=="alternate_advance":return AdvanceDemo.LENGTH
	if id=="prism_guard":return PrismGuardDemo.LENGTH
	if id=="armor_ranging":return RangingDemo.LENGTH
	if id=="following_shard":return ShardDemo.LENGTH
	if id=="ps_mirage_gap":return MirageDemo.LENGTH
	if id=="ps_convoy_repair":return ConvoyDemo.LENGTH
	if id=="ps_evacuation_escort":return EvacDemo.LENGTH
	if id=="position_rotation":return RotationDemo.LENGTH
	if id in ["ps_low_observation","hover_sighting"]:return AirDemo.LENGTH
	if id=="ps_burning_payload":return BurnDemo.LENGTH
	if id=="ps_ballistic_archive":return ArchiveDemo.LENGTH
	if id=="ap_overload_seal":return SealDemo.LENGTH
	if id=="ap_lure_pounce":return PounceDemo.LENGTH
	if id=="ps_sea_air_crossfire":return CrossfireDemo.LENGTH
	if id=="steady_seat":return IfvDemo.SEAT_LENGTH
	if id=="ps_polar_link":return SovietDemo.POLAR_LENGTH
	if id=="ap_flak_fan":return SovietDemo.FLAK_LENGTH
	if id=="wake_fork":return ForkDemo.LENGTH
	if id=="intercept_ranging":return GaugeDemo.span()*4
	if id=="reserve_transfer":return ReserveDemo.LENGTH
	if id=="ps_shore_reserve":return 16.0
	if id=="split_hunt":return HuntDemo.LENGTH
	if id in ["ps_last_calibration","full_sortie"]:return AircraftDemo.LENGTH
	if id=="ap_tractor_warhead":return TractorDemo.LENGTH
	if id=="ps_anchor_armor":return ArmorDemo.LENGTH
	if id=="ps_depth_pressure":return PressureDemo.LENGTH
	if id=="host_hunt":return HostDemo.LENGTH
	return float(GameData.get_skill(id).trigger_interval)+4.0 if id=="ps_module_shell" else 8.0

static func sample(id:String,rank:int,time:float) -> Dictionary:
	if id=="ps_depth_pressure":return PressureDemo.sample(rank,time)
	if id=="ap_observer_line":return ObserverDemo.sample(rank,time)
	if id in ["ap_anchor_pin","ap_battle_breather"]:return InfantryWDemo.sample(id,rank,time)
	if id=="ps_impact_calibration":return CalibrationDemo.sample(rank,time)
	if id in ["launch_bulkhead","escort_magazine"]:return LauncherDemo.sample(id,rank,time)
	if id=="sniper_relocate":return RelocateDemo.sample(rank,time)
	if id=="alternate_advance":return AdvanceDemo.sample(rank,time)
	if id=="prism_guard":return PrismGuardDemo.sample(rank,time)
	if id=="armor_ranging":return RangingDemo.sample(rank,time)
	if id=="following_shard":return ShardDemo.sample(rank,time)
	if id=="ps_mirage_gap":return MirageDemo.sample(rank,time)
	if id=="ps_convoy_repair":return ConvoyDemo.sample(rank,time)
	if id=="ps_evacuation_escort":return EvacDemo.sample(rank,time)
	if id=="position_rotation":return RotationDemo.sample(rank,time)
	if id in ["ps_low_observation","hover_sighting"]:return AirDemo.sample(id,rank,time)
	if id=="ps_burning_payload":return BurnDemo.sample(rank,time)
	if id=="ps_ballistic_archive":return ArchiveDemo.sample(rank,time)
	if id=="ap_overload_seal":return SealDemo.sample(rank,time)
	if id=="ap_tractor_warhead":return TractorDemo.sample(rank,time)
	if id=="ap_lure_pounce":return PounceDemo.sample(rank,time)
	if id=="ps_sea_air_crossfire":return CrossfireDemo.sample(rank,time)
	if id=="ps_module_shell":return IfvDemo.module_sample(rank,time)
	if id=="steady_seat":return IfvDemo.seat_sample(rank,time)
	if id=="ps_polar_link":return SovietDemo.polar(rank,time)
	if id=="ap_flak_fan":return SovietDemo.flak(rank,time)
	if id=="wake_fork":return ForkDemo.sample(rank,time)
	if id=="intercept_ranging":return GaugeDemo.sample(rank,time)
	if id in ["ap_escort_water","ap_gun_ballast"]:return NavalDemo.sample(id,rank,time)
	if id=="reserve_transfer":return ReserveDemo.sample(rank,time)
	if id=="ps_shore_reserve":return shore_sample(rank,time)
	if id=="ps_anchor_armor":return ArmorDemo.sample(rank,time)
	if id=="host_hunt":return HostDemo.sample(rank,time)
	if id=="split_hunt":return HuntDemo.sample(rank,time)
	if id in ["ps_last_calibration","full_sortie"]:return AircraftDemo.sample(id,rank,time)
	if id=="ap_prism_cross":return cross_sample(rank,time)
	return {"time":fposmod(time,duration(id)),"active":false,"value":0.,"charges":0,"text":""}

static func shore_sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,duration("ps_shore_reserve"))
	var local:=fposmod(t,8.0)
	var firing:=t>=10.5
	var values:Dictionary=GameData.get_skill("ps_shore_reserve").values
	var speed_left:=maxf(0,2+float(values.speed_time[rank])-local) if local>=2 else 0.
	var cloak_left:=maxf(0,2+float(values.cloak[rank])-local) if local>=2 and not firing else 0.
	var text:="水中实际移动 %.1f / 2秒"%local if local<2 else ("开火破隐 · 加速仍剩 %.1fs"%speed_left if firing and speed_left>0 else ("隐身 %.1fs · 加速 %.1fs"%[cloak_left,speed_left] if speed_left>0 else "效果结束 · 需重新完整水中移动"))
	return {"time":t,"local":local,"active":speed_left>0,"value":20.,"charges":0,"firing":firing,"cloak_left":cloak_left,"speed_left":speed_left,"distance":minf(local,6)*15+clampf(local-2,0,float(values.speed_time[rank]))*3,"text":text}

static func cross_sample(rank:int,time:float) -> Dictionary:
	var t:=fposmod(time,duration("ap_prism_cross"))
	var count:=0 if t<.6 else (1 if t<1.2 else 2)
	var damage:float=GameData.get_skill("ap_prism_cross").values.damage[rank]*100
	var active:bool=(t>=.6 and t<.84) or (t>=1.2 and t<1.44)
	return {"time":t,"active":active,"value":damage,"charges":count,"moving_hits":mini(count,1),
		"escape":Vector2(40*clampf((t-.65)/.4,0,1),35),
		"text":"固定选点／朝向 · 预警0.6秒" if count==0 else ("第一轮 +%d%% · 下方目标开始撤出"%damage if count==1 else "第二轮 +%d%% · 中心共2次，撤出者仅1次"%damage)}

static func sync_card(stage) -> void:
	var model=stage.caster_model.actor
	model.special.expansion_2_preview_card=stage.card
	if stage.card=="ps_module_shell":IfvDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	var t:float=fposmod(stage.elapsed,duration(stage.card))
	if stage.card=="ps_last_calibration":AircraftDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card=="ps_shore_reserve":
		model.passive=GameData.get_skill(stage.card)
		var sample_state:=shore_sample(stage.preview_rank,stage.elapsed)
		var s:Dictionary=model.special.get_or_add("progression_v2",{"side":model.side})
		if sample_state.cloak_left>0:s.shore_cloak=sample_state.cloak_left
		else:s.erase("shore_cloak")
		if sample_state.speed_left>0:s.shore_speed=sample_state.speed_left
		else:s.erase("shore_speed")
		model.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42*(1.2 if sample_state.active else 1.0)
	if stage.card=="ps_impact_calibration":CalibrationDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card=="ps_convoy_repair":model.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42 if sample(stage.card,stage.preview_rank,stage.elapsed).moving else Vector2.ZERO
	if stage.card=="ps_low_observation":AirDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card=="ps_mirage_gap":
		MirageDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card in ["ap_anchor_pin","ap_battle_breather"]:InfantryWDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card=="ap_lure_pounce":model.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*80 if sample(stage.card,stage.preview_rank,stage.elapsed).moving else Vector2.ZERO
	if stage.card=="ap_gun_ballast":model.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*42*(.85 if t<4 else 1.0)
	if stage.card=="ps_depth_pressure":PressureDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))
	if stage.card=="ap_observer_line":ObserverDemo.sync_actor(model,sample(stage.card,stage.preview_rank,stage.elapsed))

static func draw_card(stage) -> String:
	var s:=sample(stage.card,stage.preview_rank,stage.elapsed)
	if stage.card=="ps_depth_pressure":
		PressureDemo.draw(stage,s)
		return s.text
	if stage.card=="ap_observer_line":
		ObserverDemo.draw(stage,s)
		return s.text
	if stage.card in ["ap_anchor_pin","ap_battle_breather"]:
		InfantryWDemo.draw(stage,stage.card,s)
		return s.text
	if stage.card=="ps_impact_calibration":
		CalibrationDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_mirage_gap":
		MirageDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_convoy_repair":
		ConvoyDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_evacuation_escort":
		EvacDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_low_observation":
		AirDemo.draw_card(stage,s)
		return s.text
	if stage.card=="ps_burning_payload":
		BurnDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_ballistic_archive":
		ArchiveDemo.draw(stage,s)
		return s.text
	if stage.card=="ap_overload_seal":
		SealDemo.draw(stage,s)
		return s.text
	if stage.card=="ap_tractor_warhead":
		TractorDemo.draw(stage,s)
		return s.text
	if stage.card=="ap_lure_pounce":
		PounceDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_sea_air_crossfire":
		CrossfireDemo.draw(stage,s)
		return s.text
	if stage.card=="ps_module_shell":
		IfvDemo.draw_module(stage,s)
		return s.text
	if stage.card=="ps_polar_link":
		SovietDemo.draw_polar(stage,s)
		return s.text
	if stage.card=="ap_flak_fan":
		SovietDemo.draw_flak(stage,s)
		return s.text
	if stage.card=="ap_escort_water":
		NavalDemo.draw_water(stage,s)
		return s.text
	if stage.card=="ap_gun_ballast":
		NavalDemo.draw_ballast(stage,s)
		return s.text
	var a:Vector2=stage.A;var b:Vector2=stage.B
	if stage.card=="ps_anchor_armor":a.x+=clampf(s.time-6,0,3)*12
	if stage.card=="ps_shore_reserve":a.x+=s.distance
	stage.actor(a,stage.ALLY)
	stage.actor(b,stage.FOE,PI)
	match stage.card:
		"ps_last_calibration":
			AircraftDemo.draw(stage,a,b,s)
		"ps_shore_reserve":
			stage.draw_line(stage.A+Vector2(30,-45),stage.A+Vector2(30,45),Color(.3,.7,1),2)
			if s.active:stage.ring(a,24,stage.ALLY)
			stage.shot(a,b,10.5)
			stage.draw_string(ThemeDB.fallback_font,Vector2(115,20),"自然到期" if s.time<8 else "主动开火破隐",HORIZONTAL_ALIGNMENT_LEFT,-1,12,stage.BONUS)
			stage.draw_string(ThemeDB.fallback_font,Vector2(115,37),"隐身 %.1fs / 加速 %.1fs"%[s.cloak_left,s.speed_left],HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.ALLY)
		"ps_anchor_armor":
			ArmorDemo.draw(stage,a,b,s)
		"ap_prism_cross":
			stage.actor(b+s.escape,stage.FOE,PI,false)
			stage.actor(b+Vector2(0,-35),stage.FOE,PI,false)
			if s.time<1.44:
				var color:Color=stage.BONUS if s.active else stage.MUTED
				stage.draw_rect(Rect2(b+Vector2(-55,-8.25),Vector2(110,16.5)),Color(color,.25),true)
				stage.draw_rect(Rect2(b+Vector2(-8.25,-55),Vector2(16.5,110)),Color(color,.25),true)
				for axis in [Vector2.RIGHT,Vector2.DOWN]:stage.draw_line(b-axis*55,b+axis*55,color,3 if s.active else 1)
			stage.draw_string(ThemeDB.fallback_font,b+Vector2(-55,-15),"中心 %d次"%s.charges,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.BONUS)
			stage.draw_string(ThemeDB.fallback_font,b+s.escape+Vector2(-30,20),"撤出 %d次"%s.moving_hits,HORIZONTAL_ALIGNMENT_LEFT,-1,11,stage.FOE)
	return s.text

static func animate(preview) -> void:
	var s:=sample(preview.demo,preview.rank,preview.age)
	preview.actor.velocity=Vector2.ZERO
	if preview.demo in ["launch_bulkhead","escort_magazine"]:LauncherDemo.sync_actor(preview.actor,s)
	if preview.demo=="steady_seat":
		IfvDemo.sync_actor(preview.actor,s)
		preview.actor.position+=preview.viewport.canvas_transform.affine_inverse().basis_xform(Vector2(s.distance,0))
		preview.actor.velocity=Vector2.RIGHT.rotated(Iso.eff_angle())*30 if s.moving else Vector2.ZERO
	if preview.demo=="full_sortie":AircraftDemo.sync_actor(preview.actor,s)
	if preview.demo=="hover_sighting":
		AirDemo.sync_actor(preview.actor,s)
		preview.actor.position+=preview.viewport.canvas_transform.affine_inverse().basis_xform(Vector2(s.distance,0 if s.airborne else 18))
	if preview.demo=="position_rotation":preview.actor._deployed=s.deployed
	if preview.demo=="armor_ranging":preview.actor._deployed=s.deployed
	if preview.demo in ["sniper_relocate","alternate_advance"]:
		preview.actor.position+=preview.viewport.canvas_transform.affine_inverse().basis_xform(Vector2(-s.distance,0))
		preview.actor.velocity=Vector2.LEFT.rotated(Iso.eff_angle())*s.speed if s.moving else Vector2.ZERO
		if preview.demo=="alternate_advance" and s.turning:
			preview.actor.hull_angle+=sin(s.local*2)*.8
			preview.actor.turret_angle=preview.actor.hull_angle
	if preview.demo=="host_hunt":
		HostDemo.animate(preview,s)

static func draw_talent(preview,clock:float) -> void:
	var s:=sample(preview.demo,preview.rank,clock)
	var origin:Vector2=preview.viewport.canvas_transform*preview.actor.position
	if preview.demo in ["launch_bulkhead","escort_magazine"]:
		LauncherDemo.draw(preview,origin,preview.demo,s)
	elif preview.demo=="full_sortie":
		AircraftDemo.draw(preview,origin,preview.MAIN_POINT,s)
	elif preview.demo=="wake_fork":
		ForkDemo.draw(preview,origin,s)
	elif preview.demo=="intercept_ranging":
		GaugeDemo.draw(preview,origin,s)
	elif preview.demo=="hover_sighting":
		AirDemo.draw_talent(preview,origin,s)
	elif preview.demo=="split_hunt":
		HuntDemo.draw(preview,origin,s)
	elif preview.demo=="position_rotation":
		RotationDemo.draw(preview,origin,s)
	elif preview.demo=="steady_seat":
		IfvDemo.draw_seat(preview,origin,s)
	elif preview.demo=="armor_ranging":
		RangingDemo.draw(preview,origin,s)
	elif preview.demo=="prism_guard":
		PrismGuardDemo.draw(preview,origin,s)
	elif preview.demo=="host_hunt":
		HostDemo.draw(preview,s)
	elif preview.demo=="sniper_relocate":
		RelocateDemo.draw(preview,origin,s)
	elif preview.demo=="alternate_advance":
		AdvanceDemo.draw(preview,origin,s)
	elif preview.demo=="reserve_transfer":
		ReserveDemo.draw(preview,origin,s)
	elif preview.demo=="following_shard":
		ShardDemo.draw(preview,origin,s)
	preview.draw_string(ThemeDB.fallback_font,Vector2(10,145),s.text,HORIZONTAL_ALIGNMENT_CENTER,410,12,Color.WHITE)
