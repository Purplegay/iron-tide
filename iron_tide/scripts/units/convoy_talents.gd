extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const CELL=55.0
const TITLES={"FV":["领航胶卷","末车守则"],"HARV":["战地采办","压机炮班"]}
const TRAITS={
	"FV": [
		[
			"勘路镜。实驶两格，视野增加两格，持续四秒。",
			"搭顺风车。步兵普通登车、首次登车晋升或 W 选人成功入座，均触发三秒 15% 加速。同一次入座只算一次，共用十五秒冷却。",
			"弯道灯。两秒内实驶一格并转向超过 60°，在弯心生成独立地面 token。半径四格、持续六秒，进入范围的每个己方地面单位均获三秒 15% 加速，每个 token 对每人一次。独立编号、范围圈和倒计时，触发间隔十二秒。",
			"战地除虫。每八秒一次维修脉冲，优先清除三格内一辆己方车上的敌方恐怖机器人，含引片自身；范围内没有寄生时，可改为给一台受损的己方恐怖机器人恢复 20% 最大生命。有效治疗或清除后才进冷却。",
			"高位观察。实际地速连续三秒不高于本车常规全速的 50% 即展开探测，发现三格内隐形敌方地面车辆。停车与慢行都计时，重新高速行驶立即收镜并重置。",
			"集中放行。引片被敌方攻击命中时获得十秒减伤，触发这一击即享 90%，随后按对数曲线衰减至零。触发起三十秒冷却，期间受击不刷新。建议减伤率 R(t)=90% × [1−ln(1+0.3t)/ln(4)]，t 为经过秒数，0／1／5／10 秒约为 90%／73%／31%／0%。"
		],
		[
			"靠边检修。停车脱战四秒，每秒自修 1%，最多修到半血。",
			"同车授勋。乘员每实际获得 1 点战斗经验，引片同步得到 1 点。保留乘员原经验；同一事件引片已直接获得的那一份去重，共享经验不再回传。",
			"安全下车。实体步兵成功下车即获两秒无敌，期间所受伤害为零。每名步兵间隔二十秒。",
			"急救力场。自身或三格内己方地面单位低于 50% 生命时展开四格力场，持续五秒。每秒为圈内低于半血的友军各恢复最大生命的 4%，单次场最多五跳，三十秒冷却，从展开时起算。",
			"镜幕断锁。三格内其他己方地面友军被敌方制导弹锁定后，引片放出一枚镜像诱饵，引走最早将要命中的一枚可拦截制导弹。攻击落到诱饵位置并按原弹头结算，间隔十八秒。",
			"紧急拖救。每局首次有两格内其他己方地面车辆被敌方从 20% 生命以上打到 20% 或以下且存活，授予其 15% 最大生命护盾六秒。"
		]
	],
	"HARV": [
		[
			"矿区哨位。停在未采空矿点一格内，视野增加两格。",
			"双斗取样。每铲双倍，仓容提升到原来的 200%。热锭始终每发消耗原仓的 25%，满仓八发。",
			"废钢回炉。亲自击毁敌方地面战车时，回收等于原仓 5% 的普通矿料进入货仓，余位封顶。由此获得的是战利品，不计入采矿任务。",
			"带料起步。载货至少原仓四分之一，起步时获得两秒 15% 移速，间隔十二秒。",
			"矿斗配重。用矿吸收最多一半即将扣到车体生命的敌方伤害。每消耗原仓 1% 可免去最大生命 1% 的损失，可按小数换算。例：最大生命 1000，即将扣 200，花 10% 原仓矿后实扣 100；只余 3% 矿则实扣 170。护盾已吸收部分不耗矿。",
			"流动抢修站。老秤停车时，三格内其他己方战车低于半血，可从车上拨出 10% 原仓矿，放出一台抢修机，六秒内每秒修复该车 4% 最大生命。自动优先最低血比，间隔三十秒；车主仍能随时带余矿离开。"
		],
		[
			"架稳。车体停下即可取得对敌地面车辆与建筑的普攻增伤 10%。停车期间持续生效，实际移动时结束。",
			"第三发分火。每三轮原生普攻，第三轮额外向主目标两格内另一个合法射程内敌人开一发，按原生单发 100% 结算。自动选最近副目标，无副目标则该轮只打主目标；副弹不推进轮数。",
			"盯履带。连续三次普攻命中同一敌车，使其减速 15% 两秒，每目标间隔十二秒。",
			"压线。初始体积值 100%，本人每击毁一个敌人 +20 个百分点，最高 500%。达 200% 可碾卧倒步兵；300% 追加天启碾压档；500% 再追加盟军战斗要塞碾压档。各档累积。按击杀身份只记一次，本车本局保存，5／10／20 次击杀分别达档。",
			"拆工事。连续三次普攻命中同一敌建筑后，第四击在命中点追加一次半径 1.5 格的攻城溅射。范围内敌方地面单位和建筑各受原生单发 20% 的伤害，主建筑可吃一次溅射，随后清零。",
			"压轴一发。老秤亲自摧毁敌方已部署基地（建造场）、维修厂或作战实验室，在该建筑原址释放一次 10% 威力的游戏核弹。爆炸伤害=该位置标准核弹爆炸伤害 × 发射时本方核弹科技树倍率 × 10%，沿用爆炸范围和衰减，仅产生瞬时爆炸。每座被毁建筑一次，奖励爆炸不连锁触发本天赋。"
		]
	]
}

