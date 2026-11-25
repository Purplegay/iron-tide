extends Node
const Army=preload("res://scripts/expedition/army.gd")
const Catalog=preload("res://scripts/expedition/catalog.gd")
var checks:=0
var failed:=0
func check(ok:bool,title:String) -> void:
	checks+=1
	if not ok:failed+=1;print("FAIL ",title)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	check(Expedition.start("美国","",715),"start isolated run")
	check(Expedition.choose(0),"ready camp")
	var run:Dictionary=Expedition.state.duplicate(true)
	run.reinforcements=[{"id":"MTNK","count":6}]
	run.survivors=[];run.special_squads=[];run.active_roster=["MTNK"]
	var before:=var_to_bytes(run)
	var sale:Dictionary=Expedition.excess_sale(run)
	check(sale.count==2 and sale.supplies==2*Catalog.dismissal_value("MTNK"),"six tanks sell exactly two with refund")
	check(var_to_bytes(run)==before,"preview does not mutate state")
	run.reinforcements=[]
	for i in 4:run.survivors.append({"id":"MTNK","hero":"","variant":"","rank":0,"xp":0.0,"hp":1.0})
	run.survivors.append({"id":"MTNK","hero":"","variant":"gold","rank":2,"xp":8.0,"hp":1.0})
	run.survivors.append({"id":"MTNK","hero":"MTNK","variant":"","rank":2,"xp":9.0,"hp":1.0})
	run.special_squads=[{"id":"MTNK","token":"gold","tier":3,"native_rank":0,"count":1}]
	sale=Expedition.excess_sale(run)
	check(sale.count==1,"hero excluded from count")
	check(sale.rows.any(func(row):return row.get("hero","")=="MTNK"),"hero retained")
	check(sale.rows.any(func(row):return row.get("variant","")=="gold"),"special veteran retained")
	run.reinforcements=[{"id":"MTNK","count":4},{"id":"GGI","count":8},{"id":"E1","count":8},{"id":"SREF","count":4},{"id":"HTK","count":4}]
	run.survivors=[];run.special_squads=[]
	sale=Expedition.excess_sale(run)
	check(sale.count==28-preload("res://scripts/expedition/campaign.gd").population(run.stage),"chapter population excess removed")
	# Exercise actual atomic commit and repeat-click behavior.
	run=Expedition.state.duplicate(true)
	run.reinforcements=[{"id":"MTNK","count":6}];run.survivors=[];run.special_squads=[];run.active_roster=["MTNK"]
	Expedition.state=run
	var funds:int=run.supplies
	var ui=load("res://scenes/expedition.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	var buttons:Array=ui.find_children("*","Button",true,false)
	check(buttons.any(func(entry):return entry.text.begins_with("一键售出多余人员 · 2 个")),"camp exposes one-click sale with exact count")
	ui.free()
	check(Expedition.sell_excess_personnel(),"one click commits")
	check(Army.quantity(Expedition.state,"MTNK")==4 and Expedition.state.supplies==funds+2*Catalog.dismissal_value("MTNK"),"stored quantity and refund exact")
	check(not Expedition.sell_excess_personnel() and Expedition.state.supplies==funds+2*Catalog.dismissal_value("MTNK"),"repeat cannot sell or refund again")
	check(Expedition.load_run() and Army.quantity(Expedition.state,"MTNK")==4,"sale survives reload")
	print("EXCESS SALE checks=",checks," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
