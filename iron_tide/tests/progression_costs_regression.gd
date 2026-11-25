extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	var m=MetaProgress
	var a=MetaProgress.Academy
	m.reset_save()
	m.currency={"credits":100000000,"cores":1000,"diamonds":777}
	check(m.available_talent_slots("MTNK")==1,"Grizzly has exactly one released talent")
	check(m.buy_talent_slot("MTNK",1),"first released slot can be bought")
	var before:float=m.balance("cores")
	check(not m.buy_talent_slot("MTNK",2) and m.balance("cores")==before,"unreleased second slot cannot charge cores")
	check(m.available_talent_slots("R3REAPER")==2 and m.buy_talent_slot("R3REAPER",1) and m.buy_talent_slot("R3REAPER",2),"two released Reaper talents retain both slots")
	var none_id:=""
	for id in GameData.unit_index:
		if m.talent_options(id).is_empty(): none_id=id;break
	check(not none_id.is_empty() and not m.buy_talent_slot(none_id,1),"no released talents means no first slot")
	m.talent_slots.MTNK=2
	m.save();m.load_save()
	check(m.talent_capacity("MTNK")==2 and not m.buy_talent_slot("MTNK",3),"old paid spare capacity survives without another purchase")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	ui._unit_sel="MTNK"
	m.talent_slots.MTNK=1
	ui._rebuild_unit_detail()
	check(ui.unit_detail.find_child("OpenTalentSlot",true,false)==null,"single talent UI hides second slot purchase")
	ui.free()
	for track in ["atk","def","skill"]:
		var uid := "E1" if track == "skill" else "MTNK"
		m.unit_levels={}
		var start_balance:float=m.balance("credits")
		for level in 20:
			check(m.unit_level(uid,track)==level and m.buy_unit_upgrade(uid,track),"unit "+track+" purchase "+str(level+1))
		check(start_balance-m.balance("credits")==576096,"unit "+track+" total price is 576096")
		var balance_after:float=m.balance("credits")
		check(m.unit_level(uid,track)==20 and not m.buy_unit_upgrade(uid,track) and m.balance("credits")==balance_after,"unit "+track+" cap prevents further charge")
		m.save();m.load_save()
		check(m.unit_level(uid,track)==20,"unit "+track+" level survives reload")
	m.unit_levels={"MTNK":{"atk":12,"def":12,"skill":10}}
	m.academy.hero_builds={"E1":50,"E2":50}
	m.academy.hero_training={"E1":{"firepower":199,"health":199},"E2":3}
	m.save();m.load_save()
	check(m.unit_level("MTNK","atk")==12 and m.unit_level("MTNK","def")==12 and m.unit_level("MTNK","skill")==10,"old ordinary levels retained")
	var bonus:Dictionary=m.unit_stat_bonus("MTNK")
	check(is_equal_approx(bonus.attack_bonus,1.09) and is_equal_approx(bonus.defense_bonus,1.075) and is_equal_approx(bonus.skill_bonus,1.0),"paid stat training quartered and retired skill track inactive")
	check(a.training_cap("firepower")==200 and a.training_cap("health")==200,"both hero training tracks have 200 levels")
	m.currency.credits=358608
	before=m.balance("cores")
	check(a.purchase(m,"firepower","E1") and a.purchase(m,"health","E1") and m.balance("credits")==0 and m.balance("cores")==before,"final hero purchases charge 179304 credits each")
	check(a.training_percent("firepower",200)==100 and a.training_percent("health",200)==150,"hero final bonuses quartered")
	m.currency.credits=1000000
	check(not a.purchase(m,"health","E1") and not a.purchase(m,"firepower","E1"),"hero cap cannot be bought again")
	m.currency.credits=0
	check(not a.purchase(m,"health","E2"),"cores cannot substitute for insufficient hero credits")
	m.currency.credits=a.hero_training_cost(3)
	check(a.purchase(m,"health","E2") and m.academy.hero_training.E2=={"firepower":3,"health":4},"legacy combined hero rank preserved on credit purchase")
	m.save();m.load_save()
	check(a.training_rank(m.academy.hero_training,"E2","firepower")==3 and a.training_rank(m.academy.hero_training,"E2","health")==4,"hero training survives reload")
	m.currency.credits=100000.0
	m.save()
	var bytes:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	var wallet:Dictionary=m.currency.duplicate()
	var levels:Dictionary=m.unit_levels.duplicate(true)
	var academy:Dictionary=m.academy.duplicate(true)
	check(DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")==OK,"block isolated save target")
	check(not m.buy_unit_upgrade("MTNK","atk") and m.currency==wallet and m.unit_levels==levels,"failed ordinary upgrade rolls back price and level")
	check(not a.purchase(m,"health","E2") and m.currency==wallet and m.academy==academy,"failed hero upgrade rolls back price and level")
	check(FileAccess.get_file_as_bytes(m.SAVE_PATH)==bytes,"failed writes preserve original profile bytes")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	check(m.buy_unit_upgrade("MTNK","atk") and a.purchase(m,"health","E2"),"purchases recover after storage recovers")
	check(m.balance("diamonds")==777,"all progression leaves diamonds untouched")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
