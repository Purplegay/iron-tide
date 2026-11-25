extends RefCounted
## Read-only projection of the shields consumed by Unit.receive_hit. No combat state is created here.
const V2=[["module_shield","模块封装"],["prism_shield","余光护镜"],["bulkhead_shield","发射隔舱"],["pressure_shield","深潜耐压"],["water_relay_shield","余波接力"]]

static func add(rows:Array,title:String,value,maximum:float=-1) -> void:
	var hp:float=float(value.get("hp",0)) if value is Dictionary else float(value)
	if hp<=0:return
	if value is Dictionary:maximum=float(value.get("maximum",maximum))
	rows.append({"name":title,"hp":hp,"maximum":maxf(hp,maximum) if maximum>=0 else -1.0})

static func entries(unit) -> Array:
	var rows:Array=[]
	if unit._dead or unit.hp<=0:return rows
	var s:Dictionary=unit.special
	if unit is Building:
		if BattleRequest.is_ai_house(unit.side):add(rows,"建筑护盾",s.get("brutal_shield",0),unit.max_hp*0.5)
		return rows
	if s.has("furnace_prone"):
		add(rows,"熔炉壁垒",s.furnace_prone,Unit.TankHero.Shield.maximum(unit))
	elif s.has(Unit.TankHero.Shield.KEY):
		add(rows,"重装护盾",s[Unit.TankHero.Shield.KEY],Unit.TankHero.Shield.maximum(unit))
	var first:Dictionary=s.get("progression_v1",{})
	add(rows,"折光护盾",first.get("mirror_shield",{}))
	var scrap:=0.0
	for layer in first.get("scrap",[]):scrap+=maxf(0,float(layer))
	add(rows,"废铁装甲",scrap)
	if preload("res://scripts/units/expansion_rules.gd").active(unit):
		var second:Dictionary=s.get("progression_v2",{})
		for spec in V2:
			if spec[0] in ["bulkhead_shield","pressure_shield","water_relay_shield"] and second.get("side",unit.side)!=unit.side:continue
			add(rows,spec[1],second.get(spec[0],{}))
		add(rows,"护航弹仓",preload("res://scripts/units/expansion_2_dread.gd").shield(unit))
	if preload("res://scripts/expedition/rules.gd").eligible(unit):add(rows,"远征护盾",s.get("expedition_shield",0))
	if BattleRequest.extensions_enabled():
		var radio:Dictionary=s.get("boris_radio_shield",{})
		if radio.get("side",unit.side)==unit.side:add(rows,"电台掩护",radio)
		if s.get("academy_hero","") in ["TANY","BORIS"]:
			var commando:Dictionary=s.get("commando_hero_v2",{})
			add(rows,"极限脱身",commando.get("shield",{}))
			if s.get("academy_hero")=="TANY":add(rows,"泅渡护盾",commando.get("swim_shield",{}))
	if s.has("peregrine"):
		var plane:Dictionary=s.peregrine
		if preload("res://scripts/units/peregrine_cards.gd").active(unit) and unit.passive.get("id")=="ps_peregrine_rearm" and plane.get("side",unit.side)==unit.side:
			add(rows,"补弹残盾",plane.get("rearm_shield",0))
		add(rows,"停机护罩",plane.get("maintenance_shield",{}))
	if s.has("leizhu"):
		var tesla:Dictionary=s.leizhu
		if preload("res://scripts/units/leizhu.gd").active(unit):add(rows,"线圈护套",tesla.get("shield",{}))
		if preload("res://scripts/units/leizhu_command.gd").rank(unit)>=1:add(rows,"电磁夺盾",tesla.get("stolen",{}))
		if preload("res://scripts/units/leizhu_defense.gd").rank(unit)>=2:add(rows,"电能回收",tesla.get("recycled",{}))
		add(rows,"停堆应急盾",tesla.get("emergency_shield",0))
	return rows

static func amount(unit) -> float:
	var total:=0.0
	for row in entries(unit):total+=float(row.hp)
	return total

static func summary(unit) -> Dictionary:
	if unit._dead or unit.hp<=0 or unit.special.has("hero_wreck"):
		return {"amount":0.0,"visible":false,"text":"","details":""}
	var rows:=entries(unit);var current:=0.0;var maximum:=0.0;var known:=true
	var details:=PackedStringArray()
	for row in rows:
		current+=float(row.hp)
		if float(row.maximum)<0:known=false
		else:maximum+=float(row.maximum)
		details.append(str(row.name)+"："+HpBar.shield_number(row.hp))
	var stationary:bool=unit is Unit and (unit.special.has(Unit.Furnace.STANCE) or Unit.TankHero.active(unit))
	if stationary and Unit.TankHero.Shield.amount(unit)<=0:maximum+=Unit.TankHero.Shield.maximum(unit)
	var text:="护盾 "+HpBar.shield_number(current)
	if known:text+=" / "+HpBar.shield_number(maximum)
	return {"amount":current,"visible":current>0 or stationary,"text":text,"details":"\n".join(details)}
