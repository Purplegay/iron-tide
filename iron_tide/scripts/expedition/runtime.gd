extends Node
const Rules=preload("res://scripts/expedition/rules.gd")
const Army=preload("res://scripts/expedition/army.gd")
const Tasks=preload("res://scripts/expedition/objectives.gd")
var tasks
var field_ops
var keepsake_orders:Dictionary={}
const Keepsakes=preload("res://scripts/expedition/commander_keepsakes.gd")
var gift_retry:=0.0
var reunion_pending:Array=[]
const GiftNotice = preload("res://scripts/expedition/keepsake_notice.gd")
var gift_notice: GiftNotice
const Catalog=preload("res://scripts/expedition/catalog.gd")
var world
var elapsed:=0.0
var save_elapsed:=0.0
var status:Label
var side_status:Label
var hud_details:VBoxContainer
var hud_detail_status:Label
var hud_objective_only:=false
var hud_toggle:Button
var error := ""
var retreat_dialog:ConfirmationDialog
var convoy_button:Button
var convoy_controls:Array[Button]=[]
var convoy_actors:Array=[]
var dispatch_menu:PopupMenu
var dispatch_button:Button
var field_buttons:Array[Button]=[]
var track_buttons:Dictionary={}
var reinforcement_plan:Array=[]
var reinforcement_clock:=0.0
var fleet_in_reserve:=false

func setup(battle,restored:bool) -> bool:
	world=battle
	if not Rules.active():return true
	if not restored:
		world.allied_state.expedition_tally = {"ore":0.0,"losses":{},"scorers":{}}
	world.allied_state.expedition_bridge_guard=preload("res://scripts/expedition/relics.gd").owned(Expedition.state,"bridge_station")
	fleet_in_reserve=world.map_layout() not in preload("res://scripts/expedition/campaign.gd").NAVAL
	if not restored:
		if not prepare():return false
		deploy_late_guards(int(Rules.context().stage))
	if not ensure_basic_ferry(restored):return false
	if restored and world.allied_state.has("expedition_reinforcement_plan"):
		reinforcement_plan=world.allied_state.expedition_reinforcement_plan.filter(func(r):return not str(r.id).begins_with("R3")).duplicate(true)
		world.allied_state.expedition_legion_initial=world.allied_state.get("expedition_legion_initial",[]).filter(func(r):return not str(r.id).begins_with("R3"))
		reinforcement_clock=float(world.allied_state.get("expedition_reinforcement_clock",0.0))
	else:
		reinforcement_plan=preload("res://scripts/expedition/reinforcement_plan.gd").build(Expedition.state)
		reinforcement_clock=0.0
		world.allied_state.expedition_legion_initial=reinforcement_plan.duplicate(true)
	world.allied_state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
	world.allied_state.expedition_reinforcement_clock=reinforcement_clock
	tasks=Tasks.new()
	world.add_child(tasks)
	if not tasks.setup(world,restored):error=tasks.error;return false
	field_ops=preload("res://scripts/expedition/field_operations.gd").new();world.add_child(field_ops);field_ops.setup(world,restored)
	tasks.field_ops=field_ops
	var carried := Keepsakes.carried(Rules.context())
	for slot in carried.size():
		var gift_id: String = carried[slot]
		var order= preload("res://scripts/expedition/keepsake_orders.gd").new()
		world.add_child(order)
		order.setup(world,gift_id,0 if restored else Keepsakes.opening_cooldown(slot,Expedition.state))
		keepsake_orders[gift_id]=order
	preload("res://scripts/expedition/red_alert.gd").setup(world,Expedition.state,restored)
	for actor in world.units+world.buildings:preload("res://scripts/expedition/elite_tactics.gd").apply(actor,preload("res://scripts/expedition/elite_tactics.gd").current())
	Events.unit_spawned.connect(apply_elite)
	Events.building_placed.connect(apply_elite)
	Events.unit_died.connect(unit_died)
	return true

func apply_elite(actor) -> void:
	if Rules.active():preload("res://scripts/expedition/elite_tactics.gd").apply(actor,preload("res://scripts/expedition/elite_tactics.gd").current())

const CampaignBonus = preload("res://scripts/expedition/campaign.gd")

