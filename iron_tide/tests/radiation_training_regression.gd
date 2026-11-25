extends "res://tests/ground_control_regression.gd"
const Soviet=preload("res://scripts/units/soviet_specials.gd")
const Training=preload("res://scripts/rules/skill_training.gd")

func migration() -> void:
	var m=MetaProgress
	for rank in 4:
		m.reset_save()
		m.currency.cores=1000;m.owned_talent_points=2;m.talent_slots={"DESO":2}
		m.unit_talents={"DESO":{"deso_expansion":2,"deso_sample":rank}}
		m.unit_levels={"DESO":{"skill":13}}
		m.disabled_effects={"talent/DESO/deso_sample":true}
		m.save();m.load_save()
		var expected:int=1000+[0,40,160,400][rank]
		check(m.balance("cores")==expected and m.unassigned_talent_points()==1,"refund exact rank cores and one allocated point "+str(rank))
		check(m.unit_talents.DESO=={"deso_expansion":2,"native_radiation":2} and m.unit_level("DESO","skill")==0 and m.talent_capacity("DESO")==2,"preserve growth, convert training, retain purchased slots")
		check(not m.disabled_effects.has("talent/DESO/deso_sample"),"retired effect switch removed")
		m.load_save();m.load_save()
		check(m.balance("cores")==expected and m.unassigned_talent_points()==1,"refund persists exactly once")
		check(not m.upgrade_talent("DESO","deso_sample",rank) and not m.set_unit_talent("DESO","deso_sample"),"retired talent cannot be purchased or allocated")
	m.unit_talents.DESO.deso_sample=3;m.owned_talent_points=2;m.currency.cores=20;m.save()
	var original:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")
	m.load_save();m.load_save()
	check(m.balance("cores")==420 and FileAccess.get_file_as_bytes(m.SAVE_PATH)==original,"failed migration write retries without cumulative refund")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	m.load_save();m.load_save()
	check(m.balance("cores")==420 and not m.unit_talents.DESO.has("deso_sample"),"migration persists after storage recovers")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui);ui._unit_sel="DESO"
	for rank in 4:
		m.unit_talents.DESO.native_radiation=rank
		ui._rebuild_unit_detail()
		var rows:=m.skill_training_benefits("DESO")
		check(rows.is_empty() and Training.talent_description("DESO").contains("12"),"retired training hidden, native cap described "+str(rank))
		check(ui.unit_detail.find_child("UpgradeTalent_deso_sample",true,false)==null and ui.unit_detail.find_child("Talent_deso_sample",true,false)==null,"retired talent UI absent")
	ui.free()

func exercise(mode:String) -> void:
	if mode==MatchRules.RA2: migration()
	start(mode)
	battle.fog=null;battle.paused=false;battle.ended=false;get_tree().paused=false
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	BattleRequest.combat_context.unit_talents={"DESO":{"deso_sample":3}}
	var deso=battle.spawn_unit("DESO","ally",Vector2(1200,1200));activate(deso)
	var target=battle.spawn_unit("HTNK","enemy",deso.position);activate(target)
	target.max_hp=100000;target.hp=target.max_hp
	check(not BattleRequest.has_unit_talent("DESO","deso_sample","ally"),prefix+"old frozen talent cannot reactivate")
	var base_damage:=0.0
	for rank in [-1,0,1,2,3]:
		battle.allied_state.erase("rad_sites")
		BattleRequest.combat_context.unit_talents.DESO={} if rank<0 else {"native_radiation":rank}
		Soviet.add_radiation(battle,deso.position,3,500,"ally",deso)
		var site:Dictionary=battle.allied_state.rad_sites[0]
		var expected:float=1.0+0.03*(rank+1) if mode==MatchRules.EXTENDED else 1.0
		check(is_equal_approx(site.training_damage,expected),prefix+"actual field factor rank "+str(rank))
		site.samplers={deso:{"bonus":99,"exposures":{target:3}}}
		site.pulse=0
		target.hp=target.max_hp
		Soviet.tick_world(battle,0)
		var damage:float=target.max_hp-target.hp
		if rank==-1:base_damage=damage
		check(absf(damage-base_damage*expected)<1.01 and damage>0 and not site.has("samplers"),prefix+"real damage bounded and no sample bonus rank "+str(rank))
	# Legacy field factors translate once and stay stable after serialization.
	var legacy:={"training_damage":2.2,"samplers":{}}
	Soviet.normalize_radiation_training(legacy);Soviet.normalize_radiation_training(legacy)
	check(is_equal_approx(legacy.training_damage,1.12) and not legacy.has("samplers"),prefix+"old +120 percent field converts exactly once")
	var codec=BattleSaves.Snapshot.new()
	var state:Dictionary=codec.capture(battle)
	codec.restore(battle,state)
	var restored:Dictionary=battle.allied_state.rad_sites[0]
	Soviet.normalize_radiation_training(restored)
	check(is_equal_approx(restored.training_damage,1.12 if mode==MatchRules.EXTENDED else 1.0),prefix+"snapshot preserves new factor without converting twice")
	await finish()
