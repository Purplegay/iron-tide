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

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	# Non-player actors cannot own unit talents. Keep live cards and saved effects.
	if unit.side != "ally" and unit.passive.is_empty() and not unit.special.has(KEY): return false
	var id: String = unit.unit_id
	if id in ["ORCA","BEAG"] and Aircraft.eligible(unit):return true
	if id=="DRED" and Dread.enabled(unit):return true
	if id not in ["E1","E2","SNIPE","FLAKT","FV","GGI","SREF","MGTK","SHK","HTK","DRON","V3","APOC","JUMPJET","SHAD","SCHP","HYD","AEGIS","SUB","MTNK","HTNK","GHOST","TANY","BORIS"] and not unit.special.has(KEY):return false
	if not R.active(unit):return false
	# Saved effects and the two type-independent cards retain the full tick path.
	# Only dispatch is narrowed; card ranks, ownership and status remain live.
	if unit.special.has(KEY) or unit.passive.get("id") in ["ps_mirage_gap","ps_module_shell"]:return true
	match id:
		"GHOST","TANY","BORIS":return Infiltration.eligible(unit)
		"SCHP":return Calibration.equipped(unit) or Air.eligible(unit)
		"MTNK","HTNK","HTK":return Convoy.eligible(unit)
		"FV":return Convoy.eligible(unit) or R.talent_rank(unit,"steady_seat")>=0
		"SUB":return Submarine.eligible(unit)
		"HYD","AEGIS":return NavalFire.eligible(unit)
		"JUMPJET","SHAD":return Air.eligible(unit)
		"GGI","SREF":return Ground.eligible(unit)
		"SHK":return Soviet.eligible(unit) or Infantry.eligible(unit)
		"DRON":return Drone.enabled(unit)
		"E2","SNIPE","FLAKT":return Infantry.eligible(unit)
		"V3","APOC":return Armor.eligible(unit)
		"E1":return R.talent_rank(unit,"position_rotation")>=0
	return false

static func tick(unit,dt:float) -> void:
	if not eligible(unit):return
	var s:=state(unit)
	var was_boosted:=s.has("breather_left")
	if s.get("side",unit.side)!=unit.side:
		unit.special.erase(KEY)
		if was_boosted or s.has("pounce_left") or s.has("relocate_left") or s.has("advance_left") or s.has("ballast_left") or s.has("shore_speed") or s.has("escort_buffs"):unit._recompute_bonuses()
		return
	Ground.tick(unit,dt)
	Soviet.tick(unit,dt)
	Drone.tick(unit,dt)
	Infantry.tick(unit,dt)
	Armor.tick(unit,dt)
	Naval.tick(unit,dt)
	NavalFire.tick(unit,dt)
	Submarine.tick(unit,dt)
	Calibration.tick(unit,dt)
	Convoy.tick(unit,dt)
	Infiltration.tick(unit,dt)
	Air.tick(unit,dt)
	Tractor.tick(unit,dt)
	for key in ["observer_left","breather_left","module_cd","rotation_cd"]:R.timer(s,key,dt)
	if s.has("module_cd") and s.module_cd<=.000001:s.erase("module_cd")
	if was_boosted and not s.has("breather_left"):unit._recompute_bonuses()
	if unit._moving() or unit.embarked_in!=null:s.erase("observer_left")
	if s.has("module_shield"):
		s.module_shield.left-=dt
		if s.module_shield.left<=0.000001:
			s.erase("module_shield");unit.queue_redraw()
	if unit.unit_id=="FV":
		crew_changed(unit)
		if AlliedAbilities.alive(s.get("crew")):s.crew_age=minf(P.number("mechanic/core_v2","crew_prepare"),float(s.get("crew_age",0))+dt)
	if unit.unit_id=="E1" and R.talent_rank(unit,"position_rotation")>=0:
		if not unit.is_deployed():
			s.rotation_charges=0;s.rotation_idle=0.0
		elif int(s.get("rotation_charges",0))==0:
			s.rotation_idle=float(s.get("rotation_idle",0))+dt
			if s.rotation_idle>=P.number("mechanic/core_v2","rotation_prepare") and not s.has("rotation_cd"):
				s.rotation_charges=P.count("mechanic/core_v2","rotation_count");s.rotation_idle=0.0;s.rotation_cd=P.number("mechanic/core_v2","rotation_cd")
				unit.queue_redraw()

