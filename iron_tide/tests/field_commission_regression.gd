extends "res://tests/ground_control_regression.gd"
const Commission = preload("res://scripts/rules/field_commission.gd")
const Soviet = preload("res://scripts/units/soviet_specials.gd")

func make(id: String, side := "ally"):
	var actor = battle.spawn_unit(id, side, Vector2(1200, 1500))
	activate(actor)
	if side=="ally": actor.max_hp=100000; actor.hp=100000
	return actor

func equip(id: String, card: String, rank: int) -> void:
	BattleRequest.combat_context.loadouts[id] = {"active": [], "passive": card}
	BattleRequest.combat_context.card_ranks[card] = rank

func place(id: String, side := "ally"):
	var building = battle._place_building(id, side, Vector2(1700, 1800), true)
	building._buildup_play = -1.0
	return building

func kill(source, id := "E2", side := "enemy"):
	var victim = make(id, side)
	victim.receive_hit(1000000, "rifle", {}, source)
	check(victim._dead, "real damage kills target")
	return victim

func planted(unit, side := "enemy"):
	var target = make("HTNK", side)
	Soviet.shoot(unit, target, {})
	check(target.special.has("ivan_bomb"), "real Ivan weapon plants bomb")
	return target

func progress(card: String) -> int:
	return Commission.count(battle.allied_state, "ally", card)

func clear_progress() -> void:
	battle.allied_state.erase(Commission.STATE)

