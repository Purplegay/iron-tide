extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Separate TTNK hero state; ordinary Tesla tanks keep their original rules.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="leizhu"
const TITLES=["移动变电站","过载保险"]
const BASE_TEXT=["高压标定：普通主电击命中敌战斗地面载具后，标定 4 秒；本人下一次主电击对它增伤 10%，消耗标定且该发不重新施标。","线圈护套：连续停火 4 秒获得最大生命 8% 护盾，持续 6 秒、间隔 18 秒；移动可积累，不触发旧坦克英雄的破盾爆炸。"]
const OPEN_RANK=preload("res://scripts/units/leizhu_defense.gd").OPEN_RANK

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.unit_id=="TTNK" and unit.special.get("academy_hero")=="TTNK" and unit.special.has(KEY) and R.active(unit)

static func promote(_meta,world,unit) -> void:
	if not BattleRequest.extensions_enabled() or not AlliedAbilities.alive(unit) or unit.unit_id!="TTNK" or R.temporary(unit):return
	var deployed:Dictionary=world.allied_state.get_or_add("leizhu_deployed",{})
	if deployed.has(unit.side):return
	deployed[unit.side]=true
	if unit.side=="ally":world.allied_state.get_or_add("named_heroes",{})["TTNK"]=10
	unit.special.academy_hero="TTNK"
	unit.special.hero_command_rank=clampi(int(BattleRequest.combat_context.get("hero_escort_ranks",{}).get("TTNK",0)),0,preload("res://scripts/units/leizhu_command.gd").OPEN_RANK) if unit.side=="ally" else 0
	unit.special.hero_survival_rank=clampi(int(BattleRequest.combat_context.get("hero_survival_ranks",{}).get("TTNK",0)),0,OPEN_RANK) if unit.side=="ally" else 0
	unit.display_name="英雄 · 雷铸"
	unit.equip_hero_cards()
	var academy=MetaProgress.Academy
	var training:Dictionary=BattleRequest.combat_context.get("hero_training",{}) if unit.side=="ally" else {}
	var scale:float=BattleRequest.combat_context.get("hero_training_scale",academy.HERO_TRAINING_SCALE)
	unit._grant_veteran(int(GameData.ra2_veteran_rules().get("cap",2)),false)
	unit._base_max_hp*=1.0+.01*academy.training_percent("health",academy.training_rank(training,"TTNK","health"),scale)
	unit.max_hp=unit._base_max_hp;unit.hp=unit.max_hp
	unit._base_atk*=CombatMath.additional_growth_ratio(unit.bonuses,1.0+.01*academy.training_percent("firepower",academy.training_rank(training,"TTNK","firepower"),scale))
	unit.special[KEY]={"quiet":0.0,"marks":{},"side":unit.side}
	preload("res://scripts/units/leizhu_command.gd").install(unit)
	preload("res://scripts/units/leizhu_safety.gd").install(unit)
	unit._recompute_bonuses();unit._refresh_weapon_derived();unit.refresh_house_color()