func prepare() -> bool:
	world.match_id=str(Rules.context().token)
	world.allied_state.expedition_kits=int(Expedition.state.kits)
	world.allied_state.expedition_losses=0
	var stage:int=Rules.context().stage
	world.mission.name="铁潮远征 %d / %d · %s"%[stage,Catalog.TOTAL,Rules.context().title]
	world.funds+=CampaignBonus.EXTRA_FUNDS+Rules.value("deployment")+(3000 if Rules.context().condition=="funds" else 0)
	var fog=world.fog
	world.fog=null
	for building in world.buildings:
		if building.side=="ally":building._buildup_play=-1
	var structures:Array=["GAWEAP"]
	if stage>=4:structures.append("GAAIRC")
	if stage>=6:structures.append("GATECH")
	for uid:String in Rules.context().licenses:
		if uid not in Expedition.state.active_roster and uid not in ["CMIN","HARV","AMCV","SMCV","ENGINEER","SENGINEER"]:continue
		for required in GameData.production_prerequisites(uid,world.allied_state,"ally"):
			var mapped:String={"BARRACKS":"GAPILE","TECH":"GATECH","POWER":"GAPOWR","PROC":"GAREFN","RADAR":"GAAIRC","FACTORY":"GAWEAP","EXPEDITION_FACTORY":"GAWEAP"}.get(required,required)
			if GameData.building_index.has(mapped) and mapped not in structures:structures.append(mapped)
	var needs_navy:=false
	for uid:String in Expedition.state.active_roster:
		if Catalog.group(uid)=="naval":needs_navy=true
	if needs_navy:structures.append("GAYARD")
	if stage>=16:
		structures.append_array(["GADEPT","GATECH","GAAIRC","GAAIRC"])
		structures.append("NANRCT" if world.roster_faction()=="soviet" else "GAROBO")
	for uid:String in Rules.context().licenses:
		if uid not in Expedition.state.active_roster:continue
		var producer:String=GameData.get_unit(uid).get("built_at","")
		if producer in ["GAAIRC","GAYARD","NAYARD"] and not producer in structures:structures.append(producer)
	if "ORCA" in Catalog.Heroes.owned(Rules.context()) and "ORCA" not in Catalog.Heroes.wounded(Rules.context()) and "GAAIRC" not in structures:structures.append("GAAIRC")
	var placed:Dictionary={}
	for common:String in structures:
		if common in ["GAYARD","NAYARD"] and fleet_in_reserve:continue
		var id:String=world.roster_id(common,"ally")
		if world.roster_faction()=="soviet":id={"GAAIRC":"NARADR","GATECH":"NATECH","GADEPT":"NADEPT"}.get(common,id)
		if not ensure_structure(id,id=="GAAIRC" and placed.has(id)):
			if id in ["GAYARD","NAYARD"]:
				fleet_in_reserve=true
				error=""
				continue
			break
		placed[id]=true
	var aircraft_count:=0
	for row:Dictionary in Expedition.state.survivors:
		if row.id in ["ORCA","BEAG"] and str(row.get("hero",""))!="ORCA":aircraft_count+=1
	for row:Dictionary in Expedition.state.reinforcements:
		if row.id in ["ORCA","BEAG"]:aircraft_count+=int(row.count)
	# A Korean permit includes access to a working airfield, even with no aircraft in the roster yet.
	if Rules.has_training_permit("BEAG","ally"):aircraft_count=maxi(1,aircraft_count)
	while world.aircraft_capacity("ally")<aircraft_count:
		if not ensure_structure("GAAIRC",true):break
	for index in 12:
		world._update_power()
		if not world.power_low:break
		if not ensure_structure(world.roster_id("GAPOWR","ally"),true):break
	if stage>=16:
		for key in ["RequiresStolenAlliedTech","RequiresStolenSovietTech","RequiresStolenThirdTech"]:world.allied_state["stolen_ally_"+key]=true
	world.fog=fog
	if not error.is_empty():return false
	# Survivors are legion inventory, not opening-map spawns. Every new
	# battle queues them with purchases/heroes through the chrono plan.
	if world.map_layout()=="island_cross":
		for id:String in ( ["HYD"] if world.roster_faction()=="soviet" else ["DEST"] ):
			if not id in Rules.context().licenses:Rules.context().licenses.append(id)
			if deploy(id)==null:return false
	world._update_power()
	Events.funds_changed.emit(world.funds)
	Events.production_queue_changed.emit()
	return true

func ensure_basic_ferry(restored: bool) -> bool:
	const ISSUED := "expedition_basic_ferry_issued"
	if world.allied_state.get(ISSUED, false):return true
	var id := "SAPC" if world.roster_faction() == "soviet" else "LCRF"
	if world.map_layout() == "island_cross" and id not in Rules.context().licenses:
		Rules.context().licenses.append(id)
	if restored:
		for unit in world.units:
			if world.actor_alive(unit) and unit.side == "ally" and unit.unit_id == id:
				world.allied_state[ISSUED] = true
				return true
	var origin: Vector2 = world.path_service.ground_near_base(world.player_start())
	var radius := float(GameData.get_unit(id).get("radius", 24))
	for ring in range(1, 22):
		for step in ring * 8:
			var target := origin + Vector2.RIGHT.rotated(TAU * step / (ring * 8)) * (ring * 55.0)
			var point: Vector2 = world.path_service.nearest_reachable(target, origin, false, 2)
			if not point.is_finite() or world.path_service.is_blocked(point, false, true):continue
			if not preload("res://scripts/world/economy_cycle.gd").landing_clear(world, point, radius):continue
			if world.spawn_unit(id, "ally", point) != null:
				world.allied_state[ISSUED] = true
				return true
	error = "基地附近没有可部署气垫运输船的位置"
	return false

func deploy_late_guards(stage:int) -> void:
	if stage<26:return
	var count:=8+2*(stage-26)
	var roster:=["MTNK","E1","FV","GGI"]
	if world.roster_faction("enemy")=="soviet":roster=["HTNK","E2","HTK","SHK"]
	var center:Vector2=world.enemy_base_center
	var origin:Vector2=world.path_service.ground_near_base(center)
	if not origin.is_finite():return
	var forward:=center.direction_to(world.player_start())
	var deployed:=0
	for slot in 72:
		var offset:=forward.rotated(TAU*(slot%12)/12.0)*(320.0+80.0*floori(slot/12.0))
		var pos:Vector2=world.path_service.nearest_reachable(center+offset,origin,false,8)
		var id:String=roster[deployed%roster.size()]
		var radius:=float(GameData.get_unit(id).get("radius",20))
		if not pos.is_finite() or not preload("res://scripts/world/economy_cycle.gd").landing_clear(world,pos,radius):continue
		var guard=world.spawn_unit(id,"enemy",pos)
		if guard==null:break
		guard.order_guard()
		deployed+=1
		if deployed==count:break

