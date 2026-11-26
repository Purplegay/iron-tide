extends "res://tests/expedition_relics_regression.gd"

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	new_ready("美国",26)
	var run:Dictionary=Expedition.state.duplicate(true)
	run.licenses=["E1"]
	for stage in range(25,31):
		run.stage=stage
		for id in Catalog.BUFFS:
			run.buffs[id]=3 if int(Catalog.BUFFS[id].get("min_stage",1))<stage else 0
		for key in Army.TRAITS:
			run.trait_buffs[key]=9 if int(Army.TRAITS[key].get("min_stage",1))<stage else 0
		var gear:=Market.buff_pool(run)
		check(gear.size()==int(stage>=26),"one newly open equipment at stage %d"%stage)
		for item in gear:check(Catalog.BUFFS[item.id].min_stage==stage,"equipment gate")
		check(Market.trait_pool(run).size()==int(stage in [26,28]),"new school at stage %d"%stage)
		if stage>=26:check(Market.bonus_rewards(run).any(func(item):return item.kind in ["buff","trait_buff","relic"]),"bonus round offers an upgrade")
	var save:Dictionary=Expedition.state.duplicate(true)
	save.stage=30
	Expedition.grant(save,{"kind":"trait_buff","id":"siege_team"})
	Expedition.grant(save,{"kind":"buff","id":"escort_plate"})
	Relics.grant(save,"reserve_credit")
	check(Expedition.commit(save) and Expedition.load_run() and Expedition.state.trait_buffs.siege_team==1 and Expedition.state.buffs.escort_plate==1 and Relics.level(Expedition.state,"reserve_credit")==1,"new acquisitions persist")
	for i in 4:Relics.grant(save,"field_procurement")
	check(Relics.refresh_price(save,30)==22 and Relics.refresh_price(save,0)==0,"procurement price and free refresh")
	new_ready("美国",26)
	Expedition.launch(0)
	if instantiate_battle():
		var gun=actor("E1")
		var first=actor("MTNK","enemy")
		var second=actor("MTNK","enemy")
		equip([])
		Rules.context().trait_buffs={"pursuit":9,"siege_team":9}
		Rules.context().buffs={"pivot_sight":1,"sight_memory":1,"rescue_patch":1,"escort_plate":3,"shield_lens":1}
		time_at(10)
		var initial:float=gun.hp
		hit(gun,first,124,"opening hit")
		check(is_equal_approx(gun.hp-initial,gun.max_hp*0.03),"low-health patch")
		hit(gun,second,149,"switch target")
		check(is_equal_approx(gun.special.expedition_shield,gun.max_hp*0.12),"larger of both shields")
		hit(gun,second,180,"follow-up with shield and same-target equipment")
		hit(gun,second,145,"third hit consumes siege cycle")
		check(is_equal_approx(gun.hp-initial,gun.max_hp*0.09) and second.special.get("expedition_suppressed_until",0)==14,"third hit heal and suppression")
		await finish()
	print("FINAL BUILDS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
