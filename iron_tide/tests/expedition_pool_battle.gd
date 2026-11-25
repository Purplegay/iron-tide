extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	if not OS.get_user_data_dir().contains("IronTidePoolResearchValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	BattleRequest.combat_context.loadouts={"DLPH":{"active":["ap_sonar_jam"]},"CARRIER":{"active":["ap_carrier_reserve"]}}
	BattleRequest.combat_context.card_ranks={"ap_sonar_jam":3}
	battle.fog=null
	var dolphin=battle.spawn_unit("DLPH","ally",Vector2(1200,1200))
	var ship=battle.spawn_unit("HYD","enemy",Vector2(1280,1200))
	var index:=UnitSkillLayout.index(dolphin,1)
	battle.select_unit(dolphin,false)
	check(battle.request_ability(index)==-1,"manual target mode")
	battle.cancel_cast()
	dolphin.attack_target=ship;ship._cd_timer=5.0
	check(Unit.PoolCards.automatic(dolphin,dolphin.ability_at(index),index),"automatic sonar")
	check(is_equal_approx(ship.special.get("sonar_reload_lock",0),5.0),"rank 3 lock")
	ship._physics_process(0.1)
	check(is_equal_approx(ship._cd_timer,5),"ship reload paused during real physics")
	var carrier=battle.spawn_unit("CARRIER","ally",Vector2(1150,1150))
	var count:int=carrier.logistics.squadron.size()
	check(carrier.use_ability(UnitSkillLayout.index(carrier,1)) and carrier.logistics.squadron.size()==count+2,"carrier capacity")
	carrier.logistics.tick_squadron(11.0)
	check(carrier.logistics.squadron.size()==count,"expired unused berths")
	var interface=preload("res://scripts/expedition/screen.gd").new()
	add_child(interface)
	preload("res://scripts/expedition/research.gd").open(interface)
	var dialogs=interface.find_children("*","AcceptDialog",true,false)
	check(dialogs.size()>0 and dialogs.back().find_children("*","Button",true,false).size()>=40,"research panel")
	interface.free()
	await finish()
	print("POOL_BATTLE checks=",checks.size()," failures=",failed)
	get_tree().quit(int(failed>0))