func ensure_structure(id:String,extra:=false) -> bool:
	if not extra and id in world.owned_building_ids():return true
	var definition:=GameData.get_building(id)
	if definition.is_empty():error="缺少远征建筑配置："+id;return false
	var point:=structure_site(definition)
	if not point.is_finite():error="当前地图无法安置远征设施："+str(definition.name);return false
	var building=world._place_building(id,"ally",point,true)
	building._buildup_play=-1
	return true

func structure_site(definition:Dictionary) -> Vector2:
	var home:Vector2=world.player_start()
	var footprint := Placement.aabb(Building.placement_poly(definition))
	var occupied: Array[Rect2] = []
	var refinery_aprons: Array[Rect2] = []
	for building in world.buildings:
		if building.side == "ally":
			var rect: Rect2 = building.footprint_rect()
			rect.position += building.global_position
			occupied.append(rect)
			if building.is_refinery():
				var radius := float(GameData.get_unit(world.roster_id("CMIN")).radius)
				var apron := Building.refinery_apron(building.footprint_poly(), radius)
				apron.position += building.global_position
				refinery_aprons.append(apron)
	# Prefer a vehicle lane around each foundation within the local base area.
	for ring in range(3, 10):
		for step in ring * 8:
			var point: Vector2 = world.snap_build_pos(home + Vector2.RIGHT.rotated(TAU * step / (ring * 8)) * ring * 100)
			if point.distance_to(world.enemy_base_center) < point.distance_to(home):continue
			var site := Rect2(point + footprint.position, footprint.size)
			if occupied.any(func(other: Rect2): return Placement.aabb_gap(site, other) < 100.0):continue
			if structure_site_open(point, definition, site, refinery_aprons):return point
	# Narrow shorelines may only have room for a compact placement.
	for ring in range(2,24):
		for step in ring*8:
			var point:Vector2=world.snap_build_pos(home+Vector2.RIGHT.rotated(TAU*step/(ring*8))*ring*100)
			var enemy_home:Vector2=world.enemy_base_center
			if point.distance_to(enemy_home)<point.distance_to(home):continue
			if structure_site_open(point, definition, Rect2(point + footprint.position, footprint.size), refinery_aprons):return point
	return Vector2.INF

func structure_site_open(point: Vector2, definition: Dictionary, footprint: Rect2, refinery_aprons: Array[Rect2]) -> bool:
	for apron in refinery_aprons:
		if footprint.intersects(apron, true):return false
	if not world.build_spot_ok(point, definition, true, "ally", world).ok:return false
	# Even separated foundations can seal the last passage along a map edge.
	return preload("res://scripts/world/ai_base_routes.gd").placement_ok(world.path_service, footprint.grow(2.0))

func deploy(id:String,hero_id:=""):
	if hero_id=="ORCA":
		for airport in world.buildings:
			if airport.side=="ally" and airport.is_operational() and airport.building_id in ["GAAIRC","AMRADR"]:
				var at:=preload("res://scripts/rules/hero_reinforcements.gd").point(world,airport.position)
				if at.is_finite():return world.spawn_unit("ORCA","ally",at)
		error="游隼需要本轮可用机场及合法空域，不需要空余停机位"
		return null
	var data:=GameData.get_unit(id)
	var producer_id:String=data.get("built_at","")
	var producer=null
	for building in world.buildings:
		if building.side=="ally" and building.building_id==producer_id:
			producer=building
			if building._spawn_point(id).is_finite():break
	var point:Vector2=producer._spawn_point(id) if producer!=null else Vector2.INF
	if not point.is_finite() and producer!=null and id not in ["ORCA","BEAG"]:
		var category:=Catalog.group(id)
		for ring in range(2,16):
			for step in ring*8:
				var candidate:Vector2=producer.position+Vector2.RIGHT.rotated(TAU*step/(ring*8))*ring*60
				if producer._exit_position_clear(candidate,float(data.get("radius",12)),category=="naval",category=="air"):
					point=candidate;break
			if point.is_finite():break
	if not point.is_finite() and Catalog.group(id) not in ["naval","air"]:
		point=preload("res://scripts/world/american_paradrop.gd").open_ground(world,world.player_start()+Vector2(240,-180))
	if not point.is_finite():error="无法部署增援："+str(data.get("name",id));return null
	return world.spawn_unit(id,"ally",point,producer)

func unit_died(unit) -> void:
	if is_instance_valid(unit) and unit.special.get("expedition_radio_copy",false):return
	if is_instance_valid(field_ops) and is_instance_valid(unit) and unit is Unit and unit.special.has("field_box"):field_ops.carrier_died(unit)
	if Rules.active() and not world.ended and is_instance_valid(unit):preload("res://scripts/expedition/red_alert.gd").defeated(world,unit)
	if not Rules.active() or world.ended or not is_instance_valid(unit) or not unit is Unit or unit.side!="ally":return
	if world.allied_state.has("expedition_tally"):
		var fallen: Dictionary = world.allied_state.expedition_tally.losses
		fallen[unit.unit_id] = int(fallen.get(unit.unit_id,0))+1
	if unit.special.get(preload("res://scripts/expedition/reinforcement_plan.gd").MEMBER,false):
		var losses:Dictionary=world.allied_state.get_or_add("expedition_legion_deaths",{})
		losses[unit.unit_id]=int(losses.get(unit.unit_id,0))+1
	var hero_id:=str(unit.special.get("academy_hero",""))
	if not hero_id.is_empty():
		var deaths:Array=world.allied_state.get_or_add("expedition_hero_deaths",[])
		if hero_id not in deaths:deaths.append(hero_id)
	if Catalog.group(unit.unit_id)!="vehicle" or unit.is_harvester or unit.special.has("expansion_temporary") or unit.special.has("furnace_flak_life"):return
	world.allied_state.expedition_losses=mini(5,int(world.allied_state.get("expedition_losses",0))+1)

