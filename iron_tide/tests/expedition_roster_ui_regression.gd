extends "res://tests/expedition_layout_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	stage=SubViewport.new();stage.size=Vector2i(1600,900);add_child(stage)
	check(Expedition.start("美国","",12345),"start isolated expedition")
	Expedition.choose(0)
	var next:Dictionary=Expedition.state.duplicate(true)
	var army=preload("res://scripts/expedition/army.gd")
	for id in ["E1","GGI","MTNK","FV","SREF","MGTK","CLEG","SNIPE"]:army.add_unit(next,id,1)
	var capacity:int=preload("res://scripts/expedition/campaign.gd").slots(next)
	var ids:Array=army.available(next)
	next.active_roster=ids.slice(0,capacity)
	check(ids.size()>capacity and Expedition.commit(next),"prepare full roster with reserves")
	camp=load("res://scenes/expedition.tscn").instantiate();stage.add_child(camp);camp.change_tab(2)
	await get_tree().process_frame
	var reserve:String=ids[capacity]
	var first=tile(0)
	var source=tile(-1,reserve)
	check(source.global_position.x>first.global_position.x and source.text.contains("首批"),"reserve sidebar and first arrival time")
	# Use the same viewport input path as a real drag from the reserve card.
	camp.scroll.ensure_control_visible(first)
	await get_tree().process_frame
	await get_tree().process_frame
	var start:Vector2=source.get_global_rect().get_center()
	var end:Vector2=first.get_global_rect().get_center()
	mouse_motion(start,false)
	mouse_press(start,true)
	mouse_motion(start+Vector2(16,0),true)
	mouse_motion(end,true)
	mouse_press(end,false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Expedition.formation_slots()[0]==reserve and ids[0] not in Expedition.state.active_roster,"drop on full formation replaces exactly one type")
	check(Expedition.load_run() and Expedition.formation_slots()[0]==reserve and army.quantity(Expedition.state,ids[0])>0,"both units survive disk reload")
	var inventory:Array=army.inventory(Expedition.state).duplicate(true)
	var original_slots:=Expedition.formation_slots()
	var expected_slots:=original_slots.duplicate()
	expected_slots[0]=ids[0]
	start=tile(0).get_global_rect().get_center()
	end=tile(-1,ids[0]).get_global_rect().get_center()
	mouse_motion(start,false)
	mouse_press(start,true)
	mouse_motion(start+Vector2(16,0),true)
	mouse_motion(end,true)
	mouse_press(end,false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Expedition.formation_slots()==expected_slots and tile(-1,reserve)!=null,"active-to-reserve drag swaps the target type into the vacated slot")
	check(Expedition.load_run() and Expedition.formation_slots()==expected_slots and army.inventory(Expedition.state)==inventory,"reverse swap persists all slots and the exact inventory")
	tile(0).pressed.emit()
	tile(-1,reserve).pressed.emit()
	await get_tree().process_frame
	check(Expedition.formation_slots()==original_slots and tile(-1,ids[0])!=null,"clicking active then reserve swaps the same pair back")
	tile(0).pressed.emit()
	tile(-1).pressed.emit()
	await get_tree().process_frame
	check(Expedition.formation_slots()[0]=="","returning to reserve leaves that exact slot open")
	tile(-1,reserve).pressed.emit()
	tile(0).pressed.emit()
	await get_tree().process_frame
	check(Expedition.formation_slots()[0]==reserve,"click alternative fills the chosen empty slot")
	var before:=Expedition.state.duplicate(true)
	check(not Expedition.move_formation("unknown",0) and not Expedition.move_formation(reserve,capacity) and Expedition.state==before,"invalid drops preserve state")
	check_unlimited_reserves()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("ROSTER_UI checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func check_unlimited_reserves() -> void:
	var army=preload("res://scripts/expedition/army.gd")
	var run:=Expedition.state.duplicate(true)
	run.stage=11
	run.survivors=[]
	run.special_squads=[]
	run.reinforcements=[]
	run.active_roster=[]
	var active:={"HTNK":4,"SUB":1,"TTNK":2,"APOC":4,"BORIS":1,"SREF":3,"FV":4,"SHK":6}
	var reserves:={"SENGINEER":3,"MGTK":1,"FLAKT":5,"CLEG":1,"ZEP":1,"HTK":4}
	for group:Dictionary in [active,reserves]:
		for id:String in group:army.add_unit(run,id,group[id])
	Expedition.ready(run)
	check(run.active_roster==active.keys() and army.inventory(run).size()==40 and army.roster_error(run).is_empty(),"8 active types and 6 reserve types at 40/40 may deploy")
	var excess:=run.duplicate(true)
	excess.active_roster.append("MGTK")
	check(army.roster_error(excess).contains("出战编制超过"),"ninth active type still exceeds chapter slots")
	excess=run.duplicate(true)
	army.add_unit(excess,"ZEP",1)
	check(army.roster_error(excess).is_empty() and Expedition.excess_sale(excess).count==0 and army.deployment(excess).reserve.size()==16,"a legal reserve can raise total inventory above the deployment cap")
	check(Expedition.commit(run) and Expedition.load_run(),"reload full camp with all six reserves")
	camp.change_tab(2)
	check(camp.body.find_children("*","Label",true,false).any(func(l):return l.text.contains("预备 15 个") and l.text.contains("出战人数 25 / 40")),"camp shows reserve count and population separately")
	for id:String in reserves:
		check(tile(-1,id)!=null and army.quantity(Expedition.state,id)==reserves[id],"reserve card and saved quantity "+id)
	camp.change_tab(0)
	var deploy:Array=camp.body.find_children("*","Button",true,false).filter(func(b):return b.text=="部署到此战区")
	check(not deploy.is_empty() and deploy.all(func(b):return not b.disabled),"route deployment available with six reserves")
	check(Expedition.launch(0) and Expedition.state.phase=="battle","launch from full camp without dismissal")
	var plan:=preload("res://scripts/expedition/reinforcement_plan.gd").build(Expedition.state)
	check(plan.size()>0 and plan.all(func(row):return row.id not in reserves),"only deployed types join the reinforcement plan")

func tile(index:int,id:String=""):
	for node in camp.body.find_child("FormationBox",true,false).find_children("*","Button",true,false):
		if "slot_index" in node and node.slot_index==index and (index>=0 or node.unit_id==id):return node
	return null

func mouse_motion(point:Vector2,pressed:bool) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.relative=Vector2(16,0)
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	stage.push_input(event,true)

func mouse_press(point:Vector2,pressed:bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=point
	stage.push_input(event,true)
