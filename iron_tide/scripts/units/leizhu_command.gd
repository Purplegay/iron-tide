extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="leizhu"
const CONTROL="leizhu_control"
const GROUP="leizhu_detectors"
const OPEN_RANK=5
const COMMAND_DEFAULT = [
	"高压标定：普通主电击命中敌战斗地面载具，标定4秒；本人下一发增伤10%，消耗且不重新施标。",
	"电磁夺盾：普通主电击实际打掉敌盾量的50%变为自身夺取盾，上限最大生命20%、持续6秒；有效夺取刷新时限，无盾不产生。",
	"电磁搜迹：本人周围3格侦测隐形／伪装敌地面载具，正常遮挡有效；不侦测步兵、飞机、潜艇，不揭开全图。",
	"传动闭锁：每第三次主电击直击同一敌地面载具，锁住移动1秒，仍可开火；转火或4秒未命中清计数，目标共用8秒间隔。",
	"贯地放电：停火3秒后下一次主电击，沿本人至主目标地面线段，对最近两个其他可见敌地面单位各造成攻击力30%电伤；间隔12秒，不穿阻挡，不递归。",
	"应急供电：基地基础缺电且在同方已完成建造场中心8格内时，实际供电+100；仍可移动作战。离距、失去建造场、冻结、EMP、阵亡或停堆即停止；补足后以排除英雄的基础收支判断，避免反复断供。"
]
static var COMMAND:Array:
	get:return P.traits("hero/TTNK/command",COMMAND_DEFAULT)

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or unit.unit_id!="TTNK" or unit.special.get("academy_hero")!="TTNK" or not unit.special.has(KEY) or not R.active(unit):return -1
	return clampi(int(unit.special.get("hero_command_rank",0)),0,OPEN_RANK)

static func install(unit) -> void:
	if rank(unit)>=2 and not unit.is_in_group(GROUP):unit.add_to_group(GROUP)

static func direct(target,source,bonus:Dictionary) -> bool:
	if not bonus.get("leizhu_primary",false) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return false
	var owner=R.owner(source)
	if rank(owner)<0 or owner.side!=bonus.get("leizhu_side") or not R.enemy(owner,target) or R.temporary(target):return false
	return not source is Projectile or (source.target==target and source.owner_side==owner.side)

static func ground_vehicle(target) -> bool:
	return target is Unit and R.active(target) and not AlliedAbilities.infantry(target) and not target.is_air_target() and not target.is_naval and target.embarked_in==null and not NavalContact.underwater_type(target)

static func steal(target,source,bonus:Dictionary,absorbed:float) -> void:
	if absorbed<=0 or not direct(target,source,bonus):return
	var unit=R.owner(source)
	if rank(unit)<1:return
	var s:Dictionary=unit.special[KEY]
	s.stolen={"hp":minf(unit.max_hp*P.number("hero/TTNK/command","steal_cap"),float(s.get("stolen",{}).get("hp",0))+absorbed*P.number("hero/TTNK/command","steal_ratio")),"left":P.number("hero/TTNK/command","steal_duration")}
	unit.queue_redraw()

static func absorb(unit,amount:float) -> float:
	if rank(unit)<1 or amount<=0 or not unit.special[KEY].has("stolen"):return amount
	var shield:Dictionary=unit.special[KEY].stolen
	var used:=minf(amount,float(shield.hp));shield.hp-=used
	if shield.hp<=0:unit.special[KEY].erase("stolen")
	unit.queue_redraw();return amount-used

static func tick(unit,dt:float) -> void:
	install(unit)
	var s:Dictionary=unit.special[KEY]
	if s.get("side",unit.side)!=unit.side:
		for key in ["stolen","drive_target","drive_count","drive_left","pierce_cd","pierce_flash"]:s.erase(key)
	if s.has("stolen"):
		s.stolen.left-=maxf(0,dt)
		if s.stolen.left<=0.000001:s.erase("stolen")
	R.timer(s,"pierce_cd",maxf(0,dt))
	if float(s.get("pierce_cd",0))<=.000001:s.erase("pierce_cd")
	if s.has("pierce_flash"):
		s.pierce_flash.left-=maxf(0,dt)
		if s.pierce_flash.left<=0:s.erase("pierce_flash")
	R.timer(s,"drive_left",maxf(0,dt))
	if float(s.get("drive_left",0))<=0.000001 or not R.enemy(unit,s.get("drive_target")):
		for key in ["drive_target","drive_count","drive_left"]:s.erase(key)

static func shot(unit,target,bonus:Dictionary) -> void:
	preload("res://scripts/units/leizhu_station.gd").prepare(unit,target,bonus)
	if rank(unit)<3:return
	var s:Dictionary=unit.special[KEY]
	if not is_same(s.get("drive_target"),target):
		for key in ["drive_target","drive_count","drive_left"]:s.erase(key)