var tanker_bar:HBoxContainer
var tanker_job:Dictionary={}

func update_tanker_bar() -> void:
	if not is_instance_valid(tanker_bar):return
	if tanker_job.is_empty() or tanker_job.get("phase","")!="choice" or tanker_job.done or tanker_job.failed or world.ended:
		tanker_bar.hide()
		return
	var truck=field_ops.missions.tagged("field_tanker",tanker_job.id)
	if truck==null:
		tanker_bar.hide()
		return
	var anchor:Vector2=truck.get_global_transform_with_canvas().origin
	var view:=get_viewport().get_visible_rect()
	if not view.has_point(anchor):
		tanker_bar.hide()
		return
	tanker_bar.get_child(0).visible=not tanker_job.get("site_lost",false)
	tanker_bar.position=(anchor-Vector2(tanker_bar.size.x/2,tanker_bar.size.y+28)).clamp(Vector2.ZERO,(view.size-tanker_bar.size).max(Vector2.ZERO))
	tanker_bar.show()

func update_convoy_controls() -> void:
	for index in convoy_controls.size():
		var button:=convoy_controls[index]
		var truck=convoy_actors[index]
		if not world.actor_alive(truck) or world.ended or tasks.state.outcome!=0 or index in tasks.state.arrived:
			button.hide();continue
		var anchor:Vector2=world.get_canvas_transform()*truck.art_center()
		button.position=(anchor+Vector2(-button.size.x*0.5,12)).round()
		var rect:=button.get_global_rect()
		button.visible=get_viewport().get_visible_rect().encloses(rect) and not world.hud.covers_world_pixel(rect.get_center()) and not tasks.state.get("outcome",0)
		var paused:bool=tasks.state.get("convoy_paused",false)
		button.text="▶" if paused else "Ⅱ"
		button.tooltip_text="全车队继续前进" if paused else "暂停全车队"

func _process(delta:float) -> void:
	if is_instance_valid(world) and not convoy_controls.is_empty():update_convoy_controls()
	if is_instance_valid(world):update_tanker_bar()
	if not is_instance_valid(world) or world.ended or world.paused or not Rules.active():return
	tick(delta)
	save_elapsed+=delta
	if save_elapsed>=30:
		save_elapsed=0
		world.allied_state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
		world.allied_state.expedition_reinforcement_clock=reinforcement_clock
		if not Expedition.checkpoint(world):show_error(Expedition.error)

func tick(delta:float) -> void:
	for order in keepsake_orders.values():order.advance(delta)
	if not reunion_pending.is_empty():
		gift_retry-=delta
		if gift_retry<=0:deliver_gifts()
	elapsed+=delta
	if elapsed<1.0:return
	var seconds:=elapsed;elapsed=0
	preload("res://scripts/expedition/red_alert.gd").tick(world,seconds)
	if field_ops!=null:field_ops.tick(seconds)
	if tasks!=null:tasks.tick(seconds)
	reinforcement_clock+=seconds
	var deadline:=float(world.allied_state.get("dispatch_until",-1))
	if deadline>=0 and reinforcement_clock>=deadline:
		if not reinforcement_plan.is_empty():
			adjust_batch("field_dispatch",float(reinforcement_plan.back().due),true)
		world.allied_state.dispatch_until=-1
		if is_instance_valid(dispatch_menu):dispatch_menu.hide()
	_process_reinforcements()
	world.allied_state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
	world.allied_state.expedition_reinforcement_clock=reinforcement_clock
	refresh_status()
	world.allied_state.expedition_medical=float(world.allied_state.get("expedition_medical",0))+seconds
	var medical:bool=float(world.allied_state.expedition_medical)>=5
	if medical:world.allied_state.expedition_medical=0.0
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side!="ally" or unit.special.has("expansion_temporary"):continue
		var category:=Catalog.group(unit.unit_id)
		Rules.tick_unit(unit,seconds,medical)
		if medical:
			var heal:=Rules.value("medics") if category=="infantry" else 0.0
			if Rules.context().condition=="medic":heal+=0.02
			if heal>0:unit.heal(unit.max_hp*heal)
		if Rules.rank("repair")==0 or category not in ["vehicle","naval"]:continue
		var previous:float=unit.special.get("expedition_hp",unit.hp)
		var idle:=float(unit.special.get("expedition_repair_idle",0))
		idle=0.0 if unit.hp<previous or is_instance_valid(unit.attack_target) else idle+seconds
		if idle>=8:unit.heal(unit.max_hp*Rules.value("repair")*seconds)
		unit.special.expedition_hp=unit.hp
		unit.special.expedition_repair_idle=idle

