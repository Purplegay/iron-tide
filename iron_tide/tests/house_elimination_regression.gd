extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await short_match()
	await annihilation()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("HOUSE ELIMINATION checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func open_match(multiple:bool) -> void:
	var config={"map_layout":"yr_crctbrd","opening":"prebuilt","enemy_country":"美国","difficulty":2,"fog_of_war":false}
	if multiple: config.houses=[{"country":"美国","team":1},{"country":"美国","team":2},{"country":"苏俄","team":1},{"country":"苏俄","team":2}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false

func short_match() -> void:
	open_match(true)
	battle.mission.victory_condition="short"
	var point:=Vector2(1100,1100)
	var mcv=battle.spawn_unit("AMCV","enemy",point)
	var hero=battle.spawn_unit("MTNK","enemy",point+Vector2(100,0))
	hero.special.academy_hero="MTNK"
	hero.special.hero_command_rank=1
	var wreck=battle.spawn_unit("HTNK","enemy",point+Vector2(150,0))
	wreck.special.academy_hero="HTNK"
	wreck.special.hero_command_rank=1
	wreck.hp=0
	wreck._die()
	check(wreck.special.has("hero_wreck"),"fixture includes a pending hero revival")
	var transport=battle.spawn_unit("SHAD","enemy",point+Vector2(0,150))
	var passenger=battle.spawn_unit("GHOST","enemy",point)
	transport.logistics.passengers.append(passenger)
	passenger.embarked_in=transport
	var carrier=battle.spawn_unit("CARRIER","enemy",point+Vector2(0,250))
	var aircraft=battle.spawn_unit("HORNET","enemy",point)
	carrier.logistics.squadron[0].unit=aircraft
	aircraft.logistics.carrier_owner=carrier
	var truck=battle.spawn_unit("DTRUCK","enemy",point+Vector2(300,0))
	var bystander=battle.spawn_unit("MTNK","ally",truck.position+Vector2(1,1))
	var before:float=bystander.hp
	var guard=battle._place_building("GAPILL","enemy",point+Vector2(0,400),true)
	for b in battle.buildings:
		if b.side=="enemy" and b!=guard: b.hp=0
	battle._check_end()
	check(not battle.house_defeated("enemy") and battle.actor_alive(hero),"undeployed MCV preserves short-match survival")
	mcv.hp=0
	var kills_before:int=battle.kills
	battle._check_end()
	check(battle.house_defeated("enemy") and not battle.ended,"one defeated house is removed while the four-house match continues")
	for actor in [hero,wreck,transport,passenger,carrier,aircraft,truck,guard]:
		check(not battle.actor_alive(actor),"elimination destroys "+str(actor.get("unit_id") if actor is Unit else actor.building_id))
	check(not hero.special.has("hero_wreck") and not wreck.special.has("hero_wreck"),"heroes cannot enter or retain resurrection state after defeat")
	check(bystander.hp==before,"defeat explosions do not trigger demolition-truck collateral")
	check(battle.kills==kills_before,"automatic defeat cleanup grants no extra kill score")
	check(battle.has_surviving_assets("ai2") and battle.has_surviving_assets("ai3"),"other allies and enemies remain alive")
	check(battle.spawn_unit("PDPLANE","enemy",point)==null and battle.spawn_unit("MTNK","enemy",point)==null,"late support and factory spawns are rejected")
	check(battle._place_building("GACNST","enemy",point,true)==null,"defeated house cannot recreate its base")
	var jobs:Array=[{"id":"GAPOWR","cost":800.0,"time":30.0,"elapsed":0.0,"paid":0.0}]
	var ready:Dictionary={}
	var funds_before:float=battle.funds_for("enemy")
	battle._tick_structure_jobs(60.0,jobs,ready,"enemy")
	check(jobs[0].elapsed==0.0 and ready.is_empty() and battle.funds_for("enemy")==funds_before,"defeated construction queues stop progressing and charging funds")
	battle._check_end()
	check(battle.kills==kills_before and not battle.ended,"repeat defeat checks are idempotent")
	var codec=BattleSaves.Snapshot.new()
	var data:Dictionary=codec.capture(battle)
	check(BattleSaves.validate(data).is_empty(),"defeated-house record is valid save data")
	codec.restore(battle,data)
	check(battle.house_defeated("enemy") and battle.spawn_unit("MTNK","enemy",point)==null,"defeat persists across save restoration")
	for b in battle.buildings:
		if b.side=="ally": b.hp=0
	for u in battle.units:
		if u.side=="ally" and not u.deploy_building_id().is_empty(): u.hp=0
	battle._check_end()
	check(battle.house_defeated("ally") and not battle.ended and battle.has_surviving_assets("ai2"),"player defeat removes player army without eliminating the allied team")
	await finish()

func annihilation() -> void:
	open_match(false)
	battle.mission.victory_condition="annihilation"
	var troop=battle.spawn_unit("MTNK","enemy",Vector2(1000,1000))
	for b in battle.buildings:
		if b.side=="enemy":b.hp=0
	for u in battle.units:
		if u.side=="enemy" and u!=troop:u.hp=0
	battle._check_end()
	check(not battle.house_defeated("enemy") and battle.actor_alive(troop) and not battle.ended,"annihilation mode preserves remaining army after losing buildings")
	battle.gm_unit_lab=true
	troop.hp=0
	battle._check_end()
	check(not battle.house_defeated("enemy"),"GM lab does not eliminate houses")
	battle.gm_unit_lab=false
	battle._check_end()
	check(battle.house_defeated("enemy") and battle.ended,"annihilation ends after the last real asset is gone")
	await finish()
