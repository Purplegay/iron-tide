extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")

const ACTIVE := "ap_furnace_bastion"
const PASSIVE := "ps_furnace_flak"
const STANCE := "furnace_prone"
const GUARD := "furnace_flak_life"
static var SUMMON_COOLDOWN:float:
	get:return P.number("mechanic/ap_furnace_bastion","summon_cooldown")
static var RADIUS:float:
	get:return P.number("mechanic/ap_furnace_bastion","blast_radius")*Ra2Damage.PX_PER_CELL

const ARMOR = preload("res://assets/cosmetics/heroes/furnace_prone_armor.png")

static func armor_region(frame:int) -> Rect2:
	var slot := frame-86 if frame>=86 and frame<134 else frame-212+48 if frame>=212 and frame<260 else -1
	if slot<0:return Rect2()
	var cell:=Vector2(152,192)
	return Rect2(Vector2(slot%12,slot/12)*cell,cell)

static func draw_armor(unit, frame:int, dest:Rect2, opacity:float) -> void:
	var region:=armor_region(frame)
	if not region.has_area():return
	var tint:=Color(1.0,0.86,0.72,opacity) if unit.special.get("hero_skin",false) else Color(1,1,1,opacity)
	unit.draw_texture_rect_region(ARMOR,dest,region,tint)

static func rank_of(card: String) -> int:
	return clampi(int(BattleRequest.combat_context.get("card_ranks", {}).get(card, 0)), 0, 3)

static func can_switch(unit) -> bool:
	return unit.special.get("academy_hero") == "E2" and AlliedAbilities.alive(unit) and unit.embarked_in == null and unit._stun_timer <= 0 and not AlliedAbilities.frozen(unit)

static func cast(unit, ability) -> bool:
	if not can_switch(unit): return false
	if unit.special.has(STANCE):
		burst(unit)
		unit.special.erase(STANCE)
	else:
		var card := GameData.get_skill(ACTIVE)
		var rank := rank_of(ACTIVE)
		var shield_ready: bool = ability.ready()
		unit.special[STANCE] = {"hp":unit.max_hp * float(card.shield_by_rank[rank]) if shield_ready else 0.0, "left":P.number("mechanic/ap_furnace_bastion","shield_seconds") if shield_ready else 0.0, "rank":rank}
		if shield_ready: ability.trigger_cooldown()
	unit._recompute_bonuses()
	unit.queue_redraw()
	return true

static func burst(unit) -> void:
	var state: Dictionary = unit.special[STANCE]
	if state.hp <= 0: return
	state.hp = 0.0 # Consume first, including when splash provokes damage recursively.
	var world = unit._battle_world()
	if world == null: return
	var weapon: Dictionary = unit._active_weapon().duplicate()
	weapon.damage *= float(GameData.get_skill(ACTIVE).burst_by_rank[state.rank])
	preload("res://scripts/core/shield_break_wave.gd").spawn(world,unit.position,RADIUS)
	for enemy in world.units + world.buildings:
		if not world.actor_alive(enemy) or BattleRequest.friendly(enemy.side, unit.side) or enemy.side == "neutral": continue
		if enemy is Unit and (enemy.embarked_in != null or enemy.is_air_target()): continue
		var at: Vector2 = enemy.closest_footprint_point(unit.position) if enemy is Building else enemy.position
		if unit.position.distance_squared_to(at) > RADIUS * RADIUS: continue
		var damage := CombatMath.full_damage(weapon,enemy.armor,unit.bonuses,null,enemy.ra2_armor,0.0,enemy)
		enemy.receive_hit(damage,"explosion",unit.bonuses,unit,str(weapon.get("ra2_warhead","")))

static func absorb(unit, damage:float) -> float:
	var state: Dictionary = unit.special[STANCE]
	var used := minf(maxf(damage,0.0),float(state.hp))
	if used > 0:
		if used >= state.hp: burst(unit)
		else: state.hp -= used
	return damage-used

static func tick(unit, delta:float) -> void:
	if unit._dead: return
	if unit.special.has(GUARD):
		var guard:Dictionary=unit.special[GUARD]
		var old:float=guard.age
		guard.age=minf(guard.life,old+delta)
		unit.hp=maxf(0,unit.hp-unit.max_hp*(guard.age*guard.age-old*old)/(guard.life*guard.life))
		if unit.hp <= 0.0001 or guard.age >= guard.life:
			Effects.spawn_sparks(unit.art_center(),8,Color.GOLD)
			unit.hp=0
			unit._die(null,true) # Dissolve without spawning a wreck or an escaping driver.
		return
	if unit.special.has(STANCE):
		var state:Dictionary=unit.special[STANCE]
		state.left=maxf(0.0,state.left-delta)
		if state.left<=0: state.hp=0.0
	if unit.special.get("academy_hero")!="E2" or unit.passive.get("id")!=PASSIVE: return
	var cd:=maxf(0.0,float(unit.special.get("furnace_flak_cd",0))-delta)
	unit.special.furnace_flak_cd=cd
	if cd>0 or unit.embarked_in!=null or AlliedAbilities.frozen(unit) or unit._stun_timer>0:return
	unit.special.furnace_flak_cd=0.25
	var world=unit._battle_world()
	if world==null:return
	var reach:float=GameData.get_unit("HTK").anti_air_weapon.range
	var nearest=null
	for enemy in world.units:
		if not world.actor_alive(enemy) or BattleRequest.friendly(enemy.side,unit.side) or enemy.side=="neutral" or not enemy.is_air_target() or enemy.embarked_in!=null:continue
		var distance:float=unit.position.distance_to(enemy.position)
		if distance<=reach and world.actor_visible_to(unit.side,enemy):
			nearest=enemy
			reach=distance
	if nearest==null:return
	var card:=GameData.get_skill(PASSIVE)
	var rank:=rank_of(PASSIVE)
	for index in P.count("mechanic/ap_furnace_bastion","summon_count"):
		var sign_value:float=2.0*index-(P.count("mechanic/ap_furnace_bastion","summon_count")-1)
		var at:=preload("res://scripts/world/american_paradrop.gd").open_ground(world,unit.position+Vector2(P.number("mechanic/ap_furnace_bastion","summon_spacing")*sign_value,0))
		if not at.is_finite():continue
		var car=world.spawn_unit("HTK",unit.side,at)
		if car==null:continue
		car.max_hp*=float(card.hp_by_rank[rank])
		car.hp=car.max_hp
		car.special[GUARD]={"life":float(card.life_by_rank[rank]),"age":0.0,"rate":float(card.rof_by_rank[rank])}
		car.order_target(nearest,false,false)
		unit.special.furnace_flak_cd=SUMMON_COOLDOWN