func _process_reinforcements() -> void:
	if reinforcement_plan.is_empty():return
	var arrived:=0
	# Remove only successfully deployed entries. A blocked landing must not
	# discard the rest of a due batch or block unrelated unit categories.
	var index:=0
	while index<reinforcement_plan.size():
		var row:Dictionary=reinforcement_plan[index]
		if float(row.due)>reinforcement_clock:break
		if fleet_in_reserve and Catalog.group(row.id)=="naval":
			index+=1
			continue
		var previous_error:=error
		var unit=deploy(str(row.id),str(row.get("hero","")))
		if unit==null:
			error=previous_error
			index+=1
			continue
		if row.get("radio_copy",false):unit.special.expedition_radio_copy=true
		else:unit.special[preload("res://scripts/expedition/reinforcement_plan.gd").MEMBER]=true
		reinforcement_plan.remove_at(index)
		arrived+=1
		preload("res://scripts/world/chrono_miner_fx.gd").spawn(world,unit.global_position,"WARPOUT")
		if not str(row.get("variant","")).is_empty():
			for spec:Dictionary in Expedition.state.special_squads:
				if spec.token==row.variant:Rules.apply_variant(unit,spec);break
		if not str(row.get("hero","")).is_empty():
			MetaProgress.Academy.promote(BattleRequest.combat_context.expedition_hero_profile,world,row.id,unit)
			if not world.allied_state.has("expedition_first_hero_arrival"):world.allied_state.expedition_first_hero_arrival=reinforcement_clock
		unit._grant_veteran(maxi(unit.veteran_level,int(row.get("rank",0))),false)
		unit.excluded_from_army_selection=bool(row.get("excluded",false))
		var research_level := preload("res://scripts/expedition/research.gd").rank(Expedition.state,"army")
		if research_level>=2 and str(row.get("hero",""))=="":
			unit._base_speed *= 1.01+0.01*int(research_level>=6)
			var hp_scale:=1.0+0.01*int(research_level>=4)+0.01*int(research_level>=8)
			unit._base_max_hp*=hp_scale
			unit.max_hp*=hp_scale
		unit._vet_kills=float(row.get("xp",0.0))
		unit.hp=unit.max_hp*float(row.get("hp",1.0))
	world.allied_state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
	world.allied_state.expedition_reinforcement_clock=reinforcement_clock
	if arrived>0:
		Ra2Sfx.play_player_eva(world,Ra2Sfx.REINFORCEMENTS_ARRIVED,0)
		Events.emit_message("超时空增援抵达 · %d 个单位"%arrived,UiKit.COL_GOLD)

func on_radio_alert() -> void:
	var copies:=preload("res://scripts/expedition/reinforcement_plan.gd").radio_copies(reinforcement_plan,world.allied_state.get("expedition_legion_initial",[]),reinforcement_clock)
	if copies.is_empty():return
	reinforcement_plan.append_array(copies)
	reinforcement_plan.sort_custom(func(a,b):return float(a.due)<float(b.due))
	world.allied_state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
	Events.emit_message("静默电台 · %d 个复制增援已排队"%copies.size(),UiKit.COL_GOLD)
	refresh_status()

func reinforcement_summary() -> String:
	if reinforcement_plan.is_empty():return "超时空增援：已全部抵达"
	var next:Dictionary=reinforcement_plan[0]
	var remaining:=maxi(0,ceili(float(next.due)-reinforcement_clock))
	var count:=0
	for row:Dictionary in reinforcement_plan:
		if is_equal_approx(float(row.due),float(next.due)):count+=1
	var name_text:=str(GameData.get_unit(str(next.id)).get("name",next.id))
	if not str(next.get("hero","")).is_empty():name_text=MetaProgress.Academy.hero_label(next.hero)
	return "超时空增援：%s 等 %d 个 · %02d:%02d（待抵达 %d）"%[name_text,count,remaining/60,remaining%60,reinforcement_plan.size()]

func choose_batch(mode:String) -> void:
	if world.ended or world.paused or world.get_tree().paused:return
	if mode=="field_dispatch":
		var deadline:=float(world.allied_state.get("dispatch_until",-1))
		if not world.allied_state.has("dispatch_until"):
			Events.emit_message("战地接驳：先使用本关第一个维修包。",UiKit.COL_GOLD);return
		if deadline<0:
			Events.emit_message("战地接驳：本关已使用。",UiKit.COL_GOLD);return
		if reinforcement_clock>deadline:
			Events.emit_message("战地接驳：维修包触发的 10 秒选择时间已结束。",UiKit.COL_GOLD);return
	if mode=="chrono_decree" and world.allied_state.get("decree_used",false):return
	var menu:=PopupMenu.new()
	add_child(menu)
	var times:Array=[]
	for entry:Dictionary in reinforcement_plan:
		var due:=float(entry.due)
		if due in times or due<=reinforcement_clock or (mode=="chrono_decree" and due==float(reinforcement_plan[0].due)):continue
		times.append(due)
		menu.add_item("%s · %d 秒"%[GameData.get_unit(entry.id).get("name",entry.id),ceili(due-reinforcement_clock)])
	if times.is_empty():
		menu.queue_free()
		Events.emit_message("没有可供调度的待抵达援军批次。",UiKit.COL_GOLD)
		return
	if mode=="field_dispatch":
		if is_instance_valid(dispatch_menu):dispatch_menu.hide()
		dispatch_menu=menu
	menu.id_pressed.connect(func(index:int):
		if not adjust_batch(mode,float(times[index])):
			Events.emit_message("调度未生效：批次已变化或使用时间已结束。",UiKit.COL_GOLD))
	menu.popup_hide.connect(menu.queue_free)
	menu.popup_centered()

