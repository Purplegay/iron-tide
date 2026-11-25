extends "res://tests/expedition_regression.gd"
const Missions=preload("res://scripts/expedition/field_missions.gd")
var ops
var mission:Dictionary

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	check_escort_candidates()
	await check_compact_escort()
	for branch:String in ["radio","radio_direct","box","fuel_drive","fuel_scrap","fuel_loss","divert_move","divert_kill","engineer"]:
		if OS.get_environment("IRON_TIDE_FUEL_ONLY")=="1" and not branch.begins_with("fuel"):continue
		var kind:=branch.get_slice("_",0)
		if open_mission(kind):
			match branch:
				"radio":await radio_case()
				"radio_direct":
					soldier(mission.stations[mission.real]);ops.tick(1)
					check(mission.done and not mission.listened and not mission.ambushed,"direct guess can rescue without visiting the listener")
				"box":await box_case()
				"fuel_drive":await fuel_drive()
				"fuel_scrap":await fuel_scrap()
				"fuel_loss":fuel_loss()
				"divert_move":await divert_move()
				"divert_kill":divert_kill()
				"engineer":await bridge_case()
		if is_instance_valid(screen):await finish()
	FileAccess.open(output_dir.path_join("field-missions.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks},"  "))
	print("FIELD MISSIONS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func open_mission(kind:String) -> bool:
	var stage:=16 if kind=="divert" else 1
	for seed_value in range(1,121):
		var model={"stage":stage,"seed":seed_value,"history":[]}
		var routes:=Campaign.routes(model)
		for i in routes.size():
			if Missions.candidate(seed_value,stage,routes[i],1)!=kind:continue
			check(Expedition.start("美国","",seed_value) and Expedition.choose(0),"open camp "+kind)
			var next:=Expedition.state.duplicate(true);next.stage=stage
			Expedition.ready(next);Expedition.commit(next)
			check(Expedition.launch(i),"launch "+kind)
			if not instantiate_battle():return false
			ops=screen.expedition_runtime.field_ops
			for o:Dictionary in ops.data.objectives:
				if o.kind==kind:
					mission=o
					var marks:Array=ops.missions.marks(o)
					check(marks.all(func(m):return battle.path_service.same_zone(screen.expedition_runtime.tasks.state.origin,m.position)),"all initial mission markers reachable "+kind)
					check(screen.hud.minimap.objective_marks().any(func(m):return m.key==marks[0].key and m.color==UiKit.COL_SIDE_MISSION),"real minimap includes mission "+kind)
					return true
			check(false,"deployment expected "+kind);return false
	check(false,"no route generated for "+kind);return false

func restore() -> void:
	var kind:String=mission.kind
	check(Expedition.checkpoint(battle),"checkpoint "+kind)
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"read disk checkpoint "+kind)
	if not instantiate_battle():return
	ops=screen.expedition_runtime.field_ops
	mission=ops.data.objectives.filter(func(o):return o.kind==kind)[0]

func soldier(at:Vector2):
	return battle.spawn_unit("E1","ally",at)

func check_escort_candidates() -> void:
	for enemies in [1,2,3]:
		var route:={"task":"escort","map":"exp_plain","enemy_count":enemies}
		var kinds:={}
		for seed_value in range(120):
			kinds[Missions.candidate(seed_value,14,route)]=true
		check(not kinds.has("fuel") and not kinds.has("box") and kinds.has("radio"),"escort route excludes competing transport jobs with %d enemies"%enemies)

func check_compact_escort() -> void:
	new_ready("美国",3)
	check(Expedition.launch(0),"launch main escort")
	if instantiate_battle():
		var rt=screen.expedition_runtime
		for frame in 3:await get_tree().process_frame
		check(not rt.hud_details.visible and rt.convoy_button.is_visible_in_tree(),"main convoy command visible in collapsed HUD")
		click_command(rt.convoy_button)
		check(rt.tasks.state.get("convoy_paused",false) and not rt.tasks.actor("convoy0").has_move_order,"compact command parks the escort")
		click_command(rt.convoy_button)
		check(not rt.tasks.state.get("convoy_paused",false) and rt.tasks.actor("convoy0").has_move_order,"compact command sends escort on again")
	await finish()

func click_command(button:Button) -> void:
	var point:=button.get_global_rect().get_center()
	check(screen.hud.covers_world_pixel(point),"command owns the battlefield click "+button.text)
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		get_viewport().push_input(event,true)

func action(caption:String) -> void:
	var rt=screen.expedition_runtime
	rt.refresh_status()
	for frame in 3:await get_tree().process_frame
	check(not rt.hud_details.visible,"issuing field command with details collapsed")
	for b:Button in rt.field_buttons:
		if b.is_visible_in_tree() and b.text==caption:
			check(screen.hud.expedition_panel.size.x<=340,"active commands stay within the narrow HUD")
			click_command(b)
			check(not b.is_visible_in_tree(),"consumed field choice disappears")
			return
	check(false,"available HUD action "+caption)

func radio_case() -> void:
	var real_index:int=mission.real
	var scout=soldier(mission.position);ops.tick(1)
	check(mission.listened and ops.summary().contains(Missions.CALLS[real_index]),"listening reveals matching call sign")
	# Take the known risk to exercise the alternative before following the intel.
	var count_before:int=battle.units.size()
	scout.position=mission.stations[1-real_index];ops.tick(1);ops.tick(1)
	check(mission.ambushed and not mission.done and battle.units.size()==count_before+3,"one false-site ambush; rescue remains possible")
	await restore()
	check(mission.ambushed and mission.listened and mission.real==real_index,"radio identity and visited sites survive")
	soldier(mission.stations[real_index])
	count_before=battle.units.size();ops.tick(1);ops.tick(1)
	check(mission.done and battle.units.size()==count_before+3 and battle.units[-1].side=="ally","real station grants the team once")

func box_case() -> void:
	var rt=screen.expedition_runtime
	rt.track_buttons[mission.id].pressed.emit()
	check(ops.data.tracked==mission.id and pinned_at(mission.cargo),"pin from HUD points to cargo")
	var crate=ops.get_children().filter(func(n):return n.get_script()==preload("res://scripts/expedition/field_crate.gd"))[0]
	var nearby=soldier(mission.cargo+Vector2(95,0))
	crate._physics_process(0.016)
	check(mission.phase=="open" and not nearby.special.has("field_box"),"nearby squad does not collect a crate from a distance")
	var other=soldier(mission.cargo+Vector2(12,0))
	var first=soldier(mission.cargo)
	crate._physics_process(0.016)
	check(ops.missions.box_holder(mission.id)==first and not other.special.has("field_box"),"only the closest unit touching the ground crate picks it up")
	nearby.position=mission.depot
	other.position=mission.cargo+Vector2(110,0)
	ops.tick(1)
	check(not mission.done and ops.missions.hint(mission).contains(first.display_name),"a non-carrier at the depot cannot deliver the box")
	ops.tick(1);await action("放下黑匣子");ops.tick(1)
	check(mission.phase=="open" and not first.special.has("field_box"),"drop does not immediately return to same soldier")
	var second=soldier(mission.cargo);ops.tick(1)
	check(second.special.get("field_box","")==mission.id,"another soldier can pick it up")
	await restore()
	check(pinned_at(mission.depot),"checkpoint restores pin and directs carrier home")
	second=ops.missions.tagged("field_box",mission.id)
	check(second!=null and mission.phase=="carry","carrier identity survives cold resume")
	second.position=battle.path_service.nearest_reachable(second.position.move_toward(mission.depot,240),mission.depot,false,6)
	var death_at:Vector2=second.position
	second._die()
	check(pinned_at(mission.cargo),"tracked location follows dropped box")
	check(mission.phase=="open" and mission.cargo.distance_to(death_at)<180,"death drops recoverable cargo")
	var runner=soldier(mission.cargo);ops.tick(1)
	check(runner.special.has("field_box"),"replacement runner carries dropped cargo")
	runner.position=mission.depot;ops.tick(1);ops.tick(1)
	check(mission.done and ops.data.wave_intel and ops.data.get("kits",0)==1,"delivered box grants intelligence and one kit across repeated ticks")
	var kit_count := int(Expedition.state.kits)
	await restore()
	check(mission.done and ops.data.get("kits",0)==1,"completed cargo reward survives checkpoint")
	var expected_stage:=int(Expedition.state.stage)+1
	check(Expedition.settle(battle,true) and Expedition.state.intel_stage==expected_stage,"victory unlocks precisely the next stage")
	check(Expedition.state.kits==kit_count+1 and Expedition.state.battle_reports.back().get("field_kits",0)==1,"victory banks and reports the recovered kit")
	var next:=Expedition.state.duplicate(true)
	Expedition.ready(next);Expedition.commit(next)
	var camp=load("res://scenes/expedition.tscn").instantiate();add_child(camp)
	var previews=camp.find_children("*","Label",true,false).filter(func(l):return l.text.begins_with("黑匣子情报"))
	check(previews.size()==next.routes.size() and previews[0].text==Campaign.wave_intel(expected_stage,next.routes[0]),"intel reaches each real next-route card")
	camp.free()
	var intel:=Campaign.wave_intel(8,{"task":"radar","elite":true,"elite_tactic":"rapid_raiders"})
	check(intel.contains(GameData.get_unit("HTNK").name) and intel.contains(GameData.get_unit("E2").name),"intel includes elite wave additions")

func pinned_at(point:Vector2) -> bool:
	var pins:Array=ops.markers().filter(func(m):return m.get("tracked",false))
	return pins.size()==1 and pins[0].position.is_equal_approx(point)

func bridge_case() -> void:
	soldier(mission.position);ops.tick(1)
	check(mission.done and ops.data.has("engineer_map"),"ground party rescues bridge engineer")
	await restore()
	check(Expedition.settle(battle,true),"settle rescued engineer after cold restore")
	var next:=Expedition.state.duplicate(true)
	var destination:String=next.engineer_map
	check(next.engineer_stage==next.stage,"support is scheduled for immediately following stage")
	var camp=load("res://scenes/expedition.tscn").instantiate();add_child(camp)
	for tab: Button in camp.find_children("*","Button",true,false):
		if tab.text=="战报与收获":
			tab.pressed.emit()
			break
	check(camp.find_children("*","Label",true,false).any(func(l):return l.text.begins_with("上场战损")),"last battle losses reach reward screen")
	camp.free()
	await finish()
	Expedition.ready(next);Expedition.commit(next)
	var routes:Array=next.routes.filter(func(r):return r.get("bridge_support",false))
	check(routes.size()==1 and routes[0].map==destination,"only the promised route shows the side bridge")
	if routes.is_empty():return
	check(Expedition.launch(next.routes.find(routes[0])),"enter bridge route")
	if not instantiate_battle():return
	ops=screen.expedition_runtime.field_ops
	var missions:Array=ops.data.objectives.filter(func(o):return o.kind=="bridge")
	check(missions.size()==1,"real route contains repair objective")
	if missions.is_empty():return
	mission=missions[0]
	await restore()
	var huts:Array=battle.buildings.filter(func(b):return b.special.get("field_bridge",false))
	var workers:Array=battle.units.filter(func(u):return u.special.get("expedition_objective_name","")=="回援的桥梁工兵")
	check(huts.size()==1 and workers.size()==1,"checkpoint restores one hut and one engineer")
	if huts.size()!=1 or workers.size()!=1:return
	var hut=huts[0];var worker=workers[0]
	var center:Vector2=hut.special.bridge_span.get_center()
	check(battle.path_service.is_blocked(center),"actual side crossing starts blocked")
	worker.position=hut.position+Vector2(55,0)
	battle.paused=false;get_tree().paused=false
	hut.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	worker.process_mode=Node.PROCESS_MODE_ALWAYS
	worker.set_physics_process(false)
	await get_tree().physics_frame
	battle.select_unit(worker,false)
	check(not battle.selected_units.has(worker),"mission engineer cannot receive player orders")
	check(worker.special.get("action","")=="allied_bridge","mission engineer automatically targets the marked repair hut")
	for i in 600:
		if worker._dead:break
		worker._physics_process(1.0/60.0)
		if i%30==0:await get_tree().physics_frame
	ops.tick(1)
	check(worker._dead and mission.done and not battle.path_service.is_blocked(center),"real engineer repairs side crossing and opens ground path")

func click_tanker_choice(index:int,truck) -> void:
	var rt=screen.expedition_runtime
	# The fixture freezes the simulation via screen.process_mode. Enable GUI dispatch for this bar.
	rt.tanker_bar.process_mode=Node.PROCESS_MODE_ALWAYS
	battle.center_on(truck.position)
	battle.camera.force_update_scroll()
	rt.update_tanker_bar()
	for frame in 3:await get_tree().process_frame
	rt.update_tanker_bar()
	var button:Button=rt.tanker_bar.get_child(index)
	var point:=button.get_global_rect().get_center()
	check(button.is_visible_in_tree() and screen.hud.covers_world_pixel(point),"truck choice owns its screen position")
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.pressed=down
		get_viewport().push_input(event,true)
		await get_tree().process_frame
		rt.update_tanker_bar()
	check(not rt.tanker_bar.visible,"truck choice consumed by cross-frame mouse click")

func fuel_drive() -> void:
	var truck=ops.missions.tagged("field_tanker",mission.id)
	check(truck.position.distance_to(battle.allied_state.expedition_task.origin)<=1200.0 and ops.safe_rescue_spawn(truck.position),"tanker starts near allied deployment outside enemy detection and fire")
	var site=ops.missions.outpost(mission)
	check(site!=null and site.side=="neutral" and site.weapon.is_empty(),"outpost starts offline")
	check(site._turret_art.facing()>=0 and site._turret_art.muzzles.size()==32,"original OUTP turret loads with facing anchors")
	soldier(truck.position);ops.tick(1);await click_tanker_choice(0,truck)
	check(mission.phase=="drive" and truck.has_move_order and truck.move_target.distance_to(mission.station)<180,"fuel dispatch gives real vehicle movement order")
	await restore()
	truck=ops.missions.tagged("field_tanker",mission.id)
	check(truck!=null and mission.phase=="drive","fuel dispatch resumes without reroll")
	truck.position=mission.station;ops.tick(1)
	site=ops.missions.outpost(mission)
	check(site!=null and site.side=="ally" and site.weapon.get("ra2_aa",false),"delivered fuel activates outpost AA")
	var patient=battle.spawn_unit("MTNK","ally",mission.station)
	patient.hp=patient.max_hp*0.4
	var old_hp:float=patient.hp;ops.tick(2)
	check(mission.done and mission.phase=="station" and patient.hp>old_hp and int(ops.data.get("kits",0))==0,"working station repairs instead of paying parts")
	site._tick_anim_state(0)
	check(site._layer_visible("specialanim") and site._layer_visible("activeanim"),"repair extends arm with flag visible")
	site._tick_anim_state(3.1)
	check(site._layer_visible("specialanimtwo") and not site._layer_visible("specialanim"),"extended arm enters working loop")
	patient.hp=patient.max_hp
	ops.tick(1);site._tick_anim_state(0)
	check(site._layer_visible("specialanimthree"),"arm retracts when vehicle is repaired")
	site._tick_anim_state(3.1)
	check(site._layer_visible("idleanim") and not site._layer_visible("specialanimthree"),"arm returns to parked pose")
	await restore()
	check(mission.done and mission.phase=="station" and ops.missions.tagged("field_tanker",mission.id)==null,"station persists without duplicating tanker")

func fuel_scrap() -> void:
	var truck=ops.missions.tagged("field_tanker",mission.id)
	soldier(truck.position);ops.tick(1);await click_tanker_choice(1,truck)
	check(mission.done,"truck button selects scrap")
	ops.act("拆车换维修包")
	check(mission.done and int(ops.data.kits)==1,"scrap choice exclusive and idempotent")
	await restore()
	check(ops.actions().is_empty() and ops.data.kits==1,"pending kit survives without reopening choice")
	var kits:int=battle.allied_state.get("expedition_kits",Expedition.state.kits)
	check(Expedition.settle(battle,true) and Expedition.state.kits==kits+1,"kit actually reaches camp once on victory")

func fuel_loss() -> void:
	var truck=ops.missions.tagged("field_tanker",mission.id)
	truck._die();ops.tick(1)
	check(mission.failed and ops.actions().is_empty() and not battle.ended,"losing tanker fails only side mission")

func divert_move() -> void:
	var lead=ops.missions.tagged("field_convoy",mission.id)
	soldier(mission.relay);ops.tick(1)
	check(mission.phase=="withdraw" and lead.has_move_order,"relay diverts the active convoy")
	await restore()
	var convoy:Array=battle.units.filter(func(u):return battle.actor_alive(u) and u.special.get("field_convoy","")==mission.id)
	check(convoy.size()==3 and mission.phase=="withdraw","same convoy restored")
	for u in convoy:u.position=mission.rally
	ops.tick(1)
	check(mission.done and convoy.all(func(u):return not u.special.has("field_convoy") and u.fire_stance=="free") and ops.data.supplies==0,"regroup releases guards back into combat")

func divert_kill() -> void:
	var lead=ops.missions.tagged("field_convoy",mission.id)
	lead._die();ops.tick(1);ops.tick(1)
	check(mission.done and ops.data.supplies==45,"intercept bounty credited once")
	var before:int=Expedition.state.supplies
	check(Expedition.settle(battle,false) and Expedition.state.supplies==before,"defeat does not pay side bounty")
