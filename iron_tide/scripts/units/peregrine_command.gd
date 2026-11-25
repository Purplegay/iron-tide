extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="peregrine"
const GROUP="peregrine_leaders"
const BOMBS="peregrine_submunitions"
const COMMAND_DEFAULT = [
	"航拍落点：普通导弹命中后揭示固定落点周围 1 格，持续 3 秒；基础弹仓 4 发，空中每 8 秒补一发。",
	"备用挂架：对地弹仓增至 5 发；出场满弹，消耗后空中自动补入，无需机场。",
	"自卫机炮：可正常指令攻击 3 格内可见空敌，间隔 1 秒，造成当前主攻击力 20% 的普通枪伤，不消耗对地弹药。",
	"低空扫描：本人在空中时侦测 2 格内敌隐形／伪装地面单位，正常遮挡有效；不反潜、不增加攻击射程。",
	"领航编队：本人存活且未迫降时，全图同方真实 ORCA／BEAG 移速 +15%，包含本人；多份不叠加，不作用盟友、临时飞机或米格。",
	"末弹分束：每个补满周期最后一枚打空弹仓的普通主导弹命中后，在落点两侧各 0.8 格放出子弹药；预警 0.5 秒，半径 0.6 格，各为攻击力 35% 的普通爆破。W 不触发。"
]
static var COMMAND:Array:
	get:return P.traits("hero/ORCA/command",COMMAND_DEFAULT)

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or not R.active(unit) or unit.special.get("academy_hero")!="ORCA" or not unit.special.has(KEY):return -1
	return clampi(int(unit.special.get("hero_command_rank",0)),0,5)

static func install(unit) -> void:
	if rank(unit)<0:return
	if not unit.is_in_group(GROUP):unit.add_to_group(GROUP)

static func anti_air(unit,target) -> bool:
	return rank(unit)>=2 and not unit.special.has("hero_wreck") and target is Unit and AlliedAbilities.alive(target) and target.is_air_target()

static func weapon(unit,base:Dictionary) -> Dictionary:
	return {"name":"游隼自卫机炮","damage":float(base.get("damage",0))*P.number("hero/ORCA/command","aa_damage"),"attack_type":"bullet","range":P.number("hero/ORCA/command","aa_range")*R.CELL,"min_range":0,"cooldown":P.number("hero/ORCA/command","aa_cooldown"),"burst":1,"projectile_speed":0.0,"ra2_aa":true,"ra2_ag":false,"peregrine_aa":true}

static func speed_bonus(unit) -> float:
	if unit.unit_id not in ["ORCA","BEAG"] or not R.active(unit) or unit.special.has("hero_wreck"):return 0
	var world=R.world(unit)
	if world==null or world.house_defeated(unit.side):return 0
	for leader in unit.get_tree().get_nodes_in_group(GROUP):
		if leader.side==unit.side and world.is_ancestor_of(leader) and rank(leader)>=4 and not leader.special.has("hero_wreck"):return P.number("hero/ORCA/command","formation_speed")
	return 0

static func detects(world,observer:String,target) -> bool:
	if not BattleRequest.extensions_enabled() or world==null:return false
	if not target is Unit or target.is_air_target() or target.is_naval or target.embarked_in!=null or NavalContact.underwater_type(target):return false
	if target.side=="neutral" or BattleRequest.friendly(observer,target.side):return false
	for scout in world.get_tree().get_nodes_in_group(GROUP):
		if scout.side!=observer or not world.is_ancestor_of(scout) or rank(scout)<3 or not scout.is_air_target() or scout.special.has("hero_wreck") or scout._stun_timer>0 or AlliedAbilities.frozen(scout):continue
		if scout.position.distance_to(target.position)>P.number("hero/ORCA/command","detect_cells")*R.CELL:continue
		var ray:=PhysicsRayQueryParameters2D.create(scout.global_position,target.global_position,1,[scout.get_rid(),target.get_rid()])
		if world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():return true
	return false

static func spent(unit,before:int,after:int,normal:bool) -> void:
	var s:Dictionary=unit.special[KEY]
	s.erase("split_pending")
	if before>after and after==0 and s.get("last_ready",true):
		s.last_ready=false
		if normal and rank(unit)>=5:s.split_pending=true

static func shot(unit,target,bonus:Dictionary) -> void:
	var s:Dictionary=unit.special[KEY]
	if anti_air(unit,target):
		s.erase("split_pending");bonus.peregrine_aa=true;return
	bonus.peregrine_normal=true;bonus.peregrine_direct=true;bonus.peregrine_side=unit.side
	if s.get("split_pending",false):
		s.erase("split_pending")
		bonus.peregrine_split={"raw":float(unit._weapon_for_target(null).get("damage",0))*P.number("hero/ORCA/command","split_damage"),"axis":unit.position.direction_to(target.position).orthogonal(),"bonus":unit.bonuses.duplicate(true)}

