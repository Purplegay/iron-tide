extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const T=preload("res://scripts/units/tanya_talents.gd")
const R=preload("res://scripts/units/expansion_rules.gd")

static func detects(world,observer:String,target) -> bool:
	if world==null:return false
	if preload("res://scripts/units/convoy_talents.gd").detects(world,observer,target):return true
	if preload("res://scripts/units/leizhu_command.gd").detects(world,observer,target):return true
	if preload("res://scripts/units/peregrine_command.gd").detects(world,observer,target):return true
	if not target is Unit or target.is_air_target() or target.is_naval or target.embarked_in!=null or NavalContact.underwater_type(target):return false
	for scout in world.neighborhood.nearby(target.position,P.number("hero/TANY/command","detect_cells")*R.CELL,true):
		if scout.side!=observer or not AlliedAbilities.alive(scout) or scout.embarked_in!=null or T.rank(scout)<1:continue
		if scout.position.distance_to(target.position)>P.number("hero/TANY/command","detect_cells")*R.CELL:continue
		if clear_line(world,scout,target):return true
	return false

static func clear_line(world,source,target) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(source.global_position,target.global_position,1,[source.get_rid(),target.get_rid()])
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func concealed(unit,observer:String) -> bool:
	if BattleRequest.friendly(unit.side,observer):return false
	var world=R.world(unit)
	if detects(world,observer,unit):return false
	for detector in unit.get_tree().get_nodes_in_group("disguise_detectors"):
		if detector.side!=observer or not AlliedAbilities.alive(detector) or detector.embarked_in!=null or not world.is_ancestor_of(detector):continue
		if detector.position.distance_to(unit.position)<=detector.sight and clear_line(world,detector,unit):return false
	return true

static func target_allowed(unit,target) -> bool:
	if T.silenced(unit):return false
	if not T.active(unit):return true
	if unit.embarked_in!=null or AlliedAbilities.frozen(unit) or unit._stun_timer>0:return false
	if not unit.has_move_order and unit.velocity.length_squared()<1:return true
	return T.rank(unit)>=4 and AlliedAbilities.infantry(target) and not target.is_air_target() and unit.fire_stance!="none"

static func move_factor(unit) -> float:
	return P.number("hero/TANY/command","firing_speed") if T.rank(unit)>=4 and unit._fire_anim_time>=0 else 1.0

static func volley(unit,target,weapon:Dictionary) -> void:
	if not T.active(unit):return
	T.attacking(unit)
	var id:=str(weapon.get("ra2_weapon_id","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	if T.rank(unit)<2 or id not in ["DoublePistols","DoublePistolsE"] or not AlliedAbilities.infantry(target) or not R.enemy(unit,target):return
	var s:Dictionary=unit.special[T.KEY]
	s.split_round=int(s.get("split_round",0))+1
	if s.split_round%P.count("hero/TANY/command","split_rounds")!=0:return
	var world=R.world(unit)
	var best=null
	var distance:=INF
	for other in world.neighborhood.nearby(target.position,P.number("hero/TANY/command","split_radius")*R.CELL,true):
		if other==target or not R.enemy(unit,other) or not AlliedAbilities.infantry(other) or other.is_air_target() or other.embarked_in!=null:continue
		if not world.actor_visible_to(unit.side,other) or AlliedAbilities.concealed(other,unit.side):continue
		var d:float=other.position.distance_squared_to(target.position)
		if d>pow(P.number("hero/TANY/command","split_radius")*R.CELL,2):continue
		if d<distance:distance=d;best=other
	if best==null:return
	extra_hit(unit,best,P.number("hero/TANY/command","split_damage"),"bullet")
	Effects.spawn_beam(unit.position,Effects.hit_position(best),Color(1,.85,.5),"laser",1.0,.12)

static func extra_hit(unit,target,factor:float,kind:String) -> void:
	var primary:=CommandoCombat.weapon_for(unit,null)
	var weapon:Dictionary={"damage":float(primary.get("damage",0))*factor,"attack_type":kind}
	var bonus:Dictionary=unit.bonuses.duplicate(true);bonus.expansion_extra=true
	bonus.reference_weapon=weapon
	bonus.hit_reference_damage=CombatMath.FinalDamage.weapon_reference(weapon,target,bonus)
	var damage:=CombatMath.full_damage(weapon,target.armor,bonus)
	if kind=="explosive":
		var armor:=preload("res://scripts/units/tanya_breach.gd").armor_factor(target)
		damage=CombatMath.with_offense(float(weapon.damage),bonus)*armor
		bonus.hit_reference_damage=float(weapon.damage)*armor*float(bonus.get("veteran_attack",1.0))
	target.receive_hit(damage,kind,bonus,unit)

static func c4_destroyed(unit,building) -> void:
	if T.rank(unit)<3 or building.special.get("c4_secondary",false):return
	var world=R.world(unit)
	for target in world.units.duplicate():
		if not R.enemy(unit,target) or target.is_air_target() or target.is_naval or target.embarked_in!=null:continue
		if building.closest_footprint_point(target.position).distance_to(target.position)>P.number("hero/TANY/command","shock_radius")*R.CELL:continue
		if not world.actor_visible_to(unit.side,target) or AlliedAbilities.concealed(target,unit.side):continue
		extra_hit(unit,target,P.number("hero/TANY/command","shock_damage"),"explosive")
	Effects.spawn_impact(building.position,Color(1,.7,.3),building.radius+P.number("hero/TANY/command","shock_radius")*R.CELL)
	if T.rank(unit)<5 or not AlliedAbilities.alive(unit):return
	var s:Dictionary=unit.special[T.KEY]
	if s.has("chain_cd") or int(s.get("chain_used",0))>=P.count("hero/TANY/command","chain_limit"):return
	var next=null
	var distance:=INF
	for candidate in world.buildings:
		if candidate==building or not R.enemy(unit,candidate) or not AlliedAbilities.can_order(unit,candidate,"allied_c4") or protected(candidate):continue
		var gap:=foundation_gap(building,candidate)
		if gap<=P.number("hero/TANY/command","chain_radius")*R.CELL and gap<distance:distance=gap;next=candidate
	if next==null:return
	next.special.c4_left=P.number("hero/TANY/command","chain_delay");next.special.c4_owner=unit
	next.special.c4_secondary=true;next.special.c4_side=unit.side
	s.chain_cd=P.number("hero/TANY/command","chain_cooldown");s.chain_used=int(s.get("chain_used",0))+1
	preload("res://scripts/units/temporal_visual.gd").sync(next)
	Effects.spawn_beam(building.position,next.position,Color.ORANGE,"laser",1.5,.25)

static func foundation_gap(a,b) -> float:
	var best:=INF
	for vertex in a.footprint_poly():
		var point:Vector2=a.position+vertex
		best=minf(best,b.closest_footprint_point(point).distance_to(point))
	for vertex in b.footprint_poly():
		var point:Vector2=b.position+vertex
		best=minf(best,a.closest_footprint_point(point).distance_to(point))
	return best

static func chain_valid(building) -> bool:
	var side:String=building.special.get("c4_side","")
	if side.is_empty() or R.world(building).house_defeated(side):return false
	return building.side!="neutral" and not BattleRequest.friendly(side,building.side) and not protected(building)

static func protected(building) -> bool:
	return building.building_id=="CABHUT" or building.special.get("expedition_protected",false) or building.special.has("iron_left") or AlliedAbilities.alive(building.special.get("temporal_by")) or building.ignores_warhead("") or float(building.special.get("force_shield_left",0))>0 or (building.side=="ally" and GM.god_mode)
