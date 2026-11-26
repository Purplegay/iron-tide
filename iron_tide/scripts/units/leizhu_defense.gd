extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="leizhu"
const OPEN_RANK=5
const DEFENSE_DEFAULT = [
	"线圈护套：连续停火 4 秒获得最大生命 8% 护盾，持续 6 秒、间隔 18 秒；移动可积累，不触发旧坦克英雄的破盾爆炸。",
	"反寄生放电：恐怖机器人成功寄生2秒后，存活且未被冻结／EMP时清除并摧毁该寄生体；放电间隔30秒。等待期间正常承受寄生伤害，控制期间不能放电。",
	"电能回收：受到敌方普通电击并存活后，将本次实际护盾与生命损失的20%转为独立回收盾，上限最大生命15%、持续4秒；不计算友伤、自伤或追加／转移伤害，不能挽救本次致命伤。",
	"绝缘缓行：被持续时空冻结时，可接受移动命令并以正常速度50%缓行，不能开火／施法；不清除冻结来源、不免疫擦除，走出合法维持距离才按原规则解除。EMP、装载与停堆仍禁止移动。",
	"分流保护：3格内最近一辆同方非英雄战斗地面载具，普通最终伤害的20%在护盾前转移；雷铸对该份伤害减免80%，再扣自己的盾与生命，不触发普通减伤、回收或再次分流。冻结／装载／EMP／停堆期间停用。",
	"紧急停堆：每局一次普通致命伤保留1生命，获得最大生命40%应急盾，停堆3秒；不能移动、攻击、施法、供电或分流，并清除电庭。存活至结束恢复到至少20%生命；后续伤害仍可击毁，不抵挡处决或时空擦除。"
]
static var DEFENSE:Array:
	get:return P.traits("hero/TTNK/survival",DEFENSE_DEFAULT)

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or unit.unit_id!="TTNK" or unit.special.get("academy_hero")!="TTNK" or not unit.special.has(KEY) or not R.active(unit):return -1
	return clampi(int(unit.special.get("hero_survival_rank",0)),0,OPEN_RANK)

static func entered(unit,drone) -> void:
	if rank(unit)<1:return
	var s:Dictionary=unit.special[KEY]
	s.purge_target=drone;s.purge_left=P.number("hero/TTNK/survival","purge_delay")
	unit.queue_redraw()

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special[KEY]
	if s.get("side",unit.side)!=unit.side:
		for key in ["purge_target","purge_left","purge_cd","purge_flash","recycled"]:s.erase(key)
		return
	for key in ["purge_cd","purge_flash"]:
		R.timer(s,key,maxf(0,dt))
		if float(s.get(key,0))<=.000001:s.erase(key)
	if s.has("recycled"):
		s.recycled.left-=maxf(0,dt)
		if s.recycled.left<=.000001:s.erase("recycled")
	if rank(unit)<1:return
	var drone=unit.special.get("parasite")
	if not AlliedAbilities.alive(drone) or drone.embarked_in!=unit:
		s.erase("purge_target");s.erase("purge_left");return
	if not is_same(s.get("purge_target"),drone):entered(unit,drone)
	s.purge_left=maxf(0,float(s.purge_left)-maxf(0,dt))
	if s.purge_left>.000001 or s.has("purge_cd") or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.embarked_in!=null:return
	preload("res://scripts/units/soviet_advanced.gd").cleanse(unit)
	s.erase("purge_target");s.erase("purge_left");s.purge_cd=P.number("hero/TTNK/survival","purge_cooldown");s.purge_flash=.4
	unit.queue_redraw()

static func absorb(unit,damage:float) -> float:
	if damage<=0 or rank(unit)<2:return damage
	var s:Dictionary=unit.special[KEY]
	if not s.has("recycled"):return damage
	var used:=minf(damage,float(s.recycled.hp));s.recycled.hp-=used
	if s.recycled.hp<=0:s.erase("recycled")
	unit.queue_redraw()
	return damage-used

static func injured(unit,source,kind:String,bonus:Dictionary,shield_loss:float,health_loss:float) -> void:
	if rank(unit)<2 or kind not in ["electric","tesla"] or bonus.get("expansion_extra",false) or bonus.get("leizhu_transfer",false) or bonus.get("equipment_secondary",false):return
	var owner=R.owner(source)
	if not is_instance_valid(owner) or not (owner is Unit or owner is Building) or owner.side=="neutral" or BattleRequest.friendly(owner.side,unit.side):return
	var gain:=maxf(0,shield_loss+health_loss)*P.number("hero/TTNK/survival","recycle_ratio")
	if gain<=0:return
	var s:Dictionary=unit.special[KEY]
	s.recycled={"hp":minf(unit.max_hp*P.number("hero/TTNK/survival","recycle_cap"),float(s.get("recycled",{}).get("hp",0))+gain),"left":P.number("hero/TTNK/survival","recycle_duration")}
	unit.queue_redraw()

static func entries(unit) -> Array:
	if rank(unit)<1:return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY];var rows:Array=[]
	if rank(unit)>=3:rows.append(V.row("绝缘缓行 · 持续冻结时可半速移动，仍会被擦除",0,false,"speed"))
	if s.has("purge_left"):rows.append(V.row("反寄生放电 · 等待控制解除" if unit._stun_timer>0 or AlliedAbilities.frozen(unit) else "反寄生放电 · 准备",s.purge_left,false,"electric"))
	if s.has("purge_cd"):rows.append(V.row("反寄生放电间隔",s.purge_cd,false,"electric"))
	if s.has("recycled"):
		var row:=V.row("电能回收",s.recycled.left,false,"guard");row.text="回收盾 %.0f"%s.recycled.hp;rows.append(row)
	return rows

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("purge_flash"):unit.draw_arc(Vector2.ZERO,unit.radius+35*(1-float(s.purge_flash)/.4),0,TAU,36,Color(.4,.9,1,clampf(s.purge_flash/.4,0,1)),3,true)