static func tick(unit,dt:float) -> void:
	if not active(unit):return
	var s:Dictionary=unit.special[KEY]
	preload("res://scripts/units/leizhu_safety.gd").tick(unit,dt)
	preload("res://scripts/units/leizhu_cards.gd").tick(unit,dt)
	preload("res://scripts/units/leizhu_command.gd").tick(unit,dt)
	preload("res://scripts/units/leizhu_defense.gd").tick(unit,dt)
	if s.side!=unit.side:
		s.marks.clear();s.erase("shield");s.quiet=0.0;s.side=unit.side
	var marks:Dictionary=s.marks
	for target in marks.keys():
		if not R.enemy(unit,target) or target.side!=marks[target].side:marks.erase(target);continue
		marks[target].left-=maxf(0,dt)
		if marks[target].left<=0.000001:marks.erase(target)
	var previous_cd:float=s.get("shield_cd",0)
	R.timer(s,"shield_cd",maxf(0,dt))
	if previous_cd<=maxf(0,dt)+0.000001:s.erase("shield_cd")
	if s.has("shield"):
		s.shield.left-=maxf(0,dt)
		if s.shield.left<=0.000001:s.erase("shield")
	if unit.embarked_in!=null:return
	var wait:=maxf(maxf(0,P.number("hero/TTNK/survival","shield_wait")-float(s.quiet)),previous_cd)
	s.quiet=minf(P.number("hero/TTNK/survival","shield_wait"),float(s.quiet)+maxf(0,dt))
	if dt+0.000001>=wait and not s.has("shield_cd"):
		var remainder:=fposmod(maxf(0,dt-wait),P.number("hero/TTNK/survival","shield_cooldown"))
		s.shield={"hp":unit.max_hp*P.number("hero/TTNK/survival","shield_hp"),"left":P.number("hero/TTNK/survival","shield_duration")-remainder}
		s.shield_cd=P.number("hero/TTNK/survival","shield_cooldown")-remainder
		if s.shield.left<=0:s.erase("shield")
		if s.shield_cd<=0:s.erase("shield_cd")
	unit.queue_redraw()

static func shot(unit,bonus:Dictionary,target=null) -> void:
	if not active(unit):return
	bonus.leizhu_primary=true;bonus.leizhu_side=unit.side
	preload("res://scripts/units/leizhu_command.gd").shot(unit,target,bonus)
	unit.special[KEY].quiet=0.0

static func impact(target,source,amount:float,bonus:Dictionary) -> float:
	if amount<=0 or not bonus.get("leizhu_primary",false) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return amount
	var unit=R.owner(source)
	if not active(unit) or unit.side!=bonus.get("leizhu_side") or not R.enemy(unit,target) or not preload("res://scripts/rules/expansion_contracts.gd").vehicle(target):return amount
	if source is Projectile and source.target!=target:return amount
	var marks:Dictionary=unit.special[KEY].marks
	if marks.has(target) and float(marks[target].left)>0 and marks[target].side==target.side:
		marks.erase(target);unit.queue_redraw();return amount*P.number("hero/TTNK/command","mark_damage")
	marks[target]={"left":P.number("hero/TTNK/command","mark_duration"),"side":target.side}
	unit.queue_redraw()
	return amount

static func absorb(unit,amount:float) -> float:
	if amount<=0 or not active(unit) or not unit.special[KEY].has("shield"):return amount
	var shield:Dictionary=unit.special[KEY].shield
	var used:=minf(amount,float(shield.hp));shield.hp-=used
	if shield.hp<=0:unit.special[KEY].erase("shield")
	unit.queue_redraw()
	return amount-used

static func entries(unit) -> Array:
	if not active(unit):return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY]
	var rows:Array=[V.row("雷铸 · 停火护套准备",maxf(0,P.number("hero/TTNK/survival","shield_wait")-float(s.quiet)),false,"guard")]
	for target in s.marks:
		if AlliedAbilities.alive(target):rows.append(V.row("高压标定 · "+target.display_name,s.marks[target].left,false,"attack"))
	if s.has("shield"):
		var row:=V.row("线圈护套",s.shield.left,false,"guard");row.text="护套盾 %.0f"%s.shield.hp;rows.append(row)
	if s.has("shield_cd"):rows.append(V.row("线圈护套触发间隔",s.shield_cd,false,"guard"))
	rows.append_array(preload("res://scripts/units/leizhu_cards.gd").entries(unit))
	rows.append_array(preload("res://scripts/units/leizhu_defense.gd").entries(unit))
	rows.append_array(preload("res://scripts/units/leizhu_safety.gd").entries(unit))
	return rows

static func draw(unit) -> void:
	preload("res://scripts/units/leizhu_safety.gd").draw(unit)
	preload("res://scripts/units/leizhu_command.gd").draw(unit)
	preload("res://scripts/units/leizhu_cards.gd").draw(unit)
	preload("res://scripts/units/leizhu_defense.gd").draw(unit)