static func tick(u,dt:float) -> void:
	var s:Dictionary=u.special.convoy
	var pos:Vector2=u.position
	var moved:float=s.position.distance_to(pos)
	var heading:float=s.position.direction_to(pos).angle() if moved>.01 else float(s.heading)
	var a:int=u.special.hero_command_rank
	var b:int=u.special.hero_survival_rank
	if u.unit_id=="FV":
		s.travel=float(s.get("travel",0))+moved
		if s.travel>=2*CELL:s.scout=4.0;s.travel=0.0
		R.timer(s,"scout",dt)
		u.sight=float(s.base_sight)+(2*CELL if s.has("scout") else 0.0)
		s.slow_time=float(s.get("slow_time",0))+dt if u.velocity.length()<=u._base_speed*.5 else 0.0
		s.quiet=float(s.get("quiet",0))+dt if moved<.01 else 0.0
		if s.quiet>=4 and u.hp<u.max_hp*.5:u.heal(minf(u.max_hp*.5-u.hp,u.max_hp*.01*dt))
		if moved>.01:
			if not s.has("turn_origin"):
				s.turn_origin=pos;s.turn_heading=heading;s.turn_age=0.0
			s.turn_age+=dt
			if a>=2 and not s.has("lamp_cd") and s.turn_origin.distance_to(pos)>=CELL and absf(angle_difference(s.turn_heading,heading))>=PI/3:
				s.lamp_serial=int(s.get("lamp_serial",0))+1
				s.lamp={"point":pos,"seen":[],"left":6.0,"serial":s.lamp_serial}
				s.lamp_cd=12.0
				if not u.is_in_group("convoy_lamps"):u.add_to_group("convoy_lamps")
			if s.turn_age>=2 or s.has("lamp_cd"):s.erase("turn_origin")
		if s.has("lamp"):
			s.lamp.left-=dt
			if s.lamp.left<=0:s.erase("lamp")
	else:
		if a>=3 and moved>.01 and not s.get("moving",false) and u.cargo>=.25*s.base_hold and not s.has("start_cd"):
			u.add_buff("speed",2,.15,"带料起步");s.start_cd=12.0
		s.moving=moved>.01
	s.position=pos;s.heading=heading
	s.pulse=float(s.get("pulse",0))+dt
	if s.pulse<.25:return
	var elapsed:float=s.pulse
	s.pulse=0.0
	if u.unit_id=="HARV":
		var node=u.resource_node
		if not is_instance_valid(node) and u.velocity.length()<1:
			for ore in u.get_tree().get_nodes_in_group("resource_nodes"):
				if u._battle_world().is_ancestor_of(ore) and not ore.is_empty() and ore.position.distance_to(pos)<=CELL:
					node=ore;break
		u.sight=s.base_sight+(2*CELL if is_instance_valid(node) and not node.is_empty() and node.position.distance_to(pos)<=CELL and u.velocity.length()<1 else 0)
	if u.unit_id=="HARV" and a<5:return
	if u.unit_id=="FV" and a<3 and b<3 and not s.has("lamp"):return
	var friends:Array=[]
	for other in u._battle_world().neighborhood.nearby(pos,4*CELL,true):
		if other is Unit and AlliedAbilities.alive(other) and other.side==u.side and other.embarked_in==null and not other.is_air_target() and not other.is_naval and other.position.distance_to(pos)<=4*CELL:friends.append(other)
	if u not in friends:friends.append(u)
	if u.unit_id=="HARV":
		if a>=5:repair_station(u,s,friends,elapsed)
		return
	if s.has("lamp"):
		var lamp:Dictionary=s.lamp
		for other in u._battle_world().neighborhood.nearby(lamp.point,4*CELL,true):
			if other is Unit and other.side==u.side and AlliedAbilities.alive(other) and other.embarked_in==null and not other.is_air_target() and not other.is_naval and other not in lamp.seen and other.position.distance_to(lamp.point)<=4*CELL:
				lamp.seen.append(other);other.add_buff("speed",3,.15,"弯道灯")
	if a>=3 and not s.has("cleanse_cd"):
		var drone=null
		for other in friends:
			if other.position.distance_to(pos)>3*CELL:continue
			if AlliedAbilities.alive(other.special.get("parasite")):
				preload("res://scripts/units/soviet_advanced.gd").cleanse(other,true);s.cleanse_cd=8.0;break
			if other.unit_id=="DRON" and other.hp<other.max_hp:drone=other
		if not s.has("cleanse_cd") and drone!=null:drone.heal(drone.max_hp*.2);s.cleanse_cd=8.0
	if b>=3:
		if not s.has("field_cd"):
			for other in friends:
				if other.hp<.5*other.max_hp and pos.distance_to(other.position)<=3*CELL:
					s.field_cd=30.0;s.field_ticks=5;s.field_age=0.0;break
		if int(s.get("field_ticks",0))>0:
			s.field_age+=elapsed
			while s.field_age>=1 and s.field_ticks>0:
				s.field_age-=1;s.field_ticks-=1
				for other in friends:
					if other.hp<other.max_hp*.5:other.heal(other.max_hp*.04)
	var w=u._battle_world()
	if b>=4 and not s.has("mirror_cd"):
		var chosen=null
		var best:=INF
		for shot in w.projectiles_root.get_children():
			if not shot is Projectile or not shot.ra2_homing or shot.target not in friends or shot.target==u or BattleRequest.friendly(shot.owner_side,u.side):continue
			if pos.distance_to(shot.target.position)>3*CELL:continue
			var eta:float=shot.position.distance_to(shot.target.position)/maxf(1,shot.speed)
			if eta<best:chosen=shot;best=eta
		if chosen!=null:
			chosen.target_point=pos+Vector2.from_angle(u.hull_angle+PI*.5)*CELL
			chosen.target=null;chosen.ra2_homing=false;s.mirror_cd=18.0