func exercise(mode: String) -> void:
	start(mode)
	GM.god_mode=false; GM.one_shot_kill=false; GM.infinite_funds=false
	var barracks = place("GAPILE")
	var soviet_barracks = place("NAHAND")
	var lab = place("GATECH")
	check(not GameData.faction_unit_catalog("allied", true).has("PTROOP"), "psychic commando hidden from roster/refit")
	check(not barracks.buildable.has("PTROOP") and not barracks.can_queue("PTROOP"), "psychic commando cannot queue")
	var picker=preload("res://scripts/admin/gm_unit_panel.gd").new()
	add_child(picker)
	check(not picker.ids.has("PTROOP"), "psychic commando hidden from GM picker")
	picker.free()
	for id in ["CCOMAND","CIVAN","SPY"]:
		check("扩展新局" in EntityDescription.text(GameData.get_unit(id)), "unit description distinguishes old/new recruitment "+id)
	var retained=make("PTROOP")
	check(retained.unit_id=="PTROOP", "old actors retain data, hiding does not delete units")
	if mode==MatchRules.RA2:
		equip("CCOMAND", Commission.SEAL, 3)
		var seal=make("GHOST")
		kill(seal)
		check(seal.passive.is_empty() and progress(Commission.SEAL)==0, "classic mode ignores cards and objectives")
		battle.allied_state.stolen_ally_RequiresStolenAlliedTech=true
		check(barracks.can_queue("CCOMAND"), "classic stolen technology remains authoritative")
		await finish()
		return
	check(not barracks.enqueue("CCOMAND") and not soviet_barracks.enqueue("CIVAN"), "laboratory alone does not unlock recruits")
	check("本局累计" in barracks.queue_block_reason("CCOMAND"), "production explains card objective")
	battle.allied_state.stolen_ally_RequiresStolenAlliedTech=true
	battle.allied_state.stolen_ally_RequiresStolenSovietTech=true
	check(barracks.can_queue("CCOMAND") and soviet_barracks.can_queue("CIVAN"), "new extension match preserves stolen technology as alternative unlock")
	lab.under_construction=true
	check(barracks.can_queue("CCOMAND") and soviet_barracks.can_queue("CIVAN"), "stolen route retains original prerequisites without own lab")
	check(not GameData.production_prerequisites("CCOMAND",battle.allied_state).has("TECH"), "stolen route guidance uses original prerequisites")
	battle.allied_state.erase("stolen_ally_RequiresStolenAlliedTech")
	check(not barracks.can_queue("CCOMAND") and soviet_barracks.can_queue("CIVAN"), "wrong faction stolen tech does not unlock commando")
	battle.allied_state.erase("stolen_ally_RequiresStolenSovietTech")
	for pair in [["GATECH","CCOMAND",barracks],["NATECH","CIVAN",soviet_barracks]]:
		var spy=make("SPY")
		var enemy_lab=place(pair[0],"enemy")
		check(AlliedAbilities.can_order(spy,enemy_lab,"allied_infiltrate"), "spy accepts enemy lab "+pair[0])
		AlliedAbilities.resolve_infiltration(spy,enemy_lab)
		check(pair[2].can_queue(pair[1]), "real infiltration unlocks recruit without own lab "+pair[1])
		check(GameData.unit_production_block_reason(pair[1],battle.allied_state,"enemy")!="", "stolen unlock belongs only to thief side")
	battle.allied_state.erase("stolen_ally_RequiresStolenAlliedTech")
	battle.allied_state.erase("stolen_ally_RequiresStolenSovietTech")
	lab.under_construction=false
	for rank in 4:
		clear_progress()
		equip("CCOMAND", Commission.SEAL, rank)
		var seal=make("GHOST")
		var mate=make("GHOST")
		var threshold:int=[10,8,5,3][rank]
		check(Commission.goal(Commission.SEAL)==threshold, "SEAL threshold rank "+str(rank))
		check(str(threshold)+" 次" in MetaProgress.Academy.skill_description(GameData.get_skill(Commission.SEAL),rank), "SEAL card description rank "+str(rank))
		check(seal.passive.is_empty() and mate.passive.is_empty(), "ordinary team requires no equipped card")
		seal._grant_veteran(2, false)
		seal.credit_kill(99999, "enemy")
		check(progress(Commission.SEAL)==0, "GM/experience grants never advance objective")
		for i in threshold:
			var victim=kill(seal if i%2==0 else mate)
			victim._die(seal)
			check(progress(Commission.SEAL)==i+1, "elite SEAL team kill counted exactly once")
			check(barracks.can_queue("CCOMAND")== (i+1==threshold), "production opens only at kill threshold")
		check(Commission.completed(battle.allied_state,"ally",Commission.SEAL), "completed card reports unlock")
		check(barracks.enqueue("CCOMAND"), "real commando order accepted")
		barracks.cancel_at(0)
		clear_progress()
		equip("CIVAN", Commission.IVAN, rank)
		var ivan=make("IVAN")
		threshold=[5,4,3,1][rank]
		check(Commission.goal(Commission.IVAN)==threshold, "Ivan threshold rank "+str(rank))
		for i in threshold:
			var target=planted(ivan)
			check(progress(Commission.IVAN)==i, "planting alone never grants progress")
			Soviet.tick_actor(target,31)
			Soviet.remove_bomb(target,true)
			check(progress(Commission.IVAN)==i+1, "actual fuse expiry counted once")
			check(soviet_barracks.can_queue("CIVAN")== (i+1==threshold), "Ivan production threshold")
		check(soviet_barracks.enqueue("CIVAN"), "real chrono Ivan order accepted")
		soviet_barracks.cancel_at(0)
	# Invalid events remain excluded; lab ownership never gates objective counting.
	clear_progress()
	equip("CCOMAND", Commission.SEAL, 0); equip("CIVAN", Commission.IVAN, 0)
	var seal=make("GHOST");var ivan=make("IVAN")
	var plain=make("GHOST");plain.passive={}
	kill(plain)
	check(progress(Commission.SEAL)==1,"unequipped ordinary SEAL counts through chrono loadout")
	clear_progress()
	equip("CCOMAND","",0);kill(plain)
	check(progress(Commission.SEAL)==0,"no chrono loadout means no progress")
	equip("CCOMAND",Commission.SEAL,0)
	kill(seal,"E2","ally");kill(seal,"E2","neutral");kill(seal,"V3ROCKET")
	check(progress(Commission.SEAL)==0, "no card, friendly, neutral and spawned missile kills excluded")
	var target=planted(ivan);Soviet.remove_bomb(target,false)
	var friendly=planted(ivan,"ally");Soviet.remove_bomb(friendly,true)
	check(progress(Commission.IVAN)==0, "disarmed and friendly bombs excluded")
	lab.under_construction=true
	kill(seal)
	target=planted(ivan);lab.under_construction=false;Soviet.remove_bomb(target,true)
	check(progress(Commission.SEAL)==1 and progress(Commission.IVAN)==1, "unfinished lab no longer blocks kill or bomb provenance")
	lab.side="enemy"
	kill(seal)
	check(progress(Commission.SEAL)==2, "kills count even without own laboratory")
	lab.side="ally"
	target=planted(ivan);lab.under_construction=true;Soviet.remove_bomb(target,true)
	check(progress(Commission.IVAN)==2, "missing lab at detonation still counts")
	# A completed card objective is retained, but its production route still needs a lab.
	clear_progress();equip("CIVAN", Commission.IVAN, 3)
	target=planted(ivan);Soviet.remove_bomb(target,true)
	check(Commission.completed(battle.allied_state,"ally",Commission.IVAN), "objective completes before own laboratory")
	check(not soviet_barracks.can_queue("CIVAN"), "completed objective alone does not remove production lab requirement")
	lab.under_construction=false
	check(soviet_barracks.can_queue("CIVAN"), "finished lab enables previously completed objective")
	clear_progress();equip("CIVAN", Commission.IVAN, 0)
	var building=place("GAPOWR","enemy")
	building.receive_hit(1000000,"rifle",{},seal)
	check(progress(Commission.SEAL)==1, "actual enemy building death counts for SEAL")
	# Bomb provenance must survive both planter destruction and the disk save path.
	target=planted(ivan)
	ivan._die();battle.units.erase(ivan);ivan.free()
	await get_tree().process_frame
	check(BattleSaves.save_slot(battle,"slot1").ok, "save partial objective and pending bomb to disk")
	clear_progress()
	check(BattleSaves.prepare_load("slot1").ok, "public load accepts objective save")
	BattleSaves.restore_pending(battle)
	battle.paused=false;get_tree().paused=false
	check(progress(Commission.SEAL)==1 and progress(Commission.IVAN)==0, "partial progress restored")
	target=battle.units.filter(func(u):return is_instance_valid(u) and u.special.has("ivan_bomb"))[0]
	Soviet.remove_bomb(target,true)
	check(progress(Commission.IVAN)==1, "saved bomb credits detonation after planter death")
	barracks=battle.buildings.filter(func(b):return b.building_id=="GAPILE" and b.side=="ally")[0]
	lab=battle.buildings.filter(func(b):return b.building_id=="GATECH" and b.side=="ally")[0]
	seal=battle.units.filter(func(u):return is_instance_valid(u) and u.unit_id=="GHOST")[0]
	for i in 9:kill(seal)
	check(barracks.can_queue("CCOMAND"), "restored partial count completes")
	lab.under_construction=true
	check(not barracks.can_queue("CCOMAND") and "作战实验室" in barracks.queue_block_reason("CCOMAND"), "unlock retained but production requires lab")
	lab.under_construction=false
	check(barracks.can_queue("CCOMAND"), "rebuilding lab restores completed unlock")
	battle.funds=100000; battle.power_low=false
	check(barracks.enqueue("CCOMAND"), "enqueue completed commando after disk restore")
	for i in 100:
		barracks._process(1.0)
		if barracks.production.is_empty(): break
	check(battle.units.any(func(u):return is_instance_valid(u) and u.unit_id=="CCOMAND"), "completed production delivers real commando")
	equip("CIVAN", Commission.IVAN, 0)
	ivan=make("IVAN")
	for i in 4:
		target=planted(ivan);Soviet.remove_bomb(target,true)
	soviet_barracks=battle.buildings.filter(func(b):return b.building_id=="NAHAND" and b.side=="ally")[0]
	check(soviet_barracks.enqueue("CIVAN"), "enqueue completed chrono Ivan after disk restore")
	for i in 100:
		soviet_barracks._process(1.0)
		if soviet_barracks.production.is_empty(): break
	check(battle.units.any(func(u):return is_instance_valid(u) and u.unit_id=="CIVAN"), "completed production delivers real chrono Ivan")
	check(BattleSaves.save_slot(battle,"slot2").ok and BattleSaves.prepare_load("slot2").ok, "completed unlock saves and loads")
	BattleSaves.restore_pending(battle);battle.paused=false;get_tree().paused=false
	check(Commission.completed(battle.allied_state,"ally",Commission.SEAL), "completed flag survives restore")
	check(not Commission.completed(battle.allied_state,"enemy",Commission.SEAL), "opponent cannot inherit player progress")
	# Legacy context has no feature marker; it keeps original stolen-tech gating.
	battle.allied_state.stolen_ally_RequiresStolenAlliedTech=true
	BattleRequest.combat_context.erase("field_commission_version")
	check(GameData.unit_production_block_reason("CCOMAND",battle.allied_state).is_empty(), "old extension save retains spy unlock")
	check(not GameData.production_prerequisites("CCOMAND").has("TECH"), "legacy production prerequisites unchanged")
	check_acquisition()
	await finish()
	start(mode)
	check(progress(Commission.SEAL)==0 and progress(Commission.IVAN)==0, "new match resets all objective progress")
	check(not Commission.completed(battle.allied_state,"ally",Commission.SEAL), "new match has no permanent recruit unlock")
	await finish()

