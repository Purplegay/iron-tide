extends "res://tests/ground_control_regression.gd"
const Indicator=preload("res://scripts/ui/talent_stack_indicator.gd")
const Reserve=preload("res://scripts/units/tesla_reserve.gd")
const Growth=preload("res://scripts/units/radiation_growth.gd")
const Split=preload("res://scripts/units/ra3_reaper_split.gd")

func make(id:String):
	var unit=battle.spawn_unit(id,"ally",Vector2(1200,1200))
	activate(unit)
	return unit

func exercise(mode:String) -> void:
	start(mode)
	BattleRequest.combat_context.unit_talents={"SHK":{"tesla_reserve":3},"DESO":{"deso_expansion":3},"R3REAPER":{"reaper_fire_control":3}}
	var tesla=make("SHK")
	if mode==MatchRules.RA2:
		check(Indicator.rows(tesla).is_empty(),"classic mode never shows extension stacks")
		await finish();return
	check(Indicator.rows(tesla)[0].count==0 and Indicator.rows(tesla)[0].limit==3,"allocated zero stacks remain readable")
	for i in 3:
		Reserve.tick(tesla,3)
		check(Indicator.rows(tesla)[0].count==i+1,"display follows real Tesla charge "+str(i+1))
	var original:Dictionary=tesla.special.duplicate(true)
	for i in 20:Indicator.rows(tesla)
	check(tesla.special==original,"reading display never advances simulation or changes state")
	Reserve.discharge(tesla)
	check(Indicator.rows(tesla)[0].count==0,"discharge clears visible layers immediately")
	var deso=make("DESO");deso.set_deployed(true,false)
	for i in 3:
		Growth.tick(deso,1.5)
		check(Indicator.rows(deso)[0].count==i+1,"display follows deployed radiation growth "+str(i+1))
	deso.set_deployed(false,false)
	check(Indicator.rows(deso).is_empty(),"standing up hides radiation stacks")
	var reaper=make("R3REAPER")
	var main=battle.spawn_unit("HTNK","enemy",Vector2(1350,1200))
	var secondary=battle.spawn_unit("HTNK","enemy",Vector2(1200,1350))
	reaper.attack_target=main
	reaper.special.split_enemy=secondary
	reaper.special.reaper_heat={main:[1.0,3.0,5.0],secondary:[4.0]}
	var entries:=Indicator.rows(reaper)
	check(entries.size()==2 and entries[0].count==3 and entries[1].count==1,"primary and secondary Heat never summed")
	check(entries[0].limit==4 and entries[1].limit==4,"Heat cap reads actual lifetime and charge interval")
	Split.advance_focus(reaper,1.1)
	check(Indicator.rows(reaper)[0].count==2 and Indicator.rows(reaper)[1].count==1,"expiry updates each target independently")
	reaper.special.reaper_heat[main]=2.5
	check(Indicator.rows(reaper)[0].count==1 and reaper.special.reaper_heat[main] is float,"legacy Heat reads one layer without migrating during draw")
	reaper.attack_target=secondary
	check(Indicator.rows(reaper).size()==1 and Indicator.rows(reaper)[0].count==1,"target switch displays matching target without double counting")
	var future=make("R3FUTURE")
	future.passive={"id":"ps_phase"};future.attack_target=main
	future.special.phase_target=main;future.special.phase_time=6.0
	check(Indicator.rows(future)[0].count==2,"Flux reads actual accumulated focus time")
	future.attack_target=secondary
	check(Indicator.rows(future)[0].count==0,"Flux never displays previous target layers on new target")
	var transport=make("BFRT")
	tesla.embarked_in=transport
	check(Indicator.rows(tesla).is_empty(),"passengers hide stack marker")
	tesla.embarked_in=null;tesla._dead=true
	check(Indicator.rows(tesla).is_empty(),"dead unit hides stack marker")
	check(Indicator.rows(transport).is_empty(),"unrelated unit has no stack marker")
	for i in 4:
		for j in 4:
			if i!=j:check(Indicator.layer_color(i)!=Indicator.layer_color(j),"layer colors distinct "+str(i)+"/"+str(j))
	check(Indicator.layer_color(-1)==Indicator.COLORS[0] and Indicator.layer_color(99)==Indicator.COLORS[3],"palette has bounded fallback")
	await finish()
