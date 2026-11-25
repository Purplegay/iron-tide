extends Node
const Rules=preload("res://scripts/expedition/rules.gd")
var checks:=0
var failed:=0
func check(ok:bool,label:String,details="") -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",label," ",details)
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir",false) and not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	var saved:=BattleRequest.combat_context.duplicate(true)
	BattleRequest.combat_context={"expedition":{
		"catalog":["MTNK","HTNK"],"licenses":["MTNK"],"active_roster":[],
		"condition":"normal","stage":1}}
	check(Rules.block_reason("MTNK","ally").is_empty(),"licensed unlocked unit produces outside active roster")
	check(not Rules.block_reason("HTNK","ally").is_empty(),"catalog unit without license remains blocked")
	check(not Rules.block_reason("APOC","ally").is_empty(),"unit outside expedition catalog remains blocked")
	BattleRequest.combat_context.expedition.licenses.append("HTNK")
	BattleRequest.combat_context.expedition.technology={"HTNK":false}
	check(Rules.block_reason("HTNK","ally").is_empty(),"licensed unit is not blocked by active roster")
	var battle := Battle.new()
	battle.skirmish = true
	battle._countries = {"ally":"Arabs", "enemy":"Arabs"}
	BattleRequest.combat_context.expedition.catalog.append("TTNK")
	check(not battle.country_block_reason("TTNK").is_empty(), "Iraqi player without Tesla Tank license sees country lock")
	BattleRequest.combat_context.expedition.licenses.append("TTNK")
	check(battle.country_block_reason("TTNK").is_empty() and Rules.block_reason("TTNK", "ally").is_empty(), "licensed Iraqi player passes Tesla Tank gates")
	check(not battle.country_block_reason("TTNK", "enemy").is_empty(), "enemy cannot use player license")
	BattleRequest.combat_context = {}
	check(not battle.country_block_reason("TTNK").is_empty(), "skirmish retains Tesla Tank country lock")
	battle.free()
	if OS.get_environment("IRON_TIDE_VERIFY_PRISM") == "1":
		check_prism_checkpoint()
	BattleRequest.combat_context=saved
	print("EXPEDITION PRODUCTION UNLOCK checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_prism_checkpoint() -> void:
	check(Expedition.state.get("stage", 0) == 19 and Expedition.prepare_battle(), "restore stage 19 checkpoint")
	var screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var world = screen.battle
	check("GATECH" not in world.owned_building_ids("ally"), "no allied battle lab")
	for factory in world.buildings:
		if factory.side != "ally" or factory.building_id != "GAWEAP": continue
		screen.hud.prod_tab = "vehicle"
		screen.hud._factories.remember(factory, "vehicle")
		check("SREF" in screen.hud._unit_catalog(), "licensed prism tank visible")
		check(factory.enqueue("SREF") and factory.unit_prereqs_ok("SREF"), "prism tank accepted and eligible for production")
		while factory.production.size() < factory.queue_capacity(): factory.production.append("SREF")
		check("SREF" in screen.hud._unit_catalog() and not factory.queue_block_reason("SREF").is_empty(), "full queue keeps tank visible")
		Rules.context().licenses.erase("SREF")
		check("SREF" not in screen.hud._unit_catalog() and not factory.enqueue("SREF"), "missing license hides tank and rejects order")
		return
	check(false, "allied war factory present")