static func crew_changed(unit) -> void:
	if unit.unit_id!="FV" or not eligible(unit):return
	var s:=state(unit)
	var passenger=unit.logistics.passengers[0] if not unit.logistics.passengers.is_empty() else null
	if not AlliedAbilities.alive(passenger):passenger=null
	if not is_same(s.get("crew"),passenger):s.crew=passenger;s.crew_age=0.0
	var mode:int=int(AlliedAbilities.source(passenger).get("IFVMode",0)) if passenger!=null else 0
	var previous:int=int(s.get("crew_mode",0))
	s.crew_mode=mode
	if mode==previous or unit.passive.get("id")!="ps_module_shell" or s.has("module_cd"):return
	var hp:float=unit.max_hp*R.value(unit,"ps_module_shell","shield")
	var card:=GameData.get_skill("ps_module_shell")
	s.module_shield={"hp":hp,"maximum":hp,"left":float(card.duration)};s.module_cd=float(card.trigger_interval)
	unit.queue_redraw()

static func ready(unit,ab) -> bool:
	if not R.active(unit) or not ab.ready() or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit):return false
	if ab.id in Naval.ACTIVE:return Naval.ready(unit,ab.id)
	if ab.id==Overload.CARD:return unit.unit_id in Overload.CASTERS
	if ab.id==Tractor.CARD:return Tractor.ready(unit)
	match ab.id:
		"ap_anchor_pin":return anchor_target(unit)!=null
		"ap_observer_line":return not unit._moving()
		"ap_battle_breather":return not unit.is_deployed()
		"ap_prism_cross":return unit.unit_id=="SREF" and not state(unit).has("prism_cross")
		"ap_flak_fan":return unit.unit_id=="HTK" and not state(unit).has("flak_arm")
		"ap_lure_pounce":return Drone.ready(unit)
	return false

static func cast(unit,ab,point:=Vector2.INF) -> bool:
	if not ready(unit,ab):return false
	if ab.id in Naval.ACTIVE:return Naval.cast(unit,ab)
	if ab.id==Overload.CARD:return Overload.cast(unit,ab,point)
	if ab.id==Tractor.CARD:return Tractor.cast(unit,ab)
	if ab.id=="ap_prism_cross":return Ground.cast_cross(unit,ab,point)
	if ab.id=="ap_anchor_pin":return cast_anchor(unit,ab)
	if ab.id=="ap_lure_pounce":return Drone.cast(unit,ab)
	var s:=state(unit)
	match ab.id:
		"ap_flak_fan":s.flak_arm=P.number("mechanic/core_v2","flak_duration")
		"ap_observer_line":s.observer_left=P.number("mechanic/core_v2","observer_duration");s.observer_cells=R.value(unit,ab.id,"sight")
		"ap_battle_breather":
			s.breather_left=P.number("mechanic/core_v2","breather_duration");s.breather_speed=R.value(unit,ab.id,"speed")
			unit._cancel_burst()
	ab.trigger_cooldown();unit._recompute_bonuses();unit.queue_redraw()
	return true

static func shot(unit) -> void:
	if not R.active(unit) or unit.unit_id!="E1" or R.talent_rank(unit,"position_rotation")<0:return
	state(unit).rotation_idle=0.0

