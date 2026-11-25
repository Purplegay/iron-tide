extends "res://tests/electric_cards_regression.gd"
const Migration=preload("res://scripts/rules/native_talent_migration.gd")
const Training=preload("res://scripts/rules/skill_training.gd")
const Split=preload("res://scripts/units/ra3_reaper_split.gd")

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	BattleRequest.combat_context.native_training_version=4
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	for id in Training.PROFILES:
		var talent:=Training.talent_id(id)
		var actor=make(id,"ally",Vector2(1100,1100))
		actor.skill_power=99
		BattleRequest.combat_context.unit_talents={}
		check(Training.scale(actor)==1,"old skill power cannot amplify new battles "+id+mode)
		if talent.is_empty():
			check(Training.timing_scale(actor)==1,"transport training removed "+id+mode)
			clear_units();continue
		for rank in 4:
			BattleRequest.combat_context.unit_talents={id:{talent:rank}}
			var expected:float=1.3+rank*0.3 if mode==MatchRules.EXTENDED else 1.0
			check(is_equal_approx(Training.scale(actor),expected),"native talent effective rank "+id+str(rank)+mode)
			check(Training.timing_scale(actor)<=2.000001,"timing never more than fifty percent reduction")
			if id=="SCHP":check(Training.siege_extra(actor)<=2.000001,"siege range cap")
			if id=="DESO":check(Training.radiation_damage(actor)<=1.120001,"radiation twelve percent cap")
			if id in ["IVAN","CIVAN"]:check(Training.fuse(actor,30)>=15,"Ivan fuse floor")
		clear_units()
	for id in ["AMCV","SMCV","DOG","SOV_DOG"]:
		for rank in 4:
			BattleRequest.combat_context.unit_talents={id:{Training.talent_id(id):rank}}
			var actor=make(id,"ally",Vector2(1200,1200));actor.hull_angle=0
			actor.bonuses=MatchRules.neutral_bonuses()
			var enemy=make("HTNK","enemy",Vector2(1300,1200))
			var before:float=actor.hp
			actor.receive_hit(140,"bullet",{},enemy)
			var expected:float=floorf(140/(1.0+0.1*(rank+1))) if mode==MatchRules.EXTENDED else 140
			check(is_equal_approx(before-actor.hp,expected),"real frontal hit armor "+id+str(rank)+mode)
			enemy.position=actor.position+Vector2(-100,0);before=actor.hp
			actor.receive_hit(140,"bullet",{},enemy)
			check(is_equal_approx(before-actor.hp,140 if id in ["DOG","SOV_DOG"] else expected),"dog rear unprotected, MCV all around")
			if id in ["DOG","SOV_DOG"]:
				check(Training.defend(actor,140,null)==140,"unknown attack direction not reduced")
				enemy.position=actor.position+Vector2(100,0).rotated(PI/3+0.01)
				check(Training.defend(actor,140,enemy)==140,"outside front cone not reduced")
			clear_units()
	if mode==MatchRules.EXTENDED:
		check_migration()
		check_split_card()
	await finish()

func check_migration() -> void:
	var m=MetaProgress
	for level in [1,6,7,13,14,20]:
		m.reset_save();m.currency={"credits":777,"cores":999,"diamonds":888}
		for id in Training.PROFILES:
			if Training.talent_id(id).is_empty():continue
			m.unit_levels[id]={"skill":level,"atk":2}
		m.unit_talents={"CLEG":{"chrono_bookmark":2},"R3REAPER":{"reaper_fire_control":2,"reaper_split_fire":2}}
		m.owned_talent_points=4;m.talent_slots={"CLEG":1,"R3REAPER":2}
		m.disabled_effects={"track/E1/skill":true}
		m.unit_loadouts.R3REAPER={"active":["ap_twin"],"passive":""}
		m.save();m.load_save()
		var snapshot:Dictionary=m.to_dict().duplicate(true)
		for id in Training.PROFILES:
			var talent:=Training.talent_id(id)
			if talent.is_empty():continue
			check(m.talent_rank(id,talent,m.unit_talents)==Migration.folded_rank(level) and m.unit_level(id,"skill")==0,"migration rank "+id+str(level))
			check(m.talent_capacity(id)>=m.selected_talents(id,m.unit_talents).size() and m.unit_level(id,"atk")==2,"free required slots; other training retained")
		check(m.balance("credits")==777 and m.balance("cores")==999 and m.unassigned_talent_points()==2,"no charge, keeps free points and returns split point")
		check(not m.effect_enabled("talent","native_deploy_def","E1"),"disabled old training stays disabled")
		check(m.unlocked_skills.has(Split.ID) and m.Academy.card_rank(m,Split.ID)==2 and m.unit_loadouts.R3REAPER.active==["ap_twin"],"split talent transfers card rank without replacing equipped W")
		m.load_save()
		var differences:Dictionary={}
		for key in snapshot:
			if JSON.parse_string(JSON.stringify(snapshot[key]))!=JSON.parse_string(JSON.stringify(m.to_dict()[key])):differences[key]=[snapshot[key],m.to_dict()[key]]
		check(differences.is_empty(),"repeated load does not duplicate points or card",differences)
		check(not m.can_buy_unit_upgrade("E1","skill") and m.skill_training_benefits("E1").is_empty() and not m.unit_upgrade_tracks().any(func(t):return t.id=="skill"),"retired training absent and not purchasable")
	# Deleted transport benefits refund exactly what was paid, once.
	m.reset_save();m.currency.credits=77
	for id in ["LCRF","SAPC","SHAD"]:m.unit_levels[id]={"skill":2}
	m.save();m.load_save()
	check(m.balance("credits")==77+3*(500+675) and m.unit_talents.is_empty(),"transport training refunded and no new talent")
	m.load_save();check(m.balance("credits")==77+3*(500+675),"transport refund idempotent")
	m.unit_levels.E1={"skill":20};m.save()
	var bytes:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp");m.load_save()
	var points:int=m.owned_talent_points
	check(FileAccess.get_file_as_bytes(m.SAVE_PATH)==bytes,"failed migration save preserves original bytes")
	m.load_save();check(m.owned_talent_points==points,"failure reload never duplicates grant")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp");m.load_save();m.load_save()
	check(m.owned_talent_points==points and m.talent_rank("E1","native_deploy_def",m.unit_talents)==3,"migration succeeds once after failed write")
	BattleRequest.freeze_combat_context()
	check(BattleRequest.combat_context.native_training_version==4 and BattleRequest.unit_bonus("E1").skill_bonus==1,"new match uses talent rules, no old multiplier")
	var ui=load("res://scenes/meta.tscn").instantiate();add_child(ui)
	for id in Training.PROFILES:
		if Training.talent_id(id).is_empty():continue
		ui._unit_sel=id;ui._rebuild_unit_detail()
		check(Training.talent_description(id).contains("3 级"),"four level description "+id)
		ui._show_talent_demo(id,Training.talent_id(id),3)
		var panel=ui.get_node_or_null("TalentDemo")
		check(panel!=null,"numeric preview opens "+id)
		if panel!=null:panel.free()
	ui.free()

