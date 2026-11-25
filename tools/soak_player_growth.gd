extends RefCounted
## Test-only adapter, loaded exclusively by the isolated performance runner.

static func apply(world) -> Dictionary:
	assert(OS.get_user_data_dir().contains("CodexIronTideValidation"))
	assert(BattleRequest.extensions_enabled())
	for unit in world.units:
		if unit.side=="ally" or not BattleRequest.is_house(unit.side):continue
		var old_attack:float=unit.bonuses.attack_bonus
		var old_defense:float=unit.bonuses.defense_bonus
		var old_speed:float=unit.move_speed
		unit._apply_passive(true)
		unit._load_equipped_skills(BattleRequest.unit_loadout(unit.unit_id))
		unit._base_atk*=float(unit.bonuses.attack_bonus)/maxf(old_attack,0.0001)
		unit._base_def*=float(unit.bonuses.defense_bonus)/maxf(old_defense,0.0001)
		unit._base_speed*=unit.move_speed/maxf(old_speed,0.0001)
		unit._init_native_skills()
		UnitSkillLayout.ensure(unit)
	for building in world.buildings:
		if building.side!="ally" and BattleRequest.is_house(building.side):
			preload("res://scripts/buildings/tesla_pulse.gd").configure(building)
			if building.building_id=="NAFLAK" and BattleRequest.unit_loadout("NAFLAK").passive=="ps_barrage":
				building.special.flak_card=float(GameData.get_skill("ps_barrage").value)*BattleRequest.card_scale("ps_barrage")
	return audit(world)

static func audit(world) -> Dictionary:
	var rows:Dictionary={}
	var errors:Array=[]
	for unit in world.units:
		if not world.actor_alive(unit) or not BattleRequest.is_house(unit.side):continue
		var row:Dictionary=rows.get_or_add(unit.side,{"units":0,"with_w":0,"with_passive":0,"with_talents":0,"auto_w_enabled":0,"types":{}})
		row.units+=1
		var expected:Dictionary=BattleRequest.unit_loadout(unit.unit_id)
		var w:String=preload("res://scripts/units/auto_w.gd").card_id(unit)
		var passive:String=str(unit.passive.get("id",""))
		var talents:Array=MetaProgress.selected_talents(unit.unit_id,BattleRequest.combat_context.get("unit_talents",{}))
		if not w.is_empty():row.with_w+=1
		if not passive.is_empty():row.with_passive+=1
		if not talents.is_empty():row.with_talents+=1
		if preload("res://scripts/units/auto_w.gd").enabled(unit):row.auto_w_enabled+=1
		for talent in talents:
			if not BattleRequest.has_unit_talent(unit.unit_id,talent,unit.side):errors.append([unit.side,unit.unit_id,"talent",talent])
		if unit.side!="ally" and not unit.special.has("expansion_temporary"):
			if w!=str(expected.active[0]) or passive!=str(expected.passive):errors.append([unit.side,unit.unit_id,"loadout",w,passive,expected])
		row.types[unit.unit_id]={"w":w,"passive":passive,"talents":talents}
	return {"source":"slot1 frozen combat_context", "scope":"talents, W and passive cards with saved card ranks; original AI stats and controllers retained", "houses":rows,"errors":errors,"auto_w_casts":preload("res://scripts/units/auto_w.gd").soak_casts.duplicate()}
