extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## New commando heroes own their state; none of the original escort/survival rules apply.
const IDS := ["TANY", "BORIS"]
const KEY := "commando_hero_v2"
const R = preload("res://scripts/units/expansion_rules.gd")
const TITLES := {"TANY":["破袭专家","极限脱身"],"BORIS":["前线指挥","战地电台"]}
const BASE_TEXT := {
	"TANY":["开始安装原生 C4 时，普通伤害减免 15%，持续 2 秒，触发间隔 12 秒；取消安装仍消耗本次机会。", "敌方单次实际生命伤害达到最大生命 15%，且本次攻击后仍存活，获得最大生命 10% 的护盾，持续 3 秒，触发间隔 30 秒。"],
	"BORIS":["视野增加 1 格，不增加步枪射程或米格呼叫距离。", "原地停留 2 秒后，普通远程伤害减免 15%；移动后保留 0.5 秒。"]
}

static func active(unit) -> bool:
	return unit.special.get("academy_hero","") in IDS and BattleRequest.extensions_enabled()

static func install(unit) -> void:
	if unit.special.has(KEY):return
	unit.special[KEY]={"origin":unit.position,"stationary":0.0}
	if unit.unit_id=="BORIS":unit.sight+=P.number("hero/BORIS/command","sight_cells")*R.CELL

static func tick(unit,dt:float) -> void:
	preload("res://scripts/units/boris_radio.gd").tick(unit,dt)
	preload("res://scripts/units/boris_fire_control.gd").tick(unit,dt)
	preload("res://scripts/units/tanya_breach.gd").tick(unit,dt)
	preload("res://scripts/units/tanya_talents.gd").tick(unit,dt)
	if not active(unit) or not AlliedAbilities.alive(unit):return
	var s:Dictionary=unit.special.get(KEY,{})
	if s.is_empty():return
	var had_rhythm:bool=s.has("rhythm_left")
	for key in ["c4_guard","c4_cd","escape_cd","radio_grace","rhythm_left","rhythm_cd"]:R.timer(s,key,dt)
	if had_rhythm and not s.has("rhythm_left"):unit._recompute_bonuses()
	if s.has("shield"):
		s.shield.left-=dt
		if s.shield.left<=0:s.erase("shield")
	var moved:bool=unit.position.distance_squared_to(s.origin)>0.000001
	s.origin=unit.position
	if unit.unit_id=="BORIS":
		if moved:
			if float(s.stationary)>=P.number("hero/BORIS/survival","stationary_seconds"):s.radio_grace=P.number("hero/BORIS/survival","move_grace")
			s.stationary=0.0
		else:s.stationary=minf(P.number("hero/BORIS/survival","stationary_seconds"),float(s.stationary)+dt)
	unit.queue_redraw()

static func c4_started(unit) -> void:
	if not active(unit) or unit.unit_id!="TANY" or not unit.special.has(KEY):return
	preload("res://scripts/units/tanya_talents.gd").attacking(unit)
	var s:Dictionary=unit.special[KEY]
	if s.has("c4_cd"):return
	s.c4_guard=P.number("hero/TANY/command","c4_guard_seconds");s.c4_cd=P.number("hero/TANY/command","c4_cooldown")
	unit.queue_redraw()

static func hostile(unit,source) -> bool:
	var actor=R.owner(source)
	return is_instance_valid(actor) and (actor is Unit or actor is Building) and actor.side!="neutral" and not BattleRequest.friendly(unit.side,actor.side)

static func defend(unit,amount:float,kind:String,bonus:Dictionary,source) -> float:
	if amount<=0 or not active(unit):return amount
	# Scripted extras, culling and removal are not ordinary weapon damage.
	if bonus.get("expansion_extra",false) or kind in ["crush","erase","execute"]:return amount
	var s:Dictionary=unit.special.get(KEY,{})
	if unit.unit_id=="TANY":
		if s.has("c4_guard"):amount*=1.0-P.number("hero/TANY/command","c4_defense")
		if s.has("rhythm_left") and kind in ["bullet","shell","missile","laser","electric","sniper"] and hostile(unit,source) and (not source is Projectile or is_same(source.target,unit)):amount*=1.0-float(s.rhythm_defense)
		return amount
	if kind not in ["bullet","shell","missile","laser","electric","sniper"] or not hostile(unit,source):return amount
	if source is Projectile and not is_same(source.target,unit):return amount
	return amount*(1.0-P.number("hero/BORIS/survival","ranged_defense")) if float(s.get("stationary",0))>=P.number("hero/BORIS/survival","stationary_seconds") or s.has("radio_grace") else amount

static func absorb(unit,amount:float) -> float:
	if amount<=0 or not active(unit):return amount
	amount=preload("res://scripts/units/tanya_talents.gd").absorb(unit,amount)
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("shield"):return amount
	var used:=minf(amount,float(s.shield.hp))
	s.shield.hp-=used
	if s.shield.hp<=0:s.erase("shield")
	return amount-used

static func injured(unit,source,health_loss:float) -> void:
	preload("res://scripts/units/tanya_talents.gd").injured(unit,source,health_loss)
	if not active(unit) or unit.unit_id!="TANY" or not unit.special.has(KEY) or unit.hp<=0 or health_loss<unit.max_hp*P.number("hero/TANY/survival","trigger_loss") or not hostile(unit,source):return
	var s:Dictionary=unit.special[KEY]
	if s.has("escape_cd"):return
	s.shield={"hp":unit.max_hp*P.number("hero/TANY/survival","escape_shield"),"left":P.number("hero/TANY/survival","escape_seconds")}
	s.escape_cd=P.number("hero/TANY/survival","escape_cooldown")
	unit.queue_redraw()

static func entries(unit) -> Array:
	if not active(unit):return []
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	out.append_array(preload("res://scripts/units/boris_fire_control.gd").entries(unit))
	out.append_array(preload("res://scripts/units/tanya_talents.gd").entries(unit))
	const V=preload("res://scripts/units/expansion_visual.gd")
	for item in [["c4_guard","破袭专家 · 减伤 15%"],["c4_cd","破袭专家冷却"],["escape_cd","极限脱身冷却"]]:
		if s.has(item[0]):out.append(V.row(item[1],s[item[0]],false,"guard"))
	if s.has("breach_throw"):out.append(V.row("三点破门 · 待投 %d 枚"%(3-int(s.breach_throw.index)),s.breach_throw.next,false,"explosive"))
	if s.has("rhythm_left"):out.append(V.row("破门节拍 · 移速 +25% / 远程减伤 %d%%"%roundi(s.rhythm_defense*100),s.rhythm_left,false,"speed"))
	if s.has("rhythm_cd"):out.append(V.row("破门节拍冷却",s.rhythm_cd,false,"reload"))
	if s.has("shield"):
		var row:=V.row("极限脱身护盾",s.shield.left,false,"guard")
		row.text="剩余护盾 %.0f"%s.shield.hp;out.append(row)
	if unit.unit_id=="BORIS":
		var ready:bool=float(s.get("stationary",0))>=P.number("hero/BORIS/survival","stationary_seconds")
		if ready or s.has("radio_grace"):out.append(V.row("战地电台 · 远程减伤 15%",float(s.get("radio_grace",0)),false,"guard"))
	return out

static func draw(unit) -> void:
	if not active(unit):return
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("shield"):return
	unit.draw_arc(Vector2(0,-unit._visual_lift()-8),unit.radius+8,0,TAU,24,Color(0.25,0.9,1,0.7),1.5,true)
