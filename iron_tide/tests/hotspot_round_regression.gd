extends Node
@export var round_id:=1
const Progress=preload("res://scripts/units/progression_expansion.gd")
const Expedition=preload("res://scripts/expedition/rules.gd")
const Dispatch=preload("res://scripts/world/ai_unit_dispatch.gd")
const Ref1=preload("res://tests/hotspot_reference_1.gd")
const Ref2=preload("res://tests/hotspot_reference_2.gd")
const Ref3=preload("res://tests/hotspot_reference_3.gd")
const Ref4=preload("res://tests/hotspot_reference_4.gd")
const Ref5=preload("res://tests/hotspot_reference_5.gd")
var check_count:=0
var failed:=0
var failures:Array=[]
var timings:Array=[]
var retained:Array=[]

func check(ok:bool,label:String) -> void:
	check_count+=1
	if not ok:
		failed+=1
		if failures.size()<20:failures.append(label)

func unit(id:String="MTNK") -> Unit:
	var u:=Unit.new();u.unit_id=id;u.side="ally";u.hp=100.0
	retained.append(u)
	return u

func compare(old:Callable,current:Callable,u:Unit,label:String) -> void:
	var state:=u.special.duplicate(true)
	check(old.call(u)==current.call(u),label)
	check(u.special==state,"query read-only "+label)

func bench(old:Callable,current:Callable,inputs:Array) -> void:
	# Equal inputs and call counts, alternating order; not a full-frame FPS test.
	for batch in 8:
		var row:Dictionary={}
		for before in ([true,false] if batch%2==0 else [false,true]):
			var method:Callable=old if before else current
			var total:=0.0
			var start:=Time.get_ticks_usec()
			for repeat in 1200:
				for input in inputs:total+=float(method.call(input))
			row["original_us" if before else "candidate_us"]=Time.get_ticks_usec()-start
			row["original_sum" if before else "candidate_sum"]=total
		check(row.original_sum==row.candidate_sum,"benchmark equal answers")
		timings.append(row)

func round_one() -> void:
	var u:=unit()
	var states:Array=[{}, {"speed_bonus":.25},{"move_lock":false},{"afterburn":{"speed":.2}},{"dive_boost":true},{"speed_bonus":-.5,"afterburn":{"speed":.3},"dive_boost":true}]
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		BattleRequest.rules_mode=mode
		for id in ["MTNK","DRON","SNIPE","DEST","BORIS"]:
			u.unit_id=id
			for side in ["ally","enemy"]:
				u.side=side
				for first in states:
					for second in [{},{"breather_left":2,"breather_speed":.2},{"pounce_left":1,"pounce_speed":.5},{"ballast_left":1,"side":side},{"shore_speed":1,"escort_buffs":[{"left":2,"side":side,"speed":.2}]}]:
						for include_first in [false,true]:
							for include_second in [false,true]:
								u.special={}
								if include_first:u.special.progression_v1=first.duplicate(true)
								if include_second:u.special.progression_v2=second.duplicate(true)
								compare(Ref1.speed,Progress.speed,u,"first/second speed")
								u.special.leizhu_control={"left":2,"side":side}
								compare(Ref1.speed,Progress.speed,u,"control lock")
	BattleRequest.rules_mode=MatchRules.EXTENDED
	var inputs:Array=[]
	for i in 32:
		var actor:=unit()
		if i%8==0:actor.special.progression_v1={"speed_bonus":.2}
		if i%8==1:actor.special.progression_v2={"breather_left":1,"breather_speed":.2}
		inputs.append(actor)
	bench(Ref1.speed,Progress.speed,inputs)

func round_two() -> void:
	var u:=unit()
	var target:=unit()
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		BattleRequest.rules_mode=mode
		for side in ["ally","enemy","ai2","neutral"]:
			u.side=side
			for context in [{},{"expedition":{}},{"expedition":{"traits":{"air":2},"specializations":{"MTNK":"b"}}}]:
				BattleRequest.combat_context=context
				for state in [{},{"expedition_convoy":true},{"expedition_convoy":true,"expedition_convoy_paused":true},{"expedition_speed_factor":1.2,"expedition_release_until":2},{"expedition_speed_factor":1.5}]:
					u.special=state
					for air in [false,true]:
						u.is_air=air
						for flight in ["flying","returning","rearming"]:
							u.logistics.air_state=flight
							for attacking in [false,true]:
								u.attack_target=target if attacking else null
								compare(Ref2.speed_factor,Expedition.speed_factor,u,"expedition live context")
	BattleRequest.rules_mode=MatchRules.EXTENDED;BattleRequest.combat_context={}
	var inputs:Array=[]
	for i in 30:
		var actor:=unit();actor.side="ally" if i%6==0 else "enemy";inputs.append(actor)
	bench(Ref2.speed_factor,Expedition.speed_factor,inputs)

