extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const KEY="commando_hero_v2"
const R=preload("res://scripts/units/expansion_rules.gd")
const COMMAND_DEFAULT = [
	"破拆预备：开始安装原生 C4 后普通减伤 15%，持续 2 秒，间隔 12 秒。",
	"近距识破：侦测 2 格内敌方隐形／伪装地面单位；实体遮挡会阻断，不侦测潜艇。",
	"双枪分击：每第三轮普通双枪开火，向主目标 1 格内另一名最近可见敌步兵追加攻击力 40% 的普通枪伤，不复制处决。",
	"破拆震波：本人原生 C4 摧毁建筑后，对地基外 1.5 格内可见敌地面单位造成攻击力 60% 的普通爆破伤害，不伤建筑。",
	"行进双枪：普通移动中可向射程内合法敌步兵开火；开枪动作期间以当前速度的 70% 行进，不改变移动路线。",
	"连锁拆除：原生 C4 拆楼后向地基间距 1.5 格内最近可见合法敌建筑附着 4 秒链式 C4，可由工程师拆除；间隔 60 秒，每局最多 2 次，不递归。"
]
static var COMMAND:Array:
	get:return P.traits("hero/TANY/command",COMMAND_DEFAULT)
const DEFENSE_DEFAULT = [
	"脱离杀线：单次敌伤实际扣除最大生命至少 15% 且存活，获得最大生命 10% 护盾，持续 3 秒，间隔 30 秒。",
	"反猎杀训练：犬扑、狙击与步兵普通枪击的致命单击最多扣除最大生命 1/3，低血仍会死；不限制坦克炮击。",
	"潜泳：水中停火 2 秒隐形；攻击、安装炸药、受伤或离水解除。真正破隐后获得最大生命 15% 护盾、持续 4 秒，间隔 15 秒；护盾不抵扣触发破隐的伤害。",
	"翻越履带：免疫普通地面载具碾压，仍受武器伤害，不获得穿越车辆或墙体的能力。",
	"闪光脱离：敌伤使生命低于 25% 且存活时，使 2 格内可见敌步兵停止开火 1.5 秒，间隔 40 秒；须恢复到阈值以上才可再次触发。",
	"最后一搏：每局一次，普通致命伤保留 1 点生命并隐形 2 秒，清除当前普通减速；2 秒内不能攻击或施法，仍可移动，后续伤害可破隐或致死。"
]
static var DEFENSE:Array:
	get:return P.traits("hero/TANY/survival",DEFENSE_DEFAULT)

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.special.get("academy_hero")=="TANY" and unit.special.has(KEY) and BattleRequest.extensions_enabled()

static func rank(unit,defense:=false) -> int:
	return clampi(int(unit.special.get("hero_survival_rank" if defense else "hero_command_rank",0)),0,5) if active(unit) else -1

static func locked(unit) -> bool:
	return active(unit) and unit.special[KEY].has("last_lock")

static func silenced(unit) -> bool:
	return unit.special.has("tanya_flash_left") or locked(unit)

static func tick(unit,dt:float) -> void:
	if not active(unit) or not AlliedAbilities.alive(unit):return
	var s:Dictionary=unit.special[KEY]
	for key in ["swim_shield_cd","flash_cd","chain_cd","last_cloak","last_lock"]:R.timer(s,key,dt)
	if s.has("swim_shield"):
		s.swim_shield.left-=dt
		if s.swim_shield.left<=0:s.erase("swim_shield")
	if unit.hp>=unit.max_hp*P.number("hero/TANY/survival","flash_threshold"):s.flash_armed=true
	if rank(unit,true)<2:return
	var water:bool=R.world(unit).in_water_world(unit.position)
	if not water or unit.embarked_in!=null:
		break_swim(unit);s.swim_quiet=0.0;return
	if unit.special.get("c4_stage","") in ["enter","exit"] or AlliedAbilities.frozen(unit):
		break_swim(unit);s.swim_quiet=0.0;return
	s.swim_quiet=float(s.get("swim_quiet",0))+dt
	if s.swim_quiet>=P.number("hero/TANY/survival","swim_quiet") and not s.has("swimming"):
		s.swimming=true;unit.queue_redraw()

static func break_swim(unit,defer_shield:=false) -> void:
	if not active(unit):return
	var s:Dictionary=unit.special[KEY]
	s.swim_quiet=0.0
	if not s.erase("swimming"):return
	if defer_shield:s.swim_exit_pending=true
	else:swim_shield(unit)
	unit.queue_redraw()

static func swim_shield(unit) -> void:
	var s:Dictionary=unit.special[KEY]
	s.erase("swim_exit_pending")
	if not AlliedAbilities.alive(unit) or s.has("swim_shield_cd"):return
	s.swim_shield={"hp":unit.max_hp*P.number("hero/TANY/survival","swim_shield"),"left":P.number("hero/TANY/survival","swim_duration")};s.swim_shield_cd=P.number("hero/TANY/survival","swim_cooldown")
	unit.queue_redraw()

static func attacking(unit) -> void:
	break_swim(unit)

static func hidden(unit) -> bool:
	return active(unit) and (unit.special[KEY].has("swimming") or unit.special[KEY].has("last_cloak"))