func adjust_batch(mode:String,due:float,automatic:bool=false) -> bool:
	if world.ended or world.paused or world.get_tree().paused or reinforcement_plan.is_empty() or due<=reinforcement_clock:return false
	if not preload("res://scripts/expedition/relics.gd").owned(Expedition.state,mode):return false
	if not reinforcement_plan.any(func(r):return float(r.due)==due):return false
	var head:=float(reinforcement_plan[0].due)
	var state:Dictionary=world.allied_state
	if mode=="field_dispatch":
		var deadline:=float(state.get("dispatch_until",-1))
		if deadline<0 or (not automatic and deadline<reinforcement_clock):return false
		state.dispatch_until=-1
	elif mode=="chrono_decree":
		if head==due or state.get("decree_used",false):return false
		state.decree_used=true
	else:return false
	for r:Dictionary in reinforcement_plan:
		if float(r.due)==due:r.due=head if mode=="chrono_decree" else reinforcement_clock+(due-reinforcement_clock)*0.5
		elif mode=="chrono_decree" and float(r.due)==head:r.due=due
	reinforcement_plan.sort_custom(func(a,b):return float(a.due)<float(b.due))
	state.expedition_reinforcement_plan=reinforcement_plan.duplicate(true)
	if mode=="field_dispatch":
		Events.emit_message("战地接驳生效：所选批次剩余 %.1f 秒 → %.1f 秒"%[due-reinforcement_clock,(due-reinforcement_clock)*0.5],UiKit.COL_GOLD)
	refresh_status()
	return true

func use_kit() -> bool:
	if world.ended or world.paused or int(world.allied_state.get("expedition_kits",0))<=0:return false
	world.allied_state.expedition_kits-=1
	if preload("res://scripts/expedition/relics.gd").owned(Expedition.state,"field_dispatch") and not world.allied_state.has("dispatch_until"):
		world.allied_state.dispatch_until=reinforcement_clock+10.0
		choose_batch("field_dispatch")
	for unit in world.units:
		if world.actor_alive(unit) and unit.side=="ally":unit.heal(unit.max_hp*0.35)
	refresh_status()
	return true

