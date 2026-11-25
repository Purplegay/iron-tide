extends RefCounted
const Income=preload("res://scripts/expedition/income.gd")

static func run(t) -> void:
	var total_credits:=0
	var total_cores:=0
	for stage in range(1,31):
		var reward:=Income.quote(stage)
		t.check(reward.credits==[800,1200,1600,2000,2400,2800][(stage-1)/5] and reward.cores==[20,30,40,50,60,70][(stage-1)/5],"income chapter boundary "+str(stage))
		total_credits+=reward.credits
		total_cores+=reward.cores
	t.check(total_credits==54000 and total_cores==1350,"full campaign income totals")
	t.new_ready("美国")
	t.check(Expedition.launch(0),"income test launch")
	if not t.instantiate_battle():await t.finish();return
	var before:Dictionary=MetaProgress.currency.duplicate(true)
	var receipts:Dictionary=MetaProgress.settled_matches.duplicate(true)
	var before_stats:Dictionary=MetaProgress.stats.duplicate(true)
	var original:Dictionary=Expedition.state.duplicate(true)
	var original_bytes:=var_to_bytes(Expedition.state)
	var exp_tmp:String=Expedition.FILE+".tmp"
	if FileAccess.file_exists(exp_tmp):DirAccess.remove_absolute(exp_tmp)
	t.check(DirAccess.make_dir_absolute(exp_tmp)==OK,"block expedition temporary file")
	var rejected:=not Expedition.settle(t.battle,true)
	var changed_keys:Array=[]
	for key:String in original:
		if original[key]!=Expedition.state.get(key):changed_keys.append(key)
	t.check(rejected and var_to_bytes(Expedition.state)==original_bytes and MetaProgress.currency==before,"failed run write cannot grant income or advance stage",{"rejected":rejected,"changed_keys":changed_keys,"wallet_before":before,"wallet_after":MetaProgress.currency.duplicate(true)})
	t.check(DirAccess.remove_absolute(exp_tmp)==OK,"restore expedition write path")
	var meta_tmp:String=MetaProgress.SAVE_PATH+".tmp"
	if FileAccess.file_exists(meta_tmp):DirAccess.remove_absolute(meta_tmp)
	t.check(DirAccess.make_dir_absolute(meta_tmp)==OK,"block permanent temporary file")
	t.check(Expedition.settle(t.battle,true),"victory remains durable when permanent save fails")
	t.check(Expedition.state.phase=="reward" and Income.has_pending(Expedition.state,MetaProgress),"durable victory retains pending grant")
	t.check(MetaProgress.currency==before and MetaProgress.settled_matches==receipts,"failed permanent write rolls back both wallet and receipt")
	var pending:Dictionary=Expedition.state.duplicate(true)
	t.check(not Expedition.start("苏俄") and Expedition.state==pending,"cannot overwrite an undelivered reward with a new run")
	t.check(Expedition.load_run() and Income.has_pending(Expedition.state,MetaProgress),"pending reward survives disk reload")
	t.check(DirAccess.remove_absolute(meta_tmp)==OK,"restore permanent write path")
	t.check(Expedition.load_run() and not Income.has_pending(Expedition.state,MetaProgress),"reload automatically delivers saved pending reward")
	t.check(MetaProgress.balance("credits")==float(before.credits)+800 and MetaProgress.balance("cores")==float(before.cores)+20,"recovery pays exact frozen amount")
	var paid:Dictionary=MetaProgress.currency.duplicate(true)
	MetaProgress.load_save()
	t.check(MetaProgress.currency==paid and Expedition.load_run() and MetaProgress.currency==paid,"receipt and wallet survive disk reload without duplicate")
	t.check(Expedition.commit(original) and Expedition.settle(t.battle,true) and MetaProgress.currency==paid,"replaying earlier battle state cannot duplicate permanent grant")
	for key:String in ["battles","battles_won","appearance_wins"]:
		t.check(int(MetaProgress.stats.get(key,0))==int(before_stats.get(key,0)),"expedition income does not change ordinary match stat "+key)
	var ui=load("res://scenes/expedition.tscn").instantiate()
	t.add_child(ui)
	await t.get_tree().process_frame
	t.check(contains_text(ui,"远征额外已到账：军需券 800 · 战略核心 20"),"reward page displays actual paid totals")
	ui.tab=3;ui.build_history()
	t.check(contains_text(ui,"军需券 +800 · 战略核心 +20（已到账）"),"history displays persisted receipt")
	ui.queue_free()
	await t.finish()
	t.new_ready("美国",6)
	ui=load("res://scenes/expedition.tscn").instantiate();t.add_child(ui)
	await t.get_tree().process_frame
	t.check(contains_text(ui,"额外胜利收益：军需券 +1200 · 战略核心 +30"),"route displays next chapter income")
	ui.queue_free()
	await t.get_tree().process_frame

static func contains_text(node:Node,text:String) -> bool:
	if node is Label and node.text.contains(text):return true
	for child:Node in node.get_children():
		if contains_text(child,text):return true
	return false