static func hit(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not source is Projectile or not bonus.has("peregrine_split") or not is_same(source.target,target):return
	if bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false) or source.splinters.get("peregrine_split_done",false):return
	if target.side=="neutral" or BattleRequest.friendly(source.owner_side,target.side) or not target is Unit and not target is Building:return
	if target is Unit and (target.is_air_target() or target.embarked_in!=null or target.is_naval):return
	source.splinters.peregrine_split_done=true;source.splinters.peregrine_split_pending=true

static func finish(projectile) -> void:
	if not projectile.splinters.get("peregrine_split_pending",false):return
	projectile.splinters.erase("peregrine_split_pending")
	var host=projectile.get_parent()
	var world=host.get_parent() if host!=null and host.get_parent() is Battle else null
	if world==null or world.house_defeated(projectile.owner_side):return
	var payload:Dictionary=projectile.attacker_bonus.peregrine_split
	var bonus:Dictionary=payload.bonus.duplicate(true)
	for field in ["peregrine_split","peregrine_normal","peregrine_direct","peregrine_hunt","hit_reference_damage","expansion_burning","expansion_air_cycle"]:bonus.erase(field)
	bonus.expansion_extra=true;bonus.reference_weapon={"damage":payload.raw,"attack_type":"explosive"}
	for direction in [-1,1]:
		world.allied_state.get_or_add(BOMBS,[]).append({"owner":projectile.shooter(),"side":projectile.owner_side,"point":projectile.target_point+payload.axis*(direction*P.number("hero/ORCA/command","split_offset")*R.CELL),"left":P.number("hero/ORCA/command","split_delay"),"raw":payload.raw,"damage":CombatMath.with_offense(payload.raw,bonus),"bonus":bonus})
	world.queue_redraw()

static func world_tick(world,dt:float) -> void:
	var bombs:Array=world.allied_state.get(BOMBS,[])
	for bomb:Dictionary in bombs.duplicate():
		if world.house_defeated(bomb.side):bombs.erase(bomb);continue
		bomb.left-=dt
		if bomb.left>0.000001:continue
		bombs.erase(bomb)
		for target in world.units.duplicate()+world.buildings.duplicate():
			if not preload("res://scripts/units/peregrine_cards.gd").legal(bomb.side,target):continue
			var point:Vector2=target.closest_footprint_point(bomb.point) if target is Building else target.position
			if point.distance_to(bomb.point)>P.number("hero/ORCA/command","split_radius")*R.CELL:continue
			var armor:=preload("res://scripts/units/tanya_breach.gd").armor_factor(target)
			var bonus:Dictionary=bomb.bonus.duplicate(true)
			bonus.hit_reference_damage=float(bomb.raw)*armor*float(bonus.get("veteran_attack",1))
			target.receive_hit(float(bomb.damage)*armor,"explosive",bonus,bomb.owner if is_instance_valid(bomb.owner) else null)
		if world.position_visible_to("ally",bomb.point):Effects.spawn_impact(bomb.point,Color(.6,.85,1),P.number("hero/ORCA/command","split_radius")*R.CELL)
	if bombs.is_empty():world.allied_state.erase(BOMBS)
	world.queue_redraw()

static func draw_world(world) -> void:
	for bomb in world.allied_state.get(BOMBS,[]):
		if not world.position_visible_to("ally",bomb.point):continue
		world.draw_set_transform(bomb.point,Iso.eff_angle(),Iso.up())
		world.draw_arc(Vector2.ZERO,P.number("hero/ORCA/command","split_radius")*R.CELL,0,TAU,24,Color(.5,.85,1,.85),1.5,true)
		world.draw_circle(Vector2.ZERO,3,Color.WHITE)
	world.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[]
	if speed_bonus(unit)>0:rows.append(V.row("领航编队 · 全图同方战机移速 +15%",0,false,"speed"))
	var level:=rank(unit)
	if level>=2:rows.append(V.row("自卫机炮 · 对空3格 / 1秒 / 20%攻击，不耗弹",0,false,"attack"))
	if level>=3 and unit.is_air_target():rows.append(V.row("低空扫描 · 2格地面反隐，遮挡有效",0,false,"eye"))
	if level>=5:rows.append(V.row("末弹分束 · "+("本周期可用" if unit.special[KEY].get("last_ready",true) else "等待补满"),0,false,"split"))
	return rows