func install_hud(layer:CanvasLayer) -> void:
	gift_notice = GiftNotice.new()
	layer.add_child(gift_notice)
	for job:Dictionary in field_ops.data.objectives:
		if job.kind!="fuel":continue
		tanker_job=job;tanker_bar=HBoxContainer.new();layer.add_child(tanker_bar);tanker_bar.hide()
		world.hud.tanker_bar=tanker_bar
		for pair in [["护送到前哨站\n开启防空和维修","派车进站"],["拆车换维修包\n胜利带回 ×1","拆车换维修包"]]:
			var btn:=side_button(pair[0]);btn.pressed.connect(field_ops.act.bind(pair[1]));tanker_bar.add_child(btn)
		break
	field_ops.transmission.connect(world.hud.show_field_transmission)
	field_ops.contact_met.connect(on_contact_met)
	field_ops.greet_from_support()
	for person: Dictionary in field_ops.data.get("contacts", []):
		field_ops.meet_contact(person.id)
	for side: String in field_ops.support_ids:
		if field_ops.data.get("greeted", {}).has(side):
			field_ops.meet_contact(field_ops.support_ids[side])
	for owner_id: String in field_ops.data.get("met_contacts", []):
		queue_gift(owner_id)
	deliver_gifts()
	var panel:=UiKit.make_panel(UiKit.COL_PANEL,UiKit.COL_GOLD)
	panel.process_mode=Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size.x=300
	layer.add_child(panel)
	world.hud.expedition_panel=panel
	var column:=VBoxContainer.new()
	panel.add_child(column)
	var header:=HBoxContainer.new()
	column.add_child(header)
	hud_toggle=UiKit.make_button("",12)
	hud_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud_toggle.clip_text=true
	hud_toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT
	hud_toggle.tooltip_text="展开或收起任务说明"
	header.add_child(hud_toggle)
	var collapse:=UiKit.make_button("完全收起",12)
	header.add_child(collapse)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events=false
	scroll.follow_focus=true
	column.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	world.hud.mount_expedition_panel(panel,scroll,body)
	status=UiKit.make_label("",12,UiKit.COL_GOLD)
	status.custom_minimum_size.x=280
	status.clip_text=true
	body.add_child(status)
	side_status=UiKit.make_label("",12,UiKit.COL_SIDE_MISSION)
	side_status.custom_minimum_size.x=280
	side_status.clip_text=true
	body.add_child(side_status)
	var row:=GridContainer.new()
	row.columns=3
	body.add_child(row)
	hud_details=VBoxContainer.new()
	body.add_child(hud_details)
	hud_details.visible=false
	hud_detail_status=UiKit.make_label("",12,UiKit.COL_SIDE_MISSION)
	hud_detail_status.custom_minimum_size.x=280
	hud_detail_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud_details.add_child(hud_detail_status)
	for kind:String in field_ops.data.get("school_finds",{}):
		var item:Dictionary=field_ops.data.school_finds[kind]
		var pin:=side_button("")
		pin.name="SchoolFind_"+kind
		pin.tooltip_text="派己方地面部队靠近，获胜后带回。"
		pin.add_theme_color_override("font_color",field_ops.SchoolField.PINK)
		pin.pressed.connect(world.center_on.bind(item.position))
		body.add_child(pin)
	if field_ops.data.has("shelter_at"):
		var shelter_pin:=side_button("定位 · 百合子初遇 · 雨棚")
		shelter_pin.name="YurikoShelter"
		shelter_pin.add_theme_color_override("font_color",field_ops.SchoolField.PINK)
		shelter_pin.pressed.connect(func():world.center_on(field_ops.data.shelter_at))
		body.add_child(shelter_pin)
	if field_ops.data.has("archive_at"):
		var archive_pin:=side_button("定位 · 秘密档案")
		archive_pin.name="YurikoArchive"
		archive_pin.add_theme_color_override("font_color",field_ops.SchoolField.PINK)
		archive_pin.pressed.connect(func():world.center_on(field_ops.data.archive_at))
		body.add_child(archive_pin)
	for objective:Dictionary in field_ops.data.objectives:
		var pin:=side_button("")
		var id:String=objective.id
		if objective.kind=="contact":
			pin.tooltip_text=str(objective.person.bio)
		if objective.get("hero_lead","")=="YURIKO":
			pin.add_theme_color_override("font_color",field_ops.SchoolField.PINK)
			body.add_child(pin)
		else:hud_details.add_child(pin)
		track_buttons[id]=pin
		pin.pressed.connect(toggle_tracking.bind(id))
	collapse.pressed.connect(func():
		hud_objective_only=true
		scroll.hide()
		collapse.hide()
		hud_toggle.tooltip_text="点击恢复远征面板"
		refresh_status())
	hud_toggle.pressed.connect(func():
		if hud_objective_only:
			hud_objective_only=false
			scroll.show()
			collapse.show()
			hud_toggle.tooltip_text="展开或收起任务说明"
		else:
			hud_details.visible=not hud_details.visible
		scroll.scroll_vertical=0
		refresh_status())
	var alert_panel:=Control.new()
	alert_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var alert_anchor:=Control.new()
	layer.add_child(alert_anchor)
	alert_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alert_anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE
	alert_anchor.add_child(alert_panel)
	alert_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	alert_panel.offset_left=8
	alert_panel.offset_top=-416
	alert_panel.offset_bottom=-226
	alert_panel.offset_right=226
	world.hud.red_alert_panel=alert_panel
	var red_alert := preload("res://scripts/ui/uprising_red_alert_button.gd").new()
	alert_panel.add_child(red_alert)
	red_alert.setup(world)
	red_alert.build_status(alert_panel)
	world.hud._layout_selection_strip.call_deferred()
	if preload("res://scripts/expedition/relics.gd").owned(Expedition.state,"silent_radio"):
		red_alert.activated.connect(on_radio_alert)
	for mode:String in ["field_dispatch","chrono_decree"]:
		if preload("res://scripts/expedition/relics.gd").owned(Expedition.state,mode):
			var order:=side_button("战地接驳" if mode=="field_dispatch" else "逆时换序")
			if mode=="field_dispatch":
				dispatch_button=order
				order.tooltip_text="本关首次使用紧急维修后，10 秒内选择一批增援，剩余等待减半。超时自动选择最后一批。"
			order.pressed.connect(choose_batch.bind(mode));row.add_child(order)
	var locate:=UiKit.make_button("定位目标",12)
	locate.pressed.connect(tasks.focus_next)
	row.add_child(locate)
	var optional:=side_button("定位支线");optional.pressed.connect(field_ops.focus_next);row.add_child(optional)
	if tasks.state.kind=="escort":
		convoy_button=UiKit.make_button("暂停车队",12)
		convoy_button.tooltip_text="只控制主线护送车队，战斗和敌军继续进行。继续后车队以原速的 65% 驶向护送终点。"
		convoy_button.pressed.connect(toggle_convoy)
		row.add_child(convoy_button)
		for index in 3:
			var truck=tasks.actor("convoy"+str(index))
			var switch:=UiKit.make_button("Ⅱ",13)
			switch.custom_minimum_size=Vector2(32,25)
			switch.focus_mode=Control.FOCUS_NONE
			switch.pressed.connect(toggle_convoy)
			layer.add_child(switch)
			convoy_controls.append(switch)
			convoy_actors.append(truck)
		update_convoy_controls()
	var kit:=UiKit.make_button("紧急维修",12)
	kit.pressed.connect(use_kit)
	row.add_child(kit)
	for order in keepsake_orders.values():
		order.mount(world.hud.make_support_button())
	var save:=UiKit.make_button("保存远征并返回",12)
	save.pressed.connect(save_and_leave)
	row.add_child(save)
	if int(Rules.context().stage)%5!=0 and not Expedition.state.get("retreat_used",false):
		var retreat_button:=UiKit.make_button("撤离 · 80 补给",12)
		retreat_button.disabled=int(Expedition.state.supplies)<80
		retreat_button.pressed.connect(request_retreat)
		row.add_child(retreat_button)
		retreat_dialog=ConfirmationDialog.new()
		retreat_dialog.process_mode=Node.PROCESS_MODE_ALWAYS
		retreat_dialog.title="撤离当前战区"
		retreat_dialog.dialog_text="消耗 80 远征补给，保留幸存者并前往下一关，放弃本关全部奖励。本轮只能撤离一次；章末决战不能撤离。"
		retreat_dialog.confirmed.connect(retreat)
		layer.add_child(retreat_dialog)
	for i in 2:
		var action:=side_button("")
		row.add_child(action);field_buttons.append(action)
		action.pressed.connect(field_action.bind(action))
	refresh_status()

func on_contact_met(owner_id: String) -> void:
	queue_gift(owner_id)
	deliver_gifts()

func queue_gift(owner_id:String) -> void:
	if Keepsakes.eligible(owner_id, Expedition.state, field_ops.data.get("met_contacts", [])) and owner_id not in reunion_pending:
		reunion_pending.append(owner_id)

func deliver_gifts() -> void:
	gift_retry=5
	for owner_id:String in reunion_pending.duplicate():
		if Keepsakes.inscribe(owner_id,Expedition.state,false,field_ops.data.get("met_contacts",[])):
			var item:Dictionary=Keepsakes.ITEMS[owner_id]
			var level := Keepsakes.rank(owner_id)
			if keepsake_orders.has(owner_id):keepsake_orders[owner_id].update_rank()
			gift_notice.announce(owner_id)
			field_ops.transmission.emit(field_ops.Stories.PEOPLE[owner_id].name,Keepsakes.story(owner_id,level),owner_id)
			Events.emit_message("获得永久信物 · "+item.name if level == 1 else "%s强化至第 %d 档" % [item.name,level],UiKit.COL_GOLD)
		if not Keepsakes.eligible(owner_id,Expedition.state,field_ops.data.get("met_contacts",[])):reunion_pending.erase(owner_id)

