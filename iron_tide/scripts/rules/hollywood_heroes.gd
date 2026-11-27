extends RefCounted

const IDS := ["CLNT","ARND","STLN"]
const NAMES := {"CLNT":"克林特","ARND":"阿诺","STLN":"史泰龙"}
const PORTRAITS := {"CLNT":"clint","ARND":"arnold","STLN":"stallone"}
const STUDIO := "NEUTRALSTUDIO"
const TITLES := {"CLNT":["快枪手","神枪手"],"ARND":["持续开火","带伤推进"],"STLN":["第一滴血","爆破专家"]}
const TRAITS := {
	"CLNT":[["快拔 · 停火 3 秒后，第一发之后的冷却缩短 80%。","连环枪 · 击倒步兵，立即向射程内最近的另一名敌方步兵补一枪。","一镜到底 · 补枪也击倒步兵时，再补一枪，每轮最多两次。"],
		["点名 · 对手动指定的敌方步兵，第一枪射程增加 1 格。","稳住准星 · 站定连续命中同一目标，第二枪伤害提高 40%。","决斗 · 原地连续命中同一目标，第三枪伤害提高 80%，然后重新计数。"]],
	"ARND":[["热枪 · 连射同一目标，每发使下一发冷却缩短 10%，最多 30%。","接着打 · 击倒目标后 2 秒内向新目标开火，继承热枪层数。","压制射击 · 热枪满层命中步兵，使其减速 40%，持续 1 秒。"],
		["硬汉 · 受伤降至半血时减伤 30%，持续 3 秒，冷却 60 秒。","顶着走 · 硬汉生效期间移速提高 30%。","我会回来的 · 活过硬汉的 3 秒，立即恢复最大生命的 25%。"]],
	"STLN":[["游击步伐 · 命中步兵后移速提高 25%，持续 2 秒。","回马枪 · 命中后累计移动 2 格，下一发对步兵的普攻伤害提高 40%。","丛林伏击 · 回马枪击倒步兵时再获得一发。赠送的一发不会继续触发。"],
		["重装榴弹 · 榴弹对直接命中的建筑伤害提高 20%。","校准弹着 · 连续命中同栋建筑，第二发溅射周围 1 格内的敌方地面部队。","拆迁队 · 第三发对同栋建筑额外造成基础伤害的 50%，周围守军承受双倍天赋溅射，然后重新计数。"]]
}

static func install_catalog(db) -> void:
	var studio:Dictionary=db.building_index.GAPILE.duplicate(true)
	studio.merge({"id":STUDIO,"name":"中立英雄制造所","desc":"招募已入册的中立英雄。每方最多建造一座。","buildlimit":1,"faction":"neutral","builds":IDS.duplicate(),"tags":["structure","production","hero_studio"],"ra2_prereq":["STUDIO_POWER"],"buildup":"STUDIOMK"},true)
	db.building_index[STUDIO]=studio
	db.ra2_prereq[STUDIO]=["STUDIO_POWER"]
	db.ra2_ids.append(STUDIO)
	db.ra2_art[STUDIO]={"cameo":"res://assets/ui/heroes/neutral_studio_icon.tres","shp":"res://assets/ra2/shp/NEUTRALSTUDIO.png"}
	for id in IDS:
		var row:Dictionary=db.hollywood_cast.units[id].duplicate(true)
		row.merge({"faction":"neutral","built_at":STUDIO,"cost":1000,"build_time":20},true)
		if id=="STLN":row.secondary_weapon.damage=300.0 # Multi-hit hero talent; the campaign keeps its native demolition round.
		db.unit_index[id]=row
		db.ra2_ids.append(id)
		db.ra2_art[id]={"cameo":"res://assets/ui/heroes/%s_icon.tres"%PORTRAITS[id],"shp":"res://assets/ra2/shp/%s.png"%id}

static func recruit_survivors(world,academy:Dictionary) -> Array:
	var recruits:=[]
	var visited:Dictionary=world.allied_state.get("hollywood",{}).get("visited",{})
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally" or u.unit_id not in IDS:continue
		var name:String=u.special.get("hollywood_star","")
		if name!=NAMES[u.unit_id] or not u.special.get("studio_rescued",visited.has(name)):continue
		var roster:Dictionary=academy.get_or_add("hero_builds",{})
		if int(roster.get(u.unit_id,0))>0:continue
		roster[u.unit_id]=1
		var recent:Array=academy.get_or_add("hero_recency",[])
		recent.erase(u.unit_id)
		recent.push_front(u.unit_id)
		recruits.append(u.unit_id)
	return recruits

