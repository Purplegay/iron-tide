extends "res://tests/base_recovery_regression.gd"
const Complete=preload("res://scripts/admin/gm_hero_contracts.gd")
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")

class FailedSave:
	extends RefCounted
	var academy:Dictionary={"card_shards":17,"hero_contracts":{"E1":{"first":9,"second":3,"win":false,"complete":false}},"levels":{"ap_watch_posts":2}}
	var currency:Dictionary={"cores":59,"diamonds":125}
	var unlocked_skills:Array=["ap_watch_posts"]
	func save() -> bool: return false

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	MetaProgress.load_save() # Run the normal profile migrations before testing a round trip.
	MetaProgress.academy.levels={"ap_watch_posts":2,"ap_furnace_bastion":3}
	MetaProgress.academy.hero_builds.E2=12
	MetaProgress.academy.card_shards=27
	MetaProgress.academy.tickets=4
	MetaProgress.unlocked_skills.append("ap_watch_posts")
	var money:Dictionary=MetaProgress.currency.duplicate(true)
	var before_levels:Dictionary=MetaProgress.academy.levels.duplicate(true)
	var before_heroes:Dictionary=MetaProgress.academy.hero_builds.duplicate(true)
	var result:=Complete.complete(MetaProgress)
	check(result.ok and result.contracts==Pool.entries().size() and result.rewards==Pool.reward_count(),"GM dynamically completes configured hero catalog")
	check(result.added==Pool.reward_count()-1,"existing rewards are not duplicated")
	check(MetaProgress.academy.furnace_contract and MetaProgress.academy.furnace_complete,"Furnace contract is owned and complete")
	var tasks:Dictionary=MetaProgress.academy.furnace_tasks
	check(tasks.takedown and tasks.peace and tasks.damage>=10000,"Furnace tasks show completed progress")
	for row in Pool.entries():
		check(Pool.owned(MetaProgress,row),"owned contract "+row.id)
		if row.hero_id!="E2":
			var quest:Dictionary=MetaProgress.academy.hero_contracts[row.hero_id]
			check(quest.complete and quest.win and quest.first>=Contracts.GOALS[row.hero_id][0] and quest.second>=Contracts.GOALS[row.hero_id][1],"completed task counters "+row.hero_id)
		for card in row.cards: check(MetaProgress.unlocked_skills.count(card)==1,"unlocked reward exactly once "+card)
	check(Pool.candidates(MetaProgress).is_empty(),"completed contracts leave the draw pool")
	check(MetaProgress.currency==money and MetaProgress.academy.card_shards==27 and MetaProgress.academy.tickets==4,"GM completion consumes no currency tickets or shards")
	check(MetaProgress.academy.levels==before_levels and MetaProgress.academy.hero_builds==before_heroes,"existing skill ranks and hero recruitment progress preserved")
	var saved:Dictionary=MetaProgress.academy.duplicate(true)
	var cards:Array=MetaProgress.unlocked_skills.duplicate()
	result=Complete.complete(MetaProgress)
	check(result.ok and result.added==0 and MetaProgress.academy==saved and MetaProgress.unlocked_skills==cards,"repeated completion is idempotent")
	MetaProgress.academy={}
	MetaProgress.unlocked_skills.clear()
	MetaProgress.load_save()
	# JSON restores numeric values as floats; compare against the persisted representation.
	check(MetaProgress.academy==JSON.parse_string(JSON.stringify(saved)) and MetaProgress.unlocked_skills==cards,"real save and reload retains all completed contracts and rewards")
	var failed_save=FailedSave.new()
	var old_tasks:Dictionary=failed_save.academy.duplicate(true)
	var old_funds:Dictionary=failed_save.currency.duplicate(true)
	var old_cards:Array=failed_save.unlocked_skills.duplicate()
	result=Complete.complete(failed_save)
	check(not result.ok and failed_save.academy==old_tasks and failed_save.currency==old_funds and failed_save.unlocked_skills==old_cards,"save failure restores the entire batch")
	var config:=Pool.rules()
	var catalog:Array=config.entries
	config.entries=[Pool.for_hero("MTNK")]
	MetaProgress.reset_save()
	result=Complete.complete(MetaProgress)
	check(result.ok and result.contracts==1 and result.rewards==2 and MetaProgress.academy.hero_contracts.size()==1 and MetaProgress.academy.hero_contracts.has("MTNK") and not MetaProgress.academy.get("furnace_contract",false),"GM follows a changed catalog instead of hardcoding four heroes")
	config.entries=catalog.duplicate(true)
	config.entries.append({"id":"gm_unknown_contract","hero_id":"UNKNOWN","name":"未知契约","cards":[]})
	var before_invalid:Dictionary=MetaProgress.academy.duplicate(true)
	var cards_before_invalid:Array=MetaProgress.unlocked_skills.duplicate()
	result=Complete.complete(MetaProgress)
	check(not result.ok and MetaProgress.academy==before_invalid and MetaProgress.unlocked_skills==cards_before_invalid,"missing task configuration rejects the entire batch before granting anything")
	config.entries=catalog
	# Exercise the real GM button and command, in the isolated user directory only.
	MetaProgress.reset_save()
	var console=preload("res://scripts/admin/gm_console.gd").new()
	console.embed_mode=true
	add_child(console)
	var button=console.find_child("CompleteHeroContracts",true,false)
	check(button!=null and button.text=="一键完成全部英雄契约","GM console exposes one-click hero task completion")
	if button!=null:
		button.pressed.emit()
		check(Pool.candidates(MetaProgress).is_empty() and console._status.text.contains("已获得并完成全部"),"button invokes command saves state and displays result")
	console.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("GM HERO CONTRACTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