func side_button(caption:String) -> Button:
	var button:=UiKit.make_button(caption,12)
	for slot in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:
		button.add_theme_color_override(slot,UiKit.COL_SIDE_MISSION)
	return button

func toggle_convoy() -> void:
	if tasks!=null and tasks.set_convoy_paused(not tasks.state.get("convoy_paused",false)):
		refresh_status()
		update_convoy_controls()

func field_action(button:Button) -> void:
	field_ops.act(button.text)
	refresh_status()

func toggle_tracking(id:String) -> void:
	field_ops.track(id)
	refresh_status()

func refresh_dispatch_button() -> void:
	if not is_instance_valid(dispatch_button):return
	var state:Dictionary=world.allied_state
	var deadline:=float(state.get("dispatch_until",-1))
	var available:=false
	var hint:String
	if not state.has("dispatch_until"):
		hint="先用紧急维修" if int(state.get("expedition_kits",0))>0 else "缺少维修包"
	elif deadline<0:hint="本关已使用"
	elif reinforcement_clock>deadline:hint="本关已过期"
	elif not reinforcement_plan.any(func(r):return float(r.due)>reinforcement_clock):hint="无待抵达援军"
	else:
		available=true
		hint="选援军 · %d秒"%maxi(0,ceili(deadline-reinforcement_clock))
	dispatch_button.text="战地接驳\n"+hint
	dispatch_button.disabled=not available

func refresh_status() -> void:
	refresh_dispatch_button()
	var main_summary:String=("✓ " if int(tasks.state.get("outcome",0))==1 else "○ ")+tasks.summary() if tasks!=null else Rules.context().title
	if status!=null:
		status.text="%s\n%s"%[main_summary,reinforcement_summary().replace("超时空增援：","增援：")]
		if tasks!=null and not tasks.completed_items().is_empty():status.text+="\n"+tasks.completed_items()
		status.tooltip_text=status.text
	if is_instance_valid(side_status):
		side_status.text=field_ops.compact_summary() if field_ops!=null else ""
		side_status.tooltip_text=side_status.text
	if is_instance_valid(hud_toggle):
		if hud_objective_only:
			hud_toggle.text=main_summary.get_slice("\n",0)
			if tasks!=null and tasks.state.kind=="boss" and int(tasks.state.stage)==Catalog.TOTAL and int(tasks.state.phase)==1:
				hud_toggle.text="破盾进度 %d/45 秒 · 已控 %d/3"%[int(tasks.state.progress),tasks.state.get("shield_points",[]).count(1)]
		else:
			hud_toggle.text="远征 %d/%d · 维修包 %d    %s"%[Rules.context().stage,Catalog.TOTAL,world.allied_state.get("expedition_kits",0),"收起 ▴" if hud_details.visible else "展开 ▾"]
	if is_instance_valid(hud_detail_status):
		for kind:String in field_ops.data.get("school_finds",{}):
			var pin:=hud_details.get_parent().get_node_or_null("SchoolFind_"+kind) as Button
			if pin!=null:
				pin.disabled=field_ops.data.school_finds[kind].taken
				pin.text="%s · 百合子 · %s"%["已找到" if pin.disabled else "定位",field_ops.SchoolField.FINDS[kind]]
		var archive_pin:=hud_details.get_parent().get_node_or_null("YurikoArchive") as Button
		if archive_pin!=null:
			archive_pin.disabled=field_ops.data.get("archive_taken",false)
			archive_pin.text="已拾取 · 秘密档案" if archive_pin.disabled else "定位 · 秘密档案"
		hud_detail_status.text="可选支线\n"+field_ops.summary() if field_ops!=null else "暂无支线"
		for objective:Dictionary in field_ops.data.objectives:
			if not track_buttons.has(objective.id):continue
			var pin:Button=track_buttons[objective.id]
			var tracked:bool=field_ops.data.get("tracked","")==objective.id
			pin.visible=tracked or not (objective.done or objective.get("failed",false))
			pin.text=("取消追踪 · " if tracked else "追踪 · ")+field_ops.title(objective)
	if not field_buttons.is_empty():
		var choices:Array=field_ops.actions()
		for i in field_buttons.size():
			field_buttons[i].visible=i<choices.size()
			if i<choices.size():field_buttons[i].text=choices[i]
	if is_instance_valid(convoy_button):
		convoy_button.text="继续前进" if tasks.state.get("convoy_paused",false) else "暂停车队"
		convoy_button.disabled=world.ended or int(tasks.state.outcome)!=0

func show_error(message:String) -> void:
	Events.emit_message(message,Color.TOMATO)
	if status!=null:status.text=message

func save_and_leave() -> void:
	if not Expedition.checkpoint(world):show_error(Expedition.error);return
	get_tree().paused=false
	BattleClock.leave_battle()
	get_tree().change_scene_to_file("res://scenes/expedition.tscn")

func request_retreat() -> void:
	if not world.ended:retreat_dialog.popup_centered()

func retreat() -> void:
	if not Expedition.retreat(world):show_error("无法撤离：次数、补给或关卡条件不满足");return
	world.ended=true
	get_tree().paused=false
	BattleClock.leave_battle()
	get_tree().change_scene_to_file("res://scenes/expedition.tscn")