static func promote(u) -> void:
	if u.special.has("studio"):return
	var ctx:Dictionary=BattleRequest.combat_context
	u.special.academy_hero=u.unit_id
	u.special.hero_command_rank=clampi(int(ctx.get("hero_escort_ranks",{}).get(u.unit_id,0)),0,2) if u.side=="ally" else 0
	u.special.hero_survival_rank=clampi(int(ctx.get("hero_survival_ranks",{}).get(u.unit_id,0)),0,2) if u.side=="ally" else 0
	u.special.studio={"idle":3.0,"position":u.position}
	u.display_name="☆ "+NAMES[u.unit_id]
	u.skills.clear()
	u.passive.clear()
	u._has_active_skills=false
	var training:Dictionary=ctx.get("hero_training",{}) if u.side=="ally" else {}
	var academy=MetaProgress.Academy
	var scale:=float(ctx.get("hero_training_scale",academy.HERO_TRAINING_SCALE))
	u._grant_veteran(2,false)
	var hp_bonus:float=academy.training_percent("health",academy.training_rank(training,u.unit_id,"health"),scale)
	var atk_bonus:float=academy.training_percent("firepower",academy.training_rank(training,u.unit_id,"firepower"),scale)
	u._base_max_hp*=1.0+hp_bonus*.01
	u.max_hp=u._base_max_hp
	u.hp=u.max_hp
	u._base_atk*=CombatMath.additional_growth_ratio(u.bonuses,1.0+atk_bonus*.01)
	u._recompute_bonuses()
	u._refresh_weapon_derived()
	u.refresh_house_color()

static func infantry(target) -> bool:
	return is_instance_valid(target) and target is Unit and AlliedAbilities.infantry(target) and not target.is_air_target()

static func tick(u,dt:float) -> void:
	var s:Dictionary=u.special.studio
	s.idle=minf(3,float(s.idle)+dt)
	if s.has("duel") and not is_same(s.duel,u.attack_target):
		s.erase("duel")
		s.duel_hits=0
	var distance:float=u.position.distance_to(s.position)
	s.position=u.position
	if distance>.01:
		s.erase("duel")
		s.duel_hits=0
		if s.has("travel"):
			s.travel+=distance
			if s.travel>=2*Ra2Damage.PX_PER_CELL:
				s.erase("travel")
				s.return_round=1
	for key in ["carry","hard_cd","hard"]:
		if not s.has(key):continue
		s[key]=float(s[key])-dt
		if s[key]>0:continue
		s.erase(key)
		if key=="hard" and u.special.hero_survival_rank>=2 and u.hp>0:u.heal(u.max_hp*.25)

static func mark(u,target) -> void:
	if u.unit_id=="CLNT" and infantry(target) and not BattleRequest.friendly(u.side,target.side):
		var s:Dictionary=u.special.studio
		if not is_same(s.get("ordered"),target):
			s.ordered=target
			s.first=true

static func range_bonus(u,target) -> float:
	var s:Dictionary=u.special.studio
	return Ra2Damage.PX_PER_CELL if u.attack_ordered and s.get("first",false) and is_same(s.get("ordered"),target) else 0.0

static func reload_factor(u,target) -> float:
	var s:Dictionary=u.special.studio
	var factor:=1.0
	if u.unit_id=="CLNT":
		if s.idle>=3:factor=.2
		if is_same(s.get("ordered"),target):s.first=false
	if u.unit_id=="ARND":
		if not is_same(s.get("hot_target"),target):
			if not s.has("carry"):s.heat=0
			s.hot_target=target
			s.erase("carry")
		s.heat=mini(3,int(s.get("heat",0))+1)
		factor=1.0-.1*int(s.heat)
	s.idle=0.0
	return factor

static func shot(u,target,bonus:Dictionary) -> void:
	var s:Dictionary=u.special.studio
	bonus.studio_target=target
	var mult:=1.0
	match u.unit_id:
		"CLNT":
			bonus.studio_chain=int(s.get("chain_depth",0))
			if not is_same(s.get("duel"),target):
				s.duel=target
				s.duel_hits=0
			var hits:=int(s.get("duel_hits",0))
			if hits==1 and u.special.hero_survival_rank>=1:mult=1.4
			if hits==2 and u.special.hero_survival_rank>=2:mult=1.8
		"STLN":
			if not target is Building:s.erase("fort")
			if infantry(target) and s.has("return_round"):
				bonus.studio_round=int(s.return_round)
				s.erase("return_round")
				mult=1.4
			elif target is Building:
				if not is_same(s.get("fort"),target):
					s.fort=target
					s.fort_hits=0
				bonus.studio_grenade=true
	if mult!=1.0:bonus.attack_bonus=float(bonus.get("attack_bonus",1.0))*mult