static func repair_station(u,s:Dictionary,friends:Array,elapsed:float) -> void:
	if not s.has("repair_cd") and u.velocity.length()<1 and u.cargo>=.1*s.base_hold:
		var best=null
		for other in friends:
			if other==u or AlliedAbilities.infantry(other) or u.position.distance_to(other.position)>3*CELL or other.hp>=.5*other.max_hp:continue
			if best==null or other.hp/other.max_hp<best.hp/best.max_hp:best=other
		if best!=null:
			var cost:float=s.base_hold*.1
			u.cargo_gems*=1-cost/u.cargo;u.cargo-=cost
			s.repair_target=best;s.repair_cd=30.0;s.repair_age=0.0;s.repair_ticks=6
	if AlliedAbilities.alive(s.get("repair_target")) and int(s.get("repair_ticks",0))>0:
		s.repair_age+=elapsed
		while s.repair_age>=1 and s.repair_ticks>0:
			s.repair_age-=1;s.repair_ticks-=1
			s.repair_target.heal(s.repair_target.max_hp*.04)

static func rescue(target,previous:float) -> void:
	if not target is Unit or target.hp<=0 or target.hp>target.max_hp*.2 or previous<=target.max_hp*.2 or AlliedAbilities.infantry(target) or target.is_air_target() or target.is_naval:return
	var world=target._battle_world()
	if world==null:return
	for u in world.neighborhood.nearby(target.position,2*CELL,true):
		if u==target or not AlliedAbilities.alive(u) or u.side!=target.side or u.special.get("academy_hero")!="FV" or u.special.hero_survival_rank<5 or u.special.convoy.get("rescued",false):continue
		if u.position.distance_to(target.position)>2*CELL:continue
		u.special.convoy.rescued=true
		target.special.convoy_rescue_shield=target.max_hp*.15
		target.add_buff("convoy_rescue",6,1,"紧急拖救")
		return

static func hit(u,target) -> void:
	if u.unit_id!="HARV":return
	var s:Dictionary=u.special.convoy
	if s.get("last_target")!=target:s.same_hits=0
	s.last_target=target;s.same_hits=int(s.get("same_hits",0))+1
	if u.special.hero_survival_rank>=2 and target is Unit and not AlliedAbilities.infantry(target) and s.same_hits%3==0 and target.buff_value("convoy_track_cd")==0:
		target.add_buff("electric_slow",2,.15,"盯履带");target.add_buff("convoy_track_cd",12,1,"履带保护")
	if u.special.hero_survival_rank>=4 and target is Building and s.same_hits%4==0:
		R.area(u,target.closest_footprint_point(u.position),1.5*CELL,.2)

static func split_fire(u,target) -> void:
	if u.special.hero_survival_rank<1 or int(u.special.convoy.volley)%3!=0:return
	var best=null
	var dist:=INF
	for actor in u._battle_world().neighborhood.nearby(target.position,2*CELL):
		if actor==target or not R.enemy(u,actor) or not u._weapon_target_valid(actor) or u.position.distance_to(R.point(u,actor))>u.attack_range:continue
		var d:float=actor.position.distance_to(target.position)
		if d<=2*CELL and d<dist:best=actor;dist=d
	if best!=null:R.hit(u,best,1,u.position)

static func detects(world,observer:String,target) -> bool:
	if not target is Unit or AlliedAbilities.infantry(target) or target.is_air_target() or target.is_naval or target.embarked_in!=null:return false
	for u in world.get_tree().get_nodes_in_group("convoy_observers"):
		if u.side==observer and u._battle_world()==world and AlliedAbilities.alive(u) and u.embarked_in==null and float(u.special.convoy.get("slow_time",0))>=3 and u.position.distance_to(target.position)<=3*CELL:return true
	return false

