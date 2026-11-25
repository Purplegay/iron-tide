extends RefCounted
## Expedition threat and timed all-out attack.
const KEY := "expedition_red_alert"
const DURATION := 30.0
const THRESHOLD := 49000.0
const CAP := 50000.0

static func state(world) -> Dictionary:
	return world.allied_state.get_or_add(KEY,{"charge":0,"threat":0.0,"left":0.0})

static func setup(world,run:Dictionary,restored:bool) -> void:
	# Resume preserves this battle's snapshot. A new stage carries charges only.
	if restored:
		var saved:=state(world)
		saved.left=clampf(float(saved.left),0.0,DURATION)
		return
	world.allied_state[KEY]={"charge":0,"threat":0.0,"left":0.0}
	var s:=state(world)
	s.alert_level=preload("res://scripts/expedition/relics.gd").level(run,"alert_array")
	s.charge=clampi(int(run.get("red_alert_charge",0)),0,1)
	if preload("res://scripts/expedition/relics.gd").owned(run,"red_alert_warrant"):s.charge=1

static func active(world) -> bool:
	return is_instance_valid(world) and float(world.allied_state.get(KEY,{}).get("left",0.0))>0.0

static func production(world,side:String) -> float:
	return 2.0 if side=="ally" and active(world) else 1.0

static func activate(world) -> bool:
	if not is_instance_valid(world) or world.ended or world.paused or world.get_tree().paused:return false
	if not preload("res://scripts/expedition/rules.gd").active():return false
	var s:=state(world)
	if int(s.charge)<1 or float(s.left)>0:return false
	s.charge=0;s.threat=0.0;s.left=DURATION
	preload("res://scripts/world/battle_music_director.gd").trigger_uprising(world)
	apply_units(world)
	Events.emit_message("RED ALERT · %d 秒 · 全军升满军衔 · 生产耗时 -50%% · 攻速 +50%% · 威力 +30%%"%int(DURATION),Color("#ff5148"))
	return true

static func apply_units(world) -> void:
	var left:float=state(world).left
	if left<=0:return
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side!="ally":continue
		# RED ALERT restores the original emergency promotion: all allied
		# combatants are promoted immediately. _grant_veteran clamps to the
		# native cap, so RA2 units stop at Elite while RA3 heroes reach Heroic.
		if unit is Unit: unit._grant_veteran(3,false)
		unit.add_buff("red_alert_attack",left,0.30,"RED ALERT · 威力 +30%")
		unit.add_buff("red_alert_haste",left,0.50,"RED ALERT · 攻速 +50%")

static func tick(world,delta:float) -> void:
	var s:=state(world)
	if float(s.left)>0:
		s.left=maxf(0.0,float(s.left)-delta)
		if float(s.left)>0:apply_units(world)
		else:
			for unit in world.units:
				if world.actor_alive(unit):
					unit.clear_buff("red_alert_attack");unit.clear_buff("red_alert_haste")
			Music.set_red_alert(false)
			Events.emit_message("RED ALERT 总攻结束",Color("#e8c273"))
	elif int(s.charge)==0:
		var decay:=150.0 if float(s.threat)>=20000.0 and float(s.threat)<THRESHOLD else 50.0
		s.threat=maxf(0.0,float(s.threat)-decay*delta)

static func defeated(world,victim) -> void:
	if not is_instance_valid(victim) or victim.side=="neutral":return
	if victim.special.get("house_eliminated",false) or victim.special.has("expansion_temporary") or AlliedAbilities.flag(victim,"DontScore"):return
	if victim is Unit and victim.unit_id in world.SUPPORT_FLIGHTS:return
	var s:=state(world)
	if int(s.charge)>0 or float(s.left)>0:return
	var multiplier:=3.0 if victim.side=="ally" else 0.75 if not BattleRequest.friendly("ally",victim.side) else 0.0
	s.threat=minf(CAP,float(s.threat)+maxf(0.0,float(victim.data.get("cost",0)))*multiplier*(1.0+0.2*int(s.get("alert_level",0))))
	if float(s.threat)>=THRESHOLD:
		s.charge=1;s.threat=0.0
		Events.emit_message("威胁值达标 · RED ALERT 补充 1 次（1/1）",Color("#ff5148"))