static func modify_reload(unit,seconds:float) -> float:
	if not R.active(unit):return seconds
	seconds=Infantry.modify_reload(unit,seconds)
	seconds=Naval.reload_time(unit,seconds)
	seconds=NavalFire.reload_time(unit,seconds)
	seconds=Armor.begin_volley(unit,seconds)
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	if unit.unit_id=="E1" and unit.is_deployed() and int(s.get("rotation_charges",0))>0 and R.talent_rank(unit,"position_rotation")>=0:
		s.rotation_charges-=1;s.rotation_idle=0.0
		seconds*=1.0-R.talent(unit,"position_rotation","reload")
	if unit.unit_id=="FV" and R.talent_rank(unit,"steady_seat")>=0 and float(s.get("crew_age",0))>=P.number("mechanic/core_v2","crew_prepare") and not AlliedAbilities.is_repair_ifv(unit):
		var passengers:Array=unit.logistics.passengers
		if not passengers.is_empty() and AlliedAbilities.alive(passengers[0]) and is_same(passengers[0],s.get("crew")):
			seconds*=1.0-R.talent(unit,"steady_seat","reload")
	return seconds

static func anchor_target(unit):
	var target=unit.attack_target
	if unit.unit_id!="GGI" or not unit.is_deployed() or not R.enemy(unit,target) or not target is Unit:return null
	if target.is_air_target() or target.is_naval or AlliedAbilities.infantry(target) or target.embarked_in!=null:return null
	return target if unit._weapon_target_valid(target) else null

static func cast_anchor(unit,ab) -> bool:
	var target=anchor_target(unit)
	if target==null:return false
	var weapon:Dictionary=unit._active_weapon().duplicate(true)
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.expansion_anchor_slow=R.value(unit,ab.id,"slow")
	bonus.reference_weapon=weapon.duplicate(true)
	var muzzle:Vector2=unit._weapon_muzzle()
	var damage:=CombatMath.full_damage(weapon,target.armor,bonus,null,target.ra2_armor,0.0,target)
	var projectile:=Projectile.new()
	projectile.setup(muzzle,target,weapon,damage,bonus,unit.side,unit)
	unit._pick_projectile_parent().add_child(projectile)
	R.world(unit).reveal_attack(unit,target)
	unit._muzzle=.09;unit._fire_anim_time=0.0;unit._recoil=1.0;unit.special.reveal=2.0
	unit._spawn_muzzle_fx(muzzle,str(weapon.get("ra2_weapon_id","")));Ra2Sfx.play_weapon(weapon,muzzle)
	ab.trigger_cooldown();unit.queue_redraw()
	return true

static func hit(target,source,bonus:Dictionary) -> void:
	# The launched skill missile owns its slow, even after its shooter undeploys.
	if not source is Projectile or source.target!=target or not bonus.has("expansion_anchor_slow"):return
	if not target is Unit or target.is_air_target() or target.is_naval or AlliedAbilities.infantry(target) or target.embarked_in!=null:return
	if not AlliedAbilities.alive(target) or BattleRequest.friendly(source.owner_side,target.side):return
	target.add_buff("electric_slow",P.number("mechanic/core_v2","anchor_slow_seconds"),float(bonus.expansion_anchor_slow),"锚钉导弹")

static func absorb(unit,damage:float) -> float:
	if damage<=0 or not R.active(unit):return damage
	damage=Ground.absorb(unit,damage)
	damage=Armor.absorb(unit,damage)
	damage=Submarine.absorb(unit,damage)
	damage=Dread.absorb(unit,damage)
	damage=Naval.Relay.absorb(unit,damage)
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	if not s.has("module_shield"):return damage
	var shield:Dictionary=s.module_shield
	var absorbed:=minf(damage,float(shield.hp))
	shield.hp-=absorbed
	if shield.hp<=0:s.erase("module_shield")
	unit.queue_redraw()
	return damage-absorbed

static func can_attack(unit) -> bool:
	if not unit.special.has(KEY):return true
	return not R.active(unit) or float(unit.special.get(KEY,EMPTY).get("breather_left",0))<=0.0