static func absorb(unit,amount:float) -> float:
	if amount<=0 or not active(unit):return amount
	var s:Dictionary=unit.special[KEY]
	if not s.has("swim_shield"):return amount
	var used:=minf(amount,float(s.swim_shield.hp));s.swim_shield.hp-=used
	if s.swim_shield.hp<=0:s.erase("swim_shield")
	return amount-used

static func before_damage(unit,amount:float,kind:String,bonus:Dictionary,source,warhead:String) -> float:
	if not active(unit) or amount<=0:return amount
	var s:Dictionary=unit.special[KEY]
	var level:=rank(unit,true)
	if kind=="crush" and level>=3:return 0.0
	s.erase("last_cloak");break_swim(unit,true)
	if kind in ["crush","erase","execute"] or bonus.get("force_execute",false):return amount
	var attacker=R.owner(source)
	var normal:bool=not bonus.get("expansion_extra",false)
	var gun:=str(bonus.get("impact_weapon","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	var dog:bool=warhead.trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")=="ParasiteDog"
	var rifle:bool=AlliedAbilities.infantry(attacker) and kind in ["bullet","sniper"]
	if level>=1 and normal and amount>=unit.hp and (dog or rifle or gun in ["AWP","AWPE","CRAWP","Sniper","MP5","MP5E","DoublePistols","DoublePistolsE"]):amount=minf(amount,unit.max_hp*P.number("hero/TANY/survival","lethal_cap"))
	if level>=5 and normal and amount>=unit.hp and not s.get("last_used",false):
		s.last_used=true;s.last_cloak=P.number("hero/TANY/survival","last_cloak");s.last_lock=P.number("hero/TANY/survival","last_lock")
		unit._cancel_burst()
		if unit.special.get("action","")=="allied_c4":AlliedAbilities.cancel(unit)
		unit.buffs=unit.buffs.filter(func(buff):return buff.get("kind","")!="electric_slow" and not (buff.get("kind","")=="speed" and float(buff.get("value",0))<0))
		unit._recompute_bonuses();unit.queue_redraw()
		return maxf(0,unit.hp-P.number("hero/TANY/survival","last_hp"))
	return amount

static func injured(unit,source,health_loss:float) -> void:
	if not active(unit):return
	var s:Dictionary=unit.special[KEY]
	if s.has("swim_exit_pending"):swim_shield(unit)
	if not AlliedAbilities.alive(unit) or health_loss<=0 or rank(unit,true)<4 or unit.hp>=unit.max_hp*P.number("hero/TANY/survival","flash_threshold") or not hostile(unit,source):return
	if s.has("flash_cd") or not s.get("flash_armed",true):return
	s.flash_armed=false;s.flash_cd=P.number("hero/TANY/survival","flash_cooldown")
	var world=R.world(unit)
	for target in world.neighborhood.nearby(unit.position,P.number("hero/TANY/survival","flash_radius")*R.CELL,true):
		if not R.enemy(unit,target) or not AlliedAbilities.infantry(target) or target.embarked_in!=null or not world.actor_visible_to(unit.side,target) or AlliedAbilities.concealed(target,unit.side):continue
		if target.position.distance_to(unit.position)>P.number("hero/TANY/survival","flash_radius")*R.CELL:continue
		target.special.tanya_flash_left=P.number("hero/TANY/survival","flash_seconds");target._cancel_burst();target.queue_redraw()
	Effects.spawn_impact(unit.position,Color(1,.98,.8),P.number("hero/TANY/survival","flash_radius")*R.CELL)

static func hostile(unit,source) -> bool:
	var actor=R.owner(source)
	return is_instance_valid(actor) and (actor is Unit or actor is Building) and actor.side!="neutral" and not BattleRequest.friendly(unit.side,actor.side)

static func entries(unit) -> Array:
	if not active(unit):return []
	var s:Dictionary=unit.special[KEY]
	const V=preload("res://scripts/units/expansion_visual.gd")
	var out:Array=[]
	if rank(unit)>=1:out.append(V.row("近距识破 · 2 格",0,false,"sight"))
	if rank(unit)>=2:out.append(V.row("双枪分击 · %d/3 轮"%(int(s.get("split_round",0))%3),0,false,"split"))
	if s.has("swimming"):out.append(V.row("潜泳 · 已隐形",0,false,"sight"))
	if s.has("swim_shield"):out.append(V.row("潜泳护盾 · %.0f"%s.swim_shield.hp,s.swim_shield.left,false,"guard"))
	for pair in [["swim_shield_cd","潜泳护盾冷却"],["flash_cd","闪光脱离冷却"],["chain_cd","连锁拆除冷却"],["last_lock","最后一搏 · 禁止攻击/施法"]]:
		if s.has(pair[0]):out.append(V.row(pair[1],s[pair[0]],false,"hourglass"))
	if rank(unit)>=5:out.append(V.row("连锁拆除 · 剩余 %d/2"%(2-int(s.get("chain_used",0))),0,false,"explosive"))
	if rank(unit,true)>=5:out.append(V.row("最后一搏 · "+("本局已用" if s.get("last_used",false) else "本局可用"),0,false,"guard"))
	return out