static func absorb(u,damage:float) -> float:
	var s:Dictionary=u.special.studio
	if damage<=0:return damage
	if not s.has("hard_cd") and u.hp-damage<=u.max_hp*.5:
		s.hard=3.0
		s.hard_cd=60.0
		if u.special.hero_survival_rank>=1:u.add_buff("speed",3.0,.3,"顶着走")
	return damage*.7 if s.has("hard") else damage

static func impact(source,target,bonus:Dictionary) -> void:
	var u=source.shooter() if source is Projectile else source
	if not is_instance_valid(u) or not u is Unit or u.hp<=0 or not u.special.has("studio") or not is_same(bonus.get("studio_target"),target):return
	var s:Dictionary=u.special.studio
	match u.unit_id:
		"CLNT":
			if is_same(s.get("duel"),target):s.duel_hits=(int(s.get("duel_hits",0))+1)%(3 if u.special.hero_survival_rank>=2 else 2)
			var depth:=int(bonus.get("studio_chain",0))
			if target.hp<=0 and infantry(target) and depth<int(u.special.hero_command_rank):
				follow_up(u,target,depth+1)
		"ARND":
			if target.hp<=0 and u.special.hero_command_rank>=1:s.carry=2.0
			if int(s.get("heat",0))==3 and u.special.hero_command_rank>=2 and infantry(target) and target.hp>0:
				target.add_buff("electric_slow",1,.4,"压制射击")
		"STLN":
			if infantry(target):
				s.erase("fort")
				u.add_buff("speed",2.0,.25,"游击步伐")
				if u.special.hero_command_rank>=1 and not s.has("travel"):s.travel=0.0
				if target.hp<=0 and u.special.hero_command_rank>=2 and int(bonus.get("studio_round",0))==1:s.return_round=2
			elif target is Building and bonus.get("studio_grenade",false) and is_same(s.get("fort"),target):
				s.fort_hits=int(s.get("fort_hits",0))%(3 if u.special.hero_survival_rank>=2 else 2)+1
				if s.fort_hits>=2 and u.special.hero_survival_rank>=s.fort_hits-1:splash(u,target,s.fort_hits)

static func follow_up(u,previous,depth:int) -> void:
	var world=u._battle_world()
	if not world:return
	var best=null
	var nearest:=INF
	for candidate in world.units:
		if candidate==previous or not world.actor_alive(candidate) or not infantry(candidate) or BattleRequest.friendly(u.side,candidate.side):continue
		if not u._weapon_target_valid(candidate):continue
		var distance:float=u.position.distance_squared_to(candidate.position)
		if distance<nearest:
			best=candidate
			nearest=distance
	if best!=null:
		var s:Dictionary=u.special.studio
		s.chain_depth=depth
		u._fire_shot(best)
		s.erase("chain_depth")

static func grenade_multiplier(source,target,bonus:Dictionary) -> float:
	if not is_same(bonus.get("studio_target"),target):return 1.0
	var u=source.shooter() if source is Projectile else source
	if not is_instance_valid(u) or not u is Unit or not u.special.has("studio"):return 1.2
	var s:Dictionary=u.special.studio
	return 1.7 if u.special.hero_survival_rank>=2 and is_same(s.get("fort"),target) and int(s.get("fort_hits",0))%3==2 else 1.2

static func splash(u,target,number:int) -> void:
	var world=u._battle_world()
	if not world:return
	var damage:=float(u.weapon.damage)*(.5 if number==2 else 1.0)
	Effects.spawn_impact(target.position,Color.ORANGE,Ra2Damage.PX_PER_CELL)
	for enemy in world.units.duplicate():
		if not world.actor_alive(enemy) or enemy.embarked_in!=null or enemy.is_air_target() or BattleRequest.friendly(u.side,enemy.side):continue
		if enemy.position.distance_to(target.closest_footprint_point(enemy.position))<=Ra2Damage.PX_PER_CELL:enemy.receive_hit(damage,"shell",{},u)