func round_three() -> void:
	var capabilities:Dictionary=GameData.allied_capabilities
	var raw:Dictionary=GameData.ra2_source_units
	var u:=unit()
	for row in GameData.units:
		u.unit_id=row.id
		check(Ref3.source(u)==AlliedAbilities.source(u),"actual capability table")
	for table in [{},{"MTNK":{}},{"MTNK":{"Teleporter":true}}]:
		for fallback in [{},{"MTNK":{}},{"MTNK":{"extra":{"Teleporter":false}}}]:
			GameData.allied_capabilities={"units":table};GameData.ra2_source_units=fallback
			u.unit_id="MTNK"
			check(Ref3.source(u)==AlliedAbilities.source(u),"empty/present/fallback")
			if table.has("MTNK"):
				check(is_same(AlliedAbilities.source(u),table.MTNK),"shared live row")
				table.MTNK.changed=1
				check(AlliedAbilities.source(u).changed==1,"live row mutation")
				table.MTNK={"replaced":true}
				check(AlliedAbilities.source(u).get("replaced",false),"live replacement")
	GameData.allied_capabilities={};GameData.ra2_source_units={}
	var missing:=AlliedAbilities.source(u);missing.transient=true
	check(AlliedAbilities.source(u).is_empty(),"missing result remains fresh mutable dictionary")
	for value in [null,false,true,0,1,-1,0.0,1.5,"yes","no","true","false","1","0"," YES ","unknown"]:
		GameData.allied_capabilities={"units":{"MTNK":{"Probe":value}}}
		check(Ref3.flag(u,"Probe")==AlliedAbilities.flag(u,"Probe"),"flag conversion matches original")
		check(Ref3.flag(u,"Absent")==AlliedAbilities.flag(u,"Absent"),"missing flag")
	GameData.allied_capabilities=capabilities;GameData.ra2_source_units=raw
	var inputs:Array=[]
	for id in ["E1","GGI","MTNK","HTNK","APOC","DRON","SPY","ENGINEER","SHAD","ZEP","DEST","CARRIER","UNKNOWN"]:inputs.append(unit(id))
	bench(func(actor):return Ref3.flag(actor,"Teleporter"),func(actor):return AlliedAbilities.flag(actor,"Teleporter"),inputs)

func round_four() -> void:
	var old:=Ref4.new();var current:=Dispatch.new()
	var a:=Battle.new();var b:=Battle.new();retained.append_array([a,b])
	var inputs:Array=[]
	for i in 32:inputs.append(unit())
	for repeat in 8:
		for actor:Unit in inputs:
			var ea:Dictionary=old._entry(a,actor);var eb:Dictionary=current._entry(b,actor)
			check(ea==eb,"same queue contents")
			check(is_same(eb,b.allied_state.ai_dispatch_waiting[actor]),"entry alias")
			ea.path_tick=repeat;eb.path_tick=repeat
			actor.side="enemy" if actor.side=="ally" else "ally"
			check(old._entry(a,actor)==current._entry(b,actor),"existing owner retained until scheduler validation")
			if repeat%2==0:
				a.allied_state.ai_dispatch_waiting.erase(actor);b.allied_state.ai_dispatch_waiting.erase(actor)
		check(a.allied_state.ai_dispatch_waiting.keys()==b.allied_state.ai_dispatch_waiting.keys(),"FIFO insertion order")
		if repeat%3==0:a.allied_state={};b.allied_state={}
	bench(func(actor):return old._entry(a,actor).size(),func(actor):return current._entry(b,actor).size(),inputs)

func round_five() -> void:
	var old:=Ref5.new();retained.append(old)
	var current:=unit()
	var ids:Array=["UNKNOWN"]
	for row in GameData.units:ids.append(row.id)
	for id in ids:
		old.unit_id=id;current.unit_id=id
		for bits in 128:
			for actor:Unit in [old,current]:
				actor.is_air=bool(bits&1);actor.is_naval=bool(bits&2);actor.is_harvester=bool(bits&4)
				actor._deployed=bool(bits&8);actor.special={"soviet_mode":bool(bits&16)}
				actor.data={"ra2":bool(bits&32),"move":{"turret":bool(bits&64)}}
				actor.weapon={"damage":1};actor._mv_cache.clear()
			check(old._weapon_uses_hull()==current._weapon_uses_hull(),"hull classification "+id)
			check(old._mv_cache==current._mv_cache,"same movement cache effects")
			old.weapon={};current.weapon={}
			check(old._weapon_uses_hull()==current._weapon_uses_hull(),"empty weapon "+id)
	var inputs:Array=[]
	for id in ["MTNK","HTNK","APOC","E1","DRON","DRED","DEST","ZEP","SCHP","R3APOC","R3MIRAGE","DLPH"]:
		var a:=Ref5.new();var b:=unit(id);retained.append(a);a.unit_id=id
		for actor:Unit in [a,b]:actor.data={"ra2":true,"move":{"turret":true}};actor.weapon={"damage":1}
		inputs.append([a,b])
	bench(func(pair):return pair[0]._weapon_uses_hull(),func(pair):return pair[1]._weapon_uses_hull(),inputs)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	match round_id:
		1:round_one()
		2:round_two()
		3:round_three()
		4:round_four()
		5:round_five()
	for actor in retained:actor.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"round":round_id,"check_count":check_count,"failed":failed,"failures":failures,"timings":timings}))
	print("HOTSPOT_RESULT ",round_id," ",check_count," checks ",failed," failed ",failures)
	get_tree().quit(0 if failed==0 else 1)
