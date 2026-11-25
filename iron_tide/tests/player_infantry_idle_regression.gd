extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/player_infantry_tick_reference.gd")
const After=preload("res://scripts/units/progression_expansion.gd")
const Idle=preload("res://scripts/units/unit_expansion_idle.gd")
const AutoW=preload("res://scripts/units/auto_w.gd")
var metrics:Array=[]

func capture(unit) -> Dictionary:
	return {"special":unit.special.duplicate(true),"speed":unit.move_speed,"bonuses":unit.bonuses.duplicate(true),"hp":unit.hp,"cooldown":unit._cd_timer,"think":unit._think_timer,"target":unit.attack_target}

func reset(unit,state:Dictionary) -> void:
	unit.special=state.duplicate(true)
	unit.bonuses={}
	unit.move_speed=unit._base_speed

func compare(unit,state:Dictionary,label:String) -> void:
	reset(unit,state)
	var expected_return:bool=Before.tick(unit,1.0/15.0)
	var expected:=capture(unit)
	reset(unit,state)
	check(After.tick(unit,1.0/15.0)==expected_return and capture(unit)==expected,label)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode);battle.fog=null
		var carrier=battle.spawn_unit("BFRT","ally",Vector2(800,800))
		carrier.set_physics_process(false)
		for id in ["E1","GGI","MTNK","HTNK","FLAKT","E2","SHK","HTK","APOC","SREF","FV","MGTK","TTNK","V3","DLPH","DEST","CARRIER","BEAG","HARV","CMIN","BFRT","ZEP","SQD","SUB"]:
			var unit=battle.spawn_unit(id,"ally",Vector2(800,800))
			unit.set_physics_process(false);unit.set_process(false)
			unit.passive={};unit.skills=[]
			for cargo in [false,true]:
				unit.embarked_in=carrier if cargo else null
				for rank in [0,1,2]:
					unit.veteran_level=rank;unit._refresh_veteran_bonuses(false)
					for state in [{},{"arc_count":0,"shot_idle":2.0},{"arc_count":3,"shot_idle":2.0,"shot_origin":Vector2(90,80),"rest":0.0,"scrap_idle":0,"scrap_drop":0,"volley":21,"prism_damage":0.0}]:
						compare(unit,{"progression_v1":state},prefix+id+" same bookkeeping/stats "+str([cargo,rank,state]))
					compare(unit,{},prefix+id+" missing state remains compatible")
				for key in ["tracer_arm","relay_cd","relay_left","arc_idle","deck_cd","drone_cd","dive","speed_left","afterheat_cd","capacitor_cd","dive_boost","dive_cloak","move_lock","swap_cd","swap_flash","echo_cd","rebirth_lock","echo_release_cd"]:
					var state={"progression_v1":{key:0.05,"shot_idle":2.0}}
					reset(unit,state)
					check(not Idle.try_tick(unit,1.0/15.0) and unit.special==state,prefix+id+" effect falls back without consuming time "+key)
					compare(unit,state,prefix+id+" effect expires through original handlers "+key)
				for extra in [{"future_effect":true},{"dive_used":true},{"afterburn_used":true},{"prism_damage":0.2},{"tracking":{"left":1.0,"target":carrier}},{"mirror_shield":{"left":1.0,"hp":5.0,"maximum":5.0}}]:
					reset(unit,{"progression_v1":extra})
					check(not Idle.try_tick(unit,0.1),prefix+id+" active or unknown state rejects shortcut")
					compare(unit,{"progression_v1":extra},prefix+id+" active state matches old handlers")
			unit.embarked_in=null
			for extra in [{"academy_hero":id},{"expansion_temporary":{}}]:
				reset(unit,extra)
				check(not Idle.try_tick(unit,0.1),prefix+id+" heroes and summons retain full updates")
			unit.special={};unit.passive={"id":"ps_spine_scrap"}
			check(not Idle.try_tick(unit,0.1),prefix+id+" autonomous scrap passive retains full updates")
			unit.passive={}
			for deployed in [false,true]:
				unit._deployed=deployed
				for active_buffs in [[],[{"kind":"attack","value":0.25,"left":1.0},{"kind":"speed","value":0.2,"left":1.0},{"kind":"electric_slow","value":0.1,"left":1.0}]]:
					unit.buffs=active_buffs.duplicate(true)
					compare(unit,{"progression_v1":{"arc_count":0,"shot_idle":1.0},"hero_speed_floor":12.0},prefix+id+" buffs/deployment/live speed floor keep identical stats")
			unit._deployed=false;unit.buffs=[]
			if mode==MatchRules.EXTENDED:
				talent_change(unit)
				talent_change(unit,"mirage_afterheat")
				benchmark(unit)
			unit.special={"auto_w_hit_left":0.5};unit.embarked_in=carrier;unit.set_meta("auto_w_think",0.0)
			AutoW.tick(unit,0.1)
			check(is_equal_approx(unit.special.auto_w_hit_left,0.4) and not AutoW.evaluate(unit),prefix+id+" cargo W remains unavailable while hit clock advances")
			unit.embarked_in=null
			unit.free();battle.units.erase(unit)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics},"  "))
	get_tree().quit(0 if failed==0 else 1)

func talent_change(unit,talent: String = "ground_capacitor") -> void:
	# Inject a valid existing talent definition into this type to prove that a
	# live selection change is read, rather than assuming GI can never gain it.
	var definitions:Dictionary=GameData.meta_config.unit_talents
	var old=definitions.get(unit.unit_id)
	var source:Dictionary={}
	for row in definitions.values():
		if row.has(talent):source=row[talent].duplicate(true);break
	check(not source.is_empty(),"fixture has existing capacitor talent")
	definitions[unit.unit_id]={talent:source}
	var context:Dictionary=BattleRequest.combat_context.duplicate(true)
	BattleRequest.combat_context.unit_talents={unit.unit_id:[talent]}
	unit.special={"progression_v1":{"shot_idle":3.0,"rest":1.99}}
	check(After.R.talent_rank(unit,talent)>=0,"live talent selection fixture activates")
	check(not Idle.try_tick(unit,0.1),"live capacitor selection falls back immediately")
	compare(unit,unit.special.duplicate(true),"live talent uses same rest/capacitor state transitions")
	BattleRequest.combat_context=context
	if old==null:definitions.erase(unit.unit_id)
	else:definitions[unit.unit_id]=old

func benchmark(unit) -> void:
	var initial={"progression_v1":{"arc_count":0,"shot_idle":2.0,"shot_origin":Vector2(100,200),"rest":0.0,"scrap_idle":0,"scrap_drop":0,"volley":10,"prism_damage":0.0}}
	var before:Array=[];var after:Array=[]
	for sample in 9:
		var expected:Dictionary={}
		var actual:Dictionary={}
		for variant in ([0,1] if sample%2==0 else [1,0]):
			reset(unit,initial)
			var begun:=Time.get_ticks_usec()
			for i in 1500:
				if variant==0:Before.tick(unit,1.0/15.0)
				else:After.tick(unit,1.0/15.0)
			var elapsed:=Time.get_ticks_usec()-begun
			if variant==0:before.append(elapsed);expected=capture(unit)
			else:after.append(elapsed);actual=capture(unit)
		check(actual==expected,unit.unit_id+" 1500 tick state and stats equal")
	before.sort();after.sort()
	metrics.append({"id":unit.unit_id,"repetitions":1500,"before_us":before,"after_us":after,"before_p50_us":before[4],"after_p50_us":after[4]})