func check_acquisition() -> void:
	var meta=MetaProgress
	var migration:={"GHOST":{"active":["ap_smoke"],"passive":Commission.SEAL},"IVAN":{"active":[],"passive":Commission.IVAN},"CIVAN":{"active":[],"passive":"ps_hollow_point"}}
	check(Commission.migrate_loadouts(migration),"legacy equipment migrates")
	check(migration.CCOMAND.passive==Commission.SEAL and migration.GHOST.passive=="" and migration.GHOST.active==["ap_smoke"],"empty chrono slot receives card while ordinary active remains")
	check(migration.CIVAN.passive=="ps_hollow_point" and migration.IVAN.passive=="","occupied destination is never overwritten")
	check(not Commission.migrate_loadouts(migration),"equipment migration is idempotent")
	var frozen:=BattleRequest.combat_context.duplicate(true)
	BattleRequest.combat_context.field_commission_version=1
	BattleRequest.combat_context.loadouts={"GHOST":{"passive":Commission.SEAL}}
	check(Commission.equipped(Commission.SEAL),"legacy battle retains frozen ordinary-unit equipment eligibility")
	BattleRequest.combat_context.field_commission_version=2
	check(not Commission.equipped(Commission.SEAL),"new battle cannot activate card from obsolete ordinary slot")
	BattleRequest.combat_context=frozen
	var screen=preload("res://scripts/screens/meta_screen.gd").new()
	add_child(screen)
	for id in [Commission.SEAL,Commission.IVAN]:
		for rank in 4:
			var expected:int=GameData.get_skill(id).objective_by_rank[rank]
			check(screen._card_growth_step(GameData.get_skill(id),rank)=="%d 级 %d 次" % [rank,expected],"growth table displays objective count "+id+str(rank))
	screen.free()
	for card in [Commission.SEAL,Commission.IVAN]:
		var definition:=GameData.get_skill(card)
		check(meta.skill_draw_candidates().has(definition) and definition.rarity=="epic" and definition.type=="passive", "new card in epic passive pool "+card)
		meta.unlocked_skills.erase(card);meta.academy.card_shards=50
		check(meta.Academy.purchase(meta,"redeem",card) and meta.academy.card_shards==0, "real shard exchange unlocks "+card)
		check(not meta.Academy.purchase(meta,"redeem",card), "duplicate exchange rejected")
		var unit_id:String="CCOMAND" if card==Commission.SEAL else "CIVAN"
		check(meta.set_unit_skill(unit_id,"passive",0,card), "passive equipment accepts intended unit")
		check(not meta.set_unit_skill("GHOST" if card==Commission.SEAL else "IVAN","passive",0,card), "ordinary executor cannot equip chrono card")
		check(preload("res://scripts/ui/progression_icon.gd").texture(card)!=null, "card has dedicated icon")