static func speed(unit) -> float:
	if not unit.special.has(KEY):return 1.0
	if not R.active(unit):return 1.0
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	var factor := 1.0 + float(s.get("breather_speed", 0)) if float(s.get("breather_left", 0)) > 0 else 1.0
	if unit.unit_id == "DRON" and s.has("pounce_left"):
		factor *= Drone.speed(unit)
	if unit.unit_id == "SNIPE" and s.has("relocate_left"):
		factor *= Infantry.speed(unit)
	if s.has("ballast_left"):
		factor *= Naval.speed(unit)
	if s.has("shore_speed") or s.has("escort_buffs"):
		factor *= Infiltration.speed(unit)
	return factor

static func sight(unit) -> float:
	if not unit.special.has(KEY):return 0.0
	if not R.active(unit) or unit.embarked_in!=null:return 0.0
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	return Air.sight(unit)+(float(s.get("observer_cells",0))*R.CELL if float(s.get("observer_left",0))>0 and not unit._moving() else 0.0)

static func entries(unit) -> Array:
	if not unit.special.has(KEY):return []
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	var out:Array=[]
	out.append_array(Tractor.entries(unit))
	out.append_array(Ground.entries(unit))
	out.append_array(Soviet.entries(unit))
	out.append_array(Drone.entries(unit))
	out.append_array(Infantry.entries(unit))
	out.append_array(Armor.entries(unit))
	out.append_array(Naval.entries(unit))
	out.append_array(NavalFire.entries(unit))
	out.append_array(Submarine.entries(unit))
	out.append_array(Calibration.entries(unit))
	out.append_array(Convoy.entries(unit))
	out.append_array(Infiltration.entries(unit))
	out.append_array(Aircraft.entries(unit))
	out.append_array(Dread.entries(unit))
	out.append_array(Air.entries(unit))
	const V=preload("res://scripts/units/expansion_visual.gd")
	for spec in [["observer_left","观察哨线"],["breather_left","战线换气 · 停火加速"],["module_cd","模块封装冷却"],["rotation_cd","阵地轮值冷却"]]:
		if float(s.get(spec[0],0))>0:out.append(V.row(spec[1],s[spec[0]],false,spec[0]))
	if int(s.get("rotation_charges",0))>0:
		var item:=V.row("阵地轮值",0,false,"reload");item.stacks=s.rotation_charges;item.limit=P.count("mechanic/core_v2","rotation_count");out.append(item)
	if s.has("module_shield"):
		var item:=V.row("模块封装护盾",s.module_shield.left,false,"guard");item.text="剩余护盾 %.0f"%s.module_shield.hp;out.append(item)
	if unit.unit_id=="FV" and R.talent_rank(unit,"steady_seat")>=0 and AlliedAbilities.alive(s.get("crew")):
		out.append(V.row("稳座支架 · 维修模式不加速" if AlliedAbilities.is_repair_ifv(unit) else ("稳座支架 · 装填加速" if s.crew_age>=P.number("mechanic/core_v2","crew_prepare") else "稳座支架 · 乘坐计时"),maxf(0,P.number("mechanic/core_v2","crew_prepare")-float(s.crew_age)),false,"reload"))
	return out

static func draw(unit) -> void:
	Ground.draw(unit)
	Soviet.draw(unit)
	Drone.draw(unit)
	Infantry.draw(unit)
	Armor.draw(unit)
	Naval.draw(unit)
	NavalFire.draw(unit)
	Convoy.draw(unit)
	Infiltration.draw(unit)
	Air.draw(unit)
	Dread.draw(unit)
	var s:Dictionary=unit.special.get(KEY,EMPTY)
	if int(s.get("rotation_charges",0))>0:
		for i in P.count("mechanic/core_v2","rotation_count"):
			unit.draw_circle(Vector2(-7+i*7,-unit.radius-8-unit._visual_lift()),2.0,Color.GOLD if i<int(s.rotation_charges) else Color.DIM_GRAY)
