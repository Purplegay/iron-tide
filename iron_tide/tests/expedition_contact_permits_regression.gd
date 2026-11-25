extends "res://tests/expedition_regression.gd"

const Contacts=preload("res://scripts/expedition/contact_catalog.gd")
const Guide=preload("res://scripts/expedition/field_guide.gd")

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await exercise_contact("edith","苏俄",7,false)
	var permits:={"edith":"SNIPE","sami":"DESO","vera":"TTNK","ines":"TERROR","greta":"TNKD","seojin":"BEAG","yusuf":"DTRUCK"}
	var exclusives:Array=[]
	for uid:String in GameData.ra2_source_units:
		var raw:Dictionary=GameData.ra2_source_units[uid]
		if str(raw.get("extra",{}).get("RequiredHouses","")).is_empty() or not GameData.unit_in_production_catalog(uid):continue
		if not str(GameData.get_unit(uid).get("built_at","")).is_empty():exclusives.append(uid)
	var offered:=permits.values()
	offered.sort()
	exclusives.sort()
	check(exclusives==offered,"all currently producible country-exclusive RA2 units have a rescue permit",exclusives)
	for person:String in permits:
		var profile:Dictionary=Contacts.PEOPLE[person]
		var uid:String=permits[person]
		check(profile.permit==uid and GameData.ra2_country_block_reason(uid,GameData.ra2_country_id(profile.country)).is_empty(),"permit belongs to contact's country "+uid)
		for country:String in ["美国","苏俄"]:
			await exercise_contact(person,country,Contacts.PEOPLE.keys().find(person)-1,true)
	check(Contacts.portrait("edith")!=Contacts.portrait("sami"),"distinct portraits")
	print("CONTACT PERMITS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise_contact(person:String,country:String,seed_value:int,win:bool) -> void:
	var profile:Dictionary=Contacts.PEOPLE[person]
	var uid:String=profile.permit
	check(Expedition.start(country,"",seed_value) and Expedition.choose(0),"start "+country)
	var next:Dictionary=Expedition.state.duplicate(true)
	Expedition.ready(next)
	next.routes[0].map="exp_plain"
	check(uid not in next.licenses,"new expedition starts without this license")
	check(Expedition.commit(next) and Expedition.launch(0),"launch rescue")
	if not instantiate_battle():return
	var field=screen.expedition_runtime.field_ops
	var objectives:Array=field.data.objectives.filter(func(o):return o.kind=="contact" and o.person.id==person)
	check(objectives.size()==1,"naturally selected rescue "+person)
	if objectives.is_empty():await finish();return
	var objective:Dictionary=objectives[0]
	battle.spawn_unit("E1","ally",objective.position)
	field.tick(20)
	check(objective.done and field.data.contacts.size()==1,"completed friendly rescue")
	check(screen.hud.minimap._radio_portrait.texture==Contacts.portrait(person),"HUD portrait "+person)
	field.complete(objective)
	check(field.data.contacts.size()==1 and uid not in Expedition.state.licenses,"one pending gift before settlement")
	check(Expedition.settle(battle,win),"settle rescue")
	await finish()
	check(Expedition.load_run(),"reload campaign")
	if not win:
		check(uid not in Expedition.state.licenses and Expedition.state.get("training_permits",[]).is_empty(),"defeat awards no license")
		return
	var report:Dictionary=Expedition.state.battle_reports.back()
	check(report.training_permits==[uid] and Expedition.state.licenses.count(uid)==1 and Expedition.state.catalog.count(uid)==1,"saved once in catalog and licenses")
	var archive:=VBoxContainer.new()
	Guide.add_archive(archive)
	var readers:=archive.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with(profile.name))
	check(readers.size()==1 and readers[0].icon==Contacts.portrait(person) and readers[0].text.ends_with("/%d"%(profile.chapters.size()+11)),"illustrated archive includes stories, keepsake, joint record and letters")
	archive.free()
	next=Expedition.state.duplicate(true)
	Expedition.ready(next)
	next.routes[0].map="exp_plain"
	check(Expedition.commit(next) and Expedition.launch(0),"enter next battle")
	if not instantiate_battle():return
	var soviet:=country=="苏俄"
	var facility:String=GameData.get_unit(uid).built_at
	var factory_id:=facility
	if facility in ["GAPILE","NAHAND"]:factory_id="NAHAND" if soviet else "GAPILE"
	if facility in ["GAWEAP","NAWEAP"]:factory_id="NAWEAP" if soviet else "GAWEAP"
	var home:Vector2=battle.player_start()
	var factories:Array=battle.buildings.filter(func(b):return b.side=="ally" and b.building_id==factory_id)
	if uid=="BEAG":check(not factories.is_empty() and battle.aircraft_capacity("ally")>0,"provided operational black eagle airfield "+country)
	var factory=factories.front() if not factories.is_empty() else battle._place_building(factory_id,"ally",home+Vector2(260,0),true)
	check(uid in factory.buildable,"own facility lists permit "+uid)
	if uid!="BEAG":
		check(not factory.can_queue(uid),"radar requirement remains "+uid)
		battle._place_building("NARADR" if soviet else "GAAIRC","ally",home+Vector2(0,260),true)
	screen.hud.select_prod_tab(GameData.unit_production_category(GameData.get_unit(uid)))
	screen.hud._factories.choose(factory)
	check(uid in screen.hud._unit_catalog(),"visible in actual production sidebar "+country+uid)
	var count_before:int=battle.units.filter(func(u):return u.side=="ally" and u.unit_id==uid).size()
	check(factory.enqueue(uid),"queue specialist "+uid+": "+factory.queue_block_reason(uid))
	var funds:float=battle.funds_for("ally")
	factory._tick_unit_queue(1000.0,uid)
	var produced:Array=battle.units.filter(func(u):return u.side=="ally" and u.unit_id==uid)
	check(produced.size()==count_before+1 and battle.funds_for("ally")<funds,"paid production "+uid)
	if uid=="BEAG" and not produced.is_empty():check(produced.back().logistics.home==factory,"black eagle docks at issuing airfield")
	if factory_id!=facility:
		AlliedAbilities.change_side(factory,"enemy")
		check(uid not in factory.buildable,"captured factory loses player's foreign permit")
		AlliedAbilities.change_side(factory,"ally")
		check(uid in factory.buildable,"recaptured factory honors player's permit")
	check(factory.enqueue(uid),"start second order for checkpoint "+uid)
	factory._tick_unit_queue(0.25,uid)
	check(Expedition.checkpoint(battle),"checkpoint productive facility and queue "+uid)
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"load checkpoint")
	if not instantiate_battle():return
	check(battle.buildings.any(func(b):return b.side=="ally" and b.building_id==factory_id and uid in b.production and b.can_queue(uid)),"restored facility retains order and can train again "+uid)
	await finish()
