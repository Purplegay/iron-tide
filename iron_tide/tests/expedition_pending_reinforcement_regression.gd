extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	await check_pending_is_not_loss()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PENDING REINFORCEMENT checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_pending_is_not_loss() -> void:
	start(MatchRules.EXTENDED)
	var context:Dictionary=BattleRequest.combat_context.get("expedition",{})
	context.catalog=["MTNK","E1"]
	context.active_roster=["MTNK"]
	context.licenses=["MTNK","E1"]
	BattleRequest.combat_context.expedition=context
	Expedition.state={"catalog":["MTNK","E1"],"active_roster":["MTNK"],"stage":1,"trait_buffs":{},"survivors":[],"reinforcements":[]}
	battle.allied_state.expedition_reinforcement_plan=[
		{"id":"MTNK","hero":"","variant":"","due":9999.0},
		{"id":"E1","hero":"E1","variant":"","due":9999.0}
	]
	var rows:=Expedition.collect(battle)
	var tanks:=0;var heroes:=0
	for row:Dictionary in rows:
		if row.id=="MTNK":tanks+=1
		if row.get("hero","")=="E1":heroes+=1
	check(tanks==1,"pending tank returns as intact reserve, not a loss")
	check(heroes==1,"pending hero remains available and not wounded")
	check(rows.any(func(row):return row.id=="MTNK" and row.get("hp",0)==1.0),"pending unit returns full health")
	await finish()