func check_split_card() -> void:
	var m=MetaProgress;m.reset_save();m.academy.card_shards=999
	check(m.skill_draw_candidates().any(func(c):return c.id==Split.ID),"split card included in pool")
	check(not m.set_unit_skill("R3REAPER","active",0,Split.ID),"unowned split cannot equip")
	check(m.Academy.purchase(m,"redeem",Split.ID) and m.set_unit_skill("R3REAPER","active",0,Split.ID),"epic redemption and W equip")
	check(not m.set_unit_skill("SHK","active",0,Split.ID),"other units cannot equip")
	for rank in 4:
		m.academy.get_or_add("levels",{})[Split.ID]=rank
		m.unit_talents={"R3REAPER":{"reaper_fire_control":3,"native_leap":3}}
		BattleRequest.freeze_combat_context()
		var gun=make("R3REAPER","ally",Vector2(1200,1200))
		var main=make("HTNK","enemy",gun.position+Vector2(140,0))
		var other=make("HTNK","enemy",gun.position+Vector2(0,140))
		gun.hull_angle=0;gun.turret_angle=0;gun.attack_target=main;gun.attack_ordered=true
		battle.select_unit(gun,false)
		check(Split.unlocked(gun) and UnitSkillLayout.info(gun,1).id==Split.ID and UnitSkillLayout.info(gun,2).get("id","")!=Split.ID,"W split and E native separate")
		screen.hud._cast_ability(1)
		check(battle.command_mode==Split.ID,"actual W button enters target selection")
		Split.confirm(battle,other.position)
		check(gun.special.get("split_enemy")==other and battle.command_mode=="","select secondary enemy confirms split")
		var shot:=Projectile.new();shot.target=other;shot.splinters={"amount":100.0}
		Split.apply_shot_talents(gun,shot)
		check(is_equal_approx(shot.splinters.amount,float([100,110,135,150][rank])),"side round uses card rank damage")
		shot.free();gun.order_stop()
		check(not gun.special.has("split_enemy"),"stop clears assignment")
		clear_units()

	# Same equipped card remains usable after leap deployment and a battle save/load.
	var walker=make("R3REAPER","ally",Vector2(1600,1600))
	var soviet=preload("res://scripts/units/ra3_soviet.gd")
	soviet.use(walker,walker.position+Vector2(60,0))
	soviet.tick(walker,soviet.Leap.TAKEOFF_SECONDS+float(walker.special.walker_jump.flight)+0.01)
	var tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")[0]
	tower._buildup_play=-1;tower._think=99
	var primary=make("HTNK","enemy",tower.position+Vector2(140,0))
	var side_target=make("HTNK","enemy",tower.position+Vector2(0,140))
	var mount=preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(tower)
	mount.hull_angle=0;mount.turret_angle=0;mount.attack_target=primary;mount.attack_ordered=true
	tower.attack_target=primary;tower.special.reaper_ordered_target=primary
	battle.select_building(tower);screen.hud._rebuild_ability_bar()
	check(screen.hud._reaper_split_btn!=null and not screen.hud._reaper_split_btn.disabled,"deployed form has ready W card button")
	screen.hud._reaper_split_btn.pressed.emit()
	check(battle.command_mode==Split.ID and battle.split_gunner==mount,"deployed button enters W target selection")
	Split.confirm(battle,side_target.position)
	check(mount.special.get("split_enemy")==side_target and is_equal_approx(Split.damage_scale(mount),1.5),"deployed W selects side target at retained card rank")
	var saved=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,saved)
	tower=battle.buildings.filter(func(b):return b.building_id=="R3REAPERTURRET")[0]
	mount=preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(tower)
	check(Split.unlocked(mount) and is_equal_approx(Split.damage_scale(mount),1.5) and is_instance_valid(mount.special.get("split_enemy")),"deployed W ownership rank and target survive snapshot")