static func hit(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not direct(target,source,bonus):return
	var unit=R.owner(source)
	if rank(unit)<3:return
	var s:Dictionary=unit.special[KEY]
	if not ground_vehicle(target):
		for key in ["drive_target","drive_count","drive_left"]:s.erase(key)
		return
	s.drive_count=int(s.get("drive_count",0))+1 if is_same(s.get("drive_target"),target) else 1
	s.drive_target=target;s.drive_left=P.number("hero/TTNK/command","lock_window")
	if s.drive_count<P.count("hero/TTNK/command","lock_hits"):return
	s.drive_count=0
	var control:Dictionary=target.special.get_or_add(CONTROL,{"side":target.side})
	if control.side!=target.side:control.clear();control.side=target.side
	if float(control.get("cd",0))>0:return
	control.left=P.number("hero/TTNK/command","lock_seconds");control.cd=P.number("hero/TTNK/command","lock_cooldown")
	target.velocity=Vector2.ZERO;target._recompute_bonuses();target.queue_redraw()

static func controlled(unit) -> bool:
	var s:Dictionary=unit.special.get(CONTROL,{})
	return BattleRequest.extensions_enabled() and s.get("side",unit.side)==unit.side and float(s.get("left",0))>0

static func control_tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special[CONTROL]
	if s.side!=unit.side or not BattleRequest.extensions_enabled():unit.special.erase(CONTROL);unit._recompute_bonuses();return
	for key in ["left","cd"]:
		R.timer(s,key,maxf(0,dt))
		if float(s.get(key,0))<=0.000001:s.erase(key)
	if s.is_empty() or not s.has("cd"):unit.special.erase(CONTROL)
	unit._recompute_bonuses();unit.queue_redraw()

static func detects(world,observer:String,target) -> bool:
	if not BattleRequest.extensions_enabled() or world==null or not ground_vehicle(target):return false
	if target.side=="neutral" or BattleRequest.friendly(observer,target.side):return false
	for scout in world.get_tree().get_nodes_in_group(GROUP):
		if scout.side!=observer or not world.is_ancestor_of(scout) or rank(scout)<2 or scout.embarked_in!=null or scout._stun_timer>0 or AlliedAbilities.frozen(scout):continue
		if scout.position.distance_to(target.position)>P.number("hero/TTNK/command","detect_cells")*R.CELL:continue
		var ray:=PhysicsRayQueryParameters2D.create(scout.global_position,target.global_position,1,[scout.get_rid(),target.get_rid()])
		if world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():return true
	return false

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[]
	if controlled(unit):rows.append(V.row("传动闭锁 · 不能移动，仍可开火",unit.special[CONTROL].left,true,"electric"))
	if rank(unit)<0:return rows
	var s:Dictionary=unit.special[KEY]
	if s.has("stolen"):
		var row:=V.row("电磁夺盾",s.stolen.left,false,"guard");row.text="夺取盾 %.0f"%s.stolen.hp;rows.append(row)
	if rank(unit)>=2:rows.append(V.row("电磁搜迹 · 3格敌地面载具",0,false,"radar"))
	if s.has("drive_target") and AlliedAbilities.alive(s.drive_target):rows.append(V.row("传动闭锁 · %d/3 · %s"%[s.drive_count,s.drive_target.display_name],s.drive_left,false,"electric"))
	if rank(unit)>=4:rows.append(V.row("贯地放电 · 间隔" if s.has("pierce_cd") else "贯地放电 · 停火准备",float(s.get("pierce_cd",maxf(0,3-float(s.get("quiet",0))))),false,"electric"))
	if rank(unit)>=5:rows.append(V.row("英雄供电 +100" if s.get("power_active",false) else "应急供电 · 待基地缺电及进入范围",0,false,"electric"))
	return rows

static func draw(unit) -> void:
	var state:Dictionary=unit.special.get(KEY,{})
	if state.has("pierce_flash"):
		for point:Vector2 in state.pierce_flash.points:unit.draw_line(Iso.dir(state.pierce_flash.origin-unit.position),Iso.dir(point-unit.position),Color(.4,.9,1,clampf(state.pierce_flash.left/.3,0,1)),2,true)
	if state.get("power_active",false):unit.draw_arc(Vector2.ZERO,unit.radius+15,0,TAU,32,Color(1,.8,.2,.7),1.5,true)
	if unit.special.get(KEY,{}).has("stolen"):unit.draw_arc(Vector2.ZERO,unit.radius+11,0,TAU,32,Color(.9,.7,.25,.8),2,true)
	if controlled(unit):
		unit.draw_line(Vector2(-unit.radius,5),Vector2(unit.radius,5),Color.CYAN,3)
