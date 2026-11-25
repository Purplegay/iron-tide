extends "res://tests/base_recovery_regression.gd"
const Unlock=preload("res://scripts/admin/gm_heroes.gd")
const Academy=preload("res://scripts/rules/academy.gd")

class FailedSave:
	extends RefCounted
	var academy:Dictionary={"hero_builds":{"ORCA":3},"hero_contracts":{"ORCA":{"first":2}},"hero_escort_ranks":{"ORCA":1}}
	var currency:Dictionary={"credits":99,"cores":12}
	var unlocked_skills:Array=["ap_smoke"]
	func save() -> bool:return false

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	MetaProgress.reset_save();MetaProgress.load_save()
	MetaProgress.academy.hero_builds={"E1":77,"ORCA":3,"TTNK":5}
	MetaProgress.academy.hero_escort_ranks={"ORCA":2}
	MetaProgress.academy.hero_contracts={"ORCA":{"first":3,"second":2,"win":false,"complete":false}}
	var original:Dictionary=MetaProgress.academy.duplicate(true)
	var funds:Dictionary=MetaProgress.currency.duplicate(true)
	var cards:Array=MetaProgress.unlocked_skills.duplicate()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","difficulty":1,"map_size":2400})
	BattleRequest.freeze_combat_context()
	var frozen:Dictionary=BattleRequest.combat_context.duplicate(true)
	var ui=load("res://scenes/meta.tscn").instantiate();ui.initial_page="heroes";add_child(ui)
	ui.heroes.selected="ORCA";ui.heroes.refresh()
	var console=preload("res://scripts/admin/gm_console.gd").new();console.embed_mode=true;add_child(console)
	var button:Button=console.find_child("UnlockAllHeroes",true,false)
	check(button!=null and button.text=="一键解锁所有英雄","GM exposes explicit unlock-all-heroes button")
	if button!=null:button.pressed.emit()
	for id:String in Academy.HEROES:
		check(Academy.hero_build_count(MetaProgress,id)>=Academy.hero_requirement(id),"one click unlocks configured hero "+id)
	check(console._status.text.contains("全部 8 名") and console._status.text.contains("新增 6 名"),"command reports actual total and newly unlocked count")
	check(MetaProgress.academy.hero_builds.E1==77,"higher existing production progress is preserved")
	var expected:Dictionary=original.duplicate(true);expected.hero_builds=MetaProgress.academy.hero_builds.duplicate(true)
	check(MetaProgress.academy==expected and MetaProgress.currency==funds and MetaProgress.unlocked_skills==cards,"only hero unlock counters change; ranks contracts cards and funds stay intact")
	check(BattleRequest.combat_context==frozen,"GM does not rewrite active match eligibility or spawn units")
	check(ui.heroes.progress_label.text.begins_with("已解锁") and ui.heroes.hero_buttons.ORCA.text.contains("已解锁"),"real meta event refreshes flat hero roster immediately")
	var saved:Dictionary=MetaProgress.academy.duplicate(true)
	var result:=Unlock.unlock_all(MetaProgress)
	check(result.ok and result.added==0 and MetaProgress.academy==saved,"repeat click is idempotent")
	console.free();ui.free();await get_tree().process_frame
	MetaProgress.academy={};MetaProgress.load_save()
	check(MetaProgress.academy==JSON.parse_string(JSON.stringify(saved)),"all unlocks survive actual profile reload")
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":"美国","difficulty":1,"map_size":2400})
	BattleRequest.freeze_combat_context()
	for id in ["ORCA","TTNK"]:check(BattleRequest.combat_context.reinforcement_hero_unlocked[id],"next match enables gift hero "+id)
	for id in ["TANY","BORIS"]:check(BattleRequest.combat_context.commando_hero_unlocked[id],"next match enables commando hero "+id)
	var failed_save=FailedSave.new()
	var before:Dictionary=failed_save.academy.duplicate(true)
	var old_funds:Dictionary=failed_save.currency.duplicate(true)
	var old_cards:Array=failed_save.unlocked_skills.duplicate()
	result=Unlock.unlock_all(failed_save)
	check(not result.ok and result.error.contains("已恢复") and failed_save.academy==before and failed_save.currency==old_funds and failed_save.unlocked_skills==old_cards,"failed save rolls back complete unlock batch")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